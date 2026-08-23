/// A single user_roles grant, joined with the display info the Role &
/// Permission Management screen (v0.8 Checkpoint 2 Phase 3) needs to render
/// it -- profile_id/role/organization_id/granted_by/granted_at are the raw
/// row, displayName/email/avatarUrl come from a profiles lookup.
class AdminRoleAssignmentModel {
  final String profileId;
  final String role;
  final String? organizationId;
  final String? grantedBy;
  final DateTime grantedAt;
  final String displayName;
  final String? email;
  final String? avatarUrl;

  const AdminRoleAssignmentModel({
    required this.profileId,
    required this.role,
    this.organizationId,
    this.grantedBy,
    required this.grantedAt,
    required this.displayName,
    this.email,
    this.avatarUrl,
  });

  bool get isMasterAdmin => role == 'master_admin';
  bool get isAdmin => role == 'admin';
  bool get isPermittedAdmin => role == 'org_owner' || role == 'org_co_owner';
}

/// The capability keys the roadmap names as examples for the checkbox-style
/// grant layer (user_permissions). Not an exhaustive/enforced enum -- any
/// string is a valid permission_key in the schema -- just the known set this
/// screen offers checkboxes for.
const List<String> kKnownAdminCapabilities = [
  'edit_terms',
  'moderate_chat_platform_wide',
  'manage_admins',
];
