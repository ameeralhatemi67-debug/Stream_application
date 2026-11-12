import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'lantern_base.dart';
import 'lantern_controls.dart';

/// The one card shell: 24 px corners, a hairline, a warm shadow. A tappable
/// card lifts 4 px and a light crosses it on hover; [selected] adds the gold
/// ring and a star in the corner.
class LCard extends StatelessWidget implements LanternSkinWidget {
  const LCard(
      {super.key,
      required this.child,
      this.onTap,
      this.label,
      this.padding = const EdgeInsets.all(16),
      this.radius = Lantern.radiusCard,
      this.selected = false,
      this.dim = false,
      this.color,
      this.flat = false,
      this.clip = true});

  final Widget child;
  final VoidCallback? onTap;

  /// Spoken name when the whole card is one button.
  final String? label;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool selected, dim, flat, clip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget shell(LPressState s) {
      final lifted = s.hovered && !s.pressed;
      return AnimatedContainer(
          duration: Lantern.calm(context)
              ? Lantern.none
              : const Duration(milliseconds: 300),
          curve: Lantern.ease,
          transform: Matrix4.translationValues(0, lifted ? -4 : 0, 0),
          decoration: BoxDecoration(
              color: color ?? t.surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                  color: selected
                      ? LanternTokens.gold
                      : lifted
                          ? LanternTokens.goldHi
                          : t.line),
              boxShadow: flat
                  ? null
                  : [
                      if (selected) BoxShadow(color: t.glow, spreadRadius: 3),
                      ...(lifted ? t.shadowHi : t.shadow),
                    ]),
          child: Stack(children: [
            clip
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(radius - 1),
                    child: Padding(padding: padding, child: child))
                : Padding(padding: padding, child: child),
            if (selected)
              const PositionedDirectional(
                  top: 10, end: 10, child: LStar(size: 20)),
          ]));
    }

    final card = onTap == null
        ? shell((hovered: false, pressed: false, focused: false))
        : LPressable(
            onTap: onTap,
            label: label,
            radius: radius,
            pressScale: .985,
            builder: (context, s) => shell(s));
    return dim ? Opacity(opacity: .55, child: card) : card;
  }
}

/// A list row: an icon disc, a title and a line under it, and an arrow or a
/// control at the end. Settings, menus and lists share it.
class LRow extends StatelessWidget implements LanternSkinWidget {
  const LRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.icon,
      this.leading,
      this.trailing,
      this.onTap,
      this.arrow = true,
      this.danger = false,
      this.dense = false});

  final String title;
  final String? subtitle;
  final LGlyph? icon;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  final bool arrow, danger, dense;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget body(LPressState s) => AnimatedContainer(
        duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 9 : 12),
        decoration: BoxDecoration(
            color: s.hovered ? t.sunk : t.surface,
            borderRadius: BorderRadius.circular(Lantern.radiusRow),
            border: Border.all(color: s.hovered ? t.line : t.line2)),
        child: Row(children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          if (leading == null && icon != null) ...[
            Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: danger ? t.liveSoft : t.sunk,
                    borderRadius: BorderRadius.circular(Lantern.radiusTile)),
                child: LIcon(icon!,
                    size: 20, color: danger ? t.liveText : t.goldInk)),
            const SizedBox(width: 12),
          ],
          Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Lantern.textStyle(14.5,
                        color: danger ? t.liveText : t.fg,
                        weight: FontWeight.w600,
                        height: 1.35)),
                if (subtitle != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(subtitle!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(12.5,
                              color: t.muted, height: 1.4))),
              ])),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (trailing == null && arrow && onTap != null) ...[
            const SizedBox(width: 8),
            LIcon(LGlyph.chevronend,
                size: 18, color: s.hovered ? t.goldInk : t.faint),
          ],
        ]));
    return onTap == null
        ? body((hovered: false, pressed: false, focused: false))
        : LPressable(
            onTap: onTap,
            radius: Lantern.radiusRow,
            pressScale: .985,
            builder: (context, s) => body(s));
  }
}

/// A section's heading: the small arch, the title, a count and one link.
class LSectionHead extends StatelessWidget implements LanternSkinWidget {
  const LSectionHead(this.title,
      {super.key,
      this.count,
      this.subtitle,
      this.action,
      this.onAction,
      this.arch = true,
      this.isNew = false});

