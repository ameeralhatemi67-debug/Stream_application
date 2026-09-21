/// A `banned_users` row (see
/// supabase/migrations/20260830170000_banned_users.sql), joined with the
/// banned profile's display info for the "Banned Accounts"admin manager
/// (Cluster 4 Task 16). Row presence = banned; there is no separate
/// `isActive` flag -- unbanning deletes the row, same pattern as
/// `chat_muted_users`.
class BannedUserModel {
  final String id;
  final String profileId;
  final String email;
  final String reason;
  final String? bannedBy;
  final DateTime bannedAt;
  final DateTime? expiresAt;
  final String? displayName;
  final String? avatarUrl;

  const BannedUserModel({
    required this.id,
    required this.profileId,
    required this.email,
    required this.reason,
    this.bannedBy,
    required this.bannedAt,
    this.expiresAt,
    this.displayName,
    this.avatarUrl,
  });

  bool get isPermanent => expiresAt == null;
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
}
