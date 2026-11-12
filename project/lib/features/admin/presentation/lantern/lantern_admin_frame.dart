import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../lessons/state/lessons_controller.dart';
import '../../models/tag_moderation_model.dart';

/// One tab of the admin page, in the order of its `TabBarView`.
typedef LanternAdminTab = ({String label, LGlyph icon, int count});

/// The four groups of the rail (owner brief for Lantern and Arch), by the
/// label key of each tab. A tab this admin does not have is left out.
const lanternAdminGroups = <({String title, List<String> labels})>[
  (
    title: 'admin.nav_review',
    labels: [
      'admin.tab_overview',
      'admin.tab_verification',
      'admin.tab_custom_cards',
    ]
  ),
  (
    title: 'admin.nav_moderate',
    labels: [
      'admin.tab_chat_moderation',
      'admin.tab_banned_accounts',
      'safety.tab',
    ]
  ),
  (
    title: 'admin.nav_directory',
    labels: [
      'admin.tab_streamers',
      'admin.tab_organizations',
      'directory.title',
      'admin.tab_viewers',
    ]
  ),
  (
    title: 'admin.nav_configure',
    labels: [
      'admin.tab_categories',
      'admin.tab_tags',
      'admin.tab_terms',
      'admin.tab_roles',
      'admin.tab_testing',
    ]
  ),
];

/// The admin page's tabs in the order `AdminHubScreen` builds its
/// `TabBarView` (the same order as its own navigation), with the counts the
/// older navigation shows.
List<LanternAdminTab> lanternAdminTabs(AppProvider p,
        {required bool master, required bool debug}) =>
    [
      (label: 'admin.tab_overview', icon: LGlyph.chart, count: 0),
      (
        label: 'admin.tab_verification',
        icon: LGlyph.verified,
        count: p.pendingApplications.length
      ),
      (label: 'admin.tab_streamers', icon: LGlyph.mic, count: 0),
      (label: 'admin.tab_organizations', icon: LGlyph.org, count: 0),
      (label: 'admin.tab_viewers', icon: LGlyph.eye, count: 0),
      (label: 'admin.tab_terms', icon: LGlyph.scale, count: 0),
      (
        label: 'admin.tab_chat_moderation',
        icon: LGlyph.chat,
        count: p.chatReports.length
      ),
      (
        label: 'admin.tab_custom_cards',
        icon: LGlyph.image,
        count: p.pendingCustomPlaceholders.length
      ),
      (label: 'admin.tab_categories', icon: LGlyph.book, count: 0),
      (
        label: 'admin.tab_tags',
        icon: LGlyph.filter,
        count: p.allTagsForModeration
            .where((t) => t.status == TagStatus.pending)
            .length
      ),
      (
        label: 'admin.tab_banned_accounts',
        icon: LGlyph.ban,
        count: p.bannedUsers.length
      ),
      if (debug) (label: 'admin.tab_testing', icon: LGlyph.settings, count: 0),
      if (master) (label: 'admin.tab_roles', icon: LGlyph.lock, count: 0),
      (label: 'directory.title', icon: LGlyph.users, count: 0),
      (label: 'safety.tab', icon: LGlyph.shield, count: 0),
    ];

/// The admin page in Lantern and Arch: a night rail on the start side of the
/// website layout, a page bar with a sections sheet on phones. [child] is the
/// screen's own `TabBarView` on [controller]; choosing a tab calls
/// [onSelect], the same tab change the older navigation makes.
class LanternAdminFrame extends StatelessWidget implements LanternSkinWidget {
  const LanternAdminFrame(
      {super.key,
      required this.tabs,
      required this.controller,
      required this.onSelect,
      required this.child});

