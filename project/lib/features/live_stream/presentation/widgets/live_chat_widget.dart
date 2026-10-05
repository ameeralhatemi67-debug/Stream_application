import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../models/chat_message_model.dart';
import '../../services/live_chat_controller.dart';
import 'live_chat_layout.dart';
import 'floating_reactions_overlay.dart' show raisedHandGlyph, loweredHandGlyph;
import '../../../../core/widgets/hadayah_loading_indicator.dart';
import '../../../../core/widgets/ds/ca_feedback.dart';
import '../../../../core/widgets/ds/ca_icon.dart';

class LiveChatWidget extends StatefulWidget {
  final List<ChatMessageModel> messages;
  final ChatConnectionState connectionState;
  final Function(String messageText) onSendTextMessage;
  final TextEditingController? textController;
  final bool cinema;

  /// Shown as a sheet: adds a drag handle and a close button to the header.
  final VoidCallback? onClose;

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
    this.textController,
    this.cinema = false,
    this.onClose,
    this.onMessageLongPress,
  });

  @override
  State<LiveChatWidget> createState() => _LiveChatWidgetState();
}

class _LiveChatWidgetState extends State<LiveChatWidget> {
  late final TextEditingController _textController =
      widget.textController ?? TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool get _readOnly => isCompactLandscapeChat(context);
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _textController.text.trim().isNotEmpty;
    _textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _hasText && mounted) setState(() => _hasText = hasText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readOnly) _focusNode.unfocus();
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    if (widget.textController == null) _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSendText() {
    if (_readOnly) return;
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      widget.onSendTextMessage(text);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cinema) return _buildCinema(context);
    return Container(
      color: Canopy.dawn,
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
                bottom: BorderSide(color: Canopy.hairline, width: 1),
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
                Expanded(
                    child: Text(
                  'live.ghost_audience'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Canopy.ink,
                      ),
                )),
                const SizedBox(width: AppTheme.spaceSm),
                Flexible(
                    child:
                        _ConnectionStatusChip(state: widget.connectionState)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Canopy.mint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  ),
                  child: Text(
                    '${widget.messages.length}',
                    style: const TextStyle(
                      color: Canopy.slate,
                      fontSize: AppTheme.captionFont,
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

          if (_readOnly)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              child: Text('live.landscape_chat_read_only'.tr(),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Canopy.slate),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(
                  top: BorderSide(color: Canopy.hairline, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(
                        color: Canopy.ink,
                        fontSize: 13,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendText(),
                      decoration: InputDecoration(
                        hintText: 'live.chat_placeholder'.tr(),
                        hintStyle: const TextStyle(
                          color: Canopy.haze,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: Canopy.mint,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
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
                      foregroundColor: Canopy.dawn,
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

extension on _LiveChatWidgetState {
  Widget _buildCinema(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final divider = Canopy.paper.withValues(alpha: .12);
    return ColoredBox(
      color: Canopy.forestDeep,
      child: Column(
        children: [
          if (widget.onClose != null)
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceSm),
              child: Container(
                width: CanopySize.handleWidth,
                height: CanopySize.handleHeight,
                decoration: BoxDecoration(
                  color: Canopy.paper.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(CanopyRadius.pill),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(AppTheme.spaceLg,
                AppTheme.spaceSm, widget.onClose == null ? AppTheme.spaceLg : 0,
                AppTheme.spaceSm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'live.ghost_audience'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.titleMedium?.copyWith(
                            color: Canopy.paper, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Row(children: [
                        Flexible(
                            child: _ConnectionStatusChip(
                                state: widget.connectionState)),
                        const SizedBox(width: AppTheme.spaceSm),
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 12, color: Canopy.mist),
                        const SizedBox(width: 4),
                        Text('${widget.messages.length}',
                            style: theme.labelSmall?.copyWith(
                                color: Canopy.mist,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded, color: Canopy.paper),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: divider),
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spaceXl),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Canopy.paper.withValues(alpha: .08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.forum_outlined,
                                color: Canopy.mist, size: 26),
                          ),
                          const SizedBox(height: AppTheme.spaceMd),
                          Text('live.chat_empty_title'.tr(),
                              textAlign: TextAlign.center,
                              style: theme.titleSmall?.copyWith(
                                  color: Canopy.paper,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: AppTheme.spaceXs),
                          Text('live.chat_empty_subtitle'.tr(),
                              textAlign: TextAlign.center,
                              style: theme.bodySmall
                                  ?.copyWith(color: Canopy.mist)),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    reverse: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg,
                      vertical: AppTheme.spaceMd,
                    ),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final message =
                          widget.messages[widget.messages.length - 1 - index];
                      return _ChatTile(
                        cinema: true,
                        message: message,
                        onLongPress: widget.onMessageLongPress == null
                            ? null
                            : () => widget.onMessageLongPress!(message),
                      );
                    },
                  ),
          ),
          if (_readOnly)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceSm),
              child: Text('live.landscape_chat_read_only'.tr(),
                  style: theme.bodySmall?.copyWith(color: Canopy.mist),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: divider)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(AppTheme.spaceLg,
                      AppTheme.spaceSm, AppTheme.spaceSm, AppTheme.spaceSm),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          minLines: 1,
                          maxLines: 4,
                          style: theme.bodyMedium?.copyWith(color: Canopy.paper),
                          cursorColor: Canopy.mist,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSendText(),
                          decoration: InputDecoration(
                            hintText: 'live.chat_placeholder'.tr(),
                            hintStyle: theme.bodyMedium?.copyWith(
                                color: Canopy.paper.withValues(alpha: .55)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spaceLg,
                              vertical: AppTheme.spaceMd,
                            ),
                            filled: true,
                            fillColor: Canopy.paper.withValues(alpha: .08),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(CanopyRadius.pill),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(CanopyRadius.pill),
                              borderSide: const BorderSide(color: Canopy.mist),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      IconButton.filled(
                        onPressed: _hasText ? _handleSendText : null,
                        tooltip: 'live.chat_placeholder'.tr(),
                        icon: const Icon(Icons.send_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Canopy.leaf,
                          foregroundColor: Canopy.paper,
                          disabledBackgroundColor:
                              Canopy.paper.withValues(alpha: .12),
                          disabledForegroundColor:
                              Canopy.paper.withValues(alpha: .4),
                          minimumSize: const Size.square(CanopySize.target),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
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
  final bool cinema;

  const _ChatTile(
      {required this.message, this.onLongPress, this.cinema = false});

  @override
  Widget build(BuildContext context) {
    if (cinema) {
      return GestureDetector(
          onLongPress: onLongPress,
          child: Padding(
              padding:
                  const EdgeInsetsDirectional.only(bottom: AppTheme.spaceSm),
              child: CaChatBubble(
                name: message.senderName,
                message: (message.body == raisedHandGlyph
                        ? 'live.hand_raised_message'.tr()
                        : message.body == loweredHandGlyph
                            ? 'live.hand_lowered_message'.tr()
                            : message.body) +
                    (message.isEdited
                        ? ' ${'live.message_edited_badge'.tr()}'
                        : ''),
                time: TimeOfDay.fromDateTime(message.createdAt.toLocal())
                    .format(context),
                avatarUrl: message.senderAvatarUrl,
                isOwn: message.isCurrentUser,
                isSpeaker: message.badges.contains(ChatSenderBadge.speaker),
                dark: true,
                roleBadges: [
                  for (final badge in message.badges)
                    (
                      icon: switch (badge) {
                        ChatSenderBadge.speaker => CaGlyph.mic,
                        ChatSenderBadge.admin ||
                        ChatSenderBadge.moderator =>
                          CaGlyph.shield,
                        ChatSenderBadge.verified => CaGlyph.check,
                        ChatSenderBadge.organization => CaGlyph.home,
                      },
                      label: context.locale.languageCode == 'ar'
                          ? badge.labelAr
                          : badge.labelEn
                    )
                ],
              )));
    }
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
              backgroundColor:
                  message.isCurrentUser ? AppTheme.primary : AppTheme.surface,
              backgroundImage:
                  (message.senderAvatarUrl?.startsWith('assets/') ?? false)
                      ? AssetImage(message.senderAvatarUrl!) as ImageProvider
                      : (message.senderAvatarUrl != null
                          ? downscaledImage(
                              NetworkImage(message.senderAvatarUrl!),
                              width: 96)
                          : null),
              child: message.senderAvatarUrl == null
                  ? Text(
                      message.senderName.isNotEmpty
                          ? message.senderName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: AppTheme.onMedia,
                        fontSize: AppTheme.captionFont,
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
                              : Canopy.ink,
                        ),
                      ),
                      if (message.body == raisedHandGlyph)
                        const Icon(Icons.back_hand_rounded,
                            size: 15, color: AppTheme.warning),
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
                            border:
                                Border.all(color: AppTheme.primary, width: 0.8),
                          ),
                          child: Text(
                            'live.you'.tr(),
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontSize: AppTheme.captionFont,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      Text(
                        TimeOfDay.fromDateTime(message.createdAt.toLocal())
                            .format(context),
                        style: const TextStyle(
                          fontSize: AppTheme.captionFont,
                          color: Canopy.haze,
                        ),
                      ),
                      if (message.isPending)
                        const SizedBox(
                          width: 9,
                          height: 9,
                          child: HadayahLoadingIndicator(
                            strokeWidth: 1.5,
                            color: Canopy.haze,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: message.body == raisedHandGlyph
                              ? 'live.hand_raised_message'.tr()
                              : message.body == loweredHandGlyph
                                  ? 'live.hand_lowered_message'.tr()
                                  : message.body,
                        ),
                        if (message.isEdited)
                          TextSpan(
                            text: ' ${'live.message_edited_badge'.tr()}',
                            style: const TextStyle(color: Canopy.haze),
                          ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Canopy.slate,
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
    return Icon(badge.icon,
        size: 13,
        color: AppTheme.primary,
        semanticLabel: isAr ? badge.labelAr : badge.labelEn);
  }

  final isAdminBadge = badge == ChatSenderBadge.admin;
  final accentColor = isAdminBadge ? AppTheme.warning : AppTheme.primary;

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
        fontSize: AppTheme.captionFont,
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
          Canopy.leaf,
          'live.chat_status_live'.tr()
        ),
      ChatConnectionState.connecting => (
          AppTheme.warning,
          'live.chat_status_connecting'.tr()
        ),
      ChatConnectionState.reconnecting => (
          Canopy.liveCrimson,
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
        Flexible(
            child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: color,
              fontSize: AppTheme.captionFont,
              fontWeight: FontWeight.bold),
        )),
      ],
    );
  }
}
