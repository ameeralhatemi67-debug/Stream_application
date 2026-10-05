import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/chat_message_model.dart';
import '../../services/chat_block_list.dart';
import '../../services/live_chat_controller.dart';
import 'live_chat_layout.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_button.dart';

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
  final action = await _showChatMenu<_ChatMessageAction>(
    context,
    _ChatMessageActionsMenu(
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
      await _handleBlock(context, message: message, controller: controller);
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

Future<T?> _showChatMenu<T>(BuildContext context, Widget menu) {
  // Laptop actions stay beside the iframe, on the same root navigator.
  // Phone actions retain the native bottom-sheet local navigator default.
  final laptop = isLaptopLiveLayout(context);
  return showCaSheet<T>(context,
      title: '',
      body: menu,
      framed: false,
      job: laptop ? CaSheetJob.studio : CaSheetJob.standard,
      constraints:
          laptop ? const BoxConstraints(maxWidth: CanopySize.wizardRail) : null,
      useRootNavigator: laptop);
}

Widget _placeChatDialog(BuildContext context, Widget dialog) {
  if (!isLaptopLiveLayout(context)) return dialog;
  return Align(
    alignment: AlignmentDirectional.centerEnd,
    child: SizedBox(width: 320, child: dialog),
  );
}

Future<void> _handleEdit(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) async {
  final textController = TextEditingController(text: message.body);
  final route = createCaDialogRoute<String>(
    context: context,
    builder: (dialogContext) => _placeChatDialog(
      dialogContext,
      CaAlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: Canopy.hairline),
        ),
        title: Text(
          'live.edit_message_title'.tr(),
          style: const TextStyle(
              color: Canopy.ink, fontWeight: FontWeight.bold),
        ),
        scrollable: true,
        content: isCompactLandscapeChat(dialogContext)
            ? Text('live.landscape_chat_read_only'.tr())
            : TextField(
                controller: textController,
                autofocus: true,
                maxLength: 500,
                maxLines: 3,
                style: const TextStyle(color: Canopy.ink),
                decoration: InputDecoration(
                  hintText: 'live.edit_message_hint'.tr(),
                  hintStyle: const TextStyle(color: Canopy.haze),
                ),
              ),
        actions: [
          CaButton(
              label: 'common.cancel'.tr(),
              variant: CaButtonVariant.text,
              onPressed: () => Navigator.of(dialogContext).pop()),
          CaButton(
              label: 'live.save_edit'.tr(),
              variant: CaButtonVariant.primary,
              onPressed: isCompactLandscapeChat(dialogContext)
                  ? null
                  : () => Navigator.of(dialogContext).pop(textController.text)),
        ],
      ),
    ),
  );
  final newBody = await Navigator.of(context, rootNavigator: true).push(route);
  // The pop result precedes the reverse animation; the field can still rebuild.
  await route.completed;
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
      SnackBar(content: Text('$e'), backgroundColor: Canopy.liveCrimson),
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, {required String title}) {
  return showCaDialog<bool>(
    context: context,
    builder: (context) => _placeChatDialog(
      context,
      CaAlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: Canopy.hairline),
        ),
        title: Text(
          title,
          style: const TextStyle(
              color: Canopy.ink, fontWeight: FontWeight.bold),
        ),
        actions: [
          CaButton(
              label: 'common.cancel'.tr(),
              variant: CaButtonVariant.text,
              onPressed: () => Navigator.of(context).pop(false)),
          CaButton(
              label: 'common.delete'.tr(),
              variant: CaButtonVariant.destructive,
              onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    ),
  );
}

/// The block holds only once the server accepts it, so a refusal is shown
/// and the sender stays visible rather than being hidden on this device alone.
Future<void> _handleBlock(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) async {
  String? errorKey;
  try {
    await controller.blockUser(message.senderId);
  } on ChatBlockException catch (e) {
    errorKey = chatBlockFailureKey(e.failure);
  } catch (_) {
    errorKey = chatBlockFailureKey(ChatBlockFailure.network);
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text((errorKey ?? 'live.user_blocked_toast').tr()),
      backgroundColor: errorKey == null ? null : Canopy.liveCrimson,
    ),
  );
}

/// Localization key for a refused block or unblock.
String chatBlockFailureKey(ChatBlockFailure failure) => switch (failure) {
      ChatBlockFailure.signedOut => 'live.block_sign_in_toast',
      ChatBlockFailure.notPermitted => 'live.block_not_permitted_toast',
      ChatBlockFailure.targetGone => 'live.block_target_gone_toast',
      ChatBlockFailure.network => 'live.block_failed_toast',
    };

