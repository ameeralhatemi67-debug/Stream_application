import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/admin/presentation/widgets/org_management_view.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';

class DirectJsonAssetLoader extends AssetLoader {
  final Map<String, dynamic> enData;
  final Map<String, dynamic> arData;

  const DirectJsonAssetLoader({required this.enData, required this.arData});

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return locale.languageCode == 'ar' ? arData : enData;
  }
}

late Map<String, dynamic> globalEnData;
late Map<String, dynamic> globalArData;

Widget createTestWidget({
  required Widget child,
  required AppProvider provider,
}) {
  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    path: 'assets/i18n',
    assetLoader: DirectJsonAssetLoader(
      enData: globalEnData,
      arData: globalArData,
    ),
    fallbackLocale: const Locale('en'),
    startLocale: const Locale('en'),
    saveLocale: false,
    useOnlyLangCode: true,
    child: Builder(
      builder: (context) {
        return ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: ThemeData.dark(useMaterial3: true).copyWith(
              scaffoldBackgroundColor: AppTheme.bg,
              cardColor: AppTheme.surface,
            ),
            home: Scaffold(body: child),
          ),
        );
      },
    ),
  );
}

Future<void> pumpTestApp(
    WidgetTester tester, Widget child, AppProvider provider) async {
  await tester.pumpWidget(createTestWidget(child: child, provider: provider));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    globalEnData = jsonDecode(await File('assets/i18n/en.json').readAsString());
    globalArData = jsonDecode(await File('assets/i18n/ar.json').readAsString());
    await EasyLocalization.ensureInitialized();
  });

  group('Phase 4: Go Live Studio & Organization Management Tests', () {
    late AppProvider provider;

    setUp(() async {
      final dbService = await AdminDatabaseService.create();
      provider = AppProvider(dbService);
      seedStreamerFixtures(provider);
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test('TC-ORG-GOLIVE-01: Deferred organization identity cannot be selected',
        () {
      expect(provider.selectedBroadcastOrgId, isNull);
      expect(provider.selectedVenueBranchId, isNull);
      expect(provider.selectedCoSpeakerIds, isEmpty);

      provider.setSelectedBroadcastOrgId('org_dalilk_04');
      expect(provider.selectedBroadcastOrgId, isNull);
      expect(provider.selectedVenueBranchId, isNull);
      expect(provider.selectedCoSpeakerIds, isEmpty);
      // Unrelated organization data remains available.
      expect(provider.getOrganizationVenues('org_dalilk_04'), hasLength(3));
      expect(provider.getOrganizationSpeakers('org_dalilk_04'), isNotEmpty);
    });

    test(
        'TC-ORG-GOLIVE-02: Org Live without a primary backend session is denied',
        () async {
      provider.setSelectedBroadcastOrgId('org_dalilk_04');
      provider.setSelectedVenueBranchId('dalilk_branch_dhahran');
      provider.setBroadcastType(BroadcastType.liveVideo);

      final initialLogsCount = provider.auditLogs.length;

      // Go live as organization
      await provider.toggleBroadcasterGoLive();
      expect(provider.isBroadcastingLive, isFalse);
      expect(provider.broadcastSessionError, 'broadcast_primary_required');

      final org = provider.getStreamerById('org_dalilk_04');
      expect(org, isNotNull);
      expect(provider.selectedVenueBranchId, 'dalilk_branch_dhahran');

      // Verify audit log for startLiveBroadcast
      expect(provider.auditLogs.length, equals(initialLogsCount));

      // End broadcast
      await provider.toggleBroadcasterGoLive();
      expect(provider.isBroadcastingLive, isFalse);
      expect(provider.auditLogs.length, equals(initialLogsCount));
    });

    test('Organization writes fail without a backend and preserve visible data', () async {
      final venues = provider.getOrganizationVenues('org_dalilk_04');
      final speakers = provider.getOrganizationSpeakers('org_dalilk_04');
      final audits = provider.auditLogs.length;
      await expectLater(provider.addOrganizationBranch('org_dalilk_04', venues.first), throwsException);
      await expectLater(provider.updateOrganizationBranch('org_dalilk_04', venues.first), throwsException);
      await expectLater(provider.deleteOrganizationBranch('org_dalilk_04', venues.first.venueId), throwsException);
      await expectLater(provider.addOrganizationSpeaker('org_dalilk_04', speakers.first), throwsException);
      await expectLater(provider.updateOrganizationSpeaker('org_dalilk_04', speakers.first), throwsException);
      await expectLater(provider.deleteOrganizationSpeaker('org_dalilk_04', speakers.first.speakerId), throwsException);
      await expectLater(provider.updateSpeakerPermissions('org_dalilk_04', speakers.first.speakerId,
          speakers.first.permissions.copyWith(canGoLiveVideo: true)), throwsStateError);
      expect(provider.getOrganizationVenues('org_dalilk_04'), venues);
      expect(provider.getOrganizationSpeakers('org_dalilk_04'), speakers);
      expect(provider.auditLogs.length, audits);
    });

    testWidgets(
        'TC-ORG-ADMIN-04: OrgManagementView widget renders tabs, branch cards, and speaker roster',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = await AdminDatabaseService.create();
      final freshProvider = AppProvider(db);
      seedStreamerFixtures(freshProvider);

      await pumpTestApp(
        tester,
        const OrgManagementView(orgId: 'org_dalilk_04'),
        freshProvider,
      );

      // Verify Header
      expect(find.textContaining('Dalilk 4 IELTS'), findsWidgets);
      expect(find.text('@dalilk4ielts'), findsOneWidget);

      // Verify Sub-Tabs
      expect(find.byIcon(Icons.apartment_rounded), findsWidgets);
      expect(find.byIcon(Icons.groups_rounded), findsWidgets);
      expect(find.byIcon(Icons.history_edu_rounded), findsWidgets);

      // Sub-Section 0 (Branches) is open by default
      expect(find.text('Khobar Academic Campus (Main HQ)'), findsOneWidget);
      expect(find.text('Dhahran Tech Innovation Hall'), findsOneWidget);

      // Switch to Sub-Section 1 (Speakers)
      await tester.tap(find.byIcon(Icons.groups_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Abdulrahman Hejazi'), findsOneWidget);
      expect(find.text('Dr. Sarah Al-Dosari'), findsOneWidget);
      expect(find.text('Alex Thompson'), findsOneWidget);

      // Switch to Sub-Section 2 (Audit Trail)
      await tester.tap(find.byIcon(Icons.history_edu_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget); // Search bar
    });

    testWidgets(
        'TC-ORG-ADMIN-05: showAuditTrail=false hides the Audit Trail tab (Permitted Admin surface, v0.8 Checkpoint 3)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = await AdminDatabaseService.create();
      final freshProvider = AppProvider(db);
      seedStreamerFixtures(freshProvider);

      await pumpTestApp(
        tester,
        const OrgManagementView(orgId: 'org_dalilk_04', showAuditTrail: false),
        freshProvider,
      );

      // Header and other sub-tabs still render...
      expect(find.textContaining('Dalilk 4 IELTS'), findsWidgets);
      expect(find.byIcon(Icons.apartment_rounded), findsWidgets);
      expect(find.byIcon(Icons.groups_rounded), findsWidgets);

      // ...but Audit Trail (admin-tier-only at the RLS layer) is gone, since
      // audit_logs would just be empty for a Permitted Admin viewer anyway.
      expect(find.byIcon(Icons.history_edu_rounded), findsNothing);
    });
  });
}
