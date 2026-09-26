import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';
import 'package:streamer_app/core/services/youtube_channel_reference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('streamer_app/rtmp_publisher');
  const events = EventChannel('streamer_app/rtmp_publisher/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final starts = <int>[];
  late RtmpPublishEngine engine;
  Future<void> emit(WidgetTester tester, String type, [int? generation]) async {
    messenger.handlePlatformMessage(
        events.name,
        events.codec.encodeSuccessEnvelope({
          'type': type,
          if (generation != null) 'generation': generation,
        }),
        (_) {});
    await tester.pump();
  }

  setUp(() {
    starts.clear();
    messenger.setMockMessageHandler(
        events.name, (_) async => events.codec.encodeSuccessEnvelope(null));
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'startStream') {
        starts.add(call.arguments['generation'] as int);
      }
      return null;
    });
    engine = RtmpPublishEngine();
  });
  tearDown(() {
    engine.dispose();
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMessageHandler(events.name, null);
  });
  Future<void> live(WidgetTester tester) async {
    await engine.initializeCamera();
    await engine.startPublishing('rtmp://127.0.0.1/test');
    await emit(tester, 'live', starts.last);
  }

  testWidgets('recovery waits 3s, checks authority and keeps mute intent',
      (tester) async {
    var checked = 0;
    engine.authorizeRecovery = () async {
      checked++;
      return true;
    };
    await live(tester);
    await engine.setMuted(true);
    await emit(tester, 'disconnected', starts.last);
    await tester.pump(const Duration(seconds: 2));
    expect(starts, hasLength(1));
    await tester.pump(const Duration(seconds: 1));
    expect(checked, 1);
    expect(starts, hasLength(2));
    await emit(tester, 'live', starts.last);
    expect(engine.isMuted, isTrue);
    expect(engine.state, RtmpPublishState.live);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('offline does not poll authority and exhausts at 60s',
      (tester) async {
    var checked = 0;
    engine.isOnline = () => false;
    engine.authorizeRecovery = () async {
      checked++;
      return true;
    };
    await live(tester);
    await emit(tester, 'disconnected', starts.last);
    await tester.pump(const Duration(seconds: 60));
    expect(checked, 0);
    expect(starts, hasLength(1));
    expect(engine.state, RtmpPublishState.error);
  });

  for (final action in ['stop', 'denied', 'stale']) {
    testWidgets('pending authority cannot revive $action', (tester) async {
      final authority = Completer<bool?>();
      engine.authorizeRecovery = () => authority.future;
      await live(tester);
      final old = starts.last;
      await emit(tester, 'disconnected', old);
      await tester.pump(const Duration(seconds: 3));
      if (action == 'stop') await engine.stopPublishing();
      if (action == 'stale') {
        await engine.stopPublishing();
        await engine.startPublishing('rtmp://127.0.0.1/replacement');
      }
      final count = starts.length;
      authority.complete(action != 'denied');
      await tester.pump();
      await emit(tester, 'live', old);
      await tester.pump(const Duration(seconds: 9));
      expect(starts, hasLength(count));
      expect(engine.state, isNot(RtmpPublishState.live));
      await engine.stopPublishing();
    });
  }

  testWidgets('duplicate failures and callback flapping cannot reset budget',
      (tester) async {
    var checked = 0;
    engine.authorizeRecovery = () async {
      checked++;
      return true;
    };
    await live(tester);
    for (var i = 0; i < 10; i++) {
      await emit(tester, 'disconnected', starts.last);
      await emit(tester, 'disconnected', starts.last);
      await tester.pump(const Duration(seconds: 3));
      await emit(tester, 'live', starts.last);
      await tester.pump(const Duration(milliseconds: 10));
    }
    await emit(tester, 'disconnected', starts.last);
    expect(checked, 10);
    expect(engine.state, RtmpPublishState.error);
    await tester.pump(const Duration(seconds: 60));
    expect(checked, 10);
  });

  test('channel references preserve identity and reject deceptive URLs', () {
    const id = 'UCabcdefghijklmnopqrstuv';
    for (final input in [
      '@lecture',
      'lecture',
      'youtube.com/@lecture/videos?si=abc'
    ]) {
      expect(YouTubeChannelReference.parse(input)!.value, 'lecture');
    }
    expect(
        YouTubeChannelReference.parse('https://youtube.com/channel/$id')!
            .parameter,
        'id');
    expect(
        YouTubeChannelReference.parse('https://youtube.com/user/lecture')!
            .parameter,
        'forUsername');
    expect(YouTubeChannelReference.parse('@محاضرات')!.value, 'محاضرات');
    for (final bad in [
      'https://evil.test/@lecture',
      'https://youtube.com.evil.test/@lecture',
      'https://user@youtube.com/@lecture',
      'https://youtu.be/abcdefghijk',
      'https://youtube.com/watch?v=abcdefghijk',
      'https://youtube.com/@lecture/unknown',
      'hello there',
      'https://youtube.com/channel/UCshort',
      'https://youtube.com/@name%2Fother'
    ]) {
      expect(YouTubeChannelReference.parse(bad), isNull, reason: bad);
    }
    expect(YouTubeChannelReference.pairError('arbitrary', '@lecture'),
        'live.channel_invalid');
    expect(YouTubeChannelReference.pairError('https://youtube.com/@new', 'old'),
        'live.channel_mismatch');
    expect(
        YouTubeChannelReference.pairError('https://youtube.com/c/old', 'old'),
        'live.channel_custom');
    expect(
        YouTubeChannelReference.pairError(
            'https://youtube.com/@lecture', '@lecture'),
        isNull);
  });
}
