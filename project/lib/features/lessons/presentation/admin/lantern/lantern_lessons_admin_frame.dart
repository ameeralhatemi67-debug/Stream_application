import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/widgets/lantern/lantern.dart';
import '../../../../admin/presentation/lantern/lantern_admin_frame.dart';

/// The Preachers & lessons area of the admin page in Lantern and Arch, in
/// the same frame as the platform area (owner notes 2026-11-12): the website
/// header and the night rail with the area switch and this area's pages on
/// the website layout; a page bar with a sections sheet on phones. [body] is
/// the area's own page, unchanged.
class LanternLessonsAdminFrame extends StatelessWidget
    implements LanternSkinWidget {
  const LanternLessonsAdminFrame(
      {super.key,
      required this.tabs,
      required this.current,
      required this.counts,
      required this.body,
      this.title,
      this.onBack});

  /// The area's pages, in order (`lessonsAdminTabs`).
  final List<String> tabs;
  final String current;

  /// Waiting items per page (approvals, reports).
  final Map<String, int> counts;
  final Widget body;

  /// A page opened from a tab (a preacher, adding a lesson): its name and
  /// the way back.
  final String? title;
  final VoidCallback? onBack;

  static LGlyph glyphOf(String tab) => switch (tab) {
        'overview' => LGlyph.chart,
        'approvals' => LGlyph.mail,
        'preachers' => LGlyph.users,
        'lessons' => LGlyph.calendar,
        'mosques' => LGlyph.mosque,
        'reports' => LGlyph.flag,
        'stats' => LGlyph.list,
        _ => LGlyph.history,
      };

  LanternAdminTab _tab(String t) =>
      (label: 'lessons.admin.tab_$t', icon: glyphOf(t), count: counts[t] ?? 0);

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Builder(
          builder: (context) =>
              context.lanternWide ? _wide(context) : _phone(context)));

  List<Widget> _rail(BuildContext context, {VoidCallback? beforeGo}) {
    final t = context.lt;
    return [
      const LanternAdminAreaSwitch(current: LanternAdminArea.lessons),
      Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 18, 12, 6),
          child: Semantics(
              header: true,
              child: Text('lessons.admin.title'.tr(),
                  style: Lantern.textStyle(12,
                      color: t.muted, weight: FontWeight.w700, height: 1.3)))),
      for (final tab in tabs)
        Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: LanternAdminNavItem(
                key: ValueKey('lessons-admin-tab-$tab'),
                tab: _tab(tab),
                selected: tab == current,
                onTap: () {
                  beforeGo?.call();
                  context.go('/admin/lessons/$tab');
                })),
    ];
  }

  Widget _wide(BuildContext context) {
    final t = context.lt;
    return Scaffold(
        key: const ValueKey('lantern-lessons-admin-frame'),
        backgroundColor: t.bg,
        body: Column(children: [
          const SafeArea(bottom: false, child: LanternWebHeader()),
          Expanded(
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                SizedBox(
                    width: Lantern.sideAdmin,
                    child: LNightBand(
                        key: const ValueKey('lantern-lessons-admin-rail'),
                        glow: const Alignment(-.8, -1),
                        latticeOpacity: .07,
                        child: Builder(
                            builder: (context) => SingleChildScrollView(
                                key: const ValueKey(
                                    'lessons-admin-navigation'),
                                padding:
                                    const EdgeInsets.fromLTRB(14, 18, 14, 24),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _rail(context)))))),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      if (title != null)
                        Padding(
                            padding:
                                const EdgeInsetsDirectional.fromSTEB(16, 12, 24, 0),
                            child: Row(children: [
                              LIconButton(
                                  key: const ValueKey('lantern-lessons-admin-back'),
                                  icon: LGlyph.back,
                                  label: 'common.back'.tr(),
                                  onPressed: onBack ??
                                      () => context.go('/admin/lessons/$current')),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Semantics(
                                      header: true,
                                      child: Text(title!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Lantern.displayStyle(20,
                                              color: t.fg,
                                              height: context.lanternArabic
                                                  ? 1.45
                                                  : 1.25)))),
                            ])),
                      Expanded(child: body),
                    ])),
              ])),
        ]));
  }

  Widget _phone(BuildContext context) {
    final t = context.lt;
    final sub = title != null;
    return Scaffold(
        key: const ValueKey('lantern-lessons-admin-frame'),
        backgroundColor: t.bg,
        appBar: LanternPageBar(
            title: title ?? 'lessons.admin.tab_$current'.tr(),
            onBack: sub
                ? (onBack ?? () => context.go('/admin/lessons/$current'))
                : null,
            actions: [
              if (!sub)
                LIconButton(
                    key: const ValueKey('lantern-lessons-admin-sections'),
                    icon: LGlyph.menu,
                    label: 'lantern.admin.sections'.tr(),
                    dot: counts.values.any((n) => n > 0),
                    onPressed: () => showLanternSheet<void>(context,
                        title: 'lessons.admin.title'.tr(),
                        body: (sheetContext) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: _rail(sheetContext,
                                beforeGo: () =>
                                    Navigator.of(sheetContext).pop())))),
            ]),
        body: body);
  }
}
