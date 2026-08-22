import 'package:flutter/foundation.dart';

/// A real, Supabase-backed live chat message. Port of a `chat_messages` row,
/// with sender display info resolved client-side from `profiles` (see
/// LiveChatController) rather than denormalized onto the row.
///
/// Distinct from GhostComment (ghost_comments.dart), which stays the
/// simulated/offline-fallback data model (Checkpoint 4) -- the two are not
/// unified because a real message has one language, not separate EN/AR text.
@immutable
class ChatMessageModel {
  final String id;
  final String streamId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String body;
  final DateTime createdAt;
  final bool isCurrentUser;

  /// True for an optimistic local echo not yet confirmed by the server
  /// (Checkpoint 1 Phase 3). Always false for messages that arrived via a
  /// real postgres_changes event.
  final bool isPending;

  const ChatMessageModel({
    required this.id,
    required this.streamId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.body,
    required this.createdAt,
    this.isCurrentUser = false,
    this.isPending = false,
  });

  ChatMessageModel copyWith({
    String? id,
    String? senderName,
    String? senderAvatarUrl,
    bool? isPending,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      streamId: streamId,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      body: body,
      createdAt: createdAt,
      isCurrentUser: isCurrentUser,
      isPending: isPending ?? this.isPending,
    );
  }
}
