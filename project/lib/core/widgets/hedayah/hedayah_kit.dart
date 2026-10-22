import 'package:flutter/material.dart';

import '../../theme/canopy_tokens.dart';
import '../../theme/hedayah_skin.dart';
import '../ds/ca_focus_ring.dart';
import 'hedayah_pattern.dart';
import 'hedayah_rosette.dart';

export 'hedayah_pattern.dart';
export 'hedayah_rosette.dart';

/// A flat gold band carrying the white lattice, the way the website opens and
/// closes its pages. Text on it is [HedayahSkin.ink].
class HedayahGoldBand extends StatelessWidget {
  const HedayahGoldBand(
      {super.key,
      required this.child,
      this.radius = BorderRadius.zero,
      this.step = 30,
      this.weight = .8,
      this.fadeFrom});

  final Widget child;
  final BorderRadius radius;
  final double step, weight;
  final Alignment? fadeFrom;

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
          color: HedayahSkin.gold,
          child: Stack(children: [
            Positioned.fill(
                child: HedayahPattern(
                    step: step, weight: weight, fadeFrom: fadeFrom)),
            child,
          ])));
}

/// The association's wordmark, هداية, in gold or reversed to white.
class HedayahWordmark extends StatelessWidget {
  const HedayahWordmark({super.key, this.height = 40, this.reversed = false});

  static const asset = 'assets/hedayah/wordmark.png';

  final double height;
  final bool reversed;

  @override
  Widget build(BuildContext context) => Image.asset(asset,
      height: height,
      fit: BoxFit.contain,
      color: reversed ? HedayahSkin.paper : null,
      colorBlendMode: reversed ? BlendMode.srcIn : null,
      semanticLabel: 'هداية',
      // On a cold start the image arrives after the first frame; it fades in
      // under the rosette rather than popping.
      frameBuilder: (context, child, frame, synchronous) => synchronous
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: CanopyMotion.reduced(context)
                  ? CanopyMotion.none
                  : CanopyMotion.contentIn,
              curve: CanopyMotion.easeOut,
              child: SizedBox(height: height, child: child)));
}

/// Rosette over wordmark: the primary lockup on white (slate and gold), or
/// all white on gold, never the primary version on gold.
class HedayahLockup extends StatelessWidget {
  const HedayahLockup(
      {super.key,
      this.size = 96,
      this.reversed = false,
      this.draw = false,
      this.drawFor = const Duration(milliseconds: 1100)});

  final double size;
  final bool reversed, draw;

  /// How long the rosette takes to draw on; the splash moves on at 1.35 s.
  final Duration drawFor;

  @override
  Widget build(BuildContext context) {
    final colour = reversed ? HedayahSkin.paper : HedayahSkin.slate;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      draw
          ? HedayahRosetteDraw(size: size, color: colour, duration: drawFor)
          : HedayahRosette(size: size, color: colour),
      SizedBox(height: size * .14),
      HedayahWordmark(height: size * .36, reversed: reversed),
    ]);
  }
}

/// The 60 x 4 gold bar that sits over every centred section title.
class HedayahRule extends StatelessWidget {
  const HedayahRule(
      {super.key, this.width = 60, this.color = HedayahSkin.gold});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: 4,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)));
}

/// A section title with the gold rule above it.
class HedayahSectionTitle extends StatelessWidget {
  const HedayahSectionTitle(this.title,
      {super.key, this.subtitle, this.centred = true, this.size = 22});

  final String title;
  final String? subtitle;
  final bool centred;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment:
              centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const HedayahRule(),
            const SizedBox(height: 12),
            Text(title,
                textAlign: centred ? TextAlign.center : TextAlign.start,
                style: HedayahSkin.displayStyle(size, weight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: centred ? TextAlign.center : TextAlign.start,
                  style: HedayahSkin.textStyle(14, color: HedayahSkin.muted)),
            ],
          ]);
}

