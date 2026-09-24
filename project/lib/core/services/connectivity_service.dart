import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/supabase_config.dart';

enum NetworkStatus { online, degraded, offline }

/// Transport attachment and a bounded request to this app's backend.
/// A response of any HTTP status proves reachability; a timeout does not.
class ConnectivityService {
  ConnectivityService({
    Connectivity? connectivity,
    Future<List<ConnectivityResult>> Function()? checkConnectivity,
    Stream<List<ConnectivityResult>>? connectivityChanges,
    Future<bool> Function(Uri)? probe,
    Uri? endpoint,
    this.debounce = const Duration(milliseconds: 400),
    this.probeTimeout = const Duration(seconds: 2),
    this.pollInterval = const Duration(seconds: 15),
    Timer Function(Duration, void Function())? createTimer,
  })  : _checkConnectivity = checkConnectivity ??
            (connectivity ?? Connectivity()).checkConnectivity,
        _connectivityChanges = connectivityChanges ??
            (connectivity ?? Connectivity()).onConnectivityChanged,
        _probe = probe,
        _createTimer =
            createTimer ?? ((duration, callback) => Timer(duration, callback)),
        endpoint = endpoint ??
            (SupabaseConfig.isConfigured
                ? Uri.tryParse(SupabaseConfig.url)?.resolve('/rest/v1/')
                : null);

  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final Future<bool> Function(Uri)? _probe;
  final Uri? endpoint;
  final Duration debounce;
  final Duration probeTimeout;
  final Duration pollInterval;
  final Timer Function(Duration, void Function()) _createTimer;
  int _revision = 0;
  bool _foreground = true;
  void Function()? _resumeMonitoring;

  /// Changes to this value invalidate older manual and monitored probes.
  int get revision => _revision;

  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    ++_revision;
    _resumeMonitoring?.call();
  }

  Future<NetworkStatus> checkNow() async {
    ++_revision;
    try {
      return await _classify(await _checkConnectivity());
    } catch (e) {
      debugPrint('ConnectivityService.checkNow failed: $e');
      return NetworkStatus.degraded;
    }
  }

  Future<NetworkStatus> _classify(List<ConnectivityResult> results) async {
    if (!results.any((r) => r != ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    final target = endpoint;
    if (target == null) return NetworkStatus.degraded;
    try {
      final reachable = await (_probe?.call(target) ?? _httpProbe(target))
          .timeout(probeTimeout);
      return reachable ? NetworkStatus.online : NetworkStatus.degraded;
    } catch (_) {
      return NetworkStatus.degraded;
    }
  }

  Future<bool> _httpProbe(Uri target) async {
    final client = http.Client();
    try {
      await client.get(target).timeout(probeTimeout);
      return true;
    } finally {
      client.close();
    }
  }

  /// Debounce transport changes, then probe the latest network state.
  Stream<NetworkStatus> get onStatusChange {
    late StreamController<NetworkStatus> controller;
    StreamSubscription<List<ConnectivityResult>>? subscription;
    Timer? debounceTimer;
    Timer? pollTimer;
    var active = true;
    Future<void> sample([List<ConnectivityResult>? known]) async {
      if (!_foreground || !active) return;
      final current = ++_revision;
      NetworkStatus status;
      try {
        status = await _classify(known ?? await _checkConnectivity());
      } catch (_) {
        status = NetworkStatus.degraded;
      }
      if (!controller.isClosed &&
          active &&
          _foreground &&
          current == _revision) {
        controller.add(status);
      }
      if (active && _foreground) {
        pollTimer?.cancel();
        pollTimer = _createTimer(pollInterval, () => unawaited(sample()));
      }
    }

    controller = StreamController<NetworkStatus>(
      onListen: () {
        _resumeMonitoring = () {
          debounceTimer?.cancel();
          pollTimer?.cancel();
          if (_foreground) unawaited(sample());
        };
        pollTimer = _createTimer(pollInterval, () => unawaited(sample()));
        subscription = _connectivityChanges.listen((results) {
          ++_revision;
          debounceTimer?.cancel();
          pollTimer?.cancel();
          if (_foreground) {
            debounceTimer =
                _createTimer(debounce, () => unawaited(sample(results)));
          }
        }, onError: controller.addError);
      },
      onCancel: () async {
        active = false;
        ++_revision;
        _resumeMonitoring = null;
        debounceTimer?.cancel();
        pollTimer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
