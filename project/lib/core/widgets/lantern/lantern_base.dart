import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../hedayah/hedayah_pattern.dart';
import '../hedayah/hedayah_rosette.dart';
import 'lantern_glyphs.dart';

export 'lantern_glyphs.dart';

/// Every widget of the Lantern and Arch design carries this mark (ADR-026).
///
/// The two older designs must never show one: test/lantern_isolation_test.dart
/// walks their screens for it, and checks that every widget class under a
/// `lantern/` folder implements it.
abstract interface class LanternSkinWidget {}

/// One icon of the Lantern set (24 grid, 1.75 stroke, round caps).
class LIcon extends StatelessWidget implements LanternSkinWidget {
  const LIcon(this.glyph, {super.key, this.size = 20, this.color, this.label});

  final LGlyph glyph;
  final double size;

  /// The surrounding icon colour when null.
  final Color? color;

  /// Read by screen readers; without one the icon is decoration.
  final String? label;

  /// Icons that point along the reading direction.
  static const _directional = {
    LGlyph.arrow,
    LGlyph.back,
    LGlyph.send,
    LGlyph.chevronend,
    LGlyph.logout,
    LGlyph.external,
    LGlyph.directions,
  };

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/lantern/icons/${glyph.name}.svg',
        width: size,
        height: size,
        matchTextDirection: _directional.contains(glyph),
        colorFilter: ColorFilter.mode(
            color ?? IconTheme.of(context).color ?? context.lt.fg,
            BlendMode.srcIn),
        semanticsLabel: label,
        excludeFromSemantics: label == null,
      );
}

/// The eight-point star of the identity, in a box of [size].
Path lanternStarPath(Size size) {
  const q = <List<double>>[
    [12, 1, 13.21, 3.59],
    [14.41, 6.18, 17.09, 5.2],
    [19.78, 4.22, 18.8, 6.91],
    [17.82, 9.59, 20.41, 10.79],
    [23, 12, 20.41, 13.21],
    [17.82, 14.41, 18.8, 17.09],
    [19.78, 19.78, 17.09, 18.8],
    [14.41, 17.82, 13.21, 20.41],
    [12, 23, 10.79, 20.41],
    [9.59, 17.82, 6.91, 18.8],
    [4.22, 19.78, 5.2, 17.09],
    [6.18, 14.41, 3.59, 13.21],
    [1, 12, 3.59, 10.79],
    [6.18, 9.59, 5.2, 6.91],
    [4.22, 4.22, 6.91, 5.2],
    [9.59, 6.18, 10.79, 3.59],
  ];
  final sx = size.width / 24, sy = size.height / 24;
  final path = Path()..moveTo(10.79 * sx, 3.59 * sy);
  for (final s in q) {
    path.quadraticBezierTo(s[0] * sx, s[1] * sy, s[2] * sx, s[3] * sy);
  }
  return path..close();
}

/// A filled eight-point star.
class LStar extends StatelessWidget implements LanternSkinWidget {
  const LStar({super.key, this.size = 12, this.color = LanternTokens.gold});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: Size.square(size), painter: _StarPainter(color)));
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      canvas.drawPath(lanternStarPath(size), Paint()..color = color);

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}

/// The star turning: the design's loading mark. Still when motion is calm.
class LStarLoader extends StatefulWidget implements LanternSkinWidget {
  const LStarLoader({super.key, this.size = 26, this.color});

  final double size;
  final Color? color;

  @override
  State<LStarLoader> createState() => _LStarLoaderState();
}

class _LStarLoaderState extends State<LStarLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Lantern.calm(context)) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(
      turns: _turn,
      child: LStar(
          size: widget.size, color: widget.color ?? LanternTokens.gold));
}

/// The arch: a round head on straight sides, the frame of the identity.
/// [bottom] rounds the two lower corners.
Path lanternArchPath(Rect rect, {double bottom = 0}) {
  final r = math.min(rect.width / 2, rect.height);
  final b = math.min(bottom, math.min(rect.width / 2, rect.height - r));
  return Path()
    ..moveTo(rect.left, rect.bottom - b)
    ..lineTo(rect.left, rect.top + r)
    ..arcToPoint(Offset(rect.right, rect.top + r),
        radius: Radius.circular(r))
    ..lineTo(rect.right, rect.bottom - b)
    ..arcToPoint(Offset(rect.right - b, rect.bottom),
        radius: Radius.circular(b))
    ..lineTo(rect.left + b, rect.bottom)
    ..arcToPoint(Offset(rect.left, rect.bottom - b),
        radius: Radius.circular(b))
    ..close();
}

/// The arch as a border, for `ShapeDecoration`, `Material` and `ClipPath`.
class LArchBorder extends OutlinedBorder {
  const LArchBorder({super.side, this.bottom = 0});

