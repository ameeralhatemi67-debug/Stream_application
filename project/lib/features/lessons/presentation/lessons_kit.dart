import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/routing/sign_in_prompt.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hedayah/hedayah_pattern.dart';
import '../../web/presentation/hidayah_web_kit.dart';
import '../data/lessons_repository.dart';
import 'lessons_icons.dart';

export 'lessons_icons.dart';
export '../../../core/theme/hidayah_gold.dart';

/// Lessons's tokens: Hidayah Gold roles as the reviewed prototype names them.
abstract final class TC {
  static const page = HidayahGold.g50, tint = HidayahGold.g100, card = HidayahGold.card;
  static const hair = HidayahGold.hairline, hair2 = Color(0xFFE0D0B0);
  static const ink = HidayahGold.s900, ink2 = HidayahGold.s700, muted = HidayahGold.s600, faint = HidayahGold.s400;
  static const bronze = HidayahGold.g700, gold = HidayahGold.g500, goldIcon = HidayahGold.g600;
  static const tagBg = HidayahGold.g100, tagFg = HidayahGold.g800;
  static const onNight = HidayahGold.g50, onNight2 = HidayahGold.s200, onNightGold = HidayahGold.g300;
  static const nightLine = Color(0x29EDDAB4);
  static const live = HidayahGold.live;
  static const successFg = HidayahGold.success, successBg = Color(0xFFE5F1E8);
  static const warnFg = HidayahGold.warning, warnBg = Color(0xFFFBEEDC);
  static const dangerFg = HidayahGold.live, dangerBg = Color(0xFFF8E4E5);
  static const infoFg = HidayahGold.info, infoBg = Color(0xFFE3EFF3);
  static const slateFg = HidayahGold.s700, slateBg = Color(0xFFEEF1F3);
  static const shadow = [BoxShadow(color: Color(0x3D6E4A14), blurRadius: 30, spreadRadius: -22, offset: Offset(0, 14))];
  static const night = LinearGradient(
      begin: Alignment(-.5, -1), end: Alignment(.5, 1), stops: [0, .55, 1],
      colors: [HidayahGold.s800, HidayahGold.s900, HidayahGold.s950]);
  static const r = 12.0, rLg = 16.0, rXl = 22.0;
}

enum TTone { gold, slate, success, warning, danger, info, live, liveSoft }

(Color, Color) toneColors(TTone t) => switch (t) {
      TTone.gold => (TC.tagBg, TC.tagFg),
      TTone.slate => (TC.slateBg, TC.slateFg),
      TTone.success => (TC.successBg, TC.successFg),
      TTone.warning => (TC.warnBg, TC.warnFg),
      TTone.danger => (TC.dangerBg, TC.dangerFg),
      TTone.info => (TC.infoBg, TC.infoFg),
      TTone.live => (TC.live, Colors.white),
      TTone.liveSoft => (TC.dangerBg, TC.dangerFg),
    };

extension LessonsContext on BuildContext {
  String get lang => locale.languageCode;
  bool get ar => locale.languageCode == 'ar';

  /// Website layout (header navigation, multi-column pages).
  bool get wide => MediaQuery.sizeOf(this).width >= HidayahWeb.minWidth;
}

TextStyle tDisplay(double size, {Color color = TC.ink}) => HidayahText.display(size, color: color);
TextStyle tBody(double size, {Color color = TC.ink2, FontWeight weight = FontWeight.w400, double height = 1.6}) =>
    HidayahText.body(size, color: color, weight: weight, height: height);
TextStyle tStrong(double size, {Color color = TC.ink}) => tBody(size, color: color, weight: FontWeight.w700, height: 1.4);

/// Localized message for a failed write.
String lessonsError(Object e) =>
    'lessons.error.${e is LessonsException ? e.failure.name : 'unknown'}'.tr();

void tToast(BuildContext context, String message, {bool warn = false, String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: TC.ink,
    duration: Duration(milliseconds: onAction == null ? 4000 : 6500),
    content: Row(children: [
      TIcon(warn ? TGlyph.info : TGlyph.check, size: 16, color: warn ? const Color(0xFFE9B872) : const Color(0xFF86CB9C)),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: tBody(14, color: TC.onNight, height: 1.4))),
    ]),
    action: onAction == null
        ? null
        : SnackBarAction(label: actionLabel ?? '', textColor: HidayahGold.g300, onPressed: onAction),
  ));
}

