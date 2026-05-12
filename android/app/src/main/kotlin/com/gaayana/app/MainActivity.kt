package com.gaayana.app

import com.ryanheise.audioservice.AudioServiceActivity

/**
 * Overrides back-press behaviour so the app moves to the background instead of
 * being destroyed. This keeps the audio_service foreground service (and the
 * Flutter engine) alive so playback survives the user pressing the system
 * Back gesture/button.
 */
class MainActivity : AudioServiceActivity() {

    @Suppress("OVERRIDE_DEPRECATION", "MissingSuperCall")
    override fun onBackPressed() {
        // Send the task to the background rather than finishing the activity.
        moveTaskToBack(true)
    }
}
