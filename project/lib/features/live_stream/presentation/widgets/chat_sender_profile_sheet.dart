import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_feedback.dart';
import '../../../../core/widgets/ds/ca_fields.dart';
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

/// Time left on a mute: "4:20", or "1:02:20" past an hour.
String chatMuteRemaining(Duration left) {
  final total = left.inSeconds < 0 ? 0 : left.inSeconds;
  final h = total ~/ 3600, m = (total % 3600) ~/ 60, sec = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '$m:${two(sec)}';
}

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

  /// Set once this window appoints or removes the sender as a moderator, so the
  /// tag and ring follow at once.
  bool? _moderatorNow;

  /// Mute state, once read: whether the sender is muted and until when (null =
  /// the rest of this stream). [_muteKnown] stays false while loading.
  bool _muteKnown = false, _muted = false;
  DateTime? _muteEnds;
  Timer? _tick;

  /// An action is running, or the last one failed (shown inline).
  bool _busy = false;
  String? _error;

  CaChatRole get _role {
    final base = widget.message.chatRole;
    final now = _moderatorNow;
    if (now == null ||
        (base != CaChatRole.viewer && base != CaChatRole.moderator)) {
      return base;
    }
    return now ? CaChatRole.moderator : CaChatRole.viewer;
  }

  /// Moderating tools are for people who can moderate this room, on ordinary
  /// viewers and other moderators, never on yourself, the broadcaster or an
  /// admin.
  bool get _canActOnSender =>
      widget.controller.canModerate &&
      !widget.message.isCurrentUser &&
      (_role == CaChatRole.viewer || _role == CaChatRole.moderator);

  @override
  void initState() {
    super.initState();
    if (_role == CaChatRole.moderator) _loadModeratorSince();
    if (_canActOnSender) _loadMuteStatus();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _loadMuteStatus() async {
    try {
      final status =
          await widget.controller.muteStatus(widget.message.senderId);
      if (!mounted) return;
      _applyMute(status.muted, status.expiresAt);
    } catch (_) {
      // The list could not be read; the mute buttons still work.
      if (mounted) setState(() => _muteKnown = true);
    }
  }

  void _applyMute(bool muted, DateTime? ends) {
    _tick?.cancel();
    setState(() {
      _muteKnown = true;
      _muted = muted;
      _muteEnds = ends;
    });
    if (muted && ends != null) {
      // Counts down while the window is open, and flips back by itself when
      // the mute runs out.
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!ends.isAfter(DateTime.now())) {
          _tick?.cancel();
          setState(() {
            _muted = false;
            _muteEnds = null;
          });
        } else {
          setState(() {});
        }
      });
    }
  }

  /// Runs one moderation action, showing a busy state and any failure inline.
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on ModeratorRevokeDenied {
      if (mounted) setState(() => _error = 'live.moderator_revoke_denied'.tr());
    } catch (_) {
      if (mounted) setState(() => _error = 'live.sender_action_failed'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mute(Duration? duration) => _run(() async {
        await widget.controller
            .muteUser(widget.message.senderId, duration: duration);
        if (!mounted) return;
        _applyMute(
            true, duration == null ? null : DateTime.now().add(duration));
      });

  Future<void> _unmute() => _run(() async {
        await widget.controller.unmuteUser(widget.message.senderId);
        if (mounted) _applyMute(false, null);
      });

  Future<void> _toggleModerator() => _run(() async {
        final make = _role != CaChatRole.moderator;
        if (make) {
          await widget.controller
              .appointStreamModerator(widget.message.senderId);
        } else {
          await widget.controller
              .revokeStreamModerator(widget.message.senderId);
        }
        if (!mounted) return;
        setState(() {
          _moderatorNow = make;
          _moderatorSince = make ? DateTime.now() : null;
        });
      });

  Future<void> _deleteAll() async {
    final count = widget.controller.messages
        .where((m) => m.senderId == widget.message.senderId)
        .length;
    final confirmed = await showCaSheet<bool>(context,
        title: 'live.sender_delete_all_title'
            .tr(namedArgs: {'name': widget.message.senderName}),
        job: CaSheetJob.confirmation,
        bareChrome: true,
        body: Text(
            'live.sender_delete_all_body'.tr(namedArgs: {'count': '$count'})),
        actions: [
          Builder(
              builder: (ctx) => CaButton(
                  label: 'common.cancel'.tr(),
                  variant: CaButtonVariant.text,
                  onPressed: () => Navigator.pop(ctx, false))),
          Builder(
              builder: (ctx) => CaButton(
                  label: 'common.delete'.tr(),
                  variant: CaButtonVariant.destructive,
                  onPressed: () => Navigator.pop(ctx, true))),
        ]);
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await widget.controller.deleteMessagesFrom(widget.message.senderId);
      if (mounted) setState(() {});
    });
  }

  Widget _moderationSection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ends = _muteEnds;
    final isModerator = _role == CaChatRole.moderator;
    final count = widget.controller.messages
        .where((m) => m.senderId == widget.message.senderId)
        .length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: AppTheme.spaceXl),
      Text('live.sender_moderation_title'.tr(), style: textTheme.titleSmall),
      const SizedBox(height: AppTheme.spaceSm),
      if (_muteKnown && _muted) ...[
        DecoratedBox(
            decoration: BoxDecoration(
                color: Canopy.warningTint,
                borderRadius: BorderRadius.circular(CanopyRadius.input)),
            child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                child: Row(children: [
                  const CaIcon(CaGlyph.micoff, color: Canopy.warning),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                      child: Text(
                          ends == null
                              ? 'live.sender_muted_rest'.tr()
                              : 'live.sender_muted_for'.tr(namedArgs: {
                                  'time':
                                      chatMuteRemaining(ends.difference(DateTime.now()))
                                }),
                          style: textTheme.bodyMedium
                              ?.copyWith(color: Canopy.warning))),
                ]))),
        const SizedBox(height: AppTheme.spaceSm),
        CaButton(
            label: 'live.sender_unmute'.tr(),
            icon: CaGlyph.volume,
            variant: CaButtonVariant.secondary,
            loading: _busy,
            onPressed: _busy ? null : _unmute),
      ] else ...[
        Text('live.sender_mute_for'.tr(), style: textTheme.bodySmall),
        const SizedBox(height: AppTheme.spaceSm),
        Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              for (final (label, duration) in <(String, Duration?)>[
                ('live.sender_mute_5m'.tr(), const Duration(minutes: 5)),
                ('live.sender_mute_10m'.tr(), const Duration(minutes: 10)),
                ('live.sender_mute_1h'.tr(), const Duration(hours: 1)),
                ('live.sender_mute_rest'.tr(), null),
              ])
                CaChip(
                    label: label,
                    onSelected: _busy ? null : (_) => _mute(duration)),
            ]),
      ],
      const SizedBox(height: AppTheme.spaceMd),
      CaButton(
          label: (isModerator
                  ? 'live.sender_remove_moderator'
                  : 'live.sender_make_moderator')
              .tr(),
          icon: CaGlyph.shield,
          variant: CaButtonVariant.secondary,
          onPressed: _busy ? null : _toggleModerator),
      if (count > 0) ...[
        const SizedBox(height: AppTheme.spaceSm),
        CaButton(
            label: 'live.sender_delete_all'.tr(namedArgs: {'count': '$count'}),
            icon: CaGlyph.trash,
            variant: CaButtonVariant.destructive,
            onPressed: _busy ? null : _deleteAll),
      ],
      if (_error != null) ...[
        const SizedBox(height: AppTheme.spaceSm),
        Text(_error!,
            style: textTheme.bodySmall?.copyWith(color: Canopy.liveCrimson)),
      ],
    ]);
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
                'date':
                    MaterialLocalizations.of(context).formatMediumDate(since)
              })),
        ],
        if (_canActOnSender) _moderationSection(context),
        const SizedBox(height: AppTheme.spaceXl),
        Text('${'live.sender_history_title'.tr()} (${history.length})',
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
