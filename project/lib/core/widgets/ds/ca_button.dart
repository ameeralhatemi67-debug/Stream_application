import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import '../../theme/app_theme.dart';
import 'ca_icon.dart';
import 'canopy_content_motion.dart';

enum CaButtonVariant { primary, secondary, text, destructive }

/// A hold is deliberate input: it keeps its 1.2s duration under reduced motion.
class CaButton extends StatefulWidget {
  const CaButton(
      {super.key,
      required this.label,
      this.onPressed,
      this.variant = CaButtonVariant.primary,
      this.icon,
      this.trailingIcon,
      this.loading = false,
      this.holdToConfirm = false,
      this.confirm = false,
      this.bareTrailing = false});
  final String label;

  /// Trailing icon without the circular badge behind it.
  final bool bareTrailing;
  final VoidCallback? onPressed;
  final CaButtonVariant variant;
  final CaGlyph? icon, trailingIcon;
  final bool loading, holdToConfirm, confirm;
  @override
  State<CaButton> createState() => _CaButtonState();
}

class _CaButtonState extends State<CaButton>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: CanopyMotion.holdToEnd,
    reverseDuration: CanopyMotion.holdRelease,
    animationBehavior: AnimationBehavior.preserve,
  );
  Timer? _deadline;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _cancel();
  }

  final _focus = FocusNode();
  bool _pressed = false, _focused = false, _holding = false, _completed = false;
  int? _pointer;
  LogicalKeyboardKey? _key;
  bool get _enabled => widget.onPressed != null && !widget.loading;
  void _start() {
    if (!_enabled || _holding) return;
    _holding = true;
    _completed = false;
    setState(() => _pressed = true);
    _hold.forward(from: 0);
    // Input timing must not depend on AnimationStatus's next rendered frame.
    _deadline = Timer(CanopyMotion.holdToEnd, () {
      if (mounted && _holding && _enabled && !_completed) {
        _completed = true;
        widget.onPressed!();
      }
    });
  }

  void _cancel() {
    if (!_holding && !_pressed) return;
    _deadline?.cancel();
    _deadline = null;
    _holding = false;
    _pointer = null;
    _key = null;
    if (mounted) setState(() => _pressed = false);
    _hold.reverse();
  }

  @override
  void didUpdateWidget(CaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled || widget.holdToConfirm != oldWidget.holdToConfirm) _cancel();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deadline?.cancel();
    _hold.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_enabled ||
        !widget.holdToConfirm ||
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
    final reduced = CanopyMotion.reduced(context);
    final active = _enabled || widget.loading;
    final primary = widget.variant == CaButtonVariant.primary;
    final destructive = widget.variant == CaButtonVariant.destructive;
    final text = widget.variant == CaButtonVariant.text;
    final foreground = !active
        ? Canopy.slate
        : primary || destructive
            ? Canopy.paper
            : Canopy.brandGreen;
    final label = Row(mainAxisSize: MainAxisSize.min, children: [
      if (widget.icon != null) ...[
        if (widget.confirm)
          CanopyCheckDraw(
              child: CaIcon(widget.icon!,
                  color: foreground, size: CanopySize.inlineIcon))
        else
          CaIcon(widget.icon!, color: foreground, size: CanopySize.inlineIcon),
        const SizedBox(width: AppTheme.spaceSm),
      ],
      Flexible(
          child: Text(widget.label,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: foreground))),
      if (widget.trailingIcon != null) ...[
        const SizedBox(width: AppTheme.spaceSm),
        Container(
            padding: const EdgeInsets.all(AppTheme.spaceXs),
            decoration: widget.bareTrailing
                ? null
                : BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        Canopy.paper.withValues(alpha: CanopySize.glassAlpha)),
            child: CaIcon(widget.trailingIcon!,
                color: foreground, size: CanopySize.inlineIcon)),
      ],
    ]);
    Widget content = AnimatedBuilder(
        animation: _hold,
        builder: (context, _) => Container(
              constraints: const BoxConstraints(minHeight: CanopySize.target),
              decoration: BoxDecoration(
                color: !active
                    ? Canopy.mint
                    : destructive
                        ? Canopy.liveCrimson
                        : primary || text
                            ? null
                            : Canopy.mint,
                gradient: active && primary ? AppGradients.pill : null,
                borderRadius: BorderRadius.circular(CanopyRadius.pill),
                border: !primary && !destructive && !text
                    ? Border.all(color: Canopy.mist)
                    : null,
                boxShadow: active && primary ? CanopyShadow.pill : null,
              ),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(CanopyRadius.pill),
                  child: Stack(alignment: Alignment.center, children: [
                    if (active && primary)
                      PositionedDirectional(
                          top: CanopySize.stroke,
                          start: AppTheme.spaceXl,
                          end: AppTheme.spaceXl,
                          height: CanopySize.stroke,
                          child: ColoredBox(
                              color: Canopy.paper.withValues(
                                  alpha: CanopySize.highlightAlpha))),
                    if (widget.holdToConfirm)
                      Positioned.fill(
                          child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FractionallySizedBox(
                            widthFactor: _hold.value,
                            heightFactor: 1,
                            child: ColoredBox(
                                color: Canopy.paper
                                    .withValues(alpha: CanopySize.glassAlpha))),
                      )),
                    Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppTheme.spaceXl,
                            vertical: AppTheme.spaceMd),
                        child: TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: widget.loading ? 0 : 1,
                                end: widget.loading ? 0 : 1),
                            duration: reduced
                                ? CanopyMotion.none
                                : CanopyMotion.buttonState,
                            curve: CanopyMotion.easeOut,
                            child: label,
                            builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: ImageFiltered(
                                    enabled: !reduced && value < 1,
                                    imageFilter: ImageFilter.blur(
                                        sigmaX:
                                            CanopySize.stateBlur * (1 - value),
                                        sigmaY:
                                            CanopySize.stateBlur * (1 - value)),
                                    child: child)))),
                    AnimatedOpacity(
                        opacity: widget.loading ? 1 : 0,
                        duration: reduced
                            ? CanopyMotion.none
                            : CanopyMotion.buttonState,
                        curve: CanopyMotion.easeOut,
                        child: TickerMode(
                            enabled: widget.loading && !reduced,
                            child: SizedBox.square(
                                dimension: CanopySize.buttonRing,
                                child: CircularProgressIndicator(
                                    strokeWidth: CanopySize.ring,
                                    backgroundColor: (primary || destructive
                                            ? Canopy.paper
                                            : Canopy.brandGreen)
                                        .withValues(
                                            alpha: CanopySize.highlightAlpha),
                                    color: primary || destructive
                                        ? Canopy.paper
                                        : Canopy.brandGreen)))),
                  ])),
            ));
    content = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CanopyRadius.pill),
            border: _focused
                ? Border.all(
                    color: active && (primary || destructive)
                        ? Canopy.paper
                        : Canopy.brandGreen,
                    width: CanopySize.focusWidth)
                : null),
        child: content);
    if (widget.holdToConfirm) {
      content = Focus(
          focusNode: _focus,
          canRequestFocus: _enabled,
          onKeyEvent: _onKey,
          onFocusChange: (value) {
            setState(() => _focused = value);
            if (!value) _cancel();
          },
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
            child: content,
          ));
    } else {
      content = Material(
          type: MaterialType.transparency,
          child: InkWell(
              borderRadius: BorderRadius.circular(CanopyRadius.pill),
              onTap: _enabled ? widget.onPressed : null,
              onFocusChange: (v) => setState(() => _focused = v),
              onTapDown:
                  _enabled ? (_) => setState(() => _pressed = true) : null,
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: content));
    }
    return Semantics(
        button: true,
        enabled: _enabled,
        hint: widget.holdToConfirm ? 'ds.hold_hint'.tr() : null,
        onLongPress: widget.holdToConfirm && _enabled ? _start : null,
        customSemanticsActions: widget.holdToConfirm && _holding
            ? {CustomSemanticsAction(label: 'ds.cancel_hold'.tr()): _cancel}
            : null,
        child: AnimatedScale(
            scale: _pressed && !reduced ? CanopyMotion.pressScale : 1,
            duration: reduced ? CanopyMotion.none : CanopyMotion.press,
            curve: CanopyMotion.easeOut,
            child: content));
  }
}
