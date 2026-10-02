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
  /// so the UI can say "stream interrupted"rather than repeat the
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
        return 360;
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

  /// i18n key for the picker label. The engine is a service and has no
  /// locale of its own, so it names the string rather than writing it; the
  /// phone broadcast screen calls `.tr()` on this. Returning English here is
  /// what left the Arabic preset picker in English.
  String get labelKey {
    switch (this) {
      case BroadcastQualityPreset.low:
        return 'live.preset_low';
      case BroadcastQualityPreset.medium:
        return 'live.preset_medium';
      case BroadcastQualityPreset.high:
        return 'live.preset_high';
    }
  }
}

class RtmpPublishEngine extends ChangeNotifier {
  /// true = freshly authorized; false = terminal; null = server unreachable.
  Future<bool?> Function()? authorizeRecovery;
  bool Function()? isOnline;
  Timer? _retryTimer;
  Timer? _recoveryDeadline;
  Timer? _stableTimer;
  int _recoveryEpoch = 0;
  int _connectionGeneration = 0;
  int _attempts = 0;
  DateTime? _deadlineAt;
  bool _hadLive = false;
  bool _recoveryActive = false;
  String? _publishUrl;
  int recoveryCount = 0;

  void _cancelRecovery() {
    _recoveryEpoch++;
    _retryTimer?.cancel();
    _recoveryDeadline?.cancel();
    _stableTimer?.cancel();
    _retryTimer = null;
    _recoveryActive = false;
  }

  void _failRecovery() {
    _cancelRecovery();
    _stopRequested = true;
    _connectionGeneration++;
    _channel.invokeMethod<void>('stopStream').catchError((_) {});
    _lastError = 'live.recovery_exhausted';
    _setState(RtmpPublishState.error);
  }

  void _beginRecovery() {
    if (_disposed || _stopRequested) return;
    _watchdogTimer?.cancel();
    _stableTimer?.cancel();
    if (!_hadLive || authorizeRecovery == null) {
      _failRecovery();
      return;
    }
    if (!_recoveryActive) {
      _recoveryActive = true;
      _attempts = 0;
      _deadlineAt = DateTime.now().add(const Duration(seconds: 60));
      _recoveryDeadline = Timer(const Duration(seconds: 60), _failRecovery);
    }
    _reconnectAttempt = _attempts;
    _maxReconnectAttempts = 10;
    _setState(RtmpPublishState.reconnecting);
    _scheduleRecovery();
  }

  void _scheduleRecovery() {
    if (!_recoveryActive || _retryTimer != null) return;
    if (_attempts >= 10) {
      _failRecovery();
      return;
    }
    final epoch = _recoveryEpoch;
    _retryTimer = Timer(const Duration(seconds: 3), () async {
      // Keep the timer non-null while authorization is in flight: duplicate
      // SDK callbacks cannot start another loop.
      if (DateTime.now().isAfter(_deadlineAt!)) {
        _failRecovery();
        return;
      }
      if (isOnline?.call() == false) {
        _retryTimer = null;
        _scheduleRecovery();
        return;
      }
      _reconnectAttempt = ++_attempts;
      notifyListeners();
      bool? allowed;
      try {
        allowed =
            await authorizeRecovery!().timeout(const Duration(seconds: 5));
      } catch (_) {
        allowed = null;
      }
      if (_disposed || _stopRequested || epoch != _recoveryEpoch) return;
      _retryTimer = null;
      if (DateTime.now().isAfter(_deadlineAt!)) {
        _failRecovery();
        return;
      }
      if (allowed == false) {
        _failRecovery();
        return;
      }
      if (allowed == null) {
        _scheduleRecovery();
        return;
      }
      try {
        final generation = ++_connectionGeneration;
        await _channel.invokeMethod<void>('startStream', {
          'url': _publishUrl,
          'generation': generation,
          'muted': _isMuted,
          'audioOnly': _isAudioOnly,
          'front': _isFrontCamera,
        });
        if (_disposed ||
            _stopRequested ||
            epoch != _recoveryEpoch ||
            _state == RtmpPublishState.live) {
          return;
        }
        _watchdogTimer?.cancel();
        _watchdogTimer = Timer(const Duration(seconds: 8), () {
          _connectionGeneration++;
          _channel.invokeMethod<void>('stopStream').catchError((_) {});
          _beginRecovery();
        });
      } catch (_) {
        if (epoch == _recoveryEpoch && !_stopRequested) _beginRecovery();
      }
    });
  }

