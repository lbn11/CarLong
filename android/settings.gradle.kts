pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // 版本必须与 Flutter SDK 模板一致（Flutter 3.41.6 → AGP 8.11.1 / Kotlin 2.2.20 / Gradle 8.14）。
    // 曾被抬到 AGP 9.0.1 + Kotlin 2.3.20 + Gradle 9.1：google_mobile_ads 5.3.1 的
    // `configurations.all` 在 Gradle 9 上直接报 unknown property，Android 端始终无法构建。
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
