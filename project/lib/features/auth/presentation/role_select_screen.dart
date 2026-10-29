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
import '../../../core/widgets/hedayah/hedayah_kit.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  /// A new viewer goes back to the page that asked for sign-in, if any.
  static void _asViewer(BuildContext context) {
    final provider = context.read<AppProvider>()..selectViewerRole();
    context.go(provider.takeSignInReturn() ?? '/feed');
  }
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
    final viewer =
        _option(context, viewer: true, dock: dock, onTap: () => _asViewer(context));
    final broadcaster = _option(context, viewer: false, onTap: () {
      final provider = context.read<AppProvider>()..selectBroadcasterRole();
      // The application comes first; a page that asked for sign-in waits.
      provider.takeSignInReturn();
      context.go('/streamer-apply');
    });
    // A preacher in the mosque lessons programme uses the app as a viewer
    // and applies; the admins approve him (ADR-020).
    final preacher = _preacherOption(context, onTap: () {
      final provider = context.read<AppProvider>()..selectViewerRole();
      provider.takeSignInReturn();
      context.go('/lessons/apply');
    });
    return Scaffold(
        backgroundColor: context.pageGround,
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
                        onPressed: () => _asViewer(context))))
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
                          // Hedayah skin: the website's gold-ruled title.
                          if (context.isHedayahSkin)
                            HedayahSectionTitle(
                                'role_select.welcome_user'.tr(args: [name]),
                                subtitle: 'role_select.prompt_title'.tr())
                          else ...[
                            Text('role_select.welcome_user'.tr(args: [name]),
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: AppTheme.spaceSm),
                            Text('role_select.prompt_title'.tr(),
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge),
                          ],
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
                          const SizedBox(height: AppTheme.spaceLg),
                          preacher,
                        ]))))));
  }

  Widget _preacherOption(BuildContext context, {required VoidCallback onTap}) {
    final hedayah = context.isHedayahSkin;
    final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('role_select.preacher_title'.tr(),
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: AppTheme.spaceXs),
      Text('role_select.preacher_desc'.tr(),
          style: Theme.of(context).textTheme.bodyMedium),
    ]);
    final button = CaButton(
        key: const Key('role-select-preacher'),
        label: 'role_select.preacher_btn'.tr(),
        variant: CaButtonVariant.secondary,
        trailingIcon: CaGlyph.arrow,
        bareTrailing: true,
        onPressed: onTap);
    final icon = Container(
        padding: const EdgeInsets.all(AppTheme.spaceSm),
        decoration: BoxDecoration(
            color: hedayah ? HedayahSkin.chip : Canopy.mint,
            borderRadius: BorderRadius.circular(
                hedayah ? HedayahSkin.radiusCard : CanopyRadius.input)),
        child: const CaIcon(CaGlyph.cal, color: Canopy.brandGreen));
    return CaCard(
        child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 600
                ? Row(children: [
                    icon,
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(child: text),
                    const SizedBox(width: AppTheme.spaceMd),
                    button,
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Row(children: [
                          icon,
                          const SizedBox(width: AppTheme.spaceMd),
                          Expanded(
                              child: Text('role_select.preacher_title'.tr(),
                                  style: Theme.of(context).textTheme.titleMedium)),
                        ]),
                        const SizedBox(height: AppTheme.spaceSm),
                        Text('role_select.preacher_desc'.tr(),
                            style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: AppTheme.spaceMd),
                        button,
                      ])));
  }

  Widget _option(BuildContext context,
      {required bool viewer, required VoidCallback onTap, bool dock = false}) {
    final prefix = viewer ? 'viewer' : 'streamer';
    final hedayah = context.isHedayahSkin;
    return CaCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                  gradient: viewer && !hedayah ? CanopyGradients.pill : null,
                  color: hedayah
                      ? (viewer ? HedayahSkin.gold : HedayahSkin.chip)
                      : viewer
                          ? null
                          : Canopy.mint,
                  borderRadius: BorderRadius.circular(hedayah
                      ? HedayahSkin.radiusCard
                      : CanopyRadius.input)),
              child: CaIcon(viewer ? CaGlyph.compass : CaGlyph.mic,
                  color: viewer ? AppPalette.ink : Canopy.brandGreen))),
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
