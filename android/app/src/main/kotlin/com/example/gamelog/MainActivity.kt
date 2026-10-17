package com.example.gamelog

import android.content.Intent
import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.gamelog/update"
    private val MEDIA_CHANNEL = "com.example.gamelog/media"
    private val worker = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // Video frames for "make a GIF from a video". Frame grabbing is slow,
        // so it runs off the main thread.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "videoDuration" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "path is required", null)
                        return@setMethodCallHandler
                    }
                    worker.execute {
                        try {
                            val retriever = MediaMetadataRetriever()
                            retriever.setDataSource(path)
                            val ms = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
                            retriever.release()
                            mainHandler.post { result.success(ms) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("VIDEO_ERROR", e.message, null) }
                        }
                    }
                }
                "extractFrames" -> {
                    val path = call.argument<String>("path")
                    val startMs = (call.argument<Number>("startMs") ?: 0).toLong()
                    val durationMs = (call.argument<Number>("durationMs") ?: 3000).toLong()
                    val fps = (call.argument<Number>("fps") ?: 10).toInt().coerceIn(1, 20)
                    val width = (call.argument<Number>("width") ?: 320).toInt()
                    val height = (call.argument<Number>("height") ?: 320).toInt()
                    if (path == null) {
                        result.error("INVALID_ARGUMENT", "path is required", null)
                        return@setMethodCallHandler
                    }
                    worker.execute {
                        try {
                            val frames = extractFrames(path, startMs, durationMs, fps, width, height)
                            mainHandler.post { result.success(frames) }
                        } catch (e: Exception) {
                            mainHandler.post { result.error("VIDEO_ERROR", e.message, null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Frames as raw RGBA bytes, already centre-cropped to [width]x[height]:
     * [fps] per second from [startMs] for [durationMs].
     */
    private fun extractFrames(path: String, startMs: Long, durationMs: Long, fps: Int, width: Int, height: Int): List<ByteArray> {
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(path)
            val total = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0L
            val end = if (total > 0) minOf(startMs + durationMs, total) else startMs + durationMs
            val stepUs = 1_000_000L / fps
            val frames = ArrayList<ByteArray>()
            var tUs = startMs * 1000
            while (tUs < end * 1000) {
                val raw: Bitmap? = retriever.getFrameAtTime(tUs, MediaMetadataRetriever.OPTION_CLOSEST)
                if (raw != null) {
                    frames.add(toRgba(cropScale(raw, width, height)))
                }
                tUs += stepUs
            }
            return frames
        } finally {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) retriever.close() else retriever.release()
        }
    }

    /** Centre-crop [src] to the target aspect ratio and scale to exactly width x height. */
    private fun cropScale(src: Bitmap, width: Int, height: Int): Bitmap {
        val target = width.toFloat() / height
        val srcAspect = src.width.toFloat() / src.height
        var cw = src.width
        var ch = src.height
        if (srcAspect > target) cw = (src.height * target).toInt() else ch = (src.width / target).toInt()
        val x = (src.width - cw) / 2
        val y = (src.height - ch) / 2
        val cropped = Bitmap.createBitmap(src, x, y, cw.coerceAtLeast(1), ch.coerceAtLeast(1))
        val scaled = Bitmap.createScaledBitmap(cropped, width, height, true)
        if (cropped !== src) cropped.recycle()
        if (scaled !== src) src.recycle()
        return scaled
    }

    private fun toRgba(bmp: Bitmap): ByteArray {
        val argb = if (bmp.config == Bitmap.Config.ARGB_8888) bmp else bmp.copy(Bitmap.Config.ARGB_8888, false)
        val buffer = java.nio.ByteBuffer.allocate(argb.byteCount)
        argb.copyPixelsToBuffer(buffer) // RGBA byte order
        if (argb !== bmp) argb.recycle()
        bmp.recycle()
        return buffer.array()
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
