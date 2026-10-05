import 'dart:async';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'ca_icon.dart';

Rect? canopyOrigin(BuildContext context) {
  final box = context.findRenderObject();
  return box is RenderBox && box.hasSize
      ? box.localToGlobal(Offset.zero) & box.size
      : null;
}

Widget canopyPageTransition(
    BuildContext context, Animation<double> animation, Widget child,
    {Rect? origin}) {
  if (CanopyMotion.reduced(context)) return child;
  if (origin != null) {
    return CanopyCardReveal(animation: animation, from: origin, child: child);
  }
  final curved = animation.drive(CurveTween(curve: CanopyMotion.easeOut));
  final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
  return AnimatedBuilder(
      animation: curved,
      child: child,
      builder: (context, child) => Opacity(
          opacity: curved.value,
          child: Transform.translate(
              offset: Offset(
                  direction * CanopySize.pageShift * (1 - curved.value), 0),
              child: child)));
}

/// Child controls retain their native activation and focus behavior.
class CanopyPress extends StatefulWidget {
  const CanopyPress({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<CanopyPress> createState() => _CanopyPressState();
}

class _CanopyPressState extends State<CanopyPress> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
      onPointerDown:
          widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
          scale: _pressed && widget.enabled && !CanopyMotion.reduced(context)
              ? CanopyMotion.pressScale
              : 1,
          duration: CanopyMotion.reduced(context)
              ? CanopyMotion.none
              : CanopyMotion.press,
          curve: CanopyMotion.easeOut,
          child: widget.child));
}

/// Source rectangle is relative to this full-page viewport (a caller's card rect).
PageRouteBuilder<T> canopyCardRoute<T>(
        {required Rect from, required WidgetBuilder builder}) =>
    PageRouteBuilder<T>(
        pageBuilder: (context, _, __) => builder(context),
        transitionDuration: CanopyMotion.cardToPage,
        reverseTransitionDuration: CanopyMotion.sheetOut,
        transitionsBuilder: (context, animation, _, child) =>
            CanopyCardReveal(animation: animation, from: from, child: child));

class CanopyCardReveal extends StatelessWidget {
  const CanopyCardReveal(
      {super.key,
      required this.animation,
      required this.from,
      required this.child});
  final Animation<double> animation;
  final Rect from;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
          animation: animation,
          child: child,
          builder: (context, child) {
            final t = CanopyMotion.reduced(context)
                ? 1.0
                : CanopyMotion.easeOut.transform(animation.value);
            final rect = Rect.lerp(from, Offset.zero & constraints.biggest, t)!;
            return ClipRRect(
                borderRadius:
                    BorderRadius.circular(CanopyRadius.card * (1 - t)),
                clipper: _CardClip(rect, CanopyRadius.card * (1 - t)),
                child: child);
          }));
}

class _CardClip extends CustomClipper<RRect> {
  const _CardClip(this.rect, this.radius);
  final Rect rect;
  final double radius;
  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));
  @override
  bool shouldReclip(_CardClip old) => old.rect != rect || old.radius != radius;
}

class CaFloatingReaction extends StatefulWidget {
  const CaFloatingReaction(
      {super.key,
      this.icon = CaGlyph.heart,
      this.onComplete,
      this.drift,
      this.tilt,
      this.child});
  final Widget? child;
  final CaGlyph icon;
  final VoidCallback? onComplete;
  final double? drift, tilt;
  @override
  State<CaFloatingReaction> createState() => _CaFloatingReactionState();
}

