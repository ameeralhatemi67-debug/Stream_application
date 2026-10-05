import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../interactive_toast_overlay.dart';
import 'ca_cards.dart';
import 'ca_button.dart';
import 'ca_icon.dart';
import 'canopy_content_motion.dart';

class CaChatBubble extends StatelessWidget {
  const CaChatBubble(
      {super.key,
      required this.name,
      required this.message,
      required this.time,
      this.avatarUrl,
      this.isOwn = false,
      this.isSpeaker = false,
      this.verified = false,
      this.dark = false,
      this.showIdentity = true,
      this.animateArrival = false,
      this.roleBadges = const []});
  final String name, message, time;
  final String? avatarUrl;
  final bool isOwn, isSpeaker, verified, dark, showIdentity, animateArrival;
  final List<({CaGlyph icon, String label})> roleBadges;
  @override
  Widget build(BuildContext context) {
    final foreground = dark && !isSpeaker ? Canopy.paper : Canopy.ink;
    final bubble = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: isOwn
            ? (Directionality.of(context) == TextDirection.rtl
                ? TextDirection.ltr
                : TextDirection.rtl)
            : null,
        children: [
          if (showIdentity)
            CaAvatar(
                name: name, url: avatarUrl, radius: CanopySize.smallAvatar / 2)
          else
            const SizedBox.square(dimension: CanopySize.smallAvatar),
          const SizedBox(width: AppTheme.spaceSm),
          Flexible(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                        color: isSpeaker
                            ? Canopy.mint
                            : dark
                                ? Canopy.cinemaBubble
                                : Canopy.paper,
                        borderRadius:
                            BorderRadius.circular(CanopyRadius.input)),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showIdentity)
                            Wrap(
                                spacing: AppTheme.spaceXs,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(dark ? '\u2068$name\u2069' : name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(color: foreground)),
                                  if (roleBadges.isNotEmpty)
                                    for (final badge in roleBadges)
                                      CaIcon(badge.icon,
                                          color: foreground,
                                          size: CanopySize.inlineIcon,
                                          label: badge.label)
                                  else if (isSpeaker || verified)
                                    CaIcon(
                                        isSpeaker ? CaGlyph.mic : CaGlyph.check,
                                        size: CanopySize.inlineIcon,
                                        label: (isSpeaker
                                                ? 'ds.speaker'
                                                : 'ds.status_verified')
                                            .tr()),
                                ]),
                          Text(message,
                              style: dark
                                  ? Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: foreground)
                                  : Theme.of(context).textTheme.bodyMedium),
                        ])),
                Padding(
                    padding: const EdgeInsetsDirectional.only(
                        start: AppTheme.spaceMd, top: AppTheme.spaceXs),
                    child: Text(time,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: dark ? Canopy.mist : Canopy.haze,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ]))),
              ])),
        ]);
    if (!animateArrival) return bubble;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: CanopyMotion.reduced(context)
          ? CanopyMotion.none
          : CanopyMotion.chatArrival,
      curve: CanopyMotion.easeOut,
      child: bubble,
      builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(
                  0,
                  CanopyMotion.reduced(context)
                      ? 0
                      : AppTheme.spaceSm * (1 - value)),
              child: child)),
    );
  }
}

class CaToast extends StatelessWidget {
  const CaToast(
      {super.key,
      required this.title,
      required this.message,
      this.icon = CaGlyph.check,
      this.error = false,
      this.onTap,
      this.onDismissed,
      this.actionLabel,
      this.onActionPressed,
      this.dismissLabel});
  final String title, message;
  final CaGlyph icon;
  final bool error;
  final VoidCallback? onTap, onDismissed, onActionPressed;
  final String? actionLabel, dismissLabel;
  static void show(BuildContext context,
          {required String title,
          required String message,
          CaGlyph icon = CaGlyph.check,
          bool error = false,
          VoidCallback? onTap,
          String? actionLabel,
          VoidCallback? onActionPressed,
          Duration duration = CanopyMotion.toastLifetime}) =>
      InteractiveToastOverlay.showWidget(context,
          duration: duration,
          builder: (ctx, dismiss) => PositionedDirectional(
              bottom: MediaQuery.paddingOf(ctx).bottom + AppTheme.spaceMd,
              start: AppTheme.spaceMd,
              end: AppTheme.spaceMd,
              child: SafeArea(
                  top: false,
                  child: CaToast(
                      title: title,
                      message: message,
                      icon: icon,
                      error: error,
                      onDismissed: dismiss,
                      onTap: () {
                        dismiss();
                        onTap?.call();
                      },
                      actionLabel: actionLabel,
                      onActionPressed: () {
                        dismiss();
                        onActionPressed?.call();
                      }))));
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      container: true,
      child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: CanopyMotion.reduced(context)
              ? CanopyMotion.none
              : CanopyMotion.toastIn,
          curve: CanopyMotion.easeOut,
          builder: (ctx, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(
                      0,
                      CanopyMotion.reduced(ctx)
                          ? 0
                          : CanopySize.toastRise * (1 - value)),
                  child: child)),
          child: Dismissible(
              key: ValueKey(this),
              direction: onDismissed == null
                  ? DismissDirection.none
                  : DismissDirection.up,
              movementDuration: CanopyMotion.reduced(context)
                  ? CanopyMotion.none
                  : CanopyMotion.toastOut,
              resizeDuration: null,
              onDismissed: (_) => onDismissed?.call(),
              child: Container(
                  decoration: BoxDecoration(
                      color: Canopy.paper,
                      borderRadius: BorderRadius.circular(CanopyRadius.pill),
                      boxShadow: CanopyShadow.floating),
                  child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                          onTap: onTap,
                          borderRadius:
                              BorderRadius.circular(CanopyRadius.pill),
                          child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spaceMd),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    CaSuccessBloom(
                                        enabled:
                                            !error && icon == CaGlyph.check,
                                        child: Container(
                                            width: CanopySize.toastDisc,
                                            height: CanopySize.toastDisc,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: error
                                                    ? AppGradients.liveSignal
                                                    : AppGradients.pill),
                                            child: Center(
                                                child: icon == CaGlyph.check &&
                                                        !error
                                                    ? CanopyCheckDraw(
                                                        child: CaIcon(icon,
                                                            color: Canopy.paper,
                                                            size: CanopySize
                                                                .inlineIcon))
                                                    : CaIcon(icon,
                                                        color: Canopy.paper,
                                                        size: CanopySize
                                                            .inlineIcon)))),
                                    const SizedBox(width: AppTheme.spaceSm),
                                    Expanded(
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge),
                                          Text(message,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall),
                                          if (actionLabel != null)
                                            CaButton(
                                                label: actionLabel!,
                                                variant: CaButtonVariant.text,
                                                onPressed:
                                                    onActionPressed ?? onTap),
                                        ])),
                                    if (onDismissed != null)
                                      CaIconButton(
                                          icon: CaGlyph.close,
                                          label:
                                              dismissLabel ?? 'ds.dismiss'.tr(),
                                          onPressed: onDismissed),
                                  ]))))))));
}

