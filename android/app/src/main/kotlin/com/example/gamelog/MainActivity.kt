package com.example.gamelog

import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.gamelog/update"
    private val WIDGET_CHANNEL = "com.example.gamelog/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Update channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        installApk(filePath)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Widget channel for deep links
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialGameId" -> {
                    val gameId = intent?.getStringExtra("gameId")
                    result.success(gameId)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        
        // Handle widget click
        val gameId = intent.getStringExtra("gameId")
        val openGameDetail = intent.getBooleanExtra("openGameDetail", false)
        
        if (gameId != null && openGameDetail) {
            // Send to Flutter
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, WIDGET_CHANNEL).invokeMethod("openGameDetail", gameId)
            }
        }
    }

    private fun installApk(filePath: String) {
        try {
            val file = File(filePath)
            if (!file.exists()) {
                return
            }

            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

            val uri = FileProvider.getUriForFile(
                this,
                "${packageName}.fileprovider",
                file
            )
            
            intent.setDataAndType(uri, "application/vnd.android.package-archive")
            startActivity(intent)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