  static const MethodChannel _channel =
      MethodChannel('streamer_app/rtmp_publisher');
  static const EventChannel _events =
      EventChannel('streamer_app/rtmp_publisher/events');

  RtmpPublishState _state = RtmpPublishState.idle;
  RtmpPublishState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  final bool _isFrontCamera = false;
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
  bool _disposed = false;

  // v0.7 Checkpoint 4 Phase 1 -- a watchdog, not just a display concern.
  // Confirmed on-device that a write-side connection drop (broken pipe from
  // a killed RTMP server) doesn't always reach RootEncoder's ConnectChecker
  // at all -- only read-side failures reliably do -- so this engine can't
  // assume a native event will always eventually arrive to end a
  // connecting/reconnecting wait. Without this, that gap is a genuine
  // silent freeze: an unbounded "reconnecting"banner with no way out.
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
    // a dedicated "view attached"channel event.
    const maxAttempts = 10;
    const retryDelay = Duration(milliseconds: 200);
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (_disposed || _stopRequested) return;
      try {
        await _channel.invokeMethod<void>('prepare', arguments);
        if (_disposed || _stopRequested) return;
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
    // Owner scope decision, 2026-09-27. The native bridge also refuses it.
    throw UnsupportedError('Front camera switching is coming soon.');
  }

  /// Hides video while retaining the RTMP video track. The current native
  /// implementation keeps the camera open; this is not a resource-off mode.
  Future<void> setAudioOnly(bool audioOnly) async {
    if (_disposed) return;
    try {
      await _channel
          .invokeMethod<void>('setAudioOnly', {'audioOnly': audioOnly});
      if (_disposed) return;
      _isAudioOnly = audioOnly;
      _isCameraOff = audioOnly;
      notifyListeners();
    } on PlatformException catch (e) {
      if (_disposed) return;
      _lastError = e.message ?? e.code;
      notifyListeners();
    }
  }

  bool _isCameraOff = false;
  bool get isCameraOff => _isCameraOff || _isAudioOnly;

  Future<void> toggleCamera([bool? forceOff]) async {
    final nextOff = forceOff ?? !isCameraOff;
    await setAudioOnly(nextOff);
  }

  /// Updates the native orientation transform on the fixed encoder canvas.
  /// A platform failure must not crash the broadcast screen.
  ///
  /// [MissingPluginException] is caught alongside [PlatformException] because
  /// it is not a subclass of it: where the native RTMP side is not registered
  /// at all, the call threw an unhandled async error rather than falling
  /// through to the log below.
  Future<void> setOrientation(int orientation) async {
    try {
      await _channel
          .invokeMethod<void>('setOrientation', {'orientation': orientation});
    } on PlatformException catch (e) {
      debugPrint('[RtmpPublishEngine] setOrientation failed: $e');
    } on MissingPluginException catch (e) {
      debugPrint('[RtmpPublishEngine] setOrientation unavailable: $e');
    }
  }

  bool _stopRequested = false;

  Future<void> startPublishing(String url) async {
    _cancelRecovery();
    _stopRequested = false;
    _hadLive = false;
    _lastError = null;
    _publishUrl = url;
    final generation = ++_connectionGeneration;
    _setState(RtmpPublishState.connecting);
    try {
      await _channel.invokeMethod<void>('startStream', {
        'url': url,
        'generation': generation,
        'muted': _isMuted,
        'audioOnly': _isAudioOnly,
        'front': _isFrontCamera,
      });
    } on PlatformException catch (e) {
      if (_disposed || _stopRequested || generation != _connectionGeneration) {
        return;
      }
      _lastError = e.message ?? e.code;
      _setState(RtmpPublishState.error);
      rethrow;
    }
  }

  /// A MethodChannel acknowledgement only starts an attempt. A native
  /// connection event is required before the caller can publish live state.
  Future<bool> waitUntilLive() async {
    if (_state == RtmpPublishState.live) return true;
    if (_state != RtmpPublishState.connecting &&
        _state != RtmpPublishState.reconnecting) {
      return false;
    }
    final result = Completer<bool>();
    void changed() {
      if (_state == RtmpPublishState.live) {
        result.complete(true);
      } else if (_state == RtmpPublishState.error ||
          _state == RtmpPublishState.stopped) {
        result.complete(false);
      }
      if (result.isCompleted) removeListener(changed);
    }

    addListener(changed);
    return result.future;
  }

