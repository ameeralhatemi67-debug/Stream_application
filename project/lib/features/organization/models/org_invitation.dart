/// A pending organization invitation: either addressed to the signed-in
/// account (`org_v1_my_invitations`) or listed for leadership
/// (`org_v1_invitations`). Tokens are never part of either listing.
class OrgInvitation {
  const OrgInvitation({
    required this.id,
    required this.role,
    required this.expiresAt,
    this.organizationId,
    this.organizationNameEn = '',
    this.organizationNameAr = '',
    this.email,
    this.invitedByEn = '',
    this.invitedByAr = '',
    this.video = false,
    this.audio = false,
  });

  final String id;
  final String role;
  final DateTime expiresAt;
  final String? organizationId;
  final String organizationNameEn;
  final String organizationNameAr;
  final String? email;
  final String invitedByEn;
  final String invitedByAr;
  final bool video;
  final bool audio;

  String organizationName(String language) => language == 'ar' && organizationNameAr.isNotEmpty
      ? organizationNameAr
      : (organizationNameEn.isNotEmpty ? organizationNameEn : organizationNameAr);

  factory OrgInvitation.fromRow(Map<String, dynamic> row) {
    final grants = Map<String, dynamic>.from(row['permissions'] as Map? ?? const {});
    return OrgInvitation(
      id: row['id'] as String,
      role: row['role'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String),
      organizationId: row['organization_id'] as String?,
      organizationNameEn: row['organization_name_en'] as String? ?? '',
      organizationNameAr: row['organization_name_ar'] as String? ?? '',
      email: row['email'] as String?,
      invitedByEn: row['invited_by_en'] as String? ?? '',
      invitedByAr: row['invited_by_ar'] as String? ?? '',
      video: grants['can_go_live_video'] == true,
      audio: grants['can_go_audio_only'] == true,
    );
  }
}
