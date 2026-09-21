import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Step 1: Broadcaster Identity & Bio
class ApplyStep1Identity extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController handleController;
  final TextEditingController bioController;

  const ApplyStep1Identity({
    super.key,
    required this.nameController,
    required this.handleController,
    required this.bioController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'wizard_steps.step1_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step1_desc'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // Full Name
          TextField(
            controller: nameController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'wizard_steps.step1_name_label'.tr(),
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: 'wizard_steps.step1_name_hint'.tr(),
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.danger),
              filled: true,
              fillColor: AppTheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Public Handle
          TextField(
            controller: handleController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'wizard_steps.step1_handle_label'.tr(),
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: 'wizard_steps.step1_handle_hint'.tr(),
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.alternate_email_rounded,
                  color: AppTheme.danger),
              filled: true,
              fillColor: AppTheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Bio
          TextField(
            controller: bioController,
            maxLines: 4,
            maxLength: 350,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: 'wizard_steps.step1_bio_label'.tr(),
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: 'wizard_steps.step1_bio_hint'.tr(),
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              alignLabelWithHint: true,
              filled: true,
              fillColor: AppTheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