/// Runs a write and reports a failure as a toast. Returns null on failure.
Future<T?> tRun<T>(BuildContext context, Future<T> Function() call, {String? success}) async {
  try {
    final r = await call();
    if (success != null && context.mounted) tToast(context, success);
    return r;
  } catch (e) {
    if (context.mounted) tToast(context, lessonsError(e), warn: true);
    return null;
  }
}

Future<void> copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) tToast(context, 'lessons.copied'.tr());
}

// ------------------------------------------------------------------ buttons
enum TBtn { minted, outline, ghost, ink, danger, night }

class TButton extends StatelessWidget {
  const TButton(this.label,
      {super.key, this.onPressed, this.kind = TBtn.outline, this.icon, this.iconEnd, this.small = false, this.large = false, this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final TBtn kind;
  final TGlyph? icon, iconEnd;
  final bool small, large, expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final (Color? bg, Gradient? grad, Color fg, Color? border) = switch (kind) {
      TBtn.minted => (null, HidayahGradients.minted, TC.ink, null),
      TBtn.outline => (TC.card, null, TC.ink, TC.hair2),
      TBtn.ghost => (Colors.transparent, null, TC.ink2, null),
      TBtn.ink => (null, HidayahGradients.selected, HidayahGold.g200, null),
      TBtn.danger => (TC.card, null, TC.dangerFg, TC.dangerFg.withValues(alpha: .35)),
      TBtn.night => (const Color(0x0FFFFFFF), null, TC.onNight, TC.nightLine),
    };
    final h = small ? 34.0 : large ? 50.0 : 42.0;
    final fs = small ? 13.0 : large ? 15.0 : 14.0;
    final content = Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[TIcon(icon!, size: small ? 15 : 17, color: fg), const SizedBox(width: 8)],
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(fs, color: fg, weight: FontWeight.w700, height: 1.2))),
      if (iconEnd != null) ...[const SizedBox(width: 8), TIcon(iconEnd!, size: small ? 15 : 17, color: fg)],
    ]);
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            gradient: grad,
            borderRadius: BorderRadius.circular(999),
            border: border == null ? null : Border.all(color: border),
            boxShadow: kind == TBtn.minted && enabled ? HidayahShadow.minted : null,
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(999),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: h, minWidth: h),
              // Both factors: without heightFactor the button grew to the
              // full height of a bounded row (the 72 px website header).
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: small ? 12 : large ? 22 : 16, vertical: 6),
                  child: Center(widthFactor: 1, heightFactor: 1, child: content)),
            ),
          ),
        ),
      ),
    );
  }
}

class TIconButton extends StatelessWidget {
  const TIconButton(this.glyph, {super.key, required this.tooltip, this.onPressed, this.badge, this.color = TC.ink2});
  final TGlyph glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final int? badge;
  final Color color;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkResponse(
          onTap: onPressed,
          radius: 24,
          child: SizedBox.square(
            dimension: 44,
            child: Stack(alignment: Alignment.center, children: [
              TIcon(glyph, size: 20, color: color, semanticLabel: tooltip),
              if ((badge ?? 0) > 0)
                PositionedDirectional(
                  top: 4,
                  end: 2,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(color: TC.live, borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: Text('$badge', style: tBody(11, color: Colors.white, weight: FontWeight.w700, height: 1)),
                  ),
                ),
            ]),
          ),
        ),
      );
}

// --------------------------------------------------------------- tags/chips
class TTag extends StatelessWidget {
  const TTag(this.label, {super.key, this.tone = TTone.gold, this.icon});
  final String label;
  final TTone tone;
  final TGlyph? icon;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
          color: tone == TTone.live ? null : bg,
          gradient: tone == TTone.live ? HidayahGradients.live : null,
          borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[TIcon(icon!, size: 12, color: fg, stroke: 2.2), const SizedBox(width: 5)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(12, color: fg, weight: FontWeight.w700, height: 1.3))),
      ]),
    );
  }
}

