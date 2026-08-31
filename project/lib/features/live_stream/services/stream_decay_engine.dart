import 'dart:async';
import 'package:flutter/foundation.dart';

/// Monitors live broadcast activity and automatically decays (ends) ghost streams
/// if no broadcaster heartbeat, audio signal, or RTMP frame is received within
/// the inactivity threshold window.
class StreamDecayEngine {
  static const Duration kDefaultInactivityThreshold = Duration(seconds: 180);
  static const Duration kCheckInterval = Duration(seconds: 15);

  final Duration inactivityThreshold;
  final Duration checkInterval;
  final VoidCallback? onStreamDecayed;

  Timer? _monitorTimer;
  DateTime? _lastHeartbeatAt;
  bool _isBroadcasting = false;
  String? _activeStreamId;

  StreamDecayEngine({
    this.inactivityThreshold = kDefaultInactivityThreshold,
    this.checkInterval = kCheckInterval,
    this.onStreamDecayed,
  });

  bool get isBroadcasting => _isBroadcasting;
  DateTime? get lastHeartbeatAt => _lastHeartbeatAt;
  String? get activeStreamId => _activeStreamId;

  /// Starts the decay monitoring loop for a new live broadcast.
  void startMonitoring({required String streamId}) {
    _activeStreamId = streamId;
    _isBroadcasting = true;
    _lastHeartbeatAt = DateTime.now();

    _monitorTimer?.cancel();
    _monitorTimer = Timer.periodic(checkInterval, (_) => _checkInactivity());
    debugPrint('[StreamDecayEngine] Monitoring started for stream: $streamId');
  }

  /// Records a keep-alive heartbeat or data packet from the broadcast source.
  void recordHeartbeat() {
    if (!_isBroadcasting) return;
    _lastHeartbeatAt = DateTime.now();
  }

  /// Explicitly stops monitoring when the streamer ends the broadcast normally.
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isBroadcasting = false;
    _activeStreamId = null;
    _lastHeartbeatAt = null;
    debugPrint('[StreamDecayEngine] Monitoring stopped cleanly.');
  }

  void _checkInactivity() {
    if (!_isBroadcasting || _lastHeartbeatAt == null) return;

    final elapsed = DateTime.now().difference(_lastHeartbeatAt!);
    if (elapsed >= inactivityThreshold) {
      debugPrint(
          '[StreamDecayEngine] Stream $_activeStreamId decayed after ${elapsed.inSeconds}s of inactivity.');
      stopMonitoring();
      onStreamDecayed?.call();
    }
  }

  void dispose() {
    stopMonitoring();
  }
}
