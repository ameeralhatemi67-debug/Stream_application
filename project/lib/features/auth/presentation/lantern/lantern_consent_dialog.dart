import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// The consent gate in Lantern and Arch (ADR-026): every line of the older
/// dialog and its rule, Agree & Continue stays off until the box is ticked.
/// [ConsentDialog] keeps the state and the answer; it cannot be dismissed
/// by the back button or a tap outside.
class LanternConsentDialog extends StatelessWidget implements LanternSkinWidget {
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
        Widget point(LGlyph icon, String text) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
                color: t.sunk,
                borderRadius: BorderRadius.circular(Lantern.radiusTile)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              LIcon(icon, size: 18, color: t.goldInk),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(text,
                      style:
                          Lantern.textStyle(13.5, color: t.fg, height: 1.45))),
            ]));
        return LDialogCard(
            key: const ValueKey('lantern-consent'),
            title: 'consent.title'.tr(),
            body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('consent.body_intro'.tr(),
                      style: Lantern.textStyle(13.5, color: t.muted)),
                  const SizedBox(height: 12),
                  point(LGlyph.person, 'consent.data_point_profile'.tr()),
                  const SizedBox(height: 8),
                  point(LGlyph.pin, 'consent.data_point_location'.tr()),
                  const SizedBox(height: 8),
                  point(LGlyph.chat, 'consent.data_point_chat'.tr()),
                  if (support != null) support!,
                  const SizedBox(height: 6),
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LLink('consent.view_full_policy'.tr(),
                          key: const ValueKey('lantern-consent-policy'),
                          onTap: onViewPolicy)),
                  const SizedBox(height: 4),
                  LCheck(
                      key: const ValueKey('lantern-consent-check'),
                      value: agreed,
                      label: 'consent.checkbox_label'.tr(),
                      onChanged: (_) => onToggle()),
                ]),
            actions: [
              LButton(
                  key: const ValueKey('lantern-consent-decline'),
                  label: 'common.decline'.tr(),
                  kind: LButtonKind.ghost,
                  onPressed: onDecline),
              LButton(
                  key: const ValueKey('lantern-consent-accept'),
                  label: 'consent.accept_btn'.tr(),
                  onPressed: onAccept),
            ]);
      })));
}
