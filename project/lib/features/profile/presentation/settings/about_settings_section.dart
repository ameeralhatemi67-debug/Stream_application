import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/config/app_identity.dart';
import '../../../../core/theme/app_appearance.dart';
import '../../../../core/theme/app_launcher_icon.dart';
import 'package:provider/provider.dart';

class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});
  Future<void> _togglePalette(BuildContext context) async {
    try {
      await context.read<AppAppearance>().toggle();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text((error is LauncherIconException
            ? 'settings.palette_icon_error'
            : 'settings.palette_save_error').tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) => CaCard(
        child: Column(children: [
          Semantics(
            button: true,
            label: 'settings.palette_toggle'.tr(),
            onTap: () => _togglePalette(context),
            child: GestureDetector(
              key: const ValueKey('settings-palette-toggle'),
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => _togglePalette(context),
              child: const AppLogo(size: 64),
            ),
          ),
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
