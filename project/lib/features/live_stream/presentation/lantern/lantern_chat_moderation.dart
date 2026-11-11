import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/utils/text_direction.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../models/chat_message_model.dart';
import '../../services/chat_block_list.dart';
import '../../services/live_chat_controller.dart';
import '../widgets/chat_message_actions_sheet.dart' show chatBlockFailureKey;
import '../widgets/chat_sender_profile_sheet.dart';

/// The room's chat moderation in Lantern and Arch: the menu of a message and
/// the sender's window. They offer what the older sheets offer, to the same
/// people, and call the same `LiveChatController` methods; deleting is
/// press-and-hold.

enum _MessageAction {
  edit,
  deleteOwn,
  hide,
  report,
  block,
  mute,
  delete,
  appointModerator,
  revokeModerator,
}

void _say(BuildContext context, String key, {bool warn = false}) {
  if (context.mounted) {
    lanternToast(context, key.tr(),
        warn: warn, icon: warn ? LGlyph.warn : LGlyph.check);
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action,
    String successKey) async {
  try {
    await action();
    if (!context.mounted) return;
    _say(context, successKey);
  } catch (e) {
    if (!context.mounted) return;
    lanternToast(
        context,
        e is ModeratorRevokeDenied
            ? 'live.moderator_revoke_denied'.tr()
            : 'live.sender_action_failed'.tr(),
        warn: true,
        icon: LGlyph.warn);
  }
}

/// A dialog whose confirm button is press-and-hold; true when held.
Future<bool> lanternHoldConfirm(BuildContext context,
    {required String title,
    String? body,
    required String hold,
    LGlyph icon = LGlyph.trash}) async {
  final held = await showLanternDialog<bool>(context,
      title: title,
      body: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (body != null) ...[
                  Text(body,
                      style: Lantern.textStyle(14.5,
                          color: ctx.lt.muted, height: 1.5)),
                  const SizedBox(height: 8),
                ],
                Text('lantern.admin.hold_hint'.tr(),
                    style: Lantern.textStyle(12.5,
                        color: ctx.lt.muted, height: 1.4)),
              ]),
      actions: (ctx) => [
            LButton(
                label: 'common.cancel'.tr(),
                kind: LButtonKind.ghost,
                onPressed: () => Navigator.of(ctx).pop(false)),
            LHoldButton(
                key: const ValueKey('lantern-room-hold'),
                label: hold,
                icon: icon,
                onConfirmed: () => Navigator.of(ctx).pop(true)),
          ]);
  return held == true;
}

/// The menu of one chat message: edit or delete your own; report, hide or
/// block someone else's, and moderate it when this room lets you.
Future<void> showLanternChatMessageActions(BuildContext context,
    {required ChatMessageModel message,
    required LiveChatController controller}) async {
  final mine = message.isCurrentUser;
  final rows = <(_MessageAction, LGlyph, String, bool)>[
    if (mine) ...[
      (_MessageAction.edit, LGlyph.edit, 'live.edit_message', false),
      (_MessageAction.deleteOwn, LGlyph.trash, 'live.delete_message', true),
    ] else ...[
      (_MessageAction.report, LGlyph.flag, 'live.report_message', false),
      (_MessageAction.hide, LGlyph.eyeoff, 'live.hide_message', false),
      (_MessageAction.block, LGlyph.ban, 'live.block_user', true),
      if (controller.canModerate) ...[
        (_MessageAction.mute, LGlyph.micoff, 'live.mute_user', false),
        (_MessageAction.delete, LGlyph.trash, 'live.delete_message', true),
        if (message.isStreamModerator)
          (
            _MessageAction.revokeModerator,
            LGlyph.shield,
            'live.revoke_moderator',
            true
          )
        else
          (
            _MessageAction.appointModerator,
            LGlyph.shield,
            'live.appoint_moderator',
            false
          ),
      ],
    ],
  ];
  final action = await showLanternSheet<_MessageAction>(context,
      title: message.senderName,
      body: (ctx) => Column(
              key: const ValueKey('lantern-message-actions'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (action, icon, key, danger) in rows)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LRow(
                          key: ValueKey('lantern-message-${action.name}'),
                          icon: icon,
                          title: key.tr(),
                          danger: danger,
                          arrow: false,
                          onTap: () => Navigator.of(ctx).pop(action))),
              ]));
  if (action == null || !context.mounted) return;
  switch (action) {
    case _MessageAction.edit:
      await _edit(context, message, controller);
    case _MessageAction.deleteOwn:
      if (await lanternHoldConfirm(context,
              title: 'live.delete_own_message_confirm_title'.tr(),
              hold: 'lantern.admin.hold_delete'.tr()) &&
          context.mounted) {
        await _run(context, () => controller.deleteMessage(message.id),
            'live.message_deleted_toast');
      }
    case _MessageAction.hide:
      await controller.hideChatMessage(message.id);
      if (!context.mounted) return;
      _say(context, 'live.message_hidden_toast');
    case _MessageAction.report:
      await _report(context, message, controller);
    case _MessageAction.block:
      String? errorKey;
      try {
        await controller.blockUser(message.senderId);
      } on ChatBlockException catch (e) {
        errorKey = chatBlockFailureKey(e.failure);
      } catch (_) {
        errorKey = chatBlockFailureKey(ChatBlockFailure.network);
      }
      if (!context.mounted) return;
      _say(context, errorKey ?? 'live.user_blocked_toast',
          warn: errorKey != null);
    case _MessageAction.mute:
      await _run(context, () => controller.muteUser(message.senderId),
          'live.user_muted_toast');
    case _MessageAction.delete:
      if (await lanternHoldConfirm(context,
              title: 'live.delete_message_confirm_title'.tr(),
              hold: 'lantern.admin.hold_delete'.tr()) &&
          context.mounted) {
        await _run(context, () => controller.deleteMessage(message.id),
            'live.message_deleted_toast');
      }
    case _MessageAction.appointModerator:
      await _run(
          context,
          () => controller.appointStreamModerator(message.senderId),
          'live.moderator_appointed_toast');
    case _MessageAction.revokeModerator:
      await _run(
          context,
          () => controller.revokeStreamModerator(message.senderId),
          'live.moderator_revoked_toast');
  }
}

