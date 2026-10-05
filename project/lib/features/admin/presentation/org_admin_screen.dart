import '../../organization/presentation/organization_surface.dart';
import '../../../core/widgets/ds/ca_rows.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import 'widgets/org_management_view.dart';
import '../../organization/presentation/org_membership_panel.dart';
import '../../organization/models/org_membership.dart';

/// Org-scoped admin surface for Permitted Admins (Org Owners & Co-Owners --
/// v0.8 Checkpoint 3 Phase 1). Reuses OrgManagementView, the same widget
/// AdminHubScreen's Organizations tab uses for platform-wide admins, but
/// pinned to only the organization(s) AppProvider.permittedAdminOrgIds says
/// this signed-in user actually owns/co-owns. That scoping is a UX
/// convenience, not the security boundary -- org_venues/org_speakers/
/// affiliation_requests RLS (owns_organization()/is_org_member(), see
/// 20260821203100) already restricts writes to the real owner/co-owner or
/// an admin-tier account no matter what org id a client asks for.
///
/// The route guard (app_router.dart, isPermittedAdmin) keeps non-Permitted-
/// Admin accounts out entirely; the empty-state below is defense in depth
/// for the brief window right after sign-in before that role resolves.
class OrgAdminScreen extends StatefulWidget {
  const OrgAdminScreen({super.key});

  @override
  State<OrgAdminScreen> createState() => _OrgAdminScreenState();
}

class _OrgAdminScreenState extends State<OrgAdminScreen> {
  String? _selectedOrgId;

  @override
  Widget build(BuildContext context) {
    final orgIds = context
        .select<AppProvider, List<String>>((p) => p.permittedAdminOrgIds);

    if (orgIds.isEmpty) {
      return Scaffold(
        backgroundColor: Canopy.dawn,
        appBar: OrganizationAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Canopy.ink),
            onPressed: () => context.go('/feed'),
          ),
          title: Text('design_ui.organization_admin'.tr()),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            child: CaBanner(
                message:
                    'design_ui.you_are_not_an_owner_or_co_owner_of_any_organization'
                        .tr()),
          ),
        ),
      );
    }

    final names = context
        .select<AppProvider, List<OrgMembership>>((p) => p.orgMemberships);
    _selectedOrgId ??= orgIds.first;
    final activeOrgId =
        orgIds.contains(_selectedOrgId) ? _selectedOrgId! : orgIds.first;
    final membership = context.select<AppProvider, OrgMembership?>((p) => p
        .orgMemberships
        .where((m) => m.organizationId == activeOrgId && m.active)
        .firstOrNull);
    final profileAccess = membership == null ||
        {OrgRole.owner, OrgRole.coOwner}.contains(membership.role);

    return Scaffold(
      backgroundColor: Canopy.dawn,
      appBar: OrganizationAppBar(
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: Canopy.ink),
          tooltip: 'design_ui.discovery'.tr(),
          onPressed: () => context.go('/feed'),
        ),
        title: Text('design_ui.organization_admin'.tr()),
      ),
      // showAuditTrail: false -- audit_logs is admin-tier-only at the RLS
      // layer (20260821203100), so a Permitted Admin would just see an
      // always-empty tab there. See OrgManagementView's doc comment.
      body: OrganizationBody(
          child: ListView(children: [
        if (orgIds.length > 1)
          Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: OrganizationSwitcher(
                  child: DropdownButton<String>(
                value: activeOrgId,
                isExpanded: true,
                dropdownColor: Canopy.mint,
                underline: const SizedBox.shrink(),
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Canopy.ink),
                items: orgIds
                    .map((id) => DropdownMenuItem(
                          value: id,
                          child: Text(
                              names
                                      .where((m) => m.organizationId == id)
                                      .map((m) => context.locale.languageCode ==
                                                  'ar' &&
                                              m.organizationNameAr.isNotEmpty
                                          ? m.organizationNameAr
                                          : m.organizationNameEn)
                                      .firstOrNull ??
                                  id,
                              overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (id) => setState(() => _selectedOrgId = id),
              ))),
        OrgMembershipPanel(
            key: ValueKey('members_$activeOrgId'), orgId: activeOrgId),
        if (profileAccess)
          OrgManagementView(
              key: ValueKey(activeOrgId),
              orgId: activeOrgId,
              showAuditTrail: false),
      ])),
    );
  }
}
