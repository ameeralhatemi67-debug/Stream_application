import 'package:flutter/foundation.dart';

/// Where this build of the phone app is installed from (ADR-017), chosen when
/// a release is built: `--dart-define=DISTRIBUTION=apk` for the APK downloaded
/// from the website, `--dart-define=DISTRIBUTION=play` for Google Play. The
/// Android release build refuses to start without one of the two
/// (android/app/build.gradle.kts). Debug runs, tests and the web have none,
/// so they never look for updates.
enum AppDistribution {
  none,

  /// The APK from the website: the app tells people when a newer one is
  /// published and opens its download link.
  apk,

  /// Google Play updates the app. Play's policy forbids an app from updating
  /// itself any other way, so this build may only open its Play listing.
  play;

  static const _defined = String.fromEnvironment('DISTRIBUTION');

  static AppDistribution get current => kIsWeb ? none : parse(_defined);

  static AppDistribution parse(String value) => switch (value) {
        'apk' => apk,
        'play' => play,
        _ => none,
      };

  /// The `app_releases.channel` this build reads, or null when it reads none.
  String? get channel => this == none ? null : name;
}
