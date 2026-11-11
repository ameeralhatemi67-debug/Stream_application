import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_discovery.dart';
import 'package:streamer_app/core/widgets/ds/ca_feedback.dart';
import 'package:streamer_app/core/widgets/ds/ca_fields.dart';
import 'package:streamer_app/core/widgets/ds/ca_icon.dart';
import 'package:streamer_app/core/widgets/ds/ca_rows.dart';
import 'package:streamer_app/core/widgets/ds/ca_surfaces.dart';
import 'package:streamer_app/core/widgets/hadayah_loading_indicator.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/core/widgets/lantern/lantern_compat.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_kit.dart';
import 'package:streamer_app/features/web/presentation/hidayah_web_header.dart';
import 'package:streamer_app/features/web/presentation/hidayah_web_kit.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The shared kits of the older screens draw as Lantern under the Lantern
/// design, keep their callbacks, and show no Lantern widget in the two
/// older designs (ADR-026).

typedef _Case = ({
  String name,
  Type outer,
  Type lantern,
  Widget Function(VoidCallback hit) build,
  Future<void> Function(WidgetTester tester)? act,
  bool wide,
});

_Case _c(String name, Type outer, Type lantern,
        Widget Function(VoidCallback hit) build,
        {Future<void> Function(WidgetTester tester)? act, bool wide = false}) =>
    (
      name: name,
      outer: outer,
      lantern: lantern,
      build: build,
      act: act,
      wide: wide
    );

Future<void> _tapType(WidgetTester tester, Type type) async {
  await tester.tap(find.byType(type).first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 50));
}

