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

  StreamSubscription<dynamic>? _eventSub;

  Future<void> initializeCamera() async {
    _setState(RtmpPublishState.initializingCamera);
    _eventSub ??= _events.receiveBroadcastStream().listen(
          _onEvent,
          onError: _onEventError,
        );
    try {
      await _channel.invokeMethod<void>('prepare');
      _setState(RtmpPublishState.ready);
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      _setState(RtmpPublishState.error);
      rethrow;
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

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    if (type == 'error') {
      _lastError = event['message'] as String?;
      _setState(RtmpPublishState.error);
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
