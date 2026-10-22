import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../lessons/state/lessons_controller.dart';

enum AdminArea { platform, lessons }

/// The admin page's two areas (owner decision 2026-10-22): the platform
/// (channels, moderation, roles) and preachers & lessons. Lessons-only
/// admins have only the second, so they see no switch.
class AdminAreaSwitch extends StatelessWidget {
  const AdminAreaSwitch({super.key, required this.current});
  final AdminArea current;

  @override
  Widget build(BuildContext context) {
    final platform = context.select<AppProvider, bool>((p) => p.isAdminUser);
    if (!platform) return const SizedBox.shrink();
    final waiting = context.select<LessonsController?, int>((c) => c?.waitingCount ?? 0);
    Widget option(AdminArea area, String label, IconData icon) {
      final on = area == current;
      return Expanded(
        child: Material(
          color: on ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            key: ValueKey('admin-area-${area.name}'),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            onTap: on ? null : () => context.go(area == AdminArea.platform ? '/admin' : '/admin/lessons'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceSm),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 16, color: on ? AppTheme.onMedia : AppTheme.textSecondary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: on ? AppTheme.onMedia : AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                ),
                if (area == AdminArea.lessons && waiting > 0 && !on) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(99)),
                    child: Text('$waiting',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.onMedia)),
                  ),
                ],
              ]),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spaceSm, AppTheme.spaceSm, AppTheme.spaceSm, 0),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd + 4),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(children: [
        option(AdminArea.platform, 'admin.area_platform'.tr(), Icons.dashboard_outlined),
        const SizedBox(width: 4),
        option(AdminArea.lessons, 'admin.area_lessons'.tr(), Icons.menu_book_outlined),
      ]),
    );
  }
}
