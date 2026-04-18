package com.jiangyan.selune

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent
import java.io.File
import java.io.FileOutputStream
import java.util.Locale

class MainActivity : FlutterActivity() {
    private companion object {
        private const val SOURCE_IMPORT_CHANNEL_NAME = "com.jiangyan.selune/source_import_intent"
        private const val METHOD_GET_INITIAL_IMPORT_PAYLOAD = "getInitialImportPayload"
        private const val METHOD_ON_IMPORT_PAYLOAD = "onImportPayload"
        private const val METHOD_CACHE_EXTERNAL_FILE_FROM_URI = "cacheExternalFileFromUri"
        private const val READER_VOLUME_KEY_CHANNEL_NAME = "com.jiangyan.selune/reader_volume_keys"
        private const val READER_VOLUME_KEY_EVENT_CHANNEL_NAME = "com.jiangyan.selune/reader_volume_keys/events"
        private const val METHOD_SET_INTERCEPT_VOLUME_KEYS = "setInterceptVolumeKeys"
        private const val DEFAULT_PAYLOAD_LABEL = "外部导入"
        private const val PAYLOAD_TYPE_LOCAL_BOOK = "localBook"
        private const val PAYLOAD_TYPE_SCRIPT_SOURCE = "scriptSource"
        private const val PAYLOAD_TYPE_ADVANCED_THEME = "advancedTheme"
    }

