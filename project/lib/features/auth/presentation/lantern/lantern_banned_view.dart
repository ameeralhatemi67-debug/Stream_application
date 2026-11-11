import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// The page a suspended account sees instead of the app, in Lantern and
/// Arch (ADR-026): why, who to write to, and Sign out. [AccountBannedScreen]
/// keeps the alert it raises and the sign-out.
class LanternBannedView extends StatelessWidget implements LanternSkinWidget {
  const LanternBannedView(
      {super.key,
      required this.reason,
      required this.supportEmail,
      required this.onSignOut});

  final String? reason;
  final String supportEmail;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        final why = reason?.trim() ?? '';
        return Scaffold(
            key: const ValueKey('lantern-banned'),
            backgroundColor: t.bg,
            body: SafeArea(
                child: Center(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 28),
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                maxWidth: context.lanternWide ? 560 : 440),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Center(
                                      child: Container(
                                          width: 76,
                                          height: 76,
                                          alignment: Alignment.center,
                                          decoration: ShapeDecoration(
                                              color: t.liveSoft,
                                              shape: LArchBorder(
                                                  bottom: 18,
                                                  side: BorderSide(
                                                      color: t.live,
                                                      width: 2))),
                                          child: LIcon(LGlyph.ban,
                                              size: 34, color: t.liveText))),
                                  const SizedBox(height: 22),
                                  Semantics(
                                      header: true,
                                      child: Text('account_banned.title'.tr(),
                                          textAlign: TextAlign.center,
                                          style: Lantern.displayStyle(24,
                                              color: t.fg,
                                              height: context.lanternArabic
                                                  ? 1.45
                                                  : 1.25))),
                                  const SizedBox(height: 10),
                                  Text('account_banned.body'.tr(),
                                      textAlign: TextAlign.center,
                                      style: Lantern.textStyle(14.5,
                                          color: t.muted, height: 1.6)),
                                  if (why.isNotEmpty) ...[
                                    const SizedBox(height: 18),
                                    LBanner(
                                        '${'account_banned.reason_label'.tr()}: $why',
                                        key: const ValueKey(
                                            'lantern-banned-reason'),
                                        tone: LTone.live),
                                  ],
                                  const SizedBox(height: 22),
                                  Text(
                                      'account_banned.contact_support'.tr(
                                          namedArgs: {'email': supportEmail}),
                                      textAlign: TextAlign.center,
                                      style: Lantern.textStyle(13,
                                          color: t.muted)),
                                  const SizedBox(height: 22),
                                  LButton(
                                      key: const ValueKey(
                                          'lantern-banned-sign-out'),
                                      label: 'account_banned.sign_out'.tr(),
                                      icon: LGlyph.logout,
                                      kind: LButtonKind.secondary,
                                      expand: true,
                                      onPressed: onSignOut),
                                ]))))));
      }));
}
