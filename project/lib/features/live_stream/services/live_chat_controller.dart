import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/id_generator.dart';
import '../models/chat_message_model.dart';

enum ChatConnectionState { connecting, live, reconnecting }

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
    await _loadRecentMessages();
    _subscribe();
  }

  Future<void> _loadCanModerate() async {
    if (_client.auth.currentUser?.id == null) return;
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
    final userId = _client.auth.currentUser?.id;
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

    final userId = _client.auth.currentUser?.id;
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
    final userId = _client.auth.currentUser?.id;
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

    final userId = _client.auth.currentUser?.id;
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
    final reporterId = _client.auth.currentUser?.id;
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
  Future<void> muteUser(String senderId) async {
    final mutedBy = _client.auth.currentUser?.id;
    if (mutedBy == null) throw Exception('Sign in to moderate chat.');
    await _client.from('chat_muted_users').insert({
      'stream_id': streamId,
      'muted_profile_id': senderId,
      'muted_by': mutedBy,
    });
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
    await _client.from('chat_messages').delete().eq('id', messageId);
    _messages.removeWhere((m) => m.id == messageId);
    notifyListeners();
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
    final assignedBy = _client.auth.currentUser?.id;
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
    final before = _messages.length;
    _messages.removeWhere((m) => m.id == id);
    if (_messages.length != before) notifyListeners();
  }

  Future<List<ChatMessageModel>> _rowsToMessages(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final currentUserId = _client.auth.currentUser?.id;

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

    final currentUserId = _client.auth.currentUser?.id;
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
    notifyListeners();

    try {
      await _client.from('chat_messages').insert({
        'id': id,
        'stream_id': streamId,
        'sender_id': currentUserId,
        'body': trimmed,
      });
    } catch (e) {
      _messages.removeWhere((m) => m.id == id);
      notifyListeners();
      // Server-side refusals carry a readable reason; surface it instead of a
      // raw Postgrest exception, and never silently drop the message.
      final text = '$e';
      if (text.contains('banned keyword')) {
        throw Exception("Message blocked: that language isn't allowed here.");
      }
      // P6.1 enforcement, all raised by the chat_messages insert trigger.
      if (text.contains('Chat is turned off')) {
        throw Exception('The broadcaster has turned chat off for this stream.');
      }
      if (text.contains('Sending too fast')) {
        throw Exception('Slow down a moment before sending again.');
      }
      if (text.contains('Too many messages in one minute')) {
        throw Exception('You have sent too many messages in the last minute.');
      }
      rethrow;
    }
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

  @override
  void dispose() {
    _disposed = true;
    final channel = _channel;
    if (channel != null) {
      try {
        _client.removeChannel(channel);
      } catch (_) {}
    }
    super.dispose();
  }
}
