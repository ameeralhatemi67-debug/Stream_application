import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_button.dart';
import '../../../core/widgets/ds/ca_navigation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// Confirmation screen after submitting Streamer Verification Application
class ApplicationPendingScreen extends StatelessWidget {
  const ApplicationPendingScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Canopy.dawn,
        appBar: CaAppBar(
            languageBare: true,
            leading: CaIconButton(
                bare: true,
                icon: CaGlyph.back,
                label: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/settings'))),
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: CanopySize.wizardForm),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CaCard(
                      variant: CaCardVariant.feature,
                      child: Column(children: [
                        const CaIcon(CaGlyph.shield,
                            size: CanopySize.emptyArtHeight),
                        const SizedBox(height: AppTheme.spaceLg),
                        Text('wizard_pending.title'.tr(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: AppTheme.spaceSm),
                        Text('wizard_pending.subtitle'.tr(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ])),
                  const SizedBox(height: AppTheme.spaceLg),
                  CaCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        for (var i = 1; i <= 3; i++) ...[
                          Text('wizard_pending.step${i}_title'.tr(),
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: AppTheme.spaceSm),
                          Text('wizard_pending.step${i}_desc'.tr(),
                              style: Theme.of(context).textTheme.bodyMedium),
                          if (i < 3) const SizedBox(height: AppTheme.spaceLg),
                        ],
                      ])),
                  const SizedBox(height: AppTheme.spaceXl),
                  CaButton(
                      label: 'wizard_pending.btn_explore'.tr(),
                      onPressed: () => context.go('/feed')),
                ]),
          ),
        ))),
      );
}
