import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';

class LanguageSettingsSection extends StatelessWidget {
  const LanguageSettingsSection({super.key});
  @override
  Widget build(BuildContext context) {
    final currentLocale = context.locale.languageCode;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: Icon(
              currentLocale == 'en'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: currentLocale == 'en'
                  ? AppTheme.danger
                  : AppTheme.textMuted,
              size: 20,
            ),
            title: Text('design_ui.english_us'.tr(),
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            subtitle: Text('design_ui.ltr_interface'.tr(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            onTap: () => context.setLocale(const Locale('en')),
          ),
          const Divider(height: 1, color: AppTheme.border),
          ListTile(
            dense: true,
            leading: Icon(
              currentLocale == 'ar'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: currentLocale == 'ar'
                  ? AppTheme.danger
                  : AppTheme.textMuted,
              size: 20,
            ),
            title: Text('design_copy.arabic_language'.tr(),
                style:
                    const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
            subtitle: Text('design_copy.rtl_interface'.tr(),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            onTap: () => context.setLocale(const Locale('ar')),
          ),
        ],
      ),
    );
  }

}
