import '../../../../core/widgets/ds/ca_fields.dart';
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
            'wizard_steps.step1_title'.tr().split(':').last.trim(),
            style: const TextStyle(
              color: Canopy.ink,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step1_desc'.tr(),
            style: const TextStyle(
              color: Canopy.slate,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // Full Name
          CaInput(
            controller: nameController,
            label: 'wizard_steps.step1_name_label'.tr(),
            hint: 'wizard_steps.step1_name_hint'.tr(),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Public Handle
          CaInput(
            controller: handleController,
            label: 'wizard_steps.step1_handle_label'.tr(),
            hint: 'wizard_steps.step1_handle_hint'.tr(),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Bio
          CaInput(
            controller: bioController,
            maxLines: 4,
            maxLength: 350,
            label: 'wizard_steps.step1_bio_label'.tr(),
            hint: 'wizard_steps.step1_bio_hint'.tr(),
          ),
        ],
      ),
    );
  }
}