Future<void> _edit(BuildContext context, ChatMessageModel message,
    LiveChatController controller) async {
  final text = TextEditingController(text: message.body);
  final body = await showLanternDialog<String>(context,
      title: 'live.edit_message_title'.tr(),
      body: (ctx) => LField(
          key: const ValueKey('lantern-edit-message'),
          controller: text,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          hint: 'live.edit_message_hint'.tr()),
      actions: (ctx) => [
            LButton(
                label: 'common.cancel'.tr(),
                kind: LButtonKind.ghost,
                onPressed: () => Navigator.of(ctx).pop()),
            LButton(
                key: const ValueKey('lantern-edit-save'),
                label: 'live.save_edit'.tr(),
                onPressed: () => Navigator.of(ctx).pop(text.text)),
          ]);
  // The field is drawn during the closing animation; the controller is left
  // to the garbage collector.
  if (body == null || body.trim().isEmpty || !context.mounted) return;
  if (body.trim() == message.body) return;
  await _run(context, () => controller.editChatMessage(message.id, body),
      'live.message_updated_toast');
}

Future<void> _report(BuildContext context, ChatMessageModel message,
    LiveChatController controller) async {
  const reasons = [
    (ChatReportReason.spam, 'report_reason_spam'),
    (ChatReportReason.harassment, 'report_reason_harassment'),
    (ChatReportReason.hateSpeech, 'report_reason_hate'),
    (ChatReportReason.other, 'report_reason_other'),
  ];
  final reason = await showLanternSheet<String>(context,
      title: 'live.report_reason_prompt'.tr(),
      body: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (code, key) in reasons)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LRow(
                          key: ValueKey('lantern-report-reason-$code'),
                          title: 'live.$key'.tr(),
                          arrow: false,
                          onTap: () => Navigator.of(ctx).pop(code))),
              ]));
  if (reason == null || !context.mounted) return;
  try {
    await controller.reportMessage(
        messageId: message.id,
        reportedSenderId: message.senderId,
        reason: reason);
    if (!context.mounted) return;
    _say(context, 'live.report_submitted_toast');
  } catch (e) {
    final key = reportFailureKey(e);
    if (!context.mounted) return;
    _say(context, key, warn: key != 'live.report_already_submitted_toast');
  }
}

/// Opens the sender's window. [ChatSenderProfileSheet] keeps its state and
/// actions and draws [LanternSenderProfile] under Lantern.
Future<void> showLanternChatSenderProfile(BuildContext context,
        {required ChatMessageModel message,
        required LiveChatController controller}) =>
    showLanternSheet<void>(context,
        title: 'live.sender_profile_title'.tr(),
        body: (ctx) => ChangeNotifierProvider.value(
            value: context.read<AppProvider>(),
            child: ChatSenderProfileSheet(
                message: message, controller: controller)));

