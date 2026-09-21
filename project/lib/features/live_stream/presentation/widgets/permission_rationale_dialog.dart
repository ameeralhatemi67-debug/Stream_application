import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

enum BroadcastPermissionKind { camera, microphone }

/// Contextual rationale shown right before the OS permission prompt, per
/// v0.7 Checkpoint 2 Phase 1 (doc/Roadmap/v0.7_Mobile_Streaming_Android.md).
/// Returns true if the user chose to continue (system dialog should follow),
/// false if they declined.
class PermissionRationaleDialog extends StatelessWidget {
  final BroadcastPermissionKind kind;

  const PermissionRationaleDialog({super.key, required this.kind});

  static Future<bool> show(
    BuildContext context,
    BroadcastPermissionKind kind,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PermissionRationaleDialog(kind: kind),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isCamera = kind == BroadcastPermissionKind.camera;
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.danger, width: 1.5),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isCamera ? Icons.videocam_rounded : Icons.mic_rounded,
              color: AppTheme.danger,
              size: 32,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              (isCamera
                      ? 'live.permission_camera_title'
                      : 'live.permission_microphone_title')
                  .tr(),
              // The dialog surface is white, so the title takes textPrimary.
              // It was `onMedia` white on white, and simply did not show.
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              (isCamera
                      ? 'live.permission_camera_body'
                      : 'live.permission_microphone_body')
                  .tr(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            // Wrap, not Row: the two labels side by side overran a 320 px
            // dialog from text scale 1.3 upwards, in both languages. They
            // stack instead of being clipped.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppTheme.spaceSm,
              runSpacing: AppTheme.spaceSm,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('design_ui.not_now'.tr(),
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: AppTheme.onMedia,
                  ),
                  child: Text('design_ui.continue'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
