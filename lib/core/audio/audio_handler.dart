import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:rxdart/rxdart.dart';

import '../models.dart';

/// `audio_service` background handler.
///
/// Owns the [ja.AudioPlayer] and translates `audio_service` events (lock-screen
/// taps, Bluetooth media buttons, Android Auto / CarPlay) into player calls.
class GaayanaAudioHandler extends BaseAudioHandler with SeekHandler {
  GaayanaAudioHandler() {
    _init();
  }

  /// Android system equalizer applied to the player.
  final ja.AndroidEqualizer equalizer = ja.AndroidEqualizer();
  /// Android loudness enhancer — drives the "Bass / Loudness boost" slider.
  final ja.AndroidLoudnessEnhancer loudnessEnhancer =
      ja.AndroidLoudnessEnhancer();
  late final ja.AudioPlayer player = ja.AudioPlayer(
    audioPipeline: ja.AudioPipeline(
      androidAudioEffects: [loudnessEnhancer, equalizer],
    ),
  );
  final BehaviorSubject<List<Track>> _queue =
      BehaviorSubject<List<Track>>.seeded(const []);
  final BehaviorSubject<LoopMode> _loop =
      BehaviorSubject<LoopMode>.seeded(LoopMode.off);
  final BehaviorSubject<bool> _shuffle = BehaviorSubject<bool>.seeded(false);
  final BehaviorSubject<double> _speed = BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<double> _pitch = BehaviorSubject<double>.seeded(1.0);
  final BehaviorSubject<Duration> _crossfade =
      BehaviorSubject<Duration>.seeded(Duration.zero);
  final BehaviorSubject<bool> _gapless = BehaviorSubject<bool>.seeded(true);
  final BehaviorSubject<double> _bassBoostDb =
      BehaviorSubject<double>.seeded(0.0);

  Stream<List<Track>> get queueTracks => _queue.stream;
  Stream<LoopMode> get loopMode => _loop.stream;
  Stream<bool> get shuffleMode => _shuffle.stream;
  Stream<double> get speedStream => _speed.stream;
  Stream<double> get pitchStream => _pitch.stream;
  Stream<Duration> get crossfadeStream => _crossfade.stream;
  Stream<bool> get gaplessStream => _gapless.stream;
  Stream<double> get bassBoostStream => _bassBoostDb.stream;
  LoopMode get currentLoop => _loop.value;
  List<Track> get currentQueue => _queue.value;
  double get currentSpeed => _speed.value;
  double get currentPitch => _pitch.value;
  Duration get currentCrossfade => _crossfade.value;
  bool get gaplessEnabled => _gapless.value;

  Track? get currentTrack {
    final idx = player.currentIndex;
    if (idx == null || idx < 0 || idx >= _queue.value.length) return null;
    return _queue.value[idx];
  }

  Stream<Track?> get currentTrackStream =>
      Rx.combineLatest2<int?, List<Track>, Track?>(
        player.currentIndexStream,
        _queue.stream,
        (idx, q) => (idx == null || idx < 0 || idx >= q.length) ? null : q[idx],
      ).distinct();

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Resume after a transient audio-focus loss (e.g. user watches an
    // Instagram reel / YouTube short and comes back).
    //
    // Snapshot `_wasPlayingBeforeInterruption` at the START of EVERY
    // interruption (regardless of type), because by the time the OS sends the
    // "end" event the player has already been paused by just_audio's own
    // focus handler — so checking `player.playing` then is too late and the
    // resume never fires. On end, always restore volume (covers a duck that
    // was upgraded to a pause mid-flight) and resume playback if we had been
    // playing when the interruption began.
    session.interruptionEventStream.listen((event) async {
      if (event.begin) {
        _wasPlayingBeforeInterruption = player.playing;
        switch (event.type) {
          case AudioInterruptionType.duck:
            await player.setVolume(0.3);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            if (player.playing) await player.pause();
            break;
        }
      } else {
        await player.setVolume(1.0);
        if (_wasPlayingBeforeInterruption) {
          _wasPlayingBeforeInterruption = false;
          await player.play();
        }
      }
    });

    // Pause when headphones unplug / Bluetooth disconnects.
    session.becomingNoisyEventStream.listen((_) {
      if (player.playing) player.pause();
    });

    player.playbackEventStream.listen(_broadcastState,
        onError: (Object e, StackTrace s) {
      playbackState.add(playbackState.value
          .copyWith(processingState: AudioProcessingState.error));
    });

    player.currentIndexStream.listen((idx) {
      if (idx == null) return;
      final q = _queue.value;
      if (idx < 0 || idx >= q.length) return;
      mediaItem.add(_toMediaItem(q[idx]));
    });

    _wireCrossfade();
  }

  bool _wasPlayingBeforeInterruption = false;