  final String title;
  final String? count, subtitle, action;
  final VoidCallback? onAction;
  final bool arch, isNew;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (arch)
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SizedBox(
                    width: 46,
                    height: 23,
                    child: DecoratedBox(
                        decoration: ShapeDecoration(
                            gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFD2A95F),
                                  LanternTokens.gold
                                ]),
                            shape: LArchBorder())))),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text.rich(
                        TextSpan(text: title, children: [
                          if (isNew)
                            const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Padding(
                                    padding:
                                        EdgeInsetsDirectional.only(start: 8),
                                    child: LTag('NEW', tone: LTone.gold))),
                        ]),
                        style: Lantern.displayStyle(24,
                            color: t.fg,
                            height: context.lanternArabic ? 1.4 : 1.2)))),
            if (count != null)
              Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: Text(count!,
                      style: Lantern.textStyle(13, color: t.muted)
                          .copyWith(fontFeatures: Lantern.tabular))),
            if (action != null && onAction != null)
              Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12),
                  child: LLink(action!, onTap: onAction!)),
          ]),
          if (subtitle != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(subtitle!,
                    style: Lantern.textStyle(14, color: t.muted))),
        ]);
  }
}

/// A text link in gold ink with a forward arrow.
class LLink extends StatelessWidget implements LanternSkinWidget {
  const LLink(this.label,
      {super.key, required this.onTap, this.arrow = true, this.icon});

  final String label;
  final VoidCallback onTap;
  final bool arrow;
  final LGlyph? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LPressable(
        onTap: onTap,
        label: label,
        radius: 8,
        excludeChildSemantics: true,
        builder: (context, s) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[
                LIcon(icon!, size: 16, color: t.goldInk),
                const SizedBox(width: 6),
              ],
              Flexible(
                  child: Text(label,
                      style: Lantern.textStyle(14,
                              color: t.goldInk,
                              weight: FontWeight.w600,
                              height: 1.3)
                          .copyWith(
                              decoration: s.hovered
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                              decorationColor: t.goldInk))),
              if (arrow) ...[
                const SizedBox(width: 6),
                LIcon(LGlyph.arrow, size: 16, color: t.goldInk),
              ],
            ])));
  }
}

/// A divider with the star at its middle.
class LStarDivider extends StatelessWidget implements LanternSkinWidget {
  const LStarDivider({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final line = Expanded(child: Container(height: 1, color: t.line));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          line,
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: label == null
                  ? const LStar(size: 12)
                  : Text(label!,
                      style: Lantern.textStyle(12.5,
                          color: t.muted, weight: FontWeight.w600))),
          line,
        ]));
  }
}

enum LRing { none, live, audio, mod, admin }

/// A person or channel: a photo or an initial on a tinted disc, with a ring
/// for state. Live and audio rings hold still; only a white shine travels
/// around them (owner decision). Organizations are rounded squares.
class LAvatar extends StatefulWidget implements LanternSkinWidget {
  const LAvatar(
      {super.key,
      required this.name,
      this.image,
      this.size = 46,
      this.ring = LRing.none,
      this.org = false,
      this.verified = false,
      this.online = false,
      this.tone});

  final String name;
  final ImageProvider? image;
  final double size;
  final LRing ring;
  final bool org, verified, online;

  /// 0 to 4: gold, teal, violet, green, red. From the name when null.
  final int? tone;

  static const tones = <List<Color>>[
    [Color(0xFFBD933F), Color(0xFF805B1B)],
    [Color(0xFF2D6F86), Color(0xFF17414F)],
    [Color(0xFF7A6BC4), Color(0xFF3F3485)],
    [Color(0xFF2D7647), Color(0xFF174A2B)],
    [Color(0xFFC2343F), Color(0xFF7C1824)],
  ];

  static int toneOf(String name) => name.isEmpty
      ? 0
      : name.runes.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff) %
          tones.length;

  static String initialOf(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    // Skip an honorific written with a dot ("د.", "أ.", "Dr.").
    final words = trimmed.split(RegExp(r'\s+'));
    final word = words.firstWhere((w) => !w.endsWith('.') && w.isNotEmpty,
        orElse: () => words.first);
    final bare = word.startsWith('ال') && word.length > 2
        ? word.substring(2)
        : word;
    return String.fromCharCode(bare.runes.first).toUpperCase();
  }

  @override
  State<LAvatar> createState() => _LAvatarState();
}

