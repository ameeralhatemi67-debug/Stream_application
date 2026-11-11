import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../lessons/domain/lessons_rules.dart';
import '../../../lessons/presentation/lessons_in_app.dart' show MapMosque;
import '../map_cluster_layout.dart';

/// The pins of the Lantern map. Each is laid out inside the one box the
/// grouping measures ([kMapPinFootprint]): the pin on top, its label under
/// it. Because markers are grouped until no two boxes touch, neither pins
/// nor labels can cover each other.
///
/// Three shapes, as in the older map: an arch for a mosque, a ring for a
/// broadcaster, a disc for several places. Red means live in the app, green
/// means on now at the mosque; nothing else uses them.

/// The label under a pin: a small pill that never grows past the box.
class _PinLabel extends StatelessWidget {
  const _PinLabel(this.text, {this.tone = LTone.neutral});

  final String text;
  final LTone tone;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final (bg, fg) = switch (tone) {
      LTone.live => (t.live, LanternTokens.white),
      LTone.ok => (t.ok, LanternTokens.white),
      LTone.audio => (t.audio, LanternTokens.white),
      LTone.warn => (t.warnSoft, t.warn),
      _ => (t.surface, t.fg),
    };
    return Container(
        constraints: BoxConstraints(maxWidth: kMapPinFootprint.width - 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            border: tone == LTone.neutral ? Border.all(color: t.line) : null,
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))
            ]),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Lantern.textStyle(10.5,
                    color: fg, weight: FontWeight.w700, height: 1.3)
                .copyWith(fontFeatures: Lantern.tabular)));
  }
}

/// A pin and its label inside the footprint box, with one spoken name.
class _PinBox extends StatelessWidget {
  const _PinBox(
      {required this.pin,
      required this.semantics,
      required this.onTap,
      this.label,
      this.onDoubleTap});

  final Widget pin;
  final Widget? label;
  final String semantics;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
      // The box is fixed, so the label keeps one size.
      maxScaleFactor: 1,
      child: Semantics(
          button: true,
          label: semantics,
          excludeSemantics: true,
          onTap: onTap,
          child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              onDoubleTap: onDoubleTap,
              child: SizedBox(
                  width: kMapPinFootprint.width,
                  height: kMapPinFootprint.height,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        pin,
                        if (label != null) ...[
                          const SizedBox(height: 3),
                          label!
                        ],
                      ])))));
}

/// A mosque: a gold arch with the number of lessons this week, crowned by
/// the star. With nothing coming up it is a small hollow arch. Its label
/// says what is happening (on now, live, starts in, or the weekday).
class LanternMosquePin extends StatelessWidget implements LanternSkinWidget {
  const LanternMosquePin(this.mosque,
      {super.key, required this.onTap, this.selected = false});

  final MapMosque mosque;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final m = mosque;
    final quiet = m.status == MosqueStatus.quiet;
    final width = quiet ? 26.0 : 36.0, height = quiet ? 30.0 : 42.0;
    final tone = m.live
        ? LTone.live
        : m.status == MosqueStatus.now
            ? LTone.ok
            : LTone.neutral;
    final arch = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
              width: width,
              height: height,
              alignment: const Alignment(0, .35),
              decoration: ShapeDecoration(
                  gradient: quiet
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [LanternTokens.goldHi, Color(0xFFC1923B)]),
                  color: quiet ? t.surface : null,
                  shadows: [
                    if (selected) BoxShadow(color: t.glow, spreadRadius: 4),
                    const BoxShadow(
                        color: Color(0x66000000),
                        blurRadius: 8,
                        spreadRadius: -3,
                        offset: Offset(0, 5)),
                  ],
                  shape: LArchBorder(
                      bottom: quiet ? 5 : 7,
                      side: BorderSide(
                          color: selected
                              ? LanternTokens.ink
                              : quiet
                                  ? LanternTokens.gold
                                  : const Color(0xFF805B1B),
                          width: selected ? 3 : 2))),
              child: quiet
                  ? null
                  : Text('${m.count}',
                      style: Lantern.displayStyle(15,
                              color: const Color(0xFF4B320E),
                              weight: FontWeight.w700,
                              height: 1.1)
                          .copyWith(fontFeatures: Lantern.tabular))),
          if (!quiet && m.status != MosqueStatus.now)
            const Positioned(
                top: -9, child: LStar(size: 9, color: Color(0xFF805B1B))),
        ]);
    // "Wednesday · 5:15 PM" does not fit the box: a later day shows the day
    // alone. The spoken name and the place card keep the time.
    final label =
        m.status == MosqueStatus.week ? m.chip.split(' · ').first : m.chip;
    return _PinBox(
        semantics:
            '${'lantern.map.mosque_pin'.tr(args: [m.label, '${m.count}'])}${m.chip.isEmpty ? '' : ', ${m.chip}'}',
        onTap: onTap,
        pin: Padding(padding: const EdgeInsets.only(top: 8), child: arch),
        label: m.chip.isEmpty ? null : _PinLabel(label, tone: tone));
  }
}

/// A broadcaster: the avatar in the ring of its state (a rounded square for
/// an organization). Its label says LIVE or AUDIO in words, or when the next
/// broadcast starts.
class LanternStreamerPin extends StatelessWidget implements LanternSkinWidget {
  const LanternStreamerPin(
      {super.key,
      required this.name,
      required this.onTap,
      this.avatarUrl,
      this.live = false,
      this.audio = false,
      this.org = false,
      this.mine = false,
      this.selected = false,
      this.saved = false,
      this.soon,
      this.onDoubleTap});

