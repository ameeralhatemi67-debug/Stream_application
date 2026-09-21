import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/id_generator.dart';
import '../models/chat_message_model.dart';

enum ChatConnectionState { connecting, live, reconnecting }

/// Why the composer is (or is not) usable right now (P6.2). Every value maps
/// to a real server-side rule, so the composer can explain itself instead of
/// letting the viewer type into a box whose insert is going to be refused:
///
/// * [banned]        `banned_users` / the restrictive `*_not_banned` policies.
/// * [guest]         `chat_messages_insert_own` needs `auth.uid()`.
/// * [chatDisabled]  `chat_stream_settings.chat_enabled = false`, enforced by
///                   the `chat_enforce_rate_limit` trigger (P6.1). Moderators
///                   are exempt, so a broadcaster can still speak.
/// * [muted]         `chat_muted_users`, enforced by the insert policy.
/// * [offline]       Realtime is not connected, so a send would be a guess.
/// * [slowMode]      `chat_stream_settings.slow_mode_seconds` has not elapsed
///                   since this viewer's own last message.
/// * [ready]         Nothing is in the way.
///
/// Ordered by precedence in [LiveChatController.composerState]: an absolute
/// block outranks a transient one, so a banned account is never told to wait
/// out a slow-mode countdown.
enum ChatComposerState {
  banned,
  guest,
  chatDisabled,
  muted,
  offline,
  slowMode,
  ready,
}

/// Owns a single stream's live chat: loads recent history, subscribes to new
/// messages over Supabase Realtime, and sends new ones. One instance per
/// LiveBroadcastScreen (created in initState, disposed with the screen) --
/// deliberately not part of AppProvider, since this is per-stream-screen
/// state, not app-wide state.
///
/// Realtime channel naming convention: `chat:<streamId>` (see
/// supabase/migrations/20260823090000_chat_messages.sql) -- the same channel
/// Checkpoint 2 reuses for ephemeral broadcast reactions (never persisted --
/// no reason to store millions of reaction rows against the free tier's
/// quota). Reactions aren't gated behind sign-in like sending a chat message
/// is: broadcast isn't covered by chat_messages' RLS at all, and there's no
/// reason a guest viewer shouldn't be able to react.
class LiveChatController extends ChangeNotifier {
  LiveChatController({required this.streamId, this.onReaction});

  final String streamId;

  /// Invoked when another client broadcasts a reaction on this stream's
  /// channel (not when this client sends its own -- the caller already shows
  /// that immediately/locally on tap, without waiting on a round trip).
  final void Function(String reactionType)? onReaction;

  SupabaseClient get _client => Supabase.instance.client;
  RealtimeChannel? _channel;
  bool _disposed = false;

  final List<ChatMessageModel> _messages = [];

  /// Senders the current viewer has blocked (Checkpoint 3 Phase 1) --
  /// per-viewer and client-side only, never a platform-wide action, so it's
  /// filtered here rather than server-side.
  final Set<String> _blockedSenderIds = {};

  /// Messages the current viewer has hidden (Cluster 4 Task 13) -- like
  /// blocking, this is a per-viewer client-side preference with no server
  /// component: hiding one message from someone you otherwise still see is
  /// not a moderation action, just a personal "don't show me this" toggle.
  final Set<String> _hiddenMessageIds = {};

  final Map<String, ({String senderId, String senderName, int count})>
      _moderationAlerts = {};
  List<({String senderId, String senderName, int count})> get moderationAlerts =>
      _moderationAlerts.values.toList();

  void dismissModerationAlert(String senderId) {
    if (_moderationAlerts.remove(senderId) != null) {
      notifyListeners();
    }
  }

  Future<void> quickMuteFromAlert(String senderId) async {
    dismissModerationAlert(senderId);
    await muteUser(senderId);
  }

  List<ChatMessageModel> get messages => List.unmodifiable(
        _messages.where((m) =>
            !_blockedSenderIds.contains(m.senderId) &&
            !_hiddenMessageIds.contains(m.id)),
      );