/// A light kicker between two hairlines, set above a bold title.
class HedayahEyebrow extends StatelessWidget {
  const HedayahEyebrow(this.text,
      {super.key, this.color = HedayahSkin.bodyGrey});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final line =
        Container(width: 40, height: 1, color: color.withValues(alpha: .35));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      line,
      const SizedBox(width: 12),
      Flexible(
          child: Text(text,
              textAlign: TextAlign.center,
              style: HedayahSkin.displayStyle(14,
                  weight: FontWeight.w300, color: color, height: 1.5))),
      const SizedBox(width: 12),
      line,
    ]);
  }
}

enum HedayahButtonKind {
  /// Gold fill, ink label: the main action.
  gold,

  /// Bronze fill, white label (the website's Donate, made readable).
  bronze,

  /// Ink outline on white or on gold.
  outline,

  /// White fill, ink label: the main action on a gold band.
  paper,

  /// The website header's gold tint, bronze label.
  tint,
}

/// The website's one shape: a 25 px pill.
class HedayahButton extends StatelessWidget {
  const HedayahButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.kind = HedayahButtonKind.gold,
      this.leading,
      this.loading = false,
      this.expand = true,
      this.compact = false});

  final String label;
  final VoidCallback? onPressed;
  final HedayahButtonKind kind;
  final Widget? leading;
  final bool loading, expand;

  /// The website header's size: 40 px high.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final (fill, ink, border) = switch (kind) {
      HedayahButtonKind.gold => (HedayahSkin.gold, HedayahSkin.ink, null),
      HedayahButtonKind.bronze => (HedayahSkin.bronze, HedayahSkin.paper, null),
      HedayahButtonKind.outline => (
          Colors.transparent,
          HedayahSkin.ink,
          HedayahSkin.ink
        ),
      HedayahButtonKind.paper => (HedayahSkin.paper, HedayahSkin.ink, null),
      HedayahButtonKind.tint => (
          HedayahSkin.goldTint,
          HedayahSkin.bronze,
          null
        ),
    };
    final foreground = enabled ? ink : HedayahSkin.bodyGrey;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HedayahSkin.radiusPill),
        side: border == null
            ? BorderSide.none
            : BorderSide(
                color: enabled ? border : HedayahSkin.line, width: 1.5));
    final content = loading
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: ink))
        : Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                if (leading != null) ...[
                  IconTheme.merge(
                      data: IconThemeData(color: foreground, size: 20),
                      child: leading!),
                  const SizedBox(width: 10),
                ],
                Flexible(
                    child: Text(label,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: HedayahSkin.displayStyle(compact ? 14.5 : 16,
                            weight: FontWeight.w500,
                            color: foreground,
                            height: 1.3))),
              ]);
    return Semantics(
        button: true,
        enabled: enabled,
        child: CaFocusRing(
            radius: HedayahSkin.radiusPill,
            child: Material(
                color: enabled || kind == HedayahButtonKind.outline
                    ? fill
                    : HedayahSkin.disabled,
                shape: shape,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                    onTap: enabled ? onPressed : null,
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            minHeight: compact ? 40 : CanopySize.target),
                        child: Padding(
                            padding: compact
                                ? const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8)
                                : const EdgeInsets.symmetric(
                                    horizontal: 22, vertical: 12),
                            child: Center(
                                widthFactor: expand ? null : 1,
                                heightFactor: 1,
                                child: content)))))));
  }
}

/// White, 15 px corners and the website's soft ambient shadow.
class HedayahCard extends StatelessWidget {
  const HedayahCard(
      {super.key,
      required this.child,
      this.onTap,
      this.padding = const EdgeInsets.all(20)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final card = DecoratedBox(
        decoration: BoxDecoration(
            color: HedayahSkin.paper,
            borderRadius: BorderRadius.circular(HedayahSkin.radiusCard),
            boxShadow: HedayahSkin.ambient),
        child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(HedayahSkin.radiusCard),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap, child: Padding(padding: padding, child: child))));
    return onTap == null
        ? card
        : CaFocusRing(radius: HedayahSkin.radiusCard, child: card);
  }
}

