import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// A mosque on any Lantern map: an arched pin whose tail points at the
/// mosque, a mosque inside, the number of lessons this week on a small ink
/// badge, and the star above while lessons are coming. With nothing coming
/// up it is white with a gold edge (still a mosque, never a bare outline).
/// The edge is red while a lesson there is live in the app, green while one
/// is on at the mosque, ink when the pin is selected.
class LanternMosqueMark extends StatelessWidget implements LanternSkinWidget {
  const LanternMosqueMark(
      {super.key,
      this.count = 0,
      this.quiet = false,
      this.live = false,
      this.onSite = false,
      this.selected = false});

  final int count;
  final bool quiet, live, onSite, selected;

  /// The mark's box: the pin and its badge. The tail's tip is the bottom
  /// centre.
  static const size = Size(42, 50);

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final width = quiet ? 30.0 : 34.0;
    final body = quiet ? 31.0 : 36.0;
    final tip = quiet ? 38.0 : 45.0;
    final edge = selected
        ? LanternTokens.ink
        : live
            ? LanternTokens.liveFill
            : onSite
                ? LanternTokens.okFill
                : quiet
                    ? LanternTokens.gold
                    : const Color(0xFF805B1B);
    final glyph = quiet ? t.goldInk : const Color(0xFF4B320E);
    return SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // A soft ground shadow where the tail meets the map.
              Positioned(
                  bottom: -2,
                  child: Container(
                      width: 14,
                      height: 5,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Color(0x40000000), blurRadius: 4),
                          ]))),
              Positioned(
                  bottom: 0,
                  child: CustomPaint(
                      size: Size(width, tip),
                      painter: _MosquePinPainter(
                          body: body,
                          fill: quiet ? t.surface : null,
                          edge: edge,
                          edgeWidth: selected
                              ? 2.6
                              : live || onSite
                                  ? 2.4
                                  : 1.6,
                          glow: selected ? t.glow : null),
                      child: SizedBox(
                          width: width,
                          height: tip,
                          child: Padding(
                              padding: EdgeInsets.only(top: quiet ? 7 : 8),
                              child: Align(
                                  alignment: Alignment.topCenter,
                                  child: LIcon(LGlyph.mosque,
                                      size: quiet ? 15 : 18,
                                      color: glyph)))))),
              if (!quiet && !onSite && !live)
                Positioned(
                    bottom: tip - 2,
                    child: const LStar(size: 8, color: Color(0xFF805B1B))),
              if (!quiet && count > 0)
                PositionedDirectional(
                    bottom: tip - 16,
                    end: 0,
                    child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: LanternTokens.ink,
                            borderRadius:
                                BorderRadius.circular(Lantern.radiusPill),
                            border: Border.all(
                                color: LanternTokens.white, width: 1.5)),
                        child: Text('$count',
                            style: Lantern.textStyle(10.5,
                                    color: LanternTokens.white,
                                    weight: FontWeight.w700,
                                    height: 1.2)
                                .copyWith(fontFeatures: Lantern.tabular)))),
            ]));
  }
}

/// The pin: an arch on top, straight sides, rounded lower corners and a
/// short tail to a point.
class _MosquePinPainter extends CustomPainter {
  const _MosquePinPainter(
      {required this.body,
      required this.edge,
      required this.edgeWidth,
      this.fill,
      this.glow});

  /// Where the body ends and the tail begins.
  final double body;
  final Color edge;
  final double edgeWidth;

  /// Null: the gold gradient.
  final Color? fill;
  final Color? glow;

  Path _path(Size size) {
    final w = size.width, r = w / 2, h = size.height;
    return Path()
      ..moveTo(0, r)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, body - 5)
      ..quadraticBezierTo(w, body, w - 5, body)
      ..lineTo(w / 2 + 5, body)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 - 5, body)
      ..lineTo(5, body)
      ..quadraticBezierTo(0, body, 0, body - 5)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _path(size);
    if (glow != null) {
      canvas.drawPath(
          path,
          Paint()
            ..color = glow!
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6));
    }
    canvas.drawShadow(path, const Color(0xFF000000), 3, false);
    final paint = Paint();
    if (fill != null) {
      paint.color = fill!;
    } else {
      paint.shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [LanternTokens.goldHi, Color(0xFFC1923B)])
          .createShader(Offset.zero & size);
    }
    canvas
      ..drawPath(path, paint)
      ..drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = edgeWidth
            ..color = edge);
  }

  @override
  bool shouldRepaint(_MosquePinPainter old) =>
      old.body != body ||
      old.edge != edge ||
      old.edgeWidth != edgeWidth ||
      old.fill != fill ||
      old.glow != glow;
}
