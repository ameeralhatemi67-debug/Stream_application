import 'org_broadcaster_permissions.dart';

enum OrgRole { owner, coOwner, manager, moderator, broadcaster }
enum OrgMembershipStatus { active, suspended, revoked, reviewRequired }

class OrgMembership {
  const OrgMembership({
    required this.organizationId,
    required this.profileId,
    required this.role,
    required this.status,
    required this.permissions,
    required this.organizationNameEn,
    required this.organizationNameAr,
    required this.nameEn,
    required this.nameAr,
  });

  final String organizationId;
  final String profileId;
  final OrgRole role;
  final OrgMembershipStatus status;
  final OrgBroadcasterPermissions permissions;
  final String organizationNameEn;
  final String organizationNameAr;
  final String nameEn;
  final String nameAr;
  bool get active => status == OrgMembershipStatus.active;
  String get roleValue => role == OrgRole.coOwner ? 'co_owner' : role.name;
  String get statusValue => status == OrgMembershipStatus.reviewRequired ? 'review_required' : status.name;
  bool get canManageMembers => active &&
      {OrgRole.owner, OrgRole.coOwner, OrgRole.manager}.contains(role);
  bool get canModerate => active &&
      {OrgRole.owner, OrgRole.coOwner, OrgRole.moderator}.contains(role);
  bool get canManageChannel => active && role == OrgRole.owner;

  factory OrgMembership.fromRow(Map<String, dynamic> row) {
    final grants = Map<String, dynamic>.from(row['permissions'] as Map? ?? {});
    // Missing grants deny access. The legacy roster model has permissive defaults.
    bool granted(String key) => grants[key] == true;
    return OrgMembership(
      organizationId: row['organization_id'] as String,
      profileId: row['profile_id'] as String,
      role: switch (row['role']) {
        'owner' => OrgRole.owner,
        'co_owner' => OrgRole.coOwner,
        'manager' => OrgRole.manager,
        'moderator' => OrgRole.moderator,
        'broadcaster' => OrgRole.broadcaster,
        _ => throw const FormatException('Unknown organization role'),
      },
      status: switch (row['status']) {
        'active' => OrgMembershipStatus.active,
        'suspended' => OrgMembershipStatus.suspended,
        'revoked' => OrgMembershipStatus.revoked,
        'review_required' => OrgMembershipStatus.reviewRequired,
        _ => throw const FormatException('Unknown membership status'),
      },
      permissions: OrgBroadcasterPermissions(
        canGoLiveVideo: granted('can_go_live_video'),
        canGoAudioOnly: granted('can_go_audio_only'),
        canChangeLocation: granted('can_change_location'),
        canEditDescription: granted('can_edit_description'),
        canEditStreamTime: granted('can_edit_stream_time'),
        canAddExternalLinks: granted('can_add_external_links'),
      ),
      organizationNameEn: row['organization_name_en'] as String? ?? '',
      organizationNameAr: row['organization_name_ar'] as String? ?? '',
      nameEn: row['name_en'] as String? ?? '',
      nameAr: row['name_ar'] as String? ?? '',
    );
  }
}
