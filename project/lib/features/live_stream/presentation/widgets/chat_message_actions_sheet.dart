import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/live_chat_controller.dart';

/// Long-press action sheet for a chat message (Cluster 4 Task 13). Branches
/// on `message.isCurrentUser`: the sender gets Edit/Delete on their own
/// message; anyone else's message offers Report/Hide/Block, plus
/// Mute/Delete/Appoint-Moderator when the viewer can moderate this stream
/// (Checkpoint 3 Phase 1 / Cluster 4 Task 15).
Future<void> showChatMessageActionsSheet(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) async {
  final action = await showModalBottomSheet<_ChatMessageAction>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
    ),
    builder: (context) => _ChatMessageActionsMenu(
      message: message,
      canModerate: controller.canModerate,
    ),
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case _ChatMessageAction.edit:
      await _handleEdit(context, message: message, controller: controller);
    case _ChatMessageAction.deleteOwn:
      final confirmed = await _confirmDelete(
        context,
        title: 'live.delete_own_message_confirm_title'.tr(),
      );
      if (confirmed != true || !context.mounted) return;
      await _runModerationAction(
        context,
        action: () => controller.deleteMessage(message.id),
        successToastKey: 'live.message_deleted_toast',
      );
    case _ChatMessageAction.hide:
      await controller.hideChatMessage(message.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('live.message_hidden_toast'.tr())),
      );
    case _ChatMessageAction.report:
      await _handleReport(context, message: message, controller: controller);
    case _ChatMessageAction.block:
      await controller.blockUser(message.senderId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('live.user_blocked_toast'.tr())),
      );
    case _ChatMessageAction.mute:
      await _runModerationAction(
        context,
        action: () => controller.muteUser(message.senderId),
        successToastKey: 'live.user_muted_toast',
      );
    case _ChatMessageAction.delete:
      final confirmed = await _confirmDelete(
        context,
        title: 'live.delete_message_confirm_title'.tr(),
      );
      if (confirmed != true || !context.mounted) return;
      await _runModerationAction(
        context,
        action: () => controller.deleteMessage(message.id),
        successToastKey: 'live.message_deleted_toast',
      );
    case _ChatMessageAction.appointModerator:
      await _runModerationAction(
        context,
        action: () => controller.appointStreamModerator(message.senderId),
        successToastKey: 'live.moderator_appointed_toast',
      );
    case _ChatMessageAction.revokeModerator:
      await _runModerationAction(
        context,
        action: () => controller.revokeStreamModerator(message.senderId),
        successToastKey: 'live.moderator_revoked_toast',
      );
  }
}

Future<void> _handleEdit(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) async {
  final textController = TextEditingController(text: message.body);
  final newBody = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Text(
        'live.edit_message_title'.tr(),
        style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: textController,
        autofocus: true,
        maxLength: 500,
        maxLines: 3,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'live.edit_message_hint'.tr(),
          hintStyle: const TextStyle(color: AppTheme.textMuted),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text('common.cancel'.tr(),
              style: const TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.onMedia,
          ),
          onPressed: () =>
              Navigator.of(dialogContext).pop(textController.text),
          child: Text('live.save_edit'.tr()),
        ),
      ],
    ),
  );
  textController.dispose();
  if (newBody == null || newBody.trim().isEmpty || !context.mounted) return;
  if (newBody.trim() == message.body) return;

  await _runModerationAction(
    context,
    action: () => controller.editChatMessage(message.id, newBody),
    successToastKey: 'live.message_updated_toast',
  );
}

Future<void> _runModerationAction(
  BuildContext context, {
  required Future<void> Function() action,
  required String successToastKey,
}) async {
  try {
    await action();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(successToastKey.tr())),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, {required String title}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Text(
        title,
        style: const TextStyle(
            color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr(),
              style: const TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.danger,
            foregroundColor: AppTheme.onMedia,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('common.delete'.tr()),
        ),
      ],
    ),
  );
}