class TLiveTag extends StatelessWidget {
  const TLiveTag({super.key});
  @override
  Widget build(BuildContext context) => TTag('lessons.lesson.live'.tr(), tone: TTone.live, icon: TGlyph.radio);
}

class TChip extends StatelessWidget {
  const TChip(this.label, {super.key, this.selected = false, this.onTap, this.icon, this.count, this.small = false});
  final String label;
  final bool selected, small;
  final VoidCallback? onTap;
  final TGlyph? icon;
  final int? count;
  @override
  Widget build(BuildContext context) {
    final fg = selected ? HidayahGold.g200 : TC.ink2;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? null : TC.card,
            gradient: selected ? HidayahGradients.selected : null,
            borderRadius: BorderRadius.circular(999),
            border: selected ? null : Border.all(color: TC.hair2),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: small ? 34 : 40),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: small ? 11 : 14, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[TIcon(icon!, size: 14, color: fg), const SizedBox(width: 6)],
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(small ? 13 : 14, color: fg, weight: FontWeight.w600, height: 1.2))),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: selected ? const Color(0x33EDDAB4) : TC.tagBg, borderRadius: BorderRadius.circular(10)),
                      child: Text('$count', style: tBody(12, color: selected ? fg : TC.tagFg, weight: FontWeight.w700, height: 1.3)),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of chips that wraps.
class TChips extends StatelessWidget {
  const TChips(this.children, {super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: children);
}

class TSegOption<T> {
  const TSegOption(this.value, this.label, {this.icon, this.count});
  final T value;
  final String label;
  final TGlyph? icon;
  final int? count;
}

class TSeg<T> extends StatelessWidget {
  const TSeg({super.key, required this.options, required this.value, required this.onChanged, this.full = false, this.small = false, this.dark = false});
  final List<TSegOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final bool full, small, dark;
  @override
  Widget build(BuildContext context) {
    Widget item(TSegOption<T> o) {
      final on = o.value == value;
      final fg = on ? HidayahGold.g200 : (dark ? TC.onNight2 : TC.ink2);
      final child = Semantics(
        button: true,
        selected: on,
        child: InkWell(
          onTap: () => onChanged(o.value),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            constraints: BoxConstraints(minHeight: small ? 32 : 38),
            padding: EdgeInsets.symmetric(horizontal: small ? 10 : 14),
            decoration: on ? BoxDecoration(gradient: HidayahGradients.selected, borderRadius: BorderRadius.circular(999)) : null,
            alignment: Alignment.center,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (o.icon != null) ...[TIcon(o.icon!, size: 15, color: fg), const SizedBox(width: 6)],
              Flexible(child: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(small ? 12.5 : 14, color: fg, weight: FontWeight.w600, height: 1.2))),
              if (o.count != null) ...[const SizedBox(width: 6), Text('${o.count}', style: tBody(12, color: fg.withValues(alpha: .8), height: 1.2))],
            ]),
          ),
        ),
      );
      return full ? Expanded(child: child) : child;
    }

    final bar = Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: dark ? const Color(0x14FFFFFF) : TC.tint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: dark ? TC.nightLine : TC.hair)),
      child: Row(mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min, children: [for (final o in options) item(o)]),
    );
    // Full-width bars shorten their labels; the others scroll sideways when
    // large text makes them wider than the screen.
    return full ? bar : SingleChildScrollView(scrollDirection: Axis.horizontal, child: bar);
  }
}

/// Underlined tabs with the gilded underline.
class TTabs<T> extends StatelessWidget {
  const TTabs({super.key, required this.options, required this.value, required this.onChanged});
  final List<TSegOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TC.hair))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 22),
                child: InkWell(
                  onTap: () => onChanged(o.value),
                  child: SizedBox(
                    height: 46,
                    child: Stack(alignment: Alignment.center, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(o.label, style: tBody(14.5, color: o.value == value ? TC.ink : TC.muted, weight: FontWeight.w700, height: 1.2)),
                        if ((o.count ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: TC.tagBg, borderRadius: BorderRadius.circular(10)),
                            child: Text('${o.count}', style: tBody(12, color: TC.tagFg, weight: FontWeight.w700, height: 1.3)),
                          ),
                        ],
                      ]),
                      if (o.value == value)
                        const Positioned(left: 0, right: 0, bottom: 0, child: SizedBox(height: 3, child: DecoratedBox(decoration: BoxDecoration(gradient: HidayahGradients.gilded, borderRadius: BorderRadius.all(Radius.circular(3)))))),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      );
}

