import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'lantern_base.dart';
import 'lantern_controls.dart';

/// A range slider in the Lantern shape: a gold run on the hairline track and
/// a white thumb that carries the focus halo.
class LSlider extends StatelessWidget implements LanternSkinWidget {
  const LSlider(
      {super.key,
      required this.value,
      required this.min,
      required this.max,
      required this.label,
      this.divisions,
      this.onChanged,
      this.valueLabel});

  final double value, min, max;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  /// Read by screen readers with the value.
  final String label;

  /// The value as words, when it means more than the number.
  final String? valueLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Semantics(
        label: label,
        child: SliderTheme(
            data: SliderThemeData(
                trackHeight: 6,
                activeTrackColor: LanternTokens.gold,
                inactiveTrackColor: t.line,
                disabledActiveTrackColor: t.line,
                disabledInactiveTrackColor: t.sunk,
                thumbColor: LanternTokens.white,
                disabledThumbColor: t.sunk,
                overlayColor: t.glow,
                activeTickMarkColor: LanternTokens.goldTop,
                inactiveTickMarkColor: t.line2,
                valueIndicatorColor: LanternTokens.nightGround,
                valueIndicatorTextStyle: Lantern.textStyle(13,
                    color: LanternTokens.onNight, weight: FontWeight.w600),
                thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 11, elevation: 3, pressedElevation: 5),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 22)),
            child: SizedBox(
                height: Lantern.target,
                child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions,
                    label: valueLabel ?? value.round().toString(),
                    semanticFormatterCallback: (v) =>
                        valueLabel ?? v.round().toString(),
                    onChanged: onChanged))));
  }
}

/// A check box with its sentence beside it; the whole row takes the tap.
/// Ticked, the box fills with gold and carries an ink check.
class LCheck extends StatelessWidget implements LanternSkinWidget {
  const LCheck(
      {super.key,
      required this.value,
      required this.label,
      this.onChanged});

  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final enabled = onChanged != null;
    return MergeSemantics(
        child: Semantics(
            checked: value,
            child: LPressable(
                onTap: enabled ? () => onChanged!(!value) : null,
                label: label,
                button: false,
                radius: Lantern.radiusTile,
                pressScale: .99,
                excludeChildSemantics: true,
                builder: (context, s) => ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: Lantern.target),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              AnimatedContainer(
                                  duration: Lantern.calm(context)
                                      ? Lantern.none
                                      : Lantern.state,
                                  width: 24,
                                  height: 24,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      gradient:
                                          value ? Lantern.goldFill : null,
                                      color: value ? null : t.surface,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                          color: value
                                              ? LanternTokens.gold
                                              : s.hovered
                                                  ? LanternTokens.gold
                                                  : t.muted,
                                          width: 1.5)),
                                  child: value
                                      ? const LIcon(LGlyph.check,
                                          size: 16,
                                          color: LanternTokens.onGold)
                                      : null),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text(label,
                                      style: Lantern.textStyle(14,
                                          color: enabled ? t.fg : t.muted,
                                          weight: FontWeight.w500,
                                          height: 1.45))),
                            ]))))));
  }
}