/// The website's About tabs: a white pill track, the chosen one filled gold.
class HedayahPillTabs<T> extends StatelessWidget {
  const HedayahPillTabs(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
          color: HedayahSkin.paper,
          borderRadius: BorderRadius.circular(HedayahSkin.radiusPill),
          boxShadow: const [
            BoxShadow(color: Color(0x12000000), blurRadius: 10)
          ]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (option, label) in options)
          Semantics(
              button: true,
              selected: option == value,
              child: CaFocusRing(
                  radius: HedayahSkin.radiusPill,
                  child: Material(
                      color: option == value
                          ? HedayahSkin.gold
                          : Colors.transparent,
                      shape: const StadiumBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                          onTap: () => onChanged(option),
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 40),
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 18, vertical: 9),
                                  child: Text(label,
                                      style: HedayahSkin.displayStyle(14,
                                          weight: option == value
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          height: 1.4))))))))
      ]));
}

/// A gold ring on a light track with a figure inside: the website's
/// statistics.
class HedayahRing extends StatelessWidget {
  const HedayahRing(
      {super.key, required this.value, required this.child, this.size = 96});

  final double value;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: size,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
                value: value.clamp(0.0, 1.0),
                strokeWidth: size * .085,
                strokeCap: StrokeCap.butt,
                color: HedayahSkin.gold,
                backgroundColor: HedayahSkin.track)),
        child,
      ]));
}

/// A section heading marked by the gold bar the identity book uses for
/// notes, with an optional count in a chip.
class HedayahHeading extends StatelessWidget {
  const HedayahHeading(this.label, {super.key, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
                color: HedayahSkin.gold,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: HedayahSkin.displayStyle(17, height: 1.4))),
        if (count != null)
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                  color: HedayahSkin.chip,
                  borderRadius: BorderRadius.circular(HedayahSkin.radiusPill)),
              child: Text('$count',
                  style: HedayahSkin.textStyle(12.5,
                      color: HedayahSkin.chipInk,
                      weight: FontWeight.w700,
                      height: 1.5))),
      ]);
}

/// A rounded gold band with the lattice: an eyebrow, a title and an optional
/// badge, the white rosette at the end. Discover opens with it.
class HedayahHeroBand extends StatelessWidget {
  const HedayahHeroBand(
      {super.key, required this.eyebrow, required this.title, this.badge});

  final String eyebrow, title;
  final Widget? badge;

  @override
  Widget build(BuildContext context) => HedayahGoldBand(
      radius: BorderRadius.circular(HedayahSkin.radiusCard),
      step: 24,
      fadeFrom: AlignmentDirectional.centerEnd
          .resolve(Directionality.of(context)),
      child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(eyebrow,
                      style: HedayahSkin.displayStyle(12.5,
                          weight: FontWeight.w500,
                          color: HedayahSkin.ink.withValues(alpha: .9),
                          height: 1.4)),
                  const SizedBox(height: 6),
                  Text(title,
                      style: HedayahSkin.displayStyle(18,
                          weight: FontWeight.w700, height: 1.5)),
                  if (badge != null) ...[const SizedBox(height: 12), badge!],
                ])),
            const SizedBox(width: 12),
            const HedayahRosette(size: 58, color: HedayahSkin.paper),
          ])));
}

/// A white pill on gold with a red dot: how many are live now.
class HedayahLiveBadge extends StatelessWidget {
  const HedayahLiveBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 12, 4),
      decoration: BoxDecoration(
          color: HedayahSkin.paper,
          borderRadius: BorderRadius.circular(HedayahSkin.radiusPill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
                color: HedayahSkin.danger, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: HedayahSkin.displayStyle(12.5,
                weight: FontWeight.w600, height: 1.4)),
      ]));
}
