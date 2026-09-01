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
  /// v0.7 Checkpoint 4 Phase 1 -- the connection dropped mid-broadcast
  /// (network switch, weak signal) and RootEncoder is retrying with
  /// exponential backoff. Distinct from [connecting] (the initial connect)
  /// so the UI can say "stream interrupted" rather than repeat the
  /// first-connect copy.
  reconnecting,
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

  /// Cluster 1 Task 1 -- "viewers are hearing nothing, and it is the
  /// broadcaster's doing", exposed as a [ValueNotifier] so the viewer-facing
  /// badge can rebuild on its own without dragging the whole broadcast
  /// screen through a setState on every RMS sample.
  ///
  /// Two independent sources feed it:
  ///  * [setMuted] -- an explicit mute, true the instant the streamer taps
  ///    it (no waiting on an audio sample that will never arrive, since a
  ///    muted MicrophoneSource stops producing frames entirely); and
  ///  * the native `audioLevel` event -- an unmuted mic that has been below
  ///    [_silenceRmsThreshold] continuously for [_silenceGracePeriod].
  ///
  /// The grace period is what keeps this from flickering on every natural
  /// pause between sentences.
  final ValueNotifier<bool> isMicSilent = ValueNotifier<bool>(false);

  /// Most recent normalised (0.0-1.0) microphone RMS reported by the native
  /// encoder, or null when the platform has not reported one yet.
  double? _lastMicRms;
  double? get lastMicRms => _lastMicRms;

  /// Below this normalised RMS the mic is treated as producing silence
  /// rather than quiet speech -- roughly -40 dBFS, comfortably under normal
  /// room tone but above a truly dead input.
  static const double _silenceRmsThreshold = 0.01;

  /// How long the level has to stay under the threshold before viewers are
  /// told the broadcaster is silent.
  static const Duration _silenceGracePeriod = Duration(seconds: 3);

  Timer? _silenceTimer;
  bool _silentByLevel = false;

  bool _isAudioOnly = false;
  bool get isAudioOnly => _isAudioOnly;

  int? _lastBitrateBps;
  int? get lastBitrateBps => _lastBitrateBps;

  int? _reconnectAttempt;
  int? get reconnectAttempt => _reconnectAttempt;
  int? _maxReconnectAttempts;
  int? get maxReconnectAttempts => _maxReconnectAttempts;

  StreamSubscription<dynamic>? _eventSub;

  // v0.7 Checkpoint 4 Phase 1 -- a watchdog, not just a display concern.
  // Confirmed on-device that a write-side connection drop (broken pipe from
  // a killed RTMP server) doesn't always reach RootEncoder's ConnectChecker
  // at all -- only read-side failures reliably do -- so this engine can't
  // assume a native event will always eventually arrive to end a
  // connecting/reconnecting wait. Without this, that gap is a genuine
  // silent freeze: an unbounded "reconnecting" banner with no way out.
  Timer? _watchdogTimer;

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

  /// v0.7 Checkpoint 3 Phase 1 -- swaps the encoder's video source between
  /// the live camera and a static branded image, so a broadcast can go out
  /// mic-only without dropping the video track YouTube's RTMP ingest
  /// requires. Safe to call before or after [startPublishing]; RootEncoder
  /// applies source changes on the fly.
  Future<void> setAudioOnly(bool audioOnly) async {
    try {
      await _channel.invokeMethod<void>('setAudioOnly', {'audioOnly': audioOnly});
      _isAudioOnly = audioOnly;
      notifyListeners();
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      notifyListeners();
    }
  }

  Future<void> setOrientation(int orientation) async {
    try {
      await _channel.invokeMethod<void>('setOrientation', {'orientation': orientation});
    } on PlatformException catch (e) {
      debugPrint('[RtmpPublishEngine] setOrientation failed: $e');
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
      _reconnectAttempt = null;
      _maxReconnectAttempts = null;
      _silenceTimer?.cancel();
      _silenceTimer = null;
      _lastMicRms = null;
      // Mute is a property of a *live* MicrophoneSource, and stopping tears
      // that source down -- carrying the flag over would both strand a
      // "Streamer Microphone Muted" badge on an ended broadcast and make a
      // restarted one report a mute the native encoder no longer holds.
      _isMuted = false;
      _applySilenceState(levelIsSilent: false);
      _setState(RtmpPublishState.stopped);
    }
  }

  Future<void> setMuted(bool muted) async {
    try {
      await _channel.invokeMethod<void>('setMuted', {'muted': muted});
      _isMuted = muted;
      _applySilenceState();
      notifyListeners();
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
      notifyListeners();
    }
  }

  /// Folds an incoming microphone level into [isMicSilent].
  ///
  /// A level at or above the threshold clears silence immediately (the
  /// broadcaster started talking again -- no reason to make viewers wait);
  /// a level below it only arms a timer, so the flag flips on sustained
  /// silence rather than on the gaps between words.
  void _handleMicLevel(double rms) {
    _lastMicRms = rms;
    if (rms >= _silenceRmsThreshold) {
      _silenceTimer?.cancel();
      _silenceTimer = null;
      _applySilenceState(levelIsSilent: false);
      return;
    }
    if (isMicSilent.value || _silenceTimer != null) return;
    _silenceTimer = Timer(_silenceGracePeriod, () {
      _silenceTimer = null;
      _applySilenceState(levelIsSilent: true);
    });
  }

  void _applySilenceState({bool? levelIsSilent}) {
    final silentByLevel = levelIsSilent ?? _silentByLevel;
    _silentByLevel = silentByLevel;
    isMicSilent.value = _isMuted || silentByLevel;
  }

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final type = event['type'] as String?;
    switch (type) {
      case 'connecting':
        _setState(RtmpPublishState.connecting);
        break;
      case 'live':
        _reconnectAttempt = null;
        _maxReconnectAttempts = null;
        _setState(RtmpPublishState.live);
        break;
      case 'reconnecting':
        _reconnectAttempt = (event['attempt'] as num?)?.toInt();
        _maxReconnectAttempts = (event['maxAttempts'] as num?)?.toInt();
        _setState(RtmpPublishState.reconnecting);
        break;
      case 'stopped':
        if (_state == RtmpPublishState.live ||
            _state == RtmpPublishState.connecting ||
            _state == RtmpPublishState.reconnecting) {
          _reconnectAttempt = null;
          _maxReconnectAttempts = null;
          _setState(RtmpPublishState.stopped);
        }
        break;
      case 'bitrate':
        _lastBitrateBps = (event['value'] as num?)?.toInt();
        notifyListeners();
        break;
      case 'audioLevel':
        // Normalised 0.0-1.0 RMS from the native encoder. The Android
        // bridge does not emit this yet (v0.7 shipped mute-only), so on
        // today's devices isMicSilent is driven purely by setMuted -- this
        // arm is the Dart half of the level pipeline, ready for the encoder
        // to start reporting without another Dart-side change.
        final rms = (event['rms'] as num?)?.toDouble();
        if (rms != null) {
          _handleMicLevel(rms.clamp(0.0, 1.0));
          notifyListeners();
        }
        break;
      case 'error':
        _reconnectAttempt = null;
        _maxReconnectAttempts = null;
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
    _watchdogTimer?.cancel();
    _state = value;
    switch (value) {
      case RtmpPublishState.connecting:
        _armWatchdog(
          const Duration(seconds: 20),
          'Could not connect -- timed out.',
        );
        break;
      case RtmpPublishState.reconnecting:
        // Ceiling comfortably above the backoff schedule's own total
        // (2+4+8+16+30 = 60s for 6 attempts), so it only fires if the
        // native side genuinely stopped reporting progress.
        _armWatchdog(
          const Duration(seconds: 75),
          'Lost connection and could not reconnect in time.',
        );
        break;
      default:
        _watchdogTimer = null;
        break;
    }
    notifyListeners();
  }

  void _armWatchdog(Duration timeout, String timeoutMessage) {
    _watchdogTimer = Timer(timeout, () {
      if (_state == RtmpPublishState.connecting ||
          _state == RtmpPublishState.reconnecting) {
        _reconnectAttempt = null;
        _maxReconnectAttempts = null;
        _lastError = timeoutMessage;
        _setState(RtmpPublishState.error);
      }
    });
  }

  @override
  void dispose() {
    _watchdogTimer?.cancel();
    _silenceTimer?.cancel();
    isMicSilent.dispose();
    _eventSub?.cancel();
    _channel.invokeMethod<void>('dispose').catchError((_) {});
    super.dispose();
  }
}
