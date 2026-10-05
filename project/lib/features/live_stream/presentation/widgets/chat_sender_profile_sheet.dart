import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_feedback.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../models/chat_message_model.dart';
import '../../services/live_chat_controller.dart';

/// How a chat message's sender looks in chat, from the badges the server
/// resolved for them. A broadcaster outranks an admin, who outranks a
/// moderator: the ring shows the highest.
extension ChatMessageRole on ChatMessageModel {
  CaChatRole get chatRole {
    if (badges.contains(ChatSenderBadge.speaker) ||
        badges.contains(ChatSenderBadge.organization)) {
      return CaChatRole.broadcaster;
    }
    if (badges.contains(ChatSenderBadge.admin)) return CaChatRole.admin;
    if (badges.contains(ChatSenderBadge.moderator)) return CaChatRole.moderator;
    return CaChatRole.viewer;
  }
}

/// Opens the profile window for the sender of [message]: who they are, what
/// they are in this room, and what they have written in it so far.
Future<void> showChatSenderProfile(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) =>
    showCaSheet<void>(context,
        title: '',
        framed: false,
        fullWidthOnPhone: true,
        flushOnPhone: true,
        body: Builder(
            builder: (sheetContext) => ChangeNotifierProvider.value(
                value: context.read<AppProvider>(),
                child: SafeArea(
                    top: false,
                    child: ChatSenderProfileSheet(
                        message: message, controller: controller)))));

class ChatSenderProfileSheet extends StatefulWidget {
  const ChatSenderProfileSheet(
      {super.key, required this.message, required this.controller});
  final ChatMessageModel message;
  final LiveChatController controller;
  @override
  State<ChatSenderProfileSheet> createState() => _ChatSenderProfileSheetState();
}

class _ChatSenderProfileSheetState extends State<ChatSenderProfileSheet> {
  /// Null until known, and still null for a moderator whose appointment date
  /// the server does not return.
  DateTime? _moderatorSince;

  CaChatRole get _role => widget.message.chatRole;

  @override
  void initState() {
    super.initState();
    if (_role == CaChatRole.moderator) _loadModeratorSince();
  }

  Future<void> _loadModeratorSince() async {
    final since =
        await widget.controller.moderatorSince(widget.message.senderId);
    if (mounted && since != null) setState(() => _moderatorSince = since);
  }

  /// What the sender belongs to: a streamer's organization, the platform for
  /// an admin; nothing for an ordinary viewer.
  String? _affiliation(BuildContext context, String lang) {
    switch (_role) {
      case CaChatRole.admin:
        return 'live.sender_affiliation_admin'.tr();
      case CaChatRole.broadcaster:
        final provider = context.read<AppProvider>();
        for (final streamer in provider.streamers) {
          if (streamer.channelProfileId == widget.message.senderId ||
              streamer.streamerId == widget.message.senderId) {
            final organization = streamer.getLocalizedOrganization(lang).trim();
            return organization.isEmpty ? null : organization;
          }
        }
        return null;
      case CaChatRole.moderator:
      case CaChatRole.viewer:
        return null;
    }
  }

  ({String label, Color color}) get _tag => switch (_role) {
        CaChatRole.admin => (
            label: 'live.sender_tag_admin'.tr(),
            color: Canopy.brandGreen
          ),
        CaChatRole.moderator => (
            label: 'live.sender_tag_moderator'.tr(),
            color: const Color(0xFF4B3F96)
          ),
        CaChatRole.broadcaster => (
            label: (widget.message.badges.contains(ChatSenderBadge.organization)
                    ? 'live.sender_tag_organization'
                    : 'live.sender_tag_broadcaster')
                .tr(),
            color: Canopy.liveCrimson
          ),
        CaChatRole.viewer => (
            label: 'live.sender_tag_viewer'.tr(),
            color: Canopy.slate
          ),
      };

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final textTheme = Theme.of(context).textTheme;
    final message = widget.message;
    final affiliation = _affiliation(context, lang);
    final history = widget.controller.messages
        .where((m) => m.senderId == message.senderId)
        .toList()
        .reversed
        .toList();
    final tag = _tag;
    final since = _moderatorSince;
    return CaSheet(
      bareChrome: true,
      title: 'live.sender_profile_title'.tr(),
      onClose: () => Navigator.pop(context),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CaAvatar(
              name: message.senderName,
              url: message.senderAvatarUrl,
              radius: 32,
              live: _role == CaChatRole.broadcaster,
              ring: switch (_role) {
                CaChatRole.admin => CaAvatarRing.admin,
                CaChatRole.moderator => CaAvatarRing.moderator,
                _ => CaAvatarRing.none,
              }),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(message.senderName, style: textTheme.titleLarge),
                const SizedBox(height: AppTheme.spaceXs),
                DecoratedBox(
                    decoration: BoxDecoration(
                        color: tag.color,
                        borderRadius: BorderRadius.circular(CanopyRadius.pill)),
                    child: Padding(
                        padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppTheme.spaceMd,
                            vertical: AppTheme.spaceXs),
                        child: Text(tag.label,
                            style: textTheme.labelMedium?.copyWith(
                                color: Canopy.paper,
                                fontWeight: FontWeight.w700)))),
              ])),
        ]),
        if (affiliation != null) ...[
          const SizedBox(height: AppTheme.spaceLg),
          _InfoRow(glyph: CaGlyph.home, text: affiliation),
        ],
        if (_role == CaChatRole.moderator && since != null) ...[
          const SizedBox(height: AppTheme.spaceSm),
          _InfoRow(
              glyph: CaGlyph.cal,
              text: 'live.sender_moderator_since'.tr(namedArgs: {
                'date': MaterialLocalizations.of(context).formatMediumDate(since)
              })),
        ],
        const SizedBox(height: AppTheme.spaceXl),
        Text(
            '${'live.sender_history_title'.tr()} (${history.length})',
            style: textTheme.titleSmall),
        const SizedBox(height: AppTheme.spaceSm),
        if (history.isEmpty)
          Text('live.sender_history_empty'.tr(), style: textTheme.bodySmall)
        else
          for (final item in history.take(40))
            Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: Canopy.mint,
                        borderRadius:
                            BorderRadius.circular(CanopyRadius.input)),
                    child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium),
                              const SizedBox(height: AppTheme.spaceXs),
                              Text(
                                  TimeOfDay.fromDateTime(
                                          item.createdAt.toLocal())
                                      .format(context),
                                  style: textTheme.labelSmall
                                      ?.copyWith(color: Canopy.haze)),
                            ])))),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.glyph, required this.text});
  final CaGlyph glyph;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CaIcon(glyph, size: CanopySize.inlineIcon),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
      ]);
}
