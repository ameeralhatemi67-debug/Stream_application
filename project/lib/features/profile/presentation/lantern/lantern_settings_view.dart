import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_skin.dart' show LanternAppearance;
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/lantern/lantern.dart';

/// One category of Settings: its name and icon, and what its pane holds.
typedef LanternSettingsCategory = ({
  String id,
  String label,
  LGlyph icon,
  List<Widget> children,
});

/// Settings in Lantern and Arch (ADR-026). [SettingsScreen] keeps every
/// load and action; this lays the categories out.
///
/// Website layout: the category list (260 px) on the start side, sticky,
/// the current one with a gold edge, and the chosen category's pane beside
/// it. Phone layout: one scrolling page with a heading per category, as the
/// older phone screen is one column (no new route).
class LanternSettingsView extends StatefulWidget implements LanternSkinWidget {
  const LanternSettingsView(
      {super.key,
      required this.categories,
      required this.selected,
      required this.onSelect,
      this.initialId});

  final List<LanternSettingsCategory> categories;
  final int selected;
  final ValueChanged<int> onSelect;

  /// The phone layout scrolls to this category once, after the first frame
  /// (the notifications panel opens Settings at its notifications).
  final String? initialId;

  @override
  State<LanternSettingsView> createState() => _LanternSettingsViewState();
}

