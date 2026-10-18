import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../theme/app_theme.dart';
import 'ca_icon.dart';
import 'ca_focus_ring.dart';
import '../phone_input_guard.dart';

class CaChip extends StatelessWidget {
  const CaChip(
      {super.key,
      required this.label,
      this.selected = false,
      this.icon,
      this.onSelected});
  final String label;
  final bool selected;
  final CaGlyph? icon;
  final ValueChanged<bool>? onSelected;
  @override
  Widget build(BuildContext context) {
    Widget contents(Color color) => Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            CaIcon(icon!,
                size: CanopySize.inlineIcon,
                color: color == paletteOnAccent(context, Canopy.paper) ? color : paletteColor(context, Canopy.brandGreen)),
            const SizedBox(width: AppTheme.spaceSm)
          ],
          Flexible(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: color))),
        ]));
    return Semantics(
        button: onSelected != null,
        selected: onSelected == null ? null : selected,
        enabled: onSelected == null ? null : true,
        child: CaFocusRing(
            onDark: selected && !paletteOf(context).hidayah,
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    borderRadius: BorderRadius.circular(CanopyRadius.pill),
                    onTap: onSelected == null
                        ? null
                        : () => onSelected!(!selected),
                    child: TweenAnimationBuilder<double>(
                      tween:
                          Tween(begin: selected ? 1 : 0, end: selected ? 1 : 0),
                      duration: CanopyMotion.reduced(context)
                          ? CanopyMotion.none
                          : selected
                              ? CanopyMotion.chipIn
                              : CanopyMotion.chipOut,
                      curve: CanopyMotion.easeOut,
                      builder: (context, value, _) => Container(
                          constraints: const BoxConstraints(
                              minHeight: CanopySize.target),
                          decoration: BoxDecoration(
                              color: selected ? null : paletteColor(context, Canopy.paper),
                              borderRadius:
                                  BorderRadius.circular(CanopyRadius.pill),
                              border: selected
                                  ? null
                                  : Border.all(color: paletteColor(context, Canopy.hairline))),
                          child: Stack(fit: StackFit.passthrough, children: [
                            contents(paletteColor(context, Canopy.slate)),
                            if (value > 0)
                              Positioned.fill(
                                  child: IgnorePointer(
                                      child: ExcludeSemantics(
                                          child: ClipRect(
                                              clipBehavior: value == 1
                                                  ? Clip.none
                                                  : Clip.hardEdge,
                                              clipper: _ChipSweep(value,
                                                  Directionality.of(context)),
                                              child: DecoratedBox(
                                                  decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              CanopyRadius
                                                                  .pill),
                                                      gradient:
                                                          paletteGradient(context, AppGradients.pill)),
                                                  child: contents(
                                                      paletteOnAccent(context, Canopy.paper))))))),
                          ])),
                    )))));
  }
}

class _ChipSweep extends CustomClipper<Rect> {
  const _ChipSweep(this.value, this.direction);
  final double value;
  final TextDirection direction;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
      direction == TextDirection.rtl ? size.width * (1 - value) : 0,
      0,
      size.width * value,
      size.height);
  @override
  bool shouldReclip(_ChipSweep old) =>
      value != old.value || direction != old.direction;
}

typedef CaFilterChip = CaChip;

