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

  /// How many broadcasters (individual profiles + organizations) currently
  /// carry this tag. Not a `tags` table column -- resolved separately via
  /// AdminDatabaseService.countBroadcastersForTag and merged in by
  /// AppProvider, since it's a count over `profiles.tags` /
  /// `organizations.tags`, not the taxonomy row itself.
  final int usageCount;

  const TagModerationModel({
    required this.name,
    required this.status,
    required this.createdAt,
    this.usageCount = 0,
  });

  TagModerationModel copyWith({int? usageCount}) => TagModerationModel(
        name: name,
        status: status,
        createdAt: createdAt,
        usageCount: usageCount ?? this.usageCount,
      );

  factory TagModerationModel.fromRow(Map<String, dynamic> row) {
    return TagModerationModel(
      name: row['name'] as String,
      status: TagStatusInfo.fromDbValue(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }
}

/// Minimal broadcaster summary for the tag "Inspect Broadcasters" drill-down
/// (Cluster 3 Task 12) -- deliberately not a full StreamerModel, since the
/// modal only ever needs enough to show a tappable row.
class TaggedBroadcasterSummary {
  final String id;
  final String nameEn;
  final String nameAr;
  final String avatarUrl;
  final bool isOrganization;

  const TaggedBroadcasterSummary({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.avatarUrl,
    required this.isOrganization,
  });
}
