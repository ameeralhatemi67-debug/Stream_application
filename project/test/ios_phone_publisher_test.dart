import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('streamer_app/rtmp_publisher');
  const events = EventChannel('streamer_app/rtmp_publisher/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];
  final engines = <RtmpPublishEngine>[];
  var supported = true;
  var missing = false;
  var eventSubscriptions = 0;
  PlatformException? prepareError;

  RtmpPublishEngine engine() {
    final value = RtmpPublishEngine();
    engines.add(value);
    return value;
  }

  Future<void> emit(Map<String, dynamic> value) async {
    messenger.handlePlatformMessage(
        events.name, events.codec.encodeSuccessEnvelope(value), (_) {});
    await Future<void>.delayed(Duration.zero);
  }

  int generation() =>
      (calls.lastWhere((call) => call.method == 'startStream').arguments
          as Map)['generation'] as int;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    calls.clear();
    engines.clear();
    supported = true;
    missing = false;
    eventSubscriptions = 0;
    prepareError = null;
    messenger.setMockMessageHandler(events.name, (message) async {
      eventSubscriptions++;
      return null;
    });
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (missing) throw MissingPluginException();
      if (call.method == 'isSupported') return supported;
      if (call.method == 'prepare' && prepareError != null) throw prepareError!;
      return null;
    });
  });

  tearDown(() async {
    for (final value in engines) {
      value.dispose();
    }
    await Future<void>.delayed(Duration.zero);
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMessageHandler(events.name, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
      'iOS availability follows compile-time opt-in; Android remains supported',
      () {
    expect(iosPhonePublishingEnabled, iosPhonePublishingFlag);
    expect(phonePublishingAvailable, iosPhonePublishingFlag);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(iosPhonePublishingEnabled, isFalse);
    expect(phonePublishingAvailable, isTrue);
  });

  test('missing native bridge is a safe false capability result', () async {
    missing = true;
    expect(await RtmpPublishEngine.iosNativePublisherAvailable(), isFalse);
  });

  test('a native unavailable result never advertises iOS support', () async {
    supported = false;
    expect(await RtmpPublishEngine.iosNativePublisherAvailable(), isFalse);
  });

  if (!iosPhonePublishingFlag) {
    test('default-off iOS never subscribes or calls native publisher methods',
        () async {
      final value = engine();
      await expectLater(
          value.initializeCamera(), throwsA(isA<PlatformException>()));
      await expectLater(value.startPublishing('rtmp://localhost/app/MOCK_KEY'),
          throwsA(isA<PlatformException>()));
      await value.setAudioOnly(true);
      await value.setMuted(true);
      await value.setOrientation(0);
      await value.stopPublishing();
      engines.remove(value);
      value.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(calls, isEmpty);
      expect(eventSubscriptions, 0);
    });
  } else {
    test('flagged iOS checks native support and passes the requested quality',
        () async {
      final value = engine();
      await value.initializeCamera(preset: BroadcastQualityPreset.high);
      expect(value.state, RtmpPublishState.ready);
      expect(calls.map((call) => call.method), ['isSupported', 'prepare']);
      expect(calls.last.arguments, {
        'width': 1920,
        'height': 1080,
        'videoBitrate': 4500000,
        'audioOnly': false,
      });
    });

    test('audio-only preparation is explicit before any video capture',
        () async {
      final value = engine();
      await value.initializeCamera(initialAudioOnly: true);
      expect((calls.last.arguments as Map)['audioOnly'], isTrue);
      expect(value.isAudioOnly, isTrue);
      expect(value.isCameraOff, isTrue);
    });

    test('native mismatch fails before prepare with a stable availability key',
        () async {
      supported = false;
      final value = engine();
      await expectLater(
          value.initializeCamera(), throwsA(isA<PlatformException>()));
      expect(value.state, RtmpPublishState.error);
      expect(value.lastError, 'live.ios_publisher_unavailable');
      expect(calls.map((call) => call.method), ['isSupported']);
    });

    test('permission/capture refusal reaches the existing error path',
        () async {
      prepareError = PlatformException(
          code: 'PERMISSION_DENIED', message: 'live.camera_setup_failed');
      final value = engine();
      await expectLater(
          value.initializeCamera(), throwsA(isA<PlatformException>()));
      expect(value.state, RtmpPublishState.error);
      expect(value.lastError, 'live.camera_setup_failed');
      expect(calls.where((call) => call.method == 'startStream'), isEmpty);
    });

    test('acknowledgement is not live; events are generation-scoped', () async {
      final value = engine();
      await value.initializeCamera();
      await value.startPublishing('rtmp://localhost/app/MOCK_KEY');
      final current = generation();
      expect(value.state, RtmpPublishState.connecting);
      await emit({'type': 'live', 'generation': current - 1});
      expect(value.state, RtmpPublishState.connecting);
      await emit({'type': 'live', 'generation': current});
      expect(value.state, RtmpPublishState.live);
      await emit({'type': 'bitrate', 'generation': current, 'value': 1200000});
      await emit({'type': 'audioLevel', 'generation': current, 'rms': 0.4});
      expect(value.lastBitrateBps, 1200000);
      expect(value.lastMicRms, 0.4);
    });

    test('mute, audio-only and orientation retain the channel contract',
        () async {
      final value = engine();
      await value.initializeCamera();
      await value.setMuted(true);
      await value.setAudioOnly(true);
      await value.setOrientation(0);
      expect(value.isMuted, isTrue);
      expect(value.isMicSilent.value, isTrue);
      expect(value.isCameraOff, isTrue);
      expect(calls.where((call) => call.method == 'setMuted').single.arguments,
          {'muted': true});
      expect(
          calls.where((call) => call.method == 'setAudioOnly').single.arguments,
          {'audioOnly': true});
      expect(calls.last.arguments, {'orientation': 0});
    });

    test('native background audio-only event updates UI and recovery state',
        () async {
      final value = engine();
      await value.initializeCamera();
      await emit(
          {'type': 'audioOnlyChanged', 'generation': 0, 'audioOnly': true});
      expect(value.isAudioOnly, isTrue);
      expect(value.isCameraOff, isTrue);
      await emit(
          {'type': 'audioOnlyChanged', 'generation': -1, 'audioOnly': false});
      expect(value.isCameraOff, isTrue);
    });

    test('drop recovery reauthorizes and carries mode into a fresh generation',
        () async {
      var authorizations = 0;
      final value = engine()
        ..authorizeRecovery = () async {
          authorizations++;
          return true;
        }
        ..isOnline = () => true;
      await value.initializeCamera();
      await value.startPublishing('rtmp://localhost/app/MOCK_KEY');
      final first = generation();
      await emit({'type': 'live', 'generation': first});
      await emit(
          {'type': 'audioOnlyChanged', 'generation': first, 'audioOnly': true});
      await emit({'type': 'disconnected', 'generation': first});
      expect(value.state, RtmpPublishState.reconnecting);
      await Future<void>.delayed(const Duration(milliseconds: 3150));
      expect(authorizations, 1);
      expect(generation(), greaterThan(first));
      final latest = generation();
      expect(
          (calls.lastWhere((call) => call.method == 'startStream').arguments
              as Map)['audioOnly'],
          isTrue);
      await emit({'type': 'live', 'generation': first});
      expect(value.state, RtmpPublishState.reconnecting);
      await emit({'type': 'live', 'generation': latest});
      expect(value.state, RtmpPublishState.live);
      expect(value.recoveryCount, 1);
    });

    test('revoked authorization prevents a native retry', () async {
      final value = engine()..authorizeRecovery = () async => false;
      await value.initializeCamera();
      await value.startPublishing('rtmp://localhost/app/MOCK_KEY');
      final current = generation();
      await emit({'type': 'live', 'generation': current});
      await emit({'type': 'disconnected', 'generation': current});
      await Future<void>.delayed(const Duration(milliseconds: 3150));
      expect(value.state, RtmpPublishState.error);
      expect(calls.where((call) => call.method == 'startStream').length, 1);
    });

    test('stop invalidates late connection and mode events', () async {
      final value = engine();
      await value.initializeCamera();
      await value.startPublishing('rtmp://localhost/app/MOCK_KEY');
      final current = generation();
      await value.stopPublishing();
      await emit({'type': 'live', 'generation': current});
      await emit({
        'type': 'audioOnlyChanged',
        'generation': current,
        'audioOnly': true
      });
      expect(value.state, RtmpPublishState.stopped);
      expect(value.isCameraOff, isFalse);
    });
  }
}
