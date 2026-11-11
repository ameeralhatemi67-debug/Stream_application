import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../features/lessons/presentation/lessons_icons.dart';
import '../../../features/lessons/presentation/lessons_kit.dart'
    show TBtn, TTone, TSegOption;
import '../../../features/web/presentation/hidayah_web_header.dart'
    show HidayahWebSection;
import '../../theme/app_theme.dart';
import '../../utils/text_direction.dart';
import '../ds/ca_button.dart' show CaButtonVariant;
import '../ds/ca_cards.dart' show CaStatusKind, CaAvatarRing;
import '../ds/ca_feedback.dart' show CaChatRole, CaSkeletonShape;
import '../ds/ca_icon.dart';
import '../ds/ca_rows.dart' show CaBannerKind;
import '../ds/canopy_content_motion.dart' show CaRollingCount;
import '../hedayah/hedayah_pattern.dart';
import '../language_switcher.dart';
import '../safe_image_provider.dart';
import 'lantern.dart';

/// The bridge from the older shared kits to Lantern and Arch (ADR-026).
///
/// Under the Lantern design the shared building blocks of the older screens
/// (`lib/core/widgets/ds/`, the website kit, the Lessons kit) hand over to
/// the pieces here and to the Lantern kit, at the top of their `build` and
/// only when `context.isLanternSkin` is true. The two older designs never
/// reach this file.

// ------------------------------------------------------------------- glyphs

/// The Lantern icon that stands for each icon of the shared set.
LGlyph lanternGlyphFor(CaGlyph glyph) => switch (glyph) {
      CaGlyph.translate => LGlyph.translate,
      CaGlyph.bell => LGlyph.bell,
      CaGlyph.search => LGlyph.search,
      CaGlyph.sliders => LGlyph.filter,
      CaGlyph.bookmark => LGlyph.bookmark,
      CaGlyph.user => LGlyph.person,
      CaGlyph.gear => LGlyph.settings,
      CaGlyph.menu => LGlyph.menu,
      CaGlyph.back => LGlyph.back,
      CaGlyph.close => LGlyph.close,
      CaGlyph.check => LGlyph.check,
      CaGlyph.verified => LGlyph.verified,
      CaGlyph.plus => LGlyph.plus,
      CaGlyph.edit => LGlyph.edit,
      CaGlyph.trash => LGlyph.trash,
      CaGlyph.refresh => LGlyph.refresh,
      CaGlyph.download => LGlyph.download,
      CaGlyph.share => LGlyph.share,
      CaGlyph.copy => LGlyph.copy,
      CaGlyph.external => LGlyph.external,
      CaGlyph.link => LGlyph.link,
      CaGlyph.key => LGlyph.key,
      CaGlyph.lock => LGlyph.lock,
      CaGlyph.shield => LGlyph.shield,
      CaGlyph.eye => LGlyph.eye,
      CaGlyph.eyeoff => LGlyph.eyeoff,
      CaGlyph.mic => LGlyph.mic,
      CaGlyph.micoff => LGlyph.micoff,
      CaGlyph.video => LGlyph.video,
      CaGlyph.videooff => LGlyph.videooff,
      CaGlyph.flip => LGlyph.flip,
      CaGlyph.volume => LGlyph.volume,
      CaGlyph.play => LGlyph.play,
      CaGlyph.pause => LGlyph.pause,
      CaGlyph.fullscreen => LGlyph.fullscreen,
      CaGlyph.heart => LGlyph.heart,
      CaGlyph.send => LGlyph.send,
      CaGlyph.chat => LGlyph.chat,
      CaGlyph.users => LGlyph.users,
      CaGlyph.cal => LGlyph.calendar,
      CaGlyph.clock => LGlyph.clock,
      CaGlyph.pin => LGlyph.pin,
      CaGlyph.map => LGlyph.map,
      CaGlyph.compass => LGlyph.compass,
      CaGlyph.list => LGlyph.list,
      CaGlyph.info => LGlyph.info,
      CaGlyph.alert => LGlyph.warn,
      CaGlyph.bars => LGlyph.signal,
      CaGlyph.wifi => LGlyph.wifi,
      CaGlyph.dots => LGlyph.more,
      CaGlyph.arrow => LGlyph.arrow,
      CaGlyph.logout => LGlyph.logout,
      CaGlyph.globe => LGlyph.globe,
      CaGlyph.scale => LGlyph.scale,
      CaGlyph.home => LGlyph.home,
    };

/// The Lantern icon that stands for each Lessons icon. The Lessons arrow
/// points back (start) and its chevron forward (end); both keep their sense.
LGlyph lanternGlyphForT(TGlyph glyph) => switch (glyph) {
      TGlyph.search => LGlyph.search,
      TGlyph.bell => LGlyph.bell,
      TGlyph.bookmark => LGlyph.bookmark,
      TGlyph.gear => LGlyph.settings,
      TGlyph.languages => LGlyph.translate,
      TGlyph.map => LGlyph.map,
      TGlyph.pin => LGlyph.pin,
      TGlyph.calendar => LGlyph.calendar,
      TGlyph.clock => LGlyph.clock,
      TGlyph.user => LGlyph.person,
      TGlyph.users => LGlyph.users,
      TGlyph.check => LGlyph.check,
      TGlyph.x => LGlyph.close,
      TGlyph.plus => LGlyph.plus,
      TGlyph.minus => LGlyph.minus,
      TGlyph.chevron => LGlyph.chevronend,
      TGlyph.chevronDown => LGlyph.chevron,
      TGlyph.arrow => LGlyph.back,
      TGlyph.arrowEnd => LGlyph.arrow,
      TGlyph.share => LGlyph.share,
      TGlyph.play => LGlyph.playfill,
      TGlyph.mic => LGlyph.mic,
      TGlyph.book => LGlyph.book,
      TGlyph.chat => LGlyph.chat,
      TGlyph.mosque => LGlyph.mosque,
      TGlyph.chart => LGlyph.chart,
      TGlyph.shield => LGlyph.shield,
      TGlyph.key => LGlyph.key,
      TGlyph.phone => LGlyph.phone,
      TGlyph.eye => LGlyph.eye,
      TGlyph.list => LGlyph.list,
      TGlyph.grid => LGlyph.grid,
      TGlyph.edit => LGlyph.edit,
      TGlyph.trash => LGlyph.trash,
      TGlyph.upload => LGlyph.upload,
      TGlyph.flag => LGlyph.flag,
      TGlyph.star => LGlyph.star,
      TGlyph.sun => LGlyph.sun,
      TGlyph.sunLow => LGlyph.sun,
      TGlyph.sunrise => LGlyph.sun,
      TGlyph.sunset => LGlyph.sun,
      TGlyph.moon => LGlyph.moon,
      TGlyph.globe => LGlyph.globe,
      TGlyph.sparkle => LGlyph.sparkles,
      TGlyph.info => LGlyph.info,
      TGlyph.alert => LGlyph.warn,
      TGlyph.history => LGlyph.history,
      TGlyph.link => LGlyph.link,
      TGlyph.copy => LGlyph.copy,
      TGlyph.send => LGlyph.send,
      TGlyph.nav => LGlyph.directions,
      TGlyph.filter => LGlyph.filter,
      TGlyph.logout => LGlyph.logout,
      TGlyph.refresh => LGlyph.refresh,
      TGlyph.inbox => LGlyph.mail,
      TGlyph.whatsapp => LGlyph.chat,
      TGlyph.lock => LGlyph.lock,
      TGlyph.repeat => LGlyph.refresh,
      TGlyph.radio => LGlyph.live,
      TGlyph.file => LGlyph.list,
      TGlyph.target => LGlyph.locate,
      TGlyph.car => LGlyph.directions,
      TGlyph.access => LGlyph.person,
      TGlyph.home => LGlyph.home,
      TGlyph.compass => LGlyph.compass,
    };

