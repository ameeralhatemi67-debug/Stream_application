import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_theme.dart';

class FeatureInProgressModal extends StatelessWidget {
  final String? featureName;

  const FeatureInProgressModal({super.key, this.featureName});

  static void show(BuildContext context, {String? featureName}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface3,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      builder: (context) => FeatureInProgressModal(featureName: featureName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleText = featureName != null && featureName!.isNotEmpty
        ? '${'safety.modal_title'.tr()}: $featureName'
        : 'safety.modal_title'.tr();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXl,
        vertical: AppTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.darkBorderHighlight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppTheme.spaceXl),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.construction_rounded,
              size: 40,
              color: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Text(
            titleText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'safety.modal_body'.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondaryDark,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.space2Xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.darkSurface2,
                foregroundColor: AppTheme.textPrimaryDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spaceMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  side: const BorderSide(color: AppTheme.darkBorderHighlight),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'safety.got_it'.tr(),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
        ],
      ),
    );
  }
}
