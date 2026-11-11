import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_focus_ring.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/hedayah/hedayah_kit.dart';
import '../../../../core/widgets/lantern/lantern_base.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../lantern/lantern_settings_sections.dart';
import '../lantern/lantern_settings_view.dart';

/// Settings → Design: the app's gold & black design, the Hedayah skin
/// (ADR-016) or Lantern and Arch (ADR-026), per device. Each choice is a
/// small picture of itself.
class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.select<AppProvider, AppSkin>((p) => p.appSkin);
    if (context.isLanternSkin) return _buildLantern(context, skin);
    final hedayah = context.isHedayahSkin;
    return CaCard(
        key: const ValueKey('settings-design'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CaIcon(CaGlyph.eye),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
                child: Text('skin.title'.tr(),
                    style: hedayah
                        ? HedayahSkin.displayStyle(16)
                        : Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: AppTheme.spaceXs),
          Text('skin.hint'.tr(), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppTheme.spaceMd),
          // Two tiles to a row, as when there were two designs: the third
          // sits on a second row, so the first two keep their size.
          Semantics(
              explicitChildNodes: true,
              child: LayoutBuilder(builder: (context, box) {
                const gap = AppTheme.spaceMd;
                final width = (box.maxWidth - gap) / 2;
                return Wrap(spacing: gap, runSpacing: gap, children: [
                  for (final option in AppSkin.values)
                    SizedBox(
                        width: width,
                        child: _SkinTile(
                            skin: option,
                            selected: option == skin,
                            onTap: () => _choose(context, option))),
                ]);
              })),
        ]));
  }

  /// Lantern and Arch (ADR-026): the three designs as tiles, then Lantern's
  /// own appearance (day, night or the device's) and calm motion.
  Widget _buildLantern(BuildContext context, AppSkin skin) {
    final (appearance, calm) =
        context.select<AppProvider, (LanternAppearance, bool)>(
            (p) => (p.lanternAppearance, p.lanternCalmMotion));
    final provider = context.read<AppProvider>();
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LanternSkinTiles(
              options: [
                for (final option in AppSkin.values)
                  (skin: option, name: nameOf(option), hint: hintOf(option)),
              ],
              current: skin,
              onChoose: (option) => _choose(context, option)),
          const SizedBox(height: 22),
          LanternAppearanceGroup(
              appearance: appearance,
              calm: calm,
              onAppearance: provider.setLanternAppearance,
              onCalm: provider.setLanternCalmMotion),
        ]);
  }

  static String nameOf(AppSkin skin) => switch (skin) {
        AppSkin.gold => 'skin.gold',
        AppSkin.hedayah => 'skin.hedayah',
        AppSkin.lantern => 'lantern.skin_name',
      }
          .tr();

  static String hintOf(AppSkin skin) => switch (skin) {
        AppSkin.gold => 'skin.gold_hint',
        AppSkin.hedayah => 'skin.hedayah_hint',
        AppSkin.lantern => 'lantern.skin_hint',
      }
          .tr();

  Future<void> _choose(BuildContext context, AppSkin skin) async {
    final provider = context.read<AppProvider>();
    if (provider.appSkin == skin) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await provider.setAppSkin(skin);
    // Pages kept below Settings and styles read without a context follow too.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => LanguageSwitcher.rebuildAll());
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text('skin.changed'.tr(args: [nameOf(skin)]))));
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile(
      {required this.skin, required this.selected, required this.onTap});

  final AppSkin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hedayah = context.isHedayahSkin;
    final accent = hedayah ? HedayahSkin.bronze : AppTheme.primary;
    final radius = hedayah ? HedayahSkin.radiusCard : CanopyRadius.input;
    final name = AppearanceSettingsSection.nameOf(skin);
    return Semantics(
        key: ValueKey('skin-option-${skin.id}'),
        button: true,
        inMutuallyExclusiveGroup: true,
        selected: selected,
        label: name,
        child: CaFocusRing(
            radius: radius,
            child: Material(
                color: AppTheme.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                    side: BorderSide(
                        color: selected
                            ? accent
                            : (hedayah ? HedayahSkin.line : AppTheme.border),
                        width: selected ? 2 : 1)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: onTap,
                    child: ExcludeSemantics(
                        child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spaceSm),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(radius - 4),
                                      child: AspectRatio(
                                          aspectRatio: 1.35,
                                          child: switch (skin) {
                                            AppSkin.gold =>
                                              const _GoldPreview(),
                                            AppSkin.hedayah =>
                                              const _HedayahPreview(),
                                            AppSkin.lantern =>
                                              const _LanternPreview(),
                                          })),
                                  const SizedBox(height: AppTheme.spaceSm),
                                  Row(children: [
                                    _RadioMark(
                                        selected: selected,
                                        color: selected
                                            ? accent
                                            : AppTheme.textMuted),
                                    const SizedBox(width: 6),
                                    Expanded(
                                        child: Text(name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium)),
                                  ]),
                                  const SizedBox(height: 2),
                                  Text(
                                      AppearanceSettingsSection.hintOf(skin),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  if (selected) ...[
                                    const SizedBox(height: 4),
                                    Text('skin.in_use'.tr(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                                color: accent,
                                                fontWeight: FontWeight.w700)),
                                  ],
                                ])))))));
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      width: 18,
      height: 18,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          shape: BoxShape.circle, border: Border.all(color: color, width: 2)),
      child: selected
          ? DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle))
          : null);
}