    private var sourceImportMethodChannel: MethodChannel? = null
    private var readerVolumeKeyMethodChannel: MethodChannel? = null
    private var readerVolumeKeyEventChannel: EventChannel? = null
    private var readerVolumeKeyEventSink: EventChannel.EventSink? = null
    private var pendingInitialPayload: Map<String, Any>? = null
    private var interceptReaderVolumeKeys = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = android.graphics.Color.TRANSPARENT
        window.navigationBarColor = android.graphics.Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes.layoutInDisplayCutoutMode =
                WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
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
                    METHOD_CACHE_EXTERNAL_FILE_FROM_URI -> {
                        result.success(cacheExternalFileFromCall(call.arguments))
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
            Intent.ACTION_VIEW -> buildPayloadFromUri(intent.data, intent.type)
            Intent.ACTION_SEND -> buildPayloadFromSendIntent(intent)
            Intent.ACTION_SEND_MULTIPLE -> buildPayloadFromSendMultipleIntent(intent)
            else -> null
        }
    }

    private fun buildPayloadFromSendIntent(intent: Intent): Map<String, Any>? {
        val sharedUri = readSharedUri(intent)
        if (sharedUri != null) {
            return buildPayloadFromUri(sharedUri, intent.type)
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
        if (text.isNullOrEmpty()) {
            return null
        }

        val maybeUri = runCatching { Uri.parse(text) }.getOrNull()
        val uriScheme = maybeUri?.scheme?.lowercase(Locale.ROOT)
        if (maybeUri != null && (uriScheme == "content" || uriScheme == "file")) {
            val fromTextUri = buildPayloadFromUri(maybeUri, intent.type)
            if (fromTextUri != null) {
                return fromTextUri
            }
        }

        return null
    }

    private fun buildPayloadFromSendMultipleIntent(intent: Intent): Map<String, Any>? {
        val uris = readSharedUriList(intent)
        if (uris.isEmpty()) {
            return null
        }

        for (uri in uris) {
            val payload = buildPayloadFromUri(uri, intent.type)
            if (payload != null) {
                return payload
            }
        }
        return null
    }

    private fun buildPayloadFromUri(uri: Uri?, mimeTypeHint: String? = null): Map<String, Any>? {
        uri ?: return null

        val label = resolvePayloadLabel(uri)
        val mimeType = resolveMimeType(uri, mimeTypeHint)
        return when (classifyPayloadType(uri, label, mimeType)) {
            PAYLOAD_TYPE_LOCAL_BOOK -> mapOf(
                "type" to PAYLOAD_TYPE_LOCAL_BOOK,
                "uri" to uri.toString(),
                "label" to label,
                "mimeType" to (mimeType ?: ""),
            )
            PAYLOAD_TYPE_ADVANCED_THEME -> mapOf(
                "type" to PAYLOAD_TYPE_ADVANCED_THEME,
                "uri" to uri.toString(),
                "label" to label,
                "mimeType" to (mimeType ?: ""),
            )
            PAYLOAD_TYPE_SCRIPT_SOURCE -> mapOf(
                "type" to PAYLOAD_TYPE_SCRIPT_SOURCE,
                "uri" to uri.toString(),
                "label" to label,
                "mimeType" to (mimeType ?: ""),
            )
            else -> null
        }
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

    private fun resolveMimeType(uri: Uri, mimeTypeHint: String?): String? {
        val normalizedHint = mimeTypeHint?.trim()?.takeUnless { it.isEmpty() }
        if (normalizedHint != null) {
            return normalizedHint
        }
        return try {
            contentResolver.getType(uri)?.trim()?.takeUnless { it.isEmpty() }
        } catch (_: Exception) {
            null
        }
    }

    private fun classifyPayloadType(uri: Uri, label: String, mimeType: String?): String? {
        val extension = label.substringAfterLast('.', "").lowercase(Locale.ROOT)
        val normalizedMimeType = mimeType?.lowercase(Locale.ROOT)

        if (
            extension == "js" ||
            extension == "mjs" ||
            normalizedMimeType == "application/javascript" ||
            normalizedMimeType == "text/javascript" ||
            normalizedMimeType == "application/x-javascript"
        ) {
            return PAYLOAD_TYPE_SCRIPT_SOURCE
        }
        if (extension == "json" || normalizedMimeType == "application/json") {
            return PAYLOAD_TYPE_ADVANCED_THEME
        }
        if (extension == "epub" || normalizedMimeType == "application/epub+zip") {
            return PAYLOAD_TYPE_LOCAL_BOOK
        }
        if (extension == "txt" || normalizedMimeType == "text/plain" || normalizedMimeType == "application/octet-stream") {
            return PAYLOAD_TYPE_LOCAL_BOOK
        }
        return null
    }

    private fun cacheExternalFileFromCall(arguments: Any?): Map<String, Any>? {
        val args = arguments as? Map<*, *> ?: return null
        val rawUri = args["uri"]?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: return null
        val uri = Uri.parse(rawUri)
        val type = args["type"]?.toString()?.trim()
        val rawLabel = args["label"]?.toString()?.trim()
        val label = if (rawLabel.isNullOrEmpty()) resolvePayloadLabel(uri) else rawLabel
        val mimeType = args["mimeType"]?.toString()?.trim().takeUnless { it.isNullOrEmpty() } ?: resolveMimeType(uri, null)
        val extension = resolveExternalImportExtension(type, label, mimeType)
        if (extension == null) {
            return null
        }

        val input = try {
            contentResolver.openInputStream(uri)
        } catch (_: Exception) {
            null
        } ?: return null

        val safeBaseName = sanitizeFileToken(label.substringBeforeLast('.', label))
        val cacheDir = File(cacheDir, "external_imports")
        if (!cacheDir.exists()) {
            cacheDir.mkdirs()
        }
        val outputFile = File(
            cacheDir,
            "${System.currentTimeMillis()}_${safeBaseName}$extension"
        )

        input.use { source ->
            FileOutputStream(outputFile).use { output ->
                source.copyTo(output)
                output.flush()
            }
        }

        return mapOf(
            "path" to outputFile.absolutePath,
            "label" to if (label.lowercase(Locale.ROOT).endsWith(extension)) label else "$label$extension",
            "mimeType" to (mimeType ?: "")
        )
    }

    private fun resolveExternalImportExtension(type: String?, label: String, mimeType: String?): String? {
        return when (type?.trim()) {
            PAYLOAD_TYPE_SCRIPT_SOURCE -> resolveScriptSourceExtension(label, mimeType)
            PAYLOAD_TYPE_LOCAL_BOOK -> resolveLocalBookExtension(label, mimeType)
            PAYLOAD_TYPE_ADVANCED_THEME -> resolveAdvancedThemeExtension(label, mimeType)
            else -> resolveScriptSourceExtension(label, mimeType)
                ?: resolveAdvancedThemeExtension(label, mimeType)
                ?: resolveLocalBookExtension(label, mimeType)
        }
    }

    private fun resolveLocalBookExtension(label: String, mimeType: String?): String? {
        val lowerLabel = label.lowercase(Locale.ROOT)
        return when {
            lowerLabel.endsWith(".txt") -> ".txt"
            lowerLabel.endsWith(".epub") -> ".epub"
            mimeType.equals("application/epub+zip", ignoreCase = true) -> ".epub"
            mimeType.equals("text/plain", ignoreCase = true) ||
                mimeType.equals("application/octet-stream", ignoreCase = true) -> ".txt"
            else -> null
        }
    }

    private fun resolveScriptSourceExtension(label: String, mimeType: String?): String? {
        val lowerLabel = label.lowercase(Locale.ROOT)
        return when {
            lowerLabel.endsWith(".mjs") -> ".mjs"
            lowerLabel.endsWith(".js") -> ".js"
            lowerLabel.endsWith(".txt") -> ".txt"
            mimeType.equals("application/javascript", ignoreCase = true) ||
                mimeType.equals("text/javascript", ignoreCase = true) ||
                mimeType.equals("application/x-javascript", ignoreCase = true) -> ".js"
            else -> null
        }
    }

    private fun resolveAdvancedThemeExtension(label: String, mimeType: String?): String? {
        val lowerLabel = label.lowercase(Locale.ROOT)
        return when {
            lowerLabel.endsWith(".json") -> ".json"
            mimeType.equals("application/json", ignoreCase = true) -> ".json"
            else -> null
        }
    }

    private fun sanitizeFileToken(value: String): String {
        val sanitized = value
            .trim()
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .replace(Regex("\\s+"), "_")
        return if (sanitized.isEmpty()) "external_book" else sanitized
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
