import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/config/app_identity.dart';

class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppTheme.spaceLg),
    decoration: BoxDecoration(color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: AppTheme.border)),
    child: Column(children: [
      const AppLogo(size: 64), const SizedBox(height: AppTheme.spaceMd),
      Text(AppIdentity.name(context.locale.languageCode), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: AppTheme.spaceSm),
      Text('settings.build_version'.tr(), textAlign: TextAlign.center),
      Text('settings.release_pending'.tr(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ]),
  );

}
