import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/audio_handler.dart';
import 'audio/route_watcher.dart';
import 'audio/sleep_timer.dart';
import 'db/app_database.dart';
import 'firebase/auth_service.dart';
import 'firebase/firestore_sync.dart';
import 'music_source/local_file_source.dart';
import 'music_source/music_source.dart';
import 'network/lastfm_client.dart';
import 'network/lrclib_client.dart';

/// Initialised once at app start; see `main.dart`.
final audioHandlerProvider = Provider<GaayanaAudioHandler>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

final routeWatcherProvider = Provider<RouteWatcher>((ref) {
  final w = RouteWatcher();
  ref.onDispose(w.dispose);
  return w;
});

final outputRouteProvider = StreamProvider((ref) {
  return ref.watch(routeWatcherProvider).stream;
});

final sleepTimerProvider = Provider<SleepTimer>((ref) {
  return SleepTimer(ref.watch(audioHandlerProvider));
});

final authServiceProvider = Provider<AuthService?>(
  (ref) => ref.watch(firebaseReadyProvider) ? AuthService() : null,
);
final authStateProvider = StreamProvider<Object?>(
  (ref) => ref.watch(authServiceProvider)?.authStateChanges() ??
      Stream<Object?>.value(null),
);

final firestoreSyncProvider = Provider<FirestoreSync?>(
  (ref) => ref.watch(firebaseReadyProvider) ? FirestoreSync() : null,
);

final firebaseReadyProvider = Provider<bool>(
  (ref) => throw UnimplementedError('overridden in main()'),
);

/// App-wide theme mode, persisted in SharedPreferences.
final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(sharedPrefsProvider));
});

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._prefs) : super(_load(_prefs));
  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  static ThemeMode _load(SharedPreferences p) {
    switch (p.getString(_key)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  void set(ThemeMode mode) {
    state = mode;
    _prefs.setString(_key, mode.name);
  }

  /// Cycles system → light → dark → system.
  void toggle() {
    switch (state) {
      case ThemeMode.system:
        set(ThemeMode.light);
      case ThemeMode.light:
        set(ThemeMode.dark);
      case ThemeMode.dark:
        set(ThemeMode.system);
    }
  }
}

final musicSourceProvider = Provider<MusicSource>((ref) {
  return LocalFileSource(
    ref.watch(databaseProvider),
    prefs: ref.watch(sharedPrefsProvider),
  );
});

final lastfmClientProvider = Provider<LastfmClient>((ref) {
  const key = String.fromEnvironment('LASTFM_API_KEY');
  final prefs = ref.watch(sharedPrefsProvider);
  final stored = prefs.getString('lastfm_api_key') ?? '';
  return LastfmClient(apiKey: key.isNotEmpty ? key : stored);
});

final lrclibClientProvider = Provider<LrclibClient>((ref) => LrclibClient());

// ---- Playback state streams (UI subscribes to these) -----------------------

final currentTrackProvider = StreamProvider((ref) {
  return ref.watch(audioHandlerProvider).currentTrackStream;
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final positionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioHandlerProvider).player.positionStream;
});

final queueProvider = StreamProvider((ref) {
  return ref.watch(audioHandlerProvider).queueTracks;
});

/// Watches the current-track stream and records a play row each time the
/// track changes. Side-effect provider — must be `read` once at app start.
final playHistoryRecorderProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  String? lastRecorded;
  ref.listen<AsyncValue<dynamic>>(currentTrackProvider, (prev, next) {
    final t = next.valueOrNull;
    if (t == null) return;
    if (t.globalId == lastRecorded) return;
    lastRecorded = t.globalId;
    db.recordPlay(t.globalId);
  });
});

/// Persists the queue + position so that the user can resume after relaunch.
/// Periodically samples player state; cheap and resilient to crashes.
final playbackStatePersisterProvider = Provider<void>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final db = ref.watch(databaseProvider);
  final prefs = ref.watch(sharedPrefsProvider);

  // Restore persisted audio effects on first attach.
  final savedBass = prefs.getDouble('audio.bassBoostDb') ?? 0.0;
  if (savedBass > 0) handler.setBassBoost(savedBass);
  final savedCrossfade = prefs.getInt('audio.crossfadeSec') ?? 0;
  if (savedCrossfade > 0) {
    handler.setCrossfade(Duration(seconds: savedCrossfade));
  }
  final savedSpeed = prefs.getDouble('audio.speed') ?? 1.0;
  if (savedSpeed != 1.0) handler.setSpeed(savedSpeed);

  // Persist effect changes whenever they happen.
  final bSub = handler.bassBoostStream
      .listen((v) => prefs.setDouble('audio.bassBoostDb', v));
  final cSub = handler.crossfadeStream
      .listen((v) => prefs.setInt('audio.crossfadeSec', v.inSeconds));
  final sSub =
      handler.speedStream.listen((v) => prefs.setDouble('audio.speed', v));

  Future<void> save() async {
    try {
      final q = handler.currentQueue;
      if (q.isEmpty) return;
      await db.savePlaybackState(
        queueGlobalIds: q.map((t) => t.globalId).toList(),
        queueIndex: handler.player.currentIndex ?? 0,
        positionMs: handler.player.position.inMilliseconds,
      );
    } catch (_) {}
  }

  // Save when the user pauses/stops.
  final sub1 = handler.player.playingStream.listen((_) => save());
  // Save when the track changes.
  final sub2 = handler.player.currentIndexStream.listen((_) => save());
  // Throttled position save every 10 s while playing.
  DateTime lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  final sub3 = handler.player.positionStream.listen((_) {
    final now = DateTime.now();
    if (now.difference(lastSave).inSeconds < 10) return;
    lastSave = now;
    save();
  });

  ref.onDispose(() {
    sub1.cancel();
    sub2.cancel();
    sub3.cancel();
    bSub.cancel();
    cSub.cancel();
    sSub.cancel();
  });
});

final loopModeProvider = StreamProvider((ref) {
  return ref.watch(audioHandlerProvider).loopMode;
});

final shuffleModeProvider = StreamProvider((ref) {
  return ref.watch(audioHandlerProvider).shuffleMode;
});

final speedProvider = StreamProvider<double>((ref) {
  return ref.watch(audioHandlerProvider).speedStream;
});

final pitchProvider = StreamProvider<double>((ref) {
  return ref.watch(audioHandlerProvider).pitchStream;
});

final crossfadeProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioHandlerProvider).crossfadeStream;
});

final gaplessProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioHandlerProvider).gaplessStream;
});

final bassBoostProvider = StreamProvider<double>((ref) {
  return ref.watch(audioHandlerProvider).bassBoostStream;
});

/// Whether [globalId] is in the favorites table. Re-fetched whenever
/// [favoritesRefreshProvider] increments.
final isFavoriteProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, globalId) async {
  ref.watch(favoritesRefreshProvider);
  return ref.read(databaseProvider).isFavorite(globalId);
});

/// Bumped whenever a favorite is toggled, to invalidate watchers.
final favoritesRefreshProvider = StateProvider<int>((_) => 0);
