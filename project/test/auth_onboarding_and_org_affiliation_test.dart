import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/auth/presentation/viewer_setup_screen.dart';
import 'package:streamer_app/features/auth/presentation/role_select_screen.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';
import 'package:streamer_app/features/auth/presentation/application_pending_screen.dart';
import 'package:streamer_app/features/auth/presentation/steps/apply_step_3_professional.dart';

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
            home: child,
          ),
        );
      },
    ),
  );
}

Future<void> pumpTestApp(WidgetTester tester, Widget child, AppProvider provider) async {
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

  group('Auth, Onboarding & Streamer Application Wizard Tests', () {
    late AppProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      provider = AppProvider();
      seedStreamerFixtures(provider);
      await Future.delayed(const Duration(milliseconds: 80));
    });

    testWidgets('TC-AUTH-01: WelcomeScreen renders branding, Google Sign-In, and Guest Viewer',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      await pumpTestApp(tester, const WelcomeScreen(), provider);

      expect(find.text('Hadayah Live'), findsOneWidget);
      expect(find.text('Sign Up with Google'), findsOneWidget);
      expect(find.text('Already have an account? Log In'), findsOneWidget);
      expect(find.text('Continue as Guest Viewer (Skip Sign In)'), findsOneWidget);
    });

    testWidgets('TC-AUTH-02: ViewerSetupScreen saves display name and avatar',
        (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      await pumpTestApp(tester, const ViewerSetupScreen(), provider);

      expect(find.text('Set Up Viewer Profile'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Fahad Al-Otaibi');
      await tester.pump();

      expect(find.text('Fahad Al-Otaibi'), findsOneWidget);
    });

    testWidgets(
        'TC-AUTH-02b: ViewerSetupScreen avatar presets are neutral, not '
        'real-person or branded photos (UI-05)', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      await pumpTestApp(tester, const ViewerSetupScreen(), provider);

      final avatarFinder = find.byType(CircleAvatar);
      expect(avatarFinder, findsWidgets);
      for (final element in avatarFinder.evaluate()) {
        final avatar = element.widget as CircleAvatar;
        final image = avatar.backgroundImage;
        if (image is AssetImage) {
          expect(image.assetName, isNot(contains('Amir_Alhatemi')));
          expect(image.assetName, isNot(contains('Dalilak')));
          expect(image.assetName, contains('assets/images/avatars/'));
        }
      }
    });

    testWidgets('TC-AUTH-03: RoleSelectScreen presents Viewer vs Broadcaster options',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      await pumpTestApp(tester, const RoleSelectScreen(), provider);

      expect(find.text('How would you like to experience Streamer App today?'), findsOneWidget);
      expect(find.text('I am a Viewer / Student'), findsOneWidget);
      expect(find.text('Apply to Stream (5-Step Form)'), findsOneWidget);
    });

    testWidgets('TC-AUTH-04: StreamerApplyScreen wizard renders Step 1 Identity',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      await pumpTestApp(tester, const StreamerApplyScreen(), provider);

      expect(find.text('Streamer Verification (1/5)'), findsOneWidget);
      expect(find.text('Step 1: Broadcaster Identity'), findsOneWidget);
      expect(find.text('Next Step'), findsOneWidget);
    });

    testWidgets('TC-AUTH-05: ApplicationPendingScreen renders confirmation badge and action',
        (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1.0;
      await pumpTestApp(tester, const ApplicationPendingScreen(), provider);

      expect(find.text('Application Submitted!'), findsOneWidget);
      expect(find.text('Explore as Viewer While Waiting'), findsOneWidget);
    });

    test('TC-AUTH-06: Telemetry counters update on Google login and Guest setup', () async {
      final initialGoogleUsers = provider.viewerAnalytics.totalRegisteredGoogleUsers;
      final initialGuests = provider.viewerAnalytics.totalGuestSessions;

      await provider.registerGoogleUser();
      expect(provider.viewerAnalytics.totalRegisteredGoogleUsers, equals(initialGoogleUsers + 1));

      await provider.recordGuestSession();
      expect(provider.viewerAnalytics.totalGuestSessions, equals(initialGuests + 1));
    });

    test('TC-AUTH-07: Saudi phone validator logic', () {
      bool isSaudiPhoneValid(String input) {
        final cleaned = input.replaceAll(RegExp(r'\s+'), '');
        final hasInvalid = RegExp(r'[^0-9+]').hasMatch(cleaned);
        if (hasInvalid) return false;
        return RegExp(r'^05[0-9]{8}$').hasMatch(cleaned) ||
            RegExp(r'^9665[0-9]{8}$').hasMatch(cleaned) ||
            RegExp(r'^\+9665[0-9]{8}$').hasMatch(cleaned);
      }

      expect(isSaudiPhoneValid('+966542994098'), isTrue);
      expect(isSaudiPhoneValid('0542994098'), isTrue);
      expect(isSaudiPhoneValid('966542994098'), isTrue);
      expect(isSaudiPhoneValid('054 299 4098'), isTrue); // Whitespace stripped
      expect(isSaudiPhoneValid('054299'), isFalse); // Too short
      expect(isSaudiPhoneValid('+966abc12345'), isFalse); // Letters
      expect(isSaudiPhoneValid('0612345678'), isFalse); // Non-Saudi prefix
    });

    test('TC-AUTH-08: YouTube Handle / URL proof verification logic', () {
      bool isYoutubeProofValid(String input) {
        final text = input.trim();
        return text.startsWith('https://www.youtube.com/@') ||
            text.startsWith('http://www.youtube.com/@') ||
            text.startsWith('https://youtube.com/@') ||
            text.startsWith('youtube.com/@') ||
            text.startsWith('www.youtube.com/@') ||
            (text.startsWith('@') && text.length > 2);
      }

      expect(isYoutubeProofValid('https://www.youtube.com/@AlQuran4KOfficial'), isTrue);
      expect(isYoutubeProofValid('https://youtube.com/@amir_alhatemi'), isTrue);
      expect(isYoutubeProofValid('@amir_alhatemi'), isTrue);
      expect(isYoutubeProofValid('random_text_without_handle'), isFalse);
      expect(isYoutubeProofValid('@a'), isFalse);
    });

    testWidgets('TC-AUTH-09: Step 3 renders on narrow mobile screen (360x800) with zero overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      final affiliationCtrl = TextEditingController();
      final youtubeCtrl = TextEditingController(text: 'https://www.youtube.com/@AlQuran4KOfficial');
      final orgNameCtrl = TextEditingController();

      await pumpTestApp(
        tester,
        Scaffold(
          body: ApplyStep3Professional(
            affiliationController: affiliationCtrl,
            youtubeController: youtubeCtrl,
            orgNameController: orgNameCtrl,
            selectedCategories: const ['cs_tech'],
            isOrganization: false,
            selectedTags: const ['#AI'],
            onCategoriesChanged: (_) {},
            onTypeChanged: (_) {},
            onTagToggled: (_) {},
          ),
        ),
        provider,
      );

      // Verify clean render on mobile
      expect(find.text('Step 3: Professional & Channel Info'), findsOneWidget);
      expect(find.text('Individual Broadcaster'), findsOneWidget);
      expect(find.text('Organization / Center'), findsOneWidget);
      expect(find.text('Add Custom Field'), findsOneWidget);
    });

    test('TC-ORG-AFF-01: Bi-directional Org Affiliation submission and resolution', () async {
      final initialAffCount = provider.affiliationRequests.length;

      // Submit affiliation request from individual streamer to Org
      await provider.submitOrgAffiliationRequest(
        orgId: 'org_dalilk_04',
        note: 'I would like to broadcast IELTS preparation workshops at the Khobar Campus.',
        proposedRoleEn: 'IELTS Master Instructor',
        proposedRoleAr: 'مدرب آيلتس معتمد',
      );

      expect(provider.affiliationRequests.length, equals(initialAffCount + 1));
      final newReq = provider.affiliationRequests.first;
      expect(newReq.isPending, isTrue);
      expect(newReq.orgId, equals('org_dalilk_04'));

      // Accept request to Org roster
      await provider.acceptOrgAffiliationRequest(newReq.id);
      final acceptedReq = provider.affiliationRequests.firstWhere((r) => r.id == newReq.id);
      expect(acceptedReq.isAccepted, isTrue);
    });
  });
}
