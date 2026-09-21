import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../admin/models/broadcaster_application_model.dart';

/// The broadcaster and organization verification application: the promo card
/// for a viewer who has not applied, and the live status card once they have.
///
/// Extracted from `settings_screen.dart` with the rest of the Settings split.
class ApplicationSettingsSection extends StatelessWidget {
  const ApplicationSettingsSection({super.key});

  @override
  Widget build(BuildContext context) =>
      _buildApplicationSection(context, context.watch<AppProvider>());

  Widget _buildApplicationSection(BuildContext context, AppProvider provider) {
    final isAr = context.locale.languageCode == 'ar';
    final userApp = provider.myApplication;

    if (userApp == null) {
      return _buildBecomeBroadcasterPromoCard(context);
    }

    return _buildApplicationStatusCard(context, provider, userApp, isAr);
  }

  Widget _buildBecomeBroadcasterPromoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(Icons.school_rounded,
                    color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'application.apply_card_title'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'application.apply_card_desc'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              icon: const Icon(Icons.assignment_turned_in_rounded, size: 16),
              label: Text(
                'application.apply_btn'.tr(),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              onPressed: () => context.push('/streamer-apply'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationStatusCard(
    BuildContext context,
    AppProvider provider,
    BroadcasterApplicationModel app,
    bool isAr,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    switch (app.status) {
      case ApplicationStatus.approved:
        statusColor = AppTheme.success;
        statusIcon = Icons.verified_rounded;
        statusTitle = 'application.status_approved'.tr();
        statusSubtitle = 'application.status_approved_desc'.tr();
        break;
      case ApplicationStatus.rejected:
        statusColor = AppTheme.danger;
        statusIcon = Icons.error_outline_rounded;
        statusTitle = 'application.status_rejected'.tr();
        statusSubtitle =
            app.reviewNotes ?? 'Changes requested before verification.';
        break;
      case ApplicationStatus.pending:
      default:
        statusColor = AppTheme.warning;
        statusIcon = Icons.hourglass_top_rounded;
        statusTitle = 'application.status_pending'.tr();
        statusSubtitle = 'application.status_pending_desc'.tr();
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            statusTitle,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: AppTheme.border, width: 0.6),
                          ),
                          child: Text(
                            app.isOrganization ? 'ORGANIZATION' : 'SCHOLAR',
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 8.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${isAr ? app.applicantNameAr : app.applicantNameEn} • ${app.email}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spaceSm),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (app.status == ApplicationStatus.rejected &&
                    app.reviewNotes != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 13, color: AppTheme.danger),
                      const SizedBox(width: 4),
                      Text(
                        'application.admin_feedback'.tr(),
                        style: const TextStyle(
                          color: AppTheme.danger,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.reviewNotes!,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ] else ...[
                  Text(
                    statusSubtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          // A single "Edit"/"Reapply"action only -- no parallel "New
          // Application"button. An account is strictly limited to one
          // personal broadcaster channel (issue_log.md: "I should not have
          // the ability to own two channels"); an existing application
          // (pending, approved, or rejected) is always edited in place.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 9),
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: Text(
                app.status == ApplicationStatus.rejected
                    ? 'application.reapply_btn'.tr()
                    : 'application.edit_btn'.tr(),
                style: const TextStyle(fontSize: 11.5),
              ),
              onPressed: () => context.push('/streamer-apply'),
            ),
          ),
        ],
      ),
    );
  }

}
