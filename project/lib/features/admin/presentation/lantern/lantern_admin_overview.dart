import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// The admin overview in Lantern and Arch: the counts the older overview
/// shows, as cards, and its three shortcuts. A count the platform does not
/// measure yet (viewers, seats) says so instead of a number.
class LanternAdminOverview extends StatelessWidget
    implements LanternSkinWidget {
  const LanternAdminOverview(
      {super.key,
      required this.broadcasters,
      required this.verifiedScholars,
      required this.organizations,
      required this.pending,
      required this.onReview,
      required this.onMap,
      required this.onTerms});

  final int broadcasters, verifiedScholars, organizations, pending;
  final VoidCallback onReview, onMap, onTerms;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final kpis = <({String label, int? value, LGlyph icon})>[
      (
        label: 'admin.loaded_broadcasters'.tr(),
        value: broadcasters,
        icon: LGlyph.mic
      ),
      (
        label: 'admin.kpi_verified_scholars'.tr(),
        value: verifiedScholars,
        icon: LGlyph.verified
      ),
      (
        label: 'admin.loaded_organizations'.tr(),
        value: organizations,
        icon: LGlyph.org
      ),
      (
        label: 'admin.kpi_pending_apps'.tr(),
        value: pending,
        icon: LGlyph.clock
      ),
      (label: 'admin.kpi_active_viewers'.tr(), value: null, icon: LGlyph.eye),
      (
        label: 'admin.kpi_auditorium_seats'.tr(),
        value: null,
        icon: LGlyph.users
      ),
    ];
    final gutter = context.lanternWide ? Lantern.webGutter : Lantern.gutter;
    return ListView(
        key: const ValueKey('lantern-admin-overview'),
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 32),
        children: [
          Semantics(
              header: true,
              child: Text('admin.tab_overview'.tr(),
                  style: Lantern.displayStyle(context.lanternWide ? 26 : 22,
                      color: t.fg,
                      height: context.lanternArabic ? 1.45 : 1.25))),
          const SizedBox(height: 6),
          Text('admin.overview_data_note'.tr(),
              style: Lantern.textStyle(13.5, color: t.muted, height: 1.5)),
          const SizedBox(height: 18),
          LayoutBuilder(builder: (context, box) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = (box.maxWidth / (190 * scale)).floor().clamp(2, 3);
            final width = (box.maxWidth - 12 * (columns - 1)) / columns;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final k in kpis)
                SizedBox(
                    width: width,
                    child:
                        _KpiCard(label: k.label, value: k.value, icon: k.icon)),
            ]);
          }),
          const SizedBox(height: 28),
          LSectionHead('design_ui.quick_actions_governance_shortcuts'.tr(),
              arch: false),
          const SizedBox(height: 12),
          LRow(
              key: const ValueKey('lantern-overview-review'),
              icon: LGlyph.verified,
              title: 'admin.review_queue'.tr(),
              subtitle: 'admin.pending_review'.plural(pending),
              onTap: onReview),
          const SizedBox(height: 8),
          LRow(
              key: const ValueKey('lantern-overview-map'),
              icon: LGlyph.map,
              title: 'admin.inspect_map'.tr(),
              subtitle: 'admin.inspect_map_hint'.tr(),
              onTap: onMap),
          const SizedBox(height: 8),
          LRow(
              key: const ValueKey('lantern-overview-terms'),
              icon: LGlyph.scale,
              title: 'admin.edit_terms'.tr(),
              subtitle: 'admin.edit_terms_hint'.tr(),
              onTap: onTerms),
        ]);
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label, required this.value, required this.icon});

  final String label;
  final int? value;
  final LGlyph icon;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final value = this.value;
    return Semantics(
        container: true,
        label: '$label: ${value ?? 'admin.unavailable'.tr()}',
        child: ExcludeSemantics(
            child: LCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Lantern.textStyle(12.5,
                                    color: t.muted,
                                    weight: FontWeight.w600,
                                    height: 1.35))),
                        const SizedBox(width: 8),
                        LIcon(icon, size: 18, color: t.goldInk),
                      ]),
                      const SizedBox(height: 8),
                      if (value != null)
                        Text('$value',
                            style: Lantern.displayStyle(30,
                                    color: t.fg, height: 1.15)
                                .copyWith(fontFeatures: Lantern.tabular))
                      else
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: LTag('admin.unavailable'.tr(),
                                icon: LGlyph.info)),
                    ]))));
  }
}
