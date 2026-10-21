import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'ca_cards.dart';
import 'ca_icon.dart';
import 'ca_focus_ring.dart';

class CaStepper extends StatelessWidget {
  const CaStepper({super.key, required this.steps, required this.index})
      : assert(steps.length > 0),
        assert(index >= 0 && index < steps.length);
  final List<String> steps;
  final int index;
  @override
  Widget build(BuildContext context) {
    final statement = 'ds.step_of'
        .tr(args: ['${index + 1}', '${steps.length}', steps[index]]);
    return Semantics(
        value: statement,
        child: ExcludeSemantics(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: AppTheme.spaceXs),
                  Expanded(
                      child: Container(
                          height: CanopySize.stepBar,
                          decoration: BoxDecoration(
                              color: i <= index ? null : Canopy.mist,
                              gradient: i <= index ? AppGradients.pill : null,
                              borderRadius:
                                  BorderRadius.circular(CanopyRadius.pill)))),
                ]
              ]),
              const SizedBox(height: AppTheme.spaceSm),
              Text(statement, style: Theme.of(context).textTheme.bodySmall),
            ])));
  }
}

class CaKpiTile extends StatelessWidget {
  const CaKpiTile(
      {super.key, required this.label, this.value, this.unit, this.reason});
  final String label;
  final String? value, unit, reason;
  @override
  Widget build(BuildContext context) => CaCard(
      variant: CaCardVariant.flat,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value ?? '—',
                style: value == null
                    ? Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Canopy.haze)
                    : Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()])),
            if (value == null)
              Text(reason ?? 'ds.not_measured'.tr(),
                  style: Theme.of(context).textTheme.bodySmall),
            if (unit != null && value != null)
              Text(unit!, style: Theme.of(context).textTheme.bodySmall),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Canopy.slate)),
          ]));
}

class CaSettingsRow extends StatelessWidget {
  const CaSettingsRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.badge,
      this.icon,
      this.trailing,
      this.onTap,
      this.divider = false});
  final String title;
  final String? subtitle;

  /// Optional status shown under the title (for example a CaStatusChip), so a
  /// state reads as a chip instead of an uppercase sentence.
  final Widget? badge;
  final CaGlyph? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool divider;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        if (divider)
          const Divider(height: CanopySize.stroke, color: Canopy.hairline),
        CaFocusRing(
            radius: CanopyRadius.input,
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(CanopyRadius.input),
                    child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minHeight: CanopySize.target),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spaceMd),
                            child: Row(children: [
                              if (icon != null) ...[
                                CaIcon(icon!),
                                const SizedBox(width: AppTheme.spaceMd)
                              ],
                              Expanded(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge),
                                    if (subtitle != null)
                                      Text(subtitle!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    if (badge != null) ...[
                                      const SizedBox(height: AppTheme.spaceXs),
                                      badge!,
                                    ],
                                  ])),
                              if (trailing != null) ...[
                                const SizedBox(width: AppTheme.spaceSm),
                                trailing!
                              ],
                            ])))))),
      ]);
}

/// Values and labels come from the existing encoder/player settings at the call site.
class CaQualityPresets<T> extends StatelessWidget {
  const CaQualityPresets(
      {super.key,
      required this.options,
      required this.value,
      this.onChanged,
      this.cinema = false})
      : assert(options.length > 0);
  final bool cinema;
  final List<({T value, String label, String detail})> options;
  final T value;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTheme.spaceSm),
          Expanded(
              child: Semantics(
                  button: true,
                  selected: options[i].value == value,
                  enabled: onChanged != null,
                  child: CaFocusRing(
                      radius: CanopyRadius.input,
                      child: Material(
                          color: options[i].value == value
                              ? Canopy.mint
                              : Canopy.paper,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(CanopyRadius.input),
                              side: BorderSide(
                                  color: options[i].value == value
                                      ? Canopy.brandGreen
                                      : Canopy.hairline)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                              onTap: onChanged == null
                                  ? null
                                  : () => onChanged!(options[i].value),
                              child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      minHeight: CanopySize.target),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppTheme.spaceXs,
                                          vertical: AppTheme.spaceSm),
                                      child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(options[i].label,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                        color:
                                                            Canopy.brandGreen)),
                                            Text(options[i].detail,
                                                textAlign: TextAlign.center,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                        color: cinema
                                                            ? Canopy.slate
                                                            : null)),
                                          ])))))))),
        ]
      ]));
}

enum CaBannerKind { info, warning, success, error }

class CaBanner extends StatelessWidget {
  const CaBanner(
      {super.key,
      required this.message,
      this.kind = CaBannerKind.info,
      this.action,
      this.busy = false});
  final String message;
  final CaBannerKind kind;
  final Widget? action;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final foreground = switch (kind) {
      CaBannerKind.warning => Canopy.warning,
      CaBannerKind.error => Canopy.liveCrimson,
      CaBannerKind.success => Canopy.brandGreen,
      CaBannerKind.info => Canopy.slate
    };
    final background = switch (kind) {
      CaBannerKind.warning => Canopy.warningTint,
      CaBannerKind.error => Canopy.errorTint,
      _ => Canopy.mint
    };
    final icon = switch (kind) {
      CaBannerKind.warning || CaBannerKind.error => CaGlyph.alert,
      CaBannerKind.success => CaGlyph.check,
      CaBannerKind.info => CaGlyph.info
    };
    return Semantics(
        liveRegion: true,
        child: Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(CanopyRadius.input)),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (busy)
                SizedBox.square(
                    dimension: CanopySize.buttonRing,
                    child: CircularProgressIndicator(
                        color: foreground, strokeWidth: CanopySize.ring))
              else
                CaIcon(icon, color: foreground),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(message,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: foreground)),
                    if (action != null) action!,
                  ])),
            ])));
  }
}
