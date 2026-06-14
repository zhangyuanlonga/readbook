package com.jiangyan.selune

import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.view.KeyEvent
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.InputStream
import java.util.Locale

private data class ExternalImportSpec(
    val type: String,
    val extensions: Set<String>,
    val mimeTypeToExtension: Map<String, String>,
)

class MainActivity : FlutterActivity() {
    private companion object {
        private const val SOURCE_IMPORT_CHANNEL_NAME = "com.jiangyan.selune/external_import_intent"
        private const val METHOD_GET_INITIAL_IMPORT_PAYLOAD = "getInitialImportPayload"
        private const val METHOD_ON_IMPORT_PAYLOAD = "onImportPayload"
        private const val METHOD_CACHE_EXTERNAL_FILE_FROM_URI = "cacheExternalFileFromUri"
        private const val READER_VOLUME_KEY_CHANNEL_NAME = "com.jiangyan.selune/reader_volume_keys"
        private const val READER_VOLUME_KEY_EVENT_CHANNEL_NAME = "com.jiangyan.selune/reader_volume_keys/events"
        private const val METHOD_SET_INTERCEPT_VOLUME_KEYS = "setInterceptVolumeKeys"
        private const val READER_SCREEN_BRIGHTNESS_CHANNEL_NAME = "com.jiangyan.selune/reader_screen_brightness"
        private const val METHOD_SET_READER_BRIGHTNESS = "setReaderBrightness"
        private const val METHOD_RESET_READER_BRIGHTNESS = "resetReaderBrightness"
        private const val DEFAULT_PAYLOAD_LABEL = "外部导入"
        private const val PAYLOAD_TYPE_LOCAL_BOOK = "localBook"
        private const val PAYLOAD_TYPE_ADVANCED_THEME = "advancedTheme"
        private const val PAYLOAD_TYPE_FONT = "font"
        private val LOCAL_BOOK_IMPORT_SPEC = ExternalImportSpec(
            type = PAYLOAD_TYPE_LOCAL_BOOK,
            extensions = linkedSetOf(
                "txt",
                "epub",
                "md",
                "markdown",
                "html",
                "htm",
                "pdf",
                "mobi",
                "azw",
                "azw3",
            ),
            mimeTypeToExtension = linkedMapOf(
                "application/epub+zip" to "epub",
                "text/markdown" to "md",
                "text/x-markdown" to "md",
                "text/html" to "html",
                "application/pdf" to "pdf",
                "application/x-mobipocket-ebook" to "mobi",
                "application/vnd.amazon.ebook" to "azw",
                "application/vnd.amazon.mobi8-ebook" to "azw3",
                "text/plain" to "txt",
                "application/octet-stream" to "txt",
            )
        )
        private val ADVANCED_THEME_IMPORT_SPEC = ExternalImportSpec(
            type = PAYLOAD_TYPE_ADVANCED_THEME,
            extensions = linkedSetOf("json", "zip", "red", "rgshare"),
            mimeTypeToExtension = linkedMapOf(
                "application/json" to "json",
                "application/zip" to "zip",
                "application/x-zip-compressed" to "zip",
            )
        )
        private val FONT_IMPORT_SPEC = ExternalImportSpec(
            type = PAYLOAD_TYPE_FONT,
            extensions = linkedSetOf("ttf", "otf"),
            mimeTypeToExtension = linkedMapOf(
                "font/ttf" to "ttf",
                "font/otf" to "otf",
                "application/font-sfnt" to "otf",
                "application/x-font-ttf" to "ttf",
                "application/x-font-opentype" to "otf",
            )
        )
        private val EXTERNAL_IMPORT_SPECS = listOf(
            FONT_IMPORT_SPEC,
            ADVANCED_THEME_IMPORT_SPEC,
            LOCAL_BOOK_IMPORT_SPEC,
        )
    }

