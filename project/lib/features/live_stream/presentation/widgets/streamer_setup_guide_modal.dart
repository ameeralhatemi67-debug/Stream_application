import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import 'rtmp_ip_dialog.dart' show StudioMode;

/// "More info" for the Broadcaster Studio: short, mode-specific help that
/// explains the decision at hand and one useful action (P6S research 06).
///
/// It replaces a quest-style "Streamer Academy" carousel that promised
/// outcomes the app could not confirm and offered a clipboard shortcut for
/// the secret stream key. Each mode says only what this build can do:
/// OBS on a computer and another phone app are external senders the app
/// cannot see; the phone path keeps the screen open and ends on leave;
/// Local is not available.
class StreamerSetupGuideModal extends StatelessWidget {
  final StudioMode mode;

  /// For [StudioMode.obs]: `obs_laptop` or `external_phone`.
  final String externalSender;

  const StreamerSetupGuideModal({
    super.key,
    required this.mode,
    this.externalSender = 'obs_laptop',
  });

  static Future<void> show(
    BuildContext context, {
    required StudioMode mode,
    String externalSender = 'obs_laptop',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppTheme.media.withValues(alpha: 0.6),
      builder: (_) =>
          StreamerSetupGuideModal(mode: mode, externalSender: externalSender),
    );
  }

  String get _section => switch (mode) {
        StudioMode.obs =>
          externalSender == 'external_phone' ? 'phone_app' : 'obs',
        StudioMode.phone => 'phone',
        StudioMode.local => 'local',
      };

  List<String> get _stepKeys {
    final count = mode == StudioMode.local ? 3 : 4;
    return [for (var i = 1; i <= count; i++) 'live_guide.${_section}_$i'];
  }

  IconData get _icon => switch (_section) {
        'obs' => Icons.laptop_mac_rounded,
        'phone_app' => Icons.smartphone_rounded,
        'phone' => Icons.videocam_rounded,
        _ => Icons.wifi_off_rounded,
      };

  Future<void> _openStudio() async {
    final uri = Uri.parse('https://studio.youtube.com');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return Container(
      key: const Key('studio-guide'),
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
        border: Border(top: BorderSide(color: AppTheme.borderStrong)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon, color: AppTheme.primary, size: 22),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'live_guide.title_$_section'.tr(),
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary),
                    tooltip: 'live_guide.close'.tr(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMd),
              for (final (i, key) in _stepKeys.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: AppTheme.surfaceAlt,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      Expanded(
                        child: Text(
                          key.tr(),
                          style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              if (mode != StudioMode.local) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Container(
                  key: const Key('studio-guide-link-vs-key'),
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'live_guide.link_vs_key_title'.tr(),
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppTheme.spaceXs),
                      Text(
                        'live_guide.link_vs_key_body'.tr(),
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12.5,
                            height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('studio-guide-open-studio'),
                    onPressed: _openStudio,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text('live_guide.open_studio'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                      side: const BorderSide(color: AppTheme.primary),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
