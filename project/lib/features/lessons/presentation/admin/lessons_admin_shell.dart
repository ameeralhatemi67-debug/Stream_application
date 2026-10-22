import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/layout/content_width.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_navigation.dart';
import '../../../admin/presentation/admin_surface.dart';
import '../../../admin/presentation/widgets/admin_area_switch.dart';
import '../../data/lessons_repository.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';

/// The Preachers & lessons area of the admin page, in its order.
const lessonsAdminTabs = ['overview', 'approvals', 'preachers', 'lessons', 'mosques', 'reports', 'stats', 'log'];

TGlyph lessonsAdminGlyph(String t) => switch (t) {
      'overview' => TGlyph.chart,
      'approvals' => TGlyph.inbox,
      'preachers' => TGlyph.users,
      'lessons' => TGlyph.calendar,
      'mosques' => TGlyph.mosque,
      'reports' => TGlyph.flag,
      'stats' => TGlyph.file,
      _ => TGlyph.history,
    };

/// A page of the Preachers & lessons area: the admin page's frame (the area
/// switch and this area's tabs in a rail or drawer) around [children].
/// [current] is the tab to highlight; [title] replaces the tab's name for
/// pages opened from a tab (a preacher, adding a lesson), which also get a
/// back button.
class LessonsAdminShell extends StatefulWidget {
  const LessonsAdminShell({super.key, required this.current, required this.children, this.title, this.narrow = false});
  final String current;
  final String? title;
  final List<Widget> children;
  final bool narrow;
  @override
  State<LessonsAdminShell> createState() => _LessonsAdminShellState();
}

class _LessonsAdminShellState extends State<LessonsAdminShell> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<LessonsController>().ensureLoaded());
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;
    final c = context.watch<LessonsController>();
    final Widget body;
    if (!c.loaded && (c.loading || c.failure == null)) {
      body = const Center(child: CircularProgressIndicator(color: TC.gold));
    } else if (!c.loaded) {
      body = TEmpty(
        icon: c.failure == LessonsFailure.unavailable ? TGlyph.refresh : TGlyph.alert,
        title: 'lessons.unavailable_title'.tr(),
        body: 'lessons.unavailable_body'.tr(),
        action: TButton('lessons.retry'.tr(), kind: TBtn.minted, icon: TGlyph.refresh, onPressed: c.refresh),
      );
    } else if (!c.canManage) {
      body = TEmpty(icon: TGlyph.lock, title: 'lessons.admin.locked'.tr(), body: 'lessons.admin.locked_body'.tr());
    } else {
      body = RefreshIndicator(
        color: TC.gold,
        onRefresh: c.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (c.isDemo)
              Container(
                color: TC.warnBg,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text('lessons.sample_banner'.tr(),
                    textAlign: TextAlign.center, style: tBody(12.5, color: TC.warnFg, weight: FontWeight.w600, height: 1.4)),
              ),
            TPage(narrow: widget.narrow, children: widget.children),
          ]),
        ),
      );
    }
    final sub = widget.title != null;
    return Scaffold(
      backgroundColor: TC.page,
      appBar: CaAppBar(
        languageBare: true,
        leading: sub
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'common.back'.tr(),
                onPressed: () => context.canPop() ? context.pop() : context.go('/admin/lessons/${widget.current}'))
            : desktop
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'common.back'.tr(),
                    onPressed: () => context.go('/feed'))
                : null,
        title: Text(widget.title ?? 'lessons.admin.title'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      drawer: desktop || sub ? null : Drawer(child: SafeArea(child: _Navigation(current: widget.current, closeDrawer: true))),
      body: Row(children: [
        if (desktop) ...[
          SizedBox(width: CanopySize.adminRail, child: _Navigation(current: widget.current)),
          const VerticalDivider(width: 1),
        ],
        Expanded(child: body),
      ]),
    );
  }
}

class _Navigation extends StatelessWidget {
  const _Navigation({required this.current, this.closeDrawer = false});
  final String current;
  final bool closeDrawer;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final counts = {
      'approvals': c.pendingRequests.length + c.pendingEdits.length,
      'reports': c.openFlags.length,
    };
    return ListView(
      key: const ValueKey('lessons-admin-navigation'),
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      children: [
        if (closeDrawer)
          ListTile(
              leading: const Icon(Icons.arrow_back_rounded, color: AppTheme.textSecondary),
              title: Text('common.back'.tr()),
              onTap: () => context.go('/feed')),
        const AdminAreaSwitch(current: AdminArea.lessons),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(AppTheme.spaceLg, AppTheme.spaceLg, AppTheme.spaceLg, AppTheme.spaceSm),
          child: Text('lessons.admin.title'.tr(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
        ),
        for (final t in lessonsAdminTabs)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceXs),
            child: ListTile(
              key: ValueKey('lessons-admin-tab-$t'),
              selected: current == t,
              selectedColor: AppTheme.primary,
              selectedTileColor: AppTheme.surfaceAlt,
              minVerticalPadding: AppTheme.spaceMd,
              titleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              leading: TIcon(lessonsAdminGlyph(t), size: 20, color: current == t ? AppTheme.primary : AppTheme.textSecondary),
              title: Text('lessons.admin.tab_$t'.tr()),
              trailing: (counts[t] ?? 0) > 0 ? AdminCount(count: counts[t]!, label: 'lessons.admin.tab_$t'.tr()) : null,
              onTap: () {
                if (closeDrawer) Navigator.of(context).pop();
                context.go('/admin/lessons/$t');
              },
            ),
          ),
      ],
    );
  }
}
