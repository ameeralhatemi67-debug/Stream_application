import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/profile/models/streamer_models.dart';
import '../theme/app_theme.dart';
import 'streamer_avatar.dart';

/// Modal dialog presented when a user account is associated with multiple
/// personal broadcaster channels, allowing the streamer to pick which channel
/// to keep while permanently deleting the unselected duplicate.
class DuplicateChannelResolutionDialog extends StatefulWidget {
  final List<StreamerModel> duplicateChannels;

  const DuplicateChannelResolutionDialog({
    super.key,
    required this.duplicateChannels,
  });

  static Future<StreamerModel?> show({
    required BuildContext context,
    required List<StreamerModel> duplicateChannels,
  }) {
    return showDialog<StreamerModel>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DuplicateChannelResolutionDialog(
        duplicateChannels: duplicateChannels,
      ),
    );
  }

  @override
  State<DuplicateChannelResolutionDialog> createState() =>
      _DuplicateChannelResolutionDialogState();
}

class _DuplicateChannelResolutionDialogState
    extends State<DuplicateChannelResolutionDialog> {
  String? _selectedStreamerId;

  @override
  void initState() {
    super.initState();
    if (widget.duplicateChannels.isNotEmpty) {
      _selectedStreamerId = widget.duplicateChannels.first.streamerId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;

    return AlertDialog(
      backgroundColor: paletteColor(context, AppTheme.surface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: BorderSide(color: paletteColor(context, AppTheme.border), width: 1.2),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: paletteColor(context, AppTheme.warning).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(Icons.warning_amber_rounded,
                color: paletteColor(context, AppTheme.warning), size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(
              'design_copy.multiple_channels_detected'.tr(),
              style: TextStyle(
                color: paletteColor(context, AppTheme.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'design_copy.you_can_only_own_one_personal_broadcaster_channel_please_select_w'.tr(),
              style: TextStyle(
                color: paletteColor(context, AppTheme.textSecondary),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ...widget.duplicateChannels.map((channel) {
              final isSelected = channel.streamerId == _selectedStreamerId;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedStreamerId = channel.streamerId;
                    });
                  },
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? paletteColor(context, AppTheme.primary).withValues(alpha: 0.12)
                          : paletteColor(context, AppTheme.surfaceAlt),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? paletteColor(context, AppTheme.primary)
                            : paletteColor(context, AppTheme.border),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        StreamerAvatar(
                          radius: 20,
                          avatarUrl: channel.avatarUrl,
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel.getLocalizedName(lang),
                                style: TextStyle(
                                  color: paletteColor(context, AppTheme.textPrimary),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                channel.getLocalizedTitle(lang),
                                style: TextStyle(
                                  color: paletteColor(context, AppTheme.textSecondary),
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                channel.organizationEn,
                                style: TextStyle(
                                  color: paletteColor(context, AppTheme.primary),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? paletteColor(context, AppTheme.primary)
                                  : paletteColor(context, AppTheme.textMuted),
                              width: 2,
                            ),
                            color: isSelected
                                ? paletteColor(context, AppTheme.primary)
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? Icon(Icons.check_rounded,
                                  color: paletteColor(context, AppTheme.onMedia), size: 16)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: paletteColor(context, AppTheme.primary),
            foregroundColor: paletteColor(context, AppTheme.onMedia),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          ),
          onPressed: _selectedStreamerId == null
              ? null
              : () {
                  final selectedChannel = widget.duplicateChannels.firstWhere(
                    (c) => c.streamerId == _selectedStreamerId,
                  );
                  Navigator.of(context).pop(selectedChannel);
                },
          child: Text(
            'design_copy.keep_selected_delete_other'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