Future<void> _handleReport(
  BuildContext context, {
  required ChatMessageModel message,
  required LiveChatController controller,
}) async {
  final reason =
      await _showChatMenu<String>(context, const _ReportReasonMenu());
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
    final key = reportFailureKey(e);
    final isDuplicate = key == 'live.report_already_submitted_toast';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(key.tr()),
        backgroundColor: isDuplicate ? null : Canopy.liveCrimson,
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
    return CaSheet(
        title: message.senderName,
        onClose: () => Navigator.of(context).pop(),
        body: Column(mainAxisSize: MainAxisSize.min, children: [
          if (message.isCurrentUser) ...[
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppTheme.primary),
              title: Text(
                'live.edit_message'.tr(),
                style: const TextStyle(color: Canopy.ink),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.edit),
            ),
            const Divider(color: Canopy.mist),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Canopy.liveCrimson),
              title: Text(
                'live.delete_message'.tr(),
                style: const TextStyle(color: Canopy.liveCrimson),
              ),
              onTap: () =>
                  Navigator.of(context).pop(_ChatMessageAction.deleteOwn),
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppTheme.warning),
              title: Text(
                'live.report_message'.tr(),
                style: const TextStyle(color: Canopy.ink),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.report),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined,
                  color: Canopy.slate),
              title: Text(
                'live.hide_message'.tr(),
                style: const TextStyle(color: Canopy.ink),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.hide),
            ),
            const Divider(color: Canopy.mist),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Canopy.liveCrimson),
              title: Text(
                'live.block_user'.tr(),
                style: const TextStyle(color: Canopy.liveCrimson),
              ),
              onTap: () => Navigator.of(context).pop(_ChatMessageAction.block),
            ),
            if (canModerate) ...[
              const Divider(color: Canopy.hairline, height: 1),
              ListTile(
                leading:
                    const Icon(Icons.mic_off_rounded, color: AppTheme.warning),
                title: Text(
                  'live.mute_user'.tr(),
                  style: const TextStyle(color: Canopy.ink),
                ),
                onTap: () => Navigator.of(context).pop(_ChatMessageAction.mute),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Canopy.liveCrimson),
                title: Text(
                  'live.delete_message'.tr(),
                  style: const TextStyle(color: Canopy.ink),
                ),
                onTap: () =>
                    Navigator.of(context).pop(_ChatMessageAction.delete),
              ),
              if (message.isStreamModerator)
                ListTile(
                  leading: const Icon(Icons.remove_moderator_outlined,
                      color: Canopy.liveCrimson),
                  title: Text(
                    'live.revoke_moderator'.tr(),
                    style: const TextStyle(color: Canopy.ink),
                  ),
                  onTap: () => Navigator.of(context)
                      .pop(_ChatMessageAction.revokeModerator),
                )
              else
                ListTile(
                  leading: const Icon(Icons.add_moderator_outlined,
                      color: Canopy.leaf),
                  title: Text(
                    'live.appoint_moderator'.tr(),
                    style: const TextStyle(color: Canopy.ink),
                  ),
                  onTap: () => Navigator.of(context)
                      .pop(_ChatMessageAction.appointModerator),
                ),
            ],
          ],
          const SizedBox(height: AppTheme.spaceSm),
        ]));
  }
}

class _ReportReasonMenu extends StatelessWidget {
  const _ReportReasonMenu();

  // (stable reason code stored in chat_reports.reason, localization key) --
  // the code is what's persisted, so admin review isn't a mix of whatever
  // language each reporter's device happened to be in.
  static const _reasons = [
    (ChatReportReason.spam, 'report_reason_spam'),
    (ChatReportReason.harassment, 'report_reason_harassment'),
    (ChatReportReason.hateSpeech, 'report_reason_hate'),
    (ChatReportReason.other, 'report_reason_other'),
  ];

  @override
  Widget build(BuildContext context) {
    return CaSheet(
        title: 'live.report_reason_prompt'.tr(),
        onClose: () => Navigator.of(context).pop(),
        body: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (code, key) in _reasons)
            ListTile(
              title: Text(
                'live.$key'.tr(),
                style: const TextStyle(color: Canopy.ink),
              ),
              onTap: () => Navigator.of(context).pop(code),
            ),
          const SizedBox(height: AppTheme.spaceSm),
        ]));
  }
}
