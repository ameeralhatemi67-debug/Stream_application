import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';

/// "How will you use the app?" in Lantern and Arch (ADR-026): a viewer, a
/// broadcaster, or a preacher in the mosque lessons programme.
/// [RoleSelectScreen] keeps the choices and where each one leads.
class LanternRoleSelectView extends StatelessWidget
    implements LanternSkinWidget {
  const LanternRoleSelectView(
      {super.key,
      required this.name,
      required this.avatar,
      required this.onViewer,
      required this.onBroadcaster,
      required this.onPreacher});

  final String name;
  final String? avatar;
  final VoidCallback onViewer, onBroadcaster, onPreacher;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        final wide = context.lanternWide;
        final image = (avatar ?? '').trim().isEmpty
            ? null
            : buildSafeImageProvider(path: avatar!.trim());
        final viewer = _Choice(
            key: const ValueKey('role-select-viewer'),
            primary: true,
            icon: LGlyph.compass,
            title: 'role_select.viewer_title'.tr(),
            badge: 'role_select.viewer_badge'.tr(),
            body: 'role_select.viewer_desc'.tr(),
            action: 'role_select.viewer_btn'.tr(),
            onTap: onViewer);
        final broadcaster = _Choice(
            key: const ValueKey('role-select-broadcaster'),
            primary: false,
            icon: LGlyph.mic,
            title: 'role_select.streamer_title'.tr(),
            badge: 'role_select.streamer_badge'.tr(),
            body: 'role_select.streamer_desc'.tr(),
            action: 'role_select.streamer_btn'.tr(),
            onTap: onBroadcaster);
        return Scaffold(
            backgroundColor: t.bg,
            body: Column(children: [
              Material(
                  color: t.surface,
                  child: SafeArea(
                      bottom: false,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(
                            height: Lantern.appBarHeight,
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: wide
                                        ? Lantern.webGutter
                                        : Lantern.gutter),
                                child: Row(children: [
                                  LLogo(height: 32, onDark: t.night),
                                  const Spacer(),
                                  LChip(
                                      label: context.lanternArabic
                                          ? 'English'
                                          : 'العربية',
                                      icon: LGlyph.globe,
                                      dense: true,
                                      onTap: () =>
                                          LanguageSwitcher.toggle(context)),
                                ]))),
                        const LGiltLine(),
                      ]))),
              Expanded(
                  child: SingleChildScrollView(
                      key: const ValueKey('lantern-role-select'),
                      child: Column(children: [
                        // The welcome: a night band with the lattice, the
                        // person in a gold ring, and the question.
                        LNightBand(
                            latticeOpacity: .13,
                            glow: const Alignment(0, -.8),
                            child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                    20, wide ? 40 : 28, 20, wide ? 72 : 60),
                                child: Center(
                                    child: Column(children: [
                                  Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: Lantern.goldFill),
                                      child: LAvatar(
                                          name: name,
                                          image: image,
                                          size: wide ? 76 : 66)),
                                  const SizedBox(height: 16),
                                  Semantics(
                                      header: true,
                                      child: Text(
                                          'role_select.welcome_user'
                                              .tr(args: [name]),
                                          textAlign: TextAlign.center,
                                          style: Lantern.displayStyle(
                                              wide ? 30 : 24,
                                              color: LanternTokens.onNight,
                                              height: context.lanternArabic
                                                  ? 1.45
                                                  : 1.25))),
                                  const SizedBox(height: 8),
                                  Text('role_select.prompt_title'.tr(),
                                      textAlign: TextAlign.center,
                                      style: Lantern.textStyle(15.5,
                                          color: LanternTokens.onNight
                                              .withValues(alpha: .78))),
                                ])))),
                        // The choices rise over the band's edge.
                        Transform.translate(
                            offset: Offset(0, wide ? -44 : -36),
                            child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: wide ? 40 : 16),
                                child: Center(
                                    child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                            maxWidth: wide ? 940 : 480),
                                        child: Column(children: [
                                          if (wide)
                                            IntrinsicHeight(
                                                child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                  Expanded(child: viewer),
                                                  const SizedBox(width: 18),
                                                  Expanded(child: broadcaster),
                                                ]))
                                          else ...[
                                            viewer,
                                            const SizedBox(height: 14),
                                            broadcaster,
                                          ],
                                          const SizedBox(height: 18),
                                          const LStarDivider(),
                                          const SizedBox(height: 18),
                                          _Preacher(onTap: onPreacher),
                                          SizedBox(
                                              height:
                                                  MediaQuery.paddingOf(context)
                                                      .bottom),
                                        ]))))),
                      ]))),
            ]));
      }));
}