LGlyph? lanternGlyphOrNull(CaGlyph? glyph) =>
    glyph == null ? null : lanternGlyphFor(glyph);

LGlyph? lanternGlyphOrNullT(TGlyph? glyph) =>
    glyph == null ? null : lanternGlyphForT(glyph);

// ------------------------------------------------------------------ mapping

/// The shared kit's default icon colour (the brand gold-green) reads as
/// gold ink under Lantern; any colour a caller chose passes through.
Color lanternIconColor(BuildContext context, Color color) =>
    color == Canopy.brandGreen ? context.lt.goldInk : color;

LButtonKind lanternButtonKind(CaButtonVariant variant) => switch (variant) {
      CaButtonVariant.primary => LButtonKind.primary,
      CaButtonVariant.secondary => LButtonKind.secondary,
      CaButtonVariant.text => LButtonKind.ghost,
      CaButtonVariant.destructive => LButtonKind.danger,
    };

LButtonKind lanternTButtonKind(TBtn kind) => switch (kind) {
      TBtn.minted => LButtonKind.primary,
      TBtn.outline => LButtonKind.secondary,
      TBtn.ghost => LButtonKind.ghost,
      TBtn.ink => LButtonKind.dark,
      TBtn.danger => LButtonKind.danger,
      TBtn.night => LButtonKind.dark,
    };

LTone lanternTone(TTone tone) => switch (tone) {
      TTone.gold => LTone.gold,
      TTone.slate => LTone.neutral,
      TTone.success => LTone.ok,
      TTone.warning => LTone.warn,
      TTone.danger => LTone.live,
      TTone.info => LTone.audio,
      TTone.live => LTone.live,
      TTone.liveSoft => LTone.live,
    };

LTone lanternBannerTone(CaBannerKind kind) => switch (kind) {
      CaBannerKind.info => LTone.neutral,
      CaBannerKind.warning => LTone.warn,
      CaBannerKind.success => LTone.ok,
      CaBannerKind.error => LTone.live,
    };

LanternSection? lanternSectionFor(HidayahWebSection? section) => switch (
        section) {
      null => null,
      HidayahWebSection.discover => LanternSection.discover,
      HidayahWebSection.map => LanternSection.map,
      HidayahWebSection.lessons => LanternSection.lessons,
      HidayahWebSection.organizations => LanternSection.organizations,
      HidayahWebSection.channel => LanternSection.channel,
    };

LRing lanternRingFor(CaAvatarRing ring, {bool live = false}) => live
    ? LRing.live
    : switch (ring) {
        CaAvatarRing.none => LRing.none,
        CaAvatarRing.brand || CaAvatarRing.admin => LRing.admin,
        CaAvatarRing.moderator => LRing.mod,
      };

/// A picture from a URL, an asset or a file, as the shared kit resolves it.
ImageProvider? lanternImage(String? url) => resolveImageProviderOrNull(url);

/// Lantern's input decoration for the Lessons kit's text fields.
InputDecoration lanternInputDecoration(
    {String? hint, Widget? prefix, Widget? suffix}) {
  const t = LanternTokens.day;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Lantern.radiusField),
      borderSide: BorderSide(color: color, width: 1.5));
  return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: t.surface,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: border(t.line),
      enabledBorder: border(t.line),
      focusedBorder: border(LanternTokens.gold));
}

// ------------------------------------------------------------------ widgets

/// The state of a channel or a room in words: LIVE, AUDIO, offline,
/// scheduled or verified.
class LanternStatusChip extends StatelessWidget implements LanternSkinWidget {
  const LanternStatusChip({super.key, required this.kind, this.label});

  final CaStatusKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label ?? 'ds.status_${kind.name}'.tr();
    return switch (kind) {
      CaStatusKind.live => LBadge(text, kind: LBadgeKind.live),
      CaStatusKind.audio => LBadge(text, kind: LBadgeKind.audio),
      CaStatusKind.offline => LBadge(text, kind: LBadgeKind.off),
      CaStatusKind.pending =>
        LBadge(text, kind: LBadgeKind.soon, icon: LGlyph.clock),
      CaStatusKind.verified =>
        LTag(text, tone: LTone.gold, icon: LGlyph.verified, outlined: true),
    };
  }
}

/// The verified seal: gold with an ink check, on a ring of the card colour.
class LanternVerifiedSeal extends StatelessWidget implements LanternSkinWidget {
  const LanternVerifiedSeal({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'ds.status_verified'.tr(),
      child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: LanternTokens.gold,
              shape: BoxShape.circle,
              border: Border.all(color: context.lt.surface, width: 2)),
          child: LIcon(LGlyph.check,
              size: size * .55, color: LanternTokens.onGold)));
}

/// A card or banner picture; without one, an ink tile with the star.
class LanternCardImage extends StatelessWidget implements LanternSkinWidget {
  const LanternCardImage({super.key, this.url, this.loadingPlaceholder});

  final String? url;
  final Widget? loadingPlaceholder;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
        decoration: const BoxDecoration(gradient: Lantern.darkFill),
        child: Center(
            child: LStar(
                size: 22,
                color: LanternTokens.gold.withValues(alpha: .55))));
    final image = lanternImage(url);
    if (image == null) return fallback;
    return LayoutBuilder(
        builder: (context, constraints) => Image(
            image: constraints.maxWidth.isFinite
                ? downscaledImage(image,
                    width: (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .round())
                : image,
            fit: BoxFit.cover,
            frameBuilder: loadingPlaceholder == null
                ? null
                : (_, child, frame, synchronous) =>
                    synchronous || frame != null ? child : loadingPlaceholder!,
            errorBuilder: (_, __, ___) => fallback));
  }
}

/// A Lantern text field that keeps a form field's behaviour: validation,
/// read-only, a forced error, a tap callback. Same shape as [LField].
class LanternInput extends StatelessWidget implements LanternSkinWidget {
  const LanternInput(
      {super.key,
      this.label,
      this.semanticsLabel,
      this.hint,
      this.helper,
      this.error,
      this.controller,
      this.focusNode,
      this.icon,
      this.trailing,
      this.onChanged,
      this.onSubmitted,
      this.onTap,
      this.onTapOutside,
      this.validator,
      this.enabled = true,
      this.readOnly = false,
      this.obscure = false,
      this.autofocus = false,
      this.pill = false,
      this.keyboardType,
      this.textInputAction,
      this.maxLength,
      this.maxLines = 1,
      this.textDirection});