  final List<LanternAdminTab> tabs;
  final TabController controller;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Builder(
          builder: (context) =>
              context.lanternWide ? _wide(context) : _phone(context)));

  Widget _wide(BuildContext context) {
    final t = context.lt;
    return Scaffold(
        key: const ValueKey('lantern-admin-frame'),
        backgroundColor: t.bg,
        body: Column(children: [
          const LanternWebHeader(),
          Expanded(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                SizedBox(
                    width: Lantern.sideAdmin,
                    child: LNightBand(
                        key: const ValueKey('lantern-admin-rail'),
                        glow: const Alignment(-.8, -1),
                        latticeOpacity: .07,
                        child: AnimatedBuilder(
                            animation: controller,
                            builder: (context, _) => _AdminNavList(
                                tabs: tabs,
                                current: controller.index,
                                onSelect: onSelect,
                                padding: const EdgeInsets.fromLTRB(
                                    14, 18, 14, 24))))),
                Expanded(child: child),
              ])),
        ]));
  }

  Widget _phone(BuildContext context) {
    final t = context.lt;
    return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final index = controller.index.clamp(0, tabs.length - 1);
          return Scaffold(
              key: const ValueKey('lantern-admin-frame'),
              backgroundColor: t.bg,
              appBar: LanternPageBar(
                  title: tabs.isEmpty
                      ? 'admin.short_title'.tr()
                      : tabs[index].label.tr(),
                  actions: [
                    LIconButton(
                        key: const ValueKey('lantern-admin-sections'),
                        icon: LGlyph.menu,
                        label: 'lantern.admin.sections'.tr(),
                        dot: tabs.any((tab) => tab.count > 0),
                        onPressed: () => _openSections(context)),
                  ]),
              body: child);
        });
  }

  void _openSections(BuildContext context) {
    showLanternSheet<void>(context,
        title: 'admin.short_title'.tr(),
        body: (sheetContext) => _AdminNavList(
            key: const ValueKey('lantern-admin-sheet'),
            tabs: tabs,
            current: controller.index,
            shrinkWrap: true,
            onSelect: (i) {
              Navigator.of(sheetContext).pop();
              onSelect(i);
            }));
  }
}

/// The grouped list of tabs, in the rail or the sheet.
class _AdminNavList extends StatelessWidget {
  const _AdminNavList(
      {super.key,
      required this.tabs,
      required this.current,
      required this.onSelect,
      this.padding = EdgeInsets.zero,
      this.shrinkWrap = false});

  final List<LanternAdminTab> tabs;
  final int current;
  final ValueChanged<int> onSelect;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final children = <Widget>[
      const LanternAdminAreaSwitch(current: LanternAdminArea.platform),
      for (final group in lanternAdminGroups)
        ...() {
          final members = [
            for (final label in group.labels)
              for (var i = 0; i < tabs.length; i++)
                if (tabs[i].label == label) i
          ];
          if (members.isEmpty) return const <Widget>[];
          return [
            Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 18, 12, 6),
                child: Semantics(
                    header: true,
                    child: Text(group.title.tr(),
                        style: Lantern.textStyle(12,
                            color: t.muted,
                            weight: FontWeight.w700,
                            height: 1.3)))),
            for (final i in members)
              Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: LanternAdminNavItem(
                      key: ValueKey('lantern-${tabs[i].label}'),
                      tab: tabs[i],
                      selected: i == current,
                      onTap: () => onSelect(i))),
          ];
        }(),
    ];
    return shrinkWrap
        ? Padding(
            padding: padding,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: children))
        // Fifteen rows at most: built at once, so every tab can be reached
        // by keyboard and screen reader without scrolling first.
        : SingleChildScrollView(
            key: const ValueKey('lantern-admin-navigation'),
            padding: padding,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children));
  }
}

/// One row of an admin rail: its icon, its name and a gold count.
class LanternAdminNavItem extends StatelessWidget implements LanternSkinWidget {
  const LanternAdminNavItem(
      {super.key,
      required this.tab,
      required this.selected,
      required this.onTap});

