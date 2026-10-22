import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds/ca_icon.dart';

/// The Hidayah Gold *website* layouts (owner review 2026-10-19) replace the
/// app-on-a-laptop layout only when the gold palette is on and the window is
/// wide enough for a top navigation bar. Phones and the green palette keep
/// the existing layouts untouched.
abstract final class HidayahWeb {
  static const minWidth = 1024.0;
  static const maxContent = 1200.0;
  static const gutter = 40.0;
  static const headerHeight = 72.0;

  /// The navigation bar is wider than the 1200 px content column so the brand
  /// and the account tools sit nearer the window edges.
  static const headerMax = 1640.0;
  static const headerGutter = 32.0;
  static const radius = 16.0;
  static const hover = Duration(milliseconds: 250);
}

extension HidayahWebX on BuildContext {
  bool get usesHidayahWeb =>
      MediaQuery.sizeOf(this).width >= HidayahWeb.minWidth;
}

abstract final class HidayahText {
  static TextStyle display(double size,
          {Color color = HidayahGold.s900, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
          fontFamily: HidayahType.display,
          fontFamilyFallback: const [HidayahType.text],
          fontSize: size,
          fontWeight: weight,
          height: 1.2,
          color: color);

  static TextStyle body(double size,
          {Color color = HidayahGold.s700,
          FontWeight weight = FontWeight.w400,
          double height = 1.6}) =>
      TextStyle(
          fontFamily: HidayahType.text,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color);

  /// Small caps label; Arabic gets no tracking or upper-casing.
  static TextStyle eyebrow(BuildContext context, Color color) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return TextStyle(
        fontFamily: HidayahType.text,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        letterSpacing: ar ? 0 : 1.6,
        color: color);
  }

  static String upper(BuildContext context, String text) =>
      Localizations.localeOf(context).languageCode == 'ar'
          ? text
          : text.toUpperCase();
}

/// Centres page content in the 1200 px column with the site gutter.
class HidayahWebWidth extends StatelessWidget {
  const HidayahWebWidth({super.key, required this.child, this.wide = false});
  final Widget child;

  /// The navigation bar's wider column (Discover, owner request
  /// 2026-10-22): its edges line up with the header's brand and tools, so
  /// four channel cards a row use the window instead of side margins.
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final max = wide ? HidayahWeb.headerMax : HidayahWeb.maxContent;
    final gutter = wide ? HidayahWeb.headerGutter : HidayahWeb.gutter;
    return Center(
        child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max + gutter * 2),
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: child)));
  }
}

/// The logo's eight-point star, repeated as a gilt lattice that fades away
/// from the top end corner.
class HidayahLattice extends StatelessWidget {
  const HidayahLattice(
      {super.key, this.color = HidayahGold.g300, this.opacity = .13});
  final Color color;
  final double opacity;
  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: RepaintBoundary(
          child: CustomPaint(
              size: Size.infinite,
              painter: _LatticePainter(color.withValues(alpha: opacity),
                  Directionality.of(context)))));
}

class _LatticePainter extends CustomPainter {
  _LatticePainter(this.color, this.direction);
  final Color color;
  final TextDirection direction;
  static const _tile = 64.0;
  static final Path _star = Path()
    ..addRect(const Rect.fromLTWH(19, 19, 26, 26))
    ..addPolygon(const [
      Offset(32, 13.6),
      Offset(50.4, 32),
      Offset(32, 50.4),
      Offset(13.6, 32)
    ], true)
    ..addOval(Rect.fromCircle(center: const Offset(32, 32), radius: 5.5))
    ..moveTo(32, 0)
    ..lineTo(32, 13.6)
    ..moveTo(32, 50.4)
    ..lineTo(32, 64)
    ..moveTo(0, 32)
    ..lineTo(13.6, 32)
    ..moveTo(50.4, 32)
    ..lineTo(64, 32)
    ..moveTo(0, 0)
    ..lineTo(19, 19)
    ..moveTo(64, 0)
    ..lineTo(45, 19)
    ..moveTo(0, 64)
    ..lineTo(19, 45)
    ..moveTo(64, 64)
    ..lineTo(45, 45);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = color;
    for (var y = 0.0; y < size.height; y += _tile) {
      for (var x = 0.0; x < size.width; x += _tile) {
        canvas.drawPath(_star.shift(Offset(x, y)), stroke);
      }
    }
    final centre =
        Offset(direction == TextDirection.rtl ? 0 : size.width, 0);
    canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = const RadialGradient(
                  colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
                  stops: [0, .78])
              .createShader(Rect.fromCircle(
                  center: centre, radius: size.longestSide * 1.05)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LatticePainter old) =>
      old.color != color || old.direction != direction;
}

/// Night slate band with the warm corner glow and the gilt lattice.
class HidayahNightBand extends StatelessWidget {
  const HidayahNightBand(
      {super.key, required this.child, this.lattice = true, this.radius});
  final Widget child;
  final bool lattice;
  final BorderRadius? radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: DecoratedBox(
          decoration: const BoxDecoration(gradient: HidayahGradients.night),
          child: Stack(children: [
            const Positioned.fill(
                child: DecoratedBox(
                    decoration:
                        BoxDecoration(gradient: HidayahGradients.nightGlow))),
            if (lattice) const Positioned.fill(child: HidayahLattice()),
            child,
          ])));
}