final _cases = <_Case>[
  // ------------------------------------------------------------- ds kit
  _c('CaButton', CaButton, LButton,
      (hit) => CaButton(label: 'Go', icon: CaGlyph.play, onPressed: hit),
      act: (t) => _tapText(t, 'Go')),
  _c('CaIcon', CaIcon, LIcon, (_) => const CaIcon(CaGlyph.gear)),
  _c('CaIconButton', CaIconButton, LIconButton,
      (hit) => CaIconButton(icon: CaGlyph.bell, label: 'Bell', onPressed: hit),
      act: (t) => _tapType(t, LIconButton)),
  _c('CaLanguageChip', CaLanguageChip, LChip, (_) => const CaLanguageChip()),
  _c('CaCard', CaCard, LCard,
      (hit) => CaCard(onTap: hit, child: const Text('card')),
      act: (t) => _tapText(t, 'card')),
  _c('CaStatusChip', CaStatusChip, LBadge,
      (_) => const CaStatusChip(kind: CaStatusKind.live)),
  _c('CaStatusChip verified', CaStatusChip, LTag,
      (_) => const CaStatusChip(kind: CaStatusKind.verified)),
  _c('CaAvatar', CaAvatar, LAvatar,
      (_) => const CaAvatar(name: 'Fahd', live: true, verified: true)),
  _c('CaVerifiedBadge', CaVerifiedBadge, LanternVerifiedSeal,
      (_) => const CaVerifiedBadge()),
  _c('CaPersonRow', CaPersonRow, LRow,
      (hit) => CaPersonRow(name: 'Fahd', subtitle: 'Riyadh', onTap: hit),
      act: (t) => _tapText(t, 'Fahd')),
  _c('CaScholarCard', CaScholarCard, LCard,
      (hit) => CaScholarCard(
          name: 'Fahd', subtitle: 'Fiqh', live: true, onTap: hit),
      act: (t) => _tapText(t, 'Fiqh')),
  _c('CaLectureTile', CaLectureTile, LCard,
      (hit) => CaLectureTile(
          title: 'Lecture', meta: 'Today', duration: '12:00', onTap: hit),
      act: (t) => _tapText(t, 'Lecture')),
  _c('CaCardImage', CaCardImage, LanternCardImage,
      (_) => const SizedBox(height: 80, child: CaCardImage())),
  _c('CaHeroCard', CaHeroCard, LButton,
      (hit) => CaHeroCard(
          title: 'Hero',
          presenter: 'Fahd',
          action: 'Watch',
          height: 220,
          viewerLabel: '12 watching',
          onTap: hit),
      act: (t) => _tapText(t, 'Watch')),
  _c('CaChipRow', CaChipRow, LChip,
      (hit) => CaChipRow(children: [
            CaChip(label: 'Fiqh', onSelected: (_) => hit()),
            const CaChip(label: 'Seerah'),
          ]),
      act: (t) => _tapText(t, 'Fiqh')),
  _c('CaChatBubble', CaChatBubble, LanternChatBubble,
      (hit) => CaChatBubble(
          name: 'Fahd',
          message: 'Peace be upon you',
          time: '10:00',
          role: CaChatRole.moderator,
          onAvatarTap: hit),
      act: (t) => _tapType(t, LAvatar)),
  _c('CaToast', CaToast, LanternToastCard,
      (hit) => CaToast(title: 'Saved', message: 'Done', onTap: hit),
      act: (t) => _tapText(t, 'Saved')),
  _c('CaSkeleton', CaSkeleton, LSkeleton,
      (_) => const CaSkeleton(shape: CaSkeletonShape.row)),
  _c('CaEmptyState', CaEmptyState, LEmptyState,
      (hit) => CaEmptyState(
          title: 'Nothing',
          body: 'Empty',
          action: CaButton(label: 'Retry', onPressed: hit)),
      act: (t) => _tapText(t, 'Retry')),
  _c('CaChip', CaChip, LChip,
      (hit) => CaChip(label: 'Fiqh', onSelected: (_) => hit()),
      act: (t) => _tapText(t, 'Fiqh')),
  _c('CaSegmentedTabs', CaSegmentedTabs, LSegmented<int>,
      (hit) => CaSegmentedTabs(
          labels: const ['One', 'Two'],
          index: 0,
          onChanged: (i) {
            if (i == 1) hit();
          }),
      act: (t) => _tapText(t, 'Two')),
  _c('CaInput', CaInput, LanternInput,
      (hit) => CaInput(label: 'Name', onChanged: (_) => hit()),
      act: (t) async {
    await t.enterText(find.byType(TextFormField), 'x');
    await t.pump();
  }),
  _c('CaSearchField', CaSearchField, LanternInput,
      (hit) => CaSearchField(label: 'Search', filterLabel: 'Filter', onFilter: hit),
      act: (t) => _tapType(t, LIconButton)),
  _c('CaSwitch', CaSwitch, LSwitch,
      (hit) => CaSwitch(value: false, onChanged: (_) => hit()),
      act: (t) => _tapType(t, LSwitch)),
  _c('CaStepper', CaStepper, LanternStepBars,
      // ignore: prefer_const_constructors
      (_) => CaStepper(steps: const ['A', 'B', 'C'], index: 1)),
  _c('CaKpiTile', CaKpiTile, LCard,
      (_) => const CaKpiTile(label: 'Viewers', value: '12')),
  _c('CaSettingsRow', CaSettingsRow, LRow,
      (hit) => CaSettingsRow(title: 'Language', icon: CaGlyph.globe, onTap: hit),
      act: (t) => _tapText(t, 'Language')),
  _c('CaQualityPresets', CaQualityPresets<int>, LanternQualityPresets<int>,
      (hit) => CaQualityPresets<int>(
          options: const [
            (value: 0, label: 'Low', detail: '480p'),
            (value: 1, label: 'High', detail: '1080p'),
          ],
          value: 0,
          onChanged: (v) {
            if (v == 1) hit();
          }),
      act: (t) => _tapText(t, 'High')),
  _c('CaBanner', CaBanner, LBanner,
      (_) => const CaBanner(message: 'Careful', kind: CaBannerKind.warning)),
  _c('CaSheet', CaSheet, LanternSheetFrame,
      (hit) => SizedBox(
          height: 500,
          child: CaSheet(title: 'Sheet', body: const Text('body'), onClose: hit)),
      act: (t) => _tapType(t, LIconButton)),
  _c('CaDialog', CaDialog, LanternDialogFrame,
      (hit) => CaDialog(title: 'Dialog', body: const Text('body'), onClose: hit),
      act: (t) => _tapType(t, LIconButton)),
  _c('HadayahLoadingIndicator', HadayahLoadingIndicator, LStarLoader,
      (_) => const HadayahLoadingIndicator()),
  // ------------------------------------------------------------ web kit
  _c('HidayahButton', HidayahButton, LButton,
      (hit) => HidayahButton(label: 'Join', onPressed: hit),
      act: (t) => _tapText(t, 'Join')),
  _c('HidayahCard', HidayahCard, LCard,
      (hit) => HidayahCard(onTap: hit, child: const Text('web card')),
      act: (t) => _tapText(t, 'web card')),
  _c('HidayahNightBand', HidayahNightBand, LNightBand,
      (_) => const HidayahNightBand(child: SizedBox(height: 60))),
  _c('HidayahSectionHeader', HidayahSectionHeader, LSectionHead,
      (hit) => HidayahSectionHeader(
          title: 'Live', count: 3, action: 'All', onAction: hit),
      act: (t) => _tapText(t, 'All')),
  _c('HidayahLiveBadge', HidayahLiveBadge, LBadge,
      (_) => const HidayahLiveBadge(label: 'LIVE')),
  _c('HidayahGlassBadge', HidayahGlassBadge, LBadge,
      (_) => const HidayahGlassBadge(label: '12', icon: CaGlyph.eye)),
  _c('HidayahTag', HidayahTag, LTag, (_) => const HidayahTag('fiqh')),
  _c('HidayahGiltUnderline', HidayahGiltUnderline, LanternGiltUnderline,
      (_) => const HidayahGiltUnderline(visible: true)),
  _c('HidayahTab', HidayahTab, LanternUnderlineTab,
      (hit) => HidayahTab(label: 'Tab', selected: true, count: 2, onTap: hit),
      act: (t) => _tapText(t, 'Tab')),
  _c('HidayahDateBlock', HidayahDateBlock, LanternDateBlock,
      (_) => const HidayahDateBlock(month: 'Nov', day: '11')),
  _c('HidayahForwardIcon', HidayahForwardIcon, LIcon,
      (_) => const HidayahForwardIcon()),
  _c('HidayahMeta', HidayahMeta, LIcon,
      (_) => const HidayahMeta(icon: CaGlyph.pin, text: 'Riyadh')),
  _c('HidayahLattice', HidayahLattice, LanternLatticePaint,
      (_) => const SizedBox(height: 60, child: HidayahLattice())),
  _c('HidayahWebHeader', HidayahWebHeader, LanternWebHeader,
      (hit) => HidayahWebHeader(
          active: HidayahWebSection.map,
          onBranch: (i) {
            if (i == 0) hit();
          }),
      act: (t) => _tapText(t, 'web.nav_discover'.tr()),
      wide: true),
  _c('HidayahWebFooter', HidayahWebFooter, LanternWebFooter,
      (_) => const HidayahWebFooter(),
      wide: true),
  // -------------------------------------------------------- lessons kit
  _c('TButton', TButton, LButton,
      (hit) => TButton('Remind', kind: TBtn.minted, icon: TGlyph.bell, onPressed: hit),
      act: (t) => _tapText(t, 'Remind')),
  _c('TIconButton', TIconButton, LIconButton,
      (hit) => TIconButton(TGlyph.bell, tooltip: 'Alerts', badge: 2, onPressed: hit),
      act: (t) => _tapType(t, LIconButton)),
  _c('TTag', TTag, LTag, (_) => const TTag('Fiqh', tone: TTone.success)),
  _c('TLiveTag', TLiveTag, LBadge, (_) => const TLiveTag()),
  _c('TChip', TChip, LChip,
      (hit) => TChip('Today', count: 3, onTap: hit),
      act: (t) => _tapText(t, 'Today')),
  _c('TChips', TChips, LChip, (_) => const TChips([TChip('A'), TChip('B')])),
  _c('TSeg', TSeg<int>, LSegmented<int>,
      (hit) => TSeg<int>(
          options: const [TSegOption(0, 'Week'), TSegOption(1, 'Month')],
          value: 0,
          onChanged: (v) {
            if (v == 1) hit();
          }),
      act: (t) => _tapText(t, 'Month')),
  _c('TTabs', TTabs<int>, LanternTabBar<int>,
      (hit) => TTabs<int>(
          options: const [TSegOption(0, 'Upcoming'), TSegOption(1, 'Past')],
          value: 0,
          onChanged: (v) {
            if (v == 1) hit();
          }),
      act: (t) => _tapText(t, 'Past')),
  _c('TCard', TCard, LCard,
      (hit) => TCard(onTap: hit, child: const Text('lesson card')),
      act: (t) => _tapText(t, 'lesson card')),
  _c('TNight', TNight, LNightBand,
      (_) => const TNight(child: SizedBox(height: 60))),
  _c('TEyebrow', TEyebrow, LanternEyebrow, (_) => const TEyebrow('Programme')),
  _c('TSectionHead', TSectionHead, LSectionHead,
      (_) => const TSectionHead('This week', count: 4, eyebrow: 'Lessons')),
  _c('TPageHead', TPageHead, LanternPageHeading,
      (_) => const TPageHead(title: 'Lessons', subtitle: 'In mosques')),
  _c('TEmpty', TEmpty, LEmptyState,
      (_) => const TEmpty(title: 'No lessons', body: 'Try later')),
  _c('TMeter', TMeter, LProgress, (_) => const TMeter(value: 3, max: 10)),
  _c('TCallout', TCallout, LanternCallout,
      (_) => const TCallout(
          tone: TTone.warning, icon: TGlyph.alert, child: Text('Note'))),
  _c('TAvatar', TAvatar, LAvatar, (_) => const TAvatar(name: 'الشيخ فهد')),
  _c('TCover', TCover, LanternCover,
      (_) => const TCover(seed: 'x', glyph: TGlyph.book, word: 'Fiqh')),
  _c('TToggleRow', TToggleRow, LSwitch,
      (hit) => TToggleRow(label: 'Remind me', value: false, onChanged: (_) => hit()),
      act: (t) => _tapType(t, LSwitch)),
  _c('TField', TField, LanternInput,
      (_) => const TField(label: 'Title', child: TSearchBox(hint: 'Search'))),
  _c('TSearchBox', TSearchBox, LanternInput,
      (hit) => TSearchBox(hint: 'Search', onChanged: (_) => hit()),
      act: (t) async {
    await t.enterText(find.byType(TextFormField), 'x');
    await t.pump();
  }),
  _c('TStatTiles', TStatTiles, LanternStatTiles,
      (_) => const TStatTiles([('12', 'Lessons'), ('3', 'Mosques')])),
  _c('TOptionRow', TOptionRow, LanternOptionRow,
      (hit) => TOptionRow(title: 'Fajr', selected: false, onTap: hit),
      act: (t) => _tapText(t, 'Fajr')),
  _c('TStepper', TStepper, LanternStepDots,
      (_) => const TStepper(labels: ['One', 'Two', 'Three'], current: 1)),
  _c('TIcon', TIcon, LIcon, (_) => const TIcon(TGlyph.mosque)),
];

