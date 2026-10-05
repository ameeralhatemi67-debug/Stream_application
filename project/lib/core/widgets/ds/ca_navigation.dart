import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../layout/window_class.dart';
import '../../theme/app_theme.dart';
import '../app_logo.dart';
import '../language_switcher.dart';
import 'ca_icon.dart';
import 'ca_focus_ring.dart';

/// All feature app bars keep their native actions and gain one locale control.
class CaAppBar extends AppBar {
  CaAppBar(
      {super.key,
      super.title,
      super.leading,
      super.backgroundColor,
      super.elevation,
      super.titleSpacing,
      super.toolbarHeight,
      super.centerTitle,
      bool compactLanguage = false,
      // Icon-only language control, without the circle behind it.
      bool languageBare = false,
      List<Widget>? actions})
      : super(actions: [
          if (!(actions ?? []).any(_hasLanguage))
            CaLanguageChip(
                glass: backgroundColor == AppTheme.media,
                compact: compactLanguage,
                bare: languageBare),
          ...?actions,
        ]);
  static bool _hasLanguage(Widget w) =>
      w is CaLanguageChip ||
      w is LanguageSwitcher ||
      (w is SingleChildRenderObjectWidget &&
          w.child != null &&
          _hasLanguage(w.child!)) ||
      (w is Container && w.child != null && _hasLanguage(w.child!));
}

class CaNavBar extends StatelessWidget {
  const CaNavBar({super.key, required this.index, required this.onChanged})
      : assert(index == 0 || index == 1);
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceMd),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(CanopyRadius.pill),
              child: BackdropFilter(
                  filter: ImageFilter.blur(
                      sigmaX: CanopySize.navBlur, sigmaY: CanopySize.navBlur),
                  child: Container(
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      color: Canopy.paper
                          .withValues(alpha: CanopySize.navPaperAlpha),
                      child: LayoutBuilder(builder: (context, bounds) {
                        // The active item takes whatever the other folds away:
                        // widths trade places over the pill's own duration.
                        const gap = AppTheme.spaceSm;
                        const folded = CanopySize.target;
                        final open = bounds.maxWidth - folded - gap;
                        return TweenAnimationBuilder<double>(
                            tween: Tween(end: index.toDouble()),
                            duration: CanopyMotion.reduced(context)
                                ? CanopyMotion.none
                                : CanopyMotion.navPill,
                            curve: CanopyMotion.easeOut,
                            builder: (context, t, _) => Row(children: [
                                  _PillDestination(
                                      index: 0,
                                      width: ui.lerpDouble(open, folded, t)!,
                                      selectedness: 1 - t,
                                      onTap: () => onChanged(0)),
                                  const SizedBox(width: gap),
                                  _PillDestination(
                                      index: 1,
                                      width: ui.lerpDouble(folded, open, t)!,
                                      selectedness: t,
                                      onTap: () => onChanged(1)),
                                ]));
                      }))))));
}