// ------------------------------------------------------------------ surfaces
class TCard extends StatelessWidget {
  const TCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color = TC.card, this.highlight = false});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(TC.rLg),
            border: Border.all(color: highlight ? TC.gold : TC.hair),
            boxShadow: TC.shadow,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(TC.rLg),
            child: Padding(padding: padding, child: child),
          ),
        ),
      );
}

/// The night band: slate gradient, faint lattice, gold glow. In the Hedayah
/// skin (ADR-016) it is the identity's night variant, flat ink carrying the
/// Hedayah lattice; its text stays light.
class TNight extends StatelessWidget {
  const TNight({super.key, required this.child, this.radius, this.padding = EdgeInsets.zero});
  final Widget child;
  final BorderRadius? radius;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: radius ?? BorderRadius.zero,
        child: context.isHedayahSkin
            ? ColoredBox(
                color: HedayahSkin.ink,
                child: Stack(children: [
                  const Positioned.fill(child: HedayahPattern(color: Color(0x1FE2C389), step: 28)),
                  Padding(padding: padding, child: child),
                ]),
              )
            : DecoratedBox(
          decoration: const BoxDecoration(gradient: TC.night),
          child: Stack(children: [
            const Positioned.fill(child: HidayahLattice(color: HidayahGold.g200, opacity: .06)),
            const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: HidayahGradients.nightGlow))),
            Padding(padding: padding, child: child),
          ]),
        ),
      );
}

class TEyebrow extends StatelessWidget {
  const TEyebrow(this.text, {super.key, this.onNight = false, this.icon});
  final String text;
  final bool onNight;
  final TGlyph? icon;
  @override
  Widget build(BuildContext context) {
    final c = onNight ? TC.onNightGold : TC.bronze;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[TIcon(icon!, size: 13, color: c), const SizedBox(width: 6)] else ...[
        const SizedBox(width: 28, height: 2, child: DecoratedBox(decoration: BoxDecoration(gradient: HidayahGradients.gilded))),
        const SizedBox(width: 8),
      ],
      Flexible(child: Text(text, style: tBody(13, color: c, weight: FontWeight.w600, height: 1.4))),
    ]);
  }
}

class TSectionHead extends StatelessWidget {
  const TSectionHead(this.title, {super.key, this.count, this.action, this.sub, this.eyebrow});
  final String title;
  final int? count;
  final Widget? action;
  final String? sub, eyebrow;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (eyebrow != null) ...[TEyebrow(eyebrow!), const SizedBox(height: 4)],
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
                Text(title, style: tDisplay(context.wide ? 24 : 19)),
                if (count != null) Text('$count', style: tBody(13, color: TC.muted, weight: FontWeight.w600)),
              ]),
              if (sub != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(sub!, style: tBody(14, color: TC.muted))),
            ]),
          ),
          if (action != null) action!,
        ]),
      );
}

class TPageHead extends StatelessWidget {
  const TPageHead({super.key, this.eyebrow, required this.title, this.subtitle, this.actions = const []});
  final String? eyebrow, subtitle;
  final String title;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (eyebrow != null) ...[TEyebrow(eyebrow!), const SizedBox(height: 6)],
      Text(title, style: tDisplay(context.wide ? 34 : 26)),
      if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(subtitle!, style: tBody(15, color: TC.muted))),
    ]);
    if (actions.isEmpty) return text;
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: text),
        Wrap(spacing: 8, runSpacing: 8, children: actions),
      ],
    );
  }
}