  /// Shown above the field; [semanticsLabel] names it for screen readers.
  final String? label, semanticsLabel, hint, helper, error;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final LGlyph? icon;
  final Widget? trailing;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final String? Function(String?)? validator;
  final bool enabled, readOnly, obscure, autofocus, pill;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final int maxLines;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final radius =
        BorderRadius.circular(pill ? Lantern.radiusPill : Lantern.radiusField);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: radius, borderSide: BorderSide(color: color, width: 1.5));
    Widget errorRow(BuildContext context, String message) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: LIcon(LGlyph.warn, size: 14, color: t.liveText)),
          const SizedBox(width: 6),
          Expanded(
              child: Text(message,
                  style: Lantern.textStyle(12.5,
                      color: t.liveText,
                      weight: FontWeight.w500,
                      height: 1.35))),
        ]));
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8, start: 2),
                child: Text(label!,
                    style: Lantern.textStyle(13,
                        color: t.muted, weight: FontWeight.w600, height: 1.3))),
          Semantics(
              label: semanticsLabel,
              child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: enabled,
                  readOnly: readOnly,
                  autofocus: autofocus,
                  obscureText: obscure,
                  keyboardType: keyboardType,
                  textInputAction: textInputAction,
                  maxLength: maxLength,
                  maxLines: obscure ? 1 : maxLines,
                  textDirection: textDirection,
                  onChanged: onChanged,
                  onFieldSubmitted: onSubmitted,
                  onTap: onTap,
                  onTapOutside: onTapOutside,
                  validator: validator,
                  forceErrorText: error,
                  errorBuilder: errorRow,
                  cursorColor: t.goldInk,
                  style: Lantern.textStyle(15,
                      color: enabled ? t.fg : t.muted, height: 1.35),
                  decoration: InputDecoration(
                      hintText: hint,
                      hintStyle:
                          Lantern.textStyle(15, color: t.faint, height: 1.35),
                      filled: true,
                      fillColor: enabled ? t.surface : t.sunk,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: pill ? 18 : 16, vertical: 14),
                      constraints:
                          const BoxConstraints(minHeight: Lantern.target),
                      prefixIcon: icon == null
                          ? null
                          : Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  start: 14, end: 8),
                              child: LIcon(icon!, size: 18, color: t.faint)),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 0, minHeight: 0),
                      suffixIcon: trailing,
                      border: border(t.line),
                      enabledBorder: border(t.line),
                      disabledBorder: border(t.line),
                      focusedBorder: border(LanternTokens.gold),
                      errorBorder: border(t.live),
                      focusedErrorBorder: border(t.live)))),
          if (helper != null)
            Padding(
                padding: const EdgeInsetsDirectional.only(top: 6, start: 2),
                child: Text(helper!,
                    style: Lantern.textStyle(12.5,
                        color: t.muted, weight: FontWeight.w500, height: 1.35))),
        ]);
  }
}

/// A channel card: the banner, the avatar and name, a line, and its state.
class LanternScholarCard extends StatelessWidget implements LanternSkinWidget {
  const LanternScholarCard(
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
      this.bannerHeight = 120,
      this.footer,
      this.statusKind,
      this.largeAvatar = false,
      this.bannerOverlay,
      this.bannerLoadingPlaceholder});

  final String name, subtitle;
  final String? avatarUrl, bannerUrl, statusLabel;
  final bool live, verified, org, largeAvatar;
  final VoidCallback? onTap;
  final double bannerHeight;
  final Widget? footer, bannerOverlay, bannerLoadingPlaceholder;
  final CaStatusKind? statusKind;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LCard(
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
                    LanternCardImage(
                        url: bannerUrl,
                        loadingPlaceholder: bannerLoadingPlaceholder),
                    if (bannerOverlay != null)
                      PositionedDirectional(
                          top: 10, end: 10, child: bannerOverlay!),
                  ])),
              Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 16),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          LAvatar(
                              name: name,
                              image: lanternImage(avatarUrl),
                              size: largeAvatar ? 56 : 42,
                              verified: verified,
                              org: org),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Lantern.displayStyle(16,
                                      color: t.fg,
                                      height:
                                          context.lanternArabic ? 1.45 : 1.25))),
                        ]),
                        const SizedBox(height: 6),
                        Text(subtitle,
                            style: Lantern.textStyle(13,
                                color: t.muted, height: 1.45)),
                        if (bannerOverlay == null) ...[
                          const SizedBox(height: 10),
                          LanternStatusChip(
                              kind: statusKind ??
                                  (live
                                      ? CaStatusKind.live
                                      : CaStatusKind.offline),
                              label: statusLabel),
                        ],
                        if (footer != null) ...[
                          const SizedBox(height: 10),
                          footer!
                        ],
                      ])),
            ]));
  }
}

/// A lecture or replay in a list: the picture, its length, title and line.
class LanternLectureTile extends StatelessWidget implements LanternSkinWidget {
  const LanternLectureTile(
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
    final t = context.lt;
    final image = Stack(fit: StackFit.expand, children: [
      LanternCardImage(url: imageUrl),
      if (duration != null)
        PositionedDirectional(
            bottom: 6,
            end: 6,
            child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                    color: const Color(0xCC0B1117),
                    borderRadius: BorderRadius.circular(Lantern.radiusPill)),
                child: Text(duration!,
                    style: Lantern.textStyle(11.5,
                            color: LanternTokens.white,
                            weight: FontWeight.w600,
                            height: 1.3)
                        .copyWith(fontFeatures: Lantern.tabular)))),
    ]);
    final thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(Lantern.radiusTile),
        child: stacked
            ? AspectRatio(aspectRatio: 16 / 9, child: image)
            : SizedBox(width: 120, height: 72, child: image));
    final details = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statusKind != null) ...[
            LanternStatusChip(kind: statusKind!),
            const SizedBox(height: 6),
          ],
          Text(title,
              style: Lantern.textStyle(15,
                  color: t.fg, weight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 4),
          Text(meta,
              style: Lantern.textStyle(13, color: t.muted, height: 1.4)),
        ]);
    return LCard(
        flat: true,
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: stacked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [thumbnail, const SizedBox(height: 12), details])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                thumbnail,
                const SizedBox(width: 12),
                Expanded(child: details),
              ]));
  }
}

/// The live feature on Discover: a night card with the picture, the state,
/// the title and one way in.
class LanternHeroCard extends StatelessWidget implements LanternSkinWidget {
  const LanternHeroCard(
      {super.key,
      required this.title,
      required this.presenter,
      required this.action,
      required this.height,
      this.imageUrl,
      this.onTap,
      this.audio = false,
      this.showAction = true,
      this.viewerLabel,
      this.viewerCount,
      this.viewerSuffix});

  final String title, presenter, action;
  final String? imageUrl, viewerLabel, viewerSuffix;
  final int? viewerCount;
  final double height;
  final bool audio, showAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = lanternImage(imageUrl);
    return LNightBand(
        radius: Lantern.radiusCard,
        child: Builder(builder: (context) {
          final t = context.lt;
          return Stack(children: [
            if (image != null)
              Positioned.fill(
                  child: Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox())),
            const Positioned.fill(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x330B1117), Color(0xE60B1117)])))),
            ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            LanternStatusChip(
                                kind: audio
                                    ? CaStatusKind.audio
                                    : CaStatusKind.live),
                            if (viewerSuffix != null)
                              Container(
                                  height: 26,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: const Color(0x8C0B1117),
                                      borderRadius: BorderRadius.circular(
                                          Lantern.radiusPill)),
                                  child: CaRollingCount(
                                      value: viewerCount,
                                      suffix: viewerSuffix!,
                                      style: Lantern.textStyle(11.5,
                                          color: LanternTokens.white,
                                          weight: FontWeight.w700,
                                          height: 1.2)))
                            else if (viewerLabel != null)
                              LBadge(viewerLabel!, kind: LBadgeKind.glass),
                          ]),
                          const SizedBox(height: 22),
                          Text(title,
                              style: Lantern.displayStyle(22,
                                  color: t.fg,
                                  height: context.lanternArabic ? 1.45 : 1.25)),
                          const SizedBox(height: 6),
                          Text(presenter,
                              style: Lantern.textStyle(14,
                                  color: t.muted, height: 1.45)),
                          const SizedBox(height: 16),
                          if (showAction)
                            LButton(
                                label: action,
                                icon: audio ? LGlyph.mic : LGlyph.play,
                                onPressed: onTap),
                        ]))),
          ]);
        }));
  }
}

