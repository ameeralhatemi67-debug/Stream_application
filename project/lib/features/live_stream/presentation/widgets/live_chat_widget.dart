import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/live_chat_controller.dart';

class LiveChatWidget extends StatefulWidget {
  final List<ChatMessageModel> messages;
  final ChatConnectionState connectionState;
  final Function(String messageText) onSendTextMessage;

  /// Long-press on any message tile, own or someone else's (Cluster 4 Task
  /// 13 widened this from the Checkpoint 3 Phase 1 original, which only
  /// fired for someone else's message). This widget stays a "dumb"one that
  /// only reports the gesture; the caller decides which action sheet to
  /// show based on `message.isCurrentUser`, same shape as onSendTextMessage.
  final void Function(ChatMessageModel message)? onMessageLongPress;

  const LiveChatWidget({
    super.key,
    required this.messages,
    required this.connectionState,
    required this.onSendTextMessage,
    this.onMessageLongPress,
  });

  @override
  State<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends State<LiveChatWidget> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSendText() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendTextMessage(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // Live Chat Header Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceSm,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                bottom: BorderSide(color: AppTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Text(
                  'live.ghost_audience'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                ),
                const Spacer(),
                _ConnectionStatusChip(state: widget.connectionState),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: Text(
                    '${widget.messages.length}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Inverted Chat Message Stream (Twitch/YouTube Live style)
          Expanded(
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              reverse: true, // Index 0 is the newest message at bottom
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceLg,
                vertical: AppTheme.spaceSm,
              ),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                // messages is oldest-first; the reversed ListView wants
                // newest-first at index 0.
                final message =
                    widget.messages[widget.messages.length - 1 - index];
                return _ChatTile(
                  message: message,
                  onLongPress: widget.onMessageLongPress == null
                      ? null
                      : () => widget.onMessageLongPress!(message),
                );
              },
            ),
          ),

          // Text Input Bar
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                top: BorderSide(color: AppTheme.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendText(),
                    decoration: InputDecoration(
                      hintText: 'live.chat_placeholder'.tr(),
                      hintStyle: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        borderSide: const BorderSide(
                          color: AppTheme.primary,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                IconButton.filled(
                  onPressed: _handleSendText,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.bg,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback? onLongPress;

  const _ChatTile({required this.message, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: message.isCurrentUser
              ? AppTheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: message.isCurrentUser
              ? Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: message.isCurrentUser
                  ? AppTheme.primary
                  : AppTheme.surface,
              backgroundImage:
                  (message.senderAvatarUrl?.startsWith('assets/') ?? false)
                      ? AssetImage(message.senderAvatarUrl!) as ImageProvider
                      : (message.senderAvatarUrl != null
                          ? NetworkImage(message.senderAvatarUrl!)
                              as ImageProvider
                          : null),
              child: message.senderAvatarUrl == null
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppTheme.onMedia,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        message.senderName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: message.isCurrentUser
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      ...message.badges
                          .map((badge) => _buildSenderBadge(context, badge)),
                      if (message.isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXs),
                            border: Border.all(
                                color: AppTheme.primary, width: 0.8),
                          ),
                          child: Text(
                            'live.you'.tr(),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        TimeOfDay.fromDateTime(message.createdAt.toLocal())
                            .format(context),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      if (message.isPending)
                        const SizedBox(
                          width: 9,
                          height: 9,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppTheme.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: message.body),
                        if (message.isEdited)
                          TextSpan(
                            text: ' ${'live.message_edited_badge'.tr()}',
                            style:
                                const TextStyle(color: AppTheme.textMuted),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chat governance badges (Tasks 13 & 15): Admin gets a gold pill, Moderator
/// a cyan one, both bilingual ("ADMIN / المشرف العام", "MOD / مشرف
/// البث"). Other badge kinds (speaker/org/verified) stay a plain emoji --
/// only admin/mod need to visibly stand out in a busy live chat.
Widget _buildSenderBadge(BuildContext context, ChatSenderBadge badge) {
  final isAr = context.locale.languageCode == 'ar';
  if (badge != ChatSenderBadge.admin && badge != ChatSenderBadge.moderator) {
    return Icon(badge.icon, size: 13, color: AppTheme.primary, semanticLabel: isAr ? badge.labelAr : badge.labelEn);
  }

  final isAdminBadge = badge == ChatSenderBadge.admin;
  final accentColor =
      isAdminBadge ? AppTheme.warning : AppTheme.primary;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: accentColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppTheme.radiusXs),
      border: Border.all(color: accentColor, width: 0.8),
    ),
    child: Text(
      isAr ? badge.labelAr : badge.labelEn,
      style: TextStyle(
        color: accentColor,
        fontSize: 9.5,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _ConnectionStatusChip extends StatelessWidget {
  final ChatConnectionState state;

  const _ConnectionStatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      ChatConnectionState.live => (
          AppTheme.success,
          'live.chat_status_live'.tr()
        ),
      ChatConnectionState.connecting => (
          AppTheme.warning,
          'live.chat_status_connecting'.tr()
        ),
      ChatConnectionState.reconnecting => (
          AppTheme.danger,
          'live.chat_status_reconnecting'.tr()
        ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