class TEmpty extends StatelessWidget {
  const TEmpty({super.key, this.icon = TGlyph.inbox, required this.title, this.body, this.action, this.ok = false});
  final TGlyph icon;
  final String title;
  final String? body;
  final Widget? action;
  final bool ok;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32), bottom: Radius.circular(10)),
                border: ok ? null : Border.all(color: TC.hair2, width: 1.5),
                color: ok ? TC.successBg : null,
                gradient: ok ? null : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [TC.tint, Color(0x00F6ECD9)]),
              ),
              alignment: Alignment.center,
              child: TIcon(icon, size: 22, color: ok ? TC.successFg : TC.goldIcon),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: tStrong(16)),
            if (body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body!, textAlign: TextAlign.center, style: tBody(14, color: TC.muted))),
            if (action != null) Padding(padding: const EdgeInsets.only(top: 14), child: action!),
          ]),
        ),
      );
}

class TMeter extends StatelessWidget {
  const TMeter({super.key, required this.value, required this.max});
  final int value, max;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Stack(children: [
            const Positioned.fill(child: ColoredBox(color: TC.tint)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: max == 0 ? 0 : (value / max).clamp(0, 1).toDouble(),
              child: const DecoratedBox(decoration: BoxDecoration(gradient: HidayahGradients.meter)),
            ),
          ]),
        ),
      );
}

class TCallout extends StatelessWidget {
  const TCallout({super.key, required this.tone, required this.icon, required this.child, this.action});
  final TTone tone;
  final TGlyph icon;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = toneColors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(TC.r)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 3), child: TIcon(icon, size: 16, color: fg)),
        const SizedBox(width: 10),
        Expanded(child: DefaultTextStyle(style: tBody(14, color: fg, height: 1.6), child: child)),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ]),
    );
  }
}

/// Initials on night slate with the gold ring; a red ring while live.
class TAvatar extends StatelessWidget {
  const TAvatar({super.key, required this.name, this.size = 44, this.ring = true, this.live = false});
  final String name;
  final double size;
  final bool ring, live;
  static final _titles = RegExp(r'^(الشيخ|د\.|أ\.|م\.|Sheikh|Dr\.|Ustadha|Eng\.)\s+');
  @override
  Widget build(BuildContext context) {
    final n = name.replaceFirst(_titles, '').trim();
    final initial = n.isEmpty ? '?' : String.fromCharCode(n.runes.first);
    final core = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(center: Alignment(0, -.4), colors: [HidayahGold.s700, HidayahGold.s900])),
      child: Text(initial, style: tDisplay(size * .42, color: HidayahGold.g300)),
    );
    if (!ring && !live) return core;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: live ? null : HidayahGradients.ring,
        border: live ? Border.all(color: TC.live, width: 2.5) : null,
      ),
      child: core,
    );
  }
}

/// The lesson artwork: a night tile with the lattice, a seal and a word.
class TCover extends StatelessWidget {
  const TCover({super.key, required this.seed, required this.glyph, this.word, this.tags = const [], this.aspect = 16 / 9, this.compact = false});
  final String seed;
  final TGlyph glyph;
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
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: TC.night),
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: RadialGradient(center: Alignment(gx, gy), radius: .9, colors: const [Color(0x61C1923B), Color(0x00C1923B)]))),
          const HidayahLattice(color: HidayahGold.g200, opacity: .1),
          PositionedDirectional(
            end: compact ? 12 : 18,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: compact ? 46 : 64,
                height: compact ? 46 : 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x800B1117),
                  border: Border.all(color: const Color(0x8CE2C389), width: 1.5),
                ),
                alignment: Alignment.center,
                child: TIcon(glyph, size: compact ? 18 : 26, color: HidayahGold.g300, stroke: 1.5),
              ),
            ),
          ),
          if (word != null)
            PositionedDirectional(
              start: 16,
              bottom: 10,
              end: compact ? 70 : 100,
              child: Text(word!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: tDisplay(compact ? 18 : 26, color: const Color(0x4DEDDAB4))),
            ),
          if (tags.isNotEmpty) PositionedDirectional(top: 12, start: 12, child: Wrap(spacing: 6, children: tags)),
        ]),
      ),
    );
  }
}

