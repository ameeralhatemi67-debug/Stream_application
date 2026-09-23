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
  }) : _checkConnectivity =
           checkConnectivity ??
           (connectivity ?? Connectivity()).checkConnectivity,
       _connectivityChanges =
           connectivityChanges ??
           (connectivity ?? Connectivity()).onConnectivityChanged,
       _probe = probe,
       endpoint =
           endpoint ??
           (SupabaseConfig.isConfigured
               ? Uri.tryParse(SupabaseConfig.url)?.resolve('/rest/v1/')
               : null);

  final Future<List<ConnectivityResult>> Function() _checkConnectivity;
  final Stream<List<ConnectivityResult>> _connectivityChanges;
  final Future<bool> Function(Uri)? _probe;
  final Uri? endpoint;
  final Duration debounce;
  final Duration probeTimeout;

  Future<NetworkStatus> checkNow() async {
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
    Timer? timer;
    var generation = 0;
    controller = StreamController<NetworkStatus>(
      onListen: () {
        subscription = _connectivityChanges.listen((results) {
          final current = ++generation;
          timer?.cancel();
          timer = Timer(debounce, () async {
            final status = await _classify(results);
            if (!controller.isClosed && current == generation) {
              controller.add(status);
            }
          });
        }, onError: controller.addError);
      },
      onCancel: () async {
        generation++;
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
