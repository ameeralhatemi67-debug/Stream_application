import '../../../../core/widgets/ds/ca_cards.dart';
import '../admin_surface.dart';
import '../../../../core/widgets/phone_input_guard.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/admin_role_assignment_model.dart';
import '../../models/stream_moderator_model.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';

/// Master-Admin-only Role & Permission Management tab (v0.8 Checkpoint 2
/// Phase 3). One line per email says what it can open: both admin pages, the
/// platform page, the lessons page, or everything as a master admin. Changing
/// a line applies at once, and the capability checkboxes (user_permissions)
/// sit on lines that open the platform page. Only reachable at all when
/// AppProvider.isMasterAdmin is true (see AdminHubScreen's tab gating) --
/// admin_set_email_access checks it again on the server, so this screen being
/// reachable is a UX convenience, not the security boundary.
class RolePermissionManagementView extends StatefulWidget {
  const RolePermissionManagementView({super.key});

  @override
  State<RolePermissionManagementView> createState() =>
      _RolePermissionManagementViewState();
}

class _RolePermissionManagementViewState
    extends State<RolePermissionManagementView> {
  final TextEditingController _grantEmailController = TextEditingController();
  String _grantAccess = kAdminAccessLevels.first;
  bool _isGranting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().refreshAdminEmailGrants();
    });
  }

  @override
  void dispose() {
    _grantEmailController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Canopy.liveCrimson : Canopy.leaf,
      ),
    );
  }

  Future<void> _handleAddAccess(AppProvider provider) async {
    final email = _grantEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isGranting = true);
    try {
      // An email can be named before the account exists: its access starts
      // at the first sign-in.
      final granted = await provider.setAdminAccess(email, _grantAccess);
      _grantEmailController.clear();
      _showToast(
          (granted ? 'roles.access_saved' : 'roles.access_saved_waiting').tr());
    } catch (e) {
      _showToast('roles.access_failed'.tr(), isError: true);
    } finally {
      if (mounted) setState(() => _isGranting = false);
    }
  }

  Future<void> _handleChangeAccess(
    AppProvider provider,
    AdminEmailGrant grant,
    String access,
  ) async {
    if (access == grant.access) return;
    try {
      await provider.setAdminAccess(grant.email, access);
      _showToast('roles.access_changed'.tr());
    } catch (e) {
      _showToast('roles.access_failed'.tr(), isError: true);
    }
  }

  Future<void> _handleRemoveAccess(
    AppProvider provider,
    AdminEmailGrant grant,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('roles.email_remove'.tr()),
        content: Text('roles.remove_confirm'.tr(args: [grant.email])),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('common.cancel'.tr())),
          TextButton(
              key: const ValueKey('roles-remove-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('roles.email_remove'.tr())),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await provider.removeAdminEmail(grant.email);
      _showToast('roles.email_removed'.tr());
    } catch (e) {
      _showToast('roles.revoke_failed'.tr(), isError: true);
    }
  }

  Future<void> _handleRevokeRole(
    AppProvider provider,
    AdminRoleAssignmentModel assignment,
  ) async {
    try {
      await provider.revokeAdminRole(
        profileId: assignment.profileId,
        role: assignment.role,
        organizationId: assignment.organizationId,
      );
      _showToast('roles.revoked'.tr());
    } catch (e) {
      _showToast('roles.revoke_failed'.tr(), isError: true);
    }
  }

  Future<void> _handleTogglePermission(
    AppProvider provider,
    String profileId,
    String capability,
    bool granted,
  ) async {
    try {
      await provider.setUserPermission(
        profileId: profileId,
        capability: capability,
        granted: granted,
      );
    } catch (e) {
      _showToast('roles.permission_failed'.tr(), isError: true);
    }
  }

  String _roleLabel(String role) =>
      role == 'org_owner' ? 'roles.org_owner'.tr() : 'roles.org_co_owner'.tr();

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final assignments =
        context.select<AppProvider, List<AdminRoleAssignmentModel>>(
            (p) => p.roleAssignments);

    final permittedAdmins =
        assignments.where((a) => a.isPermittedAdmin).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings_rounded,
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'design_ui.roles_permissions'.tr(),
                style: const TextStyle(
                  color: Canopy.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'design_ui.master_admin_can_grant_revoke_admin_or_master_admin_and_toggle_ex'
                .tr(),
            style: const TextStyle(color: Canopy.slate, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          _buildAddAccessCard(provider),
          const SizedBox(height: AppTheme.spaceXl),
          _buildAccessList(provider),
          const SizedBox(height: AppTheme.spaceXl),
          _buildSectionHeader('roles.owners'.tr(), permittedAdmins.length),
          const SizedBox(height: AppTheme.spaceMd),
          if (permittedAdmins.isEmpty)
            _buildEmptyRow('roles.no_owners'.tr())
          else
            ...permittedAdmins.map((a) => _buildAssignmentCard(provider, a)),
          const SizedBox(height: AppTheme.spaceXl),
          _buildModeratorDelegationSection(provider),
        ],
      ),
    );
  }

  /// Cluster 4 Task 15: audit table of every chat moderator delegation --
  /// who appointed whom, at what scope, and when -- with a revoke action.
  /// Delegation itself happens from a live chat user's profile (see
  /// LiveChatController.appointStreamModerator); this is read/audit +
  /// revoke only.
  Widget _buildModeratorDelegationSection(AppProvider provider) {
    final moderators = context.select<AppProvider, List<StreamModeratorModel>>(
        (p) => p.streamModerators);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'admin.moderator_delegation_title'.tr(), moderators.length),
        const SizedBox(height: AppTheme.spaceSm),
        Text(
          'admin.moderator_delegation_desc'.tr(),
          style: const TextStyle(color: Canopy.slate, fontSize: 12),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (moderators.isEmpty)
          _buildEmptyRow('admin.no_moderators'.tr())
        else
          AdminCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Canopy.mint),
                  columns: [
                    DataColumn(
                        label: Text('admin.moderator_col_user'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate, fontSize: 12))),
                    DataColumn(
                        label: Text('admin.moderator_col_assigned_by'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate, fontSize: 12))),
                    DataColumn(
                        label: Text('admin.moderator_col_scope'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate, fontSize: 12))),
                    DataColumn(
                        label: Text('admin.moderator_col_date'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate, fontSize: 12))),
                    DataColumn(
                        label: Text('admin.moderator_col_revoke'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate, fontSize: 12))),
                  ],
                  rows: moderators.map((m) {
                    return DataRow(cells: [
                      DataCell(Text(
                        m.moderatorEmail ?? m.moderatorDisplayName,
                        style: const TextStyle(
                            color: Canopy.ink, fontSize: 12),
                      )),
                      DataCell(Text(
                        m.assignedByDisplayName,
                        style: const TextStyle(
                            color: Canopy.slate, fontSize: 12),
                      )),
                      DataCell(Text(
                        'roles.${m.scope.name}'.tr(),
                        style: const TextStyle(
                            color: Canopy.slate, fontSize: 12),
                      )),
                      DataCell(Text(
                        DateFormat('yyyy-MM-dd').format(m.grantedAt),
                        style: const TextStyle(
                            color: Canopy.haze, fontSize: 12),
                      )),
                      DataCell(IconButton(
                        icon: const Icon(Icons.remove_circle_outline_rounded,
                            size: 18, color: Canopy.liveCrimson),
                        tooltip: 'admin.moderator_col_revoke'.tr(),
                        onPressed: () async {
                          try {
                            await provider.revokeStreamModeratorById(m.id);
                          } catch (e) {
                            _showToast('roles.revoke_failed'.tr(),
                                isError: true);
                          }
                        },
                      )),
                    ]);
                  }).toList(),
                ),
              )),
      ],
    );
  }

  /// One line per email: what it can open and whether it has signed in yet.
  Widget _buildAccessList(AppProvider provider) {
    final grants =
        context.select<AppProvider, List<AdminEmailGrant>>((p) => p.adminEmailGrants);
    final own = context
        .select<AppProvider, String?>((p) => p.currentUserEmail)
        ?.toLowerCase();
    return Column(
      key: const ValueKey('roles-admin-emails'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('roles.access_title'.tr(), grants.length),
        const SizedBox(height: AppTheme.spaceSm),
        Text('roles.access_hint'.tr(),
            style: const TextStyle(color: Canopy.slate, fontSize: 12)),
        const SizedBox(height: AppTheme.spaceMd),
        if (grants.isEmpty)
          _buildEmptyRow('roles.no_emails'.tr())
        else
          for (final g in grants)
            _buildAccessRow(provider, g, mine: g.email == own),
      ],
    );
  }

  // From the theme: a bare TextStyle here would lose the app's font.
  TextStyle? _accessMenuStyle() => Theme.of(context)
      .textTheme
      .bodyMedium
      ?.copyWith(color: Canopy.ink, fontSize: 13);

  List<DropdownMenuItem<String>> _accessItems() => [
        for (final access in kAdminAccessLevels)
          DropdownMenuItem(
              value: access,
              child: Text('roles.access_$access'.tr(),
                  overflow: TextOverflow.ellipsis)),
      ];

  Widget _buildAccessRow(AppProvider provider, AdminEmailGrant g,
      {required bool mine}) {
    final fixed = g.locked || mine;
    final profileId = g.profileId;
    final grantedPermissions = profileId == null
        ? const <String>{}
        : provider.permissionsForProfile(profileId);
    return AdminCard(
        key: ValueKey('roles-access-${g.email}'),
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              CaAvatar(
                  name: g.displayName ?? g.email,
                  url: g.avatarUrl,
                  radius: 18,
                  // Admins wear the same green ring they have in chat.
                  ring: g.access == 'lessons'
                      ? CaAvatarRing.none
                      : CaAvatarRing.admin),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    if (g.displayName != null)
                      Text(g.displayName!,
                          style: const TextStyle(
                              color: Canopy.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    Text(g.email,
                        style: const TextStyle(
                            color: Canopy.slate,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                    Text(
                        g.waiting
                            ? 'roles.email_waiting'.tr()
                            : 'roles.email_applied'.tr(args: [
                                DateFormat('yyyy-MM-dd').format(g.appliedAt!)
                              ]),
                        style: const TextStyle(
                            color: Canopy.haze, fontSize: 12)),
                  ])),
              if (!fixed)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      size: 18, color: Canopy.liveCrimson),
                  tooltip: 'roles.email_remove'.tr(),
                  onPressed: () => _handleRemoveAccess(provider, g),
                ),
            ]),
            const SizedBox(height: AppTheme.spaceSm),
            if (fixed)
              Text(
                  g.locked
                      ? 'roles.access_locked'.tr()
                      : [
                          'roles.access_${g.access}'.tr(),
                          'roles.access_you'.tr(),
                        ].join(' · '),
                  style: const TextStyle(
                      color: Canopy.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))
            else
              DropdownButton<String>(
                key: ValueKey('roles-access-menu-${g.email}'),
                isExpanded: true,
                value: g.access,
                dropdownColor: Canopy.mint,
                style: _accessMenuStyle(),
                items: _accessItems(),
                onChanged: (value) {
                  if (value != null) _handleChangeAccess(provider, g, value);
                },
              ),
            if (profileId != null && g.platformPage) ...[
              const SizedBox(height: AppTheme.spaceSm),
              const Divider(color: Canopy.hairline, height: 1),
              const SizedBox(height: AppTheme.spaceSm),
              Wrap(
                spacing: AppTheme.spaceMd,
                runSpacing: 4,
                children: kKnownAdminCapabilities.map((capability) {
                  final granted = grantedPermissions.contains(capability);
                  return InkWell(
                    onTap: () => _handleTogglePermission(
                        provider, profileId, capability, !granted),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: granted,
                          activeColor: Canopy.leaf,
                          onChanged: (checked) => _handleTogglePermission(
                              provider, profileId, capability, checked == true),
                        ),
                        Flexible(
                            child: Text(
                          'roles.$capability'.tr(),
                          style: const TextStyle(
                              color: Canopy.slate, fontSize: 12),
                        )),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ));
  }

  Widget _buildSectionHeader(String title, int count) {
    return Wrap(
      spacing: AppTheme.spaceSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Canopy.ink,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Canopy.mint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Canopy.slate,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRow(String message) {
    return AdminCard(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Text(message,
            style:
                const TextStyle(color: Canopy.slate, fontSize: 12)));
  }

  Widget _buildAddAccessCard(AppProvider provider) {
    return AdminCard(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'roles.add_title'.tr(),
              style: const TextStyle(
                color: Canopy.ink,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  child: PhoneInputGuard(builder: (context, blocked) => TextField(
                            readOnly: blocked,
                            controller: _grantEmailController,
                            style: const TextStyle(
                                color: Canopy.ink, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'roles.email'.tr(),
                              hintStyle: const TextStyle(
                                  color: Canopy.slate, fontSize: 12),
                              prefixIcon: const Icon(Icons.email_outlined,
                                  color: Canopy.slate, size: 18),
                              filled: true,
                              fillColor: Canopy.mint,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                                borderSide:
                                    const BorderSide(color: Canopy.hairline),
                              ),
                            ),
                          )),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                DropdownButton<String>(
                  key: const ValueKey('roles-add-access'),
                  isExpanded: true,
                  value: _grantAccess,
                  dropdownColor: Canopy.mint,
                  style: _accessMenuStyle(),
                  items: _accessItems(),
                  onChanged: (value) {
                    if (value != null) setState(() => _grantAccess = value);
                  },
                ),
                const SizedBox(height: AppTheme.spaceMd),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onMedia,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                  icon: _isGranting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: HadayahLoadingIndicator(
                              strokeWidth: 2, color: AppTheme.onMedia),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: Text('roles.add_button'.tr()),
                  onPressed:
                      _isGranting ? null : () => _handleAddAccess(provider),
                ),
              ],
            ),
          ],
        ));
  }

  Widget _buildAssignmentCard(
      AppProvider provider, AdminRoleAssignmentModel assignment) {
    const tierColor = AppTheme.accent;

    return AdminCard(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppTheme.spaceSm,
              runSpacing: AppTheme.spaceSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CaAvatar(
                  name: assignment.displayName,
                  url: assignment.avatarUrl,
                  radius: 18,
                ),
                const SizedBox(width: AppTheme.spaceMd),
                SizedBox(
                  width: 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assignment.displayName,
                        style: const TextStyle(
                          color: Canopy.ink,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      if (assignment.email != null)
                        Text(
                          assignment.email!,
                          style: const TextStyle(
                              color: Canopy.haze, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: tierColor.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    _roleLabel(assignment.role),
                    style: const TextStyle(
                      color: tierColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      size: 18, color: Canopy.liveCrimson),
                  tooltip: 'roles.revoke'.tr(),
                  onPressed: () => _handleRevokeRole(provider, assignment),
                ),
              ],
            ),
          ],
        ));
  }
}
