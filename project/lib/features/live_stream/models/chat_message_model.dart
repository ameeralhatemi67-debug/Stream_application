import 'package:flutter/material.dart';

/// A role/status badge shown next to a chat sender's name, resolved from
/// user_roles/org_speakers/profiles.is_verified via the chat_sender_info RPC
/// (see supabase/migrations/20260823140000_chat_sender_info.sql -- a regular
/// viewer can't read those tables cross-user directly under their RLS).
enum ChatSenderBadge {
  speaker(Icons.mic, 'Speaker', 'متحدث'),
  organization(Icons.business, 'Org', 'مؤسسة'),
  // Gold ADMIN / cyan MOD pill styling lives in live_chat_widget.dart --
  // these two carry the exact bilingual labels Tasks 13 & 15 ask for
  // ("ADMIN / المشرف العام", "MOD / مشرف البث").
  admin(Icons.admin_panel_settings, 'ADMIN', 'المشرف العام'),
  moderator(Icons.shield, 'MOD', 'مشرف البث'),
  verified(Icons.verified, 'Verified', 'موثّق');

  final IconData icon;
  final String labelEn;
  final String labelAr;
  const ChatSenderBadge(this.icon, this.labelEn, this.labelAr);
}

/// A real, Supabase-backed live chat message. Port of a `chat_messages` row,
/// with sender display info resolved client-side (see LiveChatController)
/// rather than denormalized onto the row.
///
/// The only chat model: the simulated offline-fallback model it used to
/// share the room with was deleted in P2.
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
  /// 13) -- drives the "(edited)"indicator. Mirrors chat_messages.edited_at.
  final DateTime? editedAt;

  /// True for an optimistic echo whose insert was refused by the server
  /// (P6.2). The message stays in the list so the sender can retry or discard
  /// it instead of silently losing what they typed; [failureReason] carries
  /// the server's own explanation. Never true for a confirmed row.
  final bool isFailed;

  /// Why the send failed, already translated to something a person can read
  /// (set by LiveChatController.sendMessage). Null unless [isFailed].
  final String? failureReason;

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
    this.isFailed = false,
    this.failureReason,
  });

  ChatMessageModel copyWith({
    String? id,
    String? senderName,
    String? senderAvatarUrl,
    String? body,
    Set<ChatSenderBadge>? badges,
    bool? isPending,
    DateTime? editedAt,
    bool? isFailed,
    String? failureReason,
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
      isFailed: isFailed ?? this.isFailed,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
