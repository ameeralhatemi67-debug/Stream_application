import 'package:flutter/foundation.dart';
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
/// Checkpoint 2 will reuse for ephemeral broadcast reactions.
class LiveChatController extends ChangeNotifier {
  LiveChatController({required this.streamId});

  final String streamId;

  SupabaseClient get _client => Supabase.instance.client;
  RealtimeChannel? _channel;
  bool _disposed = false;

  final List<ChatMessageModel> _messages = [];
  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

  ChatConnectionState _connectionState = ChatConnectionState.connecting;
  ChatConnectionState get connectionState => _connectionState;

  /// sender_id -> resolved display info, populated on demand from `profiles`.
  final Map<String, ({String name, String? avatarUrl})> _profileCache = {};

  Future<void> start() async {
    await _loadRecentMessages();
    _subscribe();
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
                debugPrint('LiveChatController: channel status $status: $error');
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
        final profileRows = await _client
            .from('profiles')
            .select('id, display_name_en, avatar_url')
            .inFilter('id', unresolvedIds.toList());
        for (final p in profileRows) {
          final displayName = p['display_name_en'] as String?;
          _profileCache[p['id'] as String] = (
            name: (displayName?.trim().isNotEmpty ?? false) ? displayName! : 'Viewer',
            avatarUrl: p['avatar_url'] as String?,
          );
        }
      } catch (e) {
        debugPrint('LiveChatController: failed to resolve sender profiles: $e');
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
        body: r['body'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        isCurrentUser: senderId == currentUserId,
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
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    final channel = _channel;
    if (channel != null) {
      _client.removeChannel(channel);
    }
    super.dispose();
  }
}
