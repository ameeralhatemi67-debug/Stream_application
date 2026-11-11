import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_identity.dart';
import '../../../../core/widgets/hedayah/hedayah_rosette.dart';
import '../../../../core/widgets/lantern/lantern.dart';

/// How the opening screen is doing while the app gets ready.
enum LanternOpeningState { opening, slow, offline }

/// The opening screen of Lantern and Arch: on a night ground the lattice
/// fades in, the arch is drawn as one gold stroke, the star crowns it, the
/// white Hedayah logo rises inside, then the name and a gilt progress line.
///
/// It plays once while the app starts and never holds the app back longer
/// than [LanternOpening.minimumShow]; Skip ends even that. On a slow network
/// it offers to continue with what has loaded, and without a connection it
/// offers to try again. Under calm motion the last frame shows at once.
class LanternOpeningView extends StatefulWidget implements LanternSkinWidget {
  const LanternOpeningView(
      {super.key,
      this.state = LanternOpeningState.opening,
      this.retrying = false,
      this.onSkip,
      this.onContinue,
      this.onRetry});

  final LanternOpeningState state;
  final bool retrying;
  final VoidCallback? onSkip, onContinue, onRetry;

  @override
  State<LanternOpeningView> createState() => _LanternOpeningViewState();
}

/// The opening's timings, in one place so they are easy to change.
abstract final class LanternOpening {
  /// The whole drawing, from the first line to the full progress line.
  static const play = Duration(milliseconds: 2400);

  /// The least time the opening shows when motion is on: long enough to see
  /// the arch drawn and the logo arrive. The app opens the next page as soon
  /// as it is ready after this.
  static const minimumShow = Duration(milliseconds: 1500);

  /// The least time under calm motion, where there is nothing to watch.
  static const minimumShowCalm = Duration(milliseconds: 300);

  /// After this long without being ready, the screen says the network is
  /// slow and offers to continue.
  static const slowAfter = Duration(seconds: 6);
}

class _LanternOpeningViewState extends State<LanternOpeningView>
    with TickerProviderStateMixin {
  late final AnimationController _play =
      AnimationController(vsync: this, duration: LanternOpening.play);
  late final AnimationController _wait = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Lantern.calm(context)) {
      _play.value = 1;
    } else {
      // When the drawing is done and the app is still loading, the progress
      // line keeps moving.
      _play.forward().whenComplete(() {
        if (mounted && !Lantern.calm(context)) _wait.repeat();
      });
    }
  }

  @override
  void dispose() {
    _play.dispose();
    _wait.dispose();
    super.dispose();
  }

  Animation<double> _part(double from, double to, [Curve curve = Lantern.ease]) =>
      CurvedAnimation(parent: _play, curve: Interval(from, to, curve: curve));

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final name = AppIdentity.name(lang);
    final offline = widget.state == LanternOpeningState.offline;
    final slow = widget.state == LanternOpeningState.slow;
    final logoIn = _part(.26, .56);
    final nameIn = _part(.46, .68);
    final barIn = _part(.56, 1, Curves.easeInOut);
    return LanternSurface(
        night: true,
        child: Scaffold(
            backgroundColor: LanternTokens.nightGround,
            body: Semantics(
                container: true,
                liveRegion: true,
                label: 'lantern.opening.label'.tr(args: [name]),
                child: Stack(fit: StackFit.expand, children: [
                  FadeTransition(
                      opacity: _part(0, .3),
                      child: const Stack(fit: StackFit.expand, children: [
                        DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: RadialGradient(
                                    center: Alignment(0, -.25),
                                    radius: .9,
                                    colors: [
                              Color(0x40BD933F),
                              Color(0x00BD933F)
                            ]))),
                        LLattice(opacity: .12, step: 44),
                      ])),
                  SafeArea(
                      child: Center(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 24),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                        width: 190,
                                        height: 226,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Positioned.fill(
                                                  child: CustomPaint(
                                                      painter:
                                                          _ArchStroke(_play))),
                                              Positioned(
                                                  top: 78,
                                                  left: 0,
                                                  right: 0,
                                                  child: FadeTransition(
                                                      opacity: logoIn,
                                                      child: SlideTransition(
                                                          position: Tween(
                                                                  begin:
                                                                      const Offset(
                                                                          0,
                                                                          .14),
                                                                  end: Offset
                                                                      .zero)
                                                              .animate(logoIn),
                                                          child:
                                                              const _Lockup()))),
                                            ])),
                                    const SizedBox(height: 22),
                                    FadeTransition(
                                        opacity: nameIn,
                                        child: Column(children: [
                                          ExcludeSemantics(
                                              child: Text(name,
                                                  textAlign: TextAlign.center,
                                                  style: Lantern.displayStyle(
                                                      25,
                                                      color: const Color(
                                                          0xFFFBF7ED),
                                                      height: 1.4))),
                                          const SizedBox(height: 4),
                                          Text('lantern.opening.subtitle'.tr(),
                                              textAlign: TextAlign.center,
                                              style: Lantern.textStyle(13.5,
                                                  color:
                                                      const Color(0xFFAEB9C2))),
                                        ])),
                                    const SizedBox(height: 22),
                                    if (!offline)
                                      SizedBox(
                                          width: 190,
                                          height: 3,
                                          child: CustomPaint(
                                              painter: _ProgressLine(
                                                  fill: barIn,
                                                  wait: _wait,
                                                  rtl: Directionality.of(
                                                          context) ==
                                                      ui.TextDirection.rtl))),
                                    const SizedBox(height: 12),
                                    if (!offline && !slow)
                                      AnimatedBuilder(
                                          animation: _play,
                                          builder: (context, _) => Text(
                                              (_play.value < .5
                                                      ? 'lantern.opening.step_live'
                                                      : _play.value < 1
                                                          ? 'lantern.opening.step_order'
                                                          : 'lantern.opening.step_ready')
                                                  .tr(),
                                              textAlign: TextAlign.center,
                                              style: Lantern.textStyle(12.5,
                                                  color:
                                                      const Color(0xFF9AA7B1)))),
                                    if (slow)
                                      _Notice(
                                          key: const ValueKey(
                                              'lantern-opening-slow'),
                                          icon: LGlyph.signal,
                                          text: 'lantern.opening.slow'.tr(),
                                          action: LButton(
                                              label: 'lantern.opening.continue'
                                                  .tr(),
                                              kind: LButtonKind.secondary,
                                              size: LButtonSize.small,
                                              onPressed: widget.onContinue)),
                                    if (offline)
                                      _Notice(
                                          key: const ValueKey(
                                              'lantern-opening-offline'),
                                          icon: LGlyph.wifioff,
                                          text: 'lantern.opening.offline'.tr(),
                                          action: LButton(
                                              label:
                                                  'lantern.opening.retry'.tr(),
                                              icon: LGlyph.refresh,
                                              size: LButtonSize.small,
                                              loading: widget.retrying,
                                              onPressed: widget.onRetry)),
                                  ])))),
                  if (widget.onSkip != null)
                    PositionedDirectional(
                        top: MediaQuery.paddingOf(context).top + 8,
                        end: 12,
                        child: LButton(
                            label: 'lantern.opening.skip'.tr(),
                            kind: LButtonKind.ghost,
                            size: LButtonSize.small,
                            onPressed: widget.onSkip)),
                ]))));
  }
}

