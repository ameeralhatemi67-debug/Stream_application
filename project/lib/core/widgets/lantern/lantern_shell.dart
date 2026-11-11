import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../features/discovery/presentation/bookmarks_sheet.dart';
import '../../../features/notifications/presentation/notification_center_sheet.dart';
import '../../../features/web/presentation/hidayah_web_header.dart'
    show showHidayahLegal;
import '../../config/app_identity.dart';
import '../../providers/app_provider.dart';
import '../../routing/sign_in_prompt.dart';
import '../../theme/app_theme.dart';
import '../language_switcher.dart';
import 'lantern_base.dart';
import 'lantern_controls.dart';
import 'lantern_surfaces.dart';

/// Space a tab's content leaves at the bottom for the floating navigation.
const lanternNavClearance = 88.0;

/// Opens the notifications list and the saved list from the Lantern chrome.
/// One place, so a Lantern drawer or page can replace the sheet behind them.
void openLanternNotifications(BuildContext context) =>
    NotificationCenterSheet.show(context);
void openLanternBookmarks(BuildContext context) => BookmarksSheet.show(context);

/// The 2 px gilt line under the header.
class LGiltLine extends StatelessWidget implements LanternSkinWidget {
  const LGiltLine({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
      height: 2,
      child: DecoratedBox(decoration: BoxDecoration(gradient: Lantern.gilt)));
}

/// The phone app bar on the three tabs: the Hedayah logo at the start, the
/// bell and the settings gear at the end, 60 px with the gilt line.
class LanternPhoneBar extends StatelessWidget
    implements LanternSkinWidget, PreferredSizeWidget {
  const LanternPhoneBar({super.key, this.onHome});

  final VoidCallback? onHome;

  @override
  Size get preferredSize => const Size.fromHeight(Lantern.appBarHeight + 2);

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final (unread, signedIn) = context.select<AppProvider, (int, bool)>(
        (p) => (p.unreadNotificationsCount, p.isLoggedInStreamer));
    return Material(
        color: t.surface,
        child: SafeArea(
            bottom: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: Lantern.appBarHeight,
                  child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: Lantern.gutter, end: 8),
                      child: Row(children: [
                        LPressable(
                            onTap: onHome,
                            label: AppIdentity.name(
                                context.locale.languageCode),
                            radius: 12,
                            excludeChildSemantics: true,
                            builder: (context, _) =>
                                LLogo(height: 34, onDark: t.night)),
                        const Spacer(),
                        // Saved items stay one tap away on a phone, as in the
                        // older designs; the design sheet draws only the bell
                        // and the gear.
                        LIconButton(
                            icon: LGlyph.bookmark,
                            label: 'nav.bookmarks'.tr(),
                            iconSize: 22,
                            onPressed: () => openLanternBookmarks(context)),
                        LIconButton(
                            icon: LGlyph.bell,
                            label: 'nav.notifications'.tr(),
                            dot: unread > 0,
                            iconSize: 22,
                            onPressed: () => openLanternNotifications(context)),
                        LIconButton(
                            icon: LGlyph.settings,
                            label: 'nav.settings'.tr(),
                            iconSize: 22,
                            onPressed: () => signedIn
                                ? context.push('/settings')
                                : openSignIn(context)),
                      ]))),
              const LGiltLine(),
            ])));
  }
}

/// The bar of a pushed page on a phone: back, a title, and up to a few tools.
class LanternPageBar extends StatelessWidget
    implements LanternSkinWidget, PreferredSizeWidget {
  const LanternPageBar(
      {super.key, required this.title, this.actions = const [], this.onBack});

  final String title;
  final List<Widget> actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(Lantern.appBarHeight + 2);

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Material(
        color: t.surface,
        child: SafeArea(
            bottom: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  height: Lantern.appBarHeight,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(children: [
                        LIconButton(
                            icon: LGlyph.back,
                            label: MaterialLocalizations.of(context)
                                .backButtonTooltip,
                            onPressed: onBack ??
                                () => context.canPop()
                                    ? context.pop()
                                    : context.go('/feed')),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Semantics(
                                header: true,
                                child: Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Lantern.displayStyle(18,
                                        color: t.fg, height: 1.4)))),
                        ...actions,
                      ]))),
              const LGiltLine(),
            ])));
  }
}

/// The floating bottom navigation: Discover, Map, Lessons. The chosen tab is
/// a gold pill with its name; the others fold to their icon. Discover carries
/// the number of rooms that are live.
class LanternBottomNav extends StatelessWidget implements LanternSkinWidget {
  const LanternBottomNav(
      {super.key,
      required this.index,
      required this.onChanged,
      this.liveCount = 0});

