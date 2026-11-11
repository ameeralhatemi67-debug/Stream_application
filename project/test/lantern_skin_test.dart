import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/services/app_skin_preference.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/theme/skin_fonts.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// Lantern and Arch, the third design (ADR-026): how it is chosen and
/// remembered, its theme, its icons, and how its controls behave.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('choosing the design', () {
    test('its stored and linked names are read', () {
      expect(AppSkin.tryParse('lantern-arch'), AppSkin.lantern);
      expect(AppSkin.tryParse('lantern'), AppSkin.lantern);
      expect(AppSkin.tryParse(' lantern-arch '), AppSkin.lantern);
      expect(AppSkin.lantern.id, 'lantern-arch');
      // The older names still mean what they meant.
      expect(AppSkin.tryParse('gold-black'), AppSkin.gold);
      expect(AppSkin.tryParse('hedayah-skin'), AppSkin.hedayah);
      expect(AppSkin.tryParse('something-else'), isNull);
    });

    test('gold & black stays the default', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await readAppSkin(), AppSkin.gold);
    });

    test('a saved choice and a web link are both honoured', () async {
      SharedPreferences.setMockInitialValues({'app_skin': 'lantern-arch'});
      expect(await readAppSkin(), AppSkin.lantern);
      final store = await SharedPreferences.getInstance();
      expect(
          await readAppSkin(
              store: store,
              link: Uri.parse('https://x.test/?skin=lantern-arch#/welcome')),
          AppSkin.lantern);
      expect(store.getString('app_skin'), 'lantern-arch');
    });

    test('day is the default look; night and device are remembered', () async {
      expect(await readLanternAppearance(), LanternAppearance.day);
      await saveLanternAppearance(LanternAppearance.night);
      expect(await readLanternAppearance(), LanternAppearance.night);
      await saveLanternAppearance(LanternAppearance.system);
      expect(await readLanternAppearance(), LanternAppearance.system);
      expect(LanternAppearance.system.isNight(Brightness.dark), isTrue);
      expect(LanternAppearance.system.isNight(Brightness.light), isFalse);
      expect(LanternAppearance.parse('nonsense'), LanternAppearance.day);
      expect(await readLanternCalmMotion(), isFalse);
      await saveLanternCalmMotion(true);
      expect(await readLanternCalmMotion(), isTrue);
    });

    test('the provider keeps skin, look and calm motion', () async {
      final provider = lanternProvider(skin: AppSkin.gold);
      addTearDown(provider.dispose);
      var notified = 0;
      provider.addListener(() => notified++);
      await provider.setAppSkin(AppSkin.lantern);
      await provider.setLanternAppearance(LanternAppearance.night);
      await provider.setLanternCalmMotion(true);
      expect(provider.appSkin, AppSkin.lantern);
      expect(provider.lanternAppearance, LanternAppearance.night);
      expect(provider.lanternCalmMotion, isTrue);
      expect(notified, greaterThanOrEqualTo(3));
      expect(await readAppSkin(), AppSkin.lantern);
      expect(await readLanternAppearance(), LanternAppearance.night);
    });

    test('the heading font loads for Lantern and not for gold', () async {
      SkinFonts.debugReset();
      var loads = 0;
      final bundle = _CountingBundle(() => loads++);
      await SkinFonts.ensureLoaded(AppSkin.gold, bundle: bundle);
      expect(loads, 0);
      await SkinFonts.ensureLoaded(AppSkin.lantern, bundle: bundle);
      await SkinFonts.ensureLoaded(AppSkin.lantern, bundle: bundle);
      expect(loads, 1);
      SkinFonts.debugReset();
    });
  });

  group('theme', () {
    for (final night in [false, true]) {
      test('carries the skin and the ${night ? 'night' : 'day'} tokens', () {
        final theme = LanternSkin.theme(const Locale('ar'), night: night);
        expect(theme.extension<AppSkinTheme>()?.skin, AppSkin.lantern);
        final tokens = theme.extension<LanternTokens>()!;
        expect(tokens.night, night);
        expect(theme.scaffoldBackgroundColor, tokens.bg);
        expect(theme.brightness, night ? Brightness.dark : Brightness.light);
      });
    }

    test('the app-wide theme for the skin is its day set', () {
      final theme = AppTheme.forLocale(const Locale('en'), skin: AppSkin.lantern);
      expect(theme.extension<LanternTokens>(), LanternTokens.day);
      // The other two designs are untouched by the third.
      expect(
          AppTheme.forLocale(const Locale('en'), skin: AppSkin.gold)
              .extension<AppSkinTheme>()
              ?.skin,
          AppSkin.gold);
      expect(
          AppTheme.forLocale(const Locale('en'), skin: AppSkin.hedayah)
              .extension<AppSkinTheme>()
              ?.skin,
          AppSkin.hedayah);
      expect(
          AppTheme.forLocale(const Locale('en'), skin: AppSkin.gold)
              .extension<LanternTokens>(),
          isNull);
    });
  });

  test('every icon of the set has its drawing', () {
    for (final glyph in LGlyph.values) {
      final file = File('assets/lantern/icons/${glyph.name}.svg');
      expect(file.existsSync(), isTrue, reason: '${glyph.name}.svg');
      expect(file.readAsStringSync(), contains('viewBox="0 0 24 24"'));
    }
    expect(Directory('assets/lantern/icons').listSync().length,
        LGlyph.values.length,
        reason: 'no drawing without an icon name');
  });

  group('controls', () {
    for (final (lang, night) in [('en', false), ('ar', false), ('ar', true)]) {
      testWidgets('the kit lays out ($lang, ${night ? 'night' : 'day'})',
          (tester) async {
        var taps = 0;
        await pumpLanternWidget(
            tester,
            SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LSectionHead('Live now', count: '3', isNew: true),
                      for (final kind in LButtonKind.values)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: LButton(
                                label: 'Watch now',
                                kind: kind,
                                icon: LGlyph.live,
                                onPressed: () => taps++)),
                      const LButton(label: 'Off', onPressed: null),
                      LButton(label: 'Busy', loading: true, onPressed: () {}),
                      LHoldButton(label: 'Hold', onConfirmed: () {}),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        LChip(label: 'Fiqh', selected: true, onTap: () {}),
                        LChip(label: 'Tafsir', count: 4, onTap: () {}),
                        const LBadge('LIVE', kind: LBadgeKind.live),
                        const LBadge('AUDIO', kind: LBadgeKind.audio),
                        const LBadge('In 35 min', kind: LBadgeKind.soon),
                        const LBadge('On now', kind: LBadgeKind.now),
                        const LBadge('Offline', kind: LBadgeKind.off),
                        const LTag('Moderator', tone: LTone.mod),
                        const LTag('Broadcaster', tone: LTone.live),
                      ]),
                      LSegmented<int>(segments: const [
                        (value: 0, label: 'Chat', icon: null),
                        (value: 1, label: 'Sources', icon: null),
                        (value: 2, label: 'Venue', icon: null),
                      ], value: 1, onChanged: (_) {}),
                      LSwitch(value: true, label: 'Reminders', onChanged: (_) {}),
                      const LField(
                          hint: 'Search', icon: LGlyph.search, error: 'Needed'),
                      const Row(children: [
                        LAvatar(name: 'الشيخ فهد', ring: LRing.live),
                        SizedBox(width: 8),
                        LAvatar(
                            name: 'Quran', ring: LRing.audio, verified: true),
                        SizedBox(width: 8),
                        LAvatar(name: 'جمعية هداية', org: true),
                      ]),
                      LCard(onTap: () {}, child: const Text('A card')),
                      LRow(
                          title: 'Notifications',
                          subtitle: 'Reminders and alerts',
                          icon: LGlyph.bell,
                          onTap: () {}),
                      const LBanner('Reconnecting', tone: LTone.warn, busy: true),
                      const LSkeleton(width: 200),
                      const LProgress(.4, label: 'Progress'),
                      const LMeter(.6),
                      const LEmptyState(
                          title: 'Nothing here', body: 'Come back tonight.'),
                      const LStarDivider(),
                    ])),
            lang: lang,
            night: night);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Watch now').first);
        expect(taps, 1);
      });
    }

    testWidgets('a held button confirms after the hold and not before',
        (tester) async {
      var confirmed = 0;
      await pumpLanternWidget(
          tester,
          Center(
              child: LHoldButton(
                  label: 'End broadcast', onConfirmed: () => confirmed++)));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('End broadcast')));
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 800));
      expect(confirmed, 0, reason: 'letting go early cancels');

      final second =
          await tester.startGesture(tester.getCenter(find.text('End broadcast')));
      await tester.pump(const Duration(milliseconds: 1250));
      expect(confirmed, 1);
      await second.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(confirmed, 1, reason: 'one hold, one action');
    });

    testWidgets('a held button works from the keyboard', (tester) async {
      var confirmed = 0;
      await pumpLanternWidget(
          tester,
          Center(
              child:
                  LHoldButton(label: 'Go live', onConfirmed: () => confirmed++)));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 700));
      expect(confirmed, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 1250));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pump(const Duration(milliseconds: 300));
      expect(confirmed, 1);
    });

    testWidgets('a held button is one action for a screen reader',
        (tester) async {
      final handle = tester.ensureSemantics();
      var confirmed = 0;
      await pumpLanternWidget(
          tester,
          Center(
              child: LHoldButton(
                  label: 'Delete account', onConfirmed: () => confirmed++)));
      final node = tester.getSemantics(find.byType(LHoldButton));
      expect(node.label, 'Delete account');
      expect(node.hint, 'Press and hold to confirm');
      tester.semantics.longPress(find.semantics.byLabel('Delete account'));
      expect(confirmed, 1);
      handle.dispose();
    });

    testWidgets('a disabled held button does nothing', (tester) async {
      var confirmed = 0;
      await pumpLanternWidget(
          tester,
          Center(
              child: LHoldButton(
                  label: 'Go live',
                  enabled: false,
                  onConfirmed: () => confirmed++)));
      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Go live')));
      await tester.pump(const Duration(milliseconds: 1400));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));
      expect(confirmed, 0);
    });

    testWidgets('the switch reports its state and toggles', (tester) async {
      final handle = tester.ensureSemantics();
      var value = false;
      await pumpLanternWidget(
          tester,
          StatefulBuilder(
              builder: (context, setState) => Center(
                  child: LSwitch(
                      value: value,
                      label: 'Evening digest',
                      onChanged: (v) => setState(() => value = v)))));
      expect(
          tester.getSemantics(find.bySemanticsLabel('Evening digest')),
          isSemantics(
              label: 'Evening digest',
              hasToggledState: true,
              isToggled: false,
              hasTapAction: true,
              isEnabled: true));
      await tester.tap(find.byType(LSwitch));
      await tester.pump();
      expect(value, isTrue);
      handle.dispose();
    });

    testWidgets('motion stops under calm motion and runs without it',
        (tester) async {
      await pumpLanternWidget(tester,
          const Center(child: LBadge('LIVE', kind: LBadgeKind.live)),
          calm: true);
      expect(tester.hasRunningAnimations, isFalse);
      await pumpLanternWidget(tester,
          const Center(child: LBadge('LIVE', kind: LBadgeKind.live)),
          calm: false);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the avatar initial skips an honorific and the article',
        (tester) async {
      expect(LAvatar.initialOf('الشيخ فهد'), 'ش');
      expect(LAvatar.initialOf('د. عبدالله الشهري'), 'ع');
      expect(LAvatar.initialOf('Dr. Yusuf'), 'Y');
      expect(LAvatar.initialOf('القرآن الكريم'), 'ق');
      expect(LAvatar.initialOf(''), '');
      expect(LAvatar.toneOf('a'), inInclusiveRange(0, 4));
    });
  });

  group('in the app', () {
    testWidgets('Settings offers the three designs and Lantern is chosen',
        (tester) async {
      final provider = lanternProvider(skin: AppSkin.gold)
        ..debugSetSignedInForTests(
            email: 'viewer@example.invalid', isStreamer: false);
      final app = await LanternApp.start(tester,
          skin: AppSkin.gold, provider: provider, size: const Size(412, 900));
      await app.push('/settings');
      for (final skin in AppSkin.values) {
        final tile = find.byKey(ValueKey('skin-option-${skin.id}'));
        await tester.scrollUntilVisible(tile, 200,
            scrollable: find
                .descendant(
                    of: find.byType(SettingsScreen),
                    matching: find.byType(Scrollable))
                .first);
        expect(tile, findsOneWidget);
      }
      await tester
          .ensureVisible(find.byKey(const ValueKey('skin-option-lantern-arch')));
      await app.settle(2);
      await tester.tap(find.byKey(const ValueKey('skin-option-lantern-arch')));
      await app.settle();
      expect(provider.appSkin, AppSkin.lantern);
      expect(tester.takeException(), isNull);
      await app.close();
    });

    for (final lang in ['en', 'ar']) {
      testWidgets('switching among the three designs keeps the app whole ($lang)',
          (tester) async {
        final provider = lanternProvider(skin: AppSkin.gold)
          ..debugSetSignedInForTests(
              email: 'viewer@example.invalid', isStreamer: false);
        final app = await LanternApp.start(tester,
            skin: AppSkin.gold,
            provider: provider,
            lang: lang,
            size: const Size(412, 900),
            calm: false);
        for (final skin in [
          AppSkin.lantern,
          AppSkin.gold,
          AppSkin.lantern,
          AppSkin.hedayah,
          AppSkin.lantern,
        ]) {
          await provider.setAppSkin(skin);
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 100));
            final error = tester.takeException();
            if (error != null) fail('after choosing ${skin.id}: $error');
          }
          for (final path in ['/map', '/lessons', '/feed']) {
            app.router.go(path);
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
              final error = tester.takeException();
              if (error != null) fail('${skin.id} at $path: $error');
            }
          }
        }
        expect(find.byType(LanternTabShell), findsOneWidget);
        await app.close();
      });
    }
  });
}

class _CountingBundle extends CachingAssetBundle {
  _CountingBundle(this.onLoad);

  final VoidCallback onLoad;

  @override
  Future<ByteData> load(String key) async {
    onLoad();
    return ByteData.sublistView(
        File('assets/fonts/ReadexPro-Variable.ttf').readAsBytesSync());
  }
}
