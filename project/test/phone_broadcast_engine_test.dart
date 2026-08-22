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
}
