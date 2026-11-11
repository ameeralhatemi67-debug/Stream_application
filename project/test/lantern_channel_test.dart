import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/upcoming_schedule_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_fields.dart';
import 'package:streamer_app/core/widgets/ds/ca_feedback.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/profile/models/upcoming_schedule.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/profile/presentation/lantern/lantern_channel_view.dart';
import 'package:streamer_app/features/profile/presentation/lantern/lantern_upcoming_list.dart';
import 'package:streamer_app/features/profile/presentation/widgets/vod_grid_tile.dart';
import 'package:streamer_app/features/web/presentation/hidayah_web_kit.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The channel page in Lantern and Arch (ADR-026): the same data, states and
/// actions as the older channel page, in its own layout.

const _phone = Size(390, 844), _laptop = Size(1440, 900);

const _vods = [
  VodModel(
      vodId: 'v1',
      streamerId: 'prof_alghamdi_01',
      titleEn: 'Explaining Kitab al-Tawhid, session 11',
      titleAr: 'شرح كتاب التوحيد، المجلس 11',
      descriptionEn: '',
      descriptionAr: '',
      youtubeVideoId: 'abcdefghijk',
      durationSeconds: 3492,
      recordedDate: '2026-11-01',
      thumbnailUrl: 'assets/images/avatars/neutral_1.png',
      viewCount: 120),
  VodModel(
      vodId: 'v2',
      streamerId: 'prof_alghamdi_01',
      titleEn: 'The rights of neighbours',
      titleAr: 'حقوق الجار',
      descriptionEn: '',
      descriptionAr: '',
      youtubeVideoId: '',
      durationSeconds: 0,
      recordedDate: '',
      thumbnailUrl: '',
      viewCount: 4),
];

const _playlists = [
  PlaylistModel(
      playlistId: 'p1',
      streamerId: 'prof_alghamdi_01',
      titleEn: 'Ramadan lessons',
      titleAr: 'دروس رمضان',
      descriptionEn: '',
      descriptionAr: '',
      youtubePlaylistUrl: '',
      thumbnailUrl: '',
      videoCount: 22,
      videos: []),
];

UpcomingSchedule _plan(String id, {bool special = false}) => UpcomingSchedule(
      id: id,
      streamerId: mockStreamers.first.streamerId,
      kind: special ? 'once' : 'weekly',
      localTime: '18:40',
      weekdays: special ? const [] : const [1, 4],
      oneTimeStartUtc: special
          ? DateTime.now().toUtc().add(const Duration(days: 3))
          : null,
      titleEn: 'Lecture $id',
      titleAr: 'محاضرة $id',
      descriptionEn: 'About $id',
      descriptionAr: '',
      tags: const [],
      colorKey: 'green',
    );

/// Holds a schedule load open until [release].
class _SlowSchedules extends UpcomingScheduleService {
  final _done = Completer<List<UpcomingSchedule>>();
  void release() => _done.complete(const []);
  @override
  Future<List<UpcomingSchedule>> load(String streamerId) => _done.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final id = mockStreamers.first.streamerId;
  final org = mockStreamers.firstWhere((s) => s.isOrganization);

  AppProvider seeded(
      {LanternAppearance appearance = LanternAppearance.day,
      bool live = true}) {
    final p = lanternProvider(appearance: appearance, live: live);
    p.debugSetUpcomingSchedules(id, [_plan('a'), _plan('b', special: true)]);
    return p;
  }

  /// The archive as if YouTube had answered. The page asks YouTube again
  /// when it opens, which clears what was there, so this runs after.
  Future<void> media(LanternApp app,
      {List<VodModel> vods = _vods,
      List<PlaylistModel> playlists = _playlists}) async {
    app.provider.setStreamerMediaForTests(id,
        vods: vods.toList(), playlists: playlists.toList());
    await app.settle();
  }

  Future<void> openTab(WidgetTester tester, LanternChannelTab tab) async {
    final button =
        find.byKey(ValueKey('lantern-channel-tab-button-${tab.name}'));
    await tester.ensureVisible(button);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
  }

  void expectLanternOnly(WidgetTester tester) {
    final view = find.byType(LanternChannelView);
    for (final type in [
      CaButton,
      CaCard,
      CaAvatar,
      CaSegmentedTabs,
      CaEmptyState,
      CaStatusChip,
      VodGridTile,
      HidayahButton,
    ]) {
      expect(find.descendant(of: view, matching: find.byType(type)),
          findsNothing,
          reason: '$type belongs to the older designs');
    }
  }