/// The sender's window: who they are here, the moderation the viewer may
/// use on them, and what they have written in this room.
class LanternSenderProfile extends StatelessWidget
    implements LanternSkinWidget {
  const LanternSenderProfile(
      {super.key,
      required this.name,
      required this.avatarUrl,
      required this.roleLabel,
      required this.ring,
      required this.affiliation,
      required this.moderatorSince,
      required this.canAct,
      required this.muteKnown,
      required this.muted,
      required this.muteLeft,
      required this.isModerator,
      required this.busy,
      required this.error,
      required this.history,
      required this.onMute,
      required this.onUnmute,
      required this.onToggleModerator,
      required this.onDeleteAll});

  final String name, roleLabel;
  final String? avatarUrl, affiliation, moderatorSince, error;
  final LRing ring;
  final bool canAct, muteKnown, muted, isModerator, busy;

  /// Time left on the mute ("4:20"); null mutes for the rest of the stream.
  final String? muteLeft;

  /// The sender's messages in this room, newest first.
  final List<ChatMessageModel> history;
  final ValueChanged<Duration?> onMute;
  final VoidCallback onUnmute, onToggleModerator, onDeleteAll;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final count = history.length;
    return Column(
        key: const ValueKey('lantern-sender-profile'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            LAvatar(
                name: name,
                image: resolveImageProviderOrNull(avatarUrl),
                size: 60,
                ring: ring),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(name,
                      style: Lantern.displayStyle(18,
                          color: t.fg,
                          height: context.lanternArabic ? 1.45 : 1.25)),
                  const SizedBox(height: 6),
                  LTag(roleLabel,
                      tone: switch (ring) {
                        LRing.admin => LTone.gold,
                        LRing.mod => LTone.mod,
                        LRing.live => LTone.live,
                        _ => LTone.neutral,
                      }),
                ])),
          ]),
          if (affiliation != null) ...[
            const SizedBox(height: 14),
            _Line(icon: LGlyph.org, text: affiliation!),
          ],
          if (moderatorSince != null) ...[
            const SizedBox(height: 8),
            _Line(icon: LGlyph.calendar, text: moderatorSince!),
          ],
          if (canAct) ...[
            const SizedBox(height: 18),
            Semantics(
                header: true,
                child: Text('live.sender_moderation_title'.tr(),
                    style: Lantern.textStyle(15,
                        color: t.fg, weight: FontWeight.w700))),
            const SizedBox(height: 8),
            if (muteKnown && muted) ...[
              LBanner(
                  muteLeft == null
                      ? 'live.sender_muted_rest'.tr()
                      : 'live.sender_muted_for'
                          .tr(namedArgs: {'time': muteLeft!}),
                  tone: LTone.warn,
                  icon: LGlyph.micoff),
              const SizedBox(height: 8),
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: LButton(
                      key: const ValueKey('lantern-sender-unmute'),
                      label: 'live.sender_unmute'.tr(),
                      icon: LGlyph.volume,
                      kind: LButtonKind.secondary,
                      loading: busy,
                      onPressed: busy ? null : onUnmute)),
            ] else ...[
              Text('live.sender_mute_for'.tr(),
                  style: Lantern.textStyle(13, color: t.muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (label, duration) in <(String, Duration?)>[
                  ('live.sender_mute_5m'.tr(), const Duration(minutes: 5)),
                  ('live.sender_mute_10m'.tr(), const Duration(minutes: 10)),
                  ('live.sender_mute_1h'.tr(), const Duration(hours: 1)),
                  ('live.sender_mute_rest'.tr(), null),
                ])
                  LChip(
                      key: ValueKey(
                          'lantern-sender-mute-${duration?.inMinutes ?? 'rest'}'),
                      label: label,
                      icon: LGlyph.micoff,
                      onTap: busy ? null : () => onMute(duration)),
              ]),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              LButton(
                  key: const ValueKey('lantern-sender-moderator'),
                  label: (isModerator
                          ? 'live.sender_remove_moderator'
                          : 'live.sender_make_moderator')
                      .tr(),
                  icon: LGlyph.shield,
                  kind: LButtonKind.secondary,
                  onPressed: busy ? null : onToggleModerator),
              if (count > 0)
                LButton(
                    key: const ValueKey('lantern-sender-delete-all'),
                    label: 'live.sender_delete_all'
                        .tr(namedArgs: {'count': '$count'}),
                    icon: LGlyph.trash,
                    kind: LButtonKind.danger,
                    onPressed: busy ? null : onDeleteAll),
            ]),
            if (error != null) ...[
              const SizedBox(height: 8),
              LBanner(error!, tone: LTone.live, icon: LGlyph.warn),
            ],
          ],
          const SizedBox(height: 18),
          Text('${'live.sender_history_title'.tr()} ($count)',
              style:
                  Lantern.textStyle(15, color: t.fg, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (history.isEmpty)
            Text('live.sender_history_empty'.tr(),
                style: Lantern.textStyle(13, color: t.muted))
          else
            for (final item in history.take(40))
              Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: t.sunk,
                      borderRadius: BorderRadius.circular(Lantern.radiusTile)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(item.body,
                            textDirection: firstStrongTextDirection(item.body),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Lantern.textStyle(14,
                                color: t.fg, height: 1.45)),
                        const SizedBox(height: 4),
                        Text(
                            TimeOfDay.fromDateTime(item.createdAt.toLocal())
                                .format(context),
                            style: Lantern.textStyle(12, color: t.muted)
                                .copyWith(fontFeatures: Lantern.tabular)),
                      ])),
        ]);
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});
  final LGlyph icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(children: [
        LIcon(icon, size: 18, color: context.lt.goldInk),
        const SizedBox(width: 10),
        Expanded(
            child:
                Text(text, style: Lantern.textStyle(14, color: context.lt.fg))),
      ]);
}
