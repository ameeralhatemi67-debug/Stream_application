import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/ios_support_contact.dart';
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
  Widget build(BuildContext context) {
    context.select<AppProvider, Object?>((p) => p.termsAndConditions);
    return _buildGovernanceCard(context, context.read<AppProvider>());
  }

  Widget _buildGovernanceCard(BuildContext context, AppProvider provider) {
    final terms = provider.termsAndConditions;

    return CaCard(
      child: Column(
        children: [
          _buildGovernanceRow(context,
            icon: Icons.description_rounded,
            title: 'settings.view_terms'.tr(),
            subtitle:
                '${'settings.terms_version_label'.tr()}: ${terms.version}',
            onTap: () => _openLegalReader(context, terms, 0),
          ),
          Divider(height: 16, color: paletteColor(context, Canopy.hairline)),
          _buildGovernanceRow(context,
            icon: Icons.verified_user_rounded,
            title: 'settings.view_guidelines'.tr(),
            subtitle: 'settings.view_guidelines_subtitle'.tr(),
            onTap: () => _openLegalReader(context, terms, 1),
          ),
          Divider(height: 16, color: paletteColor(context, Canopy.hairline)),
          _buildGovernanceRow(context,
            icon: Icons.privacy_tip_rounded,
            title: 'settings.view_privacy'.tr(),
            subtitle: 'settings.view_privacy_subtitle'.tr(),
            onTap: () => _openLegalReader(context, terms, 2),
          ),
          const IosSupportContact(),
        ],
      ),
    );
  }

  Widget _buildGovernanceRow(BuildContext context, {
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
            Icon(icon, size: 20, color: paletteColor(context, AppTheme.primary)),
            const SizedBox(width: AppTheme.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: paletteColor(context, Canopy.ink),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: paletteColor(context, Canopy.haze),
                      fontSize: AppTheme.captionFont,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: paletteColor(context, Canopy.slate)),
          ],
        ),
      ),
    );
  }

  void _openLegalReader(
      BuildContext context, TermsAndConditionsModel terms, int index) {
    showCaSheet<void>(context,
        title: 'settings.governance_legal'.tr(),
        body: LegalDocumentReaderScreen(
            terms: terms, initialDocumentIndex: index),
        framed: false);
  }
}