/// One chat message in the Lantern shape: the sender's avatar with its role
/// ring, and a bubble cut to two lines with a control to open the rest.
class LanternChatBubble extends StatefulWidget implements LanternSkinWidget {
  const LanternChatBubble(
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
      this.onAvatarTap});

  final String name, message, time;
  final String? avatarUrl;
  final bool isOwn, pending, handRaised, dark, showIdentity;
  final CaChatRole role;
  final VoidCallback? onAvatarTap;

  @override
  State<LanternChatBubble> createState() => _LanternChatBubbleState();
}

class _LanternChatBubbleState extends State<LanternChatBubble> {
  bool _open = false;
  static const _lines = 2;

  @override
  Widget build(BuildContext context) {
    final t = widget.dark ? LanternTokens.dark : context.lt;
    final body = Lantern.textStyle(14, color: t.fg, height: 1.45);
    final showName = widget.role == CaChatRole.viewer && !widget.isOwn;
    final ambient = Directionality.of(context);
    final direction = firstStrongTextDirection(widget.message) ?? ambient;
    final isolateName = widget.dark || direction != ambient;
    final span = TextSpan(children: [
      if (showName)
        TextSpan(
            text:
                '${isolateName ? isolateDirection(widget.name) : widget.name}  ',
            style: Lantern.textStyle(13.5,
                color: t.goldInk, weight: FontWeight.w700, height: 1.45)),
      TextSpan(text: widget.message),
    ], style: body);
    const avatarSize = 32.0;
    final avatar = widget.showIdentity
        ? GestureDetector(
            onTap: widget.onAvatarTap,
            child: Semantics(
                button: widget.onAvatarTap != null,
                label: widget.name,
                child: LAvatar(
                    name: widget.name,
                    image: lanternImage(widget.avatarUrl),
                    size: avatarSize - 8,
                    ring: switch (widget.role) {
                      CaChatRole.broadcaster => LRing.live,
                      CaChatRole.admin => LRing.admin,
                      CaChatRole.moderator => LRing.mod,
                      CaChatRole.viewer => LRing.none,
                    })))
        : const SizedBox.square(dimension: avatarSize);
    final bubble = LayoutBuilder(builder: (context, constraints) {
      const handWidth = 20.0;
      const padding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      final painter = TextPainter(
          text: span,
          textDirection: direction,
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
                  ? t.sunk
                  : widget.dark
                      ? const Color(0x14FFFFFF)
                      : t.surface,
              borderRadius: BorderRadius.circular(Lantern.radiusRow),
              border: Border.all(
                  color: widget.isOwn
                      ? LanternTokens.gold.withValues(alpha: .5)
                      : widget.dark
                          ? const Color(0x1FFFFFFF)
                          : t.line2)),
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
                            Padding(
                                padding:
                                    const EdgeInsetsDirectional.only(end: 4),
                                child:
                                    LIcon(LGlyph.hand, size: 16, color: t.warn)),
                          Expanded(
                              child: Text.rich(span,
                                  textDirection: direction,
                                  maxLines: _open ? null : _lines,
                                  overflow:
                                      _open ? null : TextOverflow.ellipsis)),
                        ]),
                    if (long)
                      Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: LPressable(
                              onTap: () => setState(() => _open = !_open),
                              label: (_open
                                      ? 'profile.show_less'
                                      : 'profile.show_more')
                                  .tr(),
                              excludeChildSemantics: true,
                              builder: (context, _) => Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: AnimatedRotation(
                                      turns: _open ? .5 : 0,
                                      duration: Lantern.calm(context)
                                          ? Lantern.none
                                          : Lantern.state,
                                      child: LIcon(LGlyph.chevron,
                                          size: 18, color: t.muted))))),
                  ])));
    });
    return Opacity(
        opacity: widget.pending ? .6 : 1,
        child: Semantics(
            container: true,
            label: '${widget.name}, ${widget.time}',
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                textDirection: widget.isOwn
                    ? (ambient == TextDirection.rtl
                        ? TextDirection.ltr
                        : TextDirection.rtl)
                    : null,
                children: [
                  avatar,
                  const SizedBox(width: 8),
                  Flexible(child: bubble),
                ])));
  }
}

/// The shared toast as a Lantern night pill: an icon disc, the title and the
/// message, one action, and the close button.
class LanternToastCard extends StatelessWidget implements LanternSkinWidget {
  const LanternToastCard(
      {super.key,
      required this.title,
      required this.message,
      required this.icon,
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

  @override
  Widget build(BuildContext context) => LanternSurface(
      night: true,
      child: Builder(builder: (context) {
        final t = context.lt;
        return Semantics(
            liveRegion: true,
            container: true,
            child: Dismissible(
                key: ValueKey(this),
                direction: onDismissed == null
                    ? DismissDirection.none
                    : DismissDirection.up,
                movementDuration:
                    Lantern.calm(context) ? Lantern.none : Lantern.state,
                resizeDuration: null,
                onDismissed: (_) => onDismissed?.call(),
                child: Material(
                    color: t.surface,
                    elevation: 8,
                    shadowColor: const Color(0x99000000),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(Lantern.radiusCard),
                        side: BorderSide(color: t.line)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                        onTap: onTap,
                        child: Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                12, 10, 6, 10),
                            child: Row(children: [
                              Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: error
                                          ? Lantern.dangerFill
                                          : Lantern.goldFill),
                                  child: LIcon(lanternGlyphFor(icon),
                                      size: 18,
                                      color: error
                                          ? LanternTokens.white
                                          : LanternTokens.onGold)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(title,
                                        style: Lantern.textStyle(14.5,
                                            color: t.fg,
                                            weight: FontWeight.w600,
                                            height: 1.35)),
                                    Text(message,
                                        style: Lantern.textStyle(13,
                                            color: t.muted, height: 1.4)),
                                    if (actionLabel != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6),
                                          child: LButton(
                                              label: actionLabel!,
                                              kind: LButtonKind.ghost,
                                              size: LButtonSize.small,
                                              onPressed:
                                                  onActionPressed ?? onTap)),
                                  ])),
                              if (onDismissed != null)
                                LIconButton(
                                    icon: LGlyph.close,
                                    label: dismissLabel ?? 'ds.dismiss'.tr(),
                                    onPressed: onDismissed),
                            ]))))));
      }));
}

/// The shared skeleton shapes drawn with Lantern's moving light.
class LanternSkeleton extends StatelessWidget implements LanternSkinWidget {
  const LanternSkeleton(
      {super.key,
      required this.shape,
      this.lines = 3,
      this.width,
      this.height,
      this.label});

  final CaSkeletonShape shape;
  final int lines;
  final double? width, height;
  final String? label;

