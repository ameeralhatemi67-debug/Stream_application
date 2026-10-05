import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_icon.dart';

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
    final result = await showCaDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PermissionRationaleDialog(kind: kind),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isCamera = kind == BroadcastPermissionKind.camera;
    return CaDialog(
      title: (isCamera
              ? 'live.permission_camera_title'
              : 'live.permission_microphone_title')
          .tr(),
      body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CaIcon(isCamera ? CaGlyph.video : CaGlyph.mic,
                color: Canopy.brandGreen, size: 32),
            const SizedBox(height: AppTheme.spaceMd),
            Text(
                (isCamera
                        ? 'live.permission_camera_body'
                        : 'live.permission_microphone_body')
                    .tr(),
                style: Theme.of(context).textTheme.bodyMedium),
          ]),
      actions: [
        CaButton(
            label: 'design_ui.not_now'.tr(),
            variant: CaButtonVariant.text,
            onPressed: () => Navigator.of(context).pop(false)),
        CaButton(
            label: 'design_ui.continue'.tr(),
            onPressed: () => Navigator.of(context).pop(true)),
      ],
    );
  }
}
