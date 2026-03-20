package com.jiangyan.shuxiangread

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.KeyEvent
import android.provider.OpenableColumns
import io.flutter.plugin.common.EventChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        private const val SOURCE_IMPORT_CHANNEL_NAME = "com.jiangyan.shuxiangread/source_import_intent"
        private const val METHOD_GET_INITIAL_IMPORT_PAYLOAD = "getInitialImportPayload"
        private const val METHOD_ON_IMPORT_PAYLOAD = "onImportPayload"
        private const val READER_VOLUME_KEY_CHANNEL_NAME = "com.jiangyan.shuxiangread/reader_volume_keys"
        private const val READER_VOLUME_KEY_EVENT_CHANNEL_NAME = "com.jiangyan.shuxiangread/reader_volume_keys/events"
        private const val METHOD_SET_INTERCEPT_VOLUME_KEYS = "setInterceptVolumeKeys"
        private const val DEFAULT_PAYLOAD_LABEL = "外部书源"
    }

    private var sourceImportMethodChannel: MethodChannel? = null
    private var readerVolumeKeyMethodChannel: MethodChannel? = null
    private var readerVolumeKeyEventChannel: EventChannel? = null
    private var readerVolumeKeyEventSink: EventChannel.EventSink? = null
    private var pendingInitialPayload: Map<String, Any>? = null
    private var interceptReaderVolumeKeys = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        pendingInitialPayload = extractPayloadFromIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sourceImportMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SOURCE_IMPORT_CHANNEL_NAME
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_GET_INITIAL_IMPORT_PAYLOAD -> {
                        result.success(pendingInitialPayload)
                        pendingInitialPayload = null
                    }

                    else -> result.notImplemented()
                }
            }
        }

        readerVolumeKeyMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            READER_VOLUME_KEY_CHANNEL_NAME
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_SET_INTERCEPT_VOLUME_KEYS -> {
                        interceptReaderVolumeKeys = (call.arguments as? Boolean) ?: false
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }

        readerVolumeKeyEventChannel = EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            READER_VOLUME_KEY_EVENT_CHANNEL_NAME
        ).also { channel ->
            channel.setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        readerVolumeKeyEventSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        readerVolumeKeyEventSink = null
                    }
                }
            )
        }

        if (pendingInitialPayload == null) {
            pendingInitialPayload = extractPayloadFromIntent(intent)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val payload = extractPayloadFromIntent(intent) ?: return
        pendingInitialPayload = payload
        sourceImportMethodChannel?.invokeMethod(METHOD_ON_IMPORT_PAYLOAD, payload)
    }

    override fun onDestroy() {
        sourceImportMethodChannel?.setMethodCallHandler(null)
        sourceImportMethodChannel = null
        readerVolumeKeyMethodChannel?.setMethodCallHandler(null)
        readerVolumeKeyMethodChannel = null
        readerVolumeKeyEventChannel?.setStreamHandler(null)
        readerVolumeKeyEventChannel = null
        readerVolumeKeyEventSink = null
        interceptReaderVolumeKeys = false
        super.onDestroy()
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (
            interceptReaderVolumeKeys &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            when (event.action) {
                KeyEvent.ACTION_DOWN -> {
                    if (event.repeatCount == 0) {
                        val direction = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) {
                            "up"
                        } else {
                            "down"
                        }
                        readerVolumeKeyEventSink?.success(
                            mapOf(
                                "direction" to direction,
                                "repeatCount" to event.repeatCount
                            )
                        )
                    }
                    return true
                }

                KeyEvent.ACTION_UP -> return true
            }
        }
        return super.dispatchKeyEvent(event)
    }

    private fun extractPayloadFromIntent(intent: Intent?): Map<String, Any>? {
        intent ?: return null

        return when (intent.action) {
            Intent.ACTION_VIEW -> buildPayloadFromUri(intent.data)
            Intent.ACTION_SEND -> buildPayloadFromSendIntent(intent)
            Intent.ACTION_SEND_MULTIPLE -> buildPayloadFromSendMultipleIntent(intent)
            else -> null
        }
    }

    private fun buildPayloadFromSendIntent(intent: Intent): Map<String, Any>? {
        val sharedUri = readSharedUri(intent)
        if (sharedUri != null) {
            return buildPayloadFromUri(sharedUri)
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        if (text.isNullOrEmpty()) {
            return null
        }

        return mapOf(
            "bytes" to text.toByteArray(Charsets.UTF_8),
            "label" to (intent.getStringExtra(Intent.EXTRA_SUBJECT)?.trim().takeUnless { it.isNullOrEmpty() }
                ?: "外部分享文本")
        )
    }

    private fun buildPayloadFromSendMultipleIntent(intent: Intent): Map<String, Any>? {
        val uris = readSharedUriList(intent)
        if (uris.isEmpty()) {
            return null
        }

        for (uri in uris) {
            val payload = buildPayloadFromUri(uri)
            if (payload != null) {
                return payload
            }
        }
        return null
    }

    private fun buildPayloadFromUri(uri: Uri?): Map<String, Any>? {
        uri ?: return null
        val bytes = try {
            contentResolver.openInputStream(uri)?.use { it.readBytes() }
        } catch (_: Exception) {
            null
        } ?: return null

        if (bytes.isEmpty()) {
            return null
        }

        val label = resolvePayloadLabel(uri)
        return mapOf(
            "bytes" to bytes,
            "label" to label
        )
    }

    private fun resolvePayloadLabel(uri: Uri): String {
        val displayName = queryDisplayName(uri)?.trim()
        if (!displayName.isNullOrEmpty()) {
            return displayName
        }

        val lastSegment = uri.lastPathSegment?.substringAfterLast('/')?.trim()
        if (!lastSegment.isNullOrEmpty()) {
            return lastSegment
        }

        return DEFAULT_PAYLOAD_LABEL
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
            val cursor: Cursor? = contentResolver.query(uri, projection, null, null, null)
            cursor?.use {
                if (!it.moveToFirst()) {
                    return null
                }
                val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) it.getString(index) else null
            }
        } catch (_: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    private fun readSharedUri(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    @Suppress("DEPRECATION")
    private fun readSharedUriList(intent: Intent): List<Uri> {
        val list = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        }

        return list ?: emptyList()
    }
}
