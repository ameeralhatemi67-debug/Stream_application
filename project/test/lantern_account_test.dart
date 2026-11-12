import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/providers/app_flags.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/notifications/notification_models.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/services/upcoming_schedule_service.dart';
import 'package:streamer_app/features/discovery/models/bookmark_entry.dart';
import 'package:streamer_app/features/discovery/presentation/lantern/lantern_bookmarks.dart';
import 'package:streamer_app/features/notifications/presentation/lantern/lantern_notifications.dart';
import 'package:streamer_app/features/profile/models/upcoming_schedule.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/lantern/lantern_not_found_page.dart';
import 'package:streamer_app/features/auth/presentation/lantern/lantern_banned_view.dart';
import 'package:streamer_app/features/auth/presentation/lantern/lantern_consent_dialog.dart';
import 'package:streamer_app/features/auth/presentation/lantern/lantern_role_select_view.dart';
import 'package:streamer_app/features/auth/presentation/role_select_screen.dart';
import 'package:streamer_app/features/auth/presentation/screens/account_banned_screen.dart';
import 'package:streamer_app/features/auth/presentation/lantern/lantern_welcome_view.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/live_stream/services/chat_block_list.dart';
import 'package:streamer_app/features/profile/presentation/lantern/lantern_settings_sections.dart';
import 'package:streamer_app/features/profile/presentation/lantern/lantern_settings_view.dart';
import 'package:streamer_app/features/profile/presentation/settings/blocked_accounts_sheet.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';

import 'fixtures/streamer_fixtures.dart';
import 'fixtures/vod_fixtures.dart';
import 'support/empty_broadcasts.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// Settings, welcome and sign-in, notifications, bookmarks and the page
/// that is not found, in Lantern and Arch (ADR-026). The older screens keep
/// their state and actions; these tests check the Lantern layouts, their
/// states, and that the actions reach the same provider methods.

/// Widgets of the older kits (and raw Material controls) that must not be
/// inside a Lantern screen. The Lantern logo and lattice draw the Hedayah
/// rosette and pattern on purpose; those two are allowed.
final _olderKit = find.byWidgetPredicate((w) {
  final name = w.runtimeType.toString();
  if (name == 'HedayahRosette' || name == 'HedayahPattern') return false;
  return RegExp(r'^(Ca|Hidayah|Hedayah|Canopy)[A-Z]').hasMatch(name) ||
      RegExp(r'^T[A-Z][a-z]').hasMatch(name) ||
      const {
        'ElevatedButton',
        'OutlinedButton',
        'TextButton',
        'ListTile',
        'AlertDialog',
        'ChoiceChip',
        'Chip',
        'Checkbox',
        'DropdownButton<int>',
      }.contains(name);
});

/// A provider that counts account deletions instead of calling the server.
class _CountingProvider extends AppProvider {
  int deletes = 0;
  @override
  Future<String?> deleteOwnAccount() async {
    deletes++;
    return 'broadcast_active';
  }
}

AppProvider _signedIn(
    {bool streamer = false,
    bool masterAdmin = false,
    LanternAppearance appearance = LanternAppearance.day,
    AppProvider? into}) {
  final provider = (into ?? AppProvider())
    ..restoreAppSkin(AppSkin.lantern, appearance: appearance);
  for (final s in mockStreamers) {
    provider.addStreamerForTests(s);
  }
  return provider
    ..debugSetSignedInForTests(
        email: 'amal@example.invalid',
        name: 'Amal',
        isStreamer: streamer,
        isMasterAdmin: masterAdmin,
        ownedStreamerId: streamer ? 'own-channel' : null);
}

class _Blocks implements ChatBlockStore {
  _Blocks(this.ids);
  final Set<String> ids;
  final removed = <String>[];
  @override
  String? get currentUserId => 'me';
  @override
  Future<Set<String>> fetchBlockedIds(String blockerId) async => {...ids};
  @override
  Future<void> insertBlock(String blockerId, String blockedId) async {}
  @override
  Future<void> deleteBlock(String blockerId, String blockedId) async =>
      removed.add(blockedId);
  @override
  Future<Map<String, String>> resolveNames(List<String> profileIds) async =>
      {for (final id in profileIds) id: 'Name $id'};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const phone = Size(390, 844), laptop = Size(1440, 900);

