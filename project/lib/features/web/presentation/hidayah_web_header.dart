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
import '../../../core/widgets/hedayah/hedayah_kit.dart';
import '../../discovery/presentation/bookmarks_sheet.dart';
import '../../notifications/presentation/notification_center_sheet.dart';
import '../../profile/presentation/widgets/legal_document_reader_screen.dart';
import 'hidayah_web_kit.dart';

/// Top-level sections reachable from the website navigation bar.
enum HidayahWebSection { discover, map, lessons, organizations, channel }

/// The website's top navigation bar: brand, section links and account tools.
/// [dark] is the cinema variant used above the live page and the studio.
class HidayahWebHeader extends StatelessWidget {
  const HidayahWebHeader(
      {super.key, this.active, this.onBranch, this.dark = false});
  final HidayahWebSection? active;

  /// Inside the tab shell, Discover, Map and Lessons switch branches so each
  /// keeps its own navigation stack; elsewhere they navigate.
  final ValueChanged<int>? onBranch;
  final bool dark;

  void _go(BuildContext context, HidayahWebSection section) {
    switch (section) {
      case HidayahWebSection.discover:
        onBranch != null ? onBranch!(0) : context.go('/feed');
      case HidayahWebSection.map:
        onBranch != null ? onBranch!(1) : context.go('/map');
      case HidayahWebSection.lessons:
        onBranch != null ? onBranch!(2) : context.go('/lessons');
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
              // Lessons-only admins land on their area (the router).
              p.isLessonsAdmin,
              p.isPermittedAdmin,
            ));
    // Hedayah skin (ADR-016): the association website's white header under
    // a thin gold utility strip; the cinema variant stays dark.
    final hedayah = !dark && context.isHedayahSkin;
    final ink = dark ? HidayahGold.g50 : HidayahGold.s900;
    final soft = dark
        ? HidayahGold.s300
        : hedayah
            ? HedayahSkin.muted
            : HidayahGold.s700;
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
                                  style: hedayah
                                      ? HedayahSkin.displayStyle(15,
                                          color: selected
                                              ? HedayahSkin.bronze
                                              : soft,
                                          weight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          height: 1.2)
                                      : HidayahText.body(14.5,
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
                        child: hedayah
                            ? AnimatedOpacity(
                                opacity: selected ? 1 : 0,
                                duration: HidayahWeb.hover,
                                child: const SizedBox(
                                    height: 3,
                                    child: DecoratedBox(
                                        decoration: BoxDecoration(
                                            color: HedayahSkin.gold,
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(3))))))
                            : HidayahGiltUnderline(visible: selected)),
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

    final header = Material(
        color: dark ? HidayahGold.s900 : HidayahGold.card,
        child: Container(
            height: HidayahWeb.headerHeight,
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: dark
                            ? HidayahGold.s800
                            : hedayah
                                ? HedayahSkin.line
                                : HidayahGold.hairline))),
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
                        hedayah
                            ? const HedayahRosette(size: 38)
                            : const AppLogo(size: 40),
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
                                  style: hedayah
                                      ? HedayahSkin.displayStyle(19,
                                          weight: FontWeight.w700, height: 1.3)
                                      : HidayahText.display(20, color: ink)),
                              Text('web.brand_sub'.tr(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: HidayahText.body(11,
                                      color: dark
                                          ? HidayahGold.s300
                                          : hedayah
                                              ? HedayahSkin.bodyGrey
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
              link(HidayahWebSection.lessons, 'web.nav_lessons'.tr()),
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
                hedayah
                    ? HedayahButton(
                        label: 'web.sign_in'.tr(),
                        expand: false,
                        compact: true,
                        onPressed: () => openSignIn(context))
                    : HidayahButton(
                        label: 'web.sign_in'.tr(),
                        compact: true,
                        onPressed: () => openSignIn(context)),
              ],
            ]))))));
    if (!hedayah) return header;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      HedayahGoldBand(
          step: 20,
          child: SizedBox(
              height: 30,
              child: HidayahWebWidth(
                  wide: true,
                  child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('skin.association'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HedayahSkin.displayStyle(12.5,
                              weight: FontWeight.w500, height: 1.2)))))),
      header,
    ]);
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
    // Hedayah skin: the website closes on gold; its text is ink here.
    final hedayah = context.isHedayahSkin;
    final heading = hedayah ? HedayahSkin.ink : HidayahGold.g300;
    final linkColour = hedayah ? HedayahSkin.ink : HidayahGold.s200;
    final quiet =
        hedayah ? HedayahSkin.ink.withValues(alpha: .86) : HidayahGold.s300;
    final faint =
        hedayah ? HedayahSkin.ink.withValues(alpha: .86) : HidayahGold.s400;
    Widget column(String title, List<(String, VoidCallback?)> links) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(HidayahText.upper(context, title),
                  style: HidayahText.eyebrow(context, heading)),
              const SizedBox(height: 14),
              for (final (label, onTap) in links)
                Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: InkWell(
                        onTap: onTap,
                        child: Text(label,
                            style: HidayahText.body(14,
                                color: linkColour, height: 1.4)))),
            ]);
    final content = HidayahWebWidth(
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
                                hedayah
                                    ? const HedayahRosette(
                                        size: 38, color: HedayahSkin.paper)
                                    : const AppLogo(size: 40),
                                const SizedBox(width: 10),
                                Text(AppIdentity.name(lang),
                                    style: hedayah
                                        ? HedayahSkin.displayStyle(20,
                                            weight: FontWeight.w700)
                                        : HidayahText.display(20,
                                            color: HidayahGold.g50)),
                              ]),
                              const SizedBox(height: 14),
                              ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 380),
                                  child: Text('web.footer_about'.tr(),
                                      style: HidayahText.body(13.5,
                                          color: quiet))),
                            ])),
                    Expanded(
                        child: column('web.footer_platform'.tr(), [
                      ('web.nav_discover'.tr(), () => context.go('/feed')),
                      ('web.nav_map'.tr(), () => context.go('/map')),
                      ('web.nav_lessons'.tr(), () => context.go('/lessons')),
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
                  Divider(
                      color: hedayah
                          ? HedayahSkin.ink.withValues(alpha: .18)
                          : const Color(0x29E2C389),
                      height: 1),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                        child: Text('web.footer_copyright'.tr(),
                            style: HidayahText.body(12.5, color: faint))),
                    Text('web.footer_made'.tr(),
                        style: HidayahText.body(12.5, color: faint)),
                  ]),
                ])));
    return hedayah
        ? HedayahGoldBand(step: 34, child: content)
        : HidayahNightBand(child: content);
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
      backgroundColor: dark ? HidayahGold.s950 : context.pageGround,
      // On a browser there are no system bars; a landscape tablet has them.
      body: SafeArea(
          child: Column(children: [
        HidayahWebHeader(active: active, dark: dark),
        Expanded(child: body),
      ])));
}