  final LanternAdminTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final label = tab.label.tr();
    return LPressable(
        onTap: onTap,
        label: tab.count > 0 ? '$label, ${tab.count}' : label,
        selected: selected,
        radius: 14,
        pressScale: .98,
        excludeChildSemantics: true,
        builder: (context, s) => AnimatedContainer(
            duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
            constraints: const BoxConstraints(minHeight: Lantern.target + 2),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 10, 8),
            decoration: BoxDecoration(
                color: selected
                    ? t.raised
                    : s.hovered
                        ? t.sunk
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: BorderDirectional(
                    start: BorderSide(
                        color:
                            selected ? LanternTokens.gold : Colors.transparent,
                        width: 3))),
            child: Row(children: [
              LIcon(tab.icon, size: 19, color: selected ? t.goldInk : t.muted),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Lantern.textStyle(14,
                          color: selected ? t.fg : t.muted,
                          weight: selected ? FontWeight.w700 : FontWeight.w400,
                          height: 1.3))),
              if (tab.count > 0) ...[
                const SizedBox(width: 8),
                Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    height: 22,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                        gradient: Lantern.goldFill,
                        borderRadius:
                            BorderRadius.circular(Lantern.radiusPill)),
                    child: Text('${tab.count}',
                        style: Lantern.textStyle(12,
                                color: LanternTokens.onGold,
                                weight: FontWeight.w700,
                                height: 1.1)
                            .copyWith(fontFeatures: Lantern.tabular))),
              ],
            ])));
  }
}

enum LanternAdminArea { platform, lessons }

/// The switch between the admin page's two areas (ADR-015), shown only to an
/// admin who has both, as in the older designs.
class LanternAdminAreaSwitch extends StatelessWidget
    implements LanternSkinWidget {
  const LanternAdminAreaSwitch({super.key, required this.current});

  final LanternAdminArea current;

  @override
  Widget build(BuildContext context) {
    final both = context
        .select<AppProvider, bool>((p) => p.isAdminUser && p.isLessonsAdmin);
    if (!both) return const SizedBox.shrink();
    final waiting =
        context.select<LessonsController?, int>((c) => c?.waitingCount ?? 0);
    final t = context.lt;
    Widget option(LanternAdminArea area, String label) {
      final on = area == current;
      final count = area == LanternAdminArea.lessons && !on ? waiting : 0;
      return Expanded(
          child: LPressable(
              key: ValueKey('admin-area-${area.name}'),
              onTap: on
                  ? null
                  : () => context.go(area == LanternAdminArea.platform
                      ? '/admin'
                      : '/admin/lessons'),
              label: count > 0 ? '$label, $count' : label,
              selected: on,
              radius: 12,
              excludeChildSemantics: true,
              builder: (context, s) => Container(
                  constraints: const BoxConstraints(minHeight: Lantern.target),
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      gradient: on ? Lantern.goldFill : null,
                      color: on ? null : (s.hovered ? t.raised : null),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                            child: Text(label,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                style: Lantern.textStyle(13,
                                    color: on ? LanternTokens.onGold : t.fg,
                                    weight: FontWeight.w700,
                                    height: 1.25))),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          LTag('$count', tone: LTone.gold),
                        ],
                      ]))));
    }

    return Container(
        key: const ValueKey('lantern-admin-area-switch'),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: t.sunk,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line)),
        child: Row(children: [
          option(LanternAdminArea.platform, 'admin.area_platform'.tr()),
          const SizedBox(width: 4),
          option(LanternAdminArea.lessons, 'admin.area_lessons'.tr()),
        ]));
  }
}

/// Shown instead of the admin page to an account without admin access.
class LanternAdminDenied extends StatelessWidget implements LanternSkinWidget {
  const LanternAdminDenied({super.key});

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Builder(
          builder: (context) => Scaffold(
              backgroundColor: context.lt.bg,
              appBar: context.lanternWide
                  ? null
                  : LanternPageBar(
                      title: 'design_ui.access_denied'.tr(),
                      onBack: () => context.go('/feed')),
              body: Column(children: [
                if (context.lanternWide) const LanternWebHeader(),
                Expanded(
                    child: Center(
                        child: SingleChildScrollView(
                            child: LEmptyState(
                                key: const ValueKey('lantern-admin-denied'),
                                icon: LGlyph.lock,
                                tone: LTone.warn,
                                title: 'design_ui.admin_access_required'.tr(),
                                body:
                                    'design_ui.your_account_does_not_have_admin_or_master_admin_access_ask_a_mas'
                                        .tr(),
                                action: LButton(
                                    label:
                                        'design_ui.go_to_account_settings'.tr(),
                                    onPressed: () =>
                                        context.go('/settings')))))),
              ]))));
}