  bool isBlocked(String senderId) => _blockedSenderIds.contains(senderId);
  bool isHidden(String messageId) => _hiddenMessageIds.contains(messageId);

  /// Whether the current viewer is this stream's owner or an admin tier --
  /// resolved once via chat_can_moderate (see supabase/migrations/
  /// 20260825090000_chat_moderation.sql) and cached. Purely a UX gate for
  /// whether to show Mute/Delete in the chat action sheet; the mute/delete
  /// RLS policies are what actually enforce it, not this flag.
  bool _canModerate = false;
  bool get canModerate => _canModerate;

  ChatConnectionState _connectionState = ChatConnectionState.connecting;
  ChatConnectionState get connectionState => _connectionState;

  // --- P6.2 composer state -------------------------------------------------

  /// Mirrors `chat_stream_settings` for this stream. An absent row means chat
  /// is on with no slow mode, which is why these default to permissive: a
  /// stream nobody has configured is an ordinary open chat.
  bool _chatEnabled = true;
  int _slowModeSeconds = 0;
  bool get chatEnabled => _chatEnabled;
  int get slowModeSeconds => _slowModeSeconds;

  /// Resolved from `is_current_user_banned()` and `chat_is_muted()` -- both
  /// SECURITY DEFINER, so the client learns its own status without being able
  /// to read `banned_users` or `chat_muted_users` across users.
  bool _isSelfBanned = false;
  bool _isSelfMuted = false;
  bool get isSelfBanned => _isSelfBanned;
  bool get isSelfMuted => _isSelfMuted;

  /// Resolves the signed-in user id without assuming Supabase was ever
  /// initialized: `Supabase.instance` throws when it was not, and the chat
  /// room still has to render (read-only) in that case rather than crash.
  /// Overridable in tests via [debugSetStateForTests].
  String? _debugCurrentUserId;
  bool _debugUserIdOverridden = false;

