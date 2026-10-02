// Regression tests for the 2026-10-02 performance audit fixes
// (brief/audit/2026-10-02_AUDIT_FIX_LOG.md).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/public_catalog_cache.dart';
import 'package:streamer_app/core/services/youtube_api_service.dart';
import 'package:streamer_app/core/widgets/safe_image_provider.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/floating_reactions_overlay.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';

const _streamer = StreamerModel(
  streamerId: 'a',
  fullNameEn: 'A',
  fullNameAr: 'أ',
  titleEn: '',
  titleAr: '',
  organizationEn: '',
  organizationAr: '',
  avatarUrl: '',
  bannerUrl: '',
  bioEn: '',
  bioAr: '',
  isVerified: true,
  followerCount: 0,
  categoryId: 'education',
  cityEn: '',
  cityAr: '',
  venueNameEn: '',
  venueNameAr: '',
  latitude: 1,
  longitude: 1,
  isCurrentlyLive: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CA-01: an unchanged catalog is not rewritten to disk on every poll',
      () async {
    SharedPreferences.setMockInitialValues({});
    final cache = PublicCatalogCache();
    final t0 = DateTime.utc(2026, 10, 2, 12);
    await cache.save([_streamer], const [], updatedAt: t0);
    final prefs = await SharedPreferences.getInstance();
    final first = prefs.getString(PublicCatalogCache.key);

    // Same content 30 s later: skipped, so the stored timestamp is unchanged.
    await cache.save([_streamer], const [],
        updatedAt: t0.add(const Duration(seconds: 30)));
    expect(prefs.getString(PublicCatalogCache.key), first);

    // Changed content is written immediately.
    await cache.save([_streamer.copyWith(followerCount: 5), _streamer], const [],
        updatedAt: t0.add(const Duration(seconds: 40)));
    expect(prefs.getString(PublicCatalogCache.key), isNot(first));

    // Unchanged content is still refreshed once the interval has passed.
    final second = prefs.getString(PublicCatalogCache.key);
    await cache.save([_streamer.copyWith(followerCount: 5), _streamer], const [],
        updatedAt: t0.add(const Duration(minutes: 10)));
    expect(prefs.getString(PublicCatalogCache.key), isNot(second));
  });

  test('CA-04: a channel lookup is made once per handle per session', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(
          json.encode({
            'items': [
              {
                'id': 'UCchannel0000000000000000',
                'contentDetails': {
                  'relatedPlaylists': {'uploads': 'UUchannel0000000000000000'}
                }
              }
            ]
          }),
          200);
    });
    final service = YouTubeApiService(apiKey: 'test-key', client: client);
    final a = await service.fetchChannelDetails('@somehandle');
    final b = await service.fetchChannelDetails('@SomeHandle');
    expect(requests, 1);
    expect(b, a);
    // The returned map is a copy: callers cannot corrupt the cache.
    b['channelId'] = 'changed';
    expect((await service.fetchChannelDetails('@somehandle'))['channelId'],
        'UCchannel0000000000000000');
  });

  test('CA-04: a failed channel lookup is not cached', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response('boom', 500);
    });
    final service = YouTubeApiService(apiKey: 'test-key', client: client);
    expect(await service.fetchChannelDetails('@somehandle'), isEmpty);
    expect(await service.fetchChannelDetails('@somehandle'), isEmpty);
    expect(requests, 2);
  });

  test('IMG-01: downscaledImage wraps a provider in a bounded decode', () {
    final provider = downscaledImage(const AssetImage('x.png'), width: 96);
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 96);
    // No bound requested: the provider is returned untouched.
    expect(downscaledImage(const AssetImage('x.png')), isA<AssetImage>());
  });

  testWidgets('LIVE-02: floating reactions are capped', (tester) async {
    final controller = FloatingReactionsOverlayController();
    await tester.pumpWidget(MaterialApp(
        home: SizedBox(
            width: 400,
            height: 800,
            child: FloatingReactionsOverlay(controller: controller))));
    for (var i = 0; i < 60; i++) {
      controller.spawnReaction('heart');
    }
    await tester.pump();
    expect(find.text('❤️'),
        findsNWidgets(FloatingReactionsOverlayState.maxConcurrentParticles));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('❤️'), findsNothing);
  });

  test('LIVE-01: chat keeps a bounded rolling window, memoized per change', () {
    final c = LiveChatController(streamId: 'stream-1');
    addTearDown(c.dispose);
    ChatMessageModel message(int i) => ChatMessageModel(
          id: 'm$i',
          streamId: 'stream-1',
          senderId: 'u',
          senderName: 'U',
          body: 'hello $i',
          createdAt: DateTime.utc(2026, 10, 2).add(Duration(seconds: i)),
        );
    for (var i = 0; i < LiveChatController.maxRetainedMessages + 100; i++) {
      c.debugAddMessageForTests(message(i));
    }
    final visible = c.messages;
    expect(visible.length, LiveChatController.maxRetainedMessages);
    // Oldest dropped, newest kept.
    expect(visible.first.id, 'm100');
    expect(visible.last.id, 'm${LiveChatController.maxRetainedMessages + 99}');
    // Repeated reads between changes return the same cached list.
    expect(identical(c.messages, c.messages), isTrue);
    expect(identical(c.messagesNewestFirst, c.messagesNewestFirst), isTrue);
    expect(c.messagesNewestFirst.first.id, visible.last.id);
    // A change invalidates it.
    c.debugAddMessageForTests(message(9999));
    expect(c.messages.last.id, 'm9999');
  });

  test('RT-04: a heartbeat echo with nothing changed does not notify', () async {
    final provider = AppProvider();
    seedStreamerFixtures(provider);
    await provider.initDeviceSession();
    final device = provider.currentDeviceSession!;
    var notifications = 0;
    provider.addListener(() => notifications++);

    // The same rows, only last_active_at advanced (what every 20 s heartbeat
    // echoes back over Realtime).
    provider.applyDeviceSessions([device]);
    notifications = 0;
    provider.applyDeviceSessions(
        [device.copyWith(lastActiveAt: DateTime.now().add(const Duration(seconds: 20)))]);
    expect(notifications, 0);
    provider.dispose();
  });
}