class _LanternSettingsViewState extends State<LanternSettingsView> {
  final _scroll = ScrollController();
  final _content = GlobalKey();
  final _row = GlobalKey();
  final _initialHead = GlobalKey();
  final _phoneScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !context.lanternWide) _revealInitial();
    });
  }

  /// The phone list builds lazily, so a section far down does not exist
  /// yet: step down until it is built, then bring its heading into view.
  Future<void> _revealInitial() async {
    final duration = Lantern.calm(context) ? Duration.zero : Lantern.enter;
    for (var i = 0; i < 16 && mounted; i++) {
      final target = _initialHead.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(target,
            duration: duration, curve: Lantern.ease);
        return;
      }
      if (!_phoneScroll.hasClients) return;
      final p = _phoneScroll.position;
      if (p.pixels >= p.maxScrollExtent) return;
      _phoneScroll.jumpTo(
          math.min(p.pixels + p.viewportDimension * .8, p.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _phoneScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        return Scaffold(
            backgroundColor: t.bg,
            appBar: context.lanternWide
                ? null
                : LanternPageBar(title: 'settings.title'.tr(), actions: [
                    LIconButton(
                        icon: LGlyph.globe,
                        label: context.lanternArabic ? 'English' : 'العربية',
                        onPressed: () => LanguageSwitcher.toggle(context)),
                  ]),
            body: context.lanternWide ? _wide(context) : _phone(context));
      }));

  Widget _phone(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return ListView(
        key: const ValueKey('lantern-settings-phone'),
        controller: _phoneScroll,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
            Lantern.gutter, 20, Lantern.gutter, 32 + bottom),
        children: [
          for (final (i, c) in widget.categories.indexed) ...[
            if (i > 0) const SizedBox(height: 36),
            KeyedSubtree(
                key: ValueKey('lantern-settings-section-${c.id}'),
                child: KeyedSubtree(
                    key: c.id == widget.initialId ? _initialHead : null,
                    child: LSectionHead(c.label, arch: i == 0))),
            const SizedBox(height: 14),
            ..._spaced(c.children, 14),
          ],
        ]);
  }

  Widget _wide(BuildContext context) {
    final t = context.lt;
    final selected =
        widget.selected.clamp(0, math.max(0, widget.categories.length - 1)).toInt();
    final current = widget.categories[selected];
    return Column(children: [
      const SafeArea(bottom: false, child: LanternWebHeader()),
      Expanded(
          child: SingleChildScrollView(
              controller: _scroll,
              child: Column(key: _content, children: [
                Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth:
                                Lantern.webContent + Lantern.webGutter * 2),
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                                Lantern.webGutter, 32, Lantern.webGutter, 56),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                      header: true,
                                      child: Text('settings.title'.tr(),
                                          style: Lantern.displayStyle(30,
                                              color: t.fg,
                                              height: context.lanternArabic
                                                  ? 1.45
                                                  : 1.25))),
                                  const SizedBox(height: 22),
                                  Row(
                                      key: _row,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                            width: Lantern.sideSettings,
                                            child: _Sticky(
                                                controller: _scroll,
                                                content: _content,
                                                row: _row,
                                                child: _nav(context, selected))),
                                        const SizedBox(width: 28),
                                        Expanded(
                                            child: Align(
                                                alignment: AlignmentDirectional
                                                    .topStart,
                                                child: ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            maxWidth: 820),
                                                    child: Column(
                                                        key: ValueKey(
                                                            'lantern-settings-pane-${current.id}'),
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .stretch,
                                                        children: [
                                                          Semantics(
                                                              header: true,
                                                              child: Text(
                                                                  current
                                                                      .label,
                                                                  style: Lantern.displayStyle(
                                                                      22,
                                                                      color: t
                                                                          .fg,
                                                                      height: context.lanternArabic
                                                                          ? 1.45
                                                                          : 1.3))),
                                                          const SizedBox(
                                                              height: 18),
                                                          ..._spaced(
                                                              current.children,
                                                              18),
                                                        ])))),
                                      ]),
                                ])))),
                const LanternWebFooter(),
              ]))),
    ]);
  }

  Widget _nav(BuildContext context, int selected) {
    final t = context.lt;
    return Semantics(
        explicitChildNodes: true,
        label: 'lantern.account.categories'.tr(),
        child: Container(
            key: const ValueKey('lantern-settings-nav'),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: t.line)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, c) in widget.categories.indexed)
                    LPressable(
                        key: ValueKey('lantern-settings-category-${c.id}'),
                        onTap: () => widget.onSelect(i),
                        label: c.label,
                        selected: i == selected,
                        radius: Lantern.radiusTile,
                        pressScale: .98,
                        excludeChildSemantics: true,
                        builder: (context, s) {
                          final on = i == selected;
                          return AnimatedContainer(
                              duration: Lantern.calm(context)
                                  ? Lantern.none
                                  : Lantern.state,
                              constraints: const BoxConstraints(
                                  minHeight: Lantern.target),
                              margin: const EdgeInsets.symmetric(vertical: 1),
                              decoration: BoxDecoration(
                                  color: on || s.hovered ? t.sunk : null,
                                  borderRadius: BorderRadius.circular(
                                      Lantern.radiusTile)),
                              child: Stack(children: [
                                if (on)
                                  const PositionedDirectional(
                                      start: 0,
                                      top: 10,
                                      bottom: 10,
                                      width: 3,
                                      child: DecoratedBox(
                                          decoration: BoxDecoration(
                                              color: LanternTokens.gold,
                                              borderRadius: BorderRadius.all(
                                                  Radius.circular(3))))),
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 11),
                                    child: Row(children: [
                                      LIcon(c.icon,
                                          size: 19,
                                          color: on ? t.goldInk : t.muted),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(c.label,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Lantern.textStyle(14.5,
                                                  color: on || s.hovered
                                                      ? t.fg
                                                      : t.muted,
                                                  weight: on
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  height: 1.3))),
                                    ])),
                              ]));
                        }),
                ])));
  }
}

List<Widget> _spaced(List<Widget> children, double gap) => [
      for (final (i, c) in children.indexed) ...[
        if (i > 0) SizedBox(height: gap),
        c,
      ],
    ];

/// Keeps the category list in view while the pane scrolls, down to the end
/// of the pane. It is laid out in place and only painted lower, so the pane
/// beside it never moves.
class _Sticky extends StatelessWidget {
  const _Sticky(
      {required this.controller,
      required this.content,
      required this.row,
      required this.child});

  final ScrollController controller;
  final GlobalKey content, row;
  final Widget child;

