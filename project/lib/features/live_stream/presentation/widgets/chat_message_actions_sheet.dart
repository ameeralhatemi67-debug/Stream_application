import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/live_chat_controller.dart';

/// Long-press action sheet for a chat message: "Report Message" and "Block
/// User" (Checkpoint 3 Phase 1). Only ever shown for someone else's message
/// -- callers are expected to gate on `!message.isCurrentUser` first.
Future<void> showChatMessageActionsSheet(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) async {
  final action = await showModalBottomSheet<_ChatMessageAction>(
    context: context,
    backgroundColor: AppTheme.darkSurface1,
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
      final confirmed = await _confirmDelete(context);
      if (confirmed != true || !context.mounted) return;
      await _runModerationAction(
        context,
        action: () => controller.deleteMessage(message.id),
        successToastKey: 'live.message_deleted_toast',
      );
  }
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
      SnackBar(content: Text('$e'), backgroundColor: AppTheme.accentRed),
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.darkSurface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.darkBorderSubtle),
      ),
      title: Text(
        'live.delete_message_confirm_title'.tr(),
        style: const TextStyle(
            color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('common.cancel'.tr(),
              style: const TextStyle(color: AppTheme.textMutedDark)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentRed,
            foregroundColor: Colors.white,
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
    backgroundColor: AppTheme.darkSurface1,
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
        backgroundColor: isDuplicate ? null : AppTheme.accentRed,
      ),
    );
  }
}

enum _ChatMessageAction { report, block, mute, delete }

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
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.flag_outlined, color: AppTheme.accentAmber),
            title: Text(
              'live.report_message'.tr(),
              style: const TextStyle(color: AppTheme.textPrimaryDark),
            ),
            onTap: () => Navigator.of(context).pop(_ChatMessageAction.report),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded, color: AppTheme.accentRed),
            title: Text(
              'live.block_user'.tr(),
              style: const TextStyle(color: AppTheme.textPrimaryDark),
            ),
            onTap: () => Navigator.of(context).pop(_ChatMessageAction.block),
          ),
          if (canModerate) ...[
            const Divider(color: AppTheme.darkBorderSubtle, height: 1),
            ListTile(
              leading: const Icon(Icons.mic_off_rounded,
                  color: AppTheme.accentAmber),
              title: Text(
                'live.mute_user'.tr(),
                style: const TextStyle(color: AppTheme.textPrimaryDark),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.mute),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.accentRed),
              title: Text(
                'live.delete_message'.tr(),
                style: const TextStyle(color: AppTheme.textPrimaryDark),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.delete),
            ),
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
                  color: AppTheme.textPrimaryDark,
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
                style: const TextStyle(color: AppTheme.textPrimaryDark),
              ),
              onTap: () => Navigator.of(context).pop(code),
            ),
          const SizedBox(height: AppTheme.spaceSm),
        ],
      ),
    );
  }
}
