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
      backgroundColor: AppTheme.darkSurface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.accentRed, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isCamera ? Icons.videocam_rounded : Icons.mic_rounded,
              color: AppTheme.accentRed,
              size: 32,
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
              isCamera ? 'Camera access needed' : 'Microphone access needed',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              isCamera
                  ? "This app uses your phone's camera to capture video for "
                      'your broadcast. Nothing is recorded until you start '
                      'going live.'
                  : "This app uses your phone's microphone to capture audio "
                      'for your broadcast. Nothing is recorded until you '
                      'start going live.',
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    'Not now',
                    style: TextStyle(color: AppTheme.textSecondaryDark),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentRed,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