class _LAvatarState extends State<LAvatar>
    with SingleTickerProviderStateMixin {
  AnimationController? _shine;

  bool get _travels =>
      widget.ring == LRing.live || widget.ring == LRing.audio;

  void _sync() {
    final run = _travels && !Lantern.calm(context);
    if (!run) {
      _shine?.stop();
      return;
    }
    final c = _shine ??= AnimationController(vsync: this);
    c.duration = Duration(
        milliseconds: widget.ring == LRing.live ? 2600 : 3400);
    if (!c.isAnimating) c.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LAvatar old) {
    super.didUpdateWidget(old);
    if (old.ring != widget.ring) _sync();
  }

  @override
  void dispose() {
    _shine?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final s = widget.size;
    final corner = widget.org ? s * .3 : s / 2;
    final tone = LAvatar.tones[widget.tone ?? LAvatar.toneOf(widget.name)];
    final face = ClipRRect(
        borderRadius: BorderRadius.circular(corner),
        child: SizedBox.square(
            dimension: s,
            child: widget.image != null
                ? Image(
                    image: widget.image!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initial(tone, s))
                : _initial(tone, s)));
    final ringed = widget.ring == LRing.none
        ? face
        : CustomPaint(
            foregroundPainter: _RingPainter(
                ring: widget.ring,
                tokens: t,
                corner: corner + 4,
                shine: _shine),
            child: Padding(padding: const EdgeInsets.all(4), child: face));
    final seal = math.max(16.0, s * .4);
    return Semantics(
        image: true,
        label: widget.name,
        child: ExcludeSemantics(
            child: Stack(clipBehavior: Clip.none, children: [
          ringed,
          if (widget.verified)
            PositionedDirectional(
                end: -3,
                bottom: -3,
                child: Container(
                    width: seal,
                    height: seal,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: LanternTokens.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.surface, width: 2)),
                    child: LIcon(LGlyph.check,
                        size: seal * .58, color: LanternTokens.onGold)))
          else if (widget.online)
            PositionedDirectional(
                end: 0,
                bottom: 0,
                child: Container(
                    width: s * .26,
                    height: s * .26,
                    decoration: BoxDecoration(
                        color: t.ok,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.surface, width: 2)))),
        ])));
  }

  Widget _initial(List<Color> tone, double s) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: tone)),
      child: Center(
          child: Text(LAvatar.initialOf(widget.name),
              style: Lantern.displayStyle(s * .38,
                  color: LanternTokens.white,
                  weight: FontWeight.w700,
                  height: 1.1))));
}

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.ring,
      required this.tokens,
      required this.corner,
      required this.shine})
      : super(repaint: shine);

  final LRing ring;
  final LanternTokens tokens;
  final double corner;
  final Animation<double>? shine;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 2.5;
    final rect = (Offset.zero & size).deflate(w / 2);
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(corner));
    final colors = switch (ring) {
      LRing.live => const [
          Color(0xFFC2343F),
          Color(0xFFF2B5C0),
          Color(0xFF9A1C2E),
          Color(0xFFE5535E),
          Color(0xFFC2343F)
        ],
      LRing.audio => [
          tokens.audio,
          tokens.audio.withValues(alpha: .35),
          tokens.audio,
          tokens.audio.withValues(alpha: .35),
          tokens.audio
        ],
      LRing.mod => const [
          Color(0xFF4B3F96),
          Color(0xFFA99BFF),
          Color(0xFF4B3F96)
        ],
      LRing.admin => const [
          Color(0xFFBD933F),
          Color(0xFFF7E6AD),
          Color(0xFFA87726),
          Color(0xFFBD933F)
        ],
      LRing.none => const [Color(0x00000000), Color(0x00000000)],
    };
    canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..shader = SweepGradient(colors: colors).createShader(rect));
    final v = shine?.value;
    if (v == null || !(shine?.isAnimating ?? false)) return;
    // A short white arc that goes round; the ring itself does not turn.
    canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..shader = SweepGradient(
              transform: GradientRotation(v * 2 * math.pi),
              stops: const [0, .08, .16, 1],
              colors: const [
                Color(0x00FFFFFF),
                Color(0xE6FFFFFF),
                Color(0x00FFFFFF),
                Color(0x00FFFFFF)
              ]).createShader(rect));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ring != ring || old.tokens != tokens || old.corner != corner;
}

