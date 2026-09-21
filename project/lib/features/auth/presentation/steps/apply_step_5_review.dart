import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import 'apply_step_3_5_org_speakers.dart';
import 'apply_step_4_location.dart';

/// Step 5: Live Preview & Broadcasting Charter Terms Agreement
class ApplyStep5Review extends StatelessWidget {
  final String name;
  final String handle;
  final String bio;
  final String? avatarPath;
  final String? bannerPath;
  final Uint8List? avatarBytes;
  final Uint8List? bannerBytes;
  final String institution;
  final String orgName;
  final List<String> categories;
  final String youtube;
  final String city;
  final String venue;
  final String phone;
  final String contactPref;
  final bool isOrganization;
  final List<String> tags;
  final List<OrgApplicationSpeaker> speakers;
  final List<OrgBranchVenue> branches;
  final bool agreedToTerms;
  final Function(bool agreed) onTermsToggled;

  const ApplyStep5Review({
    super.key,
    required this.name,
    required this.handle,
    required this.bio,
    required this.avatarPath,
    required this.bannerPath,
    this.avatarBytes,
    this.bannerBytes,
    required this.institution,
    required this.orgName,
    required this.categories,
    required this.youtube,
    required this.city,
    required this.venue,
    required this.phone,
    required this.contactPref,
    required this.isOrganization,
    required this.tags,
    this.speakers = const [],
    this.branches = const [],
    required this.agreedToTerms,
    required this.onTermsToggled,
  });

  void _showTermsModalSheet(BuildContext context) {
    final provider = context.read<AppProvider>();
    final terms = provider.termsAndConditions;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: AppTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Row(
                children: [
                  const Icon(Icons.gavel_rounded, color: AppTheme.danger, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isOrganization
                          ? 'wizard_steps.step5_terms_modal_org'.tr()
                          : 'wizard_steps.step5_terms_modal_ind'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'wizard_steps.step5_charter_title'.tr(args: [terms.version]),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      terms.getLocalizedTerms(ctx.locale.languageCode),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    Text('design_ui.broadcasting_audio_visual_standards'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      terms.getLocalizedGuidelines(ctx.locale.languageCode),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceLg),
                    Text('design_ui.privacy_regional_telemetry_guidelines'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      terms.getLocalizedPrivacy(ctx.locale.languageCode),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: AppTheme.onMedia,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    onTermsToggled(true);
                    Navigator.of(ctx).pop();
                  },
                  child: Text('wizard_steps.step5_agree_btn'.tr()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cityName = ApplyStep4Location.cityOptions[city] ?? city;
    final displayName = isOrganization && orgName.isNotEmpty ? orgName : name;

    final bannerProvider = buildSafeImageProvider(
      path: bannerPath,
      bytes: bannerBytes,
      defaultAsset: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
    );

    final avatarProvider = buildSafeImageProvider(
      path: avatarPath,
      bytes: avatarBytes,
      defaultAsset: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'wizard_steps.step5_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step5_desc'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          //  Live Broadcaster Preview Card
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              border: Border.all(color: AppTheme.border, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.media.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Banner Container with SafeImageProvider
                Container(
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    image: DecorationImage(
                      image: bannerProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Avatar + Name Header Row
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppTheme.surfaceAlt,
                            backgroundImage: avatarProvider,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  handle.startsWith('@') ? handle : '@$handle',
                                  style: const TextStyle(
                                    color: AppTheme.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (institution.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    institution,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceMd),
                        Text(
                          bio,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppTheme.spaceMd),
                      const Divider(height: 1, color: AppTheme.border),
                      const SizedBox(height: AppTheme.spaceSm),

                      // Structured Metadata Breakdown
                      _buildSummaryRow(
                        icon: Icons.category_outlined,
                        label: 'Categories',
                        value: categories.join(', '),
                      ),
                      _buildSummaryRow(
                        icon: Icons.video_library_outlined,
                        label: 'YouTube',
                        value: youtube,
                      ),
                      _buildSummaryRow(
                        icon: Icons.location_on_outlined,
                        label: 'HQ Location',
                        value: '$cityName${venue.isNotEmpty ? " • $venue" : ""}',
                      ),
                      if (branches.isNotEmpty)
                        _buildSummaryRow(
                          icon: Icons.apartment_rounded,
                          label: 'Campus Branches',
                          value: branches.map((b) => b.branchName).join(', '),
                        ),
                      if (speakers.isNotEmpty)
                        _buildSummaryRow(
                          icon: Icons.groups_outlined,
                          label: 'Roster Speakers',
                          value: speakers.map((s) => s.name).join(', '),
                        ),
                      if (phone.isNotEmpty)
                        _buildSummaryRow(
                          icon: Icons.phone_outlined,
                          label: 'Contact ($contactPref)',
                          value: phone,
                        ),

                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tags.map((t) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceAlt,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          //  Agreement Checkbox with Clickable Sheet Link
          GestureDetector(
            onTap: () => onTermsToggled(!agreedToTerms),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: agreedToTerms ? AppTheme.danger.withValues(alpha: 0.5) : AppTheme.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: agreedToTerms,
                    onChanged: (val) => onTermsToggled(val ?? false),
                    activeColor: AppTheme.danger,
                    checkColor: AppTheme.onMedia,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'wizard_steps.step5_agree_checkbox'.tr(),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () => _showTermsModalSheet(context),
                            child: Text(
                              isOrganization
                                  ? 'wizard_steps.step5_terms_modal_org'.tr()
                                  : 'wizard_steps.step5_agree_terms_link'.tr(),
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          Text(
                            'wizard_steps.step5_agree_standards'.tr(),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: AppTheme.danger),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
