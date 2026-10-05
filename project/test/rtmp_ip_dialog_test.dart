import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/widgets/language_switcher.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'support/empty_broadcasts.dart';
import 'support/localized_app.dart';

// Manual watch-link/key entry was replaced by confirmed backend destinations.
// Provider confirmation, retry identity and device fencing live in
// broadcaster_studio_entry_test.dart; these checks cover the sheet itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  for (final language in ['en', 'ar']) {
    testWidgets(
        'studio $language preserves its draft across language changes at 2x',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = AppProvider.withServices(
          organizationBroadcastService: EmptyBroadcasts());
      await tester.pumpWidget(ChangeNotifierProvider.value(
          value: provider,
          child: localizedApp(
              home: Builder(
                  builder: (context) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(textScaler: const TextScaler.linear(2)),
                      child: const Scaffold(
                          body: LiveBroadcasterStudioSheet()))))));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(LiveBroadcasterStudioSheet));
      await context.setLocale(Locale(language));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Keep this draft');
      final toggle = find.byType(LanguageSwitcher);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.text('Keep this draft'), findsOneWidget);
      expect(find.text('design_copy.video'.tr()), findsWidgets);
      expect(find.text('design_ui.video'), findsNothing);
      expect(find.byType(TextFormField), findsOneWidget,
          reason: 'Only the existing show-title form field');
      expect(find.byType(TextField), findsOneWidget,
          reason: 'No additional raw manual ingest credential fields');
      // Without a connected channel the studio offers Connect, not Prepare.
      expect(find.text('organization_v1.prepare'.tr()), findsNothing);
      final connect = find.ancestor(
          of: find.text('organization_v1.connect'.tr()),
          matching: find.byType(CaButton));
      expect(tester.widget<CaButton>(connect).onPressed, isNotNull);
      expect(provider.phoneBroadcastStreamKey, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  }
  testWidgets('local mode cannot prepare a broadcast', (tester) async {
    final provider = AppProvider.withServices(
        organizationBroadcastService: EmptyBroadcasts());
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: provider,
        child: localizedApp(
            home: const Scaffold(
                body: LiveBroadcasterStudioSheet(
                    initialMode: StudioMode.local)))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('local-unavailable')), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(provider.isBroadcastingLive, isFalse);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
