package com.gaayana.app

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity

/**
 * Hosts the Flutter engine alongside the audio_service foreground service.
 *
 * - `onBackPressed` (legacy / pre-Android-13): minimise instead of finish so
 *   playback survives the user pressing the system Back button.
 * - `com.gaayana/system` MethodChannel: lets Dart explicitly request
 *   `moveToBackground` (used by `PopScope` on the Library home screen so
 *   predictive-back on Android 13+ also minimises instead of destroying).
 */
class MainActivity : AudioServiceActivity() {

    private val channelName = "com.gaayana/system"

    @Suppress("OVERRIDE_DEPRECATION", "MissingSuperCall")
    override fun onBackPressed() {
        moveTaskToBack(true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "moveToBackground" -> {
                        moveTaskToBack(true)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}

