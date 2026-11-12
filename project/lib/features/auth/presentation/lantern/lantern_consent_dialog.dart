import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// The consent gate in Lantern and Arch (ADR-026; redrawn 2026-11-12): a
/// night band with the lattice and a shield in the arch, what the app keeps
/// as three rows of one card, the full policy, then the agreement as one
/// tappable row that turns gold when ticked, and Agree & Continue (off until
/// then) over Decline. [ConsentDialog] keeps the state and the answer; it
/// cannot be dismissed by the back button or a tap outside.
class LanternConsentDialog extends StatelessWidget
    implements LanternSkinWidget {
  const LanternConsentDialog(
      {super.key,
      required this.agreed,
      required this.onToggle,
      required this.onDecline,
      required this.onAccept,
      required this.onViewPolicy,
      this.support});

  final bool agreed;
  final VoidCallback onToggle, onDecline, onViewPolicy;

  /// Null while the box is not ticked.
  final VoidCallback? onAccept;

  /// The support contact the older dialog shows (iOS only).
  final Widget? support;

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      child: LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        final points = [
          (LGlyph.person, 'consent.data_point_profile'.tr()),
          (LGlyph.pin, 'consent.data_point_location'.tr()),
          (LGlyph.chat, 'consent.data_point_chat'.tr()),
        ];
        return Dialog(
            key: const ValueKey('lantern-consent'),
            backgroundColor: t.raised,
            surfaceTintColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Lantern.radiusDialog),
                side: BorderSide(color: t.line)),
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                // The band and the buttons stay; the middle scrolls on a
                // short screen.
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LNightBand(
                          latticeOpacity: .14,
                          latticeStep: 34,
                          glow: const Alignment(0, -1),
                          child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(22, 18, 22, 16),
                              child: Row(children: [
                                Container(
                                    width: 54,
                                    height: 62,
                                    alignment: const Alignment(0, .3),
                                    decoration: const ShapeDecoration(
                                        gradient: Lantern.goldFill,
                                        shape: LArchBorder(bottom: 10)),
                                    child: const LIcon(LGlyph.shield,
                                        size: 26, color: LanternTokens.onGold)),
                                const SizedBox(width: 16),
                                Expanded(
                                    child: Semantics(
                                        header: true,
                                        child: Text('consent.title'.tr(),
                                            style: Lantern.displayStyle(22,
                                                color: LanternTokens.onNight,
                                                height: context.lanternArabic
                                                    ? 1.45
                                                    : 1.25)))),
                              ]))),
                      const LGiltLine(),
                      Flexible(
                          child: SingleChildScrollView(
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 16, 20, 4),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('consent.body_intro'.tr(),
                                            style: Lantern.textStyle(14,
                                                color: t.muted, height: 1.55)),
                                        const SizedBox(height: 14),
                                        Container(
                                            decoration: BoxDecoration(
                                                color: t.surface,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        Lantern.radiusRow),
                                                border:
                                                    Border.all(color: t.line2)),
                                            child: Column(children: [
                                              for (final (i, (icon, text))
                                                  in points.indexed) ...[
                                                if (i > 0)
                                                  Container(
                                                      height: 1,
                                                      color: t.line2),
                                                Padding(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 9),
                                                    child: Row(children: [
                                                      Container(
                                                          width: 36,
                                                          height: 36,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration: BoxDecoration(
                                                              color: t.sunk,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          Lantern
                                                                              .radiusTile)),
                                                          child: LIcon(icon,
                                                              size: 18,
                                                              color:
                                                                  t.goldInk)),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                          child: Text(text,
                                                              style: Lantern
                                                                  .textStyle(
                                                                      13.5,
                                                                      color:
                                                                          t.fg,
                                                                      height:
                                                                          1.45))),
                                                    ])),
                                              ],
                                            ])),
                                        if (support != null) support!,
                                        const SizedBox(height: 10),
                                        Align(
                                            alignment: AlignmentDirectional
                                                .centerStart,
                                            child: LLink(
                                                'consent.view_full_policy'.tr(),
                                                key: const ValueKey(
                                                    'lantern-consent-policy'),
                                                icon: LGlyph.external,
                                                onTap: onViewPolicy)),
                                        const SizedBox(height: 12),
                                      ])))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // The agreement: the whole row is the box.
                                LPressable(
                                    key:
                                        const ValueKey('lantern-consent-check'),
                                    onTap: onToggle,
                                    label: 'consent.checkbox_label'.tr(),
                                    toggled: agreed,
                                    button: false,
                                    radius: Lantern.radiusRow,
                                    pressScale: .99,
                                    excludeChildSemantics: true,
                                    builder: (context, s) => AnimatedContainer(
                                        duration: Lantern.calm(context)
                                            ? Lantern.none
                                            : Lantern.state,
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(6, 4, 14, 4),
                                        decoration: BoxDecoration(
                                            color: agreed
                                                ? t.sunk
                                                : s.hovered
                                                    ? t.sunk
                                                    : t.surface,
                                            borderRadius: BorderRadius.circular(
                                                Lantern.radiusRow),
                                            border: Border.all(
                                                color: agreed
                                                    ? LanternTokens.gold
                                                    : t.line,
                                                width: agreed ? 1.5 : 1)),
                                        child: Row(children: [
                                          ExcludeFocus(
                                              child: LCheckbox(
                                                  value: agreed,
                                                  label:
                                                      'consent.checkbox_label'
                                                          .tr(),
                                                  onChanged: (_) =>
                                                      onToggle())),
                                          const SizedBox(width: 4),
                                          Expanded(
                                              child: Text(
                                                  'consent.checkbox_label'.tr(),
                                                  style: Lantern.textStyle(13.5,
                                                      color: t.fg,
                                                      weight: agreed
                                                          ? FontWeight.w600
                                                          : FontWeight.w400,
                                                      height: 1.45))),
                                        ]))),
                                const SizedBox(height: 12),
                                LButton(
                                    key: const ValueKey(
                                        'lantern-consent-accept'),
                                    label: 'consent.accept_btn'.tr(),
                                    icon: LGlyph.check,
                                    expand: true,
                                    onPressed: onAccept),
                                const SizedBox(height: 8),
                                LButton(
                                    key: const ValueKey(
                                        'lantern-consent-decline'),
                                    label: 'common.decline'.tr(),
                                    kind: LButtonKind.ghost,
                                    expand: true,
                                    onPressed: onDecline),
                              ])),
                    ])));
      })));
}