  final int index, liveCount;
  final ValueChanged<int> onChanged;

  static const destinations = <(LGlyph, String)>[
    (LGlyph.home, 'web.nav_discover'),
    (LGlyph.map, 'web.nav_map'),
    (LGlyph.book, 'web.nav_lessons'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final calm = Lantern.calm(context);
    return SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Center(
                heightFactor: 1,
                child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(Lantern.radiusPill),
                        border: Border.all(color: t.line),
                        boxShadow: t.shadowHi),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final (i, d) in destinations.indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        LPressable(
                            onTap: () => onChanged(i),
                            label: i == 0 && liveCount > 0
                                ? '${d.$2.tr()}, ${'web.live_count'.plural(liveCount)}'
                                : d.$2.tr(),
                            selected: i == index,
                            excludeChildSemantics: true,
                            pressScale: .95,
                            builder: (context, s) {
                              final on = i == index;
                              final fg = on ? LanternTokens.onGold : t.fg;
                              return AnimatedContainer(
                                  duration: calm
                                      ? Lantern.none
                                      : const Duration(milliseconds: 320),
                                  curve: Lantern.ease,
                                  height: 46,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: on ? 18 : 16),
                                  decoration: BoxDecoration(
                                      color: !on && s.hovered ? t.sunk : null,
                                      gradient: on ? Lantern.goldFill : null,
                                      borderRadius: BorderRadius.circular(
                                          Lantern.radiusPill),
                                      boxShadow: on
                                          ? const [
                                              BoxShadow(
                                                  color: Color(0xB3BD933F),
                                                  blurRadius: 12,
                                                  spreadRadius: -4,
                                                  offset: Offset(0, 5))
                                            ]
                                          : null),
                                  child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Stack(
                                            clipBehavior: Clip.none,
                                            children: [
                                              LIcon(d.$1, size: 22, color: fg),
                                              if (i == 0 && liveCount > 0)
                                                PositionedDirectional(
                                                    top: -7,
                                                    end: -9,
                                                    child: _CountDot(liveCount,
                                                        ring: on
                                                            ? LanternTokens
                                                                .gold
                                                            : t.surface)),
                                            ]),
                                        // No AnimatedSize under calm
                                        // motion: with no duration it
                                        // re-lays itself out mid-layout.
                                        _NavLabel(
                                            show: on,
                                            calm: calm,
                                            label: d.$2.tr(),
                                            color: fg),
                                      ]));
                            }),
                      ],
                    ])))));
  }
}

class _NavLabel extends StatelessWidget {
  const _NavLabel(
      {required this.show,
      required this.calm,
      required this.label,
      required this.color});

  final bool show, calm;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = show
        ? Padding(
            padding: const EdgeInsetsDirectional.only(start: 9),
            child: Text(label,
                maxLines: 1,
                style: Lantern.textStyle(14.5,
                    color: color, weight: FontWeight.w600, height: 1.3)))
        : const SizedBox.shrink();
    return calm
        ? text
        : AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Lantern.ease,
            child: text);
  }
}

class _CountDot extends StatelessWidget {
  const _CountDot(this.count, {required this.ring});

  final int count;
  final Color ring;

  @override
  Widget build(BuildContext context) => Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: LanternTokens.liveFill,
          borderRadius: BorderRadius.circular(Lantern.radiusPill),
          border: Border.all(color: ring, width: 1.5)),
      child: Text(count > 99 ? '99+' : '$count',
          style: Lantern.textStyle(9.5,
                  color: LanternTokens.white,
                  weight: FontWeight.w700,
                  height: 1.1)
              .copyWith(fontFeatures: Lantern.tabular)));
}

enum LanternSection { discover, map, lessons, organizations, channel }

/// The website header (1024 and wider): 72 px with the gilt line. The brand
/// is the Hedayah logo, a hairline, then the platform's name. Discover
/// carries the live count; the admin shield and organization home show only
/// to people who may use them, and Sign in only when signed out.
class LanternWebHeader extends StatelessWidget implements LanternSkinWidget {
  const LanternWebHeader({super.key, this.active, this.onBranch});

  final LanternSection? active;

  /// Inside the tab shell the first three links switch branches, so each
  /// keeps its own page stack; elsewhere they navigate.
  final ValueChanged<int>? onBranch;

