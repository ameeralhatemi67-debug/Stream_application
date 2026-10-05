import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'ca_feedback.dart';

class CanopyCheckDraw extends StatelessWidget {
  const CanopyCheckDraw({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CanopyMotion.reduced(context)
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: CanopyMotion.reduced(context)
              ? CanopyMotion.none
              : CanopyMotion.followCheck,
          curve: CanopyMotion.easeOut,
          child: child,
          builder: (context, value, child) => ClipRect(
              clipBehavior: value == 1 ? Clip.none : Clip.hardEdge,
              clipper: _CheckClip(value),
              child: child));
}

class _CheckClip extends CustomClipper<Rect> {
  const _CheckClip(this.value);
  final double value;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * value, size.height);
  @override
  bool shouldReclip(_CheckClip old) => value != old.value;
}

class CanopyLivePulse extends StatefulWidget {
  const CanopyLivePulse({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<CanopyLivePulse> createState() => _CanopyLivePulseState();
}

class _CanopyLivePulseState extends State<CanopyLivePulse>
    with SingleTickerProviderStateMixin {
  late final _ping =
      AnimationController(vsync: this, duration: CanopyMotion.liveRing);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CanopyLivePulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (!widget.enabled || CanopyMotion.reduced(context)) {
      _ping.stop();
      _ping.value = 0;
    } else if (!_ping.isAnimating) {
      _ping.repeat();
    }
  }

  @override
  void dispose() {
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.enabled ||
          CanopyMotion.reduced(context)
      ? widget.child
      : RepaintBoundary(
          child: CustomPaint(painter: _LivePing(_ping), child: widget.child));
}

class _LivePing extends CustomPainter {
  _LivePing(this.progress) : super(repaint: progress);
  final Animation<double> progress;
  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t == 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CanopySize.stroke
      ..color =
          Canopy.liveCrimson.withValues(alpha: (1 - t) * CanopySize.glassAlpha);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            (Offset.zero & size).inflate(AppTheme.spaceXs * t),
            const Radius.circular(CanopyRadius.pill)),
        paint);
  }

  @override
  bool shouldRepaint(_LivePing old) => progress != old.progress;
}

/// Paint-only entrance; controls keep their original focus and callbacks.
class CanopyContentMotion extends StatelessWidget {
  const CanopyContentMotion(
      {super.key, required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;
  @override
  Widget build(BuildContext context) => CanopyMotion.reduced(context)
      ? child
      : AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = CanopyMotion.reduced(context) ? 1.0 : animation.value;
            return Transform.translate(
                offset: Offset(0, CanopySize.contentRise * (1 - t)),
                child: ImageFiltered(
                    enabled: t < 1,
                    imageFilter: ImageFilter.blur(
                        sigmaX: CanopySize.contentBlur * (1 - t),
                        sigmaY: CanopySize.contentBlur * (1 - t)),
                    child: child));
          });
}

class CaSuccessBloom extends StatelessWidget {
  const CaSuccessBloom({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: !enabled || CanopyMotion.reduced(context)
          ? CanopyMotion.none
          : CanopyMotion.bloom,
      curve: CanopyMotion.easeOut,
      child: child,
      builder: (context, value, child) => CustomPaint(
          painter: _BloomRays(value),
          child: Transform.scale(
              scale: CanopyMotion.reduced(context)
                  ? 1
                  : CanopyMotion.pressScale +
                      (1 - CanopyMotion.pressScale) * value,
              child: child)));
}

class _BloomRays extends CustomPainter {
  const _BloomRays(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    if (value == 1) return;
    final paint = Paint()
      ..color = Canopy.leaf.withValues(alpha: math.sin(value * math.pi))
      ..strokeWidth = CanopySize.stroke;
    final centre = size.center(Offset.zero), radius = size.shortestSide / 2;
    for (var i = 0; i < 8; i++) {
      final direction =
          Offset(math.cos(i * math.pi / 4), math.sin(i * math.pi / 4));
      canvas.drawLine(centre + direction * (radius + AppTheme.spaceXs * value),
          centre + direction * (radius + AppTheme.spaceSm * value), paint);
    }
  }

