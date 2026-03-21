import org.gradle.api.GradleException
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val isReleaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else if (isReleaseTaskRequested) {
    throw GradleException(
        "Missing android/key.properties for release signing. " +
            "Copy key.properties and the release .jks file from the machine that owns the signing key.",
    )
}

fun sanitizeGeneratedPluginRegistrantForNonTestBuilds() {
    val registrantFile = file("src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java")
    if (!registrantFile.exists()) {
        return
    }

    val integrationTestBlock = Regex(
        """\s*try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\s*\}\s*""",
        setOf(RegexOption.DOT_MATCHES_ALL),
    )
    val original = registrantFile.readText()
    val sanitized = original.replace(integrationTestBlock, "\n")
    if (sanitized != original) {
        registrantFile.writeText(sanitized)
    }
}

android {
    namespace = "com.jiangyan.shuxiangread"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jiangyan.shuxiangread"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

afterEvaluate {
    listOf("Release", "Profile").forEach { variant ->
        tasks.named("compile${variant}JavaWithJavac").configure {
            // Work around Flutter incorrectly generating integration_test registration for non-test builds.
            doFirst {
                sanitizeGeneratedPluginRegistrantForNonTestBuilds()
            }
        }
    }
}