  void _go(BuildContext context, LanternSection section) {
    switch (section) {
      case LanternSection.discover:
        onBranch != null ? onBranch!(0) : context.go('/feed');
      case LanternSection.map:
        onBranch != null ? onBranch!(1) : context.go('/map');
      case LanternSection.lessons:
        onBranch != null ? onBranch!(2) : context.go('/lessons');
      case LanternSection.organizations:
        context.push('/organizations');
      case LanternSection.channel:
        final own = context.read<AppProvider>().currentUserStreamerId;
        context.push(own == null || own.isEmpty ? '/feed' : '/profile/$own');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final (liveCount, unread, signedIn, streamer, admin, orgAdmin) =
        context.select<AppProvider, (int, int, bool, bool, bool, bool)>((p) => (
              p.isOnline
                  ? p.streamers.where((s) => s.isCurrentlyLive).length
                  : 0,
              p.unreadNotificationsCount,
              p.isLoggedInStreamer,
              p.isStreamerModeEnabled,
              p.hasAdminPage,
              p.isPermittedAdmin,
            ));
    Widget link(LanternSection section, String label, {Widget? trailing}) {
      final on = section == active;
      return LPressable(
          onTap: () => _go(context, section),
          label: label,
          selected: on,
          radius: 10,
          pressScale: 1,
          excludeChildSemantics: true,
          builder: (context, s) => SizedBox(
              height: Lantern.headerHeight,
              child: Stack(alignment: Alignment.center, children: [
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(label,
                          style: Lantern.textStyle(15,
                              color: on || s.hovered ? t.fg : t.muted,
                              weight: on ? FontWeight.w700 : FontWeight.w500,
                              height: 1.3)),
                      if (trailing != null) ...[
                        const SizedBox(width: 7),
                        trailing
                      ],
                    ])),
                Positioned(
                    left: 10,
                    right: 10,
                    bottom: 0,
                    child: AnimatedOpacity(
                        opacity: on ? 1 : 0,
                        duration:
                            Lantern.calm(context) ? Lantern.none : Lantern.state,
                        child: Container(
                            height: 3,
                            decoration: const BoxDecoration(
                                gradient: Lantern.goldFill,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(3)))))),
              ])));
    }

    return Material(
        color: t.surface,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: Lantern.headerHeight,
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(
                          maxWidth:
                              Lantern.webContent + Lantern.webGutter * 2),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Lantern.webGutter),
                          child: Row(children: [
                            LPressable(
                                onTap: () =>
                                    _go(context, LanternSection.discover),
                                label: AppIdentity.name(lang),
                                radius: 12,
                                pressScale: 1,
                                excludeChildSemantics: true,
                                builder: (context, _) => Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          LLogo(height: 38, onDark: t.night),
                                          Container(
                                              width: 1,
                                              height: 30,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14),
                                              color: t.line),
                                          Text(AppIdentity.name(lang),
                                              maxLines: 1,
                                              style: Lantern.displayStyle(17,
                                                  color: t.fg, height: 1.3)),
                                        ])),
                            const SizedBox(width: 22),
                            Expanded(
                                child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(children: [
                                      link(LanternSection.discover,
                                          'web.nav_discover'.tr(),
                                          trailing: liveCount == 0
                                              ? null
                                              : LBadge(
                                                  'web.live_count'
                                                      .plural(liveCount),
                                                  kind: LBadgeKind.live,
                                                  small: true)),
                                      link(LanternSection.map,
                                          'web.nav_map'.tr()),
                                      link(LanternSection.lessons,
                                          'web.nav_lessons'.tr()),
                                      link(LanternSection.organizations,
                                          'web.nav_orgs'.tr()),
                                      if (streamer)
                                        link(LanternSection.channel,
                                            'web.nav_channel'.tr()),
                                    ]))),
                            const SizedBox(width: 10),
                            LChip(
                                label: lang == 'ar' ? 'English' : 'العربية',
                                icon: LGlyph.globe,
                                dense: true,
                                onTap: () => LanguageSwitcher.toggle(context)),
                            const SizedBox(width: 4),
                            LIconButton(
                                icon: LGlyph.bookmark,
                                label: 'nav.bookmarks'.tr(),
                                onPressed: () => openLanternBookmarks(context)),
                            LIconButton(
                                icon: LGlyph.bell,
                                label: 'nav.notifications'.tr(),
                                dot: unread > 0,
                                onPressed: () =>
                                    openLanternNotifications(context)),
                            if (signedIn)
                              LIconButton(
                                  icon: LGlyph.settings,
                                  label: 'nav.settings'.tr(),
                                  onPressed: () => context.push('/settings')),
                            if (admin)
                              LIconButton(
                                  icon: LGlyph.shield,
                                  label: 'settings.admin_hub_title'.tr(),
                                  onPressed: () => context.push('/admin')),
                            if (orgAdmin)
                              LIconButton(
                                  icon: LGlyph.org,
                                  label: 'design_ui.organization_admin'.tr(),
                                  onPressed: () => context.push('/org-admin')),
                            if (!signedIn) ...[
                              const SizedBox(width: 8),
                              LButton(
                                  label: 'web.sign_in'.tr(),
                                  size: LButtonSize.small,
                                  onPressed: () => openSignIn(context)),
                            ],
                          ]))))),
          const LGiltLine(),
        ]));
  }
}

