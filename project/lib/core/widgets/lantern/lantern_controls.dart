import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import 'lantern_base.dart';

/// What a control is doing right now, for its builder.
typedef LPressState = ({bool hovered, bool pressed, bool focused});

/// The kit's keyboard focus mark: a gap in the page colour, then a gold ink
/// ring, both drawn outside [child]'s edge so they never cover it.
class LFocusRing extends StatelessWidget implements LanternSkinWidget {
  const LFocusRing(
      {super.key,
      required this.visible,
      required this.child,
      this.radius = Lantern.radiusPill});

  final bool visible;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return CustomPaint(
        foregroundPainter: visible
            ? _FocusRingPainter(gap: t.bg, ink: t.goldInk, radius: radius)
            : null,
        child: child);
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter(
      {required this.gap, required this.ink, required this.radius});

  final Color gap, ink;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final limit = size.shortestSide / 2;
    RRect ring(double outset) => RRect.fromRectAndRadius(box.inflate(outset),
        Radius.circular(math.min(radius, limit) + outset));
    canvas
      ..drawRRect(
          ring(1.5),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = gap)
      ..drawRRect(
          ring(4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ink);
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.gap != gap || old.ink != ink || old.radius != radius;
}

/// Hover, press and keyboard focus for one tappable thing. The kit's controls
/// are built on it so they all answer input the same way: a lift on hover, a
/// 160 ms press, and a two-ring focus mark that is never removed.
class LPressable extends StatefulWidget implements LanternSkinWidget {
  const LPressable(
      {super.key,
      required this.builder,
      this.onTap,
      this.onLongPress,
      this.radius = Lantern.radiusPill,
      this.pressScale = .97,
      this.focusRing = true,
      this.label,
      this.button = true,
      this.selected,
      this.toggled,
      this.excludeChildSemantics = false,
      this.cursor});

  final Widget Function(BuildContext context, LPressState state) builder;
  final VoidCallback? onTap, onLongPress;
  final double radius, pressScale;
  final bool focusRing, button, excludeChildSemantics;
  final String? label;
  final bool? selected, toggled;
  final MouseCursor? cursor;

  @override
  State<LPressable> createState() => _LPressableState();
}

class _LPressableState extends State<LPressable> {
  bool _hovered = false, _pressed = false, _focused = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  void _set(void Function() change) {
    if (mounted) setState(change);
  }

  @override
  Widget build(BuildContext context) {
    final calm = Lantern.calm(context);
    Widget child = widget.builder(context,
        (hovered: _hovered && _enabled, pressed: _pressed, focused: _focused));
    if (widget.focusRing) {
      child = LFocusRing(
          visible: _focused, radius: widget.radius, child: child);
    }
    return Semantics(
        button: widget.button,
        enabled: _enabled,
        label: widget.label,
        selected: widget.selected,
        toggled: widget.toggled,
        excludeSemantics: widget.excludeChildSemantics,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: FocusableActionDetector(
            enabled: _enabled,
            mouseCursor: widget.cursor ??
                (_enabled ? SystemMouseCursors.click : MouseCursor.defer),
            onShowHoverHighlight: (v) => _set(() => _hovered = v),
            onShowFocusHighlight: (v) => _set(() => _focused = v),
            actions: {
              ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) => widget.onTap?.call()),
            },
            child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapDown: _enabled ? (_) => _set(() => _pressed = true) : null,
                onTapUp: (_) => _set(() => _pressed = false),
                onTapCancel: () => _set(() => _pressed = false),
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: AnimatedScale(
                    scale: _pressed && !calm ? widget.pressScale : 1,
                    duration: calm ? Lantern.none : Lantern.press,
                    curve: Lantern.ease,
                    child: child))));
  }
}

enum LButtonKind { primary, secondary, tonal, ghost, danger, dark }

enum LButtonSize { small, medium, large }