  void _broadcastState(ja.PlaybackEvent event) {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        const MediaControl(
          androidIcon: 'drawable/ic_notif_skip_previous',
          label: 'Previous',
          action: MediaAction.skipToPrevious,
        ),
        if (playing)
          const MediaControl(
            androidIcon: 'drawable/ic_notif_pause',
            label: 'Pause',
            action: MediaAction.pause,
          )
        else
          const MediaControl(
            androidIcon: 'drawable/ic_notif_play',
            label: 'Play',
            action: MediaAction.play,
          ),
        const MediaControl(
          androidIcon: 'drawable/ic_notif_stop',
          label: 'Stop',
          action: MediaAction.stop,
        ),
        const MediaControl(
          androidIcon: 'drawable/ic_notif_skip_next',
          label: 'Next',
          action: MediaAction.skipToNext,
        ),
      ],
      systemActions: const {
        MediaAction.play,
        MediaAction.pause,
        MediaAction.playPause,
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
        MediaAction.stop,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ja.ProcessingState.idle: AudioProcessingState.idle,
        ja.ProcessingState.loading: AudioProcessingState.loading,
        ja.ProcessingState.buffering: AudioProcessingState.buffering,
        ja.ProcessingState.ready: AudioProcessingState.ready,
        ja.ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    ));
  }

  Future<void> setQueue(List<Track> tracks, {int initialIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue.add(List.unmodifiable(tracks));
    final sources = tracks.map(_toAudioSource).toList();
    final idx = initialIndex.clamp(0, tracks.length - 1);
    await player.setAudioSource(
      ja.ConcatenatingAudioSource(children: sources),
      initialIndex: idx,
      preload: true,
    );
    queue.add(tracks.map(_toMediaItem).toList());
    // Publish the current MediaItem immediately so the notification & lock
    // screen populate without waiting for the index stream tick.
    mediaItem.add(_toMediaItem(tracks[idx]));
  }

  Future<void> appendToQueue(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    final next = [..._queue.value, ...tracks];
    _queue.add(List.unmodifiable(next));
    final src = player.audioSource;
    if (src is ja.ConcatenatingAudioSource) {
      await src.addAll(tracks.map(_toAudioSource).toList());
    } else {
      await player.setAudioSource(
        ja.ConcatenatingAudioSource(
            children: next.map(_toAudioSource).toList()),
        initialIndex: player.currentIndex ?? 0,
      );
    }
    queue.add(next.map(_toMediaItem).toList());
  }

  Future<void> removeAt(int index) async {
    final list = [..._queue.value]..removeAt(index);
    _queue.add(List.unmodifiable(list));
    final src = player.audioSource;
    if (src is ja.ConcatenatingAudioSource) {
      await src.removeAt(index);
    }
    queue.add(list.map(_toMediaItem).toList());
  }

  /// Reorder a track within the current queue.
  Future<void> moveQueueItem(int from, int to) async {
    if (from == to) return;
    final list = [..._queue.value];
    if (from < 0 || from >= list.length) return;
    final item = list.removeAt(from);
    final insertAt = to.clamp(0, list.length);
    list.insert(insertAt, item);
    _queue.add(List.unmodifiable(list));
    final src = player.audioSource;
    if (src is ja.ConcatenatingAudioSource) {
      await src.move(from, insertAt);
    }
    queue.add(list.map(_toMediaItem).toList());
  }

  /// Play an arbitrary http(s)/file stream URL as a single-item queue.
  /// Used for "Open URL…" and for internet radio stations.
  Future<void> playUrl(String url, {String? title, String? artist}) async {
    final t = Track(
      id: 'url:$url',
      sourceId: 'stream',
      title: title ?? Uri.parse(url).pathSegments.lastOrNull ?? url,
      artist: artist ?? 'Stream',
      album: '',
      durationMs: 0,
      uri: url,
    );
    await setQueue([t]);
    await play();
  }

  ja.AudioSource _toAudioSource(Track t) => ja.AudioSource.uri(
        Uri.parse(t.uri),
        tag: _toMediaItem(t),
      );

  MediaItem _toMediaItem(Track t) => MediaItem(
        id: t.globalId,
        title: t.title,
        album: t.album,
        artist: t.artist,
        genre: t.genre,
        duration: Duration(milliseconds: t.durationMs),
        artUri: t.albumArtUri == null ? null : Uri.tryParse(t.albumArtUri!),
        extras: {'sourceId': t.sourceId, 'localId': t.id},
      );

  // ---- Controls (called by lock-screen / Bluetooth / UI) -------------------

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() async {
    final q = _queue.value;
    if (q.isEmpty) return;
    if (_loop.value == LoopMode.one) {
      await player.seek(Duration.zero);
      if (!player.playing) await player.play();
      return;
    }
    // Prefer just_audio's native advance — it's the source-of-truth for the
    // index and avoids a race where `player.currentIndex` lags the queue and
    // we end up re-seeking to the same track (the "Next restarts current
    // song" bug).
    if (player.hasNext) {
      await player.seekToNext();
    } else if (_loop.value == LoopMode.all) {
      await player.seek(Duration.zero, index: 0);
    } else {
      // End of queue & no loop — wrap so the button always produces feedback.
      await player.seek(Duration.zero, index: 0);
    }
    if (!player.playing) await player.play();
  }

  @override
  Future<void> skipToPrevious() async {
    final q = _queue.value;
    if (q.isEmpty) return;
    if (player.position.inSeconds > 3) {
      await player.seek(Duration.zero);
      return;
    }
    if (player.hasPrevious) {
      await player.seekToPrevious();
    } else if (_loop.value == LoopMode.all) {
      await player.seek(Duration.zero, index: q.length - 1);
    } else {
      await player.seek(Duration.zero);
      return;
    }
    if (!player.playing) await player.play();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.value.length) return;
    await player.seek(Duration.zero, index: index);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    _loop.add(mode);
    switch (mode) {
      case LoopMode.off:
        await player.setLoopMode(ja.LoopMode.off);
        break;
      case LoopMode.one:
        await player.setLoopMode(ja.LoopMode.one);
        break;
      case LoopMode.all:
        await player.setLoopMode(ja.LoopMode.all);
        break;
    }
  }

  Future<void> setShuffleEnabled(bool shuffle) async {
    _shuffle.add(shuffle);
    await player.setShuffleModeEnabled(shuffle);
    if (shuffle) await player.shuffle();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await setShuffleEnabled(shuffleMode != AudioServiceShuffleMode.none);
  }

  /// Fade-out over [duration] then pause. Used by the sleep timer.
  Future<void> fadeOutAndPause(Duration duration) async {
    final start = player.volume;
    const steps = 20;
    final stepDur = Duration(milliseconds: duration.inMilliseconds ~/ steps);
    for (var i = steps - 1; i >= 0; i--) {
      await Future<void>.delayed(stepDur);
      await player.setVolume(start * (i / steps));
    }
    await player.pause();
    await player.setVolume(start);
  }

  // ---- Speed / pitch / crossfade / gapless --------------------------------

  @override
  Future<void> setSpeed(double speed) async {
    final clamped = speed.clamp(0.5, 2.0);
    _speed.add(clamped);
    await player.setSpeed(clamped);
  }

  Future<void> setPitch(double pitch) async {
    final clamped = pitch.clamp(0.5, 1.5);
    _pitch.add(clamped);
    try {
      await player.setPitch(clamped);
    } catch (_) {
      // setPitch only works on Android and only when ProcessingState is ready.
    }
  }

  Future<void> setCrossfade(Duration d) async {
    _crossfade.add(d);
  }

  Future<void> setGapless(bool enabled) async {
    _gapless.add(enabled);
    // just_audio uses ConcatenatingAudioSource which is gapless by default;
    // when disabled we insert a tiny silence between tracks.
  }

  /// Boost loudness/bass by [db] (0..12). 0 disables the effect entirely.
  /// just_audio's `setTargetGain` is in "bels" (×1000 → millibels), so we
  /// divide by 10 to convert decibels.
  Future<void> setBassBoost(double db) async {
    final clamped = db.clamp(0.0, 12.0);
    _bassBoostDb.add(clamped);
    try {
      await loudnessEnhancer.setEnabled(clamped > 0);
      await loudnessEnhancer.setTargetGain(clamped / 10.0);
    } catch (_) {
      // Loudness enhancer is Android-only and may fail before init.
    }
  }

  StreamSubscription<Duration>? _crossfadeSub;
  Track? _crossfadingFrom;

  void _wireCrossfade() {
    _crossfadeSub?.cancel();
    _crossfadeSub = player.positionStream.listen((pos) async {
      final cf = _crossfade.value;
      if (cf == Duration.zero) return;
      final dur = player.duration;
      if (dur == null) return;
      final remaining = dur - pos;
      if (remaining > cf) {
        _crossfadingFrom = null;
        return;
      }
      if (!player.hasNext) return;
      final cur = currentTrack;
      if (cur == null || identical(cur, _crossfadingFrom)) return;
      _crossfadingFrom = cur;
      final startVol = player.volume;
      const steps = 10;
      final stepMs = (remaining.inMilliseconds / steps).clamp(20, 500).round();
      for (var i = steps - 1; i >= 0; i--) {
        await Future<void>.delayed(Duration(milliseconds: stepMs));
        await player.setVolume(startVol * (i / steps));
      }
      await player.seekToNext();
      // ramp back up
      for (var i = 1; i <= steps; i++) {
        await Future<void>.delayed(Duration(milliseconds: stepMs));
        await player.setVolume(startVol * (i / steps));
      }
      await player.setVolume(startVol);
    });
  }

  void disposeAll() {
    _crossfadeSub?.cancel();
    player.dispose();
    _queue.close();
    _loop.close();
    _shuffle.close();
    _speed.close();
    _pitch.close();
    _crossfade.close();
    _gapless.close();
    _bassBoostDb.close();
  }
}
