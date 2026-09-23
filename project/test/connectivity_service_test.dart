import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/services/connectivity_service.dart';

void main() {
  final localEndpoint = Uri.parse('http://127.0.0.1:1/rest/v1/');

  test('offline skips the backend probe', () async {
    var probes = 0;
    final service = ConnectivityService(
      endpoint: localEndpoint,
      checkConnectivity: () async => [ConnectivityResult.none],
      connectivityChanges: const Stream.empty(),
      probe: (_) async {
        probes++;
        return true;
      },
    );
    expect(await service.checkNow(), NetworkStatus.offline);
    expect(probes, 0);
  });

  test('attached transport is degraded until the backend responds', () async {
    var reachable = false;
    final service = ConnectivityService(
      endpoint: localEndpoint,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
      probe: (uri) async {
        expect(uri, localEndpoint);
        return reachable;
      },
    );
    expect(await service.checkNow(), NetworkStatus.degraded);
    reachable = true;
    expect(await service.checkNow(), NetworkStatus.online);
  });

  test('backend probe times out as degraded', () async {
    final service = ConnectivityService(
      endpoint: localEndpoint,
      checkConnectivity: () async => [ConnectivityResult.mobile],
      connectivityChanges: const Stream.empty(),
      probeTimeout: const Duration(milliseconds: 5),
      probe: (_) => Completer<bool>().future,
    );
    expect(await service.checkNow(), NetworkStatus.degraded);
  });

  test('rapid transport changes emit only the last debounced state', () async {
    final changes = StreamController<List<ConnectivityResult>>();
    final service = ConnectivityService(
      endpoint: localEndpoint,
      checkConnectivity: () async => [ConnectivityResult.wifi],
      connectivityChanges: changes.stream,
      debounce: const Duration(milliseconds: 15),
      probe: (_) async => true,
    );
    final emitted = <NetworkStatus>[];
    final sub = service.onStatusChange.listen(emitted.add);
    changes.add([ConnectivityResult.none]);
    changes.add([ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(emitted, [NetworkStatus.online]);
    await sub.cancel();
    await changes.close();
  });
}
