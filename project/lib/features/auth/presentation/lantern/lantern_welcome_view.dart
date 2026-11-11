import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../web/presentation/hidayah_web_header.dart'
    show showHidayahLegal;

/// The welcome and sign-in page in Lantern and Arch (ADR-026). The same
/// inputs as the Hedayah view: [WelcomeScreen] keeps the logic, the consent
/// gate and the sign-in calls.
///
/// Website layout: a night brand panel with the lattice, the white Hedayah
/// logo, the headline and who is live now, beside a calm card with the
/// sign-in buttons. Phone layout: the brand band on top, the card under it.
class LanternWelcomeView extends StatelessWidget implements LanternSkinWidget {
  const LanternWelcomeView(
      {super.key,
      required this.loading,
      required this.registrationsOpen,
      required this.showApple,
      required this.onGoogle,
      required this.onApple,
      required this.onGuest});

  final bool loading, registrationsOpen, showApple;
  final VoidCallback onGoogle, onApple, onGuest;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        return Scaffold(
            backgroundColor: t.bg,
            body: context.lanternWide ? _wide(context) : _phone(context));
      }));

  Widget _wide(BuildContext context) => Row(
          key: const ValueKey('lantern-welcome-wide'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                flex: 11,
                child: LNightBand(
                    latticeOpacity: .14,
                    latticeStep: 40,
                    child: SafeArea(
                        child: Center(
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(56),
                                child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 560),
                                    child: const _Brand(wide: true))))))),
            Expanded(
                flex: 10,
                child: SafeArea(
                    child: Column(children: [
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _Language())),
                  Expanded(
                      child: Center(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(40, 0, 40, 32),
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: _card(context))))),
                ]))),
          ]);

  Widget _phone(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
        key: const ValueKey('lantern-welcome-phone'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LNightBand(
              latticeOpacity: .14,
              latticeStep: 40,
              padding: EdgeInsets.fromLTRB(20, top + 12, 20, 32),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _Language()),
                    SizedBox(height: 8),
                    _Brand(wide: false),
                  ])),
          Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 28, 20, 28 + MediaQuery.paddingOf(context).bottom),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: _card(context)))),
        ]));
  }

  Widget _card(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    return Column(
        key: const ValueKey('lantern-welcome-card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
              header: true,
              child: Text('auth_welcome.card_title'.tr(),
                  style: Lantern.displayStyle(wide ? 28 : 24,
                      color: t.fg,
                      height: context.lanternArabic ? 1.45 : 1.2))),
          const SizedBox(height: 6),
          Text(
              (showApple
                      ? 'auth_welcome.card_subtitle_ios'
                      : 'auth_welcome.card_subtitle')
                  .tr(),
              style: Lantern.textStyle(14, color: t.muted, height: 1.5)),
          const SizedBox(height: 18),
          if (!registrationsOpen) ...[
            LBanner('auth_welcome.registrations_paused'.tr(),
                key: const Key('registrations-paused-notice'),
                tone: LTone.warn,
                icon: LGlyph.info),
            const SizedBox(height: 12),
          ],
          if (showApple) ...[
            SignInWithAppleButton(
                key: const Key('welcome-apple'),
                text: 'auth_welcome.btn_apple'.tr(),
                height: 52,
                style: t.night
                    ? SignInWithAppleButtonStyle.white
                    : SignInWithAppleButtonStyle.black,
                borderRadius: BorderRadius.circular(Lantern.radiusPill),
                onPressed: loading ? null : onApple),
            const SizedBox(height: 12),
          ],
          _GoogleButton(
              key: const Key('welcome-signup'),
              label: 'auth_welcome.btn_google_signup'.tr(),
              loading: loading,
              onPressed: registrationsOpen && !loading ? onGoogle : null),
          const SizedBox(height: 6),
          LButton(
              key: const ValueKey('welcome-login'),
              label: (showApple
                      ? 'auth_welcome.btn_google_login_ios'
                      : 'auth_welcome.btn_google_login')
                  .tr(),
              kind: LButtonKind.ghost,
              icon: LGlyph.person,
              onPressed: loading ? null : onGoogle),
          const SizedBox(height: 10),
          LStarDivider(label: 'auth_welcome.divider_or'.tr()),
          const SizedBox(height: 10),
          LButton(
              key: const Key('welcome-guest'),
              label: 'auth_welcome.btn_guest'.tr(),
              kind: LButtonKind.secondary,
              icon: LGlyph.compass,
              expand: true,
              onPressed: onGuest),
          const SizedBox(height: 18),
          Text('lantern.account.welcome_terms'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.textStyle(12.5, color: t.muted)),
          Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              children: [
                LLink('web.footer_terms'.tr(),
                    arrow: false, onTap: () => showHidayahLegal(context, 0)),
                LLink('web.footer_privacy'.tr(),
                    arrow: false, onTap: () => showHidayahLegal(context, 2)),
              ]),
        ]);
  }
}