/// One item of the bottom pill. [selectedness] runs 0 to 1 as the item
/// becomes the active one: its gradient fades in, its icon turns white and its
/// label appears, all while [width] grows.
class _PillDestination extends StatelessWidget {
  const _PillDestination(
      {required this.index,
      required this.width,
      required this.selectedness,
      required this.onTap});
  final int index;
  final double width, selectedness;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final label = (index == 0 ? 'nav.feed' : 'nav.map').tr();
    final color =
        Color.lerp(Canopy.brandGreen, Canopy.paper, selectedness.clamp(0, 1))!;
    return Semantics(
        button: true,
        selected: selectedness > .5,
        label: label,
        child: CaFocusRing(
            onDark: selectedness > .5,
            child: Tooltip(
                message: label,
                excludeFromSemantics: true,
                child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(CanopyRadius.pill),
                        child: ExcludeSemantics(
                            child: SizedBox(
                                width: width,
                                height: CanopySize.target,
                                child: Stack(children: [
                                  Positioned.fill(
                                      child: Opacity(
                                          opacity: selectedness.clamp(0, 1),
                                          child: const DecoratedBox(
                                              decoration: BoxDecoration(
                                                  gradient: AppGradients.pill,
                                                  borderRadius:
                                                      BorderRadius.all(
                                                          Radius.circular(
                                                              CanopyRadius
                                                                  .pill)))))),
                                  ClipRect(
                                      child: OverflowBox(
                                          maxWidth: double.infinity,
                                          child: Center(
                                              child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                CaIcon(
                                                    index == 0
                                                        ? CaGlyph.list
                                                        : CaGlyph.map,
                                                    color: color),
                                                if (selectedness > 0) ...[
                                                  const SizedBox(
                                                      width: AppTheme.spaceSm),
                                                  Opacity(
                                                      opacity: selectedness
                                                          .clamp(0, 1),
                                                      child: Text(label,
                                                          maxLines: 1,
                                                          softWrap: false,
                                                          style: Theme.of(
                                                                  context)
                                                              .textTheme
                                                              .labelSmall
                                                              ?.copyWith(
                                                                  color: color,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600))),
                                                ],
                                              ])))),
                                ]))))))));
  }
}

class _Destination extends StatelessWidget {
  const _Destination(
      {required this.index,
      required this.selected,
      required this.onTap,
      this.labelled = false,
      this.stacked = false});
  final int index;
  final bool selected, labelled, stacked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final label = (index == 0 ? 'nav.feed' : 'nav.map').tr();
    final color = selected ? Canopy.paper : Canopy.brandGreen;
    final icon = CaIcon(index == 0 ? CaGlyph.list : CaGlyph.map, color: color);
    final text = Text(label,
        textAlign: stacked ? TextAlign.center : TextAlign.start,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600));
    return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: CaFocusRing(
            onDark: selected,
            child: Tooltip(
                message: label,
                excludeFromSemantics: true,
                child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(CanopyRadius.pill),
                        child: ExcludeSemantics(
                            child: AnimatedContainer(
                          duration: CanopyMotion.reduced(context)
                              ? CanopyMotion.none
                              : CanopyMotion.navPill,
                          curve: CanopyMotion.easeOut,
                          constraints: const BoxConstraints(
                              minHeight: CanopySize.target),
                          padding: EdgeInsetsDirectional.symmetric(
                              horizontal: stacked
                                  ? 0
                                  : selected || labelled
                                      ? AppTheme.spaceMd
                                      : 0,
                              vertical: AppTheme.spaceSm),
                          decoration: BoxDecoration(
                              gradient: selected ? AppGradients.pill : null,
                              borderRadius:
                                  BorderRadius.circular(CanopyRadius.pill)),
                          child: stacked
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      icon,
                                      const SizedBox(height: AppTheme.spaceXs),
                                      text
                                    ])
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      icon,
                                      if (selected || labelled) ...[
                                        const SizedBox(width: AppTheme.spaceSm),
                                        Flexible(child: text)
                                      ]
                                    ]),
                        )))))));
  }
}

