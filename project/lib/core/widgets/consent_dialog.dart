import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';

/// PDPL onboarding consent gate (v0.9 Checkpoint 3 Phase 1) -- shown once,
/// before any personal data is gathered, for both the Google sign-in and
/// guest viewer flows (see WelcomeScreen._ensureConsent). Acceptance is
/// recorded via AppProvider.recordConsent(); the actual policy text is
/// pulled live from AppProvider.termsAndConditions rather than duplicated
/// here, so this dialog never drifts out of sync with the Governance &
/// Legal section in Settings.
class ConsentDialog extends StatefulWidget {
  const ConsentDialog({super.key});

  /// Shows the dialog and returns true only if the user explicitly agreed.
  /// Not dismissible by tapping outside or the back button -- consent has
  /// to be an affirmative choice, not an accidental miss-tap.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ConsentDialog(),
    );
    return result ?? false;
  }

  @override
  State<ConsentDialog> createState() => _ConsentDialogState();
}

class _ConsentDialogState extends State<ConsentDialog> {
  bool _agreed = false;

  void _showFullPolicy(BuildContext context) {
    final provider = context.read<AppProvider>();
    final terms = provider.termsAndConditions;
    final isAr = context.locale.languageCode == 'ar';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
        title: Text(
          'settings.view_privacy'.tr(),
          style: const TextStyle(
            color: AppTheme.textPrimaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: SelectableText(
              terms.getLocalizedPrivacy(isAr ? 'ar' : 'en'),
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text('common.close'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          side: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
        title: Row(
          children: [
            const Icon(Icons.privacy_tip_rounded,
                color: AppTheme.accentBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'consent.title'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'consent.body_intro'.tr(),
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _buildDataPoint(
                  Icons.badge_outlined, 'consent.data_point_profile'.tr()),
              _buildDataPoint(Icons.location_on_outlined,
                  'consent.data_point_location'.tr()),
              _buildDataPoint(Icons.chat_bubble_outline_rounded,
                  'consent.data_point_chat'.tr()),
              const SizedBox(height: AppTheme.spaceSm),
              InkWell(
                onTap: () => _showFullPolicy(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'consent.view_full_policy'.tr(),
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              InkWell(
                onTap: () => setState(() => _agreed = !_agreed),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      activeColor: AppTheme.accentBlue,
                      onChanged: (val) =>
                          setState(() => _agreed = val ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          'consent.checkbox_label'.tr(),
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'common.decline'.tr(),
              style: const TextStyle(color: AppTheme.textMutedDark),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentBlue,
              foregroundColor: Colors.white,
            ),
            onPressed: _agreed ? () => Navigator.pop(context, true) : null,
            child: Text('consent.accept_btn'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPoint(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.textMutedDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondaryDark,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
