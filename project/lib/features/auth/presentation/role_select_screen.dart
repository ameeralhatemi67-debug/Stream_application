import '../../../core/layout/window_class.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/ds/ca_navigation.dart';
import '../../../core/widgets/ds/ca_button.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_icon.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final name =
        context.select<AppProvider, String?>((p) => p.googleUserName) ??
            'Welcome';
    final avatar =
        context.select<AppProvider, String?>((p) => p.googleUserAvatar);
    final expanded = MediaQuery.sizeOf(context).width >= CanopyWindow.expanded;
    final dock = !expanded &&
        (MediaQuery.textScalerOf(context).scale(1) >= 1.3 || context.isShort);
    final viewer = _option(context, viewer: true, dock: dock, onTap: () {
      context.read<AppProvider>().selectViewerRole();
      context.go('/feed');
    });
    final broadcaster = _option(context, viewer: false, onTap: () {
      context.read<AppProvider>().selectBroadcasterRole();
      context.go('/streamer-apply');
    });
    return Scaffold(
        backgroundColor: Canopy.dawn,
        appBar: CaAppBar(languageBare: true),
        bottomNavigationBar: dock
            ? SafeArea(
                top: false,
                child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    child: CaButton(
                        label: 'role_select.viewer_btn'.tr(),
                        trailingIcon: CaGlyph.arrow,
                        bareTrailing: true,
                        onPressed: () {
                          context.read<AppProvider>().selectViewerRole();
                          context.go('/feed');
                        })))
            : null,
        body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth:
                                expanded ? 900 : CanopySize.welcomeCardMax),
                        child: Column(children: [
                          CaAvatar(name: name, url: avatar, radius: 32),
                          const SizedBox(height: AppTheme.spaceMd),
                          Text('role_select.welcome_user'.tr(args: [name]),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: AppTheme.spaceSm),
                          Text('role_select.prompt_title'.tr(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: AppTheme.spaceXl),
                          if (expanded)
                            IntrinsicHeight(
                                child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Expanded(child: viewer),
                                  const SizedBox(width: AppTheme.spaceLg),
                                  Expanded(child: broadcaster)
                                ]))
                          else ...[
                            viewer,
                            const SizedBox(height: AppTheme.spaceLg),
                            broadcaster
                          ],
                        ]))))));
  }

  Widget _option(BuildContext context,
      {required bool viewer, required VoidCallback onTap, bool dock = false}) {
    final prefix = viewer ? 'viewer' : 'streamer';
    return CaCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                  gradient: viewer ? CanopyGradients.pill : null,
                  color: viewer ? null : Canopy.mint,
                  borderRadius: BorderRadius.circular(CanopyRadius.input)),
              child: CaIcon(viewer ? CaGlyph.compass : CaGlyph.mic,
                  color: viewer ? Canopy.paper : Canopy.brandGreen))),
      const SizedBox(height: AppTheme.spaceMd),
      Text('role_select.${prefix}_title'.tr(),
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppTheme.spaceSm),
      Text('role_select.${prefix}_badge'.tr(),
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: Canopy.brandGreen)),
      const SizedBox(height: AppTheme.spaceMd),
      Text('role_select.${prefix}_desc'.tr(),
          style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: AppTheme.spaceLg),
      if (!dock)
        CaButton(
            label: 'role_select.${prefix}_btn'.tr(),
            variant:
                viewer ? CaButtonVariant.primary : CaButtonVariant.secondary,
            trailingIcon: CaGlyph.arrow,
            bareTrailing: true,
            onPressed: onTap),
    ]));
  }
}