class CaRail extends StatelessWidget {
  const CaRail(
      {super.key,
      required this.index,
      required this.onChanged,
      required this.role,
      this.expanded = true});
  final int index;
  final ValueChanged<int> onChanged;
  final String role;
  final bool expanded;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: expanded ? CanopySize.railExpanded : CanopySize.railMedium,
      child: ColoredBox(
          color: Canopy.paper,
          child: SafeArea(
              child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.all(AppTheme.spaceSm),
                                  child: Column(children: [
                                    const SizedBox(height: AppTheme.spaceLg),
                                    const AppLogo(size: CanopySize.railLogo),
                                    const SizedBox(height: AppTheme.spaceXl),
                                    for (var i = 0; i < 2; i++)
                                      Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: AppTheme.spaceSm),
                                          child: _Destination(
                                              index: i,
                                              selected: index == i,
                                              labelled: true,
                                              stacked: !expanded,
                                              onTap: () => onChanged(i))),
                                    if (expanded && !context.isPhone)
                                      const _RailAccountLinks(),
                                    const Spacer(),
                                    Container(
                                        padding:
                                            EdgeInsetsDirectional.symmetric(
                                                horizontal: expanded
                                                    ? AppTheme.spaceSm
                                                    : 0,
                                                vertical: AppTheme.spaceSm),
                                        decoration: BoxDecoration(
                                            gradient: expanded
                                                ? AppGradients.pill
                                                : null,
                                            color:
                                                expanded ? null : Canopy.mint,
                                            borderRadius: BorderRadius.circular(
                                                CanopyRadius.input)),
                                        width: expanded && !context.isPhone
                                            ? double.infinity
                                            : null,
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              if (expanded) ...[
                                                CaIcon(
                                                    role ==
                                                            'ds.role_streamer'
                                                                .tr()
                                                        ? CaGlyph.video
                                                        : CaGlyph.user,
                                                    color: Canopy.paper),
                                                const SizedBox(
                                                    width: AppTheme.spaceSm),
                                              ],
                                              Flexible(
                                                  child: Text(role,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                              fontWeight: expanded &&
                                                                      !context
                                                                          .isPhone
                                                                  ? FontWeight
                                                                      .w600
                                                                  : null,
                                                              color: expanded
                                                                  ? Canopy.paper
                                                                  : Canopy
                                                                      .brandGreen)))
                                            ])),
                                  ])))))))));
}

class _RailAccountLinks extends StatelessWidget {
  const _RailAccountLinks();
  @override
  Widget build(BuildContext context) {
    final role = context.select<AppProvider, (bool, bool, bool)>(
        (p) => (p.isStreamerModeEnabled, p.isAdminUser, p.isPermittedAdmin));
    Widget link(CaGlyph icon, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        child: TextButton(
            style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(CanopySize.target),
                alignment: AlignmentDirectional.centerStart,
                foregroundColor: Canopy.brandGreen),
            onPressed: onTap,
            child: Row(children: [
              CaIcon(icon),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(child: Text(label)),
            ])));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (role.$1)
        link(CaGlyph.user, 'ds.studio_profile'.tr(), () {
          final id = context.read<AppProvider>().currentUserStreamerId;
          context.push(id == null || id.isEmpty ? '/feed' : '/profile/$id');
        }),
      if (role.$2)
        link(CaGlyph.shield, 'settings.admin_hub_title'.tr(),
            () => context.push('/admin')),
      if (role.$3)
        link(CaGlyph.home, 'design_ui.organization_admin'.tr(),
            () => context.push('/org-admin')),
    ]);
  }
}

/// Account shortcuts remain available when the desktop rail is absent.
class CaAccountMenu extends StatelessWidget {
  const CaAccountMenu({super.key});
  @override
  Widget build(BuildContext context) {
    if (context.windowClass.index >= WindowClass.expanded.index &&
        !context.isPhone) {
      return const SizedBox.shrink();
    }
    final role = context.select<AppProvider, (bool, bool, bool)>(
        (p) => (p.isStreamerModeEnabled, p.isAdminUser, p.isPermittedAdmin));
    if (!role.$1 && !role.$2 && !role.$3) return const SizedBox.shrink();
    return PopupMenuButton<String>(
        tooltip: 'ds.account_actions'.tr(),
        icon: const CaIcon(CaGlyph.dots),
        onSelected: (path) {
          if (path == 'profile') {
            final ownId = context.read<AppProvider>().currentUserStreamerId;
            context.push(
                ownId == null || ownId.isEmpty ? '/feed' : '/profile/$ownId');
          } else {
            context.push(path);
          }
        },
        itemBuilder: (_) => [
              if (role.$1)
                PopupMenuItem(
                    value: 'profile', child: Text('ds.studio_profile'.tr())),
              if (role.$2)
                PopupMenuItem(
                    value: '/admin',
                    child: Text('settings.admin_hub_title'.tr())),
              if (role.$3)
                PopupMenuItem(
                    value: '/org-admin',
                    child: Text('design_ui.organization_admin'.tr())),
            ]);
  }
}