  String? get _currentUserId {
    if (_debugUserIdOverridden) return _debugCurrentUserId;
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  bool get isGuest => _currentUserId == null;

  Timer? _slowModeTicker;

  /// When this viewer may next send, given slow mode and their own last
  /// message. Null when nothing is holding them back.
  DateTime? get _nextSendAllowedAt {
    if (_slowModeSeconds <= 0 || _canModerate) return null;
    DateTime? lastOwn;
    for (final m in _messages) {
      if (!m.isCurrentUser || m.isFailed) continue;
      if (lastOwn == null || m.createdAt.isAfter(lastOwn)) lastOwn = m.createdAt;
    }
    if (lastOwn == null) return null;
    return lastOwn.add(Duration(seconds: _slowModeSeconds));
  }

  /// Whole seconds left on the slow-mode countdown, 0 when it has elapsed.
  int get slowModeSecondsRemaining {
    final next = _nextSendAllowedAt;
    if (next == null) return 0;
    final remaining = next.difference(DateTime.now()).inMilliseconds;
    return remaining <= 0 ? 0 : (remaining / 1000).ceil();
  }

  /// The single reason the composer is unusable, highest precedence first.
  /// The widget renders from this; it never re-derives the rules itself.
  ChatComposerState get composerState {
    if (_isSelfBanned) return ChatComposerState.banned;
    if (isGuest) return ChatComposerState.guest;
    if (!_chatEnabled && !_canModerate) return ChatComposerState.chatDisabled;
    if (_isSelfMuted) return ChatComposerState.muted;
    if (_connectionState != ChatConnectionState.live) {
      return ChatComposerState.offline;
    }
    if (slowModeSecondsRemaining > 0) return ChatComposerState.slowMode;
    return ChatComposerState.ready;
  }

  bool get canSend => composerState == ChatComposerState.ready;

  /// Runs a 1 s tick only while a countdown is actually visible, so an idle
  /// chat screen is not rebuilding once a second forever.
  void _syncSlowModeTicker() {
    final needed = slowModeSecondsRemaining > 0;
    if (needed && _slowModeTicker == null) {
      _slowModeTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_disposed) return;
        notifyListeners();
        if (slowModeSecondsRemaining <= 0) {
          _slowModeTicker?.cancel();
          _slowModeTicker = null;
        }
      });
    } else if (!needed && _slowModeTicker != null) {
      _slowModeTicker?.cancel();
      _slowModeTicker = null;
    }
  }

  /// Reads this stream's chat settings. Absent row = open chat, no slow mode.
  Future<void> _loadChatSettings() async {
    try {
      final row = await _client
          .from('chat_stream_settings')
          .select()
          .eq('stream_id', streamId)
          .maybeSingle();
      _applyChatSettings(row);
    } catch (e) {
      debugPrint('LiveChatController: failed to load chat settings: $e');
    }
  }

  void _applyChatSettings(Map<String, dynamic>? row) {
    _chatEnabled = (row?['chat_enabled'] as bool?) ?? true;
    _slowModeSeconds = (row?['slow_mode_seconds'] as int?) ?? 0;
    _syncSlowModeTicker();
    if (!_disposed) notifyListeners();
  }

  /// Re-resolves whether this viewer is platform-banned or muted in this
  /// stream. Called on start, after any refused send, and after one of the
  /// viewer's own messages is deleted by someone else -- `chat_muted_users` is
  /// deliberately not on the realtime publication, because letting a muted
  /// account read its own row would tell it which moderator muted it
  /// (see 20260921130000).
  Future<void> _refreshSelfStatus() async {
    if (isGuest) {
      _isSelfBanned = false;
      _isSelfMuted = false;
      return;
    }
    try {
      final banned = await _client.rpc('is_current_user_banned');
      _isSelfBanned = banned as bool? ?? false;
    } catch (e) {
      debugPrint('LiveChatController: failed to resolve ban status: $e');
    }
    try {
      final muted = await _client.rpc('chat_is_muted', params: {
        'p_stream_id': streamId,
        'p_profile_id': _currentUserId,
      });
      _isSelfMuted = muted as bool? ?? false;
    } catch (e) {
      debugPrint('LiveChatController: failed to resolve mute status: $e');
    }
    if (!_disposed) notifyListeners();
  }

  /// sender_id -> resolved display info + role badges, populated on demand
  /// via the chat_sender_info RPC (see supabase/migrations/
  /// 20260823140000_chat_sender_info.sql). Not a plain `profiles` select --
  /// profiles' own RLS only lets a viewer read their own row or an admin's,
  /// so any other sender's name/badges need this SECURITY DEFINER function.
  final Map<String,
          ({String name, String? avatarUrl, Set<ChatSenderBadge> badges})>
      _profileCache = {};

  Future<void> start() async {
    try {
      Supabase.instance;
    } catch (_) {
      _connectionState = ChatConnectionState.reconnecting;
      notifyListeners();
      return;
    }
    await _loadBlockedUsers();
    await _loadHiddenMessages();
    await _loadCanModerate();
    await _loadChatSettings();
    await _refreshSelfStatus();
    await _loadRecentMessages();
    _subscribe();
  }

  Future<void> _loadCanModerate() async {
    if (_currentUserId == null) return;
    try {
      final result = await _client
          .rpc('chat_can_moderate', params: {'p_stream_id': streamId});
      _canModerate = result as bool? ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('LiveChatController: failed to resolve moderation status: $e');
    }
  }

  static const _blockedUsersPrefsPrefix = 'chat_blocked_users_';

  Future<void> _loadBlockedUsers() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('$_blockedUsersPrefsPrefix$userId');
      if (stored != null) _blockedSenderIds.addAll(stored);
    } catch (e) {
      debugPrint('LiveChatController: failed to load blocked users: $e');
    }
  }

  /// Hides this sender's messages (past and future) for the current viewer
  /// only. Persisted per-viewer so it survives leaving and re-entering the
  /// stream.
  Future<void> blockUser(String senderId) async {
    if (!_blockedSenderIds.add(senderId)) return;
    notifyListeners();

    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '$_blockedUsersPrefsPrefix$userId',
        _blockedSenderIds.toList(),
      );
    } catch (e) {
      debugPrint('LiveChatController: failed to persist blocked users: $e');
    }
  }

  static const _hiddenMessagesPrefsPrefix = 'chat_hidden_messages_';

  Future<void> _loadHiddenMessages() async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList('$_hiddenMessagesPrefsPrefix$userId');
      if (stored != null) _hiddenMessageIds.addAll(stored);
    } catch (e) {
      debugPrint('LiveChatController: failed to load hidden messages: $e');
    }
  }

  /// Hides one message from the current viewer only (Cluster 4 Task 13) --
  /// persisted per-viewer so it stays hidden across sessions, but never
  /// touches the message for anyone else.
  Future<void> hideChatMessage(String messageId) async {
    if (!_hiddenMessageIds.add(messageId)) return;
    notifyListeners();

    final userId = _currentUserId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '$_hiddenMessagesPrefsPrefix$userId',
        _hiddenMessageIds.toList(),
      );
    } catch (e) {
      debugPrint('LiveChatController: failed to persist hidden messages: $e');
    }
  }

  /// Reports a message to admin tiers (chat_reports, RLS-gated -- see
  /// supabase/migrations/20260824090000_chat_reports.sql). Throws if the
  /// viewer already reported this same message (unique constraint) or isn't
  /// signed in; the caller surfaces that to the user.
  Future<void> reportMessage({
    required String messageId,
    required String reportedSenderId,
    required String reason,
  }) async {
    final reporterId = _currentUserId;
    if (reporterId == null) {
      throw Exception('Sign in to report a message.');
    }
    await _client.from('chat_reports').insert({
      'message_id': messageId,
      'stream_id': streamId,
      'reported_sender_id': reportedSenderId,
      'reporter_id': reporterId,
      'reason': reason,
    });
  }

  /// Mutes a sender for this stream (Checkpoint 3 Phase 2) -- server-enforced
  /// via chat_muted_users' RLS (owner/admin only) and the chat_messages
  /// insert policy that rejects muted senders, not just this client-side
  /// gate. Throws if the caller isn't this stream's owner or an admin tier.

  /// Appends a platform-scope audit entry for an in-room moderation action
  /// (P6.3). Moderating from inside the live room is exactly as privileged as
  /// moderating from the admin queue, so it leaves the same trail; the actor is
  /// taken from `auth.uid()` server-side, so it cannot be forged. Best-effort:
  /// never let a failed audit write undo a mute or a delete that has already
  /// taken effect.
  Future<void> _recordModerationAudit({
    required String action,
    required String descriptionEn,
    required String descriptionAr,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      await _client.rpc('log_audit_event', params: {
        'p_organization_id': null,
        'p_action': action,
        'p_description_en': descriptionEn,
        'p_description_ar': descriptionAr,
        'p_metadata': metadata,
      });
    } catch (e) {
      debugPrint('LiveChatController: failed to write moderation audit: $e');
    }
  }

  Future<void> muteUser(String senderId) async {
    final mutedBy = _currentUserId;
    if (mutedBy == null) throw Exception('Sign in to moderate chat.');
    await _client.from('chat_muted_users').insert({
      'stream_id': streamId,
      'muted_profile_id': senderId,
      'muted_by': mutedBy,
    });
    await _recordModerationAudit(
      action: 'chatSenderMuted',
      descriptionEn: 'Muted a chat sender from inside the live room.',
      descriptionAr: 'تم كتم مُرسل من داخل غرفة البث المباشر.',
      metadata: {'stream_id': streamId, 'muted_profile_id': senderId},
    );
  }

  Future<void> unmuteUser(String senderId) async {
    await _client
        .from('chat_muted_users')
        .delete()
        .eq('stream_id', streamId)
        .eq('muted_profile_id', senderId);
  }

  /// Deletes a message -- server-enforced via chat_messages' delete RLS,
  /// which now covers two independent cases (Checkpoint 3 Phase 2's
  /// owner/admin moderation policy, and Cluster 4 Task 13's self-delete
  /// policy for the sender's own message): this one client call works for
  /// both, since RLS decides which policy actually applies to the caller.
  /// The local removal here is just for the caller's own optimistic UI;
  /// every other viewer removes it on the postgres_changes DELETE event
  /// (_handleDelete).
  Future<void> deleteMessage(String messageId) async {
    // A moderator can delete a message that is not in this client's list at
    // all (an admin acting from the queue, a message already scrolled past).
    // Unknown counts as someone else's, so the action is audited rather than
    // quietly skipped.
    final idx = _messages.indexWhere((m) => m.id == messageId);
    final wasOwnMessage = idx != -1 && _messages[idx].isCurrentUser;

    await _client.from('chat_messages').delete().eq('id', messageId);
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();

    // Deleting your own message is not a moderation action, so it is not
    // audited; deleting someone else's is, whichever policy allowed it.
    if (!wasOwnMessage) {
      await _recordModerationAudit(
        action: 'chatMessageDeleted',
        descriptionEn: 'Deleted a chat message from inside the live room.',
        descriptionAr: 'تم حذف رسالة محادثة من داخل غرفة البث المباشر.',
        metadata: {'stream_id': streamId, 'message_id': messageId},
      );
    }
  }

  /// Edits the sender's own message (Cluster 4 Task 13) -- server-enforced
  /// via chat_messages_update_self (sender_id = auth.uid() in both `using`
  /// and `with check`), so this throws for anyone else's message rather
  /// than silently no-op'ing. Every viewer (including this one) picks up
  /// the new body/editedAt via the realtime UPDATE event (_handleUpdate);
  /// the local mutate below is just this caller's optimistic echo.
  Future<void> editChatMessage(String messageId, String newBody) async {
    final trimmed = newBody.trim();
    if (trimmed.isEmpty) return;
    final editedAt = DateTime.now();
    await _client.from('chat_messages').update({
      'body': trimmed,
      'edited_at': editedAt.toIso8601String(),
    }).eq('id', messageId);

    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _messages[idx] =
          _messages[idx].copyWith(body: trimmed, editedAt: editedAt);
      notifyListeners();
    }
  }

  /// Appoints [profileId] as this stream's chat moderator (Cluster 4 Task
  /// 15) -- server-enforced via stream_moderators' RLS (only this stream's
  /// owner/admin may insert a scope='stream' row for it, see
  /// supabase/migrations/20260830160000_stream_moderators.sql). Idempotent:
  /// re-appointing an existing moderator is swallowed rather than surfaced
  /// as an error.
  Future<void> appointStreamModerator(String profileId) async {
    final assignedBy = _currentUserId;
    if (assignedBy == null) throw Exception('Sign in to appoint moderators.');
    try {
      await _client.from('stream_moderators').insert({
        'profile_id': profileId,
        'assigned_by': assignedBy,
        'scope': 'stream',
        'stream_id': streamId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // 23505 = unique_violation, already a moderator
    }
    _profileCache.remove(profileId); // force badge re-resolution on next fetch
  }

  Future<void> revokeStreamModerator(String profileId) async {
    await _client
        .from('stream_moderators')
        .delete()
        .eq('stream_id', streamId)
        .eq('profile_id', profileId)
        .eq('scope', 'stream');
    _profileCache.remove(profileId);
  }

  Future<void> _loadRecentMessages() async {
    try {
      final rows = await _client
          .from('chat_messages')
          .select()
          .eq('stream_id', streamId)
          .order('created_at')
          .limit(100);
      final resolved = await _rowsToMessages(rows.cast<Map<String, dynamic>>());
      if (_disposed) return;
      _messages
        ..clear()
        ..addAll(resolved);
      notifyListeners();
    } catch (e) {
      debugPrint('LiveChatController: failed to load recent messages: $e');
    }
  }

  void _subscribe() {
    try {
      _channel = _client.channel('chat:$streamId')
        ..onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: streamId,
          ),
          callback: (payload) => _handleInsert(payload.newRecord),
        )
        // No stream_id filter here: Realtime can only filter DELETE events on
        // REPLICA IDENTITY FULL tables (chat_messages isn't -- default
        // identity only replicates the primary key on delete), so this
        // receives every stream's deletes and _handleDelete just checks
        // whether the id is one of ours.
        ..onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) => _handleDelete(payload.oldRecord),
        )
        // Edits (Cluster 4 Task 13) -- reuses _handleInsert's shape since it
        // already replaces-if-exists rather than only appending.
        ..onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: streamId,
          ),
          callback: (payload) => _handleInsert(payload.newRecord),
        )
        // P6.2: chat off / slow mode has to reach the composer immediately,
        // not on the next screen open (20260921130000 publishes this table).
        // An absent row means an open chat, so a DELETE resets to permissive.
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_stream_settings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'stream_id',
            value: streamId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            _applyChatSettings(row.isEmpty ? null : row);
          },
        )
        ..onBroadcast(
          event: 'reaction',
          callback: (payload) {
            final type = payload['reaction_type'] as String?;
            if (type != null) onReaction?.call(type);
          },
        )
        ..subscribe((status, error) {
          if (_disposed) return;
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              _connectionState = ChatConnectionState.live;
            case RealtimeSubscribeStatus.closed:
            case RealtimeSubscribeStatus.channelError:
            case RealtimeSubscribeStatus.timedOut:
              _connectionState = ChatConnectionState.reconnecting;
              if (error != null) {
                debugPrint(
                    'LiveChatController: channel status $status: $error');
              }
          }
          _syncSlowModeTicker();
          notifyListeners();
        });
    } catch (e) {
      // Supabase not initialized, or channel creation otherwise failed --
      // stay in "reconnecting" rather than crashing the stream screen.
      debugPrint('LiveChatController: failed to subscribe: $e');
      _connectionState = ChatConnectionState.reconnecting;
      notifyListeners();
    }
  }

  Future<void> _handleInsert(Map<String, dynamic> row) async {
    final resolved = await _rowsToMessages([row]);
    if (_disposed || resolved.isEmpty) return;
    final message = resolved.first;
    final existingIdx = _messages.indexWhere((m) => m.id == message.id);
    if (existingIdx != -1) {
      _messages[existingIdx] = message;
    } else {
      _messages.add(message);
    }
    notifyListeners();
  }

  void _handleDelete(Map<String, dynamic> oldRow) {
    final id = oldRow['id'] as String?;
    if (id == null) return;
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx == -1) return;
    final wasOwn = _messages[idx].isCurrentUser;
    _messages.removeAt(idx);
    _failureKinds.remove(id);
    notifyListeners();
    // A moderator deleting one of this viewer's messages usually comes with a
    // mute (P6.3). chat_muted_users is not published to realtime on purpose,
    // so this is where the composer finds out.
    if (wasOwn && !isGuest) _refreshSelfStatus();
  }

  Future<List<ChatMessageModel>> _rowsToMessages(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final currentUserId = _currentUserId;

    final unresolvedIds = rows
        .map((r) => r['sender_id'] as String)
        .where((id) => !_profileCache.containsKey(id))
        .toSet();
    if (unresolvedIds.isNotEmpty) {
      try {
        final senderRows = await _client.rpc('chat_sender_info', params: {
          'p_profile_ids': unresolvedIds.toList(),
          'p_stream_id': streamId,
        });
        for (final p in (senderRows as List).cast<Map<String, dynamic>>()) {
          final badges = <ChatSenderBadge>{
            if (p['is_speaker'] == true) ChatSenderBadge.speaker,
            if (p['is_org_owner'] == true) ChatSenderBadge.organization,
            if (p['is_admin'] == true) ChatSenderBadge.admin,
            if (p['is_moderator'] == true) ChatSenderBadge.moderator,
            if (p['is_verified'] == true) ChatSenderBadge.verified,
          };
          _profileCache[p['profile_id'] as String] = (
            name: p['display_name'] as String? ?? 'Viewer',
            avatarUrl: p['avatar_url'] as String?,
            badges: badges,
          );
        }
      } catch (e) {
        debugPrint('LiveChatController: failed to resolve sender info: $e');
      }
    }

    return rows.map((r) {
      final senderId = r['sender_id'] as String;
      final cached = _profileCache[senderId];
      return ChatMessageModel(
        id: r['id'] as String,
        streamId: r['stream_id'] as String,
        senderId: senderId,
        senderName: cached?.name ?? 'Viewer',
        senderAvatarUrl: cached?.avatarUrl,
        badges: cached?.badges ?? const {},
        body: r['body'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        isCurrentUser: senderId == currentUserId,
        editedAt: r['edited_at'] != null
            ? DateTime.parse(r['edited_at'] as String)
            : null,
      );
    }).toList();
  }

  /// Sends a message with an optimistic local echo: appended immediately
  /// (isPending: true), then replaced by the real confirmed row once it
  /// arrives back through this client's own postgres_changes subscription
  /// (_handleInsert matches on id -- the client generates it up front so the
  /// two can be matched without a round trip). Removed again if the insert
  /// itself fails.
  Future<void> sendMessage(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final currentUserId = _currentUserId;
    if (currentUserId == null) {
      throw Exception('Sign in to send a chat message.');
    }

    final id = newId();
    final cachedSelf = _profileCache[currentUserId];
    _messages.add(ChatMessageModel(
      id: id,
      streamId: streamId,
      senderId: currentUserId,
      senderName: cachedSelf?.name ?? 'You',
      senderAvatarUrl: cachedSelf?.avatarUrl,
      badges: cachedSelf?.badges ?? const {},
      body: trimmed,
      createdAt: DateTime.now(),
      isCurrentUser: true,
      isPending: true,
    ));
    _syncSlowModeTicker();
    notifyListeners();

    await _insertOrMarkFailed(id: id, body: trimmed, senderId: currentUserId);
  }

  /// Retries a message whose insert was refused (P6.2). Only failures that
  /// could plausibly succeed on a second attempt are retryable -- see
  /// [isRetryable]; a banned keyword will be refused identically forever, so
  /// offering "retry" there would be a lie.
  Future<void> retryFailedMessage(String messageId) async {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final message = _messages[idx];
    if (!message.isFailed || !isRetryable(messageId)) return;

    final senderId = _currentUserId;
    if (senderId == null) throw Exception('Sign in to send a chat message.');

    _messages[idx] = message.copyWith(isPending: true, isFailed: false);
    _failureKinds.remove(messageId);
    notifyListeners();

    await _insertOrMarkFailed(
        id: messageId, body: message.body, senderId: senderId);
  }

  /// Drops a failed message from the list without sending it.
  void discardFailedMessage(String messageId) {
    final before = _messages.length;
    _messages.removeWhere((m) => m.id == messageId && m.isFailed);
    _failureKinds.remove(messageId);
    if (_messages.length != before) notifyListeners();
  }

  /// Machine-readable cause per failed message id, so retryability is decided
  /// from the server's actual refusal rather than by matching display text.
  final Map<String, _SendFailure> _failureKinds = {};

  bool isRetryable(String messageId) =>
      _failureKinds[messageId]?.retryable ?? false;

  /// Inserts the row, or leaves the optimistic echo in place marked failed so
  /// the sender can retry or discard rather than losing what they typed. The
  /// thrown exception is what the caller surfaces as a toast; the retained
  /// message is what the sender acts on.
  Future<void> _insertOrMarkFailed({
    required String id,
    required String body,
    required String senderId,
  }) async {
    try {
      await _client.from('chat_messages').insert({
        'id': id,
        'stream_id': streamId,
        'sender_id': senderId,
        'body': body,
      });
    } catch (e) {
      final failure = _classifySendFailure('$e');
      _failureKinds[id] = failure;
      final idx = _messages.indexWhere((m) => m.id == id);
      if (idx != -1) {
        _messages[idx] = _messages[idx].copyWith(
          isPending: false,
          isFailed: true,
          failureReason: failure.message,
        );
      }
      notifyListeners();
      // A refusal may mean the viewer was muted, banned or the chat was
      // turned off while they were typing; re-resolve so the composer stops
      // inviting them to try again.
      await _refreshSelfStatus();
      await _loadChatSettings();
      throw Exception(failure.message);
    }
  }

  /// Maps a server refusal onto a readable reason and whether retrying could
  /// ever help. Every branch corresponds to a rule enforced by the
  /// `chat_messages` insert policy or the `chat_enforce_rate_limit` trigger.
  _SendFailure _classifySendFailure(String raw) {
    if (raw.contains('banned keyword')) {
      // Deterministic: the same body will be refused every time.
      return const _SendFailure(
          "Message blocked: that language isn't allowed here.", false);
    }
    if (raw.contains('Chat is turned off')) {
      return const _SendFailure(
          'The broadcaster has turned chat off for this stream.', false);
    }
    if (raw.contains('Sending too fast')) {
      return const _SendFailure(
          'Slow down a moment before sending again.', true);
    }
    if (raw.contains('Too many messages in one minute')) {
      return const _SendFailure(
          'You have sent too many messages in the last minute.', true);
    }
    // Anything else -- an RLS refusal (muted, banned), a dropped connection,
    // a timeout. Retrying is reasonable; the composer state explains the rest.
    return _SendFailure(raw, true);
  }

  /// Broadcasts an ephemeral reaction ('heart', 'clap', 'idea', 'fire',
  /// 'scholar', ...) to other clients on this stream's channel. Never
  /// persisted -- the caller is responsible for showing its own local
  /// floating-emoji effect immediately, without waiting on this.
  Future<void> sendReaction(String reactionType) async {
    final channel = _channel;
    if (channel == null) return;
    try {
      await channel.sendBroadcastMessage(
        event: 'reaction',
        payload: {'reaction_type': reactionType},
      );
    } catch (e) {
      debugPrint('LiveChatController: failed to send reaction: $e');
    }
  }

  // --- test seams ---------------------------------------------------------

  /// Sets the inputs [composerState] is derived from, without a database.
  /// The rules themselves are what these tests are about; the server-side
  /// enforcement of each rule is covered by supabase/tests/chat_rate_limit.test.sql
  /// and chat_keyword_filter.test.sql.
  @visibleForTesting
  void debugSetStateForTests({
    String? currentUserId,
    bool overrideCurrentUserId = true,
    bool? chatEnabled,
    int? slowModeSeconds,
    bool? isSelfBanned,
    bool? isSelfMuted,
    bool? canModerate,
    ChatConnectionState? connectionState,
  }) {
    if (overrideCurrentUserId) {
      _debugUserIdOverridden = true;
      _debugCurrentUserId = currentUserId;
    }
    if (chatEnabled != null) _chatEnabled = chatEnabled;
    if (slowModeSeconds != null) _slowModeSeconds = slowModeSeconds;
    if (isSelfBanned != null) _isSelfBanned = isSelfBanned;
    if (isSelfMuted != null) _isSelfMuted = isSelfMuted;
    if (canModerate != null) _canModerate = canModerate;
    if (connectionState != null) _connectionState = connectionState;
    notifyListeners();
  }

  /// Appends a message directly, for the slow-mode countdown (which is derived
  /// from the viewer's own most recent message) and the failed-send affordances.
  @visibleForTesting
  void debugAddMessageForTests(ChatMessageModel message, {bool? retryable}) {
    _messages.add(message);
    if (retryable != null) {
      _failureKinds[message.id] =
          _SendFailure(message.failureReason ?? '', retryable);
    }
    notifyListeners();
  }

  /// The classification [sendMessage] would apply to a raw server error, so the
  /// retry policy can be asserted without a server.
  @visibleForTesting
  ({String message, bool retryable}) debugClassifyForTests(String raw) {
    final f = _classifySendFailure(raw);
    return (message: f.message, retryable: f.retryable);
  }

  @override
  void dispose() {
    _disposed = true;
    _slowModeTicker?.cancel();
    _slowModeTicker = null;
    final channel = _channel;
    if (channel != null) {
      try {
        _client.removeChannel(channel);
      } catch (_) {}
    }
    super.dispose();
  }
}

/// A refusal from the chat insert path: what to tell the sender, and whether a
/// second attempt could ever succeed.
@immutable
class _SendFailure {
  final String message;
  final bool retryable;
  const _SendFailure(this.message, this.retryable);
}