enum HidayahButtonKind { gold, ghost, onDark }

/// Website buttons: 12 px corners rather than the app's pills.
class HidayahButton extends StatefulWidget {
  const HidayahButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.icon,
      this.kind = HidayahButtonKind.gold,
      this.compact = false,
      this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final CaGlyph? icon;
  final HidayahButtonKind kind;
  final bool compact, expand;
  @override
  State<HidayahButton> createState() => _HidayahButtonState();
}

class _HidayahButtonState extends State<HidayahButton> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final gold = widget.kind == HidayahButtonKind.gold;
    final dark = widget.kind == HidayahButtonKind.onDark;
    final foreground = dark ? HidayahGold.g200 : HidayahGold.s900;
    final radius = BorderRadius.circular(widget.compact ? 10 : 12);
    // A tight slot (narrow card, enlarged text) scales the label down rather
    // than clipping or overflowing it.
    final content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (widget.icon != null) ...[
            CaIcon(widget.icon!,
                color: foreground, size: widget.compact ? 16 : 18),
            const SizedBox(width: AppTheme.spaceSm),
          ],
          Text(widget.label,
              maxLines: 1,
              style: HidayahText.body(widget.compact ? 13 : 14.5,
                  color: foreground, weight: FontWeight.w700, height: 1.2)),
        ]));
    return Semantics(
        button: true,
        enabled: enabled,
        child: MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            onEnter: (_) => setState(() => _hover = true),
            onExit: (_) => setState(() => _hover = false),
            child: Opacity(
                opacity: enabled ? 1 : .5,
                child: AnimatedContainer(
                    duration: CanopyMotion.press,
                    height: widget.compact ? 36 : 44,
                    decoration: BoxDecoration(
                        gradient: gold ? HidayahGradients.minted : null,
                        color: gold
                            ? null
                            : dark
                                ? (_hover
                                    ? const Color(0x14E2C389)
                                    : const Color(0x0AFFFFFF))
                                : HidayahGold.card,
                        borderRadius: radius,
                        border: gold
                            ? null
                            : Border.all(
                                color: dark
                                    ? HidayahGold.g300
                                        .withValues(alpha: _hover ? .8 : .45)
                                    : (_hover
                                        ? HidayahGold.s600
                                        : HidayahGold.s300)),
                        boxShadow: gold ? HidayahShadow.minted : null),
                    child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                            borderRadius: radius,
                            onTap: widget.onPressed,
                            child: Stack(children: [
                              if (gold)
                                Positioned(
                                    top: 1,
                                    left: 10,
                                    right: 10,
                                    height: 1,
                                    child: ColoredBox(
                                        color: HidayahGold.shine
                                            .withValues(alpha: .9))),
                              Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: widget.compact ? 12 : 18),
                                  child: Center(
                                      widthFactor: widget.expand ? null : 1,
                                      child: content)),
                            ])))))));
  }
}

/// A white website card with a quiet lift on hover.
class HidayahCard extends StatefulWidget {
  const HidayahCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = EdgeInsets.zero,
      this.highlight = false});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool highlight;
  @override
  State<HidayahCard> createState() => _HidayahCardState();
}

class _HidayahCardState extends State<HidayahCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final lift = _hover && widget.onTap != null && !CanopyMotion.reduced(context);
    final radius = BorderRadius.circular(HidayahWeb.radius);
    return MouseRegion(
        cursor:
            widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
            duration: HidayahWeb.hover,
            curve: CanopyMotion.easeOut,
            transform: Matrix4.translationValues(0, lift ? -3 : 0, 0),
            decoration: BoxDecoration(
                color: HidayahGold.card,
                borderRadius: radius,
                border: Border.all(
                    color: widget.highlight || lift
                        ? HidayahGold.g300
                        : HidayahGold.hairline),
                boxShadow: HidayahShadow.card),
            child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                    borderRadius: radius,
                    onTap: widget.onTap,
                    child: ClipRRect(
                        borderRadius: radius,
                        child: Padding(
                            padding: widget.padding, child: widget.child))))));
  }
}

/// Section title with an optional count and an end-aligned link.
class HidayahSectionHeader extends StatelessWidget {
  const HidayahSectionHeader(
      {super.key, required this.title, this.count, this.action, this.onAction});
  final String title;
  final int? count;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Flexible(
            child: Text(title,
                style: HidayahText.display(26),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
        if (count != null) ...[
          const SizedBox(width: AppTheme.spaceMd),
          Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('$count',
                  style: HidayahText.body(13, color: HidayahGold.s600))),
        ],
        const Spacer(),
        if (action != null)
          TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: HidayahGold.g700),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!,
                    style: HidayahText.body(14,
                        color: HidayahGold.g700, weight: FontWeight.w700)),
                const SizedBox(width: AppTheme.spaceXs),
                const HidayahForwardIcon(color: HidayahGold.g700, size: 16),
              ])),
      ]));
}

