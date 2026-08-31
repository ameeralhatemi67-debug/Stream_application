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
      backgroundColor: AppTheme.darkSurface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.darkBorderSubtle, width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentAmber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(Icons.devices_other_rounded,
                color: AppTheme.accentAmber, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          const Expanded(
            child: Text(
              'Multiple Device Login Detected',
              style: TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This account is currently active as a broadcaster on another device. How would you like to continue on this device?',
              style: TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),

            // Existing Active Device Card
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.darkBorderSubtle),
              ),
              child: Row(
                children: [
                  Icon(_platformIcon(existingDevice.platform),
                      color: AppTheme.textMutedDark, size: 20),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existingDevice.deviceName,
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Active Broadcaster Session',
                          style: TextStyle(
                            color: AppTheme.accentAmber,
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
                color: AppTheme.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(_platformIcon(currentDevice.platform),
                      color: AppTheme.accentBlue, size: 20),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${currentDevice.deviceName} (This Device)',
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Current Local Session',
                          style: TextStyle(
                            color: AppTheme.accentBlue,
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
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textSecondaryDark,
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          onPressed: () =>
              Navigator.of(context).pop(DeviceSessionChoice.continueAsViewer),
          child: const Text('Continue as Viewer', style: TextStyle(fontSize: 12.5)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context)
              .pop(DeviceSessionChoice.transferBroadcaster),
          child: const Text('Transfer Broadcaster to This Device',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