enum LBadgeKind { live, audio, soon, now, off, glass }

/// State in words, never colour alone: LIVE (red, a pinging dot), AUDIO
/// (teal, moving bars), scheduled (amber), on now at a mosque (green),
/// offline (grey), and a glass badge for counts over video.
class LBadge extends StatelessWidget implements LanternSkinWidget {
  const LBadge(this.label,
      {super.key,
      required this.kind,
      this.icon,
      this.small = false,
      this.paused = false});

  final String label;
  final LBadgeKind kind;
  final LGlyph? icon;
  final bool small, paused;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final (bg, fg) = switch (kind) {
      LBadgeKind.live => (null, LanternTokens.white),
      LBadgeKind.audio => (t.audioSoft, t.audio),
      LBadgeKind.soon => (t.warnSoft, t.warn),
      LBadgeKind.now => (t.okSoft, t.ok),
      LBadgeKind.off => (t.sunk, t.muted),
      LBadgeKind.glass => (const Color(0x8C0B1117), LanternTokens.white),
    };
    final h = small ? 22.0 : 26.0;
    return Container(
        height: h,
        padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10),
        decoration: BoxDecoration(
            color: bg,
            gradient: kind == LBadgeKind.live ? Lantern.dangerFill : null,
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            border: kind == LBadgeKind.audio
                ? Border.all(color: t.audio, width: 1)
                : null,
            boxShadow: kind == LBadgeKind.live
                ? const [
                    BoxShadow(
                        color: Color(0xB3A31F30),
                        blurRadius: 10,
                        spreadRadius: -3,
                        offset: Offset(0, 4))
                  ]
                : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (kind == LBadgeKind.live) ...[
            const _LiveDot(),
            const SizedBox(width: 6),
          ] else if (kind == LBadgeKind.audio) ...[
            LEqualizer(color: fg, paused: paused),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            LIcon(icon!, size: small ? 12 : 14, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label,
              maxLines: 1,
              style: Lantern.textStyle(small ? 10.5 : 11.5,
                      color: fg, weight: FontWeight.w700, height: 1.2)
                  .copyWith(fontFeatures: Lantern.tabular)),
        ]));
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ping = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Lantern.calm(context)) {
      _ping.stop();
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
  Widget build(BuildContext context) => SizedBox.square(
      dimension: 10,
      child: AnimatedBuilder(
          animation: _ping,
          builder: (context, _) {
            final v = Lantern.ease.transform(_ping.value);
            return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  if (_ping.isAnimating)
                    Transform.scale(
                        scale: .5 + 1.8 * v,
                        child: Container(
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: LanternTokens.white
                                        .withValues(alpha: .75 * (1 - v)),
                                    width: 1.5)))),
                  Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: LanternTokens.white,
                          shape: BoxShape.circle)),
                ]);
          }));
}

/// Four bars that rise and fall: the mark of an audio room.
class LEqualizer extends StatefulWidget implements LanternSkinWidget {
  const LEqualizer(
      {super.key,
      required this.color,
      this.paused = false,
      this.bars = 4,
      this.height = 11,
      this.barWidth = 2.5});

  final Color color;
  final bool paused;
  final int bars;
  final double height, barWidth;

  @override
  State<LEqualizer> createState() => _LEqualizerState();
}

class _LEqualizerState extends State<LEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  void _sync() {
    if (widget.paused || Lantern.calm(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LEqualizer old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < widget.bars; i++) ...[
                      if (i > 0) SizedBox(width: widget.barWidth * .8),
                      Container(
                          width: widget.barWidth,
                          height: widget.height *
                              (_c.isAnimating
                                  ? .35 +
                                      .65 *
                                          (.5 +
                                              .5 *
                                                  math.sin(2 *
                                                      math.pi *
                                                      (_c.value +
                                                          const [
                                                            0,
                                                            .33,
                                                            .66,
                                                            .17,
                                                            .5,
                                                            .83
                                                          ][i % 6])))
                                  : const [.5, .9, .4, .7, .6, .8][i % 6]),
                          decoration: BoxDecoration(
                              color: widget.color,
                              borderRadius: BorderRadius.circular(2))),
                    ],
                  ])));
}

