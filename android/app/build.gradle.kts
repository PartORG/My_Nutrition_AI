import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.partorg.myfoodmind"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs desugaring for scheduled notifications.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.partorg.myfoodmind"
        minSdk = 29 // Android 10, see docs/PLAN.md
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Upload key for Play (Play App Signing holds the app key). android/key.properties
    // is git-ignored; without it release builds use the debug key (local testing only).
    val keyProps = Properties().apply {
        rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
    }
    signingConfigs {
        if (keyProps.isNotEmpty()) {
            create("upload") {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    // arm64 only (PLAN). Plugins ship other ABIs' .so files (tflite, zxing, ...) while
    // Flutter itself is arm64 only here: Play would then offer the app to 32-bit and
    // x86_64 phones, where it crashes at start. ndk.abiFilters doesn't reach the bundle.
    packaging {
        jniLibs { excludes += listOf("lib/armeabi-v7a/**", "lib/armeabi/**", "lib/x86/**", "lib/x86_64/**") }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