/// The Lantern button: a pill. The main action is minted gold with ink text;
/// a light sweeps across it on hover and the star turns while it loads.
class LButton extends StatelessWidget implements LanternSkinWidget {
  const LButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.kind = LButtonKind.primary,
      this.size = LButtonSize.medium,
      this.icon,
      this.trailing,
      this.loading = false,
      this.expand = false});

  final String label;
  final VoidCallback? onPressed;
  final LButtonKind kind;
  final LButtonSize size;
  final LGlyph? icon, trailing;
  final bool loading, expand;

  static ({double height, double pad, double font}) metrics(LButtonSize s) =>
      switch (s) {
        LButtonSize.small => (height: 36, pad: 16, font: 13.5),
        LButtonSize.medium => (height: 46, pad: 22, font: 15),
        LButtonSize.large => (height: 54, pad: 30, font: 16.5),
      };

  static Color foreground(LButtonKind kind, LanternTokens t, bool hovered) =>
      switch (kind) {
        LButtonKind.primary => LanternTokens.onGold,
        LButtonKind.secondary => hovered ? t.bg : t.fg,
        LButtonKind.tonal || LButtonKind.ghost => t.goldInk,
        LButtonKind.danger => LanternTokens.white,
        LButtonKind.dark => LanternTokens.goldHi,
      };

  static BoxDecoration decoration(
      LButtonKind kind, LanternTokens t, LPressState s, bool enabled) {
    final radius = BorderRadius.circular(Lantern.radiusPill);
    if (!enabled) return BoxDecoration(color: t.sunk, borderRadius: radius);
    return switch (kind) {
      LButtonKind.primary => BoxDecoration(
          gradient: Lantern.goldFill,
          borderRadius: radius,
          boxShadow: [
            const BoxShadow(
                color: Color(0x66805B1B), blurRadius: 2, offset: Offset(0, 1)),
            BoxShadow(
                color: Color(s.hovered ? 0xD9BD933F : 0xB3BD933F),
                blurRadius: s.hovered ? 24 : 16,
                spreadRadius: -6,
                offset: Offset(0, s.hovered ? 14 : 8)),
          ]),
      LButtonKind.secondary => BoxDecoration(
          color: s.pressed
              ? t.sunk
              : s.hovered
                  ? t.fg
                  : Colors.transparent,
          borderRadius: radius,
          border: Border.all(color: t.fg, width: 1.5)),
      LButtonKind.tonal => BoxDecoration(
          color: s.hovered ? t.line : t.sunk,
          borderRadius: radius,
          border: Border.all(
              color: s.hovered ? LanternTokens.gold : t.line, width: 1)),
      LButtonKind.ghost => BoxDecoration(
          color: s.pressed
              ? t.line
              : s.hovered
                  ? t.sunk
                  : Colors.transparent,
          borderRadius: radius),
      LButtonKind.danger => BoxDecoration(
          gradient: Lantern.dangerFill,
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
                color: Color(s.hovered ? 0xD9A31F30 : 0xB3A31F30),
                blurRadius: s.hovered ? 24 : 16,
                spreadRadius: -6,
                offset: Offset(0, s.hovered ? 14 : 8)),
          ]),
      LButtonKind.dark => BoxDecoration(
          gradient: Lantern.darkFill,
          borderRadius: radius,
          boxShadow: const [
            BoxShadow(
                color: Color(0x99000000),
                blurRadius: 16,
                spreadRadius: -8,
                offset: Offset(0, 8)),
          ]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final enabled = onPressed != null && !loading;
    final m = metrics(size);
    return LPressable(
        onTap: enabled ? onPressed : null,
        label: label,
        excludeChildSemantics: true,
        builder: (context, s) {
          final lit = enabled || loading;
          final fg = lit ? foreground(kind, t, s.hovered) : t.faint;
          final lift =
              s.hovered && !s.pressed && kind != LButtonKind.ghost ? -1.0 : 0.0;
          return AnimatedContainer(
              duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
              curve: Lantern.ease,
              transform: Matrix4.translationValues(0, lift, 0),
              constraints: BoxConstraints(
                  minHeight: m.height,
                  minWidth: expand ? double.infinity : 0),
              decoration: decoration(kind, t, s, lit),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(Lantern.radiusPill),
                  child: Stack(alignment: Alignment.center, children: [
                    if (lit &&
                        (kind == LButtonKind.primary ||
                            kind == LButtonKind.danger ||
                            kind == LButtonKind.dark))
                      // The minted top edge catches the light.
                      PositionedDirectional(
                          top: 0,
                          start: 0,
                          end: 0,
                          height: 1,
                          child: ColoredBox(
                              color: LanternTokens.white.withValues(
                                  alpha:
                                      kind == LButtonKind.primary ? .5 : .2))),
                    if (lit && kind == LButtonKind.primary)
                      Positioned.fill(child: _Sweep(run: s.hovered)),
                    Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: m.pad, vertical: 8),
                        child: Opacity(
                            opacity: loading ? 0 : 1,
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (icon != null) ...[
                                    LIcon(icon!,
                                        size: m.font * 1.2, color: fg),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                      child: Text(label,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: Lantern.textStyle(m.font,
                                              color: fg,
                                              weight: FontWeight.w600,
                                              height: 1.25))),
                                  if (trailing != null) ...[
                                    const SizedBox(width: 8),
                                    LIcon(trailing!,
                                        size: m.font * 1.2, color: fg),
                                  ],
                                ]))),
                    if (loading) LStarLoader(size: 20, color: fg),
                  ])));
        });
  }
}