  @override
  Widget build(BuildContext context) => Semantics(
      label: label ?? 'ds.loading'.tr(),
      child: ExcludeSemantics(
          child: switch (shape) {
        CaSkeletonShape.line => LSkeleton(width: width, height: height ?? 14),
        CaSkeletonShape.avatar => LSkeleton(
            width: width ?? Lantern.target,
            height: height ?? Lantern.target,
            radius: Lantern.radiusPill),
        CaSkeletonShape.card => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LSkeleton(
                    width: width,
                    height: height ?? 120,
                    radius: Lantern.radiusCard),
                const SizedBox(height: 12),
                for (var i = 0; i < lines; i++)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: FractionallySizedBox(
                          widthFactor: i.isEven ? .8 : .55,
                          child: const LSkeleton())),
              ]),
        CaSkeletonShape.row => Row(children: [
            const LSkeleton(
                width: Lantern.target,
                height: Lantern.target,
                radius: Lantern.radiusPill),
            const SizedBox(width: 12),
            Expanded(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < lines; i++)
                const Padding(
                    padding: EdgeInsets.only(bottom: 8), child: LSkeleton()),
            ])),
          ]),
      }));
}

/// A number with its label on a flat Lantern card.
class LanternKpiTile extends StatelessWidget implements LanternSkinWidget {
  const LanternKpiTile(
      {super.key, required this.label, this.value, this.unit, this.reason});

  final String label;
  final String? value, unit, reason;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LCard(
        flat: true,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value ?? '—',
                  style: value == null
                      ? Lantern.textStyle(15, color: t.faint)
                      : Lantern.displayStyle(26, color: t.goldInk, height: 1.2)
                          .copyWith(fontFeatures: Lantern.tabular)),
              if (value == null)
                Text(reason ?? 'ds.not_measured'.tr(),
                    style: Lantern.textStyle(12.5, color: t.muted)),
              if (unit != null && value != null)
                Text(unit!, style: Lantern.textStyle(12.5, color: t.muted)),
              Text(label,
                  style: Lantern.textStyle(13,
                      color: t.muted, weight: FontWeight.w600)),
            ]));
  }
}

/// Step bars: gold up to the current step, then the hairline.
class LanternStepBars extends StatelessWidget implements LanternSkinWidget {
  const LanternStepBars(
      {super.key, required this.count, required this.index, required this.statement});

  final int count, index;
  final String statement;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Semantics(
        value: statement,
        child: ExcludeSemantics(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                for (var i = 0; i < count; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                      child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                              color: i <= index ? null : t.line,
                              gradient: i <= index ? Lantern.goldFill : null,
                              borderRadius:
                                  BorderRadius.circular(Lantern.radiusPill)))),
                ],
              ]),
              const SizedBox(height: 8),
              Text(statement,
                  style: Lantern.textStyle(12.5,
                      color: t.muted, weight: FontWeight.w500)),
            ])));
  }
}

/// Quality choices as small Lantern cards; the chosen one has the gold ring.
class LanternQualityPresets<T> extends StatelessWidget
    implements LanternSkinWidget {
  const LanternQualityPresets(
      {super.key, required this.options, required this.value, this.onChanged});

  final List<({T value, String label, String detail})> options;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < options.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
            child: Semantics(
                selected: options[i].value == value,
                child: LPressable(
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(options[i].value),
                    label: '${options[i].label}, ${options[i].detail}',
                    selected: options[i].value == value,
                    radius: Lantern.radiusTile,
                    pressScale: .98,
                    excludeChildSemantics: true,
                    builder: (context, s) {
                      final on = options[i].value == value;
                      return AnimatedContainer(
                          duration: Lantern.calm(context)
                              ? Lantern.none
                              : Lantern.state,
                          constraints:
                              const BoxConstraints(minHeight: Lantern.target),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                          decoration: BoxDecoration(
                              color: on || s.hovered ? t.sunk : t.surface,
                              borderRadius:
                                  BorderRadius.circular(Lantern.radiusTile),
                              border: Border.all(
                                  color: on ? LanternTokens.gold : t.line,
                                  width: on ? 1.5 : 1)),
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(options[i].label,
                                    textAlign: TextAlign.center,
                                    style: Lantern.textStyle(14,
                                        color: on ? t.goldInk : t.fg,
                                        weight: FontWeight.w600,
                                        height: 1.3)),
                                Text(options[i].detail,
                                    textAlign: TextAlign.center,
                                    style: Lantern.textStyle(12,
                                        color: t.muted, height: 1.3)),
                              ]));
                    }))),
      ],
    ]));
  }
}

/// Segmented tabs over equal slots; [dark] puts them on night colours.
/// A disabled slot takes no tap.
class LanternSegmentedTabs extends StatelessWidget
    implements LanternSkinWidget {
  const LanternSegmentedTabs(
      {super.key,
      required this.labels,
      required this.index,
      required this.onChanged,
      this.dark = false,
      this.disabledIndices = const {}});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final bool dark;
  final Set<int> disabledIndices;

  @override
  Widget build(BuildContext context) {
    final tabs = LSegmented<int>(
        expand: true,
        segments: [
          for (var i = 0; i < labels.length; i++)
            (value: i, label: labels[i], icon: null),
        ],
        value: index,
        onChanged: (i) {
          if (!disabledIndices.contains(i)) onChanged(i);
        });
    return dark ? LanternSurface(night: true, child: tabs) : tabs;
  }
}

/// The shared sheet's frame in the Lantern shape: 28 px corners, the raised
/// ground, a display title, the language control and the close button.
class LanternSheetFrame extends StatelessWidget implements LanternSkinWidget {
  const LanternSheetFrame(
      {super.key,
      required this.title,
      required this.body,
      this.actions = const [],
      this.headerStatus,
      this.onClose,
      this.scrollBody = true,
      this.handle = true,
      this.language,
      this.shortHeight = 400});

  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? headerStatus, language;
  final VoidCallback? onClose;
  final bool scrollBody, handle;

  /// Below this height the header scrolls with the body.
  final double shortHeight;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return ClipRRect(
        borderRadius: BorderRadius.circular(Lantern.radiusDialog),
        child: Material(
            color: t.raised,
            child: LayoutBuilder(builder: (context, bounds) {
              final header = Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 10, 6),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (handle) ...[
                      Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: t.line,
                              borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 10),
                    ],
                    Row(children: [
                      Expanded(
                          child: Semantics(
                              header: true,
                              child: Text(title,
                                  style: Lantern.displayStyle(18,
                                      color: t.fg,
                                      height: context.lanternArabic
                                          ? 1.45
                                          : 1.25)))),
                      const SizedBox(width: 8),
                      if (language != null) language!,
                      if (onClose != null)
                        LIconButton(
                            icon: LGlyph.close,
                            label: MaterialLocalizations.of(context)
                                .closeButtonTooltip,
                            onPressed: onClose),
                    ]),
                    if (headerStatus != null) ...[
                      const SizedBox(height: 8),
                      Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: headerStatus!),
                    ],
                  ]));
              final actionRow = Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(spacing: 10, runSpacing: 10, children: actions));
              if (bounds.maxHeight >= shortHeight || !scrollBody) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  header,
                  Container(height: 1, color: t.line2),
                  Flexible(
                      child: scrollBody
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(20), child: body)
                          : Padding(
                              padding: const EdgeInsets.all(20), child: body)),
                  if (actions.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        child: actionRow),
                ]);
              }
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                    flex: 2,
                    child: SingleChildScrollView(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                      header,
                      Padding(padding: const EdgeInsets.all(20), child: body),
                    ]))),
                if (actions.isNotEmpty)
                  Flexible(
                      child: SingleChildScrollView(
                          child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: actionRow))),
              ]);
            })));
  }
}

