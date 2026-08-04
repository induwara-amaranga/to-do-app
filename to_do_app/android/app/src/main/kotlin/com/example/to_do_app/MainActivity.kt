package com.example.to_do_app

import io.flutter.embedding.android.FlutterActivity
import android.app.Activity
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
//import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.to_do_app/ringtone"
    private val RINGTONE_PICKER_REQUEST = 999
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                pendingResult = result
                val currentUri = call.argument<String>("currentUri")

                val ringtoneType = when (call.method) {
                    "pickAlarmTone" -> RingtoneManager.TYPE_ALARM
                    "pickNotificationTone" -> RingtoneManager.TYPE_NOTIFICATION
                    else -> {
                        result.notImplemented()
                        return@setMethodCallHandler
                    }
                }

                val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                    putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, ringtoneType)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, true)
                    putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                    if (currentUri != null) {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(currentUri))
                    }
                }
                startActivityForResult(intent, RINGTONE_PICKER_REQUEST)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_PICKER_REQUEST) {
            if (resultCode == Activity.RESULT_OK) {
                val uri = data?.getParcelableExtra<Uri>(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
                if (uri != null) {
                    val ringtone = RingtoneManager.getRingtone(this, uri)
                    val name = ringtone.getTitle(this)
                    pendingResult?.success(mapOf("uri" to uri.toString(), "name" to name))
                } else {
                    pendingResult?.success(null)
                }
            } else {
                pendingResult?.success(null)
            }
            pendingResult = null
        }
    }
}

//class MainActivity : FlutterActivity()
