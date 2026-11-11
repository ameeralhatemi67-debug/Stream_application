import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// The broadcast studio in Lantern and Arch (ADR-026): one page, always
/// night like the rooms. It says where the presenter stands (not live,
/// ready, live), shows the three steps with exactly one next step, and
/// keeps the controls in one column. The studio's state object keeps every
/// load and action; this view only draws what it is given.

enum LanternStudioStatus { setup, ready, live }

/// What the connection looks like before going live.
enum LanternStudioNetwork { good, unstable, offline }

class LanternStudioView extends StatelessWidget implements LanternSkinWidget {
  const LanternStudioView(
      {super.key,
      required this.status,
      required this.destination,
      required this.sender,
      required this.format,
      required this.network,
      required this.controls,
      required this.onClose,
      this.actions = const [],
      this.help});

  final LanternStudioStatus status;

  /// The three facts of the status card; an empty one shows a dash.
  final String destination, sender, format;
  final LanternStudioNetwork network;

  /// The settings, in order, already built from the Lantern kit.
  final List<Widget> controls;

  /// The confirmation and the hold buttons, pinned under the controls.
  /// Empty while the keyboard is open or when nothing can be done.
  final List<Widget> actions;
  final VoidCallback onClose;

  /// How to send from a laptop, shown beside the steps on the website
  /// layout.
  final String? help;

  @override
  Widget build(BuildContext context) => LanternSurface(
      night: true,
      child: Builder(builder: (context) {
        final t = context.lt;
        final wide = context.lanternWide;
        final overview = <Widget>[
          _StatusCard(
              status: status,
              destination: destination,
              sender: sender,
              format: format,
              network: network),
          const SizedBox(height: 14),
          _Steps(
              done: [
                destination.isNotEmpty,
                status != LanternStudioStatus.setup,
                status == LanternStudioStatus.live
              ]),
        ];
        final footer = actions.isEmpty
            ? null
            : Container(
                key: const ValueKey('lantern-studio-actions'),
                decoration: BoxDecoration(
                    color: t.surface,
                    border: Border(top: BorderSide(color: t.line))),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: actions));
        final settings = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: controls);
        return Material(
            color: t.bg,
            child: SafeArea(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  _Bar(onClose: onClose),
                  Expanded(
                      child: wide
                          ? Center(
                              child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: Lantern.webContent),
                                  child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: Lantern.webGutter,
                                          vertical: 24),
                                      child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                                child: SingleChildScrollView(
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                  ...overview,
                                                  if (help != null) ...[
                                                    const SizedBox(height: 14),
                                                    _Help(help!),
                                                  ],
                                                ]))),
                                            const SizedBox(width: 24),
                                            SizedBox(
                                                width: Lantern.sideStudio,
                                                child: Container(
                                                    key: const ValueKey(
                                                        'lantern-studio-column'),
                                                    clipBehavior:
                                                        Clip.antiAlias,
                                                    decoration: BoxDecoration(
                                                        color: t.surface,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                Lantern
                                                                    .radiusCard),
                                                        border: Border.all(
                                                            color: t.line)),
                                                    child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          Expanded(
                                                              child: SingleChildScrollView(
                                                                  padding:
                                                                      const EdgeInsets
                                                                          .all(
                                                                          20),
                                                                  child:
                                                                      settings)),
                                                          if (footer != null)
                                                            footer,
                                                        ]))),
                                          ]))))
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(Lantern.gutter),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ...overview,
                                    const SizedBox(height: 14),
                                    LCard(
                                        padding: const EdgeInsets.all(16),
                                        child: settings),
                                  ]))),
                  if (!wide && footer != null) footer,
                ])));
      }));
}

class _Bar extends StatelessWidget {
  const _Bar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Container(
        constraints: const BoxConstraints(minHeight: Lantern.appBarHeight),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
        decoration: BoxDecoration(
            color: t.surface, border: Border(bottom: BorderSide(color: t.line))),
        child: Row(children: [
          Expanded(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Semantics(
                    header: true,
                    child: Text('organization_v1.studio'.tr(),
                        style: Lantern.displayStyle(18,
                            color: t.fg,
                            height: context.lanternArabic ? 1.45 : 1.25))),
                Text('web.studio_sub'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Lantern.textStyle(12.5, color: t.muted, height: 1.35)),
              ])),
          LIconButton(
              key: const ValueKey('lantern-studio-close'),
              icon: LGlyph.close,
              label: 'organization_v1.close'.tr(),
              onPressed: onClose),
        ]));
  }
}

/// A dot that breathes while the studio is ready (amber) or live (red). It
/// holds still under calm motion; the words beside it carry the state.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.breathes});

  final Color color;
  final bool breathes;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  void _sync() {
    final run = widget.breathes && !Lantern.calm(context);
    if (run && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!run && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: widget.color.withValues(alpha: .45),
                    spreadRadius: 1 + 5 * _pulse.value)
              ])));
}