/// The night panel: the white Hedayah logo, the platform's name, the
/// association, and who is live now.
class _Brand extends StatelessWidget {
  const _Brand({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final live = context.select<AppProvider,
            List<({String id, String name, bool audio})>>(
        (p) => !p.isOnline
            ? const []
            : [
                for (final s in p.streamers.where((s) => s.isCurrentlyLive))
                  (
                    id: s.streamerId,
                    name: s.getLocalizedName(context.locale.languageCode),
                    audio: s.isAudioLive,
                  ),
              ].take(4).toList());
    return Column(
        key: const ValueKey('lantern-welcome-brand'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LLogo(height: wide ? 64 : 48, onDark: true),
          SizedBox(height: wide ? 26 : 18),
          Text('auth_welcome.brand_title'.tr(),
              style: Lantern.textStyle(13,
                  color: LanternTokens.goldHi,
                  weight: FontWeight.w700,
                  height: 1.3)),
          const SizedBox(height: 8),
          Semantics(
              header: true,
              child: Text('skin.association'.tr(),
                  style: Lantern.displayStyle(wide ? 40 : 26,
                      color: LanternTokens.onNight,
                      height: context.lanternArabic ? 1.45 : 1.15))),
          const SizedBox(height: 10),
          Text('auth_welcome.subtitle'.tr(),
              style: Lantern.textStyle(wide ? 15 : 13.5,
                  color: t.muted, height: 1.6)),
          if (live.isNotEmpty) ...[
            SizedBox(height: wide ? 22 : 16),
            Text('web.sec_live'.tr(),
                style: Lantern.textStyle(12.5,
                    color: t.muted, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
                key: const ValueKey('lantern-welcome-live'),
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in live) _LiveChip(name: s.name, audio: s.audio),
                ]),
          ],
        ]);
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.name, required this.audio});

  final String name;
  final bool audio;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Container(
        padding: const EdgeInsetsDirectional.fromSTEB(5, 5, 10, 5),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Lantern.radiusPill),
            border: Border.all(color: t.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          LAvatar(name: name, size: 26, ring: audio ? LRing.audio : LRing.live),
          const SizedBox(width: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(13,
                      color: t.fg, weight: FontWeight.w600, height: 1.3))),
          const SizedBox(width: 8),
          LBadge((audio ? 'web.badge_audio' : 'web.badge_live').tr(),
              kind: audio ? LBadgeKind.audio : LBadgeKind.live, small: true),
        ]));
  }
}

/// The other language, as on the website header.
class _Language extends StatelessWidget {
  const _Language();

  @override
  Widget build(BuildContext context) => LChip(
      label: context.lanternArabic ? 'English' : 'العربية',
      icon: LGlyph.globe,
      dense: true,
      onTap: () => LanguageSwitcher.toggle(context));
}

/// Sign up with Google: a pill on the card ground with the G mark.
class _GoogleButton extends StatelessWidget {
  const _GoogleButton(
      {super.key,
      required this.label,
      required this.loading,
      required this.onPressed});

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final enabled = onPressed != null;
    return Opacity(
        opacity: enabled || loading ? 1 : .5,
        child: LPressable(
            onTap: onPressed,
            label: label,
            excludeChildSemantics: true,
            builder: (context, s) => AnimatedContainer(
                duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                transform: Matrix4.translationValues(
                    0, s.hovered && !s.pressed ? -1 : 0, 0),
                decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(Lantern.radiusPill),
                    border: Border.all(
                        color: s.hovered ? LanternTokens.gold : t.line,
                        width: 1.5),
                    boxShadow: s.hovered ? t.shadow : null),
                child: loading
                    ? const Center(child: LStarLoader(size: 22))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                            Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: t.sunk, shape: BoxShape.circle),
                                child: Text('G',
                                    style: Lantern.displayStyle(14,
                                        color: t.goldInk,
                                        weight: FontWeight.w700,
                                        height: 1))),
                            const SizedBox(width: 12),
                            Flexible(
                                child: Text(label,
                                    textAlign: TextAlign.center,
                                    style: Lantern.textStyle(15,
                                        color: t.fg,
                                        weight: FontWeight.w600,
                                        height: 1.3))),
                          ]))));
  }
}
