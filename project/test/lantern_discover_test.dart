import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/discovery/presentation/lantern/lantern_discover_view.dart';
import 'package:streamer_app/features/discovery/presentation/lantern/lantern_stream_cards.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/streamer_grid_card.dart';
import 'package:streamer_app/features/profile/models/upcoming_schedule.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// Discover in Lantern and Arch (ADR-026): the same catalog and actions as
/// the older Discover, in its own layout.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const phone = Size(390, 844),
      tablet = Size(820, 1180),
      laptop = Size(1440, 900);

  for (final (label, size) in [
    ('phone', phone),
    ('tablet', tablet),
    ('laptop', laptop)
  ]) {
    for (final lang in ['ar', 'en']) {
      for (final night in [false, true]) {
        testWidgets(
            'lays out on a $label in $lang, ${night ? 'night' : 'day'}',
            (tester) async {
          final app = await LanternApp.start(tester,
              size: size,
              lang: lang,
              provider: lanternProvider(
                  appearance: night
                      ? LanternAppearance.night
                      : LanternAppearance.day));
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternDiscoverView), findsOneWidget);
          expect(
              Theme.of(tester.element(find.byType(LanternDiscoverView)))
                  .extension<LanternTokens>()!
                  .night,
              night);
          // Scroll the whole page: every section must lay out.
          final scroll = find
              .descendant(
                  of: find.byType(LanternDiscoverView),
                  matching: find.byType(Scrollable))
              .first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(scroll, const Offset(0, -700));
            await tester.pump(const Duration(milliseconds: 120));
            expect(tester.takeException(), isNull, reason: 'after scroll $i');
          }
          await app.close();
        });
      }
    }
  }

  // Tall windows, so sections below the first screen are built too.
  const tallPhone = Size(390, 5200), tallLaptop = Size(1440, 3200);

  testWidgets('it is built from the Lantern kit alone', (tester) async {
    final app = await LanternApp.start(tester, size: tallLaptop, lang: 'ar');
    final view = find.byType(LanternDiscoverView);
    for (final type in [CaButton, CaCard, CaStatusChip, StreamerGridCard]) {
      expect(
          find.descendant(of: view, matching: find.byType(type)), findsNothing,
          reason: '$type belongs to the older designs');
    }
    expect(find.descendant(of: view, matching: find.byType(LanternLiveCard)),
        findsWidgets);
    expect(
        find.descendant(of: view, matching: find.byType(LanternChannelCard)),
        findsWidgets);
    await app.close();
  });

  testWidgets('the hero opens the first live room', (tester) async {
    final app = await LanternApp.start(tester, size: phone, lang: 'en');
    expect(find.text('Watch live now'), findsOneWidget);
    await tester.tap(find.text('Watch live now'));
    await app.settle();
    tester.takeException();
    expect(app.location,
        '/live/lanternLive');
    await app.close();
  });

  testWidgets('nothing live: the quiet card, and Watch is not offered',
      (tester) async {
    final app = await LanternApp.start(tester,
        size: phone, lang: 'en', provider: lanternProvider(live: false));
    expect(
        find.byKey(const ValueKey('lantern-discover-quiet')), findsOneWidget);
    expect(find.text('Nothing is live right now'), findsOneWidget);
    expect(find.byType(LanternLiveCard), findsNothing);
    final watch =
        tester.widget<LButton>(find.widgetWithText(LButton, 'Watch live now'));
    expect(watch.onPressed, isNull);
    await app.close();
  });

  testWidgets('a subject tab filters through the provider', (tester) async {
    final provider = lanternProvider();
    final app = await LanternApp.start(tester,
        size: laptop, lang: 'en', provider: provider);
    final category = provider.academicCategories.where((c) => c.isActive).first;
    expect(provider.currentCategoryFilter, 'all');
    await tester.tap(find.text(category.getLocalizedName('en')).first);
    await app.settle();
    expect(provider.currentCategoryFilter, category.id);
    await tester.tap(find.text('All Categories').first);
    await app.settle();
    expect(provider.currentCategoryFilter, 'all');
    await app.close();
  });

  testWidgets('a search with no match says so and offers to clear it',
      (tester) async {
    final provider = lanternProvider();
    final app = await LanternApp.start(tester,
        size: tallPhone, lang: 'en', provider: provider);
    await tester.enterText(find.byType(TextField).first, 'zzzz-no-such');
    await tester.pump(const Duration(seconds: 1));
    await app.settle();
    expect(provider.searchQuery, 'zzzz-no-such');
    expect(find.text('No streams found'), findsOneWidget);
    await tester.tap(find.widgetWithText(LButton, 'Clear search'));
    await app.settle();
    expect(provider.searchQuery, '');
    expect(find.byType(LanternChannelCard), findsWidgets);
    await app.close();
  });

  testWidgets('channel cards in a row are one height; Follow ends the tags line',
      (tester) async {
    final app = await LanternApp.start(tester, size: tallLaptop, lang: 'ar');
    final cards = find.byType(LanternChannelCard);
    expect(cards, findsWidgets);
    final rects = [
      for (final e in cards.evaluate()) tester.getRect(find.byWidget(e.widget))
    ];
    for (final r in rects) {
      expect(r.height, closeTo(rects.first.height, .5));
    }
    final first = cards.first;
    final follow = find.descendant(
        of: first,
        matching: find.byKey(const ValueKey('lantern-channel-card-follow')));
    if (follow.evaluate().isNotEmpty) {
      final line = tester.getRect(find.descendant(
          of: first,
          matching: find.byKey(const ValueKey('lantern-channel-card-actions'))));
      final button = tester.getRect(follow);
      // On the tags' line, at its end: the left in Arabic.
      expect(button.center.dy, closeTo(line.center.dy, 1));
      expect(button.left, closeTo(line.left, 1));
    }
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a channel card follows and opens the channel', (tester) async {
    final provider = lanternProvider()
      ..debugSetSignedInForTests(
          email: 'viewer@example.invalid', isStreamer: false);
    final app = await LanternApp.start(tester,
        size: tallLaptop, lang: 'en', provider: provider);
    final card = find.byType(LanternChannelCard).first;
    await tester.ensureVisible(card);
    await app.settle(2);
    final streamer = tester.widget<LanternChannelCard>(card).streamer;
    final follow = find.descendant(
        of: card, matching: find.widgetWithText(LButton, 'Follow'));
    expect(follow, findsOneWidget);
    await tester.tap(follow);
    await app.settle();
    tester.takeException();
    expect(provider.isFollowing(streamer.channelProfileId), isTrue);
    await tester.tap(find
        .descendant(of: card, matching: find.byType(LanternChannelAvatar))
        .first);
    await app.settle();
    tester.takeException();
    expect(app.location,
        '/profile/${streamer.channelProfileId}');
    await app.close();
  });

  group('Starting soon', () {
    UpcomingSchedule schedule(String streamerId, DateTime start) =>
        UpcomingSchedule(
            id: 'sch-$streamerId',
            streamerId: streamerId,
            kind: 'once',
            localTime: '20:00',
            weekdays: const [],
            oneTimeStartUtc: start.toUtc(),
            titleEn: 'Tafsir of Juz Amma',
            titleAr: 'تفسير جزء عم',
            descriptionEn: '',
            descriptionAr: '',
            tags: const [],
            colorKey: 'gold');

    test('lists channels that are not live, soonest first, within a week', () {
      final now = DateTime(2026, 11, 11, 18);
      final offline =
          mockStreamers.map((s) => s.copyWith(isCurrentlyLive: false)).toList();
      final live = offline.first.copyWith(isCurrentlyLive: true);
      final next = nextLiveByChannel([
        schedule(offline[1].streamerId, now.add(const Duration(hours: 5))),
        schedule(offline[2].streamerId, now.add(const Duration(minutes: 35))),
        schedule(offline[3].streamerId, now.add(const Duration(days: 9))),
        schedule(live.streamerId, now.add(const Duration(minutes: 5))),
      ], now);
      final soon = lanternSoonOf([live, ...offline.skip(1)], next, now);
      expect(soon.map((e) => e.streamer.streamerId),
          [offline[2].streamerId, offline[1].streamerId]);
    });

    test('counts are written with separators, and a dash when unknown', () {
      expect(lanternCount(1286), '1,286');
      expect(lanternCount(null), '—');
    });

    testWidgets('the card counts down and hands the reminder to its owner',
        (tester) async {
      final streamer = mockStreamers[1].copyWith(isCurrentlyLive: false);
      final start = DateTime.now().add(const Duration(minutes: 35));
      var reminded = 0;
      await pumpLanternWidget(
          tester,
          Center(
              child: SizedBox(
                  width: 360,
                  child: LanternSoonCard(
                      streamer: streamer,
                      schedule: schedule(streamer.streamerId, start),
                      start: start,
                      onRemind: () => reminded++))));
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Starts in'), findsOneWidget);
      expect(find.text('Tafsir of Juz Amma'), findsOneWidget);
      await tester.tap(find.text('Remind me'));
      expect(reminded, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('without push, the reminder button is not shown',
        (tester) async {
      final streamer = mockStreamers[1].copyWith(isCurrentlyLive: false);
      final start = DateTime.now().add(const Duration(hours: 3));
      await pumpLanternWidget(
          tester,
          Center(
              child: SizedBox(
                  width: 360,
                  child: LanternSoonCard(
                      streamer: streamer,
                      schedule: schedule(streamer.streamerId, start),
                      start: start,
                      onRemind: null))));
      expect(find.text('Remind me'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('the lessons row and the map card lead on', (tester) async {
    final app =
        await LanternApp.start(tester, size: tallPhone, lang: 'en');
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('lantern-discover-lessons')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-discover-map')), findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('lantern-discover-map')),
        matching: find.widgetWithText(LButton, 'Open the map')));
    await app.settle();
    tester.takeException();
    expect(app.location, '/map');
    await app.close();
  });
}
