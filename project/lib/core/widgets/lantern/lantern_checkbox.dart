import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'lantern_base.dart';
import 'lantern_controls.dart';

/// A Lantern checkbox: a 22 px rounded box in a 44 px target. Ticked, it
/// fills with gold and shows the check in ink; the state is also spoken
/// ("checked"), never colour alone. [value] null is the mixed state (some of
/// a list chosen), drawn as a bar.
class LCheckbox extends StatelessWidget implements LanternSkinWidget {
  const LCheckbox(
      {super.key,
      required this.value,
      required this.label,
      this.onChanged,
      this.size = Lantern.target});

  final bool? value;

  /// Spoken name; the visible text, when there is one, sits beside the box.
  final String label;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final on = value != false;
    final enabled = onChanged != null;
    return Opacity(
        opacity: enabled ? 1 : .45,
        child: LPressable(
            onTap: enabled ? () => onChanged!(value != true) : null,
            label: label,
            toggled: value ?? false,
            button: false,
            pressScale: .9,
            radius: 8,
            excludeChildSemantics: true,
            builder: (context, s) => SizedBox(
                width: size,
                height: size,
                child: Center(
                    child: AnimatedContainer(
                        duration: Lantern.calm(context)
                            ? Lantern.none
                            : Lantern.state,
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            gradient: on ? Lantern.goldFill : null,
                            color: on ? null : t.surface,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: on
                                    ? LanternTokens.goldLo
                                    : s.hovered
                                        ? t.goldInk
                                        : t.muted,
                                width: 1.5)),
                        child: value == null
                            ? Container(
                                width: 10,
                                height: 2.5,
                                decoration: BoxDecoration(
                                    color: LanternTokens.onGold,
                                    borderRadius: BorderRadius.circular(2)))
                            : on
                                ? const LIcon(LGlyph.check,
                                    size: 15, color: LanternTokens.onGold)
                                : null)))));
  }
}
