/// One aggregated row in the admin "Muted Chatters Audit Log" (Cluster 4
/// Tasks 13 & 15) -- built by grouping `public.chat_mute_audit_log` by
/// profile_id, since that table itself is one row per mute *action*.
class ChatMuteAuditEntry {
  final String profileId;
  final String displayName;
  final String? email;

  /// Count of distinct stream_id values this profile has been muted in
  /// (not the number of mute actions -- being re-muted in the same stream
  /// only counts once).
  final int streamsMutedCount;

  /// Reason/trigger of the most recent mute action.
  final String lastReason;

  /// This chatter's last messages sent prior to their most recent mute,
  /// oldest first, capped at 3.
  final List<String> lastMessages;

  final DateTime lastMutedAt;

  const ChatMuteAuditEntry({
    required this.profileId,
    required this.displayName,
    this.email,
    required this.streamsMutedCount,
    required this.lastReason,
    required this.lastMessages,
    required this.lastMutedAt,
  });
}