  final double bottom;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      lanternArchPath(rect.deflate(side.width),
          bottom: math.max(0, bottom - side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      lanternArchPath(rect, bottom: bottom);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
        lanternArchPath(rect.deflate(side.width / 2), bottom: bottom),
        side.toPaint());
  }

  @override
  LArchBorder copyWith({BorderSide? side, double? bottom}) =>
      LArchBorder(side: side ?? this.side, bottom: bottom ?? this.bottom);

  @override
  ShapeBorder scale(double t) =>
      LArchBorder(side: side.scale(t), bottom: bottom * t);

  @override
  bool operator ==(Object other) =>
      other is LArchBorder && other.side == side && other.bottom == bottom;

  @override
  int get hashCode => Object.hash(side, bottom);
}

/// The owner's lattice motif, laid over night bands and heroes.
class LLattice extends StatelessWidget implements LanternSkinWidget {
  const LLattice(
      {super.key,
      this.color = const Color(0xFFD2A95F),
      this.opacity = .1,
      this.step = 44,
      this.fadeFrom});

  final Color color;
  final double opacity, step;
  final Alignment? fadeFrom;

  @override
  Widget build(BuildContext context) => Positioned.fill(
      child: HedayahPattern(
          color: color.withValues(alpha: opacity),
          step: step,
          weight: .9,
          fadeFrom: fadeFrom));
}

/// The Hedayah logo: the rosette and the wordmark side by side. White on
/// night grounds (owner decision: the Hedayah logo, not the arch mark, leads
/// the header, footer, welcome page and opening screen).
class LLogo extends StatelessWidget implements LanternSkinWidget {
  const LLogo({super.key, this.height = 34, this.onDark = false});

  final double height;
  final bool onDark;

  static const wordmark = 'assets/hedayah/wordmark.png';

  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: 'هداية',
      child: ExcludeSemantics(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
        HedayahRosette(
            size: height,
            color: onDark ? LanternTokens.white : LanternTokens.slate),
        SizedBox(width: height * .2),
        Image.asset(wordmark,
            height: height * .78,
            fit: BoxFit.contain,
            color: onDark ? LanternTokens.white : null,
            colorBlendMode: onDark ? BlendMode.srcIn : null),
      ])));
}

/// Gives a Lantern screen its colours: day or night as chosen in Settings,
/// or always night with [night] (the rooms, the opening screen). Screens
/// that have no Lantern layout sit outside it and keep the day theme.
///
/// Also applies calm motion from Settings to everything below.
class LanternSurface extends StatelessWidget implements LanternSkinWidget {
  const LanternSurface({super.key, required this.child, this.night});

  final Widget child;

  /// Forces night (true) or day (false); null follows Settings.
  final bool? night;

  @override
  Widget build(BuildContext context) {
    final (appearance, calm) =
        context.select<AppProvider?, (LanternAppearance, bool)>((p) => (
              p?.lanternAppearance ?? LanternAppearance.fallback,
              p?.lanternCalmMotion ?? false
            ));
    final dark = night ??
        appearance.isNight(MediaQuery.platformBrightnessOf(context));
    final media = MediaQuery.of(context);
    return Theme(
        data: LanternSkin.theme(Localizations.localeOf(context), night: dark),
        child: calm && !media.disableAnimations
            ? MediaQuery(
                data: media.copyWith(disableAnimations: true), child: child)
            : child);
  }
}

/// A night band: ink ground, the lattice, and a soft gold glow. Carries
/// heroes, the footer and page headers; its content reads the night tokens.
class LNightBand extends StatelessWidget implements LanternSkinWidget {
  const LNightBand(
      {super.key,
      required this.child,
      this.padding = EdgeInsets.zero,
      this.latticeOpacity = .1,
      this.latticeStep = 44,
      this.glow = const Alignment(.6, -.6),
      this.radius = 0});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double latticeOpacity, latticeStep, radius;

  /// Where the glow sits; null leaves it out.
  final Alignment? glow;

  @override
  Widget build(BuildContext context) {
    final glow = this.glow;
    return LanternSurface(
        night: true,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: DecoratedBox(
                decoration:
                    const BoxDecoration(color: LanternTokens.nightGround),
                child: Stack(children: [
                  if (glow != null)
                    Positioned.fill(
                        child: IgnorePointer(
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                        center: glow,
                                        radius: 1.1,
                                        colors: const [
                          Color(0x47BD933F),
                          Color(0x00BD933F)
                        ]))))),
                  LLattice(opacity: latticeOpacity, step: latticeStep),
                  Padding(padding: padding, child: child),
                ]))));
  }
}