/// The website footer: a night band with the lattice at 6%, led by the white
/// Hedayah logo; four columns below it.
class LanternWebFooter extends StatelessWidget implements LanternSkinWidget {
  const LanternWebFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final wide = context.lanternWide;
    return LNightBand(
        latticeOpacity: .06,
        glow: null,
        child: Builder(builder: (context) {
          final t = context.lt;
          Widget column(String title, List<(String, VoidCallback?)> links) =>
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: Lantern.textStyle(13.5,
                            color: LanternTokens.goldHi,
                            weight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final (label, onTap) in links)
                      onTap == null
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(label,
                                  style: Lantern.textStyle(13.5,
                                      color: t.muted)))
                          : LPressable(
                              onTap: onTap,
                              label: label,
                              radius: 8,
                              pressScale: 1,
                              excludeChildSemantics: true,
                              builder: (context, s) => Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Text(label,
                                      style: Lantern.textStyle(13.5,
                                          color: s.hovered
                                              ? LanternTokens.goldHi
                                              : t.fg)))),
                  ]);
          final about = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const LLogo(height: 44, onDark: true),
                  const SizedBox(width: 14),
                  Flexible(
                      child: Text(AppIdentity.name(lang),
                          style: Lantern.displayStyle(18,
                              color: t.fg, height: 1.3))),
                ]),
                const SizedBox(height: 14),
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text('web.footer_about'.tr(),
                        style: Lantern.textStyle(13.5, color: t.muted))),
              ]);
          final columns = [
            column('web.footer_platform'.tr(), [
              ('web.nav_discover'.tr(), () => context.go('/feed')),
              ('web.nav_map'.tr(), () => context.go('/map')),
              ('web.nav_lessons'.tr(), () => context.go('/lessons')),
              ('web.nav_orgs'.tr(), () => context.push('/organizations')),
              ('web.footer_become'.tr(), () => context.push('/streamer-apply')),
            ]),
            column('web.footer_help'.tr(), [
              ('web.footer_privacy'.tr(), () => showHidayahLegal(context, 2)),
              ('web.footer_terms'.tr(), () => showHidayahLegal(context, 0)),
              (
                'web.footer_guidelines'.tr(),
                () => showHidayahLegal(context, 1)
              ),
              ('nav.settings'.tr(), () => context.push('/settings')),
            ]),
            column('web.footer_app'.tr(), [
              ('web.footer_android'.tr(), null),
              ('web.footer_ios'.tr(), null),
            ]),
          ];
          return Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: Lantern.webContent + Lantern.webGutter * 2),
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          wide ? Lantern.webGutter : Lantern.gutter,
                          36,
                          wide ? Lantern.webGutter : Lantern.gutter,
                          wide ? 28 : 28 + lanternNavClearance),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (wide)
                              Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: about),
                                    for (final c in columns)
                                      Expanded(flex: 3, child: c),
                                  ])
                            else ...[
                              about,
                              const SizedBox(height: 24),
                              Wrap(spacing: 32, runSpacing: 24, children: [
                                for (final c in columns)
                                  SizedBox(width: 150, child: c),
                              ]),
                            ],
                            const SizedBox(height: 24),
                            Container(height: 1, color: t.line),
                            const SizedBox(height: 14),
                            Wrap(
                                spacing: 16,
                                runSpacing: 6,
                                alignment: WrapAlignment.spaceBetween,
                                children: [
                                  // Fine print: the footer's own grey, 6.2:1
                                  // on the night ground.
                                  Text('web.footer_copyright'.tr(),
                                      style: Lantern.textStyle(12.5,
                                          color: const Color(0xFF8A959F))),
                                  Text('web.footer_made'.tr(),
                                      style: Lantern.textStyle(12.5,
                                          color: const Color(0xFF8A959F))),
                                ]),
                          ]))));
        }));
  }
}

