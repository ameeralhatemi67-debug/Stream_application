/// A server-written Organization V1 event addressed to the signed-in account
/// (`public.org_v1_events`). The kind decides where it navigates.
class OrgEvent {
  const OrgEvent({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.organizationId,
    this.sessionId,
    this.invitationId,
    this.payload = const {},
    this.readAt,
  });

  final String id;
  final String kind;
  final String? organizationId;
  final String? sessionId;
  final String? invitationId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt;

  static const kinds = {
    'invitation', 'invitation_answered', 'join_request', 'join_request_answered',
    'assignment', 'assignment_changed', 'assignment_cancelled', 'assignment_answered',
    'assignment_reminder', 'membership_changed', 'show_live', 'show_ending',
    'transfer_proposed', 'transfer_cancelled', 'transfer_completed',
  };

  bool get read => readAt != null;
  bool get liveAlert => kind == 'show_live';

  String text(String key, String language) {
    final value = payload['${key}_${language == 'ar' ? 'ar' : 'en'}'];
    final fallback = payload['${key}_${language == 'ar' ? 'en' : 'ar'}'];
    final first = value is String ? value.trim() : '';
    return first.isNotEmpty ? first : (fallback is String ? fallback.trim() : '');
  }

  String organizationName(String language) => text('organization_name', language);
  String title(String language) => text('title', language);
  bool get accepted => payload['accepted'] == true;
  String? get role => payload['role'] as String?;

  /// In-app destination. Live alerts open the exact session room.
  String get route => switch (kind) {
        'invitation' => invitationId == null ? '/organizations' : '/org-invite/$invitationId',
        'show_live' => sessionId == null ? '/organizations' : '/live/$sessionId',
        'assignment' || 'assignment_changed' || 'assignment_cancelled' ||
        'assignment_answered' || 'assignment_reminder' || 'show_ending' => '/shows',
        _ => '/organizations',
      };

  factory OrgEvent.fromRow(Map<String, dynamic> row) {
    final kind = row['kind'] as String;
    if (!kinds.contains(kind)) throw const FormatException('Unknown organization event');
    return OrgEvent(
      id: row['id'] as String,
      kind: kind,
      organizationId: row['organization_id'] as String?,
      sessionId: row['session_id'] as String?,
      invitationId: row['invitation_id'] as String?,
      payload: Map<String, dynamic>.from(row['payload'] as Map? ?? const {}),
      createdAt: DateTime.parse(row['created_at'] as String),
      readAt: row['read_at'] == null ? null : DateTime.parse(row['read_at'] as String),
    );
  }
}