/// The shared dialog's frame in the Lantern shape.
class LanternDialogFrame extends StatelessWidget implements LanternSkinWidget {
  const LanternDialogFrame(
      {super.key,
      required this.title,
      required this.body,
      this.titleWidget,
      this.actions = const [],
      this.onClose,
      this.maxWidth = 440,
      this.shortHeight = 400,
      this.reflowTextScale = 1.6});

  final String title;
  final Widget? titleWidget;
  final Widget body;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final double maxWidth, shortHeight, reflowTextScale;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Dialog(
        backgroundColor: t.raised,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        insetAnimationDuration:
            Lantern.calm(context) ? Lantern.none : Lantern.state,
        insetAnimationCurve: Lantern.ease,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Lantern.radiusDialog),
            side: BorderSide(color: t.line)),
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
            child: LayoutBuilder(builder: (context, bounds) {
              final header = Row(children: [
                Expanded(
                    child: DefaultTextStyle.merge(
                        style: Lantern.displayStyle(19,
                            color: t.fg,
                            height: context.lanternArabic ? 1.45 : 1.25),
                        child: Semantics(
                            header: true,
                            child: titleWidget ??
                                Text(title,
                                    style: Lantern.displayStyle(19,
                                        color: t.fg,
                                        height: context.lanternArabic
                                            ? 1.45
                                            : 1.25))))),
                if (onClose != null)
                  LIconButton(
                      icon: LGlyph.close,
                      label:
                          MaterialLocalizations.of(context).closeButtonTooltip,
                      onPressed: onClose),
              ]);
              final actionRow = Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(spacing: 10, runSpacing: 10, children: actions));
              final inner = Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: body);
              if (bounds.maxHeight >= shortHeight &&
                  MediaQuery.textScalerOf(context).scale(1) <=
                      reflowTextScale) {
                return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      header,
                      const SizedBox(height: 12),
                      Flexible(child: SingleChildScrollView(child: inner)),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: actionRow),
                      ],
                    ]);
              }
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(
                    flex: 2,
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          header,
                          const SizedBox(height: 12),
                          inner,
                        ]))),
                if (actions.isNotEmpty)
                  Flexible(child: SingleChildScrollView(child: actionRow)),
              ]);
            })));
  }
}

/// The language control: a chip with the other language's name, or a globe
/// button when [compact].
class LanternLanguageControl extends StatelessWidget
    implements LanternSkinWidget {
  const LanternLanguageControl(
      {super.key, this.compact = false, this.glass = false});

  final bool compact, glass;

  @override
  Widget build(BuildContext context) {
    final other =
        context.locale.languageCode == 'ar' ? 'English' : 'العربية';
    if (compact || glass) {
      return LIconButton(
          icon: LGlyph.globe,
          label: other,
          glass: glass,
          onPressed: () => LanguageSwitcher.toggle(context));
    }
    return Center(
        widthFactor: 1,
        heightFactor: 1,
        child: LChip(
            label: other,
            icon: LGlyph.globe,
            dense: true,
            onTap: () => LanguageSwitcher.toggle(context)));
  }
}

/// The side rail of the medium window, in Lantern colours.
class LanternRail extends StatelessWidget implements LanternSkinWidget {
  const LanternRail(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.role,
      required this.destinations,
      required this.width,
      this.expanded = true,
      this.accountLinks});

  final int index;
  final ValueChanged<int> onChanged;
  final String role;
  final List<(CaGlyph, String)> destinations;
  final double width;
  final bool expanded;
  final Widget? accountLinks;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return SizedBox(
        width: width,
        child: DecoratedBox(
            decoration: BoxDecoration(
                color: t.surface,
                border: BorderDirectional(end: BorderSide(color: t.line))),
            child: SafeArea(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: [
                      const SizedBox(height: 16),
                      LLogo(height: expanded ? 32 : 26),
                      const SizedBox(height: 22),
                      for (var i = 0; i < destinations.length; i++)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: LPressable(
                                onTap: () => onChanged(i),
                                label: destinations[i].$2.tr(),
                                selected: index == i,
                                excludeChildSemantics: true,
                                builder: (context, s) {
                                  final on = index == i;
                                  final fg = on ? LanternTokens.onGold : t.fg;
                                  return Container(
                                      constraints: const BoxConstraints(
                                          minHeight: Lantern.target),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                          gradient:
                                              on ? Lantern.goldFill : null,
                                          color: !on && s.hovered
                                              ? t.sunk
                                              : null,
                                          borderRadius: BorderRadius.circular(
                                              Lantern.radiusPill)),
                                      child: expanded
                                          ? Row(children: [
                                              LIcon(
                                                  lanternGlyphFor(
                                                      destinations[i].$1),
                                                  size: 20,
                                                  color: fg),
                                              const SizedBox(width: 10),
                                              Flexible(
                                                  child: Text(
                                                      destinations[i].$2.tr(),
                                                      style: Lantern.textStyle(
                                                          14,
                                                          color: fg,
                                                          weight:
                                                              FontWeight.w600,
                                                          height: 1.3))),
                                            ])
                                          : Column(children: [
                                              LIcon(
                                                  lanternGlyphFor(
                                                      destinations[i].$1),
                                                  size: 20,
                                                  color: fg),
                                              const SizedBox(height: 4),
                                              Text(destinations[i].$2.tr(),
                                                  textAlign: TextAlign.center,
                                                  style: Lantern.textStyle(11.5,
                                                      color: fg,
                                                      weight: FontWeight.w600,
                                                      height: 1.2)),
                                            ]));
                                })),
                      if (accountLinks != null) accountLinks!,
                      const SizedBox(height: 16),
                      LTag(role, tone: LTone.gold),
                    ])))));
  }
}

/// A Lessons icon button that keeps its count.
class LanternCountIconButton extends StatelessWidget
    implements LanternSkinWidget {
  const LanternCountIconButton(
      {super.key,
      required this.icon,
      required this.label,
      this.onPressed,
      this.badge,
      this.color});

  final LGlyph icon;
  final String label;
  final VoidCallback? onPressed;
  final int? badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Stack(clipBehavior: Clip.none, children: [
      LIconButton(
          icon: icon,
          label: (badge ?? 0) > 0 ? '$label, $badge' : label,
          onPressed: onPressed,
          color: color),
      if ((badge ?? 0) > 0)
        PositionedDirectional(
            top: 2,
            end: 0,
            child: IgnorePointer(
                child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: t.live,
                        borderRadius: BorderRadius.circular(Lantern.radiusPill),
                        border: Border.all(color: t.bg, width: 1.5)),
                    child: Text('$badge',
                        style: Lantern.textStyle(10.5,
                                color: LanternTokens.white,
                                weight: FontWeight.w700,
                                height: 1.1)
                            .copyWith(fontFeatures: Lantern.tabular))))),
    ]);
  }
}