  Future<void> stopPublishing() async {
    if (_disposed) return;
    _stopRequested = true;
    _cancelRecovery();
    final generation = ++_connectionGeneration;
    _publishUrl = null;
    try {
      await _channel.invokeMethod<void>('stopStream');
    } on PlatformException catch (e) {
      _lastError = e.message ?? e.code;
    } finally {
      if (!_disposed && generation == _connectionGeneration) {
        _lastBitrateBps = null;
        _reconnectAttempt = null;
        _maxReconnectAttempts = null;
        _silenceTimer?.cancel();
        _silenceTimer = null;
        _lastMicRms = null;
        // Mute is a property of a *live* MicrophoneSource, and stopping tears
        // that source down -- carrying the flag over would both strand a
        // "Streamer Microphone Muted"badge on an ended broadcast and make a
        // restarted one report a mute the native encoder no longer holds.
        _isMuted = false;
        _applySilenceState(levelIsSilent: false);
        _setState(RtmpPublishState.stopped);
      }
    }
  }

  Future<void> setMuted(bool muted) async {
    if (_disposed) return;
    try {
      await _channel.invokeMethod<void>('setMuted', {'muted': muted});
      if (_disposed) return;
      _isMuted = muted;
      _applySilenceState();
      notifyListeners();
    } on PlatformException catch (e) {
      if (_disposed) return;
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
    if (_disposed || event is! Map) return;
    if (event['generation'] != null &&
        event['generation'] != _connectionGeneration) {
      return;
    }
    final type = event['type'] as String?;
    if (_stopRequested &&
        (type == 'connecting' ||
            type == 'live' ||
            type == 'reconnecting' ||
            type == 'bitrate')) {
      return;
    }
    switch (type) {
      case 'connecting':
        _setState(_recoveryActive
            ? RtmpPublishState.reconnecting
            : RtmpPublishState.connecting);
        break;
      case 'disconnected':
        _beginRecovery();
        break;
      case 'live':
        _hadLive = true;
        if (_recoveryActive) {
          recoveryCount++;
          _stableTimer?.cancel();
          // Flapping success callbacks do not reset the episode budget.
          _stableTimer = Timer(const Duration(seconds: 10), _cancelRecovery);
        }
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
        final bitrate = (event['value'] as num?)?.toInt();
        // The sample arrives about once a second and rebuilt the whole studio
        // screen each time while the phone is encoding. Only notify when the
        // displayed kbit/s figure changes (audit RT-08).
        final changed = bitrate == null ||
            _lastBitrateBps == null ||
            (bitrate / 1000).round() != (_lastBitrateBps! / 1000).round();
        _lastBitrateBps = bitrate;
        if (changed) notifyListeners();
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
        _cancelRecovery();
        _stopRequested = true;
        _reconnectAttempt = null;
        _maxReconnectAttempts = null;
        _lastError = event['message'] as String? ?? 'live.connection_error';
        _setState(RtmpPublishState.error);
        break;
    }
  }

  void _onEventError(Object error) {
    if (!_disposed && !_stopRequested) _failRecovery();
  }

  void _setState(RtmpPublishState value) {
    if (_disposed) return;
    if (value != RtmpPublishState.reconnecting || !_recoveryActive) {
      _watchdogTimer?.cancel();
    }
    _state = value;
    switch (value) {
      case RtmpPublishState.connecting:
        _armWatchdog(
          const Duration(seconds: 20),
          'Could not connect -- timed out.',
        );
        break;
      case RtmpPublishState.reconnecting:
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
        _channel.invokeMethod<void>('stopStream').catchError((_) {});
        _stopRequested = true;
        _setState(RtmpPublishState.error);
      }
    });
  }

  @override
  void dispose() {
    _cancelRecovery();
    _stopRequested = true;
    _connectionGeneration++;
    _setState(RtmpPublishState.stopped);
    _disposed = true;
    _watchdogTimer?.cancel();
    _silenceTimer?.cancel();
    isMicSilent.dispose();
    _eventSub?.cancel();
    _channel.invokeMethod<void>('dispose').catchError((_) {});
    super.dispose();
  }
}
