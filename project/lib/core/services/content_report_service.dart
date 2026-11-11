import 'package:supabase_flutter/supabase_flutter.dart';

/// What a report is about: one broadcast or recording, or a whole channel.
enum ContentReportKind { stream, channel }

/// The reasons a viewer can pick. The codes are the ones the database
/// accepts (`content_reports.reason`).
abstract final class ContentReportReason {
  static const wrongTeaching = 'wrong_teaching';
  static const hateSpeech = 'hate_speech';
  static const harassment = 'harassment';
  static const inappropriate = 'inappropriate';
  static const spam = 'spam';
  static const impersonation = 'impersonation';
  static const other = 'other';

  static const all = [
    wrongTeaching,
    hateSpeech,
    harassment,
    inappropriate,
    spam,
    impersonation,
    other
  ];

  /// The translation key of a stored reason.
  static String labelKey(String reason) =>
      'lantern.report.reason_${all.contains(reason) ? reason : other}';
}

/// One row of the queue admin tiers read.
class ContentReport {
  const ContentReport(
      {required this.id,
      required this.kind,
      required this.channelProfileId,
      required this.reporterId,
      required this.reason,
      required this.createdAt,
      this.streamId,
      this.note});

  factory ContentReport.fromRow(Map<String, dynamic> row) => ContentReport(
      id: row['id'] as String,
      kind: row['target_kind'] == 'stream'
          ? ContentReportKind.stream
          : ContentReportKind.channel,
      channelProfileId: row['channel_profile_id'] as String,
      streamId: row['stream_id'] as String?,
      reporterId: row['reporter_id'] as String,
      reason: row['reason'] as String,
      note: row['note'] as String?,
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ?? DateTime.now());

  final String id, channelProfileId, reporterId, reason;
  final ContentReportKind kind;
  final String? streamId, note;
  final DateTime createdAt;
}

/// What the person who reported is told.
enum ContentReportOutcome { sent, already, signIn, tooMany, failed }

/// Reports of a broadcast or a channel (`content_reports`, migration
/// 20261111120000). Row-level security lets a signed-in person add a report
/// as themselves and lets only admin tiers read or clear the queue.
class ContentReportService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> submit(
          {required ContentReportKind kind,
          required String channelProfileId,
          required String reason,
          String? streamId,
          String? note}) =>
      _client.from('content_reports').insert({
        'target_kind': kind.name,
        'channel_profile_id': channelProfileId,
        if (streamId != null) 'stream_id': streamId,
        'reason': reason,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      });

  /// The newest 200 reports. Empty for anyone who is not an admin tier.
  Future<List<ContentReport>> loadOpen() async {
    final rows = await _client
        .from('content_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(200);
    return [for (final row in rows) ContentReport.fromRow(row)];
  }

  /// Clears a report after it was acted on.
  Future<void> dismiss(String id) =>
      _client.from('content_reports').delete().eq('id', id);
}