enum LTone { gold, neutral, live, audio, ok, warn, mod }

/// A small labelled chip: roles in chat (words, not only ring colours),
/// verified, tags and states in lists.
class LTag extends StatelessWidget implements LanternSkinWidget {
  const LTag(this.label,
      {super.key, this.tone = LTone.neutral, this.icon, this.outlined = false});

  final String label;
  final LTone tone;
  final LGlyph? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final (bg, fg) = switch (tone) {
      LTone.gold => (t.sunk, t.goldInk),
      LTone.neutral => (t.sunk, t.muted),
      LTone.live => (t.liveSoft, t.liveText),
      LTone.audio => (t.audioSoft, t.audio),
      LTone.ok => (t.okSoft, t.ok),
      LTone.warn => (t.warnSoft, t.warn),
      LTone.mod => (t.modSoft, t.mod),
    };
    return Container(
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            border: outlined
                ? Border.all(
                    color: tone == LTone.gold ? LanternTokens.gold : t.line)
                : null),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            LIcon(icon!, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(11.5,
                      color: fg, weight: FontWeight.w600, height: 1.2))),
        ]));
  }
}

/// A banner inside a page: neutral, caution, error, fine or information.
class LBanner extends StatelessWidget implements LanternSkinWidget {
  const LBanner(this.text,
      {super.key,
      this.tone = LTone.neutral,
      this.icon,
      this.action,
      this.busy = false});

  final String text;
  final LTone tone;
  final LGlyph? icon;
  final Widget? action;

  /// Three moving dots after the text (reconnecting, sending).
  final bool busy;

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
    final glyph = icon ??
        switch (tone) {
          LTone.warn => LGlyph.warn,
          LTone.live => LGlyph.warn,
          LTone.ok => LGlyph.check,
          _ => LGlyph.info,
        };
    return Semantics(
        liveRegion: tone == LTone.live || tone == LTone.warn,
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(Lantern.radiusField),
                border: tone == LTone.neutral || tone == LTone.gold
                    ? Border.all(color: t.line)
                    : null),
            child: Row(children: [
              LIcon(glyph, size: 18, color: fg),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style: Lantern.textStyle(13.5,
                          color: fg, weight: FontWeight.w500, height: 1.4))),
              if (busy) ...[
                const SizedBox(width: 8),
                LEqualizer(color: fg, bars: 3, height: 8, barWidth: 3),
              ],
              if (action != null) ...[const SizedBox(width: 10), action!],
            ])));
  }
}

/// A short message that rises from the bottom: a night pill with one icon
/// and at most one action.
void lanternToast(BuildContext context, String message,
    {LGlyph icon = LGlyph.check,
    String? actionLabel,
    VoidCallback? onAction,
    bool warn = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LanternTokens.nightGround,
        elevation: 6,
        shape: const StadiumBorder(),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
        duration: Duration(seconds: actionLabel == null ? 3 : 5),
        content: Row(children: [
          LIcon(warn ? LGlyph.warn : icon,
              size: 18,
              color: warn ? const Color(0xFFE3A857) : LanternTokens.goldHi),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: Lantern.textStyle(14,
                      color: LanternTokens.onNight,
                      weight: FontWeight.w500,
                      height: 1.35))),
          if (actionLabel != null)
            TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onAction?.call();
                },
                style: TextButton.styleFrom(
                    foregroundColor: LanternTokens.goldHi),
                child: Text(actionLabel)),
        ])));
}

/// A grey block with a light passing over it, while content loads. Still
/// under calm motion.
class LSkeleton extends StatefulWidget implements LanternSkinWidget {
  const LSkeleton(
      {super.key, this.width, this.height = 14, this.radius = 12});

  final double? width;
  final double height, radius;

  @override
  State<LSkeleton> createState() => _LSkeletonState();
}