/// LIVE (crimson) or AUDIO (ink with gold) badge for media corners.
class HidayahLiveBadge extends StatelessWidget {
  const HidayahLiveBadge(
      {super.key, required this.label, this.audio = false});
  final String label;
  final bool audio;
  @override
  Widget build(BuildContext context) => Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
          gradient: audio ? null : HidayahGradients.live,
          color: audio ? HidayahGold.s900 : null,
          borderRadius: BorderRadius.circular(7),
          border: audio
              ? Border.all(color: HidayahGold.g300.withValues(alpha: .4))
              : null),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (audio)
          const CaIcon(CaGlyph.mic, color: HidayahGold.g200, size: 13)
        else
          Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: HidayahGold.card, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: HidayahText.body(11.5,
                color: audio ? HidayahGold.g200 : HidayahGold.card,
                weight: FontWeight.w700,
                height: 1)),
      ]));
}

/// Translucent chip for counts over imagery.
class HidayahGlassBadge extends StatelessWidget {
  const HidayahGlassBadge({super.key, required this.label, this.icon});
  final String label;
  final CaGlyph? icon;
  @override
  Widget build(BuildContext context) => Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
          color: HidayahGold.s950.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          CaIcon(icon!, color: HidayahGold.g100, size: 13),
          const SizedBox(width: 6),
        ],
        Text(label,
            style: HidayahText.body(12,
                color: HidayahGold.g100, weight: FontWeight.w500, height: 1)),
      ]));
}

class HidayahTag extends StatelessWidget {
  const HidayahTag(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
          color: HidayahGold.g100, borderRadius: BorderRadius.circular(999)),
      child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(label,
              style: HidayahText.body(11.5,
                  color: HidayahGold.g800, weight: FontWeight.w600))));
}

/// The 3 px gilt underline under the active tab or nav link.
class HidayahGiltUnderline extends StatelessWidget {
  const HidayahGiltUnderline({super.key, required this.visible});
  final bool visible;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: CanopyMotion.reduced(context)
          ? CanopyMotion.none
          : CanopyMotion.chipIn,
      child: Container(
          height: 3,
          decoration: const BoxDecoration(
              gradient: HidayahGradients.gilded,
              borderRadius: BorderRadius.vertical(top: Radius.circular(3)))));
}

/// One underline tab of a website tab bar.
class HidayahTab extends StatelessWidget {
  const HidayahTab(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap,
      this.count,
      this.dark = false,
      this.height = 52});
  final String label;
  final bool selected, dark;
  final VoidCallback onTap;
  final int? count;
  final double height;
  @override
  Widget build(BuildContext context) {
    final color = dark
        ? (selected ? HidayahGold.g50 : HidayahGold.s300)
        : (selected ? HidayahGold.s900 : HidayahGold.s700);
    return Semantics(
        button: true,
        selected: selected,
        child: InkWell(
            onTap: onTap,
            child: SizedBox(
                height: height,
                child: Stack(children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Center(
                          widthFactor: 1,
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(label,
                                style: HidayahText.body(14.5,
                                    color: color,
                                    weight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    height: 1.2)),
                            if (count != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 1),
                                  decoration: BoxDecoration(
                                      color: dark
                                          ? HidayahGold.s800
                                          : HidayahGold.g100,
                                      borderRadius:
                                          BorderRadius.circular(999)),
                                  child: Text('$count',
                                      style: HidayahText.body(11.5,
                                          color: dark
                                              ? HidayahGold.g200
                                              : HidayahGold.g800,
                                          weight: FontWeight.w700,
                                          height: 1.3))),
                            ],
                          ]))),
                  Positioned(
                      left: 8,
                      right: 8,
                      bottom: 0,
                      child: HidayahGiltUnderline(visible: selected)),
                ]))));
  }
}

/// Date block for schedule rows: month in gold on ink, day in Kufi.
class HidayahDateBlock extends StatelessWidget {
  const HidayahDateBlock(
      {super.key, required this.month, required this.day, this.width = 56});
  final String month, day;
  final double width;
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
          color: HidayahGold.s900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HidayahGold.g300.withValues(alpha: .25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(HidayahText.upper(context, month),
            style: HidayahText.body(11,
                color: HidayahGold.g300, weight: FontWeight.w700, height: 1.3)),
        Text(day,
            style: HidayahText.display(24, color: HidayahGold.g50)),
      ]));
}

/// A chevron pointing in the reading direction ("See all ›" / "‹ عرض الكل").
class HidayahForwardIcon extends StatelessWidget {
  const HidayahForwardIcon(
      {super.key, this.color = HidayahGold.s600, this.size = 16});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Transform.flip(
      flipX: true, child: CaIcon(CaGlyph.back, color: color, size: size));
}

/// Icon + text meta row (place, time, category).
class HidayahMeta extends StatelessWidget {
  const HidayahMeta(
      {super.key,
      required this.icon,
      required this.text,
      this.color = HidayahGold.s600});
  final CaGlyph icon;
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        CaIcon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HidayahText.body(12.5, color: color, height: 1.4))),
      ]);
}
