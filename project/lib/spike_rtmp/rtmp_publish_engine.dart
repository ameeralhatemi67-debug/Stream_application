import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:rtmp_streaming/rtmp_streaming.dart' as rtmp;

/// v0.7 Checkpoint 1 spike -- streaming-engine half of the "keep UI
/// controls decoupled from the streaming engine" skill note. Owns the
/// camera + RTMP publish lifecycle; lib/spike_rtmp/rtmp_spike_screen.dart
/// only ever reads [state]/[stats]/[lastError] and calls these methods --
/// it never touches the underlying rtmp_streaming CameraController directly
/// except to hand it to a CameraPreview. That boundary is deliberately the
/// shape Checkpoint 2's production controller should copy, and the shape
/// v1.1's iOS engine would sit behind too (rtmp_streaming already wraps
/// HaishinKit on iOS behind this same Dart API).
enum RtmpPublishState {
  idle,
  initializingCamera,
  ready,
  connecting,
  live,
  stopped,
  error,
}

class RtmpPublishEngine extends ChangeNotifier {
  rtmp.CameraController? _controller;
  rtmp.CameraController? get cameraController => _controller;

  RtmpPublishState _state = RtmpPublishState.idle;
  RtmpPublishState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  rtmp.StreamStatistics? _stats;
  rtmp.StreamStatistics? get stats => _stats;

  Timer? _statsTimer;
  final rtmp.CameraLensDirection _lens = rtmp.CameraLensDirection.back;

  Future<void> initializeCamera() async {
    _setState(RtmpPublishState.initializingCamera);
    try {
      final cameras = await rtmp.availableCameras();
      final desc = cameras.firstWhere(
        (c) => c.lensDirection == _lens,
        orElse: () => cameras.first,
      );
      final controller = rtmp.CameraController(
        rtmp.ResolutionPreset.medium,
        enableAudio: true,
      );
      await controller.initialize(desc);
      // setRtmpShouldSendPings is what makes StreamStatistics.rttMicros
      // meaningful -- without it the field stays null and there'd be no
      // latency number to report at all.
      await controller.setRtmpShouldSendPings(true);
      _controller = controller;
      _setState(RtmpPublishState.ready);
    } catch (e) {
      _lastError = '$e';
      _setState(RtmpPublishState.error);
      rethrow;
    }
  }

  Future<void> startPublishing(String url) async {
    final controller = _controller;
    if (controller == null) {
      throw StateError('Call initializeCamera() before startPublishing().');
    }
    _setState(RtmpPublishState.connecting);
    try {
      await controller.startVideoStreaming(url, bitrate: 1200 * 1024);
      _setState(RtmpPublishState.live);
      _statsTimer?.cancel();
      _statsTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          _stats = await controller.getStreamStatistics();
          notifyListeners();
        } catch (e) {
          debugPrint('RtmpPublishEngine: stats poll failed: $e');
        }
      });
    } catch (e) {
      _lastError = '$e';
      _setState(RtmpPublishState.error);
      rethrow;
    }
  }

  Future<void> stopPublishing() async {
    _statsTimer?.cancel();
    _statsTimer = null;
    _stats = null;
    try {
      await _controller?.stopVideoStreaming();
    } catch (e) {
      debugPrint('RtmpPublishEngine: stopVideoStreaming failed: $e');
    }
    _setState(RtmpPublishState.stopped);
  }

  void _setState(RtmpPublishState s) {
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