enum CaSkeletonShape { line, card, avatar, row }

class CaSkeleton extends StatefulWidget {
  const CaSkeleton(
      {super.key,
      this.shape = CaSkeletonShape.line,
      this.lines = 3,
      this.width,
      this.height,
      this.label});
  final CaSkeletonShape shape;
  final int lines;
  final double? width, height;
  final String? label;
  @override
  State<CaSkeleton> createState() => _CaSkeletonState();
}

class _CaSkeletonState extends State<CaSkeleton>
    with SingleTickerProviderStateMixin {
  late final _shimmer =
      AnimationController(vsync: this, duration: CanopyMotion.shimmer);
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (CanopyMotion.reduced(context)) {
      _shimmer.stop();
      _shimmer.value = 0;
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  Widget _block({double? width, double? height, bool round = false}) => ClipRRect(
      borderRadius:
          BorderRadius.circular(round ? CanopyRadius.pill : CanopyRadius.input),
      child: SizedBox(
          width: width,
          height: height ?? CanopySize.skeletonLine,
          child: ColoredBox(
              color: Canopy.mint,
              child: CanopyMotion.reduced(context)
                  ? null
                  : AnimatedBuilder(
                      animation: _shimmer,
                      builder: (ctx, _) => LayoutBuilder(
                          builder: (ctx, constraints) => Transform.translate(
                              offset: Offset(
                                  (Directionality.of(ctx) == TextDirection.rtl ? -1 : 1) *
                                      (2 * _shimmer.value - 1) *
                                      constraints.maxWidth,
                                  0),
                              child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                      gradient: CanopyGradients.skeleton))))))));
  @override
  Widget build(BuildContext context) => Semantics(
      label: widget.label ?? 'ds.loading'.tr(),
      child: ExcludeSemantics(
          child: RepaintBoundary(
              child: switch (widget.shape) {
        CaSkeletonShape.line =>
          _block(width: widget.width, height: widget.height),
        CaSkeletonShape.avatar => _block(
            width: widget.width ?? CanopySize.target,
            height: widget.height ?? CanopySize.target,
            round: true),
        CaSkeletonShape.card => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _block(
                    width: widget.width,
                    height: widget.height ?? CanopySize.cardBanner),
                const SizedBox(height: AppTheme.spaceMd),
                for (var i = 0; i < widget.lines; i++)
                  Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                      child: FractionallySizedBox(
                          widthFactor: i.isEven ? .8 : .55, child: _block())),
              ]),
        CaSkeletonShape.row => Row(children: [
            _block(
                width: CanopySize.target,
                height: CanopySize.target,
                round: true),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < widget.lines; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                    child: _block())
            ])),
          ]),
      })));
}

class CaEmptyState extends StatelessWidget {
  const CaEmptyState(
      {super.key,
      required this.title,
      required this.body,
      this.action,
      this.icon = CaGlyph.bell});
  final String title, body;
  final Widget? action;
  final CaGlyph icon;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: CanopyMotion.reduced(context)
          ? CanopyMotion.none
          : CanopyMotion.emptyDraw,
      curve: CanopyMotion.easeOut,
      builder: (ctx, value, _) =>
          Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: CanopySize.emptyArtWidth,
                height: CanopySize.emptyArtHeight,
                child: CustomPaint(
                    painter: _Arches(value),
                    child: Center(child: CaIcon(icon)))),
            const SizedBox(height: AppTheme.spaceLg),
            Opacity(
                opacity: value,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(title,
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: AppTheme.spaceSm),
                  Text(body,
                      textAlign: TextAlign.center,
                      style: Theme.of(ctx)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Canopy.slate)),
                  if (action != null) ...[
                    const SizedBox(height: AppTheme.spaceLg),
                    action!
                  ],
                ])),
          ]));
}

class _Arches extends CustomPainter {
  const _Arches(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Canopy.mist
      ..style = PaintingStyle.stroke
      ..strokeWidth = CanopySize.ring;
    for (var i = 0; i < 3; i++) {
      final inset = AppTheme.spaceSm + i * AppTheme.spaceMd;
      final path = Path()
        ..moveTo(inset, size.height)
        ..lineTo(inset, size.height / 2)
        ..arcTo(Rect.fromLTRB(inset, 0, size.width - inset, size.height),
            math.pi, math.pi, false)
        ..lineTo(size.width - inset, size.height);
      final metric = path.computeMetrics().first;
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_Arches old) => old.progress != progress;
}
