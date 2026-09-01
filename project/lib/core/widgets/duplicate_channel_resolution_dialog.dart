import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/profile/models/streamer_models.dart';
import '../theme/app_theme.dart';

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

  ImageProvider _getAvatarProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final isAr = lang == 'ar';

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
            child: const Icon(Icons.warning_amber_rounded,
                color: AppTheme.accentAmber, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(
              isAr ? 'تم رصد أكثر من قناة للبث' : 'Multiple Channels Detected',
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr
                  ? 'يمكن لكل ناشر امتلاك قناة واحدة فقط. يرجى اختيار القناة التي ترغب بالاحتفاظ بها كقناتك الأساسية، وسيتم حذف القناة الأخرى تلقائياً.'
                  : 'You can only own one personal broadcaster channel. Please select which channel you want to keep. The unselected channel will be deleted permanently.',
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
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
                          ? AppTheme.accentBlue.withValues(alpha: 0.12)
                          : AppTheme.darkSurface2,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentBlue
                            : AppTheme.darkBorderSubtle,
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.darkSurface3,
                          backgroundImage:
                              _getAvatarProvider(channel.avatarUrl),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                channel.getLocalizedName(lang),
                                style: const TextStyle(
                                  color: AppTheme.textPrimaryDark,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                channel.getLocalizedTitle(lang),
                                style: const TextStyle(
                                  color: AppTheme.textSecondaryDark,
                                  fontSize: 11.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                channel.organizationEn,
                                style: const TextStyle(
                                  color: AppTheme.accentBlue,
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
                                  ? AppTheme.accentBlue
                                  : AppTheme.textMutedDark,
                              width: 2,
                            ),
                            color: isSelected
                                ? AppTheme.accentBlue
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 16)
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
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
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
            isAr ? 'تأكيد وحذف القناة المكررة' : 'Keep Selected & Delete Other',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
