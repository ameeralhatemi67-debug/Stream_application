import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Observes descendant focus without adding a keyboard stop or an action.
class CaFocusRing extends StatefulWidget {
  const CaFocusRing(
      {super.key,
      required this.child,
      this.onDark = false,
      this.radius = CanopyRadius.pill});
  final Widget child;
  final bool onDark;
  final double radius;
  @override
  State<CaFocusRing> createState() => _CaFocusRingState();
}

class _CaFocusRingState extends State<CaFocusRing> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) => Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onFocusChange: (value) => setState(() => _focused = value),
      child: CustomPaint(
          foregroundPainter: _FocusOutline(_focused,
              widget.onDark ? Canopy.paper : Canopy.brandGreen, widget.radius),
          child: widget.child));
}

class _FocusOutline extends CustomPainter {
  const _FocusOutline(this.focused, this.color, this.radius);
  final bool focused;
  final Color color;
  final double radius;
  @override
  void paint(Canvas canvas, Size size) {
    if (!focused) return;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).deflate(CanopySize.focusWidth / 2),
            Radius.circular(radius)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = CanopySize.focusWidth);
  }

  @override
  bool shouldRepaint(_FocusOutline old) =>
      old.focused != focused || old.color != color || old.radius != radius;
}