  final String name;
  final String? avatarUrl, soon;
  final bool live, audio, org, mine, selected;

  /// A place saved earlier and shown without a connection: never live.
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final label = audio
        ? _PinLabel('web.badge_audio'.tr(), tone: LTone.audio)
        : live
            ? _PinLabel('web.badge_live'.tr(), tone: LTone.live)
            : soon != null
                ? _PinLabel(soon!, tone: LTone.warn)
                : null;
    final state = audio
        ? 'web.badge_audio'.tr()
        : live
            ? 'web.badge_live'.tr()
            : saved
                ? 'lantern.map.saved_venue'.tr()
                : soon ?? 'feed.offline_badge'.tr();
    return _PinBox(
        semantics: '$name, $state',
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        pin: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
                color: selected || mine ? LanternTokens.gold : t.surface,
                borderRadius: BorderRadius.circular(org ? 16 : 40),
                boxShadow: [
                  if (selected) BoxShadow(color: t.glow, spreadRadius: 4),
                  const BoxShadow(
                      color: Color(0x59000000),
                      blurRadius: 8,
                      spreadRadius: -2,
                      offset: Offset(0, 4)),
                ]),
            child: Opacity(
                opacity: saved ? .7 : 1,
                child: LAvatar(
                    name: name,
                    image: resolveImageProviderOrNull(avatarUrl),
                    size: live || audio ? 34 : 38,
                    org: org,
                    ring: audio
                        ? LRing.audio
                        : live
                            ? LRing.live
                            : LRing.none))),
        label: label);
  }
}

/// Several places in one spot: an ink disc with the count. Its ring shows
/// the mix (gold for mosques, grey for broadcasters); small badges count
/// what is live in the app (red) and on now at a mosque (green).
class LanternBubblePin extends StatelessWidget implements LanternSkinWidget {
  const LanternBubblePin(
      {super.key,
      required this.count,
      required this.mosques,
      required this.live,
      required this.onSite,
      required this.semantics,
      required this.onTap});

  final int count, mosques, live, onSite;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget badge(int n, Color color) => Container(
        constraints: const BoxConstraints(minWidth: 18),
        height: 18,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            border: Border.all(color: LanternTokens.white, width: 1.5)),
        child: Text('$n',
            style: Lantern.textStyle(10,
                    color: LanternTokens.white,
                    weight: FontWeight.w700,
                    height: 1.1)
                .copyWith(fontFeatures: Lantern.tabular)));
    return _PinBox(
        semantics: semantics,
        onTap: onTap,
        pin: SizedBox.square(
            dimension: 56,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(
                  child: CustomPaint(
                      painter: _BubblePainter(
                          share: count == 0 ? 0 : mosques / count))),
              Center(
                  child: Text('$count',
                      style: Lantern.displayStyle(17,
                              color: LanternTokens.white,
                              weight: FontWeight.w700,
                              height: 1.1)
                          .copyWith(fontFeatures: Lantern.tabular))),
              if (live > 0)
                PositionedDirectional(
                    top: -4, start: -4, child: badge(live, t.live)),
              if (onSite > 0)
                PositionedDirectional(
                    top: -4, end: -4, child: badge(onSite, t.ok)),
            ])));
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.share});

  /// The part of the group that is mosques, 0 to 1.
  final double share;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas
      ..drawCircle(
          center.translate(0, 3),
          radius - 1,
          Paint()
            ..color = const Color(0x55000000)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5))
      ..drawCircle(center, radius - 4, Paint()..color = LanternTokens.ink);
    final ring = Rect.fromCircle(center: center, radius: radius - 2.5);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawArc(ring, 0, 2 * math.pi, false,
        stroke..color = LanternTokens.slate);
    if (share > 0) {
      canvas.drawArc(ring, -math.pi / 2, 2 * math.pi * share.clamp(0, 1),
          false, stroke..color = LanternTokens.gold);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) => old.share != share;
}

/// What the markers mean, for the map's legend button.
class LanternMapLegend extends StatelessWidget implements LanternSkinWidget {
  const LanternMapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget row(Widget mark, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 44, child: Center(child: mark)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: Lantern.textStyle(14, color: t.fg))),
        ]));
    Widget arch({bool quiet = false}) => Container(
        width: quiet ? 18 : 24,
        height: quiet ? 21 : 28,
        decoration: ShapeDecoration(
            color: quiet ? t.surface : LanternTokens.gold,
            shape: LArchBorder(
                bottom: 4,
                side: BorderSide(
                    color:
                        quiet ? LanternTokens.gold : const Color(0xFF805B1B),
                    width: 2))));
    Widget dot(Color color) => Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
    return Column(mainAxisSize: MainAxisSize.min, children: [
      row(arch(), 'lantern.map.legend_mosque'.tr()),
      row(arch(quiet: true), 'lantern.map.legend_quiet'.tr()),
      row(const LAvatar(name: 'A', size: 26), 'lantern.map.legend_channel'.tr()),
      row(dot(t.live), 'lantern.map.legend_live'.tr()),
      row(dot(t.ok), 'lantern.map.legend_now'.tr()),
      row(
          const SizedBox.square(
              dimension: 30,
              child: CustomPaint(painter: _BubblePainter(share: .6))),
          'lantern.map.legend_group'.tr()),
    ]);
  }
}
