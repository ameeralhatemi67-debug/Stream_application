import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/ghost_comments.dart';

class LiveChatWidget extends StatefulWidget {
  final List<GhostComment> comments;
  final Function(String messageText) onSendTextMessage;
  final Function(String emoji, String reactionType) onSendReaction;

  const LiveChatWidget({
    super.key,
    required this.comments,
    required this.onSendTextMessage,
    required this.onSendReaction,
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
    final langCode = context.locale.languageCode;

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface2,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppTheme.accentGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.comments.length}',
                        style: const TextStyle(
                          color: AppTheme.textSecondaryDark,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
              itemCount: widget.comments.length,
              itemBuilder: (context, index) {
                final comment = widget.comments[index];
                return _ChatTile(
                  comment: comment,
                  langCode: langCode,
                );
              },
            ),
          ),

          // Quick Reaction Pills & Interactive Input Bar
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface1,
              border: Border(
                top: BorderSide(color: AppTheme.darkBorderSubtle, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Reaction Pills Row
                Row(
                  children: [
                    Text(
                      'live.quick_reactions'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textMutedDark,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    _ReactionPill(
                      emoji: '❤️',
                      label: 'Love',
                      onTap: () => widget.onSendReaction('❤️', 'heart'),
                    ),
                    const SizedBox(width: AppTheme.spaceXs),
                    _ReactionPill(
                      emoji: '👏',
                      label: 'Clap',
                      onTap: () => widget.onSendReaction('👏', 'clap'),
                    ),
                    const SizedBox(width: AppTheme.spaceXs),
                    _ReactionPill(
                      emoji: '✋',
                      label: 'Raise Hand',
                      onTap: () => widget.onSendReaction('✋', 'raise_hand'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),

                // Text Input Field & Send Button
                Row(
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _ReactionPill({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            border: Border.all(color: AppTheme.darkBorderSubtle, width: 1),
          ),
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final GhostComment comment;
  final String langCode;

  const _ChatTile({
    required this.comment,
    required this.langCode,
  });

  bool get _isScholar =>
      comment.senderNameEn.contains('Dr.') ||
      comment.senderNameEn.contains('Prof') ||
      comment.senderNameEn.contains('Sheikh') ||
      comment.senderNameAr.contains('د.') ||
      comment.senderNameAr.contains('الشيخ') ||
      comment.senderNameAr.contains('أستاذ');

  String _getReactionEmoji(String reactionType) {
    switch (reactionType) {
      case 'heart':
        return '❤️';
      case 'clap':
        return '👏';
      case 'raise_hand':
        return '✋';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderName = comment.getLocalizedSender(langCode);
    final messageText = comment.getLocalizedMessage(langCode);
    final reactionEmoji = _getReactionEmoji(comment.reactionType);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: comment.isCurrentUser
            ? AppTheme.accentBlue.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: comment.isCurrentUser
            ? Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.3), width: 1)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar or Fallback Initials
          CircleAvatar(
            radius: 14,
            backgroundColor: comment.isCurrentUser
                ? AppTheme.accentBlue
                : (_isScholar ? AppTheme.accentPurple : AppTheme.darkSurface3),
            backgroundImage: comment.senderAvatar.startsWith('assets/')
                ? AssetImage(comment.senderAvatar) as ImageProvider
                : null,
            child: !comment.senderAvatar.startsWith('assets/')
                ? Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppTheme.spaceSm),

          // Message Info Body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender Name, Scholar/User Badge, & Timestamp
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: comment.isCurrentUser
                            ? AppTheme.accentBlue
                            : (_isScholar
                                ? AppTheme.accentPurple
                                : AppTheme.textPrimaryDark),
                      ),
                    ),

                    // Scholar Badge (#BC5FD3)
                    if (_isScholar)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                          border: Border.all(color: AppTheme.accentPurple, width: 0.8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 10,
                              color: AppTheme.accentPurple,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'live.scholar'.tr(),
                              style: const TextStyle(
                                color: AppTheme.accentPurple,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Current User "You" Pill
                    if (comment.isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                          border: Border.all(color: AppTheme.accentBlue, width: 0.8),
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

                    // Timestamp
                    Text(
                      comment.timestamp,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMutedDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),

                // Message Text & Reaction Emoji Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        messageText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryDark,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (reactionEmoji.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        reactionEmoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
