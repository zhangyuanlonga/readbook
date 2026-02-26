package com.example.flutter_appread

import android.content.ComponentName
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.content.pm.PackageManager
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        private const val SOURCE_IMPORT_CHANNEL_NAME = "com.example.flutter_appread/source_import_intent"
        private const val METHOD_GET_INITIAL_IMPORT_PAYLOAD = "getInitialImportPayload"
        private const val METHOD_ON_IMPORT_PAYLOAD = "onImportPayload"
        private const val DEFAULT_PAYLOAD_LABEL = "外部书源"

        private const val APP_ICON_CHANNEL_NAME = "com.example.flutter_appread/app_icon"
        private const val METHOD_IS_SUPPORTED = "isSupported"
        private const val METHOD_GET_CURRENT_ICON = "getCurrentIcon"
        private const val METHOD_SET_APP_ICON = "setAppIcon"
        private const val ICON_KEY_DEFAULT = "default"
        private const val ICON_KEY_ALT = "alt"
        private const val DEFAULT_ALIAS_CLASS = ".MainActivityDefault"
        private const val ALT_ALIAS_CLASS = ".MainActivityAlt"
    }

    private var sourceImportMethodChannel: MethodChannel? = null
    private var appIconMethodChannel: MethodChannel? = null
    private var pendingInitialPayload: Map<String, Any>? = null

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

        if (pendingInitialPayload == null) {
            pendingInitialPayload = extractPayloadFromIntent(intent)
        }

        appIconMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_ICON_CHANNEL_NAME
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    METHOD_IS_SUPPORTED -> result.success(true)
                    METHOD_GET_CURRENT_ICON -> result.success(resolveCurrentIconKey())
                    METHOD_SET_APP_ICON -> {
                        val icon = (call.arguments as? Map<*, *>)?.get("icon") as? String
                        if (icon.isNullOrEmpty()) {
                            result.error("INVALID_ARGUMENT", "Missing icon argument.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            setAppIcon(icon)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("SET_ICON_FAILED", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
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
        appIconMethodChannel?.setMethodCallHandler(null)
        appIconMethodChannel = null
        super.onDestroy()
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

    private fun setAppIcon(iconKey: String) {
        val normalized = if (iconKey == ICON_KEY_ALT) ICON_KEY_ALT else ICON_KEY_DEFAULT
        val packageName = packageName
        val defaultAlias = ComponentName(packageName, "$packageName$DEFAULT_ALIAS_CLASS")
        val altAlias = ComponentName(packageName, "$packageName$ALT_ALIAS_CLASS")
        val packageManager = packageManager

        when (normalized) {
            ICON_KEY_ALT -> {
                setAliasEnabled(packageManager, altAlias, true)
                setAliasEnabled(packageManager, defaultAlias, false)
            }

            else -> {
                setAliasEnabled(packageManager, defaultAlias, true)
                setAliasEnabled(packageManager, altAlias, false)
            }
        }
    }

    private fun resolveCurrentIconKey(): String {
        val packageName = packageName
        val defaultAlias = ComponentName(packageName, "$packageName$DEFAULT_ALIAS_CLASS")
        val altAlias = ComponentName(packageName, "$packageName$ALT_ALIAS_CLASS")
        val packageManager = packageManager
        val defaultEnabled = isAliasEnabled(packageManager, defaultAlias, defaultEnabled = true)
        val altEnabled = isAliasEnabled(packageManager, altAlias, defaultEnabled = false)

        if (altEnabled && !defaultEnabled) {
            return ICON_KEY_ALT
        }
        return ICON_KEY_DEFAULT
    }

    private fun isAliasEnabled(
        packageManager: PackageManager,
        componentName: ComponentName,
        defaultEnabled: Boolean
    ): Boolean {
        return when (packageManager.getComponentEnabledSetting(componentName)) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED -> false
            else -> defaultEnabled
        }
    }

    private fun setAliasEnabled(
        packageManager: PackageManager,
        componentName: ComponentName,
        enabled: Boolean
    ) {
        val newState = if (enabled) {
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
        } else {
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }
        if (packageManager.getComponentEnabledSetting(componentName) == newState) {
            return
        }
        packageManager.setComponentEnabledSetting(
            componentName,
            newState,
            PackageManager.DONT_KILL_APP
        )
    }
}