/// The white light that crosses a gold button once when the pointer arrives.
class _Sweep extends StatefulWidget {
  const _Sweep({required this.run});
  final bool run;

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Lantern.sweep);

  @override
  void didUpdateWidget(_Sweep old) {
    super.didUpdateWidget(old);
    if (widget.run && !old.run && !Lantern.calm(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => _c.isAnimating
              ? FractionalTranslation(
                  translation: Offset(
                      -1.3 + 2.6 * Lantern.ease.transform(_c.value), 0),
                  child: const DecoratedBox(
                      decoration: BoxDecoration(
                          gradient: LinearGradient(
                              begin: Alignment(-1, -.4),
                              end: Alignment(1, .4),
                              stops: [.35, .5, .65],
                              colors: [
                        Color(0x00FFFFFF),
                        Color(0x99FFFFFF),
                        Color(0x00FFFFFF)
                      ]))))
              : const SizedBox.shrink()));
}

/// Press and hold to confirm: go live, end a broadcast, ban, delete an
/// account. A fill grows from the start edge for [Lantern.hold]; letting go
/// early cancels. Space or Enter held works the same from the keyboard, and
/// screen readers get it as one long-press action. The hold keeps its length
/// under calm motion: it is input, not decoration.
class LHoldButton extends StatefulWidget implements LanternSkinWidget {
  const LHoldButton(
      {super.key,
      required this.label,
      required this.onConfirmed,
      this.kind = LButtonKind.danger,
      this.size = LButtonSize.medium,
      this.icon,
      this.enabled = true,
      this.loading = false,
      this.expand = false});

  final String label;
  final VoidCallback onConfirmed;
  final LButtonKind kind;
  final LButtonSize size;
  final LGlyph? icon;
  final bool enabled, loading, expand;

  @override
  State<LHoldButton> createState() => _LHoldButtonState();
}

