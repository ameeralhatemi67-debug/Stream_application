import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../models/device_session_model.dart';
import '../theme/app_theme.dart';

enum DeviceSessionChoice {
  transferBroadcaster,
  continueAsViewer,
}

/// Glassmorphic dialog prompted when an account is opened on a second device
/// while another device holds active broadcaster permissions.
class DeviceSessionConflictDialog extends StatelessWidget {
  final DeviceSessionModel currentDevice;
  final DeviceSessionModel existingDevice;

  const DeviceSessionConflictDialog({
    super.key,
    required this.currentDevice,
    required this.existingDevice,
  });

  static Future<DeviceSessionChoice?> show({
    required BuildContext context,
    required DeviceSessionModel currentDevice,
    required DeviceSessionModel existingDevice,
  }) {
    return showDialog<DeviceSessionChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeviceSessionConflictDialog(
        currentDevice: currentDevice,
        existingDevice: existingDevice,
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      case 'windows':
      case 'macos':
      case 'linux':
        return Icons.desktop_windows_rounded;
      case 'web':
      default:
        return Icons.language_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.border, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.devices_other_rounded,
                color: AppTheme.warning, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text('design_ui.multiple_device_login_detected'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('design_ui.this_account_is_currently_active_as_a_broadcaster_on_another_devi'.tr(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),

            // Existing Active Device Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  Icon(_platformIcon(existingDevice.platform),
                      color: AppTheme.textMuted, size: 20),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existingDevice.deviceName,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('design_ui.active_broadcaster_session'.tr(),
                          style: const TextStyle(
                            color: AppTheme.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),

            // Current Device Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(_platformIcon(currentDevice.platform),
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentDevice.deviceName} (This Device)',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('design_ui.current_local_session'.tr(),
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondary,
            side: const BorderSide(color: AppTheme.border),
          ),
          onPressed: () =>
              Navigator.of(context).pop(DeviceSessionChoice.continueAsViewer),
          child: Text('design_ui.continue_as_viewer'.tr(), style: const TextStyle(fontSize: 12.5)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppTheme.onMedia,
          ),
          onPressed: () => Navigator.of(context)
              .pop(DeviceSessionChoice.transferBroadcaster),
          child: Text('design_ui.transfer_broadcaster_to_this_device'.tr(),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