  for (final (label, size) in [('phone', _phone), ('laptop', _laptop)]) {
    for (final lang in ['en', 'ar']) {
      for (final night in [false, true]) {
        testWidgets(
            'lays out on a $label in $lang, ${night ? 'night' : 'day'}, every tab',
            (tester) async {
          final app = await LanternApp.start(tester,
              size: size,
              lang: lang,
              location: '/profile/$id',
              provider: seeded(
                  appearance: night
                      ? LanternAppearance.night
                      : LanternAppearance.day));
          await media(app);
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternChannelView), findsOneWidget);
          expect(
              Theme.of(tester.element(find.byKey(const ValueKey('lantern-channel'))))
                  .extension<LanternTokens>()!
                  .night,
              night);
          expect(find.byType(size == _phone ? LanternPageBar : LanternWebHeader),
              findsOneWidget);
          for (final tab in LanternChannelTab.values) {
            await openTab(tester, tab);
            expect(tester.takeException(), isNull, reason: tab.name);
            expect(find.byKey(ValueKey('lantern-channel-tab-${tab.name}')),
                findsOneWidget);
            expectLanternOnly(tester);
          }
          if (size == _laptop) {
            expect(find.byType(LanternWebFooter), findsOneWidget);
            expect(find.byKey(const ValueKey('lantern-channel-side')),
                findsOneWidget);
          }
          await app.close();
        });
      }
    }
  }

  testWidgets('the cover band carries no text; name and counts sit below it',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/profile/$id', provider: seeded());
    await media(app);
    final cover = tester.getRect(find.byKey(const ValueKey('lantern-channel-cover')));
    final identity =
        tester.getRect(find.byKey(const ValueKey('lantern-channel-identity')));
    expect(identity.top, greaterThanOrEqualTo(cover.bottom));
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('lantern-channel-cover')),
            matching: find.byType(Text)),
        findsNothing);
    // The avatar straddles the band's lower edge.
    final avatar =
        tester.getRect(find.byKey(const ValueKey('lantern-channel-avatar')));
    expect(avatar.top, lessThan(cover.bottom));
    expect(avatar.bottom, greaterThan(cover.bottom));
    // Live: the live ring and Watch Live.
    expect(tester.widget<LAvatar>(find.byKey(const ValueKey('lantern-channel-avatar'))).ring,
        LRing.live);
    expect(find.text('2 recordings', findRichText: true), findsOneWidget);
    expect(find.text('1 playlist', findRichText: true), findsOneWidget);
    // The archive opens first, as in the older page; each card opens the
    // recording, and the playlist tab lists the playlists.
    for (final v in _vods) {
      final card = find.byKey(ValueKey('lantern-channel-recording-${v.vodId}'));
      expect(card, findsOneWidget);
      expect(tester.widget<LCard>(card).onTap, isNotNull);
    }
    await openTab(tester, LanternChannelTab.playlists);
    expect(find.byKey(const ValueKey('lantern-channel-playlist-p1')),
        findsOneWidget);
    expect(find.text('22 Lectures'), findsOneWidget);
    await app.close();
  });

  testWidgets('counts are a dash until the archive has loaded, never 0',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/profile/$id', provider: seeded());
    final stats = find.byKey(const ValueKey('lantern-channel-stats'));
    expect(
        find.descendant(of: stats, matching: find.textContaining('—')),
        findsNWidgets(2));
    expect(find.descendant(of: stats, matching: find.textContaining('0')),
        findsNothing);
    // The archive shows the loading blocks, not "nothing here".
    expect(find.byKey(const ValueKey('lantern-channel-loading')), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-channel-no-recordings')),
        findsNothing);
    await app.close();
  });

  testWidgets('empty archive and playlists say so', (tester) async {
    final app = await LanternApp.start(tester,
        location: '/profile/$id', provider: seeded());
    await media(app, vods: const [], playlists: const []);
    expect(find.byKey(const ValueKey('lantern-channel-no-recordings')),
        findsOneWidget);
    await openTab(tester, LanternChannelTab.playlists);
    expect(find.byKey(const ValueKey('lantern-channel-no-playlists')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('Upcoming: loading, then the planned streams in order',
      (tester) async {
    final slow = _SlowSchedules();
    final provider = AppProvider.withServices(
        adminDbService: AdminDatabaseService(null), upcomingService: slow)
      ..restoreAppSkin(AppSkin.lantern);
    for (final s in mockStreamers) {
      provider.addStreamerForTests(s);
    }
    final app = await LanternApp.start(tester,
        location: '/profile/$id?tab=upcoming', provider: provider);
    expect(find.byType(LanternUpcomingList), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-upcoming-loading')), findsOneWidget);
    slow.release();
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-upcoming-empty')), findsOneWidget);
    provider.debugSetUpcomingSchedules(id, [_plan('a'), _plan('b', special: true)]);
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-upcoming-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-upcoming-b')), findsOneWidget);
    expect(find.text('Special'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('Upcoming: the error says so and Try again loads again',
      (tester) async {
    // Without a backend the schedule service fails closed.
    final provider = lanternProvider();
    final app = await LanternApp.start(tester,
        location: '/profile/$id?tab=upcoming', provider: provider);
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-upcoming-error')), findsOneWidget);
    expect(find.text('Schedules could not be loaded. Check your connection.'),
        findsOneWidget);
    final retry = find.widgetWithText(LButton, 'Try again');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-upcoming-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('Watch live opens the same room as the older page',
      (tester) async {
    final app = await LanternApp.start(tester,
        location: '/profile/$id', provider: seeded());
    final watch = find.byKey(const ValueKey('lantern-channel-watch'));
    expect(find.widgetWithText(LButton, 'Watch Live'), findsOneWidget);
    await tester.tap(watch);
    await app.settle();
    expect(app.location, '/live/lanternLive');
    tester.takeException();
    await app.close();
  });

  testWidgets('offline: Set Reminder instead of Watch, the offline badge',
      (tester) async {
    final provider = seeded(live: false)..debugRemindersAvailable = true;
    final app = await LanternApp.start(tester,
        location: '/profile/$id', provider: provider);
    expect(find.byKey(const ValueKey('lantern-channel-watch')), findsNothing);
    expect(find.widgetWithText(LButton, 'Set Reminder'), findsOneWidget);
    expect(find.widgetWithText(LBadge, 'Offline'), findsOneWidget);
    await app.close();
  });

  testWidgets('Follow follows; unfollowing asks first', (tester) async {
    final provider = seeded();
    final app = await LanternApp.start(tester,
        location: '/profile/$id', provider: provider);
    final follow = find.byKey(const ValueKey('lantern-channel-follow'));
    expect(provider.isFollowing(id), isFalse);
    await tester.tap(follow);
    await app.settle();
    expect(provider.isFollowing(id), isTrue);
    expect(find.widgetWithText(LButton, 'Following'), findsOneWidget);

    await tester.tap(follow);
    await app.settle();
    expect(find.text('Unfollow this channel?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lantern-channel-keep-following')));
    await app.settle();
    expect(provider.isFollowing(id), isTrue);

    await tester.tap(follow);
    await app.settle();
    await tester.tap(find.byKey(const ValueKey('lantern-channel-unfollow')));
    await app.settle();
    expect(provider.isFollowing(id), isFalse);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('the owner gets the studio and planned-stream tools',
      (tester) async {
    final provider = seeded()
      ..debugSetSignedInForTests(
          email: 'owner@example.invalid', ownedStreamerId: id);
    final app = await LanternApp.start(tester,
        location: '/profile/$id?tab=upcoming', provider: provider);
    expect(find.byKey(const ValueKey('lantern-channel-studio')), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-upcoming-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-upcoming-edit-a')), findsOneWidget);
    await app.close();
  });

  testWidgets('a viewer gets no studio', (tester) async {
    final app = await LanternApp.start(tester,
        location: '/profile/$id', provider: seeded());
    expect(find.byKey(const ValueKey('lantern-channel-studio')), findsNothing);
    expect(find.byKey(const ValueKey('lantern-upcoming-add')), findsNothing);
    await app.close();
  });

  for (final size in [_phone, _laptop]) {
    testWidgets('an organization shows its featured channels (${size.width})',
        (tester) async {
      final app = await LanternApp.start(tester,
          size: size, location: '/profile/${org.streamerId}');
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lantern-channel-featured')),
          findsOneWidget);
      final first = org.affiliatedSpeakers.first;
      final row = find.byKey(ValueKey('lantern-channel-speaker-${first.speakerId}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await app.settle();
      expect(find.text('Active Filter'), findsOneWidget);
      if (org.venues.isNotEmpty) {
        expect(find.byKey(const ValueKey('lantern-channel-branches')),
            findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await app.close();
    });
  }

  testWidgets('an unknown channel shows the unavailable state',
      (tester) async {
    final app = await LanternApp.start(tester, location: '/profile/nobody');
    expect(find.byKey(const ValueKey('lantern-channel-unavailable')),
        findsOneWidget);
    expect(find.text('Channel unavailable.'), findsWidgets);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('the older designs build none of it', (tester) async {
    for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
      final provider = lanternProvider(skin: skin)
        ..setStreamerMediaForTests(id,
            vods: _vods.toList(), playlists: _playlists.toList());
      final app = await LanternApp.start(tester,
          skin: skin, provider: provider, location: '/profile/$id');
      tester.takeException();
      expect(find.byType(BroadcasterProfileScreen), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is LanternSkinWidget),
          findsNothing,
          reason: skin.name);
      await app.close();
    }
  });
}