/// Underlined tabs with the gold underline (the Lessons tab bar, the
/// website's tabs).
class LanternUnderlineTab extends StatelessWidget implements LanternSkinWidget {
  const LanternUnderlineTab(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.count,
      this.dark = false,
      this.height = 48,
      this.padding = const EdgeInsets.symmetric(horizontal: 12)});

  final String label;
  final bool selected, dark;
  final VoidCallback onTap;
  final int? count;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = dark ? LanternTokens.dark : context.lt;
    return LPressable(
        onTap: onTap,
        label: count == null ? label : '$label, $count',
        selected: selected,
        radius: 10,
        pressScale: 1,
        excludeChildSemantics: true,
        builder: (context, s) => SizedBox(
            height: height,
            child: Stack(children: [
              Padding(
                  padding: padding,
                  child: Center(
                      widthFactor: 1,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(label,
                            style: Lantern.textStyle(14.5,
                                color: selected || s.hovered ? t.fg : t.muted,
                                weight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                height: 1.3)),
                        if (count != null) ...[
                          const SizedBox(width: 7),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                  color: t.sunk,
                                  borderRadius: BorderRadius.circular(
                                      Lantern.radiusPill)),
                              child: Text('$count',
                                  style: Lantern.textStyle(11.5,
                                          color: t.goldInk,
                                          weight: FontWeight.w700,
                                          height: 1.3)
                                      .copyWith(
                                          fontFeatures: Lantern.tabular))),
                        ],
                      ]))),
              PositionedDirectional(
                  start: 8,
                  end: 8,
                  bottom: 0,
                  child: LanternGiltUnderline(visible: selected)),
            ])));
  }
}

/// The 3 px gold underline under the chosen tab.
class LanternGiltUnderline extends StatelessWidget
    implements LanternSkinWidget {
  const LanternGiltUnderline({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
      child: Container(
          height: 3,
          decoration: const BoxDecoration(
              gradient: Lantern.goldFill,
              borderRadius: BorderRadius.vertical(top: Radius.circular(3)))));
}

/// The Lessons tab bar under Lantern.
class LanternTabBar<T> extends StatelessWidget implements LanternSkinWidget {
  const LanternTabBar(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});

  final List<TSegOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.lt.line))),
      child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final o in options)
              LanternUnderlineTab(
                  label: o.label,
                  selected: o.value == value,
                  count: (o.count ?? 0) > 0 ? o.count : null,
                  height: 46,
                  padding: const EdgeInsetsDirectional.only(end: 22),
                  onTap: () => onChanged(o.value)),
          ])));
}

/// A schedule date: the month in gold over the day, on ink.
class LanternDateBlock extends StatelessWidget implements LanternSkinWidget {
  const LanternDateBlock(
      {super.key, required this.month, required this.day, this.width = 56});

  final String month, day;
  final double width;

  @override
  Widget build(BuildContext context) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
          color: LanternTokens.nightGround,
          borderRadius: BorderRadius.circular(Lantern.radiusTile),
          border: Border.all(color: LanternTokens.gold.withValues(alpha: .35))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(month,
            style: Lantern.textStyle(11,
                color: LanternTokens.goldHi,
                weight: FontWeight.w700,
                height: 1.3)),
        Text(day,
            style: Lantern.displayStyle(22,
                    color: LanternTokens.onNight, height: 1.2)
                .copyWith(fontFeatures: Lantern.tabular)),
      ]));
}

/// A small gold eyebrow above a heading: a gilt dash or an icon, then text.
class LanternEyebrow extends StatelessWidget implements LanternSkinWidget {
  const LanternEyebrow(this.text, {super.key, this.onNight = false, this.icon});

  final String text;
  final bool onNight;
  final LGlyph? icon;

  @override
  Widget build(BuildContext context) {
    final c = onNight ? LanternTokens.goldHi : context.lt.goldInk;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        LIcon(icon!, size: 14, color: c),
        const SizedBox(width: 6),
      ] else ...[
        const SizedBox(
            width: 26,
            height: 2,
            child: DecoratedBox(
                decoration: BoxDecoration(gradient: Lantern.progressFill))),
        const SizedBox(width: 8),
      ],
      Flexible(
          child: Text(text,
              style: Lantern.textStyle(13,
                  color: c, weight: FontWeight.w600, height: 1.4))),
    ]);
  }
}

/// A Lessons section heading under Lantern: eyebrow, the arch and title,
/// its count and line, and an action at the end.
class LanternSectionHeading extends StatelessWidget
    implements LanternSkinWidget {
  const LanternSectionHeading(this.title,
      {super.key, this.count, this.action, this.sub, this.eyebrow});

  final String title;
  final int? count;
  final Widget? action;
  final String? sub, eyebrow;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              if (eyebrow != null) ...[
                LanternEyebrow(eyebrow!),
                const SizedBox(height: 6),
              ],
              LSectionHead(title,
                  count: count == null ? null : '$count', subtitle: sub),
            ])),
        if (action != null) ...[const SizedBox(width: 12), action!],
      ]));
}

/// A page heading: eyebrow, the display title, a line, and actions.
class LanternPageHeading extends StatelessWidget implements LanternSkinWidget {
  const LanternPageHeading(
      {super.key,
      this.eyebrow,
      required this.title,
      this.subtitle,
      this.actions = const []});

  final String? eyebrow, subtitle;
  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (eyebrow != null) ...[
            LanternEyebrow(eyebrow!),
            const SizedBox(height: 8),
          ],
          Semantics(
              header: true,
              child: Text(title,
                  style: Lantern.displayStyle(wide ? 34 : 26,
                      color: t.fg,
                      height: context.lanternArabic ? 1.45 : 1.2))),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(subtitle!,
                    style: Lantern.textStyle(15, color: t.muted))),
        ]);
    if (actions.isEmpty) return text;
    return Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720), child: text),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ]);
  }
}

/// A banner that holds any widget: the Lessons call-out under Lantern.
class LanternCallout extends StatelessWidget implements LanternSkinWidget {
  const LanternCallout(
      {super.key,
      required this.tone,
      required this.icon,
      required this.child,
      this.action});

  final LTone tone;
  final LGlyph icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final (bg, fg) = switch (tone) {
      LTone.neutral || LTone.gold => (t.sunk, t.fg),
      LTone.warn => (t.warnSoft, t.warn),
      LTone.live => (t.liveSoft, t.liveText),
      LTone.ok => (t.okSoft, t.ok),
      LTone.audio => (t.audioSoft, t.audio),
      LTone.mod => (t.modSoft, t.mod),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Lantern.radiusField),
            border: tone == LTone.neutral || tone == LTone.gold
                ? Border.all(color: t.line)
                : null),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 2),
              child: LIcon(icon, size: 18, color: fg)),
          const SizedBox(width: 10),
          Expanded(
              child: DefaultTextStyle(
                  style: Lantern.textStyle(14, color: fg, height: 1.55),
                  child: child)),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ]));
  }
}

/// The lesson artwork under Lantern: an ink tile with the lattice, a gold
/// glow, a seal with the icon and a word.
class LanternCover extends StatelessWidget implements LanternSkinWidget {
  const LanternCover(
      {super.key,
      required this.seed,
      required this.glyph,
      this.word,
      this.tags = const [],
      this.aspect = 16 / 9,
      this.compact = false});

  final String seed;
  final LGlyph glyph;
  final String? word;
  final List<Widget> tags;
  final double aspect;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final h = seed.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) & 0x7fffffff);
    final gx = -.7 + (h % 70) / 50, gy = -.8 + ((h >> 3) % 50) / 50;
    return AspectRatio(
        aspectRatio: aspect,
        child: LNightBand(
            glow: Alignment(gx, gy),
            latticeStep: compact ? 30 : 40,
            child: Stack(fit: StackFit.expand, children: [
              PositionedDirectional(
                  end: compact ? 12 : 18,
                  top: 0,
                  bottom: 0,
                  child: Center(
                      child: Container(
                          width: compact ? 46 : 64,
                          height: compact ? 46 : 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0x800B1117),
                              border: Border.all(
                                  color: LanternTokens.goldHi
                                      .withValues(alpha: .6),
                                  width: 1.5)),
                          child: LIcon(glyph,
                              size: compact ? 18 : 26,
                              color: LanternTokens.goldHi)))),
              if (word != null)
                PositionedDirectional(
                    start: 16,
                    bottom: 10,
                    end: compact ? 70 : 100,
                    child: Text(word!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Lantern.displayStyle(compact ? 18 : 26,
                            color: LanternTokens.goldHi.withValues(alpha: .35),
                            height: 1.3))),
              if (tags.isNotEmpty)
                PositionedDirectional(
                    top: 12,
                    start: 12,
                    child: Wrap(spacing: 6, children: tags)),
            ])));
  }
}

