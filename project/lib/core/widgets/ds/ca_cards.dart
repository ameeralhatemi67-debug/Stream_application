import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../safe_image_provider.dart';
import '../streamer_avatar.dart';
import 'ca_icon.dart';
import 'ca_focus_ring.dart';
import 'canopy_content_motion.dart';

enum CaCardVariant { flat, raised, feature }

class CaCard extends StatelessWidget {
  const CaCard(
      {super.key,
      required this.child,
      this.variant = CaCardVariant.raised,
      this.onTap,
      this.padding = const EdgeInsets.all(AppTheme.spaceLg)});
  final Widget child;
  final CaCardVariant variant;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
          color: Canopy.paper,
          borderRadius: BorderRadius.circular(CanopyRadius.card),
          boxShadow: variant == CaCardVariant.flat
              ? null
              : [
                  if (variant == CaCardVariant.feature) ...CanopyShadow.bezel,
                  ...CanopyShadow.card,
                ]),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(CanopyRadius.card),
          child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                  onTap: onTap,
                  child: Padding(padding: padding, child: child)))),
    );
    return onTap == null
        ? card
        : CaFocusRing(radius: CanopyRadius.card, child: card);
  }
}

enum CaStatusKind { live, audio, offline, pending, verified }

class CaStatusChip extends StatelessWidget {
  const CaStatusChip({super.key, required this.kind, this.label});
  final CaStatusKind kind;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final foreground = switch (kind) {
      CaStatusKind.live || CaStatusKind.audio => Canopy.paper,
      CaStatusKind.pending => Canopy.warning,
      CaStatusKind.verified => Canopy.brandGreen,
      CaStatusKind.offline => Canopy.slate,
    };
    final background = switch (kind) {
      CaStatusKind.live => null,
      CaStatusKind.audio => Canopy.infoTeal,
      CaStatusKind.offline => Canopy.mist,
      CaStatusKind.pending => Canopy.warningTint,
      CaStatusKind.verified => Canopy.mint,
    };
    final icon = switch (kind) {
      CaStatusKind.audio => CaGlyph.mic,
      CaStatusKind.pending => CaGlyph.clock,
      CaStatusKind.verified => CaGlyph.check,
      _ => null,
    };
    return CanopyLivePulse(
        enabled: kind == CaStatusKind.live,
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
          decoration: BoxDecoration(
              color: background,
              gradient:
                  kind == CaStatusKind.live ? AppGradients.liveSignal : null,
              borderRadius: BorderRadius.circular(CanopyRadius.pill),
              border: kind == CaStatusKind.verified
                  ? Border.all(color: Canopy.majlisGold)
                  : null),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              CaIcon(icon, color: foreground, size: CanopySize.inlineIcon),
              const SizedBox(width: AppTheme.spaceXs)
            ],
            Flexible(
                child: Text(label ?? 'ds.status_${kind.name}'.tr(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: foreground, fontWeight: FontWeight.w600))),
          ]),
        ));
  }
}

class CaAvatar extends StatefulWidget {
  const CaAvatar(
      {super.key,
      required this.name,
      this.url,
      this.radius = CanopySize.avatarRadius,
      this.live = false,
      this.verified = false,
      this.org = false});
  final String name;
  final String? url;
  final double radius;
  final bool live, verified, org;
  @override
  State<CaAvatar> createState() => _CaAvatarState();
}