class _LHoldButtonState extends State<LHoldButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fill = AnimationController(
      vsync: this,
      duration: Lantern.hold,
      reverseDuration: const Duration(milliseconds: 220),
      animationBehavior: AnimationBehavior.preserve);
  final _focus = FocusNode();
  Timer? _deadline;
  bool _holding = false, _focused = false, _hovered = false;
  int? _pointer;
  LogicalKeyboardKey? _key;

  bool get _enabled => widget.enabled && !widget.loading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  @override
  void didUpdateWidget(LHoldButton old) {
    super.didUpdateWidget(old);
    if (!_enabled) _cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deadline?.cancel();
    _fill.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _start() {
    if (!_enabled || _holding) return;
    setState(() => _holding = true);
    _fill.forward(from: 0);
    // The timer, not the animation's last frame, decides: input timing must
    // not depend on rendering.
    _deadline = Timer(Lantern.hold, () {
      if (!mounted || !_holding || !_enabled) return;
      _holding = false;
      _pointer = null;
      _key = null;
      HapticFeedback.mediumImpact();
      _fill.value = 0;
      setState(() {});
      widget.onConfirmed();
    });
  }

  void _cancel() {
    _deadline?.cancel();
    _deadline = null;
    _pointer = null;
    _key = null;
    if (!_holding) return;
    if (mounted) setState(() => _holding = false);
    _fill.reverse();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled ||
        ![LogicalKeyboardKey.space, LogicalKeyboardKey.enter]
            .contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent && !_holding) {
      _key = event.logicalKey;
      _start();
    }
    if (event is KeyUpEvent && _key == event.logicalKey) _cancel();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final m = LButton.metrics(widget.size);
    final lit = _enabled || widget.loading;
    final state =
        (hovered: _hovered && _enabled, pressed: _holding, focused: _focused);
    final fg = lit ? LButton.foreground(widget.kind, t, false) : t.faint;
    return Semantics(
        button: true,
        enabled: _enabled,
        label: widget.label,
        hint: 'lantern.hold_hint'.tr(),
        excludeSemantics: true,
        onLongPress: _enabled ? widget.onConfirmed : null,
        customSemanticsActions: _holding
            ? {
                CustomSemanticsAction(label: 'lantern.hold_cancel'.tr()):
                    _cancel
              }
            : null,
        child: Focus(
            focusNode: _focus,
            canRequestFocus: _enabled,
            onKeyEvent: _onKey,
            onFocusChange: (v) {
              setState(() => _focused = v);
              if (!v) _cancel();
            },
            child: MouseRegion(
                cursor:
                    _enabled ? SystemMouseCursors.click : MouseCursor.defer,
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: (e) {
                      if (_holding || !_enabled) return;
                      _pointer = e.pointer;
                      _focus.requestFocus();
                      _start();
                    },
                    onPointerMove: (e) {
                      final box = context.findRenderObject() as RenderBox?;
                      if (e.pointer == _pointer &&
                          box != null &&
                          !(Offset.zero & box.size)
                              .contains(box.globalToLocal(e.position))) {
                        _cancel();
                      }
                    },
                    onPointerUp: (e) {
                      if (e.pointer == _pointer) _cancel();
                    },
                    onPointerCancel: (e) {
                      if (e.pointer == _pointer) _cancel();
                    },
                    // The ring marks keyboard focus only. A finger on the
                    // button also takes focus (so Space can follow), and
                    // the ring once covered the label and the fill then.
                    child: LFocusRing(
                        visible: _focused &&
                            FocusManager.instance.highlightMode ==
                                FocusHighlightMode.traditional,
                        radius: Lantern.radiusPill,
                        child: Container(
                            constraints: BoxConstraints(
                                minHeight: m.height,
                                minWidth: widget.expand ? double.infinity : 0),
                            decoration:
                                LButton.decoration(widget.kind, t, state, lit),
                            child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(Lantern.radiusPill),
                                child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Positioned.fill(
                                          child: AnimatedBuilder(
                                              animation: _fill,
                                              builder: (context, _) => Align(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerStart,
                                                  child: FractionallySizedBox(
                                                      widthFactor: _fill.value,
                                                      heightFactor: 1,
                                                      child: const ColoredBox(
                                                          color: Color(
                                                              0x47FFFFFF)))))),
                                      Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: m.pad, vertical: 8),
                                          child: Opacity(
                                              opacity: widget.loading ? 0 : 1,
                                              child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    if (widget.icon !=
                                                        null) ...[
                                                      LIcon(widget.icon!,
                                                          size: m.font * 1.2,
                                                          color: fg),
                                                      const SizedBox(width: 8),
                                                    ],
                                                    Flexible(
                                                        child: Text(
                                                            widget.label,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: Lantern
                                                                .textStyle(
                                                                    m.font,
                                                                    color: fg,
                                                                    weight:
                                                                        FontWeight
                                                                            .w600,
                                                                    height:
                                                                        1.25))),
                                                  ]))),
                                      if (widget.loading)
                                        LStarLoader(size: 20, color: fg),
                                    ]))))))));
  }
}