class _LSkeletonState extends State<LSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Lantern.calm(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return ExcludeSemantics(
        child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius),
            child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: DecoratedBox(
                    decoration: BoxDecoration(color: t.sunk),
                    child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) => _c.isAnimating
                            ? FractionalTranslation(
                                translation: Offset(
                                    (rtl ? 1 : -1) * (1 - 2 * _c.value), 0),
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [
                                  t.shimmer.withValues(alpha: 0),
                                  t.shimmer,
                                  t.shimmer.withValues(alpha: 0)
                                ]))))
                            : const SizedBox.shrink())))));
  }
}

/// Nothing here: an arch drawn in three gold lines, a title, a sentence and
/// one way forward. Also carries errors ([tone] warn or live).
class LEmptyState extends StatelessWidget implements LanternSkinWidget {
  const LEmptyState(
      {super.key,
      required this.title,
      this.body,
      this.action,
      this.icon,
      this.tone = LTone.gold,
      this.compact = false});

  final String title;
  final String? body;
  final Widget? action;
  final LGlyph? icon;
  final LTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 20, vertical: compact ? 16 : 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 92,
              height: 66,
              child: Stack(alignment: Alignment.bottomCenter, children: [
                Positioned.fill(child: LArchDraw(lineColor: t.line)),
                if (icon != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LIcon(icon!,
                          size: 22,
                          color: tone == LTone.live
                              ? t.liveText
                              : tone == LTone.warn
                                  ? t.warn
                                  : t.goldInk)),
              ])),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: Lantern.textStyle(15.5,
                  color: t.fg, weight: FontWeight.w600, height: 1.4)),
          if (body != null) ...[
            const SizedBox(height: 6),
            ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(body!,
                    textAlign: TextAlign.center,
                    style: Lantern.textStyle(13.5, color: t.muted))),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]));
  }
}

/// Three nested arches drawing themselves once (1.2 s); drawn at once under
/// calm motion.
class LArchDraw extends StatefulWidget implements LanternSkinWidget {
  const LArchDraw({super.key, required this.lineColor});

  final Color lineColor;

  @override
  State<LArchDraw> createState() => _LArchDrawState();
}

class _LArchDrawState extends State<LArchDraw>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500));
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Lantern.calm(context)) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _ArchDrawPainter(_c, widget.lineColor));
}

class _ArchDrawPainter extends CustomPainter {
  _ArchDrawPainter(this.progress, this.lineColor) : super(repaint: progress);

  final Animation<double> progress;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    const colors = [LanternTokens.gold, LanternTokens.goldHi];
    for (var i = 0; i < 3; i++) {
      final inset = i * size.width * .13;
      final rect = Rect.fromLTRB(inset, inset * .9, size.width - inset,
          size.height + 2);
      // Open at the bottom: up one side, over the head, down the other.
      final r = rect.width / 2;
      final path = Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + r)
        ..arcToPoint(Offset(rect.right, rect.top + r),
            radius: Radius.circular(r))
        ..lineTo(rect.right, rect.bottom);
      final t = Lantern.ease
          .transform(((progress.value - i * .1) / .8).clamp(0.0, 1.0));
      if (t <= 0) continue;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = i < 2 ? colors[i] : lineColor;
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_ArchDrawPainter old) => old.lineColor != lineColor;
}

/// A thin progress bar with the gold run.
class LProgress extends StatelessWidget implements LanternSkinWidget {
  const LProgress(this.value,
      {super.key, this.height = 8, this.label, this.color});

  /// 0 to 1.
  final double value;
  final double height;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Semantics(
        label: label,
        value: '${(value.clamp(0, 1) * 100).round()}%',
        child: ClipRRect(
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            child: SizedBox(
                height: height,
                child: DecoratedBox(
                    decoration: BoxDecoration(color: t.sunk),
                    child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: AnimatedFractionallySizedBox(
                            duration: Lantern.calm(context)
                                ? Lantern.none
                                : const Duration(milliseconds: 500),
                            curve: Lantern.ease,
                            widthFactor: value.clamp(0.0, 1.0),
                            heightFactor: 1,
                            child: DecoratedBox(
                                decoration: BoxDecoration(
                                    color: color,
                                    gradient: color == null
                                        ? Lantern.progressFill
                                        : null,
                                    borderRadius: BorderRadius.circular(
                                        Lantern.radiusPill)))))))));
  }
}

/// A level meter (the studio's microphone): bars turn gold, amber, then red.
class LMeter extends StatelessWidget implements LanternSkinWidget {
  const LMeter(this.level, {super.key, this.bars = 18, this.height = 26});

