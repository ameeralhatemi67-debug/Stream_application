import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../organization/models/org_venue_branch_model.dart';
import '../../../organization/models/org_speaker_model.dart';
import '../../../organization/models/org_audit_log_entry.dart';
import '../../../organization/models/org_broadcaster_permissions.dart';
import '../../../organization/models/org_affiliation_request_model.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../../core/utils/id_generator.dart';

class OrgManagementView extends StatefulWidget {
  final String orgId;

  /// Audit Trail reads audit_logs, which is admin-tier-only at the RLS
  /// layer (20260821203100) -- a Permitted Admin viewer would just see an
  /// always-empty tab, which reads as broken rather than "no history yet".
  /// v0.8 Checkpoint 3's org-scoped surface for Permitted Admins passes
  /// false; AdminHubScreen (admin-tier only) keeps the default true.
  final bool showAuditTrail;

  const OrgManagementView({
    super.key,
    this.orgId = 'org_dalilk_04',
    this.showAuditTrail = true,
  });

  @override
  State<OrgManagementView> createState() => _OrgManagementViewState();
}

class _OrgManagementViewState extends State<OrgManagementView> {
  int _activeSubSection = 0; // 0: Branches, 1: Speakers, 2: Affiliations, 3: Audit Trail
  String _auditSearchQuery = '';

  @override
  void initState() {
    super.initState();
    // Prefetches this org's real venues/speakers from Supabase, if it has a
    // real backend row (Checkpoint 3 Phase 2) -- no-ops for mock demo orgs.
    context.read<AppProvider>().ensureOrgDataLoaded(widget.orgId);
  }

  @override
  Widget build(BuildContext context) {
    // context.read for the instance the many mutation calls below need
    // (addOrganizationBranch, updateSpeakerPermissions, etc.). context.select
    // scopes this screen's rebuild to just this org's own data -- previously
    // context.watch<AppProvider>() rebuilt this whole management view on ANY
    // AppProvider change platform-wide, including other orgs'audit logs and
    // affiliation requests.
    final provider = context.read<AppProvider>();
    final (org, branches, speakers, affiliations, auditLogs) = context.select<
        AppProvider,
        (
          StreamerModel?,
          List<OrgVenueBranchModel>,
          List<OrgSpeakerModel>,
          List<OrgAffiliationRequestModel>,
          List<OrgAuditLogEntry>
        )>((p) => (
          p.getStreamerById(widget.orgId),
          p.getOrganizationVenues(widget.orgId),
          p.getOrganizationSpeakers(widget.orgId),
          p.affiliationRequests.where((r) => r.orgId == widget.orgId).toList(),
          p.auditLogs.where((l) => l.organizationId == widget.orgId).toList(),
        ));
    final langCode = context.locale.languageCode;

    if (org == null) {
      return Center(
        child: Text('design_ui.organization_not_found'.tr(),
          style: const TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  Organization Header Card
          _buildOrgHeaderCard(org, langCode, branches.length, speakers.length),
          const SizedBox(height: AppTheme.spaceLg),

          // Sub-Navigation Tabs
          _buildSubNavTabs(branches.length, speakers.length, affiliations.length, auditLogs.length),
          const SizedBox(height: AppTheme.spaceLg),

          // Active Sub-Section
          if (_activeSubSection == 0)
            _buildBranchesSection(context, provider, branches, langCode)
          else if (_activeSubSection == 1)
            _buildSpeakersSection(context, provider, speakers, langCode)
          else if (_activeSubSection == 2)
            _buildAffiliationsSection(context, provider, affiliations, langCode)
          else if (widget.showAuditTrail)
            _buildAuditTrailSection(context, provider, auditLogs, langCode),
        ],
      ),
    );
  }

