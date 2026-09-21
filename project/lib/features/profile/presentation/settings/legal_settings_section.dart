import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/models/terms_and_conditions_model.dart';
import '../widgets/legal_document_reader_screen.dart';

/// Platform governance: terms, broadcaster guidelines and the privacy policy,
/// each opening the legal reader.
///
/// Extracted from `settings_screen.dart` with the rest of the Settings split.
class LegalSettingsSection extends StatelessWidget {
  const LegalSettingsSection({super.key});

  @override
  Widget build(BuildContext context) =>
      _buildGovernanceCard(context, context.watch<AppProvider>());

  Widget _buildGovernanceCard(BuildContext context, AppProvider provider) {
    final terms = provider.termsAndConditions;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _buildGovernanceRow(
            icon: Icons.description_rounded,
            title: 'settings.view_terms'.tr(),
            subtitle:
                '${'settings.terms_version_label'.tr()}: ${terms.version}',
            onTap: () => _openLegalReader(context, terms, 0),
          ),
          const Divider(height: 16, color: AppTheme.border),
          _buildGovernanceRow(
            icon: Icons.verified_user_rounded,
            title: 'settings.view_guidelines'.tr(),
            subtitle: 'settings.view_guidelines_subtitle'.tr(),
            onTap: () => _openLegalReader(context, terms, 1),
          ),
          const Divider(height: 16, color: AppTheme.border),
          _buildGovernanceRow(
            icon: Icons.privacy_tip_rounded,
            title: 'settings.view_privacy'.tr(),
            subtitle: 'settings.view_privacy_subtitle'.tr(),
            onTap: () => _openLegalReader(context, terms, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildGovernanceRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primary),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _openLegalReader(
      BuildContext context, TermsAndConditionsModel terms, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentReaderScreen(
          terms: terms,
          initialDocumentIndex: index,
        ),
      ),
    );
  }
}