class TToggleRow extends StatelessWidget {
  const TToggleRow({super.key, required this.label, required this.value, required this.onChanged, this.icon, this.desc, this.enabled = true});
  final String label;
  final String? desc;
  final bool value, enabled;
  final ValueChanged<bool> onChanged;
  final TGlyph? icon;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : .5,
        child: MergeSemantics(
          child: InkWell(
            onTap: enabled ? () => onChanged(!value) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: TIcon(icon!, size: 17, color: TC.goldIcon),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: tBody(14, color: TC.ink, weight: FontWeight.w600, height: 1.4)),
                    if (desc != null && desc!.isNotEmpty) Text(desc!, style: tBody(12.5, color: TC.muted, height: 1.4)),
                  ]),
                ),
                Switch.adaptive(value: value, onChanged: enabled ? onChanged : null, activeTrackColor: TC.gold),
              ]),
            ),
          ),
        ),
      );
}

class TField extends StatelessWidget {
  const TField({super.key, required this.label, required this.child, this.hint, this.required = false});
  final String label;
  final String? hint;
  final bool required;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text.rich(TextSpan(text: label, children: [if (required) const TextSpan(text: ' *', style: TextStyle(color: TC.dangerFg))]),
            style: tBody(13, color: TC.ink2, weight: FontWeight.w700, height: 1.4)),
        const SizedBox(height: 6),
        child,
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: tBody(12.5, color: TC.muted, height: 1.4))),
      ]);
}

InputDecoration tInput({String? hint, Widget? prefix, Widget? suffix}) => InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: TC.card,
      prefixIcon: prefix,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TC.hair2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TC.hair2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: TC.gold, width: 2)),
    );

/// A rounded search box.
class TSearchBox extends StatelessWidget {
  const TSearchBox(
      {super.key, required this.hint, this.controller, this.onChanged, this.onSubmitted, this.onTap, this.readOnly = false, this.trailing});
  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
        height: 46,
        decoration: BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(999), border: Border.all(color: TC.hair)),
        padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
        child: Row(children: [
          const TIcon(TGlyph.search, size: 17, color: TC.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: onSubmitted == null ? null : TextInputAction.search,
              onTap: onTap,
              readOnly: readOnly,
              style: tBody(14, color: TC.ink, height: 1.3),
              // collapsed() clears only `border`; the app theme's enabled and
              // focused outlines would otherwise draw inside the pill.
              decoration: InputDecoration.collapsed(hintText: hint, hintStyle: tBody(14, color: TC.muted, height: 1.3))
                  .copyWith(enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class TStatTiles extends StatelessWidget {
  const TStatTiles(this.items, {super.key, this.big = false});
  final List<(String, String)> items;
  final bool big;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 560 ? items.length : 2;
        final w = (c.maxWidth - (cols - 1) * 10) / cols;
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (final (v, l) in items)
            SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: TC.card, borderRadius: BorderRadius.circular(TC.r), border: Border.all(color: TC.hair)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(v, style: tDisplay(big ? 30 : 24, color: TC.bronze)),
                  Text(l, style: tBody(13, color: TC.muted, height: 1.4)),
                ]),
              ),
            ),
        ]);
      });
}

/// A selectable row (radio-like) for modal choices.
class TOptionRow extends StatelessWidget {
  const TOptionRow({super.key, required this.title, this.subtitle, required this.selected, required this.onTap, this.leading});
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final TGlyph? leading;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              color: selected ? TC.tint : TC.card,
              borderRadius: BorderRadius.circular(TC.r),
              border: Border.all(color: selected ? TC.gold : TC.hair),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(TC.r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  if (leading != null) ...[TIcon(leading!, size: 18, color: TC.goldIcon), const SizedBox(width: 12)] else ...[
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: selected ? TC.gold : TC.hair2, width: 2)),
                      padding: const EdgeInsets.all(3),
                      child: selected ? const DecoratedBox(decoration: BoxDecoration(color: TC.gold, shape: BoxShape.circle)) : null,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: tBody(14, color: TC.ink, weight: FontWeight.w600, height: 1.4)),
                      if (subtitle != null) Text(subtitle!, style: tBody(12.5, color: TC.muted, height: 1.4)),
                    ]),
                  ),
                  if (selected && leading != null) const TIcon(TGlyph.check, size: 18, color: TC.bronze),
                ]),
              ),
            ),
          ),
        ),
      );
}