/// Ivory page under a night band with a minted pill.
class _GoldPreview extends StatelessWidget {
  const _GoldPreview();

  @override
  Widget build(BuildContext context) => const ColoredBox(
      color: HidayahGold.g50,
      child: Column(children: [
        Expanded(
            flex: 5,
            child: DecoratedBox(
                decoration: BoxDecoration(gradient: HidayahGradients.night),
                child:
                    Center(child: _Pill(gradient: HidayahGradients.minted)))),
        Expanded(flex: 6, child: _Cards()),
      ]));
}

/// Mist page under a gold band with the lattice and the rosette.
class _HedayahPreview extends StatelessWidget {
  const _HedayahPreview();

  @override
  Widget build(BuildContext context) => const ColoredBox(
      color: HedayahSkin.mist,
      child: Column(children: [
        Expanded(
            flex: 5,
            child: HedayahGoldBand(
                step: 11,
                child: Center(
                    child:
                        HedayahRosette(size: 26, color: HedayahSkin.paper)))),
        Expanded(flex: 6, child: _Cards(pill: true)),
      ]));
}

/// Linen page under a night band that carries the arch and the star. Drawn
/// with a painter, not with Lantern widgets: this tile also shows in the two
/// older designs, which never build one (ADR-026).
class _LanternPreview extends StatelessWidget {
  const _LanternPreview();

  @override
  Widget build(BuildContext context) => ColoredBox(
      color: LanternTokens.day.bg,
      child: const Column(children: [
        Expanded(
            flex: 5,
            child: ColoredBox(
                color: LanternTokens.nightGround,
                child: Center(
                    child: CustomPaint(
                        size: Size(22, 26), painter: _LanternMark())))),
        Expanded(flex: 6, child: _Cards(pill: true, round: true)),
      ]));
}

class _LanternMark extends CustomPainter {
  const _LanternMark();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(lanternArchPath(rect, bottom: 3),
        Paint()..shader = Lantern.goldFill.createShader(rect));
    const star = Size.square(9);
    canvas
      ..translate((size.width - star.width) / 2, size.height * .46)
      ..drawPath(
          lanternStarPath(star), Paint()..color = LanternTokens.nightGround);
  }

  @override
  bool shouldRepaint(_LanternMark oldDelegate) => false;
}

class _Pill extends StatelessWidget {
  const _Pill({this.gradient, this.color});

  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
      width: 44,
      height: 12,
      decoration: BoxDecoration(
          gradient: gradient,
          color: color,
          borderRadius: BorderRadius.circular(6)));
}

class _Cards extends StatelessWidget {
  const _Cards({this.pill = false, this.round = false});

  final bool pill;

  /// Lantern and Arch: rounder cards.
  final bool round;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          Expanded(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(round ? 8 : 5),
                      boxShadow: const [
                BoxShadow(color: Color(0x14000000), blurRadius: 4)
              ]))),
        ],
        if (pill) ...[
          const SizedBox(height: 5),
          const Center(child: _Pill(color: HedayahSkin.gold)),
        ],
      ]));
}
