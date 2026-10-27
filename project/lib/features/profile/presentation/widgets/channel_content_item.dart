import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/hidden_content_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_rows.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../admin/presentation/widgets/admin_safety_view.dart'
    show askSafetyReason;

enum _ContentAction { share, hide, show, delete, takeDown, restore }

/// Wraps a video or playlist on a channel page. A long press (or a right click)
/// opens a menu to share it and, for the channel owner, to hide it from or show
/// it to viewers. For a recording of a live made in the app, hiding also makes
/// it private on YouTube, the owner can delete it from YouTube, and an admin
/// can take it down. The owner (and an admin) sees a hidden item blurred with
/// a "hidden" icon; viewers never get the item at all (the provider leaves it
/// out), so this widget draws nothing for a viewer if one slips through.
class ChannelContentItem extends StatelessWidget {
  const ChannelContentItem({
    super.key,
    required this.streamerId,
    required this.kind,
    required this.itemId,
    required this.title,
    required this.shareText,
    required this.child,
  });

  final String streamerId;
  final HiddenContentKind kind;
  final String itemId;
  final String title;

  /// What the share sheet sends: the item's title and its YouTube link.
  final String shareText;
  final Widget child;

  Future<void> _openMenu(BuildContext context,
      {required bool canManage,
      required bool isAdmin,
      required bool hidden,
      required RecordingControl? recording}) async {
    HapticFeedback.mediumImpact();
    // A taken-down recording stays hidden until an admin restores it.
    final locked = recording != null && recording.takenDown && hidden;
    final action = await showCaSheet<_ContentAction>(context,
        title: title,
        body: Builder(
            builder: (sheetContext) => Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceLg),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CaSettingsRow(
                      icon: CaGlyph.share,
                      title: (kind == HiddenContentKind.video
                              ? 'content_actions.share_video'
                              : 'content_actions.share_playlist')
                          .tr(),
                      onTap: () =>
                          Navigator.pop(sheetContext, _ContentAction.share)),
                  if (canManage && !(recording?.deleted ?? false))
                    CaSettingsRow(
                        key: const Key('content-action-hide-show'),
                        divider: true,
                        icon: hidden ? CaGlyph.eye : CaGlyph.eyeoff,
                        title: (hidden
                                ? 'content_actions.show'
                                : 'content_actions.hide')
                            .tr(),
                        subtitle: (locked
                                ? 'content_actions.taken_down_hint'
                                : recording != null
                                    ? (hidden
                                        ? 'content_actions.show_recording_hint'
                                        : 'content_actions.hide_recording_hint')
                                    : (hidden
                                        ? 'content_actions.show_hint'
                                        : 'content_actions.hide_hint'))
                            .tr(),
                        onTap: locked
                            ? null
                            : () => Navigator.pop(
                                sheetContext,
                                hidden
                                    ? _ContentAction.show
                                    : _ContentAction.hide)),
                  if (recording != null && (canManage || isAdmin))
                    _RecordingStatusRow(recording: recording),
                  if (canManage &&
                      recording != null &&
                      recording.canDelete &&
                      !recording.deleted &&
                      !recording.deletePending)
                    CaSettingsRow(
                        key: const Key('content-action-delete'),
                        divider: true,
                        icon: CaGlyph.trash,
                        title: 'content_actions.delete_recording'.tr(),
                        subtitle: 'content_actions.delete_recording_hint'.tr(),
                        onTap: () =>
                            Navigator.pop(sheetContext, _ContentAction.delete)),
                  if (isAdmin && recording != null && !recording.deleted)
                    CaSettingsRow(
                        key: const Key('content-action-take-down'),
                        divider: true,
                        icon: CaGlyph.shield,
                        title: (recording.takenDown
                                ? 'content_actions.restore_recording'
                                : 'content_actions.take_down_recording')
                            .tr(),
                        subtitle: (recording.takenDown
                                ? 'content_actions.restore_recording_hint'
                                : 'content_actions.take_down_recording_hint')
                            .tr(),
                        onTap: () => Navigator.pop(
                            sheetContext,
                            recording.takenDown
                                ? _ContentAction.restore
                                : _ContentAction.takeDown)),
                ]))));
    if (action == null || !context.mounted) return;
    switch (action) {
      case _ContentAction.share:
        await _share(context);
      case _ContentAction.hide:
      case _ContentAction.show:
        await _setHidden(context, action == _ContentAction.hide,
            recording: recording != null);
      case _ContentAction.delete:
        await _delete(context);
      case _ContentAction.takeDown:
      case _ContentAction.restore:
        await _takeDown(context, action == _ContentAction.takeDown);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showCaDialog<bool>(
      context: context,
      builder: (dialogContext) => CaAlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('content_actions.delete_confirm_title'.tr()),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(dialogContext).textTheme.labelLarge),
              const SizedBox(height: AppTheme.spaceSm),
              Text('content_actions.delete_confirm_body'.tr(),
                  style: Theme.of(dialogContext).textTheme.bodySmall),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('common.cancel'.tr())),
          ElevatedButton(
              key: const Key('recording-delete-confirm'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Canopy.liveCrimson,
                  foregroundColor: Canopy.paper),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('content_actions.delete_confirm_btn'.tr())),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await provider.deleteRecording(streamerId, itemId);
      messenger?.showSnackBar(
          SnackBar(content: Text('content_actions.delete_requested'.tr())));
    } catch (_) {
      messenger?.showSnackBar(
          SnackBar(content: Text('content_actions.save_failed'.tr())));
    }
  }

  Future<void> _takeDown(BuildContext context, bool down) async {
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final reason = await askSafetyReason(context,
        title: (down
                ? 'content_actions.take_down_title'
                : 'content_actions.restore_title')
            .tr(),
        body: (down
                ? 'content_actions.take_down_body'
                : 'content_actions.restore_body')
            .tr());
    if (reason == null || reason.trim().isEmpty || !context.mounted) return;
    try {
      await provider.takeDownRecording(streamerId, itemId, down, reason.trim());
      messenger?.showSnackBar(SnackBar(
          content: Text((down
                  ? 'content_actions.taken_down_done'
                  : 'content_actions.restored_done')
              .tr())));
    } catch (_) {
      messenger?.showSnackBar(
          SnackBar(content: Text('content_actions.save_failed'.tr())));
    }
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await Share.share(shareText, subject: title);
    } catch (_) {
      // Browsers without a share sheet: copy the link instead.
      await Clipboard.setData(ClipboardData(text: shareText));
      messenger?.showSnackBar(
          SnackBar(content: Text('content_actions.link_copied'.tr())));
    }
  }

  Future<void> _setHidden(BuildContext context, bool hide,
      {bool recording = false}) async {
    final provider = context.read<AppProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await provider.setContentHidden(streamerId, kind, itemId, hide);
      messenger?.showSnackBar(SnackBar(
          content: Text((recording
                  ? (hide
                      ? 'content_actions.hidden_recording_done'
                      : 'content_actions.shown_recording_done')
                  : (hide
                      ? 'content_actions.hidden_done'
                      : 'content_actions.shown_done'))
              .tr())));
    } catch (_) {
      messenger?.showSnackBar(
          SnackBar(content: Text('content_actions.save_failed'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (hidden, canManage, isAdmin, recording) =
        context.select<AppProvider, (bool, bool, bool, RecordingControl?)>((p) => (
              p.isContentHidden(streamerId, kind, itemId),
              p.canManageChannelContent(streamerId),
              p.isAdminUser,
              kind == HiddenContentKind.video
                  ? p.recordingControl(streamerId, itemId)
                  : null,
            ));
    if (hidden && !canManage && !isAdmin) return const SizedBox.shrink();
    void open() => _openMenu(context,
        canManage: canManage,
        isAdmin: isAdmin,
        hidden: hidden,
        recording: recording);
    return GestureDetector(
      onLongPress: open,
      onSecondaryTapUp: (TapUpDetails _) => open(),
      child: hidden ? _HiddenFrame(child: child) : child,
    );
  }
}

/// Where YouTube stands for an app-made recording: private or public, still
/// being updated, deleting or deleted, and whether an admin took it down.
class _RecordingStatusRow extends StatelessWidget {
  const _RecordingStatusRow({required this.recording});
  final RecordingControl recording;

  @override
  Widget build(BuildContext context) {
    final String key;
    final CaGlyph icon;
    if (recording.deleted) {
      (key, icon) = ('content_actions.yt_deleted', CaGlyph.trash);
    } else if (recording.deletePending) {
      (key, icon) = ('content_actions.yt_deleting', CaGlyph.refresh);
    } else if (recording.youtubeError && recording.youtubePending) {
      (key, icon) = ('content_actions.yt_error', CaGlyph.refresh);
    } else if (recording.youtubePending) {
      (key, icon) = ('content_actions.yt_updating', CaGlyph.refresh);
    } else if (recording.youtubePrivacy == 'private') {
      (key, icon) = ('content_actions.yt_private', CaGlyph.lock);
    } else {
      (key, icon) = ('content_actions.yt_public', CaGlyph.eye);
    }
    return CaSettingsRow(
        key: const Key('content-recording-status'),
        divider: true,
        icon: icon,
        title: key.tr(),
        subtitle: recording.takenDown
            ? 'content_actions.taken_down_badge'.tr()
            : null);
  }
}

/// The owner's view of a hidden item: blurred, with a "not visible" icon.
class _HiddenFrame extends StatelessWidget {
  const _HiddenFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(CanopyRadius.card);
    return Semantics(
      label: 'content_actions.hidden_badge'.tr(),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(children: [
          ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
              child: child),
          Positioned.fill(
              child: IgnorePointer(
                  child: LayoutBuilder(builder: (context, constraints) {
            final roomy = constraints.maxHeight >= 110;
            return ColoredBox(
                color: Canopy.forestDeep
                    .withValues(alpha: .5),
                child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CaIcon(CaGlyph.eyeoff,
                      size: 28, color: Canopy.paper),
                  if (roomy) ...[
                    const SizedBox(height: AppTheme.spaceXs),
                    Text('content_actions.hidden_badge'.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Canopy.paper)),
                  ],
                ])));
          }))),
        ]),
      ),
    );
  }
}