class _StatusCard extends StatelessWidget {
  const _StatusCard(
      {required this.status,
      required this.destination,
      required this.sender,
      required this.format,
      required this.network});

  final LanternStudioStatus status;
  final String destination, sender, format;
  final LanternStudioNetwork network;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final key = switch (status) {
      LanternStudioStatus.live => 'web.studio_live',
      LanternStudioStatus.ready => 'web.studio_ready',
      LanternStudioStatus.setup => 'web.studio_setup',
    };
    final dot = switch (status) {
      LanternStudioStatus.live => t.live,
      LanternStudioStatus.ready => LanternTokens.goldHi,
      LanternStudioStatus.setup => t.faint,
    };
    final (netKey, netTone) = switch (network) {
      LanternStudioNetwork.good => ('lantern.studio.network_good', LTone.ok),
      LanternStudioNetwork.unstable => (
          'lantern.studio.network_unstable',
          LTone.warn
        ),
      LanternStudioNetwork.offline => ('lantern.studio.network_off', LTone.live),
    };
    Widget fact(String label, Widget value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: Lantern.textStyle(12,
                      color: LanternTokens.goldHi,
                      weight: FontWeight.w700,
                      height: 1.3)),
              const SizedBox(height: 4),
              value,
            ]);
    Widget words(String value) => Text(value.isEmpty ? '—' : value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Lantern.textStyle(14.5,
            color: t.fg, weight: FontWeight.w700, height: 1.35));
    return LNightBand(
        key: const ValueKey('lantern-studio-status'),
        radius: Lantern.radiusCard,
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                  liveRegion: true,
                  child: Row(children: [
                    _StatusDot(
                        color: dot,
                        breathes: status != LanternStudioStatus.setup),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(key.tr(),
                            style: Lantern.displayStyle(24,
                                color: t.fg,
                                height: context.lanternArabic ? 1.45 : 1.2))),
                  ])),
              const SizedBox(height: 6),
              Text('${key}_body'.tr(),
                  style: Lantern.textStyle(14, color: t.muted, height: 1.5)),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, box) {
                final columns = box.maxWidth >= 560 ? 4 : 2;
                final width = (box.maxWidth - (columns - 1) * 14) / columns;
                return Wrap(spacing: 14, runSpacing: 14, children: [
                  for (final item in [
                    fact('web.studio_destination'.tr(), words(destination)),
                    fact('web.studio_sender'.tr(), words(sender)),
                    fact('web.studio_format'.tr(), words(format)),
                    fact(
                        'lantern.studio.network'.tr(),
                        Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: LTag(netKey.tr(),
                                key: const ValueKey('lantern-studio-network'),
                                tone: netTone,
                                icon: network == LanternStudioNetwork.offline
                                    ? LGlyph.wifioff
                                    : LGlyph.wifi))),
                  ])
                    SizedBox(width: width, child: item),
                ]);
              }),
            ]));
  }
}

/// The three steps. Done ones carry a check; the first one not done is the
/// next step and is the only one drawn in gold.
class _Steps extends StatelessWidget {
  const _Steps({required this.done});

  final List<bool> done;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final next = done.indexOf(false);
    final labels = [
      'web.studio_step1'.tr(),
      'web.studio_step2'.tr(),
      'web.studio_step3'.tr()
    ];
    return LCard(
        key: const ValueKey('lantern-studio-steps'),
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                  header: true,
                  child: Text('web.studio_steps'.tr(),
                      style: Lantern.displayStyle(16,
                          color: t.fg,
                          height: context.lanternArabic ? 1.45 : 1.25))),
              const SizedBox(height: 10),
              for (var i = 0; i < labels.length; i++)
                Semantics(
                    label:
                        '${i + 1}. ${labels[i]}${done[i] ? ', ${'lantern.studio.step_done'.tr()}' : i == next ? ', ${'lantern.studio.step_next'.tr()}' : ''}',
                    excludeSemantics: true,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: done[i] ? Lantern.goldFill : null,
                                  border: done[i]
                                      ? null
                                      : Border.all(
                                          color: i == next
                                              ? LanternTokens.gold
                                              : t.line,
                                          width: i == next ? 2 : 1.5)),
                              child: done[i]
                                  ? const LIcon(LGlyph.check,
                                      size: 16, color: LanternTokens.onGold)
                                  : Text('${i + 1}',
                                      style: Lantern.textStyle(13,
                                              color: i == next
                                                  ? t.goldInk
                                                  : t.muted,
                                              weight: FontWeight.w700,
                                              height: 1)
                                          .copyWith(
                                              fontFeatures: Lantern.tabular))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(labels[i],
                                  style: Lantern.textStyle(14.5,
                                      color:
                                          done[i] || i == next ? t.fg : t.muted,
                                      weight: i == next
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      height: 1.4))),
                          if (i == next)
                            LTag('lantern.studio.step_next'.tr(),
                                tone: LTone.gold),
                        ]))),
            ]));
  }
}

