import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../models/device_session_model.dart';
import 'lantern.dart';

/// What the person chose in the device dialog.
enum LanternDeviceChoice { moveHere, watch }

/// Lantern and Arch: the account broadcasts from another device. A picture
/// of the move (that device to this one), the two devices by kind, then Move
/// broadcasting here (with what it does to the other device) and Keep
/// watching. It cannot be dismissed without a choice.
Future<LanternDeviceChoice?> showLanternDeviceConflict(BuildContext context,
        {required DeviceSessionModel current,
        required DeviceSessionModel holder}) =>
    showLanternDialog<LanternDeviceChoice>(context,
        title: 'lantern.device.title'.tr(),
        dismissible: false,
        maxWidth: 440,
        body: (dialog) => LanternDeviceConflictBody(
            current: current,
            holder: holder,
            onChoice: (choice) => Navigator.of(dialog).pop(choice)));

class LanternDeviceConflictBody extends StatelessWidget
    implements LanternSkinWidget {
  const LanternDeviceConflictBody(
      {super.key,
      required this.current,
      required this.holder,
      required this.onChoice});

  final DeviceSessionModel current, holder;
  final ValueChanged<LanternDeviceChoice> onChoice;

  static LGlyph glyphOf(String platform) => switch (platform.toLowerCase()) {
        'android' || 'ios' => LGlyph.phone,
        'windows' || 'macos' || 'linux' => LGlyph.grid,
        _ => LGlyph.globe,
      };

  static String nameOf(String platform) =>
      switch (platform.toLowerCase()) {
        'android' => 'lantern.device.android',
        'ios' => 'lantern.device.ios',
        'web' => 'lantern.device.web',
        'windows' => 'lantern.device.windows',
        'macos' => 'lantern.device.macos',
        'linux' => 'lantern.device.linux',
        _ => 'lantern.device.other',
      }
          .tr();

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget disc(LGlyph glyph, {required bool here}) => Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: here ? Lantern.goldFill : null,
            color: here ? null : t.sunk,
            border: here ? null : Border.all(color: t.line),
            boxShadow: here ? t.shadow : null),
        child: LIcon(glyph,
            size: 26, color: here ? LanternTokens.onGold : t.muted));
    Widget device(DeviceSessionModel d,
            {required bool here, required Widget tag}) =>
        Container(
            key: ValueKey(here
                ? 'lantern-device-this'
                : 'lantern-device-holder'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: here ? t.surface : t.sunk,
                borderRadius: BorderRadius.circular(Lantern.radiusRow),
                border: Border.all(
                    color: here ? LanternTokens.gold : t.line2,
                    width: here ? 1.5 : 1)),
            child: Row(children: [
              Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: here ? t.sunk : t.surface,
                      borderRadius: BorderRadius.circular(Lantern.radiusTile)),
                  child: LIcon(glyphOf(d.platform),
                      size: 20, color: here ? t.goldInk : t.muted)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(nameOf(d.platform),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Lantern.textStyle(14.5,
                          color: t.fg, weight: FontWeight.w600, height: 1.35))),
              const SizedBox(width: 8),
              tag,
            ]));
    return Column(
        key: const ValueKey('lantern-device-conflict'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            disc(glyphOf(holder.platform), here: false),
            const SizedBox(width: 14),
            LIcon(LGlyph.arrow, size: 22, color: t.goldInk),
            const SizedBox(width: 14),
            disc(glyphOf(current.platform), here: true),
          ])),
          const SizedBox(height: 16),
          Text('lantern.device.body'.tr(),
              style: Lantern.textStyle(14.5, color: t.muted, height: 1.55)),
          const SizedBox(height: 16),
          device(holder,
              here: false,
              tag: LTag('lantern.device.holder'.tr(),
                  tone: LTone.live, icon: LGlyph.live)),
          const SizedBox(height: 8),
          device(current,
              here: true,
              tag: LTag('lantern.device.this_device'.tr(),
                  tone: LTone.gold, icon: LGlyph.check)),
          const SizedBox(height: 22),
          LButton(
              key: const ValueKey('lantern-device-move'),
              label: 'design_ui.transfer_broadcaster_to_this_device'.tr(),
              icon: LGlyph.mic,
              expand: true,
              onPressed: () => onChoice(LanternDeviceChoice.moveHere)),
          const SizedBox(height: 6),
          Text('lantern.device.move_hint'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.textStyle(12.5, color: t.muted, height: 1.4)),
          const SizedBox(height: 12),
          LButton(
              key: const ValueKey('lantern-device-watch'),
              label: 'design_ui.continue_as_viewer'.tr(),
              icon: LGlyph.eye,
              kind: LButtonKind.secondary,
              expand: true,
              onPressed: () => onChoice(LanternDeviceChoice.watch)),
        ]);
  }
}
