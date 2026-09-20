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
import 'package:streamer_app/features/organization/models/org_venue_branch_model.dart';
import 'package:streamer_app/features/organization/models/org_speaker_model.dart';
import 'package:streamer_app/features/organization/models/org_audit_log_entry.dart';
import 'package:streamer_app/features/organization/models/org_broadcaster_permissions.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

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
              scaffoldBackgroundColor: AppTheme.darkBgBase,
              cardColor: AppTheme.darkSurface1,
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
      await Future.delayed(const Duration(milliseconds: 50));
    });

    test(
        'TC-ORG-GOLIVE-01: Broadcast identity and branch selection state updates correctly',
        () {
      expect(provider.selectedBroadcastOrgId, isNull);
      expect(provider.selectedVenueBranchId, isNull);
      expect(provider.selectedCoSpeakerIds, isEmpty);

      // Select Dalilk 4 IELTS organization
      provider.setSelectedBroadcastOrgId('org_dalilk_04');
      expect(provider.selectedBroadcastOrgId, equals('org_dalilk_04'));
      expect(provider.selectedVenueBranchId, equals('dalilk_hq_khobar'));
      expect(provider.selectedCoSpeakerIds, contains('spk_abdulrahman'));

      // Switch to Dhahran Campus branch
      provider.setSelectedVenueBranchId('dalilk_branch_dhahran');
      expect(provider.selectedVenueBranchId, equals('dalilk_branch_dhahran'));

      // Toggle additional co-speakers
      provider.toggleCoSpeaker('spk_sarah');
      expect(provider.selectedCoSpeakerIds,
          containsAll(['spk_abdulrahman', 'spk_sarah']));

      // Toggle off
      provider.toggleCoSpeaker('spk_abdulrahman');
      expect(provider.selectedCoSpeakerIds, equals(['spk_sarah']));
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

    test(
        'TC-ORG-ADMIN-01: Branch CRUD operations update organization venues and audit trail',
        () async {
      final initialBranches = provider.getOrganizationVenues('org_dalilk_04');
      expect(initialBranches.length, equals(3));

      // 1. Add new branch
      const newBranch = OrgVenueBranchModel(
        venueId: 'branch_jubail_04',
        nameEn: 'Jubail Industrial Center',
        nameAr: 'مركز الجبيل الصناعي',
        cityEn: 'Jubail',
        cityAr: 'الجبيل',
        latitude: 27.0046,
        longitude: 49.6591,
        seatingCapacity: 75,
        availableFacilities: ['Interactive Lab', 'High-Speed Wi-Fi'],
      );

      await provider.addOrganizationBranch('org_dalilk_04', newBranch);
      final branchesAfterAdd = provider.getOrganizationVenues('org_dalilk_04');
      expect(branchesAfterAdd.length, equals(4));
      expect(
          branchesAfterAdd.any((b) => b.venueId == 'branch_jubail_04'), isTrue);
      expect(provider.auditLogs.first.action,
          equals(OrgAuditAction.addVenueBranch));

      // 2. Update branch
      final updatedBranch = newBranch.copyWith(seatingCapacity: 150);
      await provider.updateOrganizationBranch('org_dalilk_04', updatedBranch);
      final branchesAfterUpd = provider.getOrganizationVenues('org_dalilk_04');
      expect(
          branchesAfterUpd
              .firstWhere((b) => b.venueId == 'branch_jubail_04')
              .seatingCapacity,
          equals(150));
      expect(provider.auditLogs.first.action,
          equals(OrgAuditAction.updateVenueBranch));

      // 3. Delete branch
      await provider.deleteOrganizationBranch(
          'org_dalilk_04', 'branch_jubail_04');
      final branchesAfterDel = provider.getOrganizationVenues('org_dalilk_04');
      expect(branchesAfterDel.length, equals(3));
      expect(branchesAfterDel.any((b) => b.venueId == 'branch_jubail_04'),
          isFalse);
      expect(provider.auditLogs.first.action,
          equals(OrgAuditAction.removeVenueBranch));
    });

    test(
        'TC-ORG-ADMIN-02: Speaker CRUD operations update organization roster and audit trail',
        () async {
      final initialSpeakers = provider.getOrganizationSpeakers('org_dalilk_04');
      expect(initialSpeakers.length, equals(3));

      // 1. Add speaker
      const newSpeaker = OrgSpeakerModel(
        speakerId: 'spk_nasser_04',
        nameEn: 'Dr. Nasser Al-Qahtani',
        nameAr: 'د. ناصر القحطاني',
        roleOrTitleEn: 'Advanced Writing Specialist',
        roleOrTitleAr: 'أخصائي الكتابة المتقدمة',
        avatarUrl: 'assets/images/Dalilak/profile1.jpg',
        bioEn: 'IELTS Writing Task 2 mentor.',
        bioAr: 'مدرب مهام الكتابة المتقدمة لاختبار الآيلتس.',
        isPermanentStaff: false,
        permissions: OrgBroadcasterPermissions(
          canGoLiveVideo: true,
          canGoAudioOnly: true,
        ),
      );

      await provider.addOrganizationSpeaker('org_dalilk_04', newSpeaker);
      final speakersAfterAdd =
          provider.getOrganizationSpeakers('org_dalilk_04');
      expect(speakersAfterAdd.length, equals(4));
      expect(
          speakersAfterAdd.any((s) => s.speakerId == 'spk_nasser_04'), isTrue);
      expect(provider.auditLogs.first.action,
          equals(OrgAuditAction.addSpeakerToRoster));

      // 2. Update speaker
      final updatedSpeaker =
          newSpeaker.copyWith(roleOrTitleEn: 'Head of IELTS Writing');
      await provider.updateOrganizationSpeaker('org_dalilk_04', updatedSpeaker);
      final speakersAfterUpd =
          provider.getOrganizationSpeakers('org_dalilk_04');
      expect(
          speakersAfterUpd
              .firstWhere((s) => s.speakerId == 'spk_nasser_04')
              .roleOrTitleEn,
          equals('Head of IELTS Writing'));
      expect(provider.auditLogs.first.action,
          equals(OrgAuditAction.updateSpeakerDetails));

      // 3. Delete speaker
      await provider.deleteOrganizationSpeaker(
          'org_dalilk_04', 'spk_nasser_04');
      final speakersAfterDel =
          provider.getOrganizationSpeakers('org_dalilk_04');
      expect(speakersAfterDel.length, equals(3));
      expect(
          speakersAfterDel.any((s) => s.speakerId == 'spk_nasser_04'), isFalse);
      expect(provider.auditLogs.first.action,
          equals(OrgAuditAction.removeSpeakerFromRoster));
    });

    test(
        'TC-ORG-ADMIN-03: RBAC permission adjustment updates speaker permissions and records audit entry',
        () async {
      final speaker = provider.getOrganizationSpeakers('org_dalilk_04').first;
      expect(speaker.permissions.canChangeLocation, isFalse);

      // Grant location change permission
      final updatedPerms =
          speaker.permissions.copyWith(canChangeLocation: true);
      await provider.updateSpeakerPermissions(
          'org_dalilk_04', speaker.speakerId, updatedPerms);

      final updatedSpeaker = provider
          .getOrganizationSpeakers('org_dalilk_04')
          .firstWhere((s) => s.speakerId == speaker.speakerId);
      expect(updatedSpeaker.permissions.canChangeLocation, isTrue);

      final auditLog = provider.auditLogs.first;
      expect(auditLog.action, equals(OrgAuditAction.grantBroadcastPermission));
      expect(auditLog.organizationId, equals('org_dalilk_04'));
      expect(auditLog.descriptionEn, contains(speaker.nameEn));
    });

    testWidgets(
        'TC-ORG-ADMIN-04: OrgManagementView widget renders tabs, branch cards, and speaker roster',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final db = await AdminDatabaseService.create();
      final freshProvider = AppProvider(db);

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
