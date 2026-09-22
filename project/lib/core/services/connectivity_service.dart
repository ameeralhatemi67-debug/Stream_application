import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around `connectivity_plus` so the rest of the app depends on
/// a plain `bool` online/offline signal, not the plugin's own result enum.
///
/// This reports *device network reachability* (Wi-Fi/mobile data attached),
/// not proof that a specific backend request will succeed -- it is
/// deliberately conservative: a device can report "connected" to a Wi-Fi
/// network with no real internet behind it. UI-08 treats this as the trigger
/// to switch to the offline map experience and to retry when it flips back;
/// individual network calls still handle their own failures independently.
class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _isOnline(results);
    } catch (e) {
      debugPrint('ConnectivityService.checkNow failed: $e');
      // Fail open: an unreadable connectivity API must not itself lock the
      // app into a false "offline" state.
      return true;
    }
  }

  Stream<bool> get onStatusChange {
    try {
      return _connectivity.onConnectivityChanged.map(_isOnline);
    } catch (e) {
      debugPrint('ConnectivityService.onStatusChange failed: $e');
      return const Stream.empty();
    }
  }
}
