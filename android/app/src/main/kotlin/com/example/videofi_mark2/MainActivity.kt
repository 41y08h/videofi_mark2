package com.example.videofi_mark2

import android.media.RingtoneManager
import androidx.annotation.NonNull
import dev.darttools.flutter_android_volume_keydown.FlutterAndroidVolumeKeydownActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterAndroidVolumeKeydownActivity() {
    private val CHANNEL = "videofi_common_channel"
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "getDefaultRingtoneUri") {
                result.success(getDefaultRingtoneUri())
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getDefaultRingtoneUri(): String {
        val uri =
                RingtoneManager.getActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE)
        return uri.toString()
    }
}
