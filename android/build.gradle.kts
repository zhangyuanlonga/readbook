import org.jetbrains.kotlin.gradle.dsl.KotlinVersion
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

val flutterStorageBaseUrl = (System.getenv("FLUTTER_STORAGE_BASE_URL") ?: "https://storage.flutter-io.cn")
    .trimEnd('/')

allprojects {
    repositories {
        mavenLocal()  // 加这一行
        maven("${flutterStorageBaseUrl}/download.flutter.io") {
            content {
                includeGroup("io.flutter")
            }
        }
        maven("https://repo.huaweicloud.com/repository/maven/")
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/central")
        maven("https://maven.aliyun.com/repository/public")
        // 把 google() 和 mavenCentral() 放到最后，并且加上完整地址
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    tasks.withType<KotlinCompile>().configureEach {
        compilerOptions {
            // 统一覆盖旧插件写死的 Kotlin 1.6 编译语言版本，避免 Kotlin 2.x 工具链直接拒绝 Android 构建。
            languageVersion.set(KotlinVersion.KOTLIN_1_8)
            apiVersion.set(KotlinVersion.KOTLIN_1_8)
        }
    }
}
subprojects {
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            when ("${requested.group}:${requested.name}") {
                "androidx.test:runner" -> {
                    if (requested.version?.contains("+") == true) {
                        useVersion("1.2.0")
                        because("Flutter integration_test declares 1.2+; pin it to avoid remote metadata lookup during app builds.")
                    }
                }
                "androidx.test:rules" -> {
                    if (requested.version?.contains("+") == true) {
                        useVersion("1.2.0")
                        because("Flutter integration_test declares 1.2+; pin it to avoid remote metadata lookup during app builds.")
                    }
                }
                "androidx.test.espresso:espresso-core" -> {
                    if (requested.version?.contains("+") == true) {
                        useVersion("3.3.0")
                        because("Flutter integration_test declares 3.3+; pin it to avoid remote metadata lookup during app builds.")
                    }
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
