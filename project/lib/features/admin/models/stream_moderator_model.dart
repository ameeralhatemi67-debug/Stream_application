/// Scope of a chat moderator delegation -- see `stream_moderators`
/// (supabase/migrations/20260830160000_stream_moderators.sql).
enum ModeratorScope { stream, organization, global }

extension ModeratorScopeInfo on ModeratorScope {
  String get dbValue => name;

  static ModeratorScope fromDbValue(String value) {
    return ModeratorScope.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => ModeratorScope.stream,
    );
  }

  String get labelEn {
    switch (this) {
      case ModeratorScope.stream:
        return 'Stream';
      case ModeratorScope.organization:
        return 'Organization';
      case ModeratorScope.global:
        return 'Global';
    }
  }
}

/// A `stream_moderators` row joined with display info, for the "Stream
/// Moderator Labels & Delegation" audit table (Cluster 4 Task 15).
class StreamModeratorModel {
  final String id;
  final String profileId;
  final String assignedBy;
  final ModeratorScope scope;
  final String? streamId;
  final String? organizationId;
  final DateTime grantedAt;
  final String moderatorDisplayName;
  final String? moderatorEmail;
  final String assignedByDisplayName;

  const StreamModeratorModel({
    required this.id,
    required this.profileId,
    required this.assignedBy,
    required this.scope,
    this.streamId,
    this.organizationId,
    required this.grantedAt,
    required this.moderatorDisplayName,
    this.moderatorEmail,
    required this.assignedByDisplayName,
  });

  String get scopeLabel {
    switch (scope) {
      case ModeratorScope.stream:
        return 'Stream: ${streamId ?? '-'}';
      case ModeratorScope.organization:
        return 'Organization';
      case ModeratorScope.global:
        return 'Global (Platform-Wide)';
    }
  }
}
