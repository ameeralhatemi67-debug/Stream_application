import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';
import 'package:streamer_app/features/admin/models/admin_role_assignment_model.dart';
import 'package:streamer_app/features/admin/models/chat_report_model.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';
import 'fixtures/streamer_fixtures.dart';
import 'fixtures/admin_applications.dart';
import 'support/fixture_application_db.dart';

late Map<String, dynamic> en, ar;

class DirectJsonAssetLoader extends AssetLoader {
  const DirectJsonAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      locale.languageCode == 'ar' ? ar : en;
}

class PopulatedAdmin extends AppProvider {
  PopulatedAdmin() : super(FixtureApplicationDb());
  @override
  List<AdminRoleAssignmentModel> get roleAssignments => [
        AdminRoleAssignmentModel(
            profileId: 'a',
            role: 'admin',
            grantedAt: DateTime(2026),
            displayName: 'مشرف تجريبي طويل الاسم',
            email: 'admin@example.invalid'),
        AdminRoleAssignmentModel(
            profileId: 'b',
            role: 'org_co_owner',
            grantedAt: DateTime(2026),
            displayName: 'مالك المؤسسة التعليمية التجريبية'),
      ];
  @override
  List<ChatReportModel> get chatReports => [
        ChatReportModel(
            id: 'r',
            messageId: 'm',
            streamId: 'test-room',
            reportedSenderId: 'a',
            reporterId: 'b',
            reason: 'spam',
            createdAt: DateTime(2026),
            messageBody: 'رسالة للاختبار',
            reporterDisplayName: 'المبلّغ التجريبي',
            reportedDisplayName: 'المرسل التجريبي')
      ];
}

Widget harness(AppProvider p, String lang, Widget screen) => EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    path: 'assets/i18n',
    assetLoader: const DirectJsonAssetLoader(),
    startLocale: Locale(lang),
    saveLocale: false,
    child: ChangeNotifierProvider<AppProvider>.value(
        value: p,
        child: Builder(
            builder: (context) => MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                theme: AppTheme.forLocale(context.locale),
                home: screen))));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    en = jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    ar = jsonDecode(File('assets/i18n/ar.json').readAsStringSync());
    await EasyLocalization.ensureInitialized();
  });
  for (final lang in ['en', 'ar']) {
    for (final width in [360.0, 390.0]) {
      testWidgets('populated admin phone layouts $width $lang', (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = PopulatedAdmin();
        p.debugSetSignedInForTests(
            email: 'admin@example.invalid', isMasterAdmin: true);
        seedStreamerFixtures(p);
        for (final a in sampleBroadcasterApplications()) {
          await p.submitBroadcasterApplication(a);
        }
        await tester.pumpWidget(harness(p, lang, const AdminHubScreen()));
        await tester.pumpAndSettle();
        for (final tab in [
          'verification',
          'streamers',
          'terms',
          'categories',
          'roles',
          'chat_moderation'
        ]) {
          tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
          await tester.pumpAndSettle();
          final entry = find.byKey(ValueKey('admin.tab_$tab'));
          await tester.scrollUntilVisible(entry, 200,
              scrollable: find
                  .descendant(
                      of: find.byKey(const ValueKey('admin-navigation')),
                      matching: find.byType(Scrollable))
                  .first);
          await tester.pumpAndSettle();
          await tester.tap(entry);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$tab at $width $lang');
        }
        await tester.pumpWidget(const SizedBox());
        p.dispose();
      });
    }
    testWidgets('phone chat with keyboard remains usable and offline $lang',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const permissions =
          MethodChannel('flutter.baseflow.com/permissions/methods');
      const rtmp = MethodChannel('streamer_app/rtmp_publisher');
      const events = EventChannel('streamer_app/rtmp_publisher/events');
      messenger.setMockMethodCallHandler(
          permissions,
          (call) async =>
              call.method == 'requestPermissions' ? <int, int>{17: 1} : 1);
      messenger.setMockMethodCallHandler(rtmp, (call) async => null);
      messenger.setMockMessageHandler(
          events.name, (_) async => events.codec.encodeSuccessEnvelope(null));
      final p = AppProvider(AdminDatabaseService(null));
      p.debugSetSignedInForTests(email: 'phone@example.invalid');
      await tester.pumpWidget(harness(
          p,
          lang,
          const PhoneBroadcastScreen(
              quickLaunchPreset: BroadcastQualityPreset.medium)));
      await tester.pumpAndSettle();
      expect(
          find.text(lang == 'en' ? 'Not live' : 'غير مباشر'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'landscape $lang');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'keyboard $lang');
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      p.dispose();
      messenger.setMockMethodCallHandler(permissions, null);
      messenger.setMockMethodCallHandler(rtmp, null);
      messenger.setMockMessageHandler(events.name, null);
    });
  }
}