  @override
  bool shouldRepaint(_BloomRays old) => value != old.value;
}

/// Runs only when an existing selected state becomes true, never on first paint.
class CanopyConfirmMotion extends StatefulWidget {
  const CanopyConfirmMotion(
      {super.key,
      required this.active,
      required this.child,
      this.wiggle = false});
  final bool active, wiggle;
  final Widget child;
  @override
  State<CanopyConfirmMotion> createState() => _CanopyConfirmMotionState();
}

class _CanopyConfirmMotionState extends State<CanopyConfirmMotion>
    with SingleTickerProviderStateMixin {
  late final _motion =
      AnimationController(vsync: this, duration: CanopyMotion.bloom, value: 1);
  @override
  void didUpdateWidget(CanopyConfirmMotion old) {
    super.didUpdateWidget(old);
    if (!old.active && widget.active && !CanopyMotion.reduced(context)) {
      _motion.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanopyMotion.reduced(context)) {
      _motion.stop();
      _motion.value = 1;
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CanopyMotion.reduced(context)
      ? widget.child
      : AnimatedBuilder(
          animation: _motion,
          child: widget.child,
          builder: (context, child) {
            final wave = math.sin(_motion.value * math.pi);
            return widget.wiggle
                ? Transform.rotate(
                    angle: CanopyMotion.reduced(context)
                        ? 0
                        : wave *
                            math.sin(_motion.value * math.pi * 6) *
                            CanopySize.confirmTilt,
                    child: child)
                : Transform.scale(
                    scale: CanopyMotion.reduced(context)
                        ? 1
                        : 1 + wave * CanopySize.confirmScale,
                    child: child);
          });
}

/// The label is spoken once; outgoing counter glyphs are decorative.
class CaRollingCount extends StatelessWidget {
  const CaRollingCount(
      {super.key, required this.value, required this.suffix, this.style});
  final int? value;
  final String suffix;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    final number = value?.toString() ?? '—';
    final reduced = CanopyMotion.reduced(context);
    final type = value == null
        ? style
        : style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    final label = '$number $suffix';
    // Unknown counts appear immediately. Only known-to-known updates roll.
    if (reduced || value == null) return Text(label, style: style);
    return Semantics(
        label: label,
        child: ExcludeSemantics(
            child: ClipRect(
                child: AnimatedSwitcher(
                    duration: reduced ? CanopyMotion.none : CanopyMotion.count,
                    reverseDuration:
                        reduced ? CanopyMotion.none : CanopyMotion.chipOut,
                    switchInCurve: CanopyMotion.easeOut,
                    switchOutCurve: CanopyMotion.easeOut,
                    transitionBuilder: (child, animation) => reduced
                        ? child
                        : FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                                position: animation.drive(Tween(
                                    begin: const Offset(0, 1),
                                    end: Offset.zero)),
                                child: child)),
                    child: Text(label,
                        key: ValueKey(label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type)))));
  }
}

/// Known list geometry; only used on existing page-loading branches.
class CaPageSkeleton extends StatelessWidget {
  const CaPageSkeleton({super.key, this.rows = 3});
  final int rows;
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'ds.loading'.tr(),
      child: ExcludeSemantics(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(children: [
                for (var i = 0; i < rows; i++)
                  const Padding(
                      padding: EdgeInsets.only(bottom: AppTheme.spaceLg),
                      child: CaSkeleton(shape: CaSkeletonShape.row, lines: 2))
              ]))));
}

/// Existing connectivity state enters quietly; no recovery timer is invented.
class CanopyReconnectMotion extends StatelessWidget {
  const CanopyReconnectMotion({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => CanopyMotion.reduced(context)
      ? child
      : TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: CanopyMotion.reduced(context)
              ? CanopyMotion.none
              : CanopyMotion.sheetIn,
          curve: CanopyMotion.drawer,
          child: child,
          builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(
                      0,
                      CanopyMotion.reduced(context)
                          ? 0
                          : -CanopySize.contentRise * (1 - value)),
                  child: child)));
}
