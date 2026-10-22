import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/config/app_identity.dart';

/// The app's logo beside the logo of the association behind it.
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context) => CaCard(
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const AppLogo(size: 64),
            const SizedBox(width: AppTheme.spaceLg),
            const SizedBox(
                height: 64,
                child: VerticalDivider(width: 1, color: Canopy.hairline)),
            const SizedBox(width: AppTheme.spaceLg),
            Semantics(
                image: true,
                label: 'common.hadayah_charity'.tr(),
                child: Image.asset('assets/images/hadayah_association_logo.png',
                    key: const ValueKey('settings-association-logo'),
                    height: 80,
                    excludeFromSemantics: true)),
          ]),
          const SizedBox(height: AppTheme.spaceMd),
          Text(AppIdentity.name(context.locale.languageCode),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center),
          const SizedBox(height: AppTheme.spaceSm),
          Text('settings.build_version'.tr(), textAlign: TextAlign.center),
          Text('settings.release_pending'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ]),
      );
}