/// One widget in any design, the way the app themes it.
Future<void> _pump(WidgetTester tester, Widget child,
    {required AppSkin skin, String lang = 'en', bool wide = false}) async {
  tester.view.physicalSize = wide ? const Size(1440, 900) : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final app = lanternProvider(skin: skin);
  addTearDown(app.dispose);
  await tester.pumpWidget(EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
          value: app,
          child: Builder(
              builder: (context) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.forLocale(context.locale, skin: skin),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(disableAnimations: true),
                      child: child!),
                  home: Scaffold(
                      body: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 700),
                              child: child))))))));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every shared icon maps to a Lantern icon that has its drawing', () {
    for (final g in CaGlyph.values) {
      final l = lanternGlyphFor(g);
      expect(File('assets/lantern/icons/${l.name}.svg').existsSync(), isTrue,
          reason: '$g -> $l');
    }
    for (final g in TGlyph.values) {
      final l = lanternGlyphForT(g);
      expect(File('assets/lantern/icons/${l.name}.svg').existsSync(), isTrue,
          reason: '$g -> $l');
    }
  });

  for (final lang in ['en', 'ar']) {
    for (final c in _cases) {
      testWidgets('${c.name} draws as Lantern ($lang)', (tester) async {
        var hits = 0;
        await _pump(tester, c.build(() => hits++),
            skin: AppSkin.lantern, lang: lang, wide: c.wide);
        expect(tester.takeException(), isNull);
        expect(
            find.descendant(
                of: find.byType(c.outer), matching: find.byType(c.lantern)),
            findsWidgets);
        if (c.act != null) {
          await c.act!(tester);
          expect(hits, greaterThan(0), reason: 'the callback still fires');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a hold-to-confirm button fires only after the hold',
      (tester) async {
    var hits = 0;
    await _pump(
        tester,
        CaButton(
            label: 'End',
            holdToConfirm: true,
            variant: CaButtonVariant.destructive,
            onPressed: () => hits++),
        skin: AppSkin.lantern);
    expect(
        find.descendant(
            of: find.byType(CaButton), matching: find.byType(LHoldButton)),
        findsOneWidget);
    await tester.tap(find.text('End'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(hits, 0, reason: 'a tap is not a hold');
    final gesture = await tester.startGesture(tester.getCenter(find.text('End')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(hits, 0);
    await tester.pump(const Duration(milliseconds: 800));
    expect(hits, 1);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
  });

  for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
    testWidgets('${skin.id} draws the shared kits with no Lantern widget',
        (tester) async {
      for (final c in _cases) {
        await _pump(tester, c.build(() {}),
            skin: skin, lang: 'ar', wide: c.wide);
        tester.takeException();
        expect(find.byType(c.outer), findsWidgets, reason: c.name);
        expect(tester.allWidgets.whereType<LanternSkinWidget>(), isEmpty,
            reason: '${c.name} in ${skin.id}');
      }
      expect(ActiveSkin.current, skin);
    });
  }
}
