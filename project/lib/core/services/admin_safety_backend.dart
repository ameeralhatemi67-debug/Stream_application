import 'package:supabase_flutter/supabase_flutter.dart';

/// A broadcaster the server currently marks live (P6 admin live list).
class LiveBroadcastRow {
  const LiveBroadcastRow({
    required this.profileId,
    required this.name,
    required this.broadcastType,
    required this.streamId,
    this.email,
    this.viewerCount,
  });

  final String profileId;
  final String name;
  final String? email;
  final String broadcastType;
  final String streamId;

  /// Null when the count could not be read; never guessed.
  final int? viewerCount;
}

class AdminAuditEntry {
  const AdminAuditEntry({
    required this.id,
    required this.action,
    required this.actorName,
    required this.actorEmail,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.createdAt,
    this.organizationId,
    this.metadata = const {},
  });

  final String id;
  final String action;
  final String actorName;
  final String actorEmail;
  final String descriptionEn;
  final String descriptionAr;
  final DateTime createdAt;
  final String? organizationId;
  final Map<String, dynamic> metadata;

  factory AdminAuditEntry.fromRow(Map<String, dynamic> r) => AdminAuditEntry(
        id: r['id'] as String,
        action: r['action'] as String,
        actorName: (r['actor_name'] as String?) ?? '',
        actorEmail: (r['actor_email'] as String?) ?? '',
        descriptionEn: (r['description_en'] as String?) ?? '',
        descriptionAr: (r['description_ar'] as String?) ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
        organizationId: r['organization_id'] as String?,
        metadata: (r['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}

class AuditPage {
  const AuditPage(this.entries, {required this.hasMore});
  final List<AdminAuditEntry> entries;
  final bool hasMore;
}

class BlocklistKeyword {
  const BlocklistKeyword({
    required this.id,
    required this.keyword,
    required this.matchMode,
    required this.createdAt,
  });

  final String id;
  final String keyword;

  /// `word` or `substring` (20260921120000).
  final String matchMode;
  final DateTime createdAt;
}

enum AdminSafetyFailure { notPermitted, invalid, duplicate, network }

class AdminSafetyException implements Exception {
  const AdminSafetyException(this.failure);
  final AdminSafetyFailure failure;
  @override
  String toString() => 'AdminSafetyException($failure)';

  static AdminSafetyException from(Object e) {
    if (e is AdminSafetyException) return e;
    if (e is PostgrestException) {
      return AdminSafetyException(switch (e.code) {
        '42501' => AdminSafetyFailure.notPermitted,
        '23505' => AdminSafetyFailure.duplicate,
        '23514' || '22023' || '23502' => AdminSafetyFailure.invalid,
        _ => e.message.contains('row-level security')
            ? AdminSafetyFailure.notPermitted
            : AdminSafetyFailure.network,
      });
    }
    return const AdminSafetyException(AdminSafetyFailure.network);
  }
}

/// Reads and writes behind the admin Safety tab. Every call is admin-tier
/// RLS or a SECURITY DEFINER function on the server; nothing here falls back
/// to local or sample data, so an unreachable backend shows as an error.
abstract class AdminSafetyBackend {
  Future<List<LiveBroadcastRow>> loadLiveBroadcasts();
  Future<AuditPage> loadAudit({String? action, int offset = 0});
  Future<List<BlocklistKeyword>> loadKeywords();
  Future<void> addKeyword(String keyword, String matchMode);
  Future<void> setKeywordMode(String id, String matchMode);
  Future<void> removeKeyword(String id);
}

class SupabaseAdminSafetyBackend implements AdminSafetyBackend {
  const SupabaseAdminSafetyBackend();

  static const auditPageSize = 50;

  SupabaseClient get _client => Supabase.instance.client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      throw AdminSafetyException.from(e);
    }
  }

  @override
  Future<List<LiveBroadcastRow>> loadLiveBroadcasts() => _guard(() async {
        // Expire flags whose device stopped heartbeating, so the list does not
        // offer to end a broadcast that has already stopped.
        try {
          await _client.rpc('sweep_stale_live_flags');
        } catch (_) {}
        final rows = await _client
            .from('profiles')
            .select(
                'id, display_name_en, email, broadcast_type, active_stream_id')
            .eq('is_currently_live', true)
            .order('display_name_en');
        final list = (rows as List).cast<Map<String, dynamic>>();
        final streamIds = [
          for (final r in list)
            if (r['active_stream_id'] != null) r['active_stream_id'] as String,
        ];
        final counts = <String, int>{};
        if (streamIds.isNotEmpty) {
          try {
            final res = await _client.rpc('get_viewer_counts',
                params: {'p_stream_ids': streamIds});
            for (final c in (res as List).cast<Map<String, dynamic>>()) {
              counts[c['stream_id'] as String] = c['viewer_count'] as int;
            }
          } catch (_) {}
        }
        return [
          for (final r in list)
            LiveBroadcastRow(
              profileId: r['id'] as String,
              name: (r['display_name_en'] as String?) ??
                  (r['email'] as String?) ??
                  '',
              email: r['email'] as String?,
              broadcastType: r['broadcast_type'] as String,
              streamId: (r['active_stream_id'] as String?) ?? '',
              viewerCount: counts[r['active_stream_id']],
            ),
        ];
      });

  @override
  Future<AuditPage> loadAudit({String? action, int offset = 0}) =>
      _guard(() async {
        var query = _client.from('audit_logs').select();
        if (action != null) query = query.eq('action', action);
        final rows = await query
            .order('created_at', ascending: false)
            .range(offset, offset + auditPageSize);
        final list = (rows as List)
            .cast<Map<String, dynamic>>()
            .map(AdminAuditEntry.fromRow)
            .toList();
        final hasMore = list.length > auditPageSize;
        return AuditPage(
          hasMore ? list.sublist(0, auditPageSize) : list,
          hasMore: hasMore,
        );
      });

  @override
  Future<List<BlocklistKeyword>> loadKeywords() => _guard(() async {
        final rows = await _client
            .from('chat_banned_keywords')
            .select('id, keyword, match_mode, created_at')
            .order('keyword');
        return [
          for (final r in (rows as List).cast<Map<String, dynamic>>())
            BlocklistKeyword(
              id: r['id'] as String,
              keyword: r['keyword'] as String,
              matchMode: (r['match_mode'] as String?) ?? 'word',
              createdAt: DateTime.parse(r['created_at'] as String),
            ),
        ];
      });

  @override
  Future<void> addKeyword(String keyword, String matchMode) =>
      _guard(() => _client
          .from('chat_banned_keywords')
          .insert({'keyword': keyword, 'match_mode': matchMode}));

  /// RLS turns a refused update or delete into zero affected rows rather than
  /// an error, so both ask for the rows back and treat none as a refusal.
  @override
  Future<void> setKeywordMode(String id, String matchMode) =>
      _guard(() async {
        final rows = await _client
            .from('chat_banned_keywords')
            .update({'match_mode': matchMode})
            .eq('id', id)
            .select('id');
        if ((rows as List).isEmpty) {
          throw const AdminSafetyException(AdminSafetyFailure.notPermitted);
        }
      });

  @override
  Future<void> removeKeyword(String id) => _guard(() async {
        final rows = await _client
            .from('chat_banned_keywords')
            .delete()
            .eq('id', id)
            .select('id');
        if ((rows as List).isEmpty) {
          throw const AdminSafetyException(AdminSafetyFailure.notPermitted);
        }
      });
}