class _Choice extends StatelessWidget {
  const _Choice(
      {super.key,
      required this.primary,
      required this.icon,
      required this.title,
      required this.badge,
      required this.body,
      required this.action,
      required this.onTap});

  final bool primary;
  final LGlyph icon;
  final String title, badge, body, action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    // The recommended choice carries the gold edge and the star.
    return LCard(
        padding: EdgeInsets.zero,
        selected: primary,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  height: 92,
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                      color: primary ? null : t.sunk,
                      gradient: primary
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x40E2C389), Color(0x00E2C389)])
                          : null),
                  child: Container(
                      width: 64,
                      height: 74,
                      alignment: const Alignment(0, .3),
                      decoration: ShapeDecoration(
                          gradient: primary ? Lantern.goldFill : null,
                          color: primary ? null : t.surface,
                          shape: LArchBorder(
                              bottom: 0,
                              side: primary
                                  ? BorderSide.none
                                  : BorderSide(color: t.line, width: 1.5))),
                      child: LIcon(icon,
                          size: 28,
                          color: primary ? LanternTokens.onGold : t.goldInk))),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            textAlign: TextAlign.center,
                            style: Lantern.displayStyle(19,
                                color: t.fg,
                                height: context.lanternArabic ? 1.45 : 1.25)),
                        const SizedBox(height: 8),
                        Center(
                            child: LTag(badge,
                                tone: primary ? LTone.gold : LTone.neutral,
                                icon: primary
                                    ? LGlyph.sparkles
                                    : LGlyph.verified)),
                        const SizedBox(height: 12),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: Lantern.textStyle(14,
                                color: t.muted, height: 1.6)),
                        const SizedBox(height: 18),
                        LButton(
                            label: action,
                            kind: primary
                                ? LButtonKind.primary
                                : LButtonKind.secondary,
                            trailing: LGlyph.arrow,
                            expand: true,
                            onPressed: onTap),
                      ])),
            ]));
  }
}

class _Preacher extends StatelessWidget {
  const _Preacher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final icon = Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: t.sunk,
            borderRadius: BorderRadius.circular(Lantern.radiusTile)),
        child: LIcon(LGlyph.mosque, size: 22, color: t.goldInk));
    final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('role_select.preacher_title'.tr(),
              style: Lantern.textStyle(15.5,
                  color: t.fg, weight: FontWeight.w700, height: 1.35)),
          const SizedBox(height: 3),
          Text('role_select.preacher_desc'.tr(),
              style: Lantern.textStyle(13.5, color: t.muted)),
        ]);
    final button = LButton(
        key: const Key('role-select-preacher'),
        label: 'role_select.preacher_btn'.tr(),
        kind: LButtonKind.tonal,
        trailing: LGlyph.arrow,
        onPressed: onTap);
    return LCard(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
            builder: (context, box) => box.maxWidth >= 600
                ? Row(children: [
                    icon,
                    const SizedBox(width: 14),
                    Expanded(child: text),
                    const SizedBox(width: 14),
                    button,
                  ])
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              icon,
                              const SizedBox(width: 12),
                              Expanded(child: text),
                            ]),
                        const SizedBox(height: 14),
                        button,
                      ])));
  }
}
