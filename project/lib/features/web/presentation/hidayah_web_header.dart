import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/config/app_identity.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/routing/sign_in_prompt.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_surfaces.dart';
import '../../discovery/presentation/bookmarks_sheet.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import '../../profile/presentation/widgets/legal_document_reader_screen.dart';
import 'hidayah_web_kit.dart';

/// Top-level sections reachable from the website navigation bar.
enum HidayahWebSection { discover, map, organizations, channel }

/// The website's top navigation bar: brand, section links and account tools.
/// [dark] is the cinema variant used above the live page and the studio.
class HidayahWebHeader extends StatelessWidget {
  const HidayahWebHeader(
      {super.key, this.active, this.onBranch, this.dark = false});
  final HidayahWebSection? active;

  /// Inside the tab shell, Discover and Map switch branches so each keeps its
  /// own navigation stack; elsewhere they navigate.
  final ValueChanged<int>? onBranch;
  final bool dark;

  void _go(BuildContext context, HidayahWebSection section) {
    switch (section) {
      case HidayahWebSection.discover:
        onBranch != null ? onBranch!(0) : context.go('/feed');
      case HidayahWebSection.map:
        onBranch != null ? onBranch!(1) : context.go('/map');
      case HidayahWebSection.organizations:
        context.push('/organizations');
      case HidayahWebSection.channel:
        final own = context.read<AppProvider>().currentUserStreamerId;
        context.push(own == null || own.isEmpty ? '/feed' : '/profile/$own');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final (liveCount, unread, signedIn, streamer, admin, orgAdmin) =
        context.select<AppProvider, (int, int, bool, bool, bool, bool)>((p) => (
              p.isOnline
                  ? p.streamers.where((s) => s.isCurrentlyLive).length
                  : 0,
              p.unreadNotificationsCount,
              p.isLoggedInStreamer,
              p.isStreamerModeEnabled,
              p.isAdminUser,
              p.isPermittedAdmin,
            ));
    final ink = dark ? HidayahGold.g50 : HidayahGold.s900;
    final soft = dark ? HidayahGold.s300 : HidayahGold.s700;
    Widget link(HidayahWebSection section, String label, {Widget? trailing}) {
      final selected = section == active;
      return Semantics(
          button: true,
          selected: selected,
          child: InkWell(
              onTap: () => _go(context, section),
              child: SizedBox(
                  height: HidayahWeb.headerHeight,
                  child: Stack(children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Center(
                            widthFactor: 1,
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(label,
                                  style: HidayahText.body(14.5,
                                      color: selected ? ink : soft,
                                      weight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      height: 1.2)),
                              if (trailing != null) ...[
                                const SizedBox(width: 7),
                                trailing
                              ],
                            ]))),
                    Positioned(
                        left: 6,
                        right: 6,
                        bottom: 0,
                        child: HidayahGiltUnderline(visible: selected)),
                  ]))));
    }

    Widget tool(CaGlyph glyph, String label, VoidCallback onTap,
            {bool dot = false}) =>
        Tooltip(
            message: label,
            child: Semantics(
                button: true,
                label: label,
                child: InkResponse(
                    onTap: onTap,
                    radius: 22,
                    child: SizedBox.square(
                        dimension: 40,
                        child: Stack(alignment: Alignment.center, children: [
                          CaIcon(glyph, color: soft, size: 21),
                          if (dot)
                            const PositionedDirectional(
                                top: 9,
                                end: 9,
                                child: SizedBox.square(
                                    dimension: 8,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: HidayahGold.live,
                                            shape: BoxShape.circle)))),
                        ])))));

    return Material(
        color: dark ? HidayahGold.s900 : HidayahGold.card,
        child: Container(
            height: HidayahWeb.headerHeight,
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color:
                            dark ? HidayahGold.s800 : HidayahGold.hairline))),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(
                        maxWidth:
                            HidayahWeb.headerMax + HidayahWeb.headerGutter * 2),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: HidayahWeb.headerGutter),
                        child: Row(children: [
              ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: InkWell(
                      onTap: () => _go(context, HidayahWebSection.discover),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const AppLogo(size: 40),
                        const SizedBox(width: 10),
                        // The wordmark is a lockup in a 72 px bar: it grows
                        // with large text up to 1.4x, then holds.
                        Flexible(
                            child: MediaQuery.withClampedTextScaling(
                                maxScaleFactor: 1.4,
                                child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(AppIdentity.name(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HidayahText.display(20, color: ink)),
                              Text('web.brand_sub'.tr(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HidayahText.body(11,
                                      color: dark
                                          ? HidayahGold.s300
                                          : HidayahGold.s600,
                                      height: 1.3)),
                            ]))),
                      ]))),
              const SizedBox(width: 28),
              // Links scroll rather than overflow on narrow or enlarged text.
              Expanded(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
              link(HidayahWebSection.discover, 'web.nav_discover'.tr(),
                  trailing: liveCount == 0
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 1),
                          decoration: BoxDecoration(
                              gradient: HidayahGradients.live,
                              borderRadius: BorderRadius.circular(999)),
                          child: Text(
                              'web.live_count'.plural(liveCount),
                              style: HidayahText.body(11,
                                  color: HidayahGold.card,
                                  weight: FontWeight.w700,
                                  height: 1.3)))),
              link(HidayahWebSection.map, 'web.nav_map'.tr()),
              link(HidayahWebSection.organizations, 'web.nav_orgs'.tr()),
              if (streamer)
                link(HidayahWebSection.channel, 'web.nav_channel'.tr()),
                      ]))),
              const SizedBox(width: 12),
              CaLanguageChip(compact: true, bare: true, glass: dark),
              tool(CaGlyph.bookmark, 'nav.bookmarks'.tr(),
                  () => BookmarksSheet.show(context)),
              tool(CaGlyph.bell, 'nav.notifications'.tr(),
                  () => NotificationCenterSheet.show(context),
                  dot: unread > 0),
              tool(CaGlyph.gear, 'nav.settings'.tr(),
                  () => context.push('/settings')),
              if (admin)
                tool(CaGlyph.shield, 'settings.admin_hub_title'.tr(),
                    () => context.push('/admin')),
              if (orgAdmin)
                tool(CaGlyph.home, 'design_ui.organization_admin'.tr(),
                    () => context.push('/org-admin')),
              if (!signedIn) ...[
                const SizedBox(width: AppTheme.spaceSm),
                HidayahButton(
                    label: 'web.sign_in'.tr(),
                    compact: true,
                    onPressed: () => openSignIn(context)),
              ],
            ]))))));
  }
}