  Widget _buildOrgHeaderCard(
    StreamerModel org,
    String langCode,
    int branchCount,
    int speakerCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.warning, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: org.avatarUrl.startsWith('assets/')
                ? Image.asset(
                    org.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceAlt,
                      child: const Icon(Icons.apartment_rounded, color: AppTheme.warning),
                    ),
                  )
                : Image.network(
                    org.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceAlt,
                      child: const Icon(Icons.apartment_rounded, color: AppTheme.warning),
                    ),
                  ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        org.getLocalizedName(langCode),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.warning, width: 0.8),
                      ),
                      child: Text(
                        'profile.org_badge'.tr(),
                        style: const TextStyle(
                          color: AppTheme.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  org.youtubeHandle.isNotEmpty ? '@${org.youtubeHandle}' : '@dalilk4ielts',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  org.getLocalizedBio(langCode),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubNavTabs(int branchCount, int speakerCount, int affCount, int auditCount) {
    return Wrap(
      spacing: AppTheme.spaceSm,
      runSpacing: AppTheme.spaceSm,
      children: [
        _buildTabBtn(
          index: 0,
          label: 'admin.org_branches_title'.tr(),
          icon: Icons.apartment_rounded,
          count: branchCount,
        ),
        _buildTabBtn(
          index: 1,
          label: 'admin.org_speakers_title'.tr(),
          icon: Icons.groups_rounded,
          count: speakerCount,
        ),
        _buildTabBtn(
          index: 2,
          label: 'Affiliation Requests',
          icon: Icons.mark_email_unread_rounded,
          count: affCount,
        ),
        if (widget.showAuditTrail)
          _buildTabBtn(
            index: 3,
            label: 'admin.org_audit_trail_title'.tr(),
            icon: Icons.history_edu_rounded,
            count: auditCount,
          ),
      ],
    );
  }

  Widget _buildTabBtn({
    required int index,
    required String label,
    required IconData icon,
    required int count,
  }) {
    final isSelected = _activeSubSection == index;
    return InkWell(
      onTap: () => setState(() => _activeSubSection = index),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.warning.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected ? AppTheme.warning : AppTheme.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppTheme.warning : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.onMedia : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.warning.withValues(alpha: 0.3)
                    : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? AppTheme.warning : AppTheme.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //  1. Branches Section
  Widget _buildBranchesSection(
    BuildContext context,
    AppProvider provider,
    List<OrgVenueBranchModel> branches,
    String langCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'admin.org_branches_title'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: AppTheme.media,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              icon: const Icon(Icons.add_location_alt_rounded, size: 16),
              label: Text(
                'admin.add_branch'.tr(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showAddEditBranchDialog(context, provider),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: branches.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
          itemBuilder: (context, idx) {
            final branch = branches[idx];
            return _buildBranchCard(context, provider, branch, langCode);
          },
        ),
      ],
    );
  }

  Widget _buildBranchCard(
    BuildContext context,
    AppProvider provider,
    OrgVenueBranchModel branch,
    String langCode,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: branch.isMainHeadquarters
              ? AppTheme.warning.withValues(alpha: 0.5)
              : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: branch.isMainHeadquarters
                  ? AppTheme.warning.withValues(alpha: 0.15)
                  : AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              branch.isMainHeadquarters ? Icons.stars_rounded : Icons.location_on_rounded,
              color: branch.isMainHeadquarters ? AppTheme.warning : AppTheme.danger,
              size: 24,
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      branch.getLocalizedName(langCode),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (branch.isMainHeadquarters) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'admin.is_main_hq'.tr(),
                          style: const TextStyle(
                            color: AppTheme.warning,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${branch.getLocalizedCity(langCode)} • ${branch.seatingCapacity} seats • GPS: ${branch.latitude.toStringAsFixed(4)}, ${branch.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (branch.availableFacilities.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: branch.availableFacilities.map((fac) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          fac,
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
            tooltip: 'admin.edit_branch'.tr(),
            onPressed: () => _showAddEditBranchDialog(context, provider, branch: branch),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
            tooltip: 'admin.delete_branch'.tr(),
            onPressed: () => provider.deleteOrganizationBranch(widget.orgId, branch.venueId),
          ),
        ],
      ),
    );
  }

  //  2. Speakers Section
  Widget _buildSpeakersSection(
    BuildContext context,
    AppProvider provider,
    List<OrgSpeakerModel> speakers,
    String langCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'admin.org_speakers_title'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warning,
                foregroundColor: AppTheme.media,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
              label: Text(
                'admin.add_speaker'.tr(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showAddEditSpeakerDialog(context, provider),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: speakers.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
          itemBuilder: (context, idx) {
            final speaker = speakers[idx];
            return _buildSpeakerCard(context, provider, speaker, langCode);
          },
        ),
      ],
    );
  }

  Widget _buildSpeakerCard(
    BuildContext context,
    AppProvider provider,
    OrgSpeakerModel speaker,
    String langCode,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: speaker.avatarUrl.startsWith('assets/')
                ? Image.asset(
                    speaker.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceAlt,
                      child: const Icon(Icons.person, color: AppTheme.warning, size: 20),
                    ),
                  )
                : Image.network(
                    speaker.avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surfaceAlt,
                      child: const Icon(Icons.person, color: AppTheme.warning, size: 20),
                    ),
                  ),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      speaker.getLocalizedName(langCode),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: speaker.isPermanentStaff
                            ? AppTheme.warning.withValues(alpha: 0.2)
                            : AppTheme.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        speaker.isPermanentStaff
                            ? 'profile.permanent_staff'.tr()
                            : 'profile.guest_speaker'.tr(),
                        style: TextStyle(
                          color: speaker.isPermanentStaff
                              ? AppTheme.warning
                              : AppTheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  speaker.getLocalizedRole(langCode),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                // Permissions mini tags
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (speaker.permissions.canGoLiveVideo)
                      _buildPermTag('Video Live', Icons.videocam, AppTheme.success),
                    if (speaker.permissions.canGoAudioOnly)
                      _buildPermTag('Audio Live', Icons.mic, AppTheme.primary),
                    if (speaker.permissions.canChangeLocation)
                      _buildPermTag('Select Venue', Icons.location_on, AppTheme.warning),
                    if (speaker.permissions.canEditDescription)
                      _buildPermTag('Edit Title', Icons.edit_note, Colors.purpleAccent),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.security_rounded, size: 18, color: AppTheme.warning),
            tooltip: 'admin.edit_permissions'.tr(),
            onPressed: () => _showPermissionsDialog(context, provider, speaker),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
            tooltip: 'admin.edit_speaker'.tr(),
            onPressed: () => _showAddEditSpeakerDialog(context, provider, speaker: speaker),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
            tooltip: 'admin.delete_speaker'.tr(),
            onPressed: () => provider.deleteOrganizationSpeaker(widget.orgId, speaker.speakerId),
          ),
        ],
      ),
    );
  }

  Widget _buildPermTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  //  3. Audit Trail Section
  Widget _buildAuditTrailSection(
    BuildContext context,
    AppProvider provider,
    List<OrgAuditLogEntry> logs,
    String langCode,
  ) {
    final filteredLogs = logs.where((l) {
      if (_auditSearchQuery.isEmpty) return true;
      final q = _auditSearchQuery.toLowerCase();
      return l.actorEmail.toLowerCase().contains(q) ||
          l.actorName.toLowerCase().contains(q) ||
          l.getLocalizedDescription(langCode).toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'admin.org_audit_trail_title'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              width: 240,
              height: 36,
              child: TextField(
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search audit trail...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 16, color: AppTheme.textMuted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                ),
                onChanged: (val) => setState(() => _auditSearchQuery = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (filteredLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text('design_ui.no_audit_logs_found_for_this_organization'.tr(),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredLogs.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppTheme.spaceSm),
            itemBuilder: (context, idx) {
              final log = filteredLogs[idx];
              return Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.history_edu_rounded,
                        color: AppTheme.warning,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                log.actorEmail,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp),
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            log.getLocalizedDescription(langCode),
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // Dialogs
  void _showAddEditBranchDialog(
    BuildContext context,
    AppProvider provider, {
    OrgVenueBranchModel? branch,
  }) {
    final isEdit = branch != null;
    final nameEnCtrl = TextEditingController(text: branch?.nameEn ?? '');
    final nameArCtrl = TextEditingController(text: branch?.nameAr ?? '');
    final cityEnCtrl = TextEditingController(text: branch?.cityEn ?? 'Al Khobar');
    final cityArCtrl = TextEditingController(text: branch?.cityAr ?? 'الخبر');
    final seatsCtrl = TextEditingController(text: (branch?.seatingCapacity ?? 100).toString());
    final latCtrl = TextEditingController(text: (branch?.latitude ?? 26.2886).toString());
    final lngCtrl = TextEditingController(text: (branch?.longitude ?? 50.2083).toString());
    final facCtrl = TextEditingController(text: branch?.availableFacilities.join(', ') ?? 'Smart Board, High-Speed Wi-Fi');
    bool isMainHq = branch?.isMainHeadquarters ?? false;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                isEdit ? 'admin.edit_branch'.tr() : 'admin.add_branch'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameEnCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.branch_name_en'.tr()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameArCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.branch_name_ar'.tr()),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: cityEnCtrl,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(labelText: 'admin.branch_city_en'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: seatsCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(labelText: 'admin.seating_capacity'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(labelText: 'admin.latitude'.tr()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lngCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            decoration: InputDecoration(labelText: 'admin.longitude'.tr()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: facCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.facilities'.tr()),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(
                        'admin.is_main_hq'.tr(),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                      value: isMainHq,
                      activeThumbColor: AppTheme.warning,
                      onChanged: (val) => setDialogState(() => isMainHq = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('common.cancel'.tr(), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: AppTheme.media),
                  onPressed: () {
                    final newBranch = OrgVenueBranchModel(
                      venueId: branch?.venueId ?? newId(),
                      nameEn: nameEnCtrl.text.trim(),
                      nameAr: nameArCtrl.text.trim(),
                      cityEn: cityEnCtrl.text.trim(),
                      cityAr: cityArCtrl.text.trim(),
                      latitude: double.tryParse(latCtrl.text.trim()) ?? 26.2886,
                      longitude: double.tryParse(lngCtrl.text.trim()) ?? 50.2083,
                      seatingCapacity: int.tryParse(seatsCtrl.text.trim()) ?? 100,
                      isMainHeadquarters: isMainHq,
                      availableFacilities: facCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                    );
                    if (isEdit) {
                      provider.updateOrganizationBranch(widget.orgId, newBranch);
                    } else {
                      provider.addOrganizationBranch(widget.orgId, newBranch);
                    }
                    Navigator.pop(dialogCtx);
                  },
                  child: Text('common.save'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEditSpeakerDialog(
    BuildContext context,
    AppProvider provider, {
    OrgSpeakerModel? speaker,
  }) {
    final isEdit = speaker != null;
    final nameEnCtrl = TextEditingController(text: speaker?.nameEn ?? '');
    final nameArCtrl = TextEditingController(text: speaker?.nameAr ?? '');
    final roleEnCtrl = TextEditingController(text: speaker?.roleOrTitleEn ?? '');
    final roleArCtrl = TextEditingController(text: speaker?.roleOrTitleAr ?? '');
    final bioEnCtrl = TextEditingController(text: speaker?.bioEn ?? '');
    final bioArCtrl = TextEditingController(text: speaker?.bioAr ?? '');
    bool isPerm = speaker?.isPermanentStaff ?? true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                isEdit ? 'admin.edit_speaker'.tr() : 'admin.add_speaker'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameEnCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.instructor_name_en'.tr()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameArCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.instructor_name_ar'.tr()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: roleEnCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.instructor_role_en'.tr()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: roleArCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.instructor_role_ar'.tr()),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bioEnCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(labelText: 'admin.instructor_bio_en'.tr()),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: Text(
                        'admin.is_permanent_staff'.tr(),
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      ),
                      value: isPerm,
                      activeThumbColor: AppTheme.warning,
                      onChanged: (val) => setDialogState(() => isPerm = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('common.cancel'.tr(), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: AppTheme.media),
                  onPressed: () {
                    final newSpeaker = OrgSpeakerModel(
                      speakerId: speaker?.speakerId ?? newId(),
                      nameEn: nameEnCtrl.text.trim(),
                      nameAr: nameArCtrl.text.trim(),
                      roleOrTitleEn: roleEnCtrl.text.trim(),
                      roleOrTitleAr: roleArCtrl.text.trim(),
                      avatarUrl: speaker?.avatarUrl ?? 'assets/images/Dalilak/profile1.jpg',
                      bioEn: bioEnCtrl.text.trim(),
                      bioAr: bioArCtrl.text.trim(),
                      isPermanentStaff: isPerm,
                      permissions: speaker?.permissions ?? const OrgBroadcasterPermissions(),
                    );
                    if (isEdit) {
                      provider.updateOrganizationSpeaker(widget.orgId, newSpeaker);
                    } else {
                      provider.addOrganizationSpeaker(widget.orgId, newSpeaker);
                    }
                    Navigator.pop(dialogCtx);
                  },
                  child: Text('common.save'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPermissionsDialog(
    BuildContext context,
    AppProvider provider,
    OrgSpeakerModel speaker,
  ) {
    bool canVideo = speaker.permissions.canGoLiveVideo;
    bool canAudio = speaker.permissions.canGoAudioOnly;
    bool canLocation = speaker.permissions.canChangeLocation;
    bool canDesc = speaker.permissions.canEditDescription;
    bool canTime = speaker.permissions.canEditStreamTime;
    bool canLinks = speaker.permissions.canAddExternalLinks;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                '${'admin.edit_permissions'.tr()}: ${speaker.nameEn}',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text('admin.perm_can_video'.tr(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    value: canVideo,
                    activeThumbColor: AppTheme.success,
                    onChanged: (val) => setDialogState(() => canVideo = val),
                  ),
                  SwitchListTile(
                    title: Text('admin.perm_can_audio'.tr(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    value: canAudio,
                    activeThumbColor: AppTheme.primary,
                    onChanged: (val) => setDialogState(() => canAudio = val),
                  ),
                  SwitchListTile(
                    title: Text('admin.perm_can_location'.tr(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    value: canLocation,
                    activeThumbColor: AppTheme.warning,
                    onChanged: (val) => setDialogState(() => canLocation = val),
                  ),
                  SwitchListTile(
                    title: Text('admin.perm_can_description'.tr(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    value: canDesc,
                    activeThumbColor: Colors.purpleAccent,
                    onChanged: (val) => setDialogState(() => canDesc = val),
                  ),
                  SwitchListTile(
                    title: Text('admin.perm_can_time'.tr(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    value: canTime,
                    activeThumbColor: Colors.orangeAccent,
                    onChanged: (val) => setDialogState(() => canTime = val),
                  ),
                  SwitchListTile(
                    title: Text('admin.perm_can_links'.tr(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
                    value: canLinks,
                    activeThumbColor: Colors.tealAccent,
                    onChanged: (val) => setDialogState(() => canLinks = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('common.cancel'.tr(), style: const TextStyle(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning, foregroundColor: AppTheme.media),
                  onPressed: () {
                    final newPerms = OrgBroadcasterPermissions(
                      canGoLiveVideo: canVideo,
                      canGoAudioOnly: canAudio,
                      canChangeLocation: canLocation,
                      canEditDescription: canDesc,
                      canEditStreamTime: canTime,
                      canAddExternalLinks: canLinks,
                    );
                    provider.updateSpeakerPermissions(widget.orgId, speaker.speakerId, newPerms);
                    Navigator.pop(dialogCtx);
                  },
                  child: Text('common.save'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //  3. Affiliations & Join Requests Section
  Widget _buildAffiliationsSection(
    BuildContext context,
    AppProvider provider,
    List<OrgAffiliationRequestModel> affiliations,
    String langCode,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('design_ui.incoming_affiliation_requests_invites'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${affiliations.where((r) => r.isPending).length} Pending',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (affiliations.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceXl),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 36, color: AppTheme.textMuted),
                const SizedBox(height: 8),
                Text('design_ui.no_affiliation_requests_found_for_this_organization'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )
        else
          ...affiliations.map((req) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: req.isPending
                      ? AppTheme.accent.withValues(alpha: 0.4)
                      : AppTheme.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: AssetImage(req.streamerAvatarUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              req.getLocalizedStreamerName(langCode),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              req.getLocalizedProposedRole(langCode),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: req.isAccepted
                              ? AppTheme.success.withValues(alpha: 0.15)
                              : (req.isDeclined
                                  ? AppTheme.danger.withValues(alpha: 0.15)
                                  : AppTheme.warning.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          req.status.name.toUpperCase(),
                          style: TextStyle(
                            color: req.isAccepted
                                ? AppTheme.success
                                : (req.isDeclined
                                    ? AppTheme.danger
                                    : AppTheme.warning),
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (req.note.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${req.note}"',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  if (req.isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.danger,
                            side: const BorderSide(color: AppTheme.danger),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                          ),
                          onPressed: () =>
                              provider.declineOrgAffiliationRequest(req.id),
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: Text('design_ui.decline'.tr(),
                              style: const TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.success,
                            foregroundColor: AppTheme.onMedia,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                          ),
                          onPressed: () =>
                              provider.acceptOrgAffiliationRequest(req.id),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: Text('design_ui.accept_to_roster'.tr(),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }
}