  /// 0 to 1.
  final double level;
  final int bars;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lit = (level.clamp(0.0, 1.0) * bars).round();
    return ExcludeSemantics(
        child: SizedBox(
            height: height,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < bars; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                    child: FractionallySizedBox(
                        heightFactor: i < lit ? .45 + .55 * (i + 1) / bars : .3,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: i >= lit
                                    ? t.line
                                    : i >= bars * .9
                                        ? t.live
                                        : i >= bars * .72
                                            ? const Color(0xFFE3A857)
                                            : LanternTokens.gold)))),
              ],
            ])));
  }
}

/// A dialog in the Lantern shape: 28 px corners, a title in the display
/// face, a close button, the body, then actions at the end.
Future<T?> showLanternDialog<T>(BuildContext context,
    {required String title,
    required WidgetBuilder body,
    List<Widget> Function(BuildContext context)? actions,
    double maxWidth = 480,
    bool dismissible = true,
    bool? night}) {
  return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: context.lt.scrim,
      builder: (dialogContext) => LanternSurface(
          night: night ?? (context.lt.night ? true : null),
          child: Builder(builder: (context) {
            final t = context.lt;
            return Dialog(
                backgroundColor: t.raised,
                surfaceTintColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Lantern.radiusDialog),
                    side: BorderSide(color: t.line)),
                child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Semantics(
                                        header: true,
                                        child: Text(title,
                                            style: Lantern.displayStyle(19,
                                                color: t.fg,
                                                height: context.lanternArabic
                                                    ? 1.45
                                                    : 1.25)))),
                                if (dismissible)
                                  LIconButton(
                                      icon: LGlyph.close,
                                      label: MaterialLocalizations.of(context)
                                          .closeButtonLabel,
                                      onPressed: () =>
                                          Navigator.of(context).maybePop()),
                              ]),
                              const SizedBox(height: 8),
                              Flexible(
                                  child: SingleChildScrollView(
                                      child: body(context))),
                              if (actions != null) ...[
                                const SizedBox(height: 18),
                                Wrap(
                                    alignment: WrapAlignment.end,
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: actions(context)),
                              ],
                            ]))));
          })));
}

/// A bottom sheet in the Lantern shape (phones), or a dialog on the website
/// layout where a sheet would hide the page.
///
/// [headerActions] are icon buttons drawn in the title row, just before the
/// close button (on phones only; the website layout's dialog has none).
Future<T?> showLanternSheet<T>(BuildContext context,
    {required String title,
    required WidgetBuilder body,
    bool? night,
    bool scrollControlled = true,
    List<Widget> Function(BuildContext context)? headerActions}) {
  if (context.lanternWide) {
    return showLanternDialog<T>(context,
        title: title, body: body, night: night);
  }
  final forced = night ?? (context.lt.night ? true : null);
  return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: scrollControlled,
      useSafeArea: true,
      // Over the whole app: a sheet opened from a tab must cover the
      // floating navigation, not slide in under it.
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: context.lt.scrim,
      builder: (sheetContext) => LanternSurface(
          night: forced,
          child: Builder(builder: (context) {
            final t = context.lt;
            return Container(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .9),
                decoration: BoxDecoration(
                    color: t.raised,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(Lantern.radiusDialog)),
                    border: Border(top: BorderSide(color: t.line))),
                padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: Container(
                              margin: const EdgeInsets.only(top: 10),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: t.line,
                                  borderRadius: BorderRadius.circular(2)))),
                      Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              20, 10, 10, 4),
                          child: Row(children: [
                            Expanded(
                                child: Semantics(
                                    header: true,
                                    child: Text(title,
                                        style: Lantern.displayStyle(18,
                                            color: t.fg,
                                            height: context.lanternArabic
                                                ? 1.45
                                                : 1.25)))),
                            if (headerActions != null)
                              ...headerActions(context),
                            LIconButton(
                                icon: LGlyph.close,
                                label: MaterialLocalizations.of(context)
                                    .closeButtonLabel,
                                onPressed: () =>
                                    Navigator.of(context).maybePop()),
                          ])),
                      Flexible(
                          child: SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 4, 20, 24),
                              child: body(context))),
                    ]));
          })));
}
