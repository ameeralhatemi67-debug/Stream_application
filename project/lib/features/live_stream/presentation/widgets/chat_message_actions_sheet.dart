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
    builder: (context) => _ChatMessageActionsMenu(message: message),
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
  }
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

enum _ChatMessageAction { report, block }

class _ChatMessageActionsMenu extends StatelessWidget {
  final ChatMessageModel message;

  const _ChatMessageActionsMenu({required this.message});

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