class _CaAvatarState extends State<CaAvatar>
    with SingleTickerProviderStateMixin {
  late final _ring =
      AnimationController(vsync: this, duration: CanopyMotion.avatarRing);
  void _sync() {
    if (widget.live && !widget.org && !CanopyMotion.reduced(context)) {
      if (!_ring.isAnimating) _ring.repeat();
    } else {
      _ring.stop();
      _ring.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(CaAvatar old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.name.trim();
    final initial = name.isEmpty
        ? '?'
        : String.fromCharCodes(name.runes.take(1)).toUpperCase();
    final fallback = DecoratedBox(
        decoration:
            const BoxDecoration(gradient: CanopyGradients.avatarFallback),
        child: Center(
            child: Text(initial,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Canopy.brandGreen, fontSize: widget.radius))));
    final diameter = widget.radius * 2;
    final content = StreamerAvatar(
        avatarUrl: widget.url,
        radius: widget.radius,
        name: widget.name,
        square: widget.org,
        cornerRadius: CanopyRadius.orgAvatar,
        placeholder: fallback);
    return SizedBox.square(
        dimension: diameter + AppTheme.spaceXs,
        child: Stack(clipBehavior: Clip.none, children: [
          if (widget.live)
            Positioned.fill(
                child: widget.org
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                            gradient: AppGradients.ring,
                            borderRadius:
                                BorderRadius.circular(CanopyRadius.orgAvatar)))
                    : RotationTransition(
                        turns: _ring,
                        child: const DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: AppGradients.ring,
                                shape: BoxShape.circle)))),
          Padding(
              padding: const EdgeInsets.all(CanopySize.ring), child: content),
          if (widget.verified)
            PositionedDirectional(
                top: 0,
                end: 0,
                child: Semantics(
                    label: 'ds.status_verified'.tr(),
                    child: const CaIcon(CaGlyph.verified,
                        size: CanopySize.verifiedIcon + CanopySize.ring * 2))),
        ]));
  }
}

class CaPersonRow extends StatelessWidget {
  const CaPersonRow(
      {super.key,
      required this.name,
      this.subtitle,
      this.avatarUrl,
      this.live = false,
      this.verified = false,
      this.onTap,
      this.trailing});
  final String name;
  final String? subtitle, avatarUrl;
  final bool live, verified;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => CaFocusRing(
      radius: CanopyRadius.input,
      child: Material(
          type: MaterialType.transparency,
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(CanopyRadius.input),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: CanopySize.target),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
                    child: Row(children: [
                      CaAvatar(
                          name: name,
                          url: avatarUrl,
                          live: live,
                          verified: verified),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(name,
                                style: Theme.of(context).textTheme.labelLarge),
                            if (subtitle != null)
                              Text(subtitle!,
                                  style: Theme.of(context).textTheme.bodySmall),
                          ])),
                      if (trailing != null) ...[
                        const SizedBox(width: AppTheme.spaceSm),
                        trailing!
                      ],
                    ])),
              ))));
}

class CaScholarCard extends StatelessWidget {
  const CaScholarCard(
      {super.key,
      required this.name,
      required this.subtitle,
      this.avatarUrl,
      this.bannerUrl,
      this.live = false,
      this.verified = false,
      this.org = false,
      this.onTap,
      this.statusLabel,
      this.bannerHeight = CanopySize.cardBanner,
      this.footer,
      this.statusKind,
      this.largeAvatar = false,
      this.bannerOverlay});
  final double bannerHeight;
  final Widget? footer;

  /// A bigger avatar that sits half over the banner's lower edge.
  final bool largeAvatar;

  /// Pinned to the banner's top end corner (top left in Arabic). When set, the
  /// status chip is not repeated in the card body; the overlay carries it.
  final Widget? bannerOverlay;
  static const _largeAvatarRadius = 34.0;
  final CaStatusKind? statusKind;
  final String name, subtitle;
  final String? avatarUrl, bannerUrl, statusLabel;
  final bool live, verified, org;
  final VoidCallback? onTap;

  /// Use the available content width, after screen inset, rather than a breakpoint.
  static int columnsForWidth(double width, {double gap = AppTheme.spaceMd}) =>
      (width - gap) / 2 >= CanopyWindow.scholarCardMinWidth ? 2 : 1;
  @override
  Widget build(BuildContext context) => CaCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                height: bannerHeight,
                width: double.infinity,
                child: Stack(fit: StackFit.expand, children: [
                  _CardImage(url: bannerUrl),
                  if (bannerOverlay != null)
                    PositionedDirectional(
                        top: AppTheme.spaceSm,
                        end: AppTheme.spaceSm,
                        child: bannerOverlay!),
                ])),
            Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceLg),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (largeAvatar)
                        _largeAvatarRow(context)
                      else
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Transform.translate(
                                  offset: const Offset(
                                      0, -CanopySize.avatarOverlap),
                                  child: CaAvatar(
                                      name: name,
                                      url: avatarUrl,
                                      live: live,
                                      verified: verified,
                                      org: org)),
                              const SizedBox(width: AppTheme.spaceSm),
                              Expanded(
                                  child: Padding(
                                      padding: const EdgeInsets.only(
                                          top: AppTheme.spaceSm),
                                      child: Text(name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall))),
                            ]),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall),
                      if (bannerOverlay == null) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        CaStatusChip(
                            kind: statusKind ??
                                (live
                                    ? CaStatusKind.live
                                    : CaStatusKind.offline),
                            label: statusLabel),
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        footer!
                      ],
                    ])),
          ]));
}

