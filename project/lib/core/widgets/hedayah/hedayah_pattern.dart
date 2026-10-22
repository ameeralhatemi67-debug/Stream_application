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
      this.weight = .8,
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
                  painter: _PatternPainter(color, step, weight, fadeFrom)))));
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

/// The motif drawn once per colour and line weight (in motif units); each
/// copy on the grid replays it.
final Map<(int, double), ui.Picture> _motifPictures = {};

ui.Picture _motifPicture(Color color, double stroke) =>
    _motifPictures.putIfAbsent((color.toARGB32(), stroke), () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final fill = Paint()..color = color;
      final line = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeJoin = StrokeJoin.round;
      for (final path in _motifPaths) {
        canvas.drawPath(path, fill);
        if (stroke > 0) canvas.drawPath(path, line);
      }
      return recorder.endRecording();
    });

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.color, this.step, this.weight, this.fadeFrom);

  final Color color;
  final double step, weight;
  final Alignment? fadeFrom;

  /// The brand grid step in the motif's own units (millimetres).
  static const _gridStep = 12.1494;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a == 0) return;
    final rect = Offset.zero & size;
    final scale = step / _gridStep;
    final half = hedayahMotifSize * scale / 2;
    // Drawn opaque on a layer that carries the colour's alpha once, so the
    // joins where neighbouring motifs overlap do not double up.
    final picture = _motifPicture(color.withValues(alpha: 1),
        (weight / scale * 100).roundToDouble() / 100);
    final fade = fadeFrom;
    canvas.saveLayer(
        rect, Paint()..color = Color.fromRGBO(0, 0, 0, color.a));
    canvas.clipRect(rect);
    final rows = (size.height / step).ceil() + 1;
    final cols = (size.width / (2 * step)).ceil() + 1;
    for (var row = -1; row <= rows; row++) {
      final y = row * step;
      final shift = row.isOdd ? step : 0.0;
      for (var col = -1; col <= cols; col++) {
        final x = col * 2 * step + shift;
        canvas
          ..save()
          ..translate(x - half, y - half)
          ..scale(scale)
          ..drawPicture(picture)
          ..restore();
      }
    }
    if (fade != null) {
      final centre = fade.withinRect(rect);
      canvas.drawRect(
          rect,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = const RadialGradient(
                    colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                    stops: [0, .85])
                .createShader(Rect.fromCircle(
                    center: centre,
                    radius: math.max(size.width, size.height))));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.color != color ||
      old.step != step ||
      old.weight != weight ||
      old.fadeFrom != fadeFrom;
}
