/// Moderation status of one entry in `public.tags` (see
/// supabase/migrations/20260830140000_tags_taxonomy.sql). `approved` tags are
/// suggested on the streamer application form and shown in the discovery
/// filter sheet; `pending` tags await admin review; `blacklisted` tags are
/// hidden and never suggested again.
enum TagStatus { approved, pending, blacklisted }

extension TagStatusInfo on TagStatus {
  String get dbValue => name;

  static TagStatus fromDbValue(String value) {
    return TagStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => TagStatus.pending,
    );
  }
}

/// A single `tags` row, for the admin "Tag Moderation Manager" (Cluster 3
/// Task 12).
class TagModerationModel {
  final String name;
  final TagStatus status;
  final DateTime createdAt;

  const TagModerationModel({
    required this.name,
    required this.status,
    required this.createdAt,
  });

  factory TagModerationModel.fromRow(Map<String, dynamic> row) {
    return TagModerationModel(
      name: row['name'] as String,
      status: TagStatusInfo.fromDbValue(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}