/// A sheet on phones, a dialog on wide screens.
Future<T?> showTModal<T>(BuildContext context,
    {required String title, String? subtitle, required WidgetBuilder body, List<Widget> Function(BuildContext)? footer, bool wide = false}) {
  Widget frame(BuildContext ctx, {required bool sheet}) => Directionality(
        textDirection: Directionality.of(context),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (sheet)
            Center(
              child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: TC.hair2, borderRadius: BorderRadius.circular(3))),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 8, 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: tStrong(18)),
                  if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text(subtitle, style: tBody(13, color: TC.muted, height: 1.4))),
                ]),
              ),
              TIconButton(TGlyph.x, tooltip: 'lessons.close'.tr(), onPressed: () => Navigator.of(ctx).pop()),
            ]),
          ),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), child: body(ctx))),
          if (footer != null)
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, sheet ? 12 + MediaQuery.paddingOf(ctx).bottom : 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.hair))),
              child: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: footer(ctx)),
            ),
        ]),
      );
  if (context.wide || MediaQuery.sizeOf(context).width >= 720) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: TC.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TC.rXl)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 860 : 560, maxHeight: MediaQuery.sizeOf(ctx).height * .9),
          child: frame(ctx, sheet: false),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: TC.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .88), child: frame(ctx, sheet: true)),
    ),
  );
}

/// Asks a guest to sign in, explaining why.
Future<void> showTSignIn(BuildContext context, String why) => showTModal<void>(
      context,
      title: 'lessons.sign_in_title'.tr(),
      subtitle: why,
      body: (ctx) => Text('lessons.sign_in_note'.tr(), style: tBody(14, color: TC.muted)),
      footer: (ctx) => [
        TButton('lessons.sign_in'.tr(), kind: TBtn.minted, icon: TGlyph.user, onPressed: () {
          Navigator.of(ctx).pop();
          openSignIn(context);
        }),
      ],
    );

/// Centres content in the page column with the right gutter.
class TPage extends StatelessWidget {
  const TPage({super.key, required this.children, this.narrow = false, this.top = 0});
  final List<Widget> children;
  final bool narrow;
  final double top;
  @override
  Widget build(BuildContext context) {
    final wide = context.wide;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: narrow ? 820 : 1280),
        child: Padding(
          padding: EdgeInsets.fromLTRB(wide ? 40 : 16, top + (wide ? 28 : 16), wide ? 40 : 16, wide ? 56 : 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(height: wide ? 28 : 20),
              children[i],
            ]
          ]),
        ),
      ),
    );
  }
}

/// A two-up grid that falls to one column on narrow screens.
class TGrid extends StatelessWidget {
  const TGrid({super.key, required this.children, this.minWidth = 300, this.spacing = 16});
  final List<Widget> children;
  final double minWidth, spacing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = (c.maxWidth / minWidth).floor().clamp(1, 4);
        final w = (c.maxWidth - (cols - 1) * spacing) / cols;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [for (final x in children) SizedBox(width: w, child: x)]);
      });
}

String tPlural(String key, int n) => 'lessons.n.$key'.plural(n);

/// Numbered steps; finished ones show a tick.
class TStepper extends StatelessWidget {
  const TStepper({super.key, required this.labels, required this.current, this.onTap});
  final List<String> labels;
  final int current;
  final ValueChanged<int>? onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: onTap == null || i >= current ? null : () => onTap!(i),
              child: Column(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: i == current ? HidayahGradients.minted : (i < current ? HidayahGradients.selected : null),
                    color: i > current ? TC.tint : null,
                  ),
                  child: i < current
                      ? const TIcon(TGlyph.check, size: 14, color: HidayahGold.g200, stroke: 2.6)
                      : Text('${i + 1}', style: tStrong(13, color: TC.ink)),
                ),
                const SizedBox(height: 4),
                Text(labels[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tBody(12, color: i == current ? TC.ink : TC.muted, weight: FontWeight.w600, height: 1.3)),
              ]),
            ),
          ),
      ]);
}