/// The white Hedayah logo as it stands inside the arch: the rosette over the
/// wordmark.
class _Lockup extends StatelessWidget {
  const _Lockup();

  @override
  Widget build(BuildContext context) => Semantics(
      image: true,
      label: 'هداية',
      child: ExcludeSemantics(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const HedayahRosette(size: 62, color: LanternTokens.white),
        const SizedBox(height: 10),
        Image.asset(LLogo.wordmark,
            height: 30,
            fit: BoxFit.contain,
            color: LanternTokens.white,
            colorBlendMode: BlendMode.srcIn),
      ])));
}

class _Notice extends StatelessWidget {
  const _Notice(
      {super.key,
      required this.icon,
      required this.text,
      required this.action});

  final LGlyph icon;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          LIcon(icon, size: 18, color: LanternTokens.goldHi),
          const SizedBox(width: 8),
          Flexible(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: Lantern.textStyle(13.5,
                      color: LanternTokens.onNight,
                      weight: FontWeight.w500,
                      height: 1.45))),
        ]),
        const SizedBox(height: 12),
        action,
      ]));
}

/// The arch drawn as one stroke (0 to 58% of the play), a thinner arch
/// inside it, and the star that pops on at the crown (46 to 60%).
class _ArchStroke extends CustomPainter {
  _ArchStroke(this.play) : super(repaint: play);

  final Animation<double> play;

  @override
  void paint(Canvas canvas, Size size) {
    // The design's 220 x 260 drawing, scaled to this box.
    final k = size.width / 220;
    canvas.scale(k);
    final outer = Path()
      ..moveTo(14, 252)
      ..lineTo(14, 110)
      ..arcToPoint(const Offset(206, 110), radius: const Radius.circular(96))
      ..lineTo(206, 252)
      ..close();
    final inner = Path()
      ..moveTo(30, 252)
      ..lineTo(30, 114)
      ..arcToPoint(const Offset(190, 114), radius: const Radius.circular(80))
      ..lineTo(190, 252);
    void draw(Path path, double from, double to, Paint paint) {
      final t =
          Lantern.ease.transform(((play.value - from) / (to - from)).clamp(0, 1));
      if (t <= 0) return;
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
      }
    }

    draw(
        outer,
        0,
        .58,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [LanternTokens.goldHi, LanternTokens.gold])
              .createShader(const Rect.fromLTWH(0, 0, 220, 260)));
    draw(
        inner,
        .1,
        .62,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = LanternTokens.gold.withValues(alpha: .55));
    final pop = Curves.easeOutBack
        .transform(((play.value - .46) / .14).clamp(0.0, 1.0));
    if (pop > 0) {
      const star = Size.square(46);
      canvas
        ..save()
        ..translate(110, 14)
        ..scale(pop)
        ..translate(-star.width / 2, -star.height / 2)
        ..drawPath(
            lanternStarPath(star), Paint()..color = LanternTokens.goldHi)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_ArchStroke old) => false;
}

/// The gilt progress line: it fills once with the play, then a light runs
/// along it for as long as the app is still loading.
class _ProgressLine extends CustomPainter {
  _ProgressLine({required this.fill, required this.wait, required this.rtl})
      : super(repaint: Listenable.merge([fill, wait]));

  final Animation<double> fill, wait;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, radius),
        Paint()..color = const Color(0x29FFFFFF));
    final width = size.width * fill.value;
    if (width <= 0) return;
    final rect = rtl
        ? Rect.fromLTWH(size.width - width, 0, width, size.height)
        : Rect.fromLTWH(0, 0, width, size.height);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..shader = Lantern.progressFill.createShader(Offset.zero & size));
    if (!wait.isAnimating) return;
    final at = rtl ? 1 - wait.value : wait.value;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * at - 24, 0, 48, size.height)
                .intersect(Offset.zero & size),
            radius),
        Paint()..color = const Color(0xB3FFFFFF));
  }

  @override
  bool shouldRepaint(_ProgressLine old) => old.rtl != rtl;
}
