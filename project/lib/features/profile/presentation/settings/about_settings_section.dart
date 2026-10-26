import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/app_distribution.dart';
import '../../../../core/providers/app_update_controller.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/config/app_identity.dart';

/// The app's logo beside the logo of the association behind it, the installed
/// version and, on release builds, whether a newer one is published.
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final updates = context.watch<AppUpdateController?>();
    final version = updates?.installedVersion;
    final build = updates?.installedBuild;
    return CaCard(
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
        if (version != null)
          Text(
              'settings.build_version'.tr(namedArgs: {
                'version': version,
                'build': build?.toString() ?? '-',
              }),
              key: const ValueKey('settings-installed-version'),
              textAlign: TextAlign.center),
        Text('settings.release_pending'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
        if (updates != null) _UpdateRow(updates: updates),
      ]),
    );
  }
}

/// "Version x is available" with its download, or a quiet "latest" line once
/// a check has answered. Nothing on builds that never check (web, debug).
class _UpdateRow extends StatelessWidget {
  const _UpdateRow({required this.updates});

  final AppUpdateController updates;

  @override
  Widget build(BuildContext context) {
    final release = updates.release;
    final status = updates.status;
    if (status == AppUpdateStatus.upToDate) {
      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spaceSm),
        child: Text('update.settings_latest'.tr(),
            key: const ValueKey('settings-update-latest'),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      );
    }
    if (release == null ||
        (status != AppUpdateStatus.available &&
            status != AppUpdateStatus.required)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceMd),
      child: Column(children: [
        Text(
            'update.settings_available'
                .tr(namedArgs: {'version': release.versionName}),
            key: const ValueKey('settings-update-available'),
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center),
        const SizedBox(height: AppTheme.spaceSm),
        CaButton(
          key: const ValueKey('settings-update-download'),
          label: updates.distribution == AppDistribution.play
              ? 'update.open_play'.tr()
              : 'update.download'.tr(),
          icon: CaGlyph.download,
          onPressed: () async {
            final opened = await updates.openDownload();
            if (!opened && context.mounted) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text('update.open_failed'.tr())));
            }
          },
        ),
      ]),
    );
  }
}