class CaSegmentedTabs extends StatelessWidget {
  const CaSegmentedTabs(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged,
      this.dark = false,
      this.disabledIndices = const {}})
      : assert(labels.length > 0),
        assert(index >= 0 && index < labels.length);
  final bool dark;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final Set<int> disabledIndices;
  static double heightFor(
      BuildContext context, List<String> labels, double width) {
    final style = Theme.of(context).textTheme.labelMedium!;
    final direction = Directionality.of(context);
    final part = (width - AppTheme.spaceSm) / labels.length;
    var height = CanopySize.target;
    for (final label in labels) {
      final painter = TextPainter(
          text: TextSpan(text: label, style: style),
          textDirection: direction,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2)
        ..layout(maxWidth: math.max(1, part - AppTheme.spaceLg));
      height = math.max(height, painter.height + AppTheme.spaceLg);
      painter.dispose();
    }
    return height;
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final style = Theme.of(context).textTheme.labelMedium!;
        final direction = Directionality.of(context);
        final width = constraints.maxWidth - AppTheme.spaceSm;
        final part = width / labels.length;
        final height = heightFor(context, labels, constraints.maxWidth);
        Widget row(Color color, {bool interactive = false}) => Row(children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                    child: Semantics(
                        selected: index == i,
                        button: interactive,
                        enabled:
                            interactive ? !disabledIndices.contains(i) : null,
                        child: CaFocusRing(
                            onDark: (dark || index == i) && !(index == i && paletteOf(context).hidayah),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(CanopyRadius.pill),
                              onTap: interactive && !disabledIndices.contains(i)
                                  ? () => onChanged(i)
                                  : null,
                              child: Center(
                                  child: Padding(
                                      padding:
                                          const EdgeInsetsDirectional.symmetric(
                                              horizontal: AppTheme.spaceSm),
                                      child: Text(labels[i],
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              style.copyWith(color: color)))),
                            )))),
            ]);
        final physicalIndex =
            direction == TextDirection.rtl ? labels.length - 1 - index : index;
        final rect = Rect.fromLTWH(physicalIndex * part, 0, part, height);
        final duration = CanopyMotion.reduced(context)
            ? CanopyMotion.none
            : CanopyMotion.tabThumb;
        return Container(
          padding: const EdgeInsets.all(AppTheme.spaceXs),
          decoration: BoxDecoration(
              color: dark ? paletteColor(context, Canopy.canopy900) : paletteColor(context, Canopy.mint),
              borderRadius: BorderRadius.circular(CanopyRadius.pill)),
          child: SizedBox(
              height: height,
              child: Stack(children: [
                Positioned.fill(
                  child: AnimatedAlign(
                      alignment: AlignmentDirectional(
                          labels.length == 1
                              ? 0
                              : -1 + 2 * index / (labels.length - 1),
                          0),
                      duration: duration,
                      curve: CanopyMotion.easeOut,
                      child: FractionallySizedBox(
                          widthFactor: 1 / labels.length,
                          heightFactor: 1,
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  gradient: paletteGradient(context, AppGradients.pill),
                                  borderRadius: BorderRadius.circular(
                                      CanopyRadius.pill))))),
                ),
                Positioned.fill(
                    child: row(dark ? paletteColor(context, Canopy.mist) : paletteColor(context, Canopy.brandGreen),
                        interactive: true)),
                Positioned.fill(
                    child: IgnorePointer(
                        child: ExcludeSemantics(
                  child: TweenAnimationBuilder<Rect?>(
                      tween: RectTween(begin: rect, end: rect),
                      duration: duration,
                      curve: CanopyMotion.easeOut,
                      builder: (_, value, __) => ClipRect(
                          clipper: _ThumbClip(value!),
                          child: row(paletteOnAccent(context, Canopy.paper)))),
                ))),
              ])),
        );
      });
}

class _ThumbClip extends CustomClipper<Rect> {
  const _ThumbClip(this.rect);
  final Rect rect;
  @override
  Rect getClip(Size size) => rect;
  @override
  bool shouldReclip(_ThumbClip old) => rect != old.rect;
}

