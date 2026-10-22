import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/admin/models/admin_role_assignment_model.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';
import 'package:streamer_app/features/admin/presentation/widgets/role_permission_management_view.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';

import 'support/localized_app.dart';

/// Roles & Permissions (2026-10-22): lessons-only admins, and email
/// addresses that become admins at their first sign-in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, AppProvider provider) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
            builder: (context) => MaterialApp(
                  theme: AppTheme.forLocale(context.locale),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  home: const Scaffold(body: RolePermissionManagementView()),
                )),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('lessons admins and admin emails have their own sections',
      (tester) async {
    final provider = AppProvider()
      ..debugSetRoleDataForTests(assignments: [
        AdminRoleAssignmentModel(
            profileId: 'p1',
            role: 'lessons_admin',
            grantedAt: DateTime(2026, 10, 22),
            displayName: 'Lessons Person',
            email: 'lessons@example.com'),
      ], emailGrants: [
        AdminEmailGrant(
            email: 'waiting@example.com',
            role: 'admin',
            createdAt: DateTime(2026, 10, 22)),
        AdminEmailGrant(
            email: 'joined@example.com',
            role: 'admin',
            createdAt: DateTime(2026, 10, 20),
            appliedAt: DateTime(2026, 10, 21)),
      ]);
    await pump(tester, provider);

    expect(find.text('roles.lessons_admins'.tr()), findsOneWidget);
    expect(find.text('Lessons Person'), findsOneWidget);
    expect(find.text('roles.lessons_admin'.tr()), findsWidgets);

    final emails = find.byKey(const ValueKey('roles-admin-emails'));
    expect(find.descendant(of: emails, matching: find.text('waiting@example.com')),
        findsOneWidget);
    expect(
        find.descendant(
            of: emails,
            matching: find.textContaining('roles.email_waiting'.tr())),
        findsOneWidget);
    expect(
        find.descendant(
            of: emails,
            matching: find.textContaining(
                'roles.email_applied'.tr(args: ['2026-10-21']))),
        findsOneWidget);

    // The grant menu offers admin by email and the lessons admin role.
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('roles.admin_by_email'.tr()), findsWidgets);
    expect(find.text('roles.lessons_admin'.tr()), findsWidgets);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  // The admin page has two areas (2026-10-22): the platform, and preachers
  // and lessons. The hub's navigation starts with the switch between them.
  testWidgets('the admin hub switches to Preachers & lessons', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(email: 'admin@example.invalid', isAdmin: true);
    final lessons = LessonsController(DemoLessonsRepository(persona: LessonsDemoPersona.admin));
    await lessons.ensureLoaded();
    final router = GoRouter(initialLocation: '/admin', routes: [
      GoRoute(path: '/admin', builder: (_, __) => const AdminHubScreen()),
      GoRoute(path: '/admin/lessons', builder: (_, __) => const Scaffold(body: Text('lessons area'))),
    ]);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppProvider>.value(value: provider),
          ChangeNotifierProvider<LessonsController>.value(value: lessons),
        ],
        child: Builder(
            builder: (context) => MaterialApp.router(
                  routerConfig: router,
                  theme: AppTheme.forLocale(context.locale),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                )),
      ),
    ));
    await tester.pumpAndSettle();
    final lessonsArea = find.byKey(const ValueKey('admin-area-lessons'));
    expect(lessonsArea, findsOneWidget);
    // What waits in the other area is counted on the switch.
    expect(find.descendant(of: lessonsArea, matching: find.text('${lessons.waitingCount}')), findsOneWidget);
    await tester.tap(lessonsArea);
    await tester.pumpAndSettle();
    expect(find.text('lessons area'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    lessons.dispose();
    provider.dispose();
  });
}
