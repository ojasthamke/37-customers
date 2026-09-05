package com.orderkart.app

import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.orderkart.app/sound"
    private var mediaPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val win = window
                val disp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    context.display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }
                val maxMode = disp?.supportedModes?.maxByOrNull { it.refreshRate }
                if (maxMode != null) {
                    val params = win.attributes
                    params.preferredDisplayModeId = maxMode.modeId
                    win.attributes = params
                }
            }
        } catch (_: Exception) {}

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playSuccessSound") {
                try {
                    mediaPlayer?.release()
                    val resId = resources.getIdentifier("success_chime", "raw", packageName)
                    if (resId != 0) {
                        mediaPlayer = MediaPlayer.create(this, resId).apply {
                            setAudioAttributes(
                                AudioAttributes.Builder()
                                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                                    .build()
                            )
                            setOnCompletionListener { mp ->
                                mp.release()
                                if (mediaPlayer == mp) mediaPlayer = null
                            }
                            start()
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                } catch (e: Exception) {
                    result.error("AUDIO_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        try {
            mediaPlayer?.release()
            mediaPlayer = null
        } catch (_: Exception) {}
        super.onDestroy()
    }
}

