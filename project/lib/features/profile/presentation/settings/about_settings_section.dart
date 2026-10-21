import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/config/app_identity.dart';
import '../../../../core/providers/app_experience.dart';
import 'package:provider/provider.dart';

/// The app logo is the switch between Hadayah Live and Taysir.
class AboutSettingsSection extends StatelessWidget {
  const AboutSettingsSection({super.key});

  Future<void> _toggle(BuildContext context, AppExperience experience) async {
    try {
      final next = await experience.toggle();
      if (!context.mounted) return;
      context.go(next.home);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('settings.experience_save_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always provided by the app (main.dart); absent only in isolated widget
    // harnesses, where the card shows without the switch.
    final experience = context.watch<AppExperience?>();
    final taysir = experience?.taysir ?? false;
    final hint = taysir
        ? 'settings.experience_hint_taysir'.tr()
        : 'settings.experience_hint_hadayah'.tr();
    void onTap() => _toggle(context, experience!);
    return CaCard(
      child: Column(children: [
        Semantics(
          button: experience != null,
          toggled: experience == null ? null : taysir,
          label: '${'settings.experience_label'.tr()}. $hint',
          onTap: experience == null ? null : onTap,
          child: GestureDetector(
            key: const ValueKey('settings-experience-toggle'),
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: experience == null ? null : onTap,
            child: const AppLogo(size: 64),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Text(
            taysir
                ? 'settings.experience_now_taysir'.tr()
                : AppIdentity.name(context.locale.languageCode),
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center),
        if (experience != null) ...[
          const SizedBox(height: AppTheme.spaceXs),
          Text(hint,
              key: const ValueKey('settings-experience-hint'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: HidayahGold.g700),
              textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppTheme.spaceSm),
        Text('settings.build_version'.tr(), textAlign: TextAlign.center),
        Text('settings.release_pending'.tr(),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      ]),
    );
  }
}
