import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../interactive_toast_overlay.dart';
import 'ca_cards.dart';
import 'ca_button.dart';
import 'ca_icon.dart';
import 'canopy_content_motion.dart';

/// Who sent a chat message, as far as its look goes. The avatar ring carries
/// the role, so a message needs no name or badge of its own: broadcasters wear
/// the live ring, admins the green ring, moderators the violet one.
enum CaChatRole { viewer, broadcaster, admin, moderator }

/// One compact chat message: the sender's avatar and a bubble holding the text.
/// Ordinary viewers get their name in front of the text; admins, moderators
/// and the broadcaster are told apart by their ring alone. A message of more
/// than two lines is cut to two, with an arrow at the bottom end to open or
/// close the rest.
class CaChatBubble extends StatefulWidget {
  const CaChatBubble(
      {super.key,
      required this.name,
      required this.message,
      required this.time,
      this.avatarUrl,
      this.isOwn = false,
      this.role = CaChatRole.viewer,
      this.pending = false,
      this.handRaised = false,
      this.dark = false,
      this.showIdentity = true,
      this.animateArrival = false,
      this.onAvatarTap});
  final String name, message, time;
  final String? avatarUrl;
  final bool isOwn, pending, handRaised, dark, showIdentity, animateArrival;
  final CaChatRole role;

  /// Opens the sender's profile.
  final VoidCallback? onAvatarTap;
  @override
  State<CaChatBubble> createState() => _CaChatBubbleState();
}

class _CaChatBubbleState extends State<CaChatBubble>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _arrival;

  @override
  void initState() {
    super.initState();
    _arrival = AnimationController(
        vsync: this,
        duration: CanopyMotion.chatArrival,
        value: widget.animateArrival ? 0 : 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion shows the message at once.
    if (widget.animateArrival &&
        !CanopyMotion.reduced(context) &&
        _arrival.value == 0 &&
        !_arrival.isAnimating) {
      _arrival.forward();
    } else if (CanopyMotion.reduced(context)) {
      _arrival.value = 1;
    }
  }

  @override
  void dispose() {
    _arrival.dispose();
    super.dispose();
  }

  static const _lines = 2;

  CaAvatarRing get _ring => switch (widget.role) {
        CaChatRole.admin => CaAvatarRing.admin,
        CaChatRole.moderator => CaAvatarRing.moderator,
        _ => CaAvatarRing.none,
      };

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final textTheme = Theme.of(context).textTheme;
    final foreground = dark ? Canopy.paper : Canopy.ink;
    final bodyStyle = textTheme.bodyMedium?.copyWith(color: foreground);
    final showName = widget.role == CaChatRole.viewer && !widget.isOwn;
    final span = TextSpan(children: [
      if (showName)
        TextSpan(
            text: '${dark ? '\u2068${widget.name}\u2069' : widget.name}  ',
            style: textTheme.labelLarge?.copyWith(
                color: dark ? Canopy.mist : Canopy.brandGreen,
                fontWeight: FontWeight.w700)),
      TextSpan(text: widget.message),
    ], style: bodyStyle);
    const avatarSize = CanopySize.smallAvatar + AppTheme.spaceSm;
    final avatar = widget.showIdentity
        ? GestureDetector(
            onTap: widget.onAvatarTap,
            child: Semantics(
                button: widget.onAvatarTap != null,
                label: widget.name,
                child: CaAvatar(
                    name: widget.name,
                    url: widget.avatarUrl,
                    radius: 14,
                    live: widget.role == CaChatRole.broadcaster,
                    ring: _ring)))
        : const SizedBox.square(dimension: avatarSize);
    final bubble = LayoutBuilder(builder: (context, constraints) {
      // The raised-hand icon and its gap sit before the text.
      const handWidth = 16.0 + AppTheme.spaceXs;
      const padding = EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm);
      final painter = TextPainter(
          text: span,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: _lines)
        ..layout(
            maxWidth: (constraints.maxWidth -
                    padding.horizontal -
                    (widget.handRaised ? handWidth : 0))
                .clamp(0.0, double.infinity));
      final long = painter.didExceedMaxLines;
      painter.dispose();
      return DecoratedBox(
          decoration: BoxDecoration(
              color: widget.isOwn
                  ? (dark ? Canopy.paper.withValues(alpha: .18) : Canopy.mint)
                  : dark
                      ? Canopy.cinemaBubble
                      : Canopy.paper,
              borderRadius: BorderRadius.circular(CanopyRadius.input),
              boxShadow: dark || widget.isOwn ? null : CanopyShadow.card),
          child: Padding(
              padding: padding,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.handRaised)
                            const Padding(
                                padding: EdgeInsetsDirectional.only(
                                    end: AppTheme.spaceXs),
                                child: Icon(Icons.back_hand_rounded,
                                    size: 16, color: AppTheme.warning)),
                          Expanded(
                              child: Text.rich(span,
                                  maxLines: _open ? null : _lines,
                                  overflow:
                                      _open ? null : TextOverflow.ellipsis)),
                        ]),
                    if (long)
                      Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: InkResponse(
                              onTap: () => setState(() => _open = !_open),
                              radius: 16,
                              child: Semantics(
                                  button: true,
                                  label: (_open
                                          ? 'profile.show_less'
                                          : 'profile.show_more')
                                      .tr(),
                                  child: Icon(
                                      _open
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 20,
                                      color:
                                          dark ? Canopy.mist : Canopy.haze)))),
                  ])));
    });
    final row = Opacity(
        opacity: widget.pending ? .6 : 1,
        child: Semantics(
            container: true,
            label: '${widget.name}, ${widget.time}',
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: widget.isOwn
                    ? (Directionality.of(context) == TextDirection.rtl
                        ? TextDirection.ltr
                        : TextDirection.rtl)
                    : null,
                children: [
                  avatar,
                  const SizedBox(width: AppTheme.spaceSm),
                  Flexible(child: bubble),
                ])));
    if (!widget.animateArrival) return row;
    // A new message rises in while the ones above it slide up together, instead
    // of jumping: its height grows from nothing as it fades and lifts into place.
    return AnimatedBuilder(
        animation: _arrival,
        child: row,
        builder: (context, child) {
          final t = CanopyMotion.easeOut.transform(_arrival.value);
          return ClipRect(
              child: Align(
                  alignment: AlignmentDirectional.topStart,
                  heightFactor: t,
                  child: Opacity(
                      opacity: t,
                      child: Transform.translate(
                          offset: Offset(0, AppTheme.spaceMd * (1 - t)),
                          child: Transform.scale(
                              scale: .98 + .02 * t,
                              alignment: AlignmentDirectional.bottomStart,
                              child: child)))));
        });
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