/// A round 44 px icon button. [glass] sits on video; [on] marks a toggle
/// that is switched on (gold edge and a small star); [dot] is an unread mark.
class LIconButton extends StatelessWidget implements LanternSkinWidget {
  const LIconButton(
      {super.key,
      required this.icon,
      required this.label,
      this.onPressed,
      this.glass = false,
      this.on = false,
      this.dot = false,
      this.size = Lantern.target,
      this.iconSize = 20,
      this.color});

  final LGlyph icon;
  final String label;
  final VoidCallback? onPressed;
  final bool glass, on, dot;
  final double size, iconSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: LPressable(
            onTap: onPressed,
            label: label,
            toggled: on ? true : null,
            pressScale: .9,
            excludeChildSemantics: true,
            builder: (context, s) {
              final fg = onPressed == null
                  ? t.faint
                  : glass
                      ? LanternTokens.white
                      : on
                          ? t.goldInk
                          : color ?? t.fg;
              return AnimatedContainer(
                  duration:
                      Lantern.calm(context) ? Lantern.none : Lantern.state,
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: glass
                          ? Color(s.hovered ? 0xB80B1117 : 0x800B1117)
                          : s.pressed
                              ? t.line
                              : s.hovered || on
                                  ? t.sunk
                                  : Colors.transparent,
                      border: on && !glass
                          ? Border.all(color: LanternTokens.gold, width: 1.5)
                          : null),
                  child: Stack(alignment: Alignment.center, children: [
                    LIcon(icon, size: iconSize, color: fg),
                    if (on && !glass)
                      const PositionedDirectional(
                          top: 4, end: 4, child: LStar(size: 9)),
                    if (dot)
                      PositionedDirectional(
                          top: size * .18,
                          end: size * .2,
                          child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                  color: t.live,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: glass
                                          ? LanternTokens.nightGround
                                          : t.bg,
                                      width: 2)))),
                  ]));
            }));
  }
}

/// A filter chip. Selected, gold floods it from the start edge.
class LChip extends StatelessWidget implements LanternSkinWidget {
  const LChip(
      {super.key,
      required this.label,
      this.selected = false,
      this.onTap,
      this.icon,
      this.count,
      this.onRemove,
      this.dense = false});

  final String label;
  final bool selected, dense;
  final VoidCallback? onTap, onRemove;
  final LGlyph? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final fg = selected ? LanternTokens.onGold : t.fg;
    return Opacity(
        opacity: onTap == null && !selected ? .55 : 1,
        child: LPressable(
            onTap: onTap,
            label: count == null ? label : '$label, $count',
            selected: selected,
            pressScale: .95,
            excludeChildSemantics: true,
            builder: (context, s) => AnimatedContainer(
                duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
                constraints: BoxConstraints(minHeight: dense ? 32 : 38),
                transform: Matrix4.translationValues(
                    0, s.hovered && !s.pressed ? -1 : 0, 0),
                decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(Lantern.radiusPill),
                    border: Border.all(
                        color: selected || s.hovered
                            ? LanternTokens.gold
                            : t.line)),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(Lantern.radiusPill),
                    child: Stack(children: [
                      Positioned.fill(
                          child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: AnimatedFractionallySizedBox(
                                  duration: Lantern.calm(context)
                                      ? Lantern.none
                                      : const Duration(milliseconds: 280),
                                  curve: Lantern.ease,
                                  widthFactor: selected ? 1 : 0,
                                  heightFactor: 1,
                                  child: const DecoratedBox(
                                      decoration: BoxDecoration(
                                          gradient: Lantern.goldFill))))),
                      Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: dense ? 12 : 16, vertical: 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (icon != null) ...[
                              LIcon(icon!, size: 16, color: fg),
                              const SizedBox(width: 7),
                            ],
                            Flexible(
                                child: Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Lantern.textStyle(dense ? 13 : 14,
                                        color: fg,
                                        weight: FontWeight.w500,
                                        height: 1.3))),
                            if (count != null) ...[
                              const SizedBox(width: 7),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: selected
                                          ? const Color(0x24151D24)
                                          : t.sunk,
                                      borderRadius: BorderRadius.circular(
                                          Lantern.radiusPill)),
                                  child: Text('$count',
                                      style: Lantern.textStyle(12,
                                              color: selected
                                                  ? LanternTokens.onGold
                                                  : t.goldInk,
                                              weight: FontWeight.w600,
                                              height: 1.2)
                                          .copyWith(
                                              fontFeatures: Lantern.tabular))),
                            ],
                            if (onRemove != null) ...[
                              const SizedBox(width: 4),
                              GestureDetector(
                                  onTap: onRemove,
                                  child: LIcon(LGlyph.close,
                                      size: 14,
                                      color: fg.withValues(alpha: .6))),
                            ],
                          ])),
                    ])))));
  }
}

