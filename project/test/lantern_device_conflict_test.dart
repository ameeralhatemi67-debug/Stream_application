import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/core/widgets/device_session_conflict_dialog.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/core/widgets/lantern/lantern_device_conflict.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// "Logged in on several devices" in Lantern and Arch (owner notes
/// 2026-11-12): its own dialog, devices named by kind in the person's
/// language, the same two choices.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  DeviceSessionModel device(String platform, {bool primary = false}) =>
      DeviceSessionModel(
          deviceId: platform,
          deviceName: '$platform Device',
          platform: platform,
          isPrimaryBroadcaster: primary,
          lastActiveAt: DateTime(2026, 11, 12));

  for (final lang in ['ar', 'en']) {
    for (final (choice, key, expected) in [
      (
        'move',
        'lantern-device-move',
        DeviceSessionChoice.transferBroadcaster
      ),
      ('watch', 'lantern-device-watch', DeviceSessionChoice.continueAsViewer),
    ]) {
      testWidgets('Lantern draws its own dialog; $choice ($lang)',
          (tester) async {
        DeviceSessionChoice? picked;
        var done = false;
        await pumpLanternWidget(
            tester,
            Builder(
                builder: (context) => Scaffold(
                    body: Center(
                        child: LButton(
                            label: 'open',
                            onPressed: () async {
                              picked = await DeviceSessionConflictDialog.show(
                                  context: context,
                                  currentDevice: device('android'),
                                  existingDevice:
                                      device('web', primary: true));
                              done = true;
                            })))),
            lang: lang);
        await tester.tap(find.text('open'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(LanternDeviceConflictBody), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('lantern.device.title'.tr()), findsOneWidget);
        // Named by kind, never "android Device (This Device)".
        expect(find.text('lantern.device.android'.tr()), findsOneWidget);
        expect(find.text('lantern.device.web'.tr()), findsOneWidget);
        expect(find.textContaining('(This Device)'), findsNothing);
        // No close button: a choice is needed.
        expect(
            find.byWidgetPredicate(
                (w) => w is LIconButton && w.icon == LGlyph.close),
            findsNothing);
        await tester.tap(find.byKey(ValueKey(key)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(done, isTrue);
        expect(picked, expected);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