extension on CaScholarCard {
  /// The avatar straddles the banner edge by half its height; the name sits
  /// beside its lower half, so the card does not grow by the overlap.
  Widget _largeAvatarRow(BuildContext context) {
    const radius = CaScholarCard._largeAvatarRadius;
    const box = radius * 2 + AppTheme.spaceXs;
    return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: box - radius),
        child: Stack(clipBehavior: Clip.none, children: [
          Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: box + AppTheme.spaceMd, top: AppTheme.spaceSm),
              child: Text(name, style: Theme.of(context).textTheme.titleSmall)),
          PositionedDirectional(
              start: 0,
              top: -radius,
              child: CaAvatar(
                  name: name,
                  url: avatarUrl,
                  radius: radius,
                  live: live,
                  verified: verified,
                  org: org)),
        ]));
  }
}

class CaLectureTile extends StatelessWidget {
  const CaLectureTile(
      {super.key,
      required this.title,
      required this.meta,
      this.imageUrl,
      this.duration,
      this.onTap,
      this.stacked = false,
      this.statusKind});
  final String title, meta;
  final String? imageUrl, duration;
  final VoidCallback? onTap;
  final bool stacked;
  final CaStatusKind? statusKind;
  @override
  Widget build(BuildContext context) {
    final image = Stack(fit: StackFit.expand, children: [
      _CardImage(url: imageUrl),
      if (duration != null) ...[
        const DecoratedBox(
            decoration: BoxDecoration(gradient: AppGradients.mediaScrim)),
        PositionedDirectional(
            bottom: AppTheme.spaceXs,
            end: AppTheme.spaceXs,
            child: Container(
                padding: const EdgeInsets.all(AppTheme.spaceXs),
                decoration: BoxDecoration(
                    color: Canopy.forestDeep,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs)),
                child: Text(duration!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Canopy.paper,
                        fontFeatures: const [FontFeature.tabularFigures()])))),
      ],
    ]);
    final thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(CanopyRadius.input),
        child: stacked
            ? AspectRatio(aspectRatio: 16 / 9, child: image)
            : SizedBox(
                width: CanopySize.lectureImageWidth,
                height: CanopySize.lectureImageHeight,
                child: image));
    final details = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statusKind != null) ...[
            CaStatusChip(kind: statusKind!),
            const SizedBox(height: AppTheme.spaceXs)
          ],
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: Canopy.ink)),
          const SizedBox(height: AppTheme.spaceXs),
          Text(meta, style: Theme.of(context).textTheme.bodySmall),
        ]);
    return CaCard(
        variant: CaCardVariant.flat,
        onTap: onTap,
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    thumbnail,
                    const SizedBox(height: AppTheme.spaceMd),
                    details
                  ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                thumbnail,
                const SizedBox(width: AppTheme.spaceMd),
                Expanded(child: details)
              ]));
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) {
    const fallback =
        DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.canopy));
    final image = resolveImageProviderOrNull(url);
    if (image == null) return fallback;
    return LayoutBuilder(
        builder: (context, constraints) => Image(
            image: downscaledImage(image,
                width: (constraints.maxWidth *
                        MediaQuery.devicePixelRatioOf(context))
                    .round()),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback));
  }
}

/// A card or banner picture that falls back to the canopy gradient.
class CaCardImage extends StatelessWidget {
  const CaCardImage({super.key, this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => _CardImage(url: url);
}
