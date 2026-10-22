import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_focus_ring.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/hedayah/hedayah_kit.dart';
import '../../../../core/widgets/language_switcher.dart';

/// Settings → Design: the app's gold & black design or the Hedayah skin
/// (ADR-016), per device. Each choice is a small picture of itself.
class AppearanceSettingsSection extends StatelessWidget {
  const AppearanceSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.select<AppProvider, AppSkin>((p) => p.appSkin);
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
          Semantics(
              explicitChildNodes: true,
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final option in AppSkin.values) ...[
                  if (option != AppSkin.values.first)
                    const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                      child: _SkinTile(
                          skin: option,
                          selected: option == skin,
                          onTap: () => _choose(context, option))),
                ],
              ])),
        ]));
  }

  static String nameOf(AppSkin skin) =>
      (skin == AppSkin.hedayah ? 'skin.hedayah' : 'skin.gold').tr();

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
                                          child: skin == AppSkin.hedayah
                                              ? const _HedayahPreview()
                                              : const _GoldPreview())),
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
                                      (skin == AppSkin.hedayah
                                              ? 'skin.hedayah_hint'
                                              : 'skin.gold_hint')
                                          .tr(),
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
  const _Cards({this.pill = false});

  final bool pill;

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
                      borderRadius: BorderRadius.circular(5),
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