  Future<void> settle(WidgetTester tester, [int frames = 6]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> openCategory(WidgetTester tester, String id) async {
    await tester.tap(find.byKey(ValueKey('lantern-settings-category-$id')));
    await settle(tester, 3);
  }

  group('settings', () {
    for (final lang in ['en', 'ar']) {
      for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
        for (final night in [false, true]) {
          testWidgets(
              'lays out ($lang, $label, ${night ? 'night' : 'day'})',
              (tester) async {
            final provider = _signedIn(
                appearance:
                    night ? LanternAppearance.night : LanternAppearance.day);
            final app = await LanternApp.start(tester,
                provider: provider,
                lang: lang,
                size: size,
                location: '/settings');
            expect(tester.takeException(), isNull);
            expect(find.byType(LanternSettingsView), findsOneWidget);
            expect(find.byType(LanternAccountCard), findsOneWidget);
            expect(_olderKit, findsNothing);
            if (size == laptop) {
              expect(find.byType(LanternWebHeader), findsOneWidget);
              expect(
                  tester
                      .getSize(
                          find.byKey(const ValueKey('lantern-settings-nav')))
                      .width,
                  Lantern.sideSettings);
              for (final id in [
                'design',
                'notifications',
                'lessons',
                'privacy',
                'terms',
                'about',
                'account',
              ]) {
                await openCategory(tester, id);
                expect(tester.takeException(), isNull, reason: id);
                expect(find.byKey(ValueKey('lantern-settings-pane-$id')),
                    findsOneWidget);
                expect(_olderKit, findsNothing, reason: id);
              }
            } else {
              expect(find.byType(LanternPageBar), findsOneWidget);
              final list = find.byKey(const ValueKey('lantern-settings-phone'));
              for (var i = 0; i < 14; i++) {
                await tester.drag(list, const Offset(0, -500));
                await tester.pump(const Duration(milliseconds: 100));
                expect(tester.takeException(), isNull);
                expect(_olderKit, findsNothing);
              }
              expect(find.byKey(const ValueKey('lantern-settings-about')),
                  findsOneWidget);
            }
            await app.close();
          });
        }
      }
    }

    testWidgets('the account card knows guest, viewer, broadcaster and admin',
        (tester) async {
      // Guest.
      await pumpLanternWidget(tester, const SettingsScreen(), size: laptop);
      expect(tester.takeException(), isNull);
      expect(find.text('Guest — Not Signed In'), findsOneWidget);
      expect(find.text('Sign in as Broadcaster (Google Account)'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-settings-category-privacy')),
          findsNothing,
          reason: 'privacy and data need an account');

      // Viewer.
      await pumpLanternWidget(tester, const SettingsScreen(),
          size: laptop, provider: _signedIn());
      expect(find.text('Viewer / Student'), findsOneWidget);
      expect(find.text('Edit Account Profile'), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-settings-apply')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-settings-studio')),
          findsNothing);

      // Broadcaster.
      final broadcaster = _signedIn(streamer: true);
      await pumpLanternWidget(tester, const SettingsScreen(),
          size: laptop, provider: broadcaster);
      expect(find.text('Broadcaster'), findsWidgets);
      expect(find.byKey(const ValueKey('lantern-settings-studio')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-settings-application')),
          findsOneWidget);
      final role = tester.widget<LSwitch>(
          find.byKey(const ValueKey('lantern-settings-role-switch')));
      expect(role.value, isTrue);
      role.onChanged!(false);
      expect(broadcaster.isStreamerModeEnabled, isFalse,
          reason: 'the switch calls setRoleMode');

      // Master admin.
      await pumpLanternWidget(tester, const SettingsScreen(),
          size: laptop, provider: _signedIn(masterAdmin: true));
      expect(find.text('Master admin'), findsOneWidget);
      await openCategory(tester, 'terms');
      expect(find.byKey(const ValueKey('lantern-settings-admin')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-settings-legal')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('design: the three designs, day or night, and calm motion',
        (tester) async {
      final provider = await pumpLanternWidget(tester, const SettingsScreen(),
          size: laptop, provider: _signedIn());
      await openCategory(tester, 'design');
      expect(find.byKey(const ValueKey('lantern-settings-design')),
          findsOneWidget);
      for (final skin in AppSkin.choices) {
        expect(find.byKey(ValueKey('skin-option-${skin.id}')), findsOneWidget);
      }
      // Gold & black is no longer offered (ADR-027).
      expect(find.byKey(const ValueKey('skin-option-gold-black')), findsNothing);
      expect(find.text('In use'), findsOneWidget);
      await tester.tap(find.text('Night'));
      await settle(tester, 2);
      expect(provider.lanternAppearance, LanternAppearance.night);
      await tester.tap(find.text('Follow the device'));
      await settle(tester, 2);
      expect(provider.lanternAppearance, LanternAppearance.system);
      await tester.tap(find.byKey(const ValueKey('lantern-settings-calm')));
      await settle(tester, 2);
      expect(provider.lanternCalmMotion, isTrue);
      expect(find.byKey(const ValueKey('lantern-settings-language')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('skin-option-hedayah-skin')));
      await settle(tester, 2);
      expect(provider.appSkin, AppSkin.hedayah);
      expect(tester.takeException(), isNull);
    });

    testWidgets('notifications: the limit and the categories reach the provider',
        (tester) async {
      final provider = await pumpLanternWidget(tester, const SettingsScreen(),
          size: laptop, provider: _signedIn());
      await openCategory(tester, 'notifications');
      expect(find.byKey(const ValueKey('lantern-settings-limit')),
          findsOneWidget);
      expect(provider.notificationPreferences.liveVideoEnabled, isTrue);
      final live = find.widgetWithText(LRow, 'Live Video Broadcasts');
      await tester.tap(find.descendant(of: live, matching: find.byType(LSwitch)));
      await settle(tester, 2);
      expect(provider.notificationPreferences.liveVideoEnabled, isFalse);
      tester
          .widget<LSlider>(find.byKey(const ValueKey('lantern-settings-limit')))
          .onChanged!(7);
      await settle(tester, 2);
      expect(provider.notificationPreferences.maxPer10Min, 7);
      expect(find.byKey(const ValueKey('lantern-settings-blocked')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('delete my account is press-and-hold in a Lantern dialog',
        (tester) async {
      final provider = _signedIn(into: _CountingProvider()) as _CountingProvider;
      await pumpLanternWidget(tester, const SettingsScreen(),
          size: laptop, provider: provider);
      await openCategory(tester, 'privacy');
      expect(find.byType(LanternPrivacyView), findsNWidgets(2));
      await tester.tap(find.byKey(const ValueKey('lantern-settings-delete-open')));
      await settle(tester, 3);
      final hold = find.byKey(const ValueKey('lantern-delete-account-hold'));
      expect(hold, findsOneWidget);
      expect(find.text('Delete Your Account?'), findsOneWidget);
      expect(_olderKit, findsNothing);
      // A tap is not enough.
      await tester.tap(hold);
      await settle(tester, 3);
      expect(provider.deletes, 0);
      expect(hold, findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(hold));
      await tester.pump(Lantern.hold + const Duration(milliseconds: 100));
      await gesture.up();
      await settle(tester, 4);
      expect(provider.deletes, 1);
      expect(hold, findsNothing, reason: 'the dialog closed');
      // The refusal is explained as before.
      expect(find.text('End your live broadcast first, then try again.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('blocked accounts load, show and unblock', (tester) async {
      final store = _Blocks({'u1', 'u2'});
      await pumpLanternWidget(
          tester,
          SingleChildScrollView(
              child: LanternSurface(
                  child: BlockedAccountsSheet(
                      blockList: ChatBlockList(store: store)))),
          provider: _signedIn());
      await settle(tester, 3);
      expect(find.byType(LanternBlockedAccounts), findsOneWidget);
      expect(find.text('Name u1'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byKey(const Key('blocked-account-u1')),
          matching: find.text('Unblock')));
      await settle(tester, 3);
      expect(store.removed, ['u1']);
      expect(_olderKit, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('welcome and sign-in', () {
    for (final lang in ['en', 'ar']) {
      for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
        for (final night in [false, true]) {
          testWidgets('lays out ($lang, $label, ${night ? 'night' : 'day'})',
              (tester) async {
            final provider = lanternProvider(
                appearance:
                    night ? LanternAppearance.night : LanternAppearance.day);
            final app = await LanternApp.start(tester,
                provider: provider,
                lang: lang,
                size: size,
                location: '/welcome');
            expect(tester.takeException(), isNull);
            expect(find.byType(LanternWelcomeView), findsOneWidget);
            expect(
                find.byKey(ValueKey(size == laptop
                    ? 'lantern-welcome-wide'
                    : 'lantern-welcome-phone')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('lantern-welcome-brand')),
                findsOneWidget);
            // Who is live now: the sample's first channel.
            expect(find.byKey(const ValueKey('lantern-welcome-live')),
                findsOneWidget);
            expect(find.byKey(const Key('welcome-signup')), findsOneWidget);
            expect(find.byKey(const Key('welcome-guest')), findsOneWidget);
            expect(_olderKit, findsNothing);
            await app.close();
          });
        }
      }
    }

    testWidgets('sign-ups paused: sign up is off, guest and log in stay',
        (tester) async {
      final flags = AppFlags(store: _Flags(open: false));
      await pumpLanternWidget(tester, WelcomeScreen(appFlags: flags),
          size: laptop);
      await settle(tester, 2);
      expect(find.byKey(const Key('registrations-paused-notice')),
          findsOneWidget);
      final signup = find.byKey(const Key('welcome-signup'));
      expect(
          tester
              .widget<LPressable>(
                  find.descendant(of: signup, matching: find.byType(LPressable)))
              .onTap,
          isNull);
      expect(
          tester
              .widget<LButton>(find.byKey(const Key('welcome-guest')))
              .onPressed,
          isNotNull);
      expect(
          tester
              .widget<LButton>(find.byKey(const ValueKey('welcome-login')))
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'the consent gate: Agree stays off until ticked, then the guest '
        'goes on', (tester) async {
      final provider = lanternProvider();
      final app = await LanternApp.start(tester,
          provider: provider, size: phone, location: '/welcome');
      await tester.ensureVisible(find.byKey(const Key('welcome-guest')));
      await app.settle(2);
      await tester.tap(find.byKey(const Key('welcome-guest')));
      await app.settle(4);
      expect(find.byType(LanternConsentDialog), findsOneWidget);
      expect(_olderKit, findsNothing);
      final accept = find.byKey(const ValueKey('lantern-consent-accept'));
      expect(tester.widget<LButton>(accept).onPressed, isNull);
      // The agreement and the buttons stay on screen; the middle scrolls.
      expect(tester.getRect(accept).bottom, lessThanOrEqualTo(844));
      expect(
          tester
              .getRect(find.byKey(const ValueKey('lantern-consent-check')))
              .bottom,
          lessThanOrEqualTo(844));
      // The full policy opens in a Lantern dialog and closes again.
      await tester.ensureVisible(
          find.byKey(const ValueKey('lantern-consent-policy')));
      await app.settle(2);
      await tester.tap(find.byKey(const ValueKey('lantern-consent-policy')));
      await app.settle(3);
      expect(find.text('Privacy Policy'), findsWidgets);
      expect(_olderKit, findsNothing);
      await tester.tap(find.widgetWithText(LButton, 'Close'));
      await app.settle(3);
      await tester.tap(find.byKey(const ValueKey('lantern-consent-check')));
      await app.settle(2);
      expect(tester.widget<LButton>(accept).onPressed, isNotNull);
      await tester.tap(accept);
      await app.settle(6);
      expect(provider.hasAcceptedCurrentConsent, isTrue);
      expect(find.byType(LanternConsentDialog), findsNothing);
      expect(app.location, '/viewer-setup');
      expect(tester.takeException(), isNull);
      await app.close();
    });

    testWidgets('declining the consent keeps the person on the welcome page',
        (tester) async {
      final provider = lanternProvider();
      final app = await LanternApp.start(tester,
          provider: provider, size: laptop, location: '/welcome');
      await tester.tap(find.byKey(const Key('welcome-signup')));
      await app.settle(4);
      expect(find.byType(LanternConsentDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lantern-consent-decline')));
      await app.settle(4);
      expect(find.byType(LanternConsentDialog), findsNothing);
      expect(provider.hasAcceptedCurrentConsent, isFalse);
      expect(app.location, '/welcome');
      expect(tester.takeException(), isNull);
      await app.close();
    });
  });

  group('notifications', () {
    void seed(AppProvider p) {
      final now = DateTime.now();
      p
        ..addEnhancedNotification(AppNotificationModel(
            id: 'org:live-1',
            type: NotificationType.streamerLiveVideo,
            streamerId: mockStreamers.first.streamerId,
            titleEn: 'A scholar is live now',
            titleAr: 'بدأ بث مباشر',
            bodyEn: 'Session twelve',
            bodyAr: 'المجلس الثاني عشر',
            timestamp: now,
            actionUrl: '/settings'))
        ..addEnhancedNotification(AppNotificationModel(
            id: 'org:note-1',
            type: NotificationType.adminNoteToStreamer,
            titleEn: 'A note from the admins',
            titleAr: 'ملاحظة من المشرفين',
            bodyEn: 'Please read it',
            bodyAr: 'يرجى قراءتها',
            timestamp: now.subtract(const Duration(hours: 2))));
    }

    Future<LanternApp> open(WidgetTester tester,
        {String lang = 'en',
        Size size = phone,
        bool night = false,
        bool notices = true}) async {
      final provider = _signedIn(
          appearance: night ? LanternAppearance.night : LanternAppearance.day);
      if (notices) seed(provider);
      final app = await LanternApp.start(tester,
          provider: provider, lang: lang, size: size, location: '/feed');
      openLanternNotifications(tester.element(find.byType(LanternTabShell)));
      await app.settle(4);
      return app;
    }

    for (final lang in ['en', 'ar']) {
      for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
        for (final night in [false, true]) {
          testWidgets('lay out ($lang, $label, ${night ? 'night' : 'day'})',
              (tester) async {
            final app =
                await open(tester, lang: lang, size: size, night: night);
            expect(tester.takeException(), isNull);
            expect(find.byType(LanternNotificationsBody), findsOneWidget);
            expect(find.byKey(const ValueKey('lantern-notice-org:live-1')),
                findsOneWidget);
            // A panel from the end side on the website layout, a sheet on a
            // phone.
            expect(find.byType(BottomSheet),
                size == phone ? findsOneWidget : findsNothing);
            expect(_olderKit, findsNothing);
            await app.close();
          });
        }
      }
    }

    testWidgets('filter, mute, dismiss and mark all read reach the provider',
        (tester) async {
      final app = await open(tester, size: laptop);
      final provider = app.provider;
      expect(provider.unreadNotificationsCount, 2);
      expect(find.byKey(const ValueKey('lantern-notifications-unread')),
          findsOneWidget);
      await tester.tap(find.byKey(
          const ValueKey('lantern-notifications-filter-invitesAndAdmin')));
      await app.settle(2);
      expect(find.byKey(const ValueKey('lantern-notice-org:live-1')),
          findsNothing);
      expect(find.byKey(const ValueKey('lantern-notice-org:note-1')),
          findsOneWidget);
      await tester.tap(
          find.byKey(const ValueKey('lantern-notifications-filter-all')));
      await app.settle(2);
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('lantern-notice-org:live-1')),
          matching: find.text('Mute')));
      await app.settle(2);
      expect(provider.isEntityMuted(mockStreamers.first.streamerId), isTrue);
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('lantern-notice-org:note-1')),
          matching: find.byType(LIconButton)));
      await app.settle(2);
      expect(provider.enhancedNotifications.map((n) => n.id),
          isNot(contains('org:note-1')));
      await tester.tap(
          find.byKey(const ValueKey('lantern-notifications-read-all')));
      await app.settle(2);
      expect(provider.unreadNotificationsCount, 0);
      expect(tester.takeException(), isNull);
      await app.close();
    });

    testWidgets('a notice opens its target and is marked read',
        (tester) async {
      final app = await open(tester, size: phone);
      await tester.tap(find.byKey(const ValueKey('lantern-notice-org:live-1')));
      await app.settle(6);
      expect(
          app.provider.enhancedNotifications
              .firstWhere((n) => n.id == 'org:live-1')
              .isRead,
          isTrue);
      expect(find.byType(LanternNotificationsBody), findsNothing);
      expect(app.location, '/settings');
      expect(tester.takeException(), isNull);
      await app.close();
    });

    for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
      testWidgets('settings sits beside close and opens Settings at '
          'notifications ($label)', (tester) async {
        final app = await open(tester, size: size);
        final button =
            find.byKey(const ValueKey('lantern-notifications-preferences'));
        expect(button, findsOneWidget);
        // In the title row, before the close button; no text link below.
        final close = find.descendant(
            of: find.ancestor(of: button, matching: find.byType(Row)).first,
            matching: find.byWidgetPredicate(
                (w) => w is LIconButton && w.icon == LGlyph.close));
        expect(close, findsOneWidget);
        expect(find.text('design_copy.notification_preferences'.tr()),
            findsNothing);
        await tester.tap(button);
        await app.settle(10);
        expect(find.byType(LanternNotificationsBody), findsNothing);
        expect(app.location, '/settings');
        expect(
            tester
                .widget<SettingsScreen>(find.byType(SettingsScreen))
                .initialSection,
            'notifications');
        expect(find.byKey(const ValueKey('lantern-settings-notifications')),
            findsOneWidget);
        final head = find.byKey(
            const ValueKey('lantern-settings-section-notifications'));
        if (size == phone) {
          // The phone page scrolled to the section.
          expect(tester.getRect(head).top, lessThan(size.height));
        }
        expect(tester.takeException(), isNull);
        await app.close();
      });
    }

    testWidgets('nothing yet: the empty state', (tester) async {
      final app = await open(tester, size: laptop, notices: false);
      expect(find.byKey(const ValueKey('lantern-notifications-empty')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-notifications-read-all')),
          findsNothing);
      expect(tester.takeException(), isNull);
      await app.close();
    });
  });

  group('bookmarks', () {
    Future<(LanternApp, _Db)> open(WidgetTester tester,
        {String lang = 'en',
        Size size = phone,
        bool night = false,
        bool saved = true,
        bool fail = false}) async {
      final db = _Db();
      final auth = _Auth();
      final provider = AppProvider.withServices(
          adminDbService: db,
          authService: auth,
          upcomingService: _Schedules(),
          organizationBroadcastService: EmptyBroadcasts())
        ..restoreAppSkin(AppSkin.lantern,
            appearance:
                night ? LanternAppearance.night : LanternAppearance.day);
      for (final s in mockStreamers) {
        provider.addStreamerForTests(s);
      }
      provider.debugSetSignedInForTests(
          email: 'amal@example.invalid', name: 'Amal', isStreamer: false);
      if (saved) {
        await tester.runAsync(() async {
          await provider.toggleVodBookmark(_vod);
          await provider.toggleUpcomingBookmark(_schedule());
        });
      }
      final app = await LanternApp.start(tester,
          provider: provider, lang: lang, size: size, location: '/feed');
      // The saved list reads the server only with a session; the items
      // above were saved on this device.
      if (fail) {
        auth.signIn('viewer-1');
        db.fail = true;
      }
      openLanternBookmarks(tester.element(find.byType(LanternTabShell)));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await app.settle(4);
      return (app, db);
    }

    for (final lang in ['en', 'ar']) {
      for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
        for (final night in [false, true]) {
          testWidgets('lay out ($lang, $label, ${night ? 'night' : 'day'})',
              (tester) async {
            final (app, _) =
                await open(tester, lang: lang, size: size, night: night);
            expect(tester.takeException(), isNull);
            expect(find.byType(LanternBookmarksBody), findsOneWidget);
            expect(find.byKey(const ValueKey('lantern-bookmarks-tabs')),
                findsOneWidget);
            // A large dialog on the website layout, a sheet on a phone.
            expect(find.byType(BottomSheet),
                size == phone ? findsOneWidget : findsNothing);
            expect(_olderKit, findsNothing);
            await app.close();
          });
        }
      }
    }

    testWidgets('tabs filter; Remove calls the provider', (tester) async {
      final (app, db) = await open(tester, size: laptop);
      final provider = app.provider;
      expect(provider.bookmarks, hasLength(2));
      final recording = provider.bookmarks
          .firstWhere((b) => b.kind == BookmarkKind.recording);
      final upcoming =
          provider.bookmarks.firstWhere((b) => b.kind == BookmarkKind.upcoming);
      expect(find.text('Play recording'), findsOneWidget);
      expect(find.text('View upcoming stream'), findsOneWidget);
      await tester.tap(find.text('Recordings'));
      await app.settle(2);
      expect(find.byKey(ValueKey('lantern-bookmark-${upcoming.id}')),
          findsNothing);
      expect(find.byKey(ValueKey('lantern-bookmark-${recording.id}')),
          findsOneWidget);
      await tester
          .tap(find.byKey(ValueKey('lantern-bookmark-remove-${recording.id}')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await app.settle(3);
      expect(provider.bookmarks.map((b) => b.id), isNot(contains(recording.id)));
      expect(db.rows, isEmpty, reason: 'saved on this device only');
      expect(tester.takeException(), isNull);
      await app.close();
    });

    testWidgets('an upcoming stream opens its channel', (tester) async {
      final (app, _) = await open(tester, size: phone);
      final upcoming = app.provider.bookmarks
          .firstWhere((b) => b.kind == BookmarkKind.upcoming);
      await tester.ensureVisible(
          find.byKey(ValueKey('lantern-bookmark-open-${upcoming.id}')));
      await tester
          .tap(find.byKey(ValueKey('lantern-bookmark-open-${upcoming.id}')));
      await app.settle(6);
      expect(find.byType(LanternBookmarksBody), findsNothing);
      expect(app.location, '/profile/${upcoming.streamerId}');
      expect(tester.takeException(), isNull);
      await app.close();
    });

    testWidgets('empty, and partly failed with Try again', (tester) async {
      var (app, db) = await open(tester, size: laptop, saved: false);
      expect(find.byKey(const ValueKey('lantern-bookmarks-empty')),
          findsOneWidget);
      await app.close();

      (app, db) = await open(tester, size: laptop, fail: true);
      expect(find.byKey(const ValueKey('lantern-bookmarks-failed')),
          findsOneWidget);
      // What was saved before still shows.
      expect(find.text('Saved lecture'), findsOneWidget);
      db.fail = false;
      await tester.tap(find.text('Try again'));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await app.settle(3);
      expect(find.byKey(const ValueKey('lantern-bookmarks-failed')),
          findsNothing);
      expect(tester.takeException(), isNull);
      await app.close();
    });
  });

  group('role select and suspended account', () {
    for (final lang in ['en', 'ar']) {
      for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
        for (final night in [false, true]) {
          testWidgets(
              'role select lays out ($lang, $label, ${night ? 'night' : 'day'})',
              (tester) async {
            await pumpLanternWidget(tester, const RoleSelectScreen(),
                lang: lang,
                size: size,
                provider: lanternProvider(
                    appearance: night
                        ? LanternAppearance.night
                        : LanternAppearance.day));
            expect(tester.takeException(), isNull);
            expect(find.byType(LanternRoleSelectView), findsOneWidget);
            expect(find.byKey(const ValueKey('role-select-viewer')),
                findsOneWidget);
            expect(find.byKey(const ValueKey('role-select-broadcaster')),
                findsOneWidget);
            expect(find.byKey(const Key('role-select-preacher')),
                findsOneWidget);
            expect(_olderKit, findsNothing);
          });

          testWidgets(
              'the suspended page lays out ($lang, $label, ${night ? 'night' : 'day'})',
              (tester) async {
            await pumpLanternWidget(tester, const AccountBannedScreen(),
                lang: lang,
                size: size,
                provider: lanternProvider(
                    appearance: night
                        ? LanternAppearance.night
                        : LanternAppearance.day));
            await settle(tester, 2);
            expect(tester.takeException(), isNull);
            expect(find.byType(LanternBannedView), findsOneWidget);
            expect(find.byKey(const ValueKey('lantern-banned-sign-out')),
                findsOneWidget);
            expect(_olderKit, findsNothing);
          });
        }
      }
    }

    testWidgets('choosing the viewer role goes on to Discover',
        (tester) async {
      final provider = lanternProvider();
      final app = await LanternApp.start(tester,
          provider: provider, size: phone, location: '/role-select');
      expect(find.byType(LanternRoleSelectView), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('role-select-viewer')),
          matching: find.byType(LButton)));
      await app.settle();
      expect(provider.hasCompletedRoleSelection, isTrue);
      expect(app.location, '/feed');
      expect(tester.takeException(), isNull);
      await app.close();
    });
  });

  group('page not found', () {
    for (final lang in ['en', 'ar']) {
      for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
        testWidgets('an unknown link shows the Lantern page ($lang, $label)',
            (tester) async {
          final app = await LanternApp.start(tester,
              lang: lang, size: size, location: '/nowhere-at-all');
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternNotFoundPage), findsOneWidget);
          expect(find.text('404'), findsOneWidget);
          expect(_olderKit, findsNothing);
          await tester.tap(find.byKey(const ValueKey('lantern-not-found-discover')));
          await app.settle();
          expect(app.location, '/feed');
          expect(tester.takeException(), isNull);
          await app.close();
        });
      }
    }

    testWidgets('the older designs keep their own error page', (tester) async {
      for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
        final app = await LanternApp.start(tester,
            skin: skin, size: phone, location: '/nowhere-at-all');
        tester.takeException();
        expect(find.byType(LanternNotFoundPage), findsNothing);
        expect(find.textContaining('Route Not Found'), findsOneWidget);
        await app.close();
      }
    });
  });
}

final _vod = MockVodArchivePool.sampleVods.first.copyWith(
    vodId: 'vod_yt_bl60n6uuvWE',
    youtubeVideoId: 'bl60n6uuvWE',
    streamerId: mockStreamers.first.streamerId,
    titleEn: 'Saved lecture',
    thumbnailUrl: '');

UpcomingSchedule _schedule() => UpcomingSchedule(
    id: 'schedule-one',
    streamerId: mockStreamers.first.streamerId,
    kind: 'once',
    localTime: '12:00',
    weekdays: const [],
    oneTimeStartUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
    titleEn: 'Upcoming seminar',
    titleAr: 'ندوة قادمة',
    descriptionEn: '',
    descriptionAr: '',
    tags: const [],
    colorKey: 'green');

class _Auth extends SupabaseAuthService {
  Session? session;
  void signIn(String id) {
    session = Session(
        accessToken: 'test-only',
        tokenType: 'bearer',
        user: User(
            id: id,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-06T00:00:00Z'));
  }

  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  Future<void> signOut() async {
    session = null;
  }
}

class _Db extends AdminDatabaseService {
  final rows = <String, BookmarkEntry>{};
  bool fail = false;
  @override
  Future<List<BookmarkEntry>> loadBookmarks() async {
    if (fail) throw StateError('offline');
    return rows.values.toList();
  }

  @override
  Future<void> addBookmark(BookmarkEntry entry) async {
    if (fail) throw StateError('offline');
    rows.putIfAbsent(entry.id, () => entry);
  }

  @override
  Future<void> removeBookmark(String id) async {
    if (fail) throw StateError('offline');
    rows.remove(id);
  }
}

class _Schedules extends UpcomingScheduleService {
  @override
  Future<List<UpcomingSchedule>> load(String id) async => [_schedule()];
}

class _Flags implements AppFlagsStore {
  _Flags({required this.open});
  final bool open;
  @override
  Future<Map<String, ({bool enabled, DateTime? updatedAt})>> fetch() async =>
      {'registrations_open': (enabled: open, updatedAt: null)};
  @override
  Future<void> set(String key, bool enabled, String reason) async {}
}
