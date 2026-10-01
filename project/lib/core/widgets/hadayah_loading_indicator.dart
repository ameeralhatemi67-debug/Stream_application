import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Four outlined capsules from the owner's loading motion specification.
class HadayahLoadingIndicator extends StatefulWidget {
  const HadayahLoadingIndicator({
    super.key,
    this.color,
    this.valueColor,
    this.strokeWidth,
  });

  final Color? color;
  final Animation<Color>? valueColor;
  final double? strokeWidth;

  @override
  State<HadayahLoadingIndicator> createState() =>
      _HadayahLoadingIndicatorState();
}

class _HadayahLoadingIndicatorState extends State<HadayahLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  )..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: 'common.loading'.tr(),
      child: SizedBox.square(
        dimension: 36,
        child: CustomPaint(
          painter: _CapsulePainter(
            motion: _motion,
            color: widget.color ?? widget.valueColor?.value ?? AppTheme.primary,
            strokeWidth: widget.strokeWidth ?? 5.75,
            reduceMotion: reduceMotion,
          ),
        ),
      ),
    );
  }
}

class _CapsulePainter extends CustomPainter {
  _CapsulePainter({
    required this.motion,
    required this.color,
    required this.strokeWidth,
    required this.reduceMotion,
  }) : super(repaint: motion);

  final Animation<double> motion;
  final Color color;
  final double strokeWidth;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    // Two 2-second bloom cycles fit the supplied 4-second total cycle.
    final milliseconds = ((motion.value * 4000) % 2000).toDouble();
    const curve = Cubic(.64, .04, .41, 1);
    final bloom = reduceMotion
        ? 1.0
        : milliseconds < 550
            ? 0.0
            : milliseconds < 1100
                ? curve.transform((milliseconds - 550) / 550)
                : milliseconds < 1450
                    ? 1.0
                    : curve.transform(1 - (milliseconds - 1450) / 550);
    final scale = size.shortestSide / 170;
    canvas.translate(size.width / 2, size.height / 2);
    if (!reduceMotion) canvas.rotate(motion.value * 4000 / 1500 * math.pi * 2);
    canvas.scale(scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(strokeWidth, 1.25 / scale)
      ..isAntiAlias = true;
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset.zero, width: 36 + 84 * bloom, height: 36),
          const Radius.circular(18),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CapsulePainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      reduceMotion != oldDelegate.reduceMotion;
}
