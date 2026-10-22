import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/hedayah_skin.dart';
import 'hedayah_motif_data.dart';

/// The Hedayah lattice: the owner's motif repeated on the brand grid, one copy
/// every [step] across and down with alternate rows shifted half a step, so
/// each motif's corner strokes run into its neighbours' and the lattice has
/// no seams (Hedayah Brand Identity, Pattern).
class HedayahPattern extends StatelessWidget {
  const HedayahPattern(
      {super.key,
      this.color = HedayahSkin.patternOnGold,
      this.step = 30,
      this.weight = .7,
      this.fadeFrom});

  final Color color;

  /// Distance between neighbouring motifs, the brand's 12.149 mm.
  final double step;

  /// Extra line weight in logical pixels. The motif's lines are 0.12 mm
  /// outlines, under half a pixel at band sizes; this stroke brings them to
  /// about a pixel, as the website's tiles read.
  final double weight;

  /// Fades the lattice out away from this point (a fraction of the size, 0 to
  /// 1 on each axis); null keeps it even.
  final Alignment? fadeFrom;

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: ExcludeSemantics(
          child: RepaintBoundary(
              child: CustomPaint(
                  size: Size.infinite,
                  isComplex: true,
                  painter: _PatternPainter(color, step, weight,
                      MediaQuery.devicePixelRatioOf(context), fadeFrom)))));
}

/// The motif's paths, decoded once.
final List<Path> _motifPaths = [
  for (final entry in hedayahMotifPaths) _decode(entry.d, entry.evenOdd)
];

Path _decode(List<double> d, bool evenOdd) {
  final path = Path()
    ..fillType = evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
  var i = 0;
  while (i < d.length) {
    switch (d[i].toInt()) {
      case 0:
        path.moveTo(d[i + 1], d[i + 2]);
        i += 3;
      case 1:
        path.lineTo(d[i + 1], d[i + 2]);
        i += 3;
      case 2:
        path.cubicTo(
            d[i + 1], d[i + 2], d[i + 3], d[i + 4], d[i + 5], d[i + 6]);
        i += 7;
      default:
        path.close();
        i += 1;
    }
  }
  return path;
}

/// One repeat of the lattice (two motifs: one on the corners, one in the
/// middle), drawn once per colour, size and screen density into an image.
/// The painter fills any area with it as a repeating image shader: one draw
/// call however large the band, where replaying every motif's 67 paths cost
/// thousands of draws a frame and made scrolling lag on the web.
final Map<(int, double, double, double), ui.Image> _tiles = {};

ui.Image _tile(Color color, double step, double weight, double dpr) =>
    _tiles.putIfAbsent((color.toARGB32(), step, weight, dpr), () {
      // The repeat is 2 x step logical pixels; the image is a whole number of
      // device pixels across, so repeats meet without a seam.
      final period = 2 * step;
      final pixels = (period * dpr).ceil();
      final k = pixels / period;
      final scale = step / _gridStep;
      final half = hedayahMotifSize * scale / 2;
      final recorder = ui.PictureRecorder();
      final bounds = Rect.fromLTWH(0, 0, pixels.toDouble(), pixels.toDouble());
      final canvas = Canvas(recorder, bounds)..clipRect(bounds);
      // Opaque lines on a layer that carries the colour's alpha once, so the
      // joins where neighbouring motifs overlap do not double up.
      canvas
        ..saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, color.a))
        ..scale(k);
      final opaque = color.withValues(alpha: 1);
      final fill = Paint()..color = opaque;
      final line = Paint()
        ..color = opaque
        ..style = PaintingStyle.stroke
        ..strokeWidth = weight / scale
        ..strokeJoin = StrokeJoin.round;
      for (final (x, y) in [
        (0.0, 0.0), (period, 0.0), (0.0, period), (period, period), // corners
        (step, step), // the middle
        (step, -step), (-step, step), (period + step, step), (step, period + step),
      ]) {
        canvas
          ..save()
          ..translate(x - half, y - half)
          ..scale(scale);
        for (final path in _motifPaths) {
          canvas.drawPath(path, fill);
          if (weight > 0) canvas.drawPath(path, line);
        }
        canvas.restore();
      }
      canvas.restore();
      return recorder.endRecording().toImageSync(pixels, pixels);
    });

/// The brand grid step in the motif's own units (millimetres).
const _gridStep = 12.1494;

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.color, this.step, this.weight, this.dpr, this.fadeFrom);

  final Color color;
  final double step, weight, dpr;
  final Alignment? fadeFrom;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a == 0) return;
    final rect = Offset.zero & size;
    final tile = _tile(color, step, weight, dpr);
    final k = tile.width / (2 * step);
    final pattern = Paint()
      ..filterQuality = FilterQuality.medium
      ..shader = ImageShader(tile, TileMode.repeated, TileMode.repeated,
          (Matrix4.identity()..scaleByDouble(1 / k, 1 / k, 1, 1)).storage);
    final fade = fadeFrom;
    if (fade == null) {
      canvas.drawRect(rect, pattern);
      return;
    }
    canvas
      ..saveLayer(rect, Paint())
      ..drawRect(rect, pattern)
      ..drawRect(
          rect,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = const RadialGradient(
                    colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                    stops: [0, .85])
                .createShader(Rect.fromCircle(
                    center: fade.withinRect(rect),
                    radius: math.max(size.width, size.height))))
      ..restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.color != color ||
      old.step != step ||
      old.weight != weight ||
      old.dpr != dpr ||
      old.fadeFrom != fadeFrom;
}
