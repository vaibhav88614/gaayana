import 'dart:async';

import 'audio_handler.dart';

/// Sleep timer with a configurable fade-out tail. Requirement #7.
///
/// Two modes:
/// * Fixed duration ("pause in 30 minutes").
/// * End-of-track ("pause after this song finishes").
class SleepTimer {
  SleepTimer(this._handler);
  final GaayanaAudioHandler _handler;

  Timer? _timer;
  StreamSubscription<int?>? _trackSub;
  DateTime? _firesAt;
  bool _endOfTrack = false;
  static const _fadeDuration = Duration(seconds: 8);

  DateTime? get firesAt => _firesAt;
  bool get isActive => _timer != null || _trackSub != null;

  /// Start a fixed-duration timer. Cancels any existing timer.
  void startAfter(Duration duration) {
    cancel();
    _firesAt = DateTime.now().add(duration);
    final fireIn = duration - _fadeDuration;
    if (fireIn.isNegative) {
      _handler.fadeOutAndPause(duration);
    } else {
      _timer = Timer(fireIn, () => _handler.fadeOutAndPause(_fadeDuration));
    }
  }

  /// Pause when the current track finishes naturally.
  void startAtEndOfTrack() {
    cancel();
    _endOfTrack = true;
    final startIndex = _handler.player.currentIndex;
    _trackSub = _handler.player.currentIndexStream.listen((idx) {
      if (idx != startIndex) {
        _handler.pause();
        cancel();
      }
    });
  }

  /// Pause after [n] more tracks complete.
  void startAfterTracks(int n) {
    cancel();
    if (n <= 0) {
      _handler.pause();
      return;
    }
    var remaining = n;
    final startIndex = _handler.player.currentIndex;
    int? lastIdx = startIndex;
    _trackSub = _handler.player.currentIndexStream.listen((idx) {
      if (idx == null || idx == lastIdx) return;
      lastIdx = idx;
      remaining--;
      if (remaining <= 0) {
        _handler.pause();
        cancel();
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _trackSub?.cancel();
    _trackSub = null;
    _firesAt = null;
    _endOfTrack = false;
  }

  Duration? remaining() {
    if (_firesAt == null) return null;
    final r = _firesAt!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }
}