/// The corner player: what stays when someone leaves a room with "keep
/// watching in a corner". A night pill above the navigation that returns to
/// the room or closes it.
class LanternCornerPlayer extends StatelessWidget implements LanternSkinWidget {
  const LanternCornerPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final (active, title, name, id, audio) = context
        .select<AppProvider, (bool, String?, String?, String?, bool)>((p) => (
              p.isMiniPlayerActive,
              p.miniPlayerTitle,
              p.miniPlayerStreamerName,
              p.miniPlayerStreamId,
              p.isMiniPlayerAudioOnly
            ));
    if (!active || id == null || id.isEmpty) return const SizedBox.shrink();
    final wide = context.lanternWide;
    return PositionedDirectional(
        start: 16,
        end: wide ? null : 16,
        bottom: MediaQuery.paddingOf(context).bottom +
            (wide ? 20 : lanternNavClearance),
        child: LanternSurface(
            night: true,
            child: Builder(builder: (context) {
              final t = context.lt;
              void open() {
                context.read<AppProvider>().closeMiniPlayer();
                context.push('/live/$id');
              }

              return ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Material(
                      color: t.surface,
                      elevation: 8,
                      shadowColor: const Color(0x99000000),
                      shape: StadiumBorder(side: BorderSide(color: t.line)),
                      child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              6, 6, 6, 6),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Expanded(
                                child: LPressable(
                                    onTap: open,
                                    label:
                                        '${'lantern.corner.return'.tr()}: ${title ?? ''}',
                                    excludeChildSemantics: true,
                                    pressScale: .98,
                                    builder: (context, _) => Row(children: [
                                          Container(
                                              width: 44,
                                              height: 44,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                  color: audio
                                                      ? t.audioSoft
                                                      : t.liveSoft,
                                                  shape: BoxShape.circle),
                                              child: audio
                                                  ? LEqualizer(
                                                      color: t.audio,
                                                      height: 16,
                                                      barWidth: 3)
                                                  : LIcon(LGlyph.live,
                                                      size: 22,
                                                      color: t.liveText)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(title ?? '',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Lantern.textStyle(
                                                        14,
                                                        color: t.fg,
                                                        weight:
                                                            FontWeight.w600,
                                                        height: 1.3)),
                                                Text(
                                                    name == null ||
                                                            name.isEmpty
                                                        ? (audio
                                                                ? 'lantern.corner.audio'
                                                                : 'lantern.corner.video')
                                                            .tr()
                                                        : name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Lantern.textStyle(
                                                        12,
                                                        color: t.muted,
                                                        height: 1.3)),
                                              ])),
                                        ]))),
                            LIconButton(
                                icon: LGlyph.fullscreen,
                                label: 'lantern.corner.return'.tr(),
                                onPressed: open),
                            LIconButton(
                                icon: LGlyph.close,
                                label: 'lantern.corner.close'.tr(),
                                onPressed: () => context
                                    .read<AppProvider>()
                                    .closeMiniPlayer()),
                          ]))));
            })));
  }
}

/// The frame around the three tabs in the Lantern design. Website layout:
/// the header above the tab. Phone layout: the app bar above and the
/// floating navigation over the bottom of the tab.
class LanternTabShell extends StatelessWidget implements LanternSkinWidget {
  const LanternTabShell(
      {super.key,
      required this.index,
      required this.onBranch,
      required this.child});

  final int index;
  final ValueChanged<int> onBranch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = context.lanternWide;
    final liveCount = context.select<AppProvider, int>((p) => p.isOnline
        ? p.streamers.where((s) => s.isCurrentlyLive).length
        : 0);
    return LanternSurface(child: Builder(builder: (context) {
      final t = context.lt;
      final media = MediaQuery.of(context);
      return Scaffold(
          backgroundColor: t.bg,
          body: Stack(children: [
            Column(children: [
              if (wide)
                SafeArea(
                    bottom: false,
                    child: LanternWebHeader(
                        active: LanternSection.values[index],
                        onBranch: onBranch))
              else
                LanternPhoneBar(onHome: () => onBranch(0)),
              Expanded(
                  // The tab is told about the floating navigation as bottom
                  // padding, so lists end clear of it.
                  child: MediaQuery(
                      data: media.copyWith(
                          padding: media.padding.copyWith(
                              top: 0,
                              bottom: wide
                                  ? media.padding.bottom
                                  : media.padding.bottom +
                                      lanternNavClearance)),
                      child: child)),
            ]),
            if (!wide)
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LanternBottomNav(
                      index: index, onChanged: onBranch, liveCount: liveCount)),
            const LanternCornerPlayer(),
          ]));
    }));
  }
}
