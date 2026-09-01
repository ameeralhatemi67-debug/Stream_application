import 'package:flutter/foundation.dart';

/// A role/status badge shown next to a chat sender's name, resolved from
/// user_roles/org_speakers/profiles.is_verified via the chat_sender_info RPC
/// (see supabase/migrations/20260823140000_chat_sender_info.sql -- a regular
/// viewer can't read those tables cross-user directly under their RLS).
enum ChatSenderBadge {
  speaker('🎙️', 'Speaker', 'متحدث'),
  organization('🏛️', 'Org', 'مؤسسة'),
  // Gold ADMIN / cyan MOD pill styling lives in live_chat_widget.dart --
  // these two carry the exact bilingual labels Tasks 13 & 15 ask for
  // ("👑 ADMIN / المشرف العام", "🛡️ MOD / مشرف البث").
  admin('👑', 'ADMIN', 'المشرف العام'),
  moderator('🛡️', 'MOD', 'مشرف البث'),
  verified('✅', 'Verified', 'موثّق');

  final String emoji;
  final String labelEn;
  final String labelAr;
  const ChatSenderBadge(this.emoji, this.labelEn, this.labelAr);
}

/// A real, Supabase-backed live chat message. Port of a `chat_messages` row,
/// with sender display info resolved client-side (see LiveChatController)
/// rather than denormalized onto the row.
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
  final Set<ChatSenderBadge> badges;

  /// True for an optimistic local echo not yet confirmed by the server
  /// (Checkpoint 1 Phase 3). Always false for messages that arrived via a
  /// real postgres_changes event.
  final bool isPending;

  /// Set once this message has been edited by its sender (Cluster 4 Task
  /// 13) -- drives the "(edited)" indicator. Mirrors chat_messages.edited_at.
  final DateTime? editedAt;

  /// True when `badges` contains ChatSenderBadge.moderator for this stream
  /// (resolved server-side via chat_sender_info's is_moderator column).
  bool get isStreamModerator => badges.contains(ChatSenderBadge.moderator);

  bool get isEdited => editedAt != null;

  const ChatMessageModel({
    required this.id,
    required this.streamId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.body,
    required this.createdAt,
    this.isCurrentUser = false,
    this.badges = const {},
    this.isPending = false,
    this.editedAt,
  });

  ChatMessageModel copyWith({
    String? id,
    String? senderName,
    String? senderAvatarUrl,
    String? body,
    Set<ChatSenderBadge>? badges,
    bool? isPending,
    DateTime? editedAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      streamId: streamId,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      body: body ?? this.body,
      createdAt: createdAt,
      isCurrentUser: isCurrentUser,
      badges: badges ?? this.badges,
      isPending: isPending ?? this.isPending,
      editedAt: editedAt ?? this.editedAt,
    );
  }
}
