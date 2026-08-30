import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/admin_role_assignment_model.dart';
import '../../models/stream_moderator_model.dart';

/// Master-Admin-only Role & Permission Management tab (v0.8 Checkpoint 2
/// Phase 3). Lets a Master Admin view every user_roles grant, promote a
/// profile to Admin/Master Admin (or revoke), and toggle the checkbox-style
/// capability grants (user_permissions) from Checkpoint 1 Phase 2. Only
/// reachable at all when AppProvider.isMasterAdmin is true (see
/// AdminHubScreen's tab gating) -- write access is also enforced server-side
/// by the master_admin-only RLS policies from 20260827090000/100000, so this
/// screen being reachable is a UX convenience, not the security boundary.
class RolePermissionManagementView extends StatefulWidget {
  const RolePermissionManagementView({super.key});

  @override
  State<RolePermissionManagementView> createState() =>
      _RolePermissionManagementViewState();
}

class _RolePermissionManagementViewState
    extends State<RolePermissionManagementView> {
  final TextEditingController _grantEmailController = TextEditingController();
  String _grantRole = 'admin';
  bool _isGranting = false;

  @override
  void dispose() {
    _grantEmailController.dispose();
    super.dispose();
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? AppTheme.accentRed : AppTheme.accentGreen,
      ),
    );
  }

  Future<void> _handleGrantRole(AppProvider provider) async {
    final email = _grantEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isGranting = true);
    try {
      final profile = await provider.findProfileByEmail(email);
      if (profile == null) {
        _showToast(
          'No account found for "$email" -- they must sign in at least once before a role can be granted.',
          isError: true,
        );
        return;
      }
      await provider.grantAdminRole(
        profileId: profile['id'] as String,
        role: _grantRole,
      );
      _grantEmailController.clear();
      _showToast('${_grantRole == 'master_admin' ? 'Master Admin' : 'Admin'} role granted to $email.');
    } catch (e) {
      _showToast('Failed to grant role: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isGranting = false);
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
      _showToast('${assignment.displayName}\'s ${_roleLabel(assignment.role)} role revoked.');
    } catch (e) {
      _showToast('Failed to revoke role: $e', isError: true);
    }
  }

  Future<void> _handleTogglePermission(
    AppProvider provider,
    AdminRoleAssignmentModel assignment,
    String capability,
    bool granted,
  ) async {
    try {
      await provider.setUserPermission(
        profileId: assignment.profileId,
        capability: capability,
        granted: granted,
      );
    } catch (e) {
      _showToast('Failed to update permission: $e', isError: true);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'master_admin':
        return 'Master Admin';
      case 'admin':
        return 'Admin';
      case 'org_owner':
        return 'Permitted Admin (Org Owner)';
      case 'org_co_owner':
        return 'Permitted Admin (Co-Owner)';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'master_admin':
        return AppTheme.accentRed;
      case 'admin':
        return AppTheme.accentBlue;
      default:
        return AppTheme.accentPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final assignments =
        context.select<AppProvider, List<AdminRoleAssignmentModel>>(
            (p) => p.roleAssignments);

    final masterAdmins =
        assignments.where((a) => a.role == 'master_admin').toList();
    final admins = assignments.where((a) => a.role == 'admin').toList();
    final permittedAdmins = assignments.where((a) => a.isPermittedAdmin).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded,
                  color: AppTheme.accentBlue, size: 20),
              SizedBox(width: 8),
              Text(
                'Roles & Permissions',
                style: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          const Text(
            'Master Admin can grant/revoke Admin or Master Admin, and toggle extra capability checkboxes. Permitted Admin (Org Owner/Co-Owner) is auto-derived from organization ownership -- see the Organizations tab.',
            style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          _buildGrantRoleCard(provider),
          const SizedBox(height: AppTheme.spaceXl),

          _buildSectionHeader('Master Admins', masterAdmins.length),
          const SizedBox(height: AppTheme.spaceMd),
          if (masterAdmins.isEmpty)
            _buildEmptyRow('No Master Admins yet.')
          else
            ...masterAdmins.map((a) => _buildAssignmentCard(provider, a)),

          const SizedBox(height: AppTheme.spaceXl),
          _buildSectionHeader('Admins', admins.length),
          const SizedBox(height: AppTheme.spaceMd),
          if (admins.isEmpty)
            _buildEmptyRow('No Admins yet.')
          else
            ...admins.map((a) => _buildAssignmentCard(provider, a)),

          const SizedBox(height: AppTheme.spaceXl),
          _buildSectionHeader('Permitted Admins (Org Owners & Co-Owners)',
              permittedAdmins.length),
          const SizedBox(height: AppTheme.spaceMd),
          if (permittedAdmins.isEmpty)
            _buildEmptyRow('No organization owners yet.')
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
          style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (moderators.isEmpty)
          _buildEmptyRow('admin.no_moderators'.tr())
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkSurface1,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.darkBorderSubtle),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AppTheme.darkSurface2),
                columns: [
                  DataColumn(
                      label: Text('admin.moderator_col_user'.tr(),
                          style: const TextStyle(
                              color: AppTheme.textSecondaryDark, fontSize: 11))),
                  DataColumn(
                      label: Text('admin.moderator_col_assigned_by'.tr(),
                          style: const TextStyle(
                              color: AppTheme.textSecondaryDark, fontSize: 11))),
                  DataColumn(
                      label: Text('admin.moderator_col_scope'.tr(),
                          style: const TextStyle(
                              color: AppTheme.textSecondaryDark, fontSize: 11))),
                  DataColumn(
                      label: Text('admin.moderator_col_date'.tr(),
                          style: const TextStyle(
                              color: AppTheme.textSecondaryDark, fontSize: 11))),
                  DataColumn(
                      label: Text('admin.moderator_col_revoke'.tr(),
                          style: const TextStyle(
                              color: AppTheme.textSecondaryDark, fontSize: 11))),
                ],
                rows: moderators.map((m) {
                  return DataRow(cells: [
                    DataCell(Text(
                      m.moderatorEmail ?? m.moderatorDisplayName,
                      style: const TextStyle(
                          color: AppTheme.textPrimaryDark, fontSize: 12),
                    )),
                    DataCell(Text(
                      m.assignedByDisplayName,
                      style: const TextStyle(
                          color: AppTheme.textSecondaryDark, fontSize: 12),
                    )),
                    DataCell(Text(
                      m.scopeLabel,
                      style: const TextStyle(
                          color: AppTheme.textSecondaryDark, fontSize: 12),
                    )),
                    DataCell(Text(
                      DateFormat('yyyy-MM-dd').format(m.grantedAt),
                      style: const TextStyle(
                          color: AppTheme.textMutedDark, fontSize: 11),
                    )),
                    DataCell(IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded,
                          size: 18, color: AppTheme.accentRed),
                      tooltip: 'admin.moderator_col_revoke'.tr(),
                      onPressed: () async {
                        try {
                          await provider.revokeStreamModeratorById(m.id);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('$e'),
                                backgroundColor: AppTheme.accentRed),
                          );
                        }
                      },
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimaryDark,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRow(String message) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Text(message,
          style: const TextStyle(
              color: AppTheme.textSecondaryDark, fontSize: 12)),
    );
  }

  Widget _buildGrantRoleCard(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grant a Platform Role',
            style: TextStyle(
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _grantEmailController,
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Account email...',
                    hintStyle: const TextStyle(
                        color: AppTheme.textSecondaryDark, fontSize: 12),
                    prefixIcon: const Icon(Icons.email_outlined,
                        color: AppTheme.textSecondaryDark, size: 18),
                    filled: true,
                    fillColor: AppTheme.darkSurface2,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide:
                          const BorderSide(color: AppTheme.darkBorderSubtle),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              DropdownButton<String>(
                value: _grantRole,
                dropdownColor: AppTheme.darkSurface2,
                style: const TextStyle(
                    color: AppTheme.textPrimaryDark, fontSize: 13),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(
                      value: 'master_admin', child: Text('Master Admin')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _grantRole = value);
                },
              ),
              const SizedBox(width: AppTheme.spaceMd),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                icon: _isGranting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Grant'),
                onPressed:
                    _isGranting ? null : () => _handleGrantRole(provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(
      AppProvider provider, AdminRoleAssignmentModel assignment) {
    final tierColor = _roleColor(assignment.role);
    final canTogglePermissions =
        assignment.role == 'master_admin' || assignment.role == 'admin';
    final grantedPermissions = provider.permissionsForProfile(assignment.profileId);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface1,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: tierColor.withValues(alpha: 0.15),
                backgroundImage: (assignment.avatarUrl != null &&
                        assignment.avatarUrl!.isNotEmpty)
                    ? NetworkImage(assignment.avatarUrl!)
                    : null,
                child: (assignment.avatarUrl == null ||
                        assignment.avatarUrl!.isEmpty)
                    ? Icon(Icons.person_rounded, color: tierColor, size: 18)
                    : null,
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.displayName,
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (assignment.email != null)
                      Text(
                        assignment.email!,
                        style: const TextStyle(
                            color: AppTheme.textMutedDark, fontSize: 11),
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
                  style: TextStyle(
                    color: tierColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: AppTheme.accentRed),
                tooltip: 'Revoke role',
                onPressed: () => _handleRevokeRole(provider, assignment),
              ),
            ],
          ),
          if (canTogglePermissions) ...[
            const SizedBox(height: AppTheme.spaceSm),
            const Divider(color: AppTheme.darkBorderSubtle, height: 1),
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: AppTheme.spaceMd,
              runSpacing: 4,
              children: kKnownAdminCapabilities.map((capability) {
                final granted = grantedPermissions.contains(capability);
                return InkWell(
                  onTap: () => _handleTogglePermission(
                      provider, assignment, capability, !granted),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: granted,
                        activeColor: AppTheme.accentGreen,
                        onChanged: (checked) => _handleTogglePermission(
                            provider, assignment, capability, checked == true),
                      ),
                      Text(
                        capability,
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 11.5),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
