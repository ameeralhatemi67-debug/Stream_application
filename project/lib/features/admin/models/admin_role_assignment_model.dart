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

  bool get isPermittedAdmin => role == 'org_owner' || role == 'org_co_owner';
}

/// What a master admin can give an email, in the order the screen offers them
/// (admin_email_grants.access).
const List<String> kAdminAccessLevels = ['both', 'platform', 'lessons', 'master'];

/// One email's admin access. [appliedAt] is set once the account has signed
/// in, [profileId] and [displayName] once it exists. A [locked] line is the
/// owner's and cannot change.
class AdminEmailGrant {
  const AdminEmailGrant(
      {required this.email,
      required this.access,
      required this.createdAt,
      this.appliedAt,
      this.locked = false,
      this.profileId,
      this.displayName,
      this.avatarUrl});
  final String email;
  final String access;
  final DateTime createdAt;
  final DateTime? appliedAt;
  final bool locked;
  final String? profileId, displayName, avatarUrl;
  bool get waiting => appliedAt == null;

  /// Opens the platform admin page, where capability checkboxes apply.
  bool get platformPage => access == 'both' || access == 'platform';

  factory AdminEmailGrant.fromRow(Map<String, dynamic> row,
          {Map<String, dynamic>? profile}) =>
      AdminEmailGrant(
          email: row['email'] as String,
          access: row['access'] as String? ?? 'both',
          createdAt: DateTime.parse(row['created_at'] as String),
          appliedAt: row['applied_at'] == null
              ? null
              : DateTime.parse(row['applied_at'] as String),
          locked: row['locked'] as bool? ?? false,
          profileId: row['applied_profile_id'] as String?,
          displayName: profile?['display_name_en'] as String?,
          avatarUrl: profile?['avatar_url'] as String?);
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