class CaInput extends StatelessWidget {
  const CaInput(
      {super.key,
      required this.label,
      this.controller,
      this.hint,
      this.helper,
      this.error,
      this.icon,
      this.trailing,
      this.onChanged,
      this.onSubmitted,
      this.validator,
      this.enabled = true,
      this.readOnly = false,
      this.obscureText = false,
      this.showLabel = true,
      this.keyboardType,
      this.maxLength,
      this.maxLines = 1,
      this.focusNode,
      this.autofocus = false,
      this.textDirection});
  final bool autofocus;
  final TextDirection? textDirection;
  final String label;
  final String? hint, helper, error;
  final TextEditingController? controller;
  final CaGlyph? icon;
  final Widget? trailing;
  final ValueChanged<String>? onChanged, onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled, readOnly, obscureText, showLabel;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CanopyRadius.input);
    final rest =
        OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none);
    Widget errorRow(BuildContext context, String message) =>
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CaIcon(CaGlyph.alert,
              color: paletteColor(context, Canopy.liveCrimson), size: CanopySize.inlineIcon),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
              child: Text(message,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: paletteColor(context, Canopy.liveCrimson)))),
        ]);
    return PhoneInputGuard(
        showHint: !readOnly,
        builder: (context, blocked) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showLabel) ...[
                    Text(label, style: Theme.of(context).textTheme.labelMedium),
                    const SizedBox(height: AppTheme.spaceSm)
                  ],
                  Semantics(
                      label: label == hint ? null : label,
                      child: TextFormField(
                        controller: controller,
                        enabled: enabled,
                        readOnly: readOnly || blocked,
                        autofocus: autofocus && !blocked,
                        focusNode: focusNode,
                        textDirection: textDirection,
                        obscureText: obscureText,
                        keyboardType: keyboardType,
                        maxLength: maxLength,
                        maxLines: maxLines,
                        onChanged: onChanged,
                        onFieldSubmitted: onSubmitted,
                        onTapOutside: !kIsWeb &&
                                defaultTargetPlatform == TargetPlatform.iOS
                            ? (_) =>
                                FocusManager.instance.primaryFocus?.unfocus()
                            : null,
                        validator: validator,
                        forceErrorText: error,
                        errorBuilder: errorRow,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: enabled ? paletteColor(context, Canopy.ink) : paletteColor(context, Canopy.slate)),
                        decoration: InputDecoration(
                          hintText: hint,
                          filled: true,
                          fillColor: paletteColor(context, Canopy.mint),
                          hintStyle: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(color: paletteColor(context, Canopy.haze)),
                          isDense: true,
                          contentPadding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppTheme.spaceLg,
                              vertical: AppTheme.spaceMd),
                          constraints: const BoxConstraints(
                              minHeight: CanopySize.target),
                          border: rest,
                          enabledBorder: rest,
                          disabledBorder: rest,
                          focusedBorder: OutlineInputBorder(
                              borderRadius: radius,
                              borderSide: BorderSide(
                                  color: paletteColor(context, Canopy.brandGreen),
                                  width: CanopySize.focusWidth)),
                          errorBorder: OutlineInputBorder(
                              borderRadius: radius,
                              borderSide: BorderSide(
                                  color: paletteColor(context, Canopy.liveCrimson),
                                  width: CanopySize.focusWidth)),
                          focusedErrorBorder: OutlineInputBorder(
                              borderRadius: radius,
                              borderSide: BorderSide(
                                  color: paletteColor(context, Canopy.liveCrimson),
                                  width: CanopySize.focusWidth)),
                          prefixIcon: icon == null
                              ? null
                              : Center(
                                  widthFactor: 1,
                                  heightFactor: 1,
                                  child: CaIcon(icon!,
                                      size: CanopySize.inlineIcon)),
                          prefixIconConstraints: const BoxConstraints(
                              minWidth: CanopySize.target,
                              minHeight: CanopySize.target),
                          suffixIcon: trailing,
                        ),
                      )),
                  if (helper != null) ...[
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(helper!, style: Theme.of(context).textTheme.bodySmall)
                  ],
                ]));
  }
}

typedef CaTextField = CaInput;

class CaSearchField extends StatelessWidget {
  const CaSearchField(
      {super.key,
      required this.label,
      this.hint,
      this.controller,
      this.onChanged,
      this.onSubmitted,
      this.onFilter,
      required this.filterLabel,
      this.enabled = true,
      this.readOnly = false,
      this.focusNode,
      this.clearLabel,
      this.onClear});
  final FocusNode? focusNode;
  final VoidCallback? onClear;
  final String label, filterLabel;
  final String? hint, clearLabel;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onFilter;
  final bool enabled, readOnly;
  @override
  Widget build(BuildContext context) => CaInput(
      label: label,
      hint: hint,
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      enabled: enabled,
      readOnly: readOnly,
      icon: CaGlyph.search,
      showLabel: false,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (onClear != null)
          CaIconButton(
              icon: CaGlyph.close,
              label: clearLabel ??
                  MaterialLocalizations.of(context).deleteButtonTooltip,
              onPressed: onClear),
        CaIconButton(
            icon: CaGlyph.sliders,
            label: filterLabel,
            onPressed: enabled ? onFilter : null)
      ]));
}

/// Brand track with the native switch's keyboard and accessibility behavior.
class CaSwitch extends StatelessWidget {
  const CaSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => CaFocusRing(
      child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: paletteColor(context, Canopy.paper),
          activeTrackColor: paletteColor(context, Canopy.brandGreen),
          inactiveThumbColor: paletteColor(context, Canopy.slate),
          inactiveTrackColor: paletteColor(context, Canopy.mist)));
}
