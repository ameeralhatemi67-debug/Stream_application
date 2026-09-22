import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// --- Release signing (Publishing Readiness Audit, Phase 7; gate G8) --------------------------
// Loads real upload-key credentials from android/key.properties, which is NOT committed to git
// (already covered by android/.gitignore). See doc/Audit/07_Platform_Build_Readiness.md for the
// keytool command that generates the upload keystore and the key.properties format.
//
// Fails closed: a release build without key.properties now stops with an explanation instead of
// quietly signing with the debug keystore. A debug-signed artifact is indistinguishable from a
// real one by eye, Play rejects it after the upload, and the previous fallback made it possible
// to ship one by accident. Debug and profile builds are untouched, so `flutter run` still works
// on a fresh clone with no secrets.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "sa.hadayah.streamer_app"
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
        // The owner's APP_ID from brief/05_DECISIONS.md, mirrored in
        // project/lib/core/config/app_identity.dart and in the OAuth deep-link scheme
        // (AndroidManifest.xml and SupabaseConfig.oauthRedirectUrl must agree with it).
        //
        // This CANNOT be changed after the first Play Store submission without publishing as
        // an entirely new listing, so it is the owner's value verbatim and is not to be
        // "tidied" (doc/Audit/07_Platform_Build_Readiness.md §1).
        applicationId = "sa.hadayah.streamer_app"
        minSdk = flutter.minSdkVersion
        // Follows the Flutter SDK, which is 36 (Android 16) on the pinned toolchain.
        // Google Play has required API 36 for new apps and updates since 31 August 2026:
        // https://developer.android.com/google/play/requirements/target-sdk
        // The check below stops a Flutter downgrade from silently dropping under that floor.
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
            // No debug fallback: without key.properties the release build fails rather than
            // producing a debug-signed artifact (VULN-BUILD-01, gate G8).
            signingConfig = signingConfigs.findByName("release")

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

// Google Play's target API floor, checked rather than assumed. Verified 2026-09-22 against
// https://developer.android.com/google/play/requirements/target-sdk (API 36 for new apps and
// updates from 31 August 2026).
val playTargetSdkFloor = 36
if (flutter.targetSdkVersion < playTargetSdkFloor) {
    throw GradleException(
        "targetSdk is ${flutter.targetSdkVersion}, below Google Play's floor of " +
            "$playTargetSdkFloor. Upgrade the Flutter SDK, or set targetSdk explicitly " +
            "and re-check the current requirement before releasing."
    )
}

// Refuses a release assembly that has no upload keystore, at configuration time, with the
// instructions rather than a Gradle null-pointer.
gradle.taskGraph.whenReady {
    val assemblingRelease = allTasks.any { task ->
        task.project == project &&
            (task.name.contains("Release") &&
                (task.name.startsWith("assemble") || task.name.startsWith("bundle") ||
                    task.name.startsWith("package")))
    }
    if (assemblingRelease && !hasReleaseSigning) {
        throw GradleException(
            "Release signing is not configured: android/key.properties is missing. " +
                "Create the upload keystore and key.properties as described in " +
                "doc/Audit/07_Platform_Build_Readiness.md, then build again. " +
                "Never commit the keystore or key.properties."
        )
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