Future<void> _handleReport(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) async {
  final reason = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMd)),
    ),
    builder: (context) => const _ReportReasonMenu(),
  );
  if (reason == null || !context.mounted) return;

  try {
    await controller.reportMessage(
      messageId: message.id,
      reportedSenderId: message.senderId,
      reason: reason,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('live.report_submitted_toast'.tr())),
    );
  } catch (e) {
    if (!context.mounted) return;
    final isDuplicate = '$e'.contains('duplicate key');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isDuplicate ? 'live.report_already_submitted_toast'.tr() : '$e',
        ),
        backgroundColor: isDuplicate ? null : AppTheme.danger,
      ),
    );
  }
}

enum _ChatMessageAction {
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

class _ChatMessageActionsMenu extends StatelessWidget {
  final ChatMessageModel message;
  final bool canModerate;

  const _ChatMessageActionsMenu({
    required this.message,
    required this.canModerate,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg,
              AppTheme.spaceMd,
              AppTheme.spaceLg,
              AppTheme.spaceSm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                message.senderName,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          if (message.isCurrentUser) ...[
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: AppTheme.primary),
              title: Text(
                'live.edit_message'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.edit),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.danger),
              title: Text(
                'live.delete_message'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () =>
                  Navigator.of(context).pop(_ChatMessageAction.deleteOwn),
            ),
          ] else ...[
            ListTile(
              leading:
                  const Icon(Icons.flag_outlined, color: AppTheme.warning),
              title: Text(
                'live.report_message'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.report),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined,
                  color: AppTheme.textSecondary),
              title: Text(
                'live.hide_message'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.hide),
            ),
            ListTile(
              leading:
                  const Icon(Icons.block_rounded, color: AppTheme.danger),
              title: Text(
                'live.block_user'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.block),
            ),
            if (canModerate) ...[
              const Divider(color: AppTheme.border, height: 1),
              ListTile(
                leading: const Icon(Icons.mic_off_rounded,
                    color: AppTheme.warning),
                title: Text(
                  'live.mute_user'.tr(),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () =>
                    Navigator.of(context).pop(_ChatMessageAction.mute),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.danger),
                title: Text(
                  'live.delete_message'.tr(),
                  style: const TextStyle(color: AppTheme.textPrimary),
                ),
                onTap: () =>
                    Navigator.of(context).pop(_ChatMessageAction.delete),
              ),
              if (message.isStreamModerator)
                ListTile(
                  leading: const Icon(Icons.remove_moderator_outlined,
                      color: AppTheme.danger),
                  title: Text(
                    'live.revoke_moderator'.tr(),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () => Navigator.of(context)
                      .pop(_ChatMessageAction.revokeModerator),
                )
              else
                ListTile(
                  leading: const Icon(Icons.add_moderator_outlined,
                      color: AppTheme.success),
                  title: Text(
                    'live.appoint_moderator'.tr(),
                    style: const TextStyle(color: AppTheme.textPrimary),
                  ),
                  onTap: () => Navigator.of(context)
                      .pop(_ChatMessageAction.appointModerator),
                ),
            ],
          ],
          const SizedBox(height: AppTheme.spaceSm),
        ],
      ),
    );
  }
}

class _ReportReasonMenu extends StatelessWidget {
  const _ReportReasonMenu();

  // (stable reason code stored in chat_reports.reason, localization key) --
  // the code is what's persisted, so admin review isn't a mix of whatever
  // language each reporter's device happened to be in.
  static const _reasons = [
    ('spam', 'report_reason_spam'),
    ('harassment', 'report_reason_harassment'),
    ('hate_speech', 'report_reason_hate'),
    ('other', 'report_reason_other'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceLg,
              AppTheme.spaceMd,
              AppTheme.spaceLg,
              AppTheme.spaceSm,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'live.report_reason_prompt'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          for (final (code, key) in _reasons)
            ListTile(
              title: Text(
                'live.$key'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              onTap: () => Navigator.of(context).pop(code),
            ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
      ),
    );
  }
}