  static const _top = 24.0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        var shift = 0.0;
        final self = context.findRenderObject();
        final rowBox = row.currentContext?.findRenderObject();
        final contentBox = content.currentContext?.findRenderObject();
        if (controller.hasClients &&
            self is RenderBox &&
            rowBox is RenderBox &&
            contentBox is RenderBox &&
            self.hasSize &&
            rowBox.hasSize &&
            rowBox.attached &&
            contentBox.attached) {
          final rowTop =
              rowBox.localToGlobal(Offset.zero, ancestor: contentBox).dy;
          shift = (controller.offset + _top - rowTop)
              .clamp(0.0, math.max(0.0, rowBox.size.height - self.size.height));
        }
        return Transform.translate(offset: Offset(0, shift), child: child);
      });
}

/// A group of rows under a small heading (the design's `ws-group`).
class LanternSettingsGroup extends StatelessWidget implements LanternSkinWidget {
  const LanternSettingsGroup(
      {super.key, this.title, required this.children, this.trailing});

  final String? title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 10, start: 2),
                child: Row(children: [
                  Expanded(
                      child: Semantics(
                          header: true,
                          child: Text(title!,
                              style: Lantern.textStyle(13,
                                  color: t.muted,
                                  weight: FontWeight.w700,
                                  height: 1.3)))),
                  if (trailing != null) trailing!,
                ])),
          ..._spaced(children, 6),
        ]);
  }
}

/// Who is signed in: the avatar, the name, the address, the roles in words,
/// and one action (edit the profile, or sign in for a guest).
class LanternAccountCard extends StatelessWidget implements LanternSkinWidget {
  const LanternAccountCard(
      {super.key,
      required this.name,
      required this.guest,
      this.email,
      this.handle,
      this.image,
      this.roles = const [],
      this.admin = false,
      this.verified = false,
      required this.actionLabel,
      required this.onAction,
      this.actionLoading = false});

  final String name;
  final String? email, handle;
  final ImageProvider? image;
  final bool guest, admin, verified, actionLoading;
  final List<(String label, LTone tone, LGlyph icon)> roles;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final avatar = guest
        ? Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: t.sunk, shape: BoxShape.circle),
            child: LIcon(LGlyph.person, size: 30, color: t.muted))
        : LAvatar(
            name: name,
            image: image,
            size: 64,
            verified: verified,
            ring: admin ? LRing.admin : LRing.none);
    final text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: Lantern.displayStyle(17,
                  color: t.fg, height: context.lanternArabic ? 1.45 : 1.25)),
          if (handle != null && handle!.isNotEmpty)
            Text(handle!,
                textDirection: TextDirection.ltr,
                style: Lantern.textStyle(13, color: t.goldInk, height: 1.4)),
          if (email != null && email!.isNotEmpty)
            Text(email!,
                style: Lantern.textStyle(13, color: t.muted, height: 1.4)),
          if (roles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (label, tone, icon) in roles)
                LTag(label, tone: tone, icon: icon),
            ]),
          ],
        ]);
    final action = LButton(
        key: const ValueKey('lantern-settings-account-action'),
        label: actionLabel,
        icon: guest ? null : LGlyph.edit,
        kind: guest ? LButtonKind.primary : LButtonKind.secondary,
        size: LButtonSize.small,
        loading: actionLoading,
        onPressed: onAction);
    return Container(
        key: const ValueKey('lantern-settings-account'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Lantern.radiusCard),
            border: Border.all(color: guest ? t.muted : t.line),
            boxShadow: t.shadow),
        child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 560
                ? Row(children: [
                    avatar,
                    const SizedBox(width: 16),
                    Expanded(child: text),
                    const SizedBox(width: 12),
                    action,
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(children: [
                          avatar,
                          const SizedBox(width: 14),
                          Expanded(child: text),
                        ]),
                        const SizedBox(height: 14),
                        action,
                      ])));
  }
}