/// Segmented tabs with a gold thumb that slides to the chosen one.
class LSegmented<T> extends StatelessWidget implements LanternSkinWidget {
  const LSegmented(
      {super.key,
      required this.segments,
      required this.value,
      required this.onChanged,
      this.expand = false,
      this.dense = false});

  final List<({T value, String label, LGlyph? icon})> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool expand, dense;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final index = segments.indexWhere((s) => s.value == value);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final n = segments.length;
    // Alignment of the thumb across equal slots, mirrored for Arabic.
    final slot = n <= 1 ? 0.0 : -1 + 2 * (index < 0 ? 0 : index) / (n - 1);
    final track = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: t.sunk,
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            border: Border.all(color: t.line)),
        child: Stack(children: [
          if (index >= 0)
            Positioned.fill(
                child: AnimatedAlign(
                    duration: Lantern.calm(context)
                        ? Lantern.none
                        : const Duration(milliseconds: 320),
                    curve: Lantern.ease,
                    alignment: Alignment(rtl ? -slot : slot, 0),
                    child: FractionallySizedBox(
                        widthFactor: 1 / n,
                        heightFactor: 1,
                        child: const DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: Lantern.goldFill,
                                borderRadius: BorderRadius.all(
                                    Radius.circular(Lantern.radiusPill)),
                                boxShadow: [
                              BoxShadow(
                                  color: Color(0xCCBD933F),
                                  blurRadius: 10,
                                  spreadRadius: -3,
                                  offset: Offset(0, 4))
                            ]))))),
          Row(mainAxisSize: MainAxisSize.max, children: [
            for (final s in segments)
              Expanded(
                  child: LPressable(
                      onTap: () => onChanged(s.value),
                      label: s.label,
                      selected: s.value == value,
                      pressScale: .95,
                      focusRing: false,
                      excludeChildSemantics: true,
                      builder: (context, state) {
                        final on = s.value == value;
                        final fg = on
                            ? LanternTokens.onGold
                            : state.hovered || state.focused
                                ? t.fg
                                : t.muted;
                        return Container(
                            constraints:
                                BoxConstraints(minHeight: dense ? 32 : 38),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: state.focused
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        Lantern.radiusPill),
                                    border: Border.all(
                                        color: t.goldInk, width: 2))
                                : null,
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (s.icon != null) ...[
                                    LIcon(s.icon!, size: 16, color: fg),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                      child: Text(s.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Lantern.textStyle(
                                              dense ? 13 : 14,
                                              color: fg,
                                              weight: FontWeight.w600,
                                              height: 1.3))),
                                ]));
                      })),
          ]),
        ]));
    return expand ? track : IntrinsicWidth(child: track);
  }
}

