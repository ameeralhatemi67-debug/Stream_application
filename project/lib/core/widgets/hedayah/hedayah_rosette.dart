import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/canopy_tokens.dart';
import '../../theme/hedayah_skin.dart';

/// The association's rosette: four rounded loops turned 45 degrees apart, so
/// eight lobes meet around an octagonal centre (Hedayah Brand Identity, The
/// mark). Drawn as a line, in slate on light grounds and white on gold.
class HedayahRosette extends StatelessWidget {
  const HedayahRosette(
      {super.key,
      this.size = 64,
      this.color = HedayahSkin.slate,
      this.progress = 1});

  final double size;
  final Color color;

  /// How much of each loop is drawn, 0 to 1 (the splash draws it on).
  final double progress;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: Size.square(size),
          painter: _RosettePainter(color, progress.clamp(0.0, 1.0))));
}

/// The rosette drawing itself on once, then holding.
class HedayahRosetteDraw extends StatefulWidget {
  const HedayahRosetteDraw(
      {super.key,
      this.size = 120,
      this.color = HedayahSkin.slate,
      this.duration = const Duration(milliseconds: 1400)});

  final double size;
  final Color color;
  final Duration duration;

  @override
  State<HedayahRosetteDraw> createState() => _HedayahRosetteDrawState();
}

class _HedayahRosetteDrawState extends State<HedayahRosetteDraw>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanopyMotion.reduced(context)) {
      _draw.value = 1;
    } else if (!_draw.isAnimating && _draw.value == 0) {
      _draw.forward();
    }
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _draw,
      builder: (context, _) => HedayahRosette(
          size: widget.size,
          color: widget.color,
          progress: CanopyMotion.easeOut.transform(_draw.value)));
}

class _RosettePainter extends CustomPainter {
  _RosettePainter(this.color, this.progress);

  final Color color;
  final double progress;

  /// Loop width and line weight against the rosette's span, measured from
  /// the association's logo file.
  static const _loopWidth = .27, _lineWeight = .028;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final stroke = size.shortestSide * _lineWeight;
    final span = size.shortestSide - stroke;
    final loop = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset.zero, width: span * _loopWidth, height: span),
        Radius.circular(span * _loopWidth / 2));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.translate(size.width / 2, size.height / 2);
    for (var i = 0; i < 4; i++) {
      final path = (Path()..addRRect(loop))
          .transform(Matrix4.rotationZ(i * math.pi / 4).storage);
      if (progress >= 1) {
        canvas.drawPath(path, paint);
        continue;
      }
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RosettePainter old) =>
      old.color != color || old.progress != progress;
}