class _Help extends StatelessWidget {
  const _Help(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LCard(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                LIcon(LGlyph.info, size: 18, color: t.goldInk),
                const SizedBox(width: 10),
                Expanded(
                    child: Text('web.studio_help'.tr(),
                        style: Lantern.displayStyle(16,
                            color: t.fg,
                            height: context.lanternArabic ? 1.45 : 1.25))),
              ]),
              const SizedBox(height: 8),
              Text(text,
                  style: Lantern.textStyle(14, color: t.muted, height: 1.5)),
            ]));
  }
}

/// A setting with a short caption above it.
class LanternStudioField extends StatelessWidget implements LanternSkinWidget {
  const LanternStudioField(
      {super.key, required this.label, required this.child, this.note});

  final String label;
  final Widget child;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: Lantern.textStyle(13,
                      color: t.muted, weight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 8),
              child,
              if (note != null)
                Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(note!,
                        style: Lantern.textStyle(12.5,
                            color: t.muted, height: 1.4))),
            ]));
  }
}

/// One choice out of a few (a destination, an assignment): the current one
/// in a row; a tap opens the list in a sheet.
class LanternStudioChoice<T> extends StatelessWidget
    implements LanternSkinWidget {
  const LanternStudioChoice(
      {super.key,
      required this.title,
      required this.options,
      required this.value,
      required this.onChanged,
      this.icon = LGlyph.video});

  final String title;
  final List<({T value, String label})> options;
  final T? value;

  /// Null while the choice is frozen or busy.
  final ValueChanged<T>? onChanged;
  final LGlyph icon;

  @override
  Widget build(BuildContext context) {
    final current =
        options.where((o) => o.value == value).map((o) => o.label).firstOrNull;
    // One option still opens while nothing is chosen, so it can be picked.
    final open = onChanged != null &&
        options.isNotEmpty &&
        (options.length > 1 || current == null);
    return LRow(
        title: current ?? '—',
        icon: icon,
        arrow: open,
        dense: true,
        onTap: !open
            ? null
            : () => showLanternSheet<void>(context,
                title: title,
                night: true,
                body: (sheetContext) => Column(
                        key: const ValueKey('lantern-studio-choice-list'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final option in options)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: LRow(
                                    title: option.label,
                                    icon: option.value == value
                                        ? LGlyph.check
                                        : icon,
                                    arrow: false,
                                    dense: true,
                                    onTap: () {
                                      Navigator.of(sheetContext).pop();
                                      onChanged!(option.value);
                                    })),
                        ])));
  }
}

/// "I confirm this destination": a tick box the presenter must set before
/// the broadcast can be prepared.
class LanternStudioConfirm extends StatelessWidget
    implements LanternSkinWidget {
  const LanternStudioConfirm(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged});

  final String label;
  final bool value;

  /// Null while an operation is running.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Opacity(
            opacity: onChanged == null ? .55 : 1,
            child: LPressable(
                label: label,
                toggled: value,
                button: false,
                excludeChildSemantics: true,
                radius: Lantern.radiusTile,
                pressScale: .99,
                onTap: onChanged == null ? null : () => onChanged!(!value),
                builder: (context, s) => ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: Lantern.target),
                    child: Row(children: [
                      AnimatedContainer(
                          duration: Lantern.calm(context)
                              ? Lantern.none
                              : Lantern.state,
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              gradient: value ? Lantern.goldFill : null,
                              color: value ? null : t.surface,
                              borderRadius: BorderRadius.circular(7),
                              border: value
                                  ? null
                                  : Border.all(
                                      color:
                                          s.hovered ? LanternTokens.gold : t.line,
                                      width: 1.5)),
                          child: value
                              ? const LIcon(LGlyph.check,
                                  size: 15, color: LanternTokens.onGold)
                              : null),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(label,
                              style: Lantern.textStyle(14,
                                  color: t.fg,
                                  weight: FontWeight.w500,
                                  height: 1.4))),
                    ])))));
  }
}

/// The studio when it has nothing to set: a message and one or two buttons
/// (the phone lies on its side, or this device cannot send).
class LanternStudioNotice extends StatelessWidget
    implements LanternSkinWidget {
  const LanternStudioNotice(
      {super.key,
      required this.message,
      required this.actions,
      this.icon = LGlyph.info});

  final String message;
  final List<Widget> actions;
  final LGlyph icon;

  @override
  Widget build(BuildContext context) => LanternSurface(
      night: true,
      child: Builder(builder: (context) {
        final t = context.lt;
        return Material(
            color: t.bg,
            child: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LIcon(icon, size: 28, color: t.goldInk),
                                  const SizedBox(height: 12),
                                  Text(message,
                                      textAlign: TextAlign.center,
                                      style: Lantern.textStyle(15,
                                          color: t.fg, height: 1.5)),
                                  const SizedBox(height: 16),
                                  Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.center,
                                      children: actions),
                                ]))))));
      }));
}