/// Number tiles: the number in gold ink over its label.
class LanternStatTiles extends StatelessWidget implements LanternSkinWidget {
  const LanternStatTiles(this.items, {super.key, this.big = false});

  final List<(String, String)> items;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? items.length : 2;
      final w = (c.maxWidth - (cols - 1) * 10) / cols;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final (v, l) in items)
          SizedBox(
              width: w,
              child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(Lantern.radiusTile),
                      border: Border.all(color: t.line)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v,
                            style: Lantern.displayStyle(big ? 30 : 24,
                                    color: t.goldInk, height: 1.25)
                                .copyWith(fontFeatures: Lantern.tabular)),
                        Text(l,
                            style: Lantern.textStyle(13,
                                color: t.muted, height: 1.4)),
                      ]))),
      ]);
    });
  }
}

/// A choice row for modals: a radio mark (or an icon), the title and a line.
class LanternOptionRow extends StatelessWidget implements LanternSkinWidget {
  const LanternOptionRow(
      {super.key,
      required this.title,
      this.subtitle,
      required this.selected,
      required this.onTap,
      this.leading});

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final LGlyph? leading;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LPressable(
            onTap: onTap,
            label: subtitle == null ? title : '$title, $subtitle',
            selected: selected,
            radius: Lantern.radiusRow,
            pressScale: .985,
            excludeChildSemantics: true,
            builder: (context, s) => AnimatedContainer(
                duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: selected || s.hovered ? t.sunk : t.surface,
                    borderRadius: BorderRadius.circular(Lantern.radiusRow),
                    border: Border.all(
                        color: selected ? LanternTokens.gold : t.line,
                        width: selected ? 1.5 : 1)),
                child: Row(children: [
                  if (leading != null) ...[
                    LIcon(leading!, size: 18, color: t.goldInk),
                    const SizedBox(width: 12),
                  ] else ...[
                    Container(
                        width: 20,
                        height: 20,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: selected ? LanternTokens.gold : t.muted,
                                width: 2)),
                        child: selected
                            ? const DecoratedBox(
                                decoration: BoxDecoration(
                                    gradient: Lantern.goldFill,
                                    shape: BoxShape.circle))
                            : null),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(title,
                            style: Lantern.textStyle(14.5,
                                color: t.fg,
                                weight: FontWeight.w600,
                                height: 1.4)),
                        if (subtitle != null)
                          Text(subtitle!,
                              style: Lantern.textStyle(12.5,
                                  color: t.muted, height: 1.4)),
                      ])),
                  if (selected && leading != null)
                    LIcon(LGlyph.check, size: 18, color: t.goldInk),
                ]))));
  }
}

/// Numbered steps under Lantern: done ones show a check, the current one is
/// the gold coin.
class LanternStepDots extends StatelessWidget implements LanternSkinWidget {
  const LanternStepDots(
      {super.key, required this.labels, required this.current, this.onTap});

  final List<String> labels;
  final int current;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Row(children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
            child: LPressable(
                onTap: onTap == null || i >= current ? null : () => onTap!(i),
                label: labels[i],
                selected: i == current,
                radius: 12,
                pressScale: .97,
                excludeChildSemantics: true,
                builder: (context, _) => Column(children: [
                      Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: i == current
                                  ? Lantern.goldFill
                                  : i < current
                                      ? Lantern.darkFill
                                      : null,
                              color: i > current ? t.sunk : null,
                              border: i > current
                                  ? Border.all(color: t.line)
                                  : null),
                          child: i < current
                              ? const LIcon(LGlyph.check,
                                  size: 14, color: LanternTokens.goldHi)
                              : Text('${i + 1}',
                                  style: Lantern.textStyle(13,
                                          color: i == current
                                              ? LanternTokens.onGold
                                              : t.muted,
                                          weight: FontWeight.w700,
                                          height: 1.2)
                                      .copyWith(
                                          fontFeatures: Lantern.tabular))),
                      const SizedBox(height: 4),
                      Text(labels[i],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(12,
                              color: i == current ? t.fg : t.muted,
                              weight: FontWeight.w600,
                              height: 1.3)),
                    ]))),
    ]);
  }
}

/// The Lantern lattice for painters that fill their own box (the website
/// kit's lattice sits inside a `Positioned.fill` its caller gives it).
class LanternLatticePaint extends StatelessWidget implements LanternSkinWidget {
  const LanternLatticePaint({super.key, this.opacity = .1});

  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: HedayahPattern(
          color: const Color(0xFFD2A95F).withValues(alpha: opacity),
          step: 44,
          weight: .9,
          fadeFrom: AlignmentDirectional.topEnd
              .resolve(Directionality.of(context))));
}

/// The Lessons modal under Lantern: a sheet on phones, a dialog on wide
/// screens, both in the Lantern shape, with the same title, line, body and
/// footer, and the same result.
Future<T?> showLanternTModal<T>(BuildContext context,
    {required String title,
    String? subtitle,
    required WidgetBuilder body,
    List<Widget> Function(BuildContext)? footer,
    bool wide = false,
    required bool dialog}) {
  final direction = Directionality.of(context);
  Widget frame(BuildContext ctx, {required bool sheet}) {
    final t = ctx.lt;
    return Directionality(
        textDirection: direction,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sheet)
                Center(
                    child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: t.line,
                            borderRadius: BorderRadius.circular(2)))),
              Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 10, 6),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Semantics(
                                  header: true,
                                  child: Text(title,
                                      style: Lantern.displayStyle(18,
                                          color: t.fg,
                                          height: ctx.lanternArabic
                                              ? 1.45
                                              : 1.25))),
                              if (subtitle != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text(subtitle,
                                        style: Lantern.textStyle(13,
                                            color: t.muted, height: 1.4))),
                            ])),
                        LIconButton(
                            icon: LGlyph.close,
                            label: 'lessons.close'.tr(),
                            onPressed: () => Navigator.of(ctx).pop()),
                      ])),
              Flexible(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: body(ctx))),
              if (footer != null)
                Container(
                    padding: EdgeInsets.fromLTRB(20, 12, 20,
                        sheet ? 12 + MediaQuery.paddingOf(ctx).bottom : 16),
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: t.line))),
                    child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: footer(ctx))),
            ]));
  }

  final t = context.lt;
  if (dialog) {
    return showDialog<T>(
        context: context,
        barrierColor: t.scrim,
        builder: (ctx) => Dialog(
            backgroundColor: ctx.lt.raised,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Lantern.radiusDialog),
                side: BorderSide(color: ctx.lt.line)),
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: wide ? 860 : 560,
                    maxHeight: MediaQuery.sizeOf(ctx).height * .9),
                child: frame(ctx, sheet: false))));
  }
  return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: t.raised,
      barrierColor: t.scrim,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(Lantern.radiusDialog)),
          side: BorderSide(color: t.line)),
      builder: (ctx) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * .88),
              child: frame(ctx, sheet: true))));
}
