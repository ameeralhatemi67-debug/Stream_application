import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/live_stream/services/chat_block_list.dart';
import 'package:streamer_app/features/profile/presentation/lantern/lantern_settings_sections.dart';
import 'package:streamer_app/features/profile/presentation/lantern/lantern_settings_view.dart';
import 'package:streamer_app/features/profile/presentation/settings/blocked_accounts_sheet.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';

import 'fixtures/streamer_fixtures.dart';
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
      for (final skin in AppSkin.values) {
        expect(find.byKey(ValueKey('skin-option-${skin.id}')), findsOneWidget);
      }
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
      await tester.tap(find.byKey(const ValueKey('skin-option-gold-black')));
      await settle(tester, 2);
      expect(provider.appSkin, AppSkin.gold);
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
}