/// Opens the governance reader at [index]: 0 terms, 1 guidelines, 2 privacy.
void showHidayahLegal(BuildContext context, int index) => showCaSheet<void>(
    context,
    title: 'settings.governance_legal'.tr(),
    body: LegalDocumentReaderScreen(
        terms: context.read<AppProvider>().termsAndConditions,
        initialDocumentIndex: index),
    framed: false);

/// The site footer: what the platform is, where to go, and legal links.
class HidayahWebFooter extends StatelessWidget {
  const HidayahWebFooter({super.key});
  @override
  Widget build(BuildContext context) {
    void onLegal(int index) => showHidayahLegal(context, index);
    final lang = context.locale.languageCode;
    Widget column(String title, List<(String, VoidCallback?)> links) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(HidayahText.upper(context, title),
                  style: HidayahText.eyebrow(context, HidayahGold.g300)),
              const SizedBox(height: 14),
              for (final (label, onTap) in links)
                Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: InkWell(
                        onTap: onTap,
                        child: Text(label,
                            style: HidayahText.body(14,
                                color: HidayahGold.s200, height: 1.4)))),
            ]);
    return HidayahNightBand(
        child: HidayahWebWidth(
            child: Padding(
                padding: const EdgeInsets.only(top: 48, bottom: 28),
                child: Column(children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        flex: 2,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const AppLogo(size: 40),
                                const SizedBox(width: 10),
                                Text(AppIdentity.name(lang),
                                    style: HidayahText.display(20,
                                        color: HidayahGold.g50)),
                              ]),
                              const SizedBox(height: 14),
                              ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 380),
                                  child: Text('web.footer_about'.tr(),
                                      style: HidayahText.body(13.5,
                                          color: HidayahGold.s300))),
                            ])),
                    Expanded(
                        child: column('web.footer_platform'.tr(), [
                      ('web.nav_discover'.tr(), () => context.go('/feed')),
                      ('web.nav_map'.tr(), () => context.go('/map')),
                      ('web.nav_orgs'.tr(),
                          () => context.push('/organizations')),
                      ('web.footer_become'.tr(),
                          () => context.push('/streamer-apply')),
                    ])),
                    Expanded(
                        child: column('web.footer_help'.tr(), [
                      ('web.footer_privacy'.tr(), () => onLegal(2)),
                      ('web.footer_terms'.tr(), () => onLegal(0)),
                      ('web.footer_guidelines'.tr(), () => onLegal(1)),
                      ('nav.settings'.tr(), () => context.push('/settings')),
                    ])),
                    Expanded(
                        child: column('web.footer_app'.tr(), [
                      ('web.footer_android'.tr(), null),
                      ('web.footer_ios'.tr(), null),
                    ])),
                  ]),
                  const SizedBox(height: 36),
                  const Divider(color: Color(0x29E2C389), height: 1),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                        child: Text('web.footer_copyright'.tr(),
                            style: HidayahText.body(12.5,
                                color: HidayahGold.s400))),
                    Text('web.footer_made'.tr(),
                        style: HidayahText.body(12.5,
                            color: HidayahGold.s400)),
                  ]),
                ]))));
  }
}

/// A pushed website page: the navigation bar above [body].
class HidayahWebPage extends StatelessWidget {
  const HidayahWebPage(
      {super.key, required this.body, this.active, this.dark = false});
  final Widget body;
  final HidayahWebSection? active;
  final bool dark;
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: dark ? HidayahGold.s950 : HidayahGold.g50,
      // On a browser there are no system bars; a landscape tablet has them.
      body: SafeArea(
          child: Column(children: [
        HidayahWebHeader(active: active, dark: dark),
        Expanded(child: body),
      ])));
}
