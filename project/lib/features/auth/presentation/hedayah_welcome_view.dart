import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/config/app_identity.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/hedayah/hedayah_kit.dart';
import '../../../core/widgets/language_switcher.dart';

/// The welcome and sign-in page in the Hedayah skin (ADR-016). The website's
/// order: a gold band with the lattice and the reversed lockup, then a white
/// sheet with a gold-ruled title and pill actions. Wide windows split into
/// the band and the sheet side by side. [WelcomeScreen] keeps the logic.
class HedayahWelcomeView extends StatelessWidget {
  const HedayahWelcomeView(
      {super.key,
      required this.loading,
      required this.registrationsOpen,
      required this.showApple,
      required this.onGoogle,
      required this.onApple,
      required this.onGuest,
      this.pausedNotice});

  final bool loading, registrationsOpen, showApple;
  final VoidCallback onGoogle, onApple, onGuest;
  final Widget? pausedNotice;

  static const _wide = 900.0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= _wide;
    return Scaffold(
        backgroundColor: HedayahSkin.paper,
        body: wide ? _wideLayout(context) : _phoneLayout(context));
  }

  Widget _phoneLayout(BuildContext context) => SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const HedayahGoldBand(
            child: SafeArea(
                bottom: false,
                child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 60),
                    child: Column(children: [
                      Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: _LanguageTabs()),
                      SizedBox(height: 20),
                      HedayahLockup(size: 84, reversed: true, draw: true),
                      SizedBox(height: 18),
                      _Brand(size: 24),
                    ])))),
        Transform.translate(
            offset: const Offset(0, -32),
            child: Container(
                decoration: const BoxDecoration(
                    color: HedayahSkin.paper,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28))),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _actions(context))))),
      ]));

  Widget _wideLayout(BuildContext context) => Row(children: [
        Expanded(
            flex: 11,
            child: HedayahGoldBand(
                step: 36,
                child: SafeArea(
                    child: Center(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(40),
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 520),
                                child: const Column(children: [
                                  HedayahLockup(
                                      size: 132, reversed: true, draw: true),
                                  SizedBox(height: 28),
                                  _Brand(size: 34),
                                ]))))))),
        Expanded(
            flex: 9,
            child: SafeArea(
                child: Column(children: [
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: _LanguageTabs())),
              Expanded(
                  child: Center(
                      child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 12),
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: _actions(context))))),
            ]))),
      ]);

  Widget _actions(BuildContext context) {
    final ios = showApple;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HedayahSectionTitle('auth_welcome.card_title'.tr(),
          subtitle: (ios
                  ? 'auth_welcome.card_subtitle_ios'
                  : 'auth_welcome.card_subtitle')
              .tr()),
      const SizedBox(height: 24),
      if (pausedNotice != null) pausedNotice!,
      HedayahButton(
          key: const Key('welcome-signup'),
          label: 'auth_welcome.btn_google_signup'.tr(),
          loading: loading,
          leading: const _GoogleMark(),
          onPressed: registrationsOpen ? onGoogle : null),
      const SizedBox(height: 12),
      if (ios) ...[
        SignInWithAppleButton(
            key: const Key('welcome-apple'),
            text: 'auth_welcome.btn_apple'.tr(),
            height: 50,
            style: SignInWithAppleButtonStyle.black,
            borderRadius: BorderRadius.circular(HedayahSkin.radiusPill),
            onPressed: loading ? null : onApple),
        const SizedBox(height: 12),
      ],
      HedayahButton(
          kind: HedayahButtonKind.outline,
          label: (ios
                  ? 'auth_welcome.btn_google_login_ios'
                  : 'auth_welcome.btn_google_login')
              .tr(),
          leading: const CaIcon(CaGlyph.user, size: 20, color: HedayahSkin.ink),
          onPressed: loading ? null : onGoogle),
      const SizedBox(height: 18),
      Center(child: HedayahEyebrow('auth_welcome.divider_or'.tr())),
      const SizedBox(height: 18),
      HedayahButton(
          key: const Key('welcome-guest'),
          kind: HedayahButtonKind.tint,
          label: 'auth_welcome.btn_guest'.tr(),
          leading: const CaIcon(CaGlyph.compass,
              size: 20, color: HedayahSkin.bronze),
          onPressed: onGuest),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const HedayahRosette(size: 20),
        const SizedBox(width: 8),
        Flexible(
            child: Text('skin.association'.tr(),
                textAlign: TextAlign.center,
                style: HedayahSkin.textStyle(12.5,
                    color: HedayahSkin.bodyGrey, height: 1.5))),
      ]),
      const SizedBox(height: 24),
    ]);
  }
}

/// The app's name and the association's tagline, in ink on the gold band.
class _Brand extends StatelessWidget {
  const _Brand({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(AppIdentity.name(context.locale.languageCode),
            textAlign: TextAlign.center,
            style: HedayahSkin.displayStyle(size, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('skin.tagline'.tr(),
            textAlign: TextAlign.center,
            style: HedayahSkin.displayStyle(size * .56,
                weight: FontWeight.w400,
                color: HedayahSkin.ink.withValues(alpha: .86),
                height: 1.7)),
      ]);
}

/// Arabic and English as the website's pill tabs.
class _LanguageTabs extends StatelessWidget {
  const _LanguageTabs();

  @override
  Widget build(BuildContext context) => HedayahPillTabs<String>(
      options: const [('ar', 'العربية'), ('en', 'English')],
      value: context.locale.languageCode,
      onChanged: (code) {
        if (code != context.locale.languageCode) {
          LanguageSwitcher.set(context, code);
        }
      });
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: HedayahSkin.paper, shape: BoxShape.circle),
      child: Text('G',
          style: HedayahSkin.displayStyle(14,
              weight: FontWeight.w700, color: HedayahSkin.bronze, height: 1)));
}
