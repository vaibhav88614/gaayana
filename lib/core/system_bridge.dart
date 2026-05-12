import 'package:flutter/services.dart';

/// Bridge to native Android helpers in `MainActivity.kt`.
class SystemBridge {
  static const _ch = MethodChannel('com.gaayana/system');

  /// Sends the app to the background (Android's "Home" behaviour) without
  /// destroying the activity, so audio playback continues uninterrupted.
  static Future<void> moveToBackground() async {
    try {
      await _ch.invokeMethod<void>('moveToBackground');
    } catch (_) {
      // No-op on non-Android or if the channel isn't registered.
    }
  }
}
