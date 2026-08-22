import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// v0.7 Checkpoint 2 -- Dart-side half of the engine/UI split validated by
/// the Checkpoint 1 spike (lib/spike_rtmp/rtmp_publish_engine.dart). Screens
/// only ever read [state]/[lastError] and call these methods; they never
/// touch the MethodChannel/EventChannel directly. That boundary is what lets
/// v1.1 swap in an iOS-native engine behind this exact same Dart surface.
enum RtmpPublishState {
  idle,
  initializingCamera,
  ready,
  connecting,
  live,
  stopped,
  error,
}

/// Resolution/bitrate presets for Checkpoint 2 Phase 3's go-live controls.
/// Defaults to [medium] rather than [high] so a first-time broadcaster on a
/// mid-tier phone/cellular upload doesn't saturate their connection before
/// they've had a chance to see how [low]/[medium] performs.
enum BroadcastQualityPreset { low, medium, high }

extension BroadcastQualityPresetConfig on BroadcastQualityPreset {
  int get width {
    switch (this) {
      case BroadcastQualityPreset.low:
        return 640;
      case BroadcastQualityPreset.medium:
        return 1280;
      case BroadcastQualityPreset.high:
        return 1920;
    }
  }

  int get height {
    switch (this) {
      case BroadcastQualityPreset.low:
        return 480;
      case BroadcastQualityPreset.medium:
        return 720;
      case BroadcastQualityPreset.high:
        return 1080;
    }
  }

  int get videoBitrateBps {
    switch (this) {
      case BroadcastQualityPreset.low:
        return 800 * 1000;
      case BroadcastQualityPreset.medium:
        return 2500 * 1000;
      case BroadcastQualityPreset.high:
        return 4500 * 1000;
    }
  }

  String get label {
    switch (this) {
      case BroadcastQualityPreset.low:
        return 'Low (480p) -- safest on weak/cellular uploads';
      case BroadcastQualityPreset.medium:
        return 'Medium (720p) -- recommended default';
      case BroadcastQualityPreset.high:
        return 'High (1080p) -- needs a strong Wi-Fi upload';
    }
  }
}

class RtmpPublishEngine extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('streamer_app/rtmp_publisher');
  static const EventChannel _events =
      EventChannel('streamer_app/rtmp_publisher/events');

  RtmpPublishState _state = RtmpPublishState.idle;
  RtmpPublishState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  bool _isFrontCamera = false;
  bool get isFrontCamera => _isFrontCamera;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  int? _lastBitrateBps;
  int? get lastBitrateBps => _lastBitrateBps;

  StreamSubscription<dynamic>? _eventSub;

  Future<void> initializeCamera({
    BroadcastQualityPreset preset = BroadcastQualityPreset.medium,
  }) async {
    _setState(RtmpPublishState.initializingCamera);
    _eventSub ??= _events.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onEventError,
        );

    final arguments = {
      'width': preset.width,
      'height': preset.height,
      'videoBitrate': preset.videoBitrateBps,
    };

    // NOT_READY means the PlatformView's native surface hasn't finished
    // attaching to RtmpPublisherBridge yet -- normally a one-frame race, not
    // a real failure, since the screen mounts the camera preview before
    // calling this. A short bounded retry absorbs that race without needing
    // a dedicated "view attached" channel event.
    const maxAttempts = 10;
    const retryDelay = Duration(milliseconds: 200);
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await _channel.invokeMethod<void>('prepare', arguments);
        _setState(RtmpPublishState.ready);
        return;
      } on PlatformException catch (e) {
        final isNotReady = e.code == 'NOT_READY';
        if (isNotReady && attempt < maxAttempts) {
          await Future<void>.delayed(retryDelay);
          continue;
        }
        _lastError = e.message ?? e.code;
        _setState(RtmpPublishState.error);
        rethrow;
      }
    }
  }

  Future<void> switchCamera() async {
    try {
      await _channel.invokeMethod<void>('switchCamera');
      _isFrontCamera = !_isFrontCamera;
      notifyListeners();
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      notifyListeners();
    }
  }

  Future<void> startPublishing(String url) async {
    _setState(RtmpPublishState.connecting);
    try {
      await _channel.invokeMethod<void>('startStream', {'url': url});
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      _setState(RtmpPublishState.error);
      rethrow;
    }
  }

  Future<void> stopPublishing() async {
    try {
      await _channel.invokeMethod<void>('stopStream');
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
    } finally {
      _lastBitrateBps = null;
      _setState(RtmpPublishState.stopped);
    }
  }

  Future<void> setMuted(bool muted) async {
    try {
      await _channel.invokeMethod<void>('setMuted', {'muted': muted});
      _isMuted = muted;
      notifyListeners();
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      notifyListeners();
    }
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    switch (type) {
      case 'connecting':
        _setState(RtmpPublishState.connecting);
        break;
      case 'live':
        _setState(RtmpPublishState.live);
        break;
      case 'stopped':
        if (_state == RtmpPublishState.live ||
            _state == RtmpPublishState.connecting) {
          _setState(RtmpPublishState.stopped);
        }
        break;
      case 'bitrate':
        _lastBitrateBps = (event['value'] as num?)?.toInt();
        notifyListeners();
        break;
      case 'error':
        _lastError = event['message'] as String?;
        _setState(RtmpPublishState.error);
        break;
    }
  }

  void _onEventError(Object error) {
    _lastError = '$error';
    _setState(RtmpPublishState.error);
  }

  void _setState(RtmpPublishState value) {
    _state = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _channel.invokeMethod<void>('dispose').catchError((_) {});
    super.dispose();
  }
}