/// A gold-edged call to action: a title, a line and one button.
class LanternSettingsCallout extends StatelessWidget
    implements LanternSkinWidget {
  const LanternSettingsCallout(
      {super.key,
      required this.title,
      required this.body,
      required this.action,
      this.icon,
      this.tone = LTone.gold,
      this.footer});

  final String title, body;
  final Widget action;
  final LGlyph? icon;
  final LTone tone;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final (edge, ink) = switch (tone) {
      LTone.live => (t.live, t.liveText),
      LTone.warn => (t.warn, t.warn),
      LTone.ok => (t.ok, t.ok),
      _ => (LanternTokens.gold, t.goldInk),
    };
    final danger = tone == LTone.live;
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: danger ? t.liveSoft : null,
            gradient: danger
                ? null
                : LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [t.sunk, t.surface]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: edge, width: danger ? 1.5 : 1)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (icon != null) ...[
                  Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: LIcon(icon!, size: 20, color: ink)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(title,
                          style: Lantern.textStyle(15.5,
                              color: danger ? t.liveText : t.fg,
                              weight: FontWeight.w700,
                              height: 1.35)),
                      const SizedBox(height: 3),
                      Text(body,
                          style: Lantern.textStyle(13.5,
                              color: t.muted, height: 1.45)),
                    ])),
              ]),
              if (footer != null) ...[const SizedBox(height: 12), footer!],
              const SizedBox(height: 14),
              action,
            ]));
  }
}

/// Lantern's own look for this device: day, night or the device's choice,
/// and calm motion.
class LanternAppearanceGroup extends StatelessWidget
    implements LanternSkinWidget {
  const LanternAppearanceGroup(
      {super.key,
      required this.appearance,
      required this.calm,
      required this.onAppearance,
      required this.onCalm});

  final LanternAppearance appearance;
  final bool calm;
  final ValueChanged<LanternAppearance> onAppearance;
  final ValueChanged<bool> onCalm;

  @override
  Widget build(BuildContext context) => LanternSettingsGroup(
          key: const ValueKey('lantern-settings-appearance'),
          title: 'lantern.appearance.title'.tr(),
          trailing: LTag('lantern.account.new'.tr(), tone: LTone.gold),
          children: [
            Text('lantern.appearance.hint'.tr(),
                style: Lantern.textStyle(13, color: context.lt.muted)),
            LSegmented<LanternAppearance>(
                expand: true,
                segments: [
                  (
                    value: LanternAppearance.day,
                    label: 'lantern.appearance.day'.tr(),
                    icon: LGlyph.sun
                  ),
                  (
                    value: LanternAppearance.night,
                    label: 'lantern.appearance.night'.tr(),
                    icon: LGlyph.moon
                  ),
                  (
                    value: LanternAppearance.system,
                    label: 'lantern.appearance.system'.tr(),
                    icon: null
                  ),
                ],
                value: appearance,
                onChanged: onAppearance),
            LRow(
                icon: LGlyph.sparkles,
                title: 'lantern.appearance.calm'.tr(),
                subtitle: 'lantern.appearance.calm_hint'.tr(),
                trailing: LSwitch(
                    key: const ValueKey('lantern-settings-calm'),
                    value: calm,
                    label: 'lantern.appearance.calm'.tr(),
                    onChanged: onCalm)),
          ]);
}

/// The app's language as a two-way switch.
class LanternLanguageGroup extends StatelessWidget implements LanternSkinWidget {
  const LanternLanguageGroup({super.key});

  @override
  Widget build(BuildContext context) => LanternSettingsGroup(
          key: const ValueKey('lantern-settings-language'),
          title: 'settings.language'.tr(),
          children: [
            Directionality(
                textDirection: TextDirection.ltr,
                child: LSegmented<String>(
                    expand: true,
                    segments: [
                      (
                        value: 'en',
                        label: 'design_ui.english_us'.tr(),
                        icon: null
                      ),
                      (value: 'ar', label: 'العربية', icon: null),
                    ],
                    value: context.locale.languageCode,
                    onChanged: (code) {
                      if (code != context.locale.languageCode) {
                        LanguageSwitcher.set(context, code);
                      }
                    })),
          ]);
}