class _CaFloatingReactionState extends State<CaFloatingReaction>
    with SingleTickerProviderStateMixin {
  late final _animation =
      AnimationController(vsync: this, duration: CanopyMotion.reaction);
  Timer? _lifetime;
  bool _expired = false;
  final _random = math.Random();
  late final _drift =
      widget.drift ?? (_random.nextDouble() * 2 - 1) * CanopySize.reactionDrift;
  late final _tilt =
      widget.tilt ?? (_random.nextDouble() * 2 - 1) * CanopySize.reactionTilt;
  @override
  void initState() {
    super.initState();
    // Lifetime is unchanged; reduced motion needs no animation frames.
    _lifetime = Timer(CanopyMotion.reaction, () {
      if (!mounted) return;
      _expired = true;
      _animation.value = 1;
      widget.onComplete?.call();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanopyMotion.reduced(context) || _expired) {
      _animation.stop();
    } else {
      _animation.forward();
    }
  }

  @override
  void dispose() {
    _lifetime?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: AnimatedBuilder(
          animation: _animation,
          child: widget.child ??
              CaIcon(widget.icon,
                  color: Canopy.brandGreen, size: CanopySize.reactionIcon),
          builder: (context, child) {
            final t = _animation.value;
            final reduced = CanopyMotion.reduced(context);
            return Opacity(
                opacity: reduced
                    ? (_expired ? 0 : 1)
                    : math.sin(math.pi * t).clamp(0, 1),
                child: Transform.translate(
                    offset: reduced
                        ? Offset.zero
                        : Offset(_drift * math.sin(math.pi * t),
                            -CanopySize.reactionRise * t),
                    child: Transform.rotate(
                        angle: reduced ? 0 : _tilt * math.sin(math.pi * t),
                        child: child)));
          }));
}

class CaLevelMeter extends StatefulWidget {
  const CaLevelMeter({super.key, required this.level, this.label});
  final double level;
  final String? label;
  @override
  State<CaLevelMeter> createState() => _CaLevelMeterState();
}

class _CaLevelMeterState extends State<CaLevelMeter> {
  double get _level => widget.level.isFinite ? widget.level.clamp(0, 1) : 0;
  late double _previous = _level, _peak = _level;
  Timer? _hold;
  @override
  void didUpdateWidget(CaLevelMeter old) {
    super.didUpdateWidget(old);
    _previous = old.level.isFinite ? old.level.clamp(0, 1) : 0;
    if (_level >= _peak) {
      _peak = _level;
      _hold?.cancel();
      _hold = Timer(CanopyMotion.meterPeak, () {
        if (mounted) setState(() => _peak = _level);
      });
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
      label: widget.label ?? 'ds.audio_level'.tr(),
      value: '${(_level * 100).round()}%',
      child: TweenAnimationBuilder<double>(
          tween: Tween(begin: _previous, end: _level),
          duration: CanopyMotion.reduced(context)
              ? CanopyMotion.none
              : _level > _previous
                  ? CanopyMotion.meterRise
                  : CanopyMotion.meterFall,
          curve: CanopyMotion.easeOut,
          builder: (context, value, _) =>
              LayoutBuilder(builder: (context, constraints) {
                final color = _level >= CanopySize.clippingThreshold
                    ? Canopy.liveCrimson
                    : _level >= CanopySize.warningThreshold
                        ? Canopy.warning
                        : Canopy.brandGreen;
                return SizedBox(
                    height: CanopySize.meterHeight,
                    child: Stack(children: [
                      Positioned.fill(
                          child: DecoratedBox(
                              decoration: BoxDecoration(
                                  color: Canopy.mint,
                                  borderRadius: BorderRadius.circular(
                                      CanopyRadius.pill)))),
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: FractionallySizedBox(
                              widthFactor: value,
                              child: Container(
                                  height: CanopySize.meterHeight,
                                  decoration: BoxDecoration(
                                      color:
                                          _level >= CanopySize.warningThreshold
                                              ? color
                                              : null,
                                      gradient:
                                          _level < CanopySize.warningThreshold
                                              ? CanopyGradients.pillWide
                                              : null,
                                      borderRadius: BorderRadius.circular(
                                          CanopyRadius.pill))))),
                      PositionedDirectional(
                          start: (_peak * constraints.maxWidth -
                                  CanopySize.meterDot)
                              .clamp(0,
                                  constraints.maxWidth - CanopySize.meterDot),
                          child: Container(
                              width: CanopySize.meterDot,
                              height: CanopySize.meterHeight,
                              decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(
                                      CanopyRadius.pill)))),
                    ]));
              })));
}