    private var sourceImportMethodChannel: MethodChannel? = null
    private var readerVolumeKeyMethodChannel: MethodChannel? = null
    private var readerVolumeKeyEventChannel: EventChannel? = null
    private var readerVolumeKeyEventSink: EventChannel.EventSink? = null
    private var readerScreenBrightnessMethodChannel: MethodChannel? = null
    private var pendingInitialPayload: Any? = null
    private var interceptReaderVolumeKeys = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep the window height stable while IME animates so Flutter does not
        // receive a full-screen viewport resize on every keyboard frame.
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_PAN)
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
                        cacheExternalFileFromCallAsync(call.arguments, result)
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

        readerScreenBrightnessMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            READER_SCREEN_BRIGHTNESS_CHANNEL_NAME
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_SET_READER_BRIGHTNESS -> {
                        val brightness = (call.arguments as? Number)?.toFloat()
                        if (brightness == null) {
                            result.success(null)
                        } else {
                            applyReaderBrightness(brightness)
                            result.success(null)
                        }
                    }

                    METHOD_RESET_READER_BRIGHTNESS -> {
                        resetReaderBrightness()
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
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
        readerScreenBrightnessMethodChannel?.setMethodCallHandler(null)
        readerScreenBrightnessMethodChannel = null
        interceptReaderVolumeKeys = false
        super.onDestroy()
    }

    private fun applyReaderBrightness(rawBrightness: Float) {
        val params = window.attributes
        params.screenBrightness = rawBrightness.coerceIn(0f, 1f)
        window.attributes = params
    }

    private fun resetReaderBrightness() {
        val params = window.attributes
        params.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
        window.attributes = params
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

    private fun extractPayloadFromIntent(intent: Intent?): Any? {
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

    private fun buildPayloadFromSendMultipleIntent(intent: Intent): List<Map<String, Any>>? {
        val uris = readSharedUriList(intent)
        if (uris.isEmpty()) {
            return null
        }

        val payloads = mutableListOf<Map<String, Any>>()
        val seenUris = mutableSetOf<String>()
        for (uri in uris) {
            val uriKey = uri.toString()
            if (!seenUris.add(uriKey)) {
                continue
            }
            val payload = buildPayloadFromUri(uri, intent.type)
            if (payload != null) {
                payloads.add(payload)
            }
        }
        return payloads.takeIf { it.isNotEmpty() }
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
            PAYLOAD_TYPE_FONT -> mapOf(
                "type" to PAYLOAD_TYPE_FONT,
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
        val extensionCandidates = sequenceOf(
            normalizedExtension(label),
            normalizedExtension(uri.lastPathSegment.orEmpty()),
        ).filter { it.isNotEmpty() }.toSet()
        val normalizedMimeType = mimeType?.lowercase(Locale.ROOT)?.trim()

        for (spec in EXTERNAL_IMPORT_SPECS) {
            if (extensionCandidates.any(spec.extensions::contains)) {
                return spec.type
            }
            if (normalizedMimeType != null && spec.mimeTypeToExtension.containsKey(normalizedMimeType)) {
                return spec.type
            }
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
        val extension = resolveExternalImportExtension(type, uri, label, mimeType)
        if (extension == null) {
            return null
        }

        val input = openExternalInputStream(uri) ?: return null

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

    private fun cacheExternalFileFromCallAsync(arguments: Any?, result: MethodChannel.Result) {
        Thread {
            val cached = try {
                cacheExternalFileFromCall(arguments)
            } catch (_: Exception) {
                null
            }
            mainHandler.post {
                result.success(cached)
            }
        }.start()
    }

    private fun openExternalInputStream(uri: Uri): InputStream? {
        return try {
            when (uri.scheme?.lowercase(Locale.ROOT)) {
                "file" -> {
                    val path = uri.path?.trim().takeUnless { it.isNullOrEmpty() } ?: return null
                    FileInputStream(File(path))
                }
                else -> contentResolver.openInputStream(uri)
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveExternalImportExtension(
        type: String?,
        uri: Uri,
        label: String,
        mimeType: String?
    ): String? {
        val specs = when (type?.trim()) {
            PAYLOAD_TYPE_LOCAL_BOOK -> listOf(LOCAL_BOOK_IMPORT_SPEC)
            PAYLOAD_TYPE_ADVANCED_THEME -> listOf(ADVANCED_THEME_IMPORT_SPEC)
            PAYLOAD_TYPE_FONT -> listOf(FONT_IMPORT_SPEC)
            else -> EXTERNAL_IMPORT_SPECS
        }
        return resolveImportExtension(specs, uri, label, mimeType)
    }

    private fun resolveImportExtension(
        specs: List<ExternalImportSpec>,
        uri: Uri,
        label: String,
        mimeType: String?
    ): String? {
        val extensionCandidates = sequenceOf(
            normalizedExtension(uri.lastPathSegment.orEmpty()),
            normalizedExtension(label),
        ).filter { it.isNotEmpty() }
        for (extension in extensionCandidates) {
            for (spec in specs) {
                if (spec.extensions.contains(extension)) {
                    return ".$extension"
                }
            }
        }

        val normalizedMimeType = mimeType?.lowercase(Locale.ROOT)?.trim()
        if (normalizedMimeType != null) {
            for (spec in specs) {
                val extension = spec.mimeTypeToExtension[normalizedMimeType]
                if (extension != null) {
                    return ".$extension"
                }
            }
        }
        return null
    }

    private fun normalizedExtension(value: String): String {
        val normalized = value.trim().lowercase(Locale.ROOT)
        if (!normalized.contains('.')) {
            return ""
        }
        return normalized.substringAfterLast('.')
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
