# Publishing Readiness Audit, Phase 7 — added alongside enabling R8/minify for release builds.
# Without these keep-rules, R8's aggressive shrinking/obfuscation can strip or rename classes
# that these plugins reach via reflection or platform channels, causing release-only crashes
# that never reproduce in debug builds (a classic "works on `flutter run`, crashes from the
# Play Store build" bug). Start from this conservative list and extend it if a release build
# crashes on startup — the stack trace will name the missing class.

# Flutter engine & plugin registration
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# webview_flutter / webview_flutter_android (used for the YouTube/RTMP embedded players)
-keep class com.google.android.webview.** { *; }
-keep class org.chromium.** { *; }
-dontwarn org.chromium.**

# Flutter's engine carries code for Play Store deferred components (Play Core). This app uses
# none and does not bundle Play Core, so R8 stopped the first real release build (2026-10-26)
# with "Missing class com.google.android.play.core..." for exactly these packages.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# RootEncoder (phone broadcasting, RtmpPublisherBridge). It ships no consumer rules and no
# native code, and R8 finds no missing classes in it; it is kept whole anyway because a
# release-only fault would surface only once a broadcaster is going live.
-keep class com.pedro.** { *; }

# flutter_vlc_player native bindings
-keep class software.solid.fluttervlcplayer.** { *; }
-keep class org.videolan.libvlc.** { *; }
-dontwarn org.videolan.libvlc.**

# google_sign_in / Google Play Services auth
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-dontwarn com.google.android.gms.**

# Gson/JSON reflection safety net (defensive — covers any plugin using reflection-based (de)serialization)
-keepattributes Signature
-keepattributes *Annotation*
-keep class * implements java.io.Serializable { *; }
