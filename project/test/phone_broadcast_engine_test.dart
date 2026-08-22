import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('streamer_app/rtmp_publisher');
  const eventChannel = EventChannel('streamer_app/rtmp_publisher/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    // Prevents receiveBroadcastStream() from surfacing a spurious
    // MissingPluginException as an error event during these tests --
    // Phase 1 doesn't exercise event-channel traffic itself.
    messenger.setMockMessageHandler(eventChannel.name, (message) async => null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockMessageHandler(eventChannel.name, null);
  });

  test(
    'initializeCamera transitions idle -> initializingCamera -> ready on success',
    () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        expect(call.method, 'prepare');
        return null;
      });

      final engine = RtmpPublishEngine();
      final states = <RtmpPublishState>[];
      engine.addListener(() => states.add(engine.state));

      await engine.initializeCamera();

      expect(states, [
        RtmpPublishState.initializingCamera,
        RtmpPublishState.ready,
      ]);
      expect(engine.state, RtmpPublishState.ready);
      expect(engine.lastError, isNull);
    },
  );

  test('initializeCamera surfaces a PlatformException as error state', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'PREPARE_FAILED', message: 'no encoder');
    });

    final engine = RtmpPublishEngine();

    await expectLater(
      engine.initializeCamera(),
      throwsA(isA<PlatformException>()),
    );

    expect(engine.state, RtmpPublishState.error);
    expect(engine.lastError, 'no encoder');
  });

  test(
    'initializeCamera retries through NOT_READY until the native view attaches',
    () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        calls++;
        if (calls < 3) {
          throw PlatformException(
            code: 'NOT_READY',
            message: 'Camera preview is not attached yet.',
          );
        }
        return null;
      });

      final engine = RtmpPublishEngine();
      await engine.initializeCamera();

      expect(calls, 3);
      expect(engine.state, RtmpPublishState.ready);
      expect(engine.lastError, isNull);
    },
  );

  test(
    'initializeCamera surfaces NOT_READY as error once retries are exhausted',
    () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(
          code: 'NOT_READY',
          message: 'Camera preview is not attached yet.',
        );
      });

      final engine = RtmpPublishEngine();
      await expectLater(
        engine.initializeCamera(),
        throwsA(isA<PlatformException>()),
      );

      expect(engine.state, RtmpPublishState.error);
      expect(engine.lastError, 'Camera preview is not attached yet.');
    },
  );

  test('switchCamera toggles isFrontCamera on success', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);

    final engine = RtmpPublishEngine();
    expect(engine.isFrontCamera, isFalse);

    await engine.switchCamera();

    expect(engine.isFrontCamera, isTrue);
  });

  test('switchCamera surfaces an error without flipping isFrontCamera', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'SWITCH_FAILED', message: 'no second camera');
    });

    final engine = RtmpPublishEngine();
    await engine.switchCamera();

    expect(engine.isFrontCamera, isFalse);
    expect(engine.lastError, 'no second camera');
  });

  test("initializeCamera sends the selected preset's width/height/bitrate", () async {
    Map<dynamic, dynamic>? capturedArgs;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      capturedArgs = call.arguments as Map<dynamic, dynamic>?;
      return null;
    });

    final engine = RtmpPublishEngine();
    await engine.initializeCamera(preset: BroadcastQualityPreset.low);

    expect(capturedArgs, {
      'width': 640,
      'height': 480,
      'videoBitrate': 800000,
    });
  });

  test('startPublishing sends the url and sets connecting state', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      if (call.method == 'startStream') captured = call;
      return null;
    });

    final engine = RtmpPublishEngine();
    await engine.startPublishing('rtmp://example.com/live2/key');

    expect(captured?.method, 'startStream');
    expect(captured?.arguments, {'url': 'rtmp://example.com/live2/key'});
    expect(engine.state, RtmpPublishState.connecting);
  });

  test('startPublishing surfaces a PlatformException as error state', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'START_FAILED', message: 'bad url');
    });

    final engine = RtmpPublishEngine();
    await expectLater(
      engine.startPublishing('rtmp://bad'),
      throwsA(isA<PlatformException>()),
    );

    expect(engine.state, RtmpPublishState.error);
    expect(engine.lastError, 'bad url');
  });

  test('stopPublishing invokes stopStream and sets stopped state', () async {
    final calledMethods = <String>[];
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      calledMethods.add(call.method);
      return null;
    });

    final engine = RtmpPublishEngine();
    await engine.stopPublishing();

    expect(calledMethods, contains('stopStream'));
    expect(engine.state, RtmpPublishState.stopped);
  });

  test('setMuted toggles isMuted on success and sends the muted flag', () async {
    MethodCall? captured;
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      captured = call;
      return null;
    });

    final engine = RtmpPublishEngine();
    expect(engine.isMuted, isFalse);

    await engine.setMuted(true);

    expect(engine.isMuted, isTrue);
    expect(captured?.arguments, {'muted': true});
  });

  test('an event-channel "live" event flips state to live once initialized', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);

    final engine = RtmpPublishEngine();
    await engine.initializeCamera();

    messenger.handlePlatformMessage(
      eventChannel.name,
      eventChannel.codec.encodeSuccessEnvelope({'type': 'live'}),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(engine.state, RtmpPublishState.live);
  });
}
