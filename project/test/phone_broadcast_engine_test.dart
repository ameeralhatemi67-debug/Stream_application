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

  test(
    'setAudioOnly toggles isAudioOnly on success and sends the flag',
    () async {
      MethodCall? captured;
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        captured = call;
        return null;
      });

      final engine = RtmpPublishEngine();
      expect(engine.isAudioOnly, isFalse);

      await engine.setAudioOnly(true);

      expect(engine.isAudioOnly, isTrue);
      expect(captured?.method, 'setAudioOnly');
      expect(captured?.arguments, {'audioOnly': true});

      await engine.setAudioOnly(false);

      expect(engine.isAudioOnly, isFalse);
      expect(captured?.arguments, {'audioOnly': false});
    },
  );

  test(
    'setAudioOnly surfaces an error without flipping isAudioOnly',
    () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        throw PlatformException(
          code: 'SOURCE_SWITCH_FAILED',
          message: 'no bitmap decoded',
        );
      });

      final engine = RtmpPublishEngine();
      await engine.setAudioOnly(true);

      expect(engine.isAudioOnly, isFalse);
      expect(engine.lastError, 'no bitmap decoded');
    },
  );

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

  test(
    'a "reconnecting" event surfaces the attempt/maxAttempts and clears on "live"',
    () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async => null);

      final engine = RtmpPublishEngine();
      await engine.initializeCamera();

      messenger.handlePlatformMessage(
        eventChannel.name,
        eventChannel.codec.encodeSuccessEnvelope(
          {'type': 'reconnecting', 'attempt': 2, 'maxAttempts': 6},
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.state, RtmpPublishState.reconnecting);
      expect(engine.reconnectAttempt, 2);
      expect(engine.maxReconnectAttempts, 6);

      messenger.handlePlatformMessage(
        eventChannel.name,
        eventChannel.codec.encodeSuccessEnvelope({'type': 'live'}),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.state, RtmpPublishState.live);
      expect(engine.reconnectAttempt, isNull);
      expect(engine.maxReconnectAttempts, isNull);
    },
  );

  test(
    'a final "error" event after reconnecting clears the attempt counters',
    () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async => null);

      final engine = RtmpPublishEngine();
      await engine.initializeCamera();

      messenger.handlePlatformMessage(
        eventChannel.name,
        eventChannel.codec.encodeSuccessEnvelope(
          {'type': 'reconnecting', 'attempt': 6, 'maxAttempts': 6},
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      messenger.handlePlatformMessage(
        eventChannel.name,
        eventChannel.codec.encodeSuccessEnvelope(
          {
            'type': 'error',
            'message': 'Lost connection and could not reconnect: timeout',
          },
        ),
        (_) {},
      );
      await Future<void>.delayed(Duration.zero);

      expect(engine.state, RtmpPublishState.error);
      expect(
        engine.lastError,
        'Lost connection and could not reconnect: timeout',
      );
      expect(engine.reconnectAttempt, isNull);
      expect(engine.maxReconnectAttempts, isNull);
    },
  );

  // ==========================================
  // Cluster 1 Task 1 -- Mic Silence / Mute Detection
  // ==========================================

  test('isMicSilent flips with an explicit mute and clears on unmute',
      () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);

    final engine = RtmpPublishEngine();
    final observed = <bool>[];
    engine.isMicSilent.addListener(() => observed.add(engine.isMicSilent.value));

    expect(engine.isMicSilent.value, isFalse);

    // A muted MicrophoneSource stops producing frames entirely, so mute has
    // to flip this immediately rather than waiting on a level sample that
    // will never arrive.
    await engine.setMuted(true);
    expect(engine.isMuted, isTrue);
    expect(engine.isMicSilent.value, isTrue);

    await engine.setMuted(false);
    expect(engine.isMicSilent.value, isFalse);

    expect(observed, [true, false]);
  });

  test('a failed setMuted leaves the silence flag untouched', () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async {
      throw PlatformException(code: 'MUTE_FAILED', message: 'no mic source');
    });

    final engine = RtmpPublishEngine();
    await engine.setMuted(true);

    // The mic was never actually muted, so telling viewers it was would be a
    // lie -- the badge must track the real device state, not the intent.
    expect(engine.isMuted, isFalse);
    expect(engine.isMicSilent.value, isFalse);
    expect(engine.lastError, 'no mic source');
  });

  test('stopPublishing clears a lingering mute so the badge does not stick',
      () async {
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);

    final engine = RtmpPublishEngine();
    await engine.setMuted(true);
    expect(engine.isMicSilent.value, isTrue);

    await engine.stopPublishing();

    // The broadcast is over; a "Streamer Microphone Muted" badge left
    // standing on an ended stream is worse than no badge at all.
    expect(engine.state, RtmpPublishState.stopped);
    expect(engine.isMicSilent.value, isFalse);
    expect(engine.lastMicRms, isNull);
  });
}
