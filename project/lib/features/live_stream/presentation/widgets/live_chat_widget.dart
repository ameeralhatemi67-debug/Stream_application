import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/live_chat_controller.dart';

class LiveChatWidget extends StatefulWidget {
  final List<ChatMessageModel> messages;
  final ChatConnectionState connectionState;
  final Function(String messageText) onSendTextMessage;

  /// Long-press on someone else's message (Checkpoint 3 Phase 1) -- never
  /// called for the viewer's own message. This widget stays a "dumb" one
  /// that only reports the gesture; showing the report/block action sheet is
  /// the caller's job, same shape as onSendTextMessage.
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
      color: AppTheme.darkBgBase,
      child: Column(
        children: [
          // Live Chat Header Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceSm,
            ),
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface1,
              border: Border(
                bottom: BorderSide(color: AppTheme.darkBorderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppTheme.accentBlue,
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Text(
                  'live.ghost_audience'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryDark,
                      ),
                ),
                const Spacer(),
                _ConnectionStatusChip(state: widget.connectionState),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface2,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: Text(
                    '${widget.messages.length}',
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
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
                  onLongPress: message.isCurrentUser
                      ? null
                      : widget.onMessageLongPress == null
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
              color: AppTheme.darkSurface1,
              border: Border(
                top: BorderSide(color: AppTheme.darkBorderSubtle, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 13,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSendText(),
                    decoration: InputDecoration(
                      hintText: 'live.chat_placeholder'.tr(),
                      hintStyle: const TextStyle(
                        color: AppTheme.textMutedDark,
                        fontSize: 13,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: AppTheme.darkSurface2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        borderSide: const BorderSide(
                          color: AppTheme.accentBlue,
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
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: AppTheme.darkBgBase,
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
              ? AppTheme.accentBlue.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: message.isCurrentUser
              ? Border.all(
                  color: AppTheme.accentBlue.withValues(alpha: 0.3), width: 1)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: message.isCurrentUser
                  ? AppTheme.accentBlue
                  : AppTheme.darkSurface3,
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
                        color: Colors.white,
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
                              ? AppTheme.accentBlue
                              : AppTheme.textPrimaryDark,
                        ),
                      ),
                      if (message.badges.isNotEmpty)
                        Text(
                          message.badges.map((b) => b.emoji).join(),
                          style: const TextStyle(fontSize: 11),
                        ),
                      if (message.isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accentBlue.withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusXs),
                            border: Border.all(
                                color: AppTheme.accentBlue, width: 0.8),
                          ),
                          child: Text(
                            'live.you'.tr(),
                            style: const TextStyle(
                              color: AppTheme.accentBlue,
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
                          color: AppTheme.textMutedDark,
                        ),
                      ),
                      if (message.isPending)
                        const SizedBox(
                          width: 9,
                          height: 9,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: AppTheme.textMutedDark,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryDark,
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

class _ConnectionStatusChip extends StatelessWidget {
  final ChatConnectionState state;

  const _ConnectionStatusChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (state) {
      ChatConnectionState.live => (
          AppTheme.accentGreen,
          'live.chat_status_live'.tr()
        ),
      ChatConnectionState.connecting => (
          AppTheme.accentAmber,
          'live.chat_status_connecting'.tr()
        ),
      ChatConnectionState.reconnecting => (
          AppTheme.accentRed,
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
