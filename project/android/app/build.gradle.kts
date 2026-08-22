import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release signing (Publishing Readiness Audit, Phase 7) -----------------------------------
// Loads real upload-key credentials from android/key.properties, which is NOT committed to git
// (already covered by android/.gitignore). If that file doesn't exist yet — e.g. on a fresh
// clone, or before you've generated your production keystore — this falls back to the debug
// keystore exactly as before, so `flutter run --release` keeps working locally without secrets.
// See doc/Audit/07_Platform_Build_Readiness.md for the exact keytool command to generate your
// real upload keystore and the key.properties file format.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.streamer_app"
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
        // TODO(you — see doc/Audit/07_Platform_Build_Readiness.md §1): pick your permanent,
        // reverse-DNS application ID before your first release build (e.g.
        // "sa.com.yourcompany.streamerapp"). This CANNOT be changed after your first Play Store
        // submission without publishing as an entirely new app listing. Left as-is for now
        // since this is your decision to make, not mine.
        applicationId = "com.example.streamer_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { rootProject.file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Uses your real upload keystore once key.properties exists; safely falls back to
            // the debug keystore until then (was previously hardcoded to debug unconditionally —
            // see doc/Audit/01_Security_Data_Protection_Audit.md, VULN-BUILD-01).
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 code shrinking + resource shrinking for release builds (was previously
            // disabled entirely — smaller, harder-to-reverse-engineer release binaries).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // v0.7 Checkpoint 2 -- direct platform-channel wrapper against RootEncoder
    // (recommended by the Checkpoint 1 spike over the rtmp_streaming pub.dev
    // wrapper, which doesn't build on this project's toolchain -- see
    // doc/Roadmap/v0.7_Mobile_Streaming_Android.md and commit 16cd9d3).
    // Pinned to 2.7.5: the spike confirmed this is the newest release that
    // still compiles clean against compileSdk 36 / AGP 8.11.1.
    implementation("com.github.pedroSG94.RootEncoder:library:2.7.5")
    implementation("androidx.core:core-ktx:1.13.1")
}
