import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_distribution.dart';
import '../services/app_release_service.dart';

enum AppUpdateStatus {
  /// Not checked yet, not a release build, or nothing could be read.
  unknown,
  upToDate,

  /// A newer release is published; this version still works.
  available,

  /// This version is below the release's minimum and must be replaced.
  required,
}

/// The installed version and whether a newer one is published (ADR-017).
///
/// Owned by the app root (main.dart) beside [AppProvider]: it checks on start
/// and when the app returns to the foreground, at most every [minInterval].
/// A failed check changes nothing, so being offline never blocks the app.
class AppUpdateController extends ChangeNotifier {
  AppUpdateController({
    required this.distribution,
    Future<AppRelease?> Function(String channel)? fetchLatest,
    Future<({String version, int? build})?> Function()? readInstalled,
    Future<SharedPreferences> Function()? preferences,
    Future<bool> Function(Uri url)? openUrl,
    DateTime Function()? clock,
    this.minInterval = const Duration(hours: 6),
  })  : _fetchLatest = fetchLatest ?? const AppReleaseService().latest,
        _readInstalled = readInstalled ?? _platformVersion,
        _preferences = preferences ?? SharedPreferences.getInstance,
        _openUrl = openUrl ?? _openExternally,
        _clock = clock ?? DateTime.now;

  static const dismissedKey = 'app_update_dismissed_code';

  final AppDistribution distribution;
  final Duration minInterval;
  final Future<AppRelease?> Function(String channel) _fetchLatest;
  final Future<({String version, int? build})?> Function() _readInstalled;
  final Future<SharedPreferences> Function() _preferences;
  final Future<bool> Function(Uri url) _openUrl;
  final DateTime Function() _clock;

  AppUpdateStatus _status = AppUpdateStatus.unknown;
  AppRelease? _release;
  String? _installedVersion;
  int? _installedBuild;
  int? _dismissedCode;
  DateTime? _checkedAt;
  bool _checking = false;
  bool _installedRead = false;

  AppUpdateStatus get status => _status;

  /// The newest published release, when it is newer than this install.
  AppRelease? get release => _release;
  String? get installedVersion => _installedVersion;
  int? get installedBuild => _installedBuild;

  /// The dismissible prompt has not been answered for this release yet.
  bool get promptPending =>
      _status == AppUpdateStatus.available &&
      _release != null &&
      _release!.versionCode != _dismissedCode;

  static Future<({String version, int? build})?> _platformVersion() async {
    final info = await PackageInfo.fromPlatform();
    return (version: info.version, build: int.tryParse(info.buildNumber));
  }

  static Future<bool> _openExternally(Uri url) =>
      launchUrl(url, mode: LaunchMode.externalApplication);

  /// Reads the installed version (also shown in Settings on builds that
  /// never check for updates) and the release this device already dismissed.
  Future<void> loadInstalled() async {
    if (_installedRead) return;
    _installedRead = true;
    try {
      final installed = await _readInstalled();
      _installedVersion = installed?.version;
      _installedBuild = installed?.build;
    } catch (error) {
      debugPrint('Installed version could not be read: $error');
    }
    try {
      _dismissedCode = (await _preferences()).getInt(dismissedKey);
    } catch (error) {
      debugPrint('Dismissed update could not be read: $error');
    }
    notifyListeners();
  }

  /// Asks for the newest published release of this build's channel. Skipped
  /// within [minInterval] of the last answer unless [force] is set.
  Future<void> check({bool force = false}) async {
    final channel = distribution.channel;
    if (channel == null || _checking) return;
    final now = _clock();
    if (!force &&
        _checkedAt != null &&
        now.difference(_checkedAt!) < minInterval) {
      return;
    }
    _checking = true;
    try {
      await loadInstalled();
      final installed = _installedBuild;
      if (installed == null) return;
      final release = await _fetchLatest(channel);
      _checkedAt = now;
      final usable = release != null && release.linkAllowedFor(distribution);
      if (!usable || release.versionCode <= installed) {
        _set(AppUpdateStatus.upToDate, null);
      } else if (installed < release.minSupportedCode) {
        _set(AppUpdateStatus.required, release);
      } else {
        _set(AppUpdateStatus.available, release);
      }
    } catch (error) {
      // Offline or the backend is unreachable: keep what was known.
      debugPrint('Update check failed: $error');
    } finally {
      _checking = false;
    }
  }

  void _set(AppUpdateStatus status, AppRelease? release) {
    if (status == _status && release?.versionCode == _release?.versionCode) {
      return;
    }
    _status = status;
    _release = release;
    notifyListeners();
  }

  /// "Later": this release is not offered again on this device. Settings
  /// still shows it until it is installed.
  Future<void> dismiss() async {
    final code = _release?.versionCode;
    if (code == null || code == _dismissedCode) return;
    _dismissedCode = code;
    notifyListeners();
    try {
      await (await _preferences()).setInt(dismissedKey, code);
    } catch (error) {
      debugPrint('Dismissed update could not be saved: $error');
    }
  }

  /// Opens the release's download page or Play listing outside the app.
  /// False when nothing could be opened.
  Future<bool> openDownload() async {
    final release = _release;
    if (release == null || !release.linkAllowedFor(distribution)) return false;
    try {
      return await _openUrl(release.downloadUrl);
    } catch (error) {
      debugPrint('Update link could not be opened: $error');
      return false;
    }
  }
}