/// The Lantern switch: on, the thumb shows the star.
class LSwitch extends StatelessWidget implements LanternSkinWidget {
  const LSwitch(
      {super.key, required this.value, this.onChanged, required this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// For screen readers; the visible text sits beside the switch.
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final calm = Lantern.calm(context);
    return Opacity(
        opacity: onChanged == null ? .4 : 1,
        child: LPressable(
            onTap: onChanged == null ? null : () => onChanged!(!value),
            label: label,
            toggled: value,
            button: false,
            pressScale: 1,
            excludeChildSemantics: true,
            builder: (context, s) => AnimatedContainer(
                duration: calm ? Lantern.none : Lantern.state,
                width: 54,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: value ? null : t.line,
                    gradient: value ? Lantern.goldFill : null,
                    borderRadius: BorderRadius.circular(Lantern.radiusPill),
                    boxShadow: s.hovered
                        ? [BoxShadow(color: t.glow, spreadRadius: 4)]
                        : null),
                child: AnimatedAlign(
                    duration:
                        calm ? Lantern.none : const Duration(milliseconds: 300),
                    curve: Lantern.ease,
                    alignment: value
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                            color: LanternTokens.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Color(0x4D000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 2))
                            ]),
                        child: AnimatedOpacity(
                            duration: calm ? Lantern.none : Lantern.state,
                            opacity: value ? 1 : 0,
                            child: const LStar(size: 14)))))));
  }
}

/// A text field in the Lantern shape: 16 px corners (or a pill), a leading
/// icon that turns gold with focus, and the error line under it.
class LField extends StatelessWidget implements LanternSkinWidget {
  const LField(
      {super.key,
      this.controller,
      this.focusNode,
      this.hint,
      this.label,
      this.icon,
      this.error,
      this.helper,
      this.pill = false,
      this.enabled = true,
      this.obscure = false,
      this.maxLines = 1,
      this.minLines,
      this.maxLength,
      this.keyboardType,
      this.textInputAction,
      this.inputFormatters,
      this.onChanged,
      this.onSubmitted,
      this.trailing,
      this.autofocus = false,
      this.textDirection});

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint, label, error, helper;
  final LGlyph? icon;
  final bool pill, enabled, obscure, autofocus;
  final int? maxLines, minLines, maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Widget? trailing;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final radius =
        BorderRadius.circular(pill ? Lantern.radiusPill : Lantern.radiusField);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: radius, borderSide: BorderSide(color: color, width: 1.5));
    final bad = error != null;
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
          TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              obscureText: obscure,
              autofocus: autofocus,
              maxLines: obscure ? 1 : maxLines,
              minLines: minLines,
              maxLength: maxLength,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textDirection: textDirection,
              cursorColor: t.goldInk,
              style: Lantern.textStyle(15, color: t.fg, height: 1.35),
              decoration: InputDecoration(
                  hintText: hint,
                  counterText: '',
                  filled: true,
                  fillColor: enabled ? t.surface : t.sunk,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: pill ? 18 : 16, vertical: 14),
                  prefixIcon: icon == null
                      ? null
                      : Padding(
                          padding: const EdgeInsetsDirectional.only(
                              start: 14, end: 8),
                          child: LIcon(icon!,
                              size: 18, color: bad ? t.live : t.faint)),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: trailing,
                  border: border(t.line),
                  enabledBorder: border(bad ? t.live : t.line),
                  disabledBorder: border(t.line),
                  focusedBorder: border(bad ? t.live : LanternTokens.gold))),
          if (bad || helper != null)
            Padding(
                padding: const EdgeInsetsDirectional.only(top: 6, start: 2),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (bad) ...[
                        Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: LIcon(LGlyph.warn,
                                size: 14, color: t.liveText)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                          child: Text(error ?? helper!,
                              style: Lantern.textStyle(12.5,
                                  color: bad ? t.liveText : t.muted,
                                  weight: FontWeight.w500,
                                  height: 1.35))),
                    ])),
        ]);
  }
}
