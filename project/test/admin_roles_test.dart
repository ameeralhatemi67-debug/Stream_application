import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/admin/models/admin_role_assignment_model.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';
import 'package:streamer_app/features/admin/presentation/widgets/admin_area_switch.dart';
import 'package:streamer_app/features/admin/presentation/widgets/role_permission_management_view.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';

import 'support/localized_app.dart';

/// What the screen sends, without a backend.
class RecordingProvider extends AppProvider {
  final calls = <String>[];
  bool accountExists = true;

  @override
  Future<bool> setAdminAccess(String email, String access) async {
    calls.add('$email=$access');
    return accountExists;
  }

  @override
  Future<void> removeAdminEmail(String email) async => calls.add('remove $email');

  @override
  Future<void> refreshAdminEmailGrants() async {}
}

/// Admin access (2026-11-01): one line per email, opening both admin pages,
/// one of them, or everything as a master admin, and changed from this screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final owner = AdminEmailGrant(
      email: 'owner@example.com',
      access: 'master',
      locked: true,
      createdAt: DateTime(2026, 10, 1),
      appliedAt: DateTime(2026, 10, 2),
      profileId: 'p0',
      displayName: 'The Owner');
  final waiting = AdminEmailGrant(
      email: 'waiting@example.com',
      access: 'lessons',
      createdAt: DateTime(2026, 10, 22));
  final joined = AdminEmailGrant(
      email: 'joined@example.com',
      access: 'both',
      createdAt: DateTime(2026, 10, 20),
      appliedAt: DateTime(2026, 10, 21),
      profileId: 'p1',
      displayName: 'Joined Person');

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

  Finder inLine(String email, Finder finder) => find.descendant(
      of: find.byKey(ValueKey('roles-access-$email')), matching: finder);

  testWidgets('each email has one line with its access and state', (tester) async {
    final provider = AppProvider()
      ..debugSetRoleDataForTests(emailGrants: [owner, joined, waiting]);
    await pump(tester, provider);

    expect(find.text('Joined Person'), findsOneWidget);
    expect(inLine('waiting@example.com', find.textContaining('roles.email_waiting'.tr())),
        findsOneWidget);
    expect(
        inLine('joined@example.com',
            find.textContaining('roles.email_applied'.tr(args: ['2026-10-21']))),
        findsOneWidget);
    final both = tester.widget<DropdownButton<String>>(
        find.byKey(const ValueKey('roles-access-menu-joined@example.com')));
    expect(both.value, 'both');
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('roles-access-menu-waiting@example.com')))
            .value,
        'lessons');
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('adding an email sends the access chosen', (tester) async {
    final provider = RecordingProvider()..debugSetRoleDataForTests();
    await pump(tester, provider);
    expect(find.text('roles.no_emails'.tr()), findsOneWidget);

    // All four choices are on offer.
    await tester.tap(find.byKey(const ValueKey('roles-add-access')));
    await tester.pumpAndSettle();
    for (final access in kAdminAccessLevels) {
      expect(find.text('roles.access_$access'.tr()), findsWidgets);
    }
    await tester.tap(find.text('roles.access_lessons'.tr()).last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), ' new@example.com ');
    await tester.tap(find.text('roles.add_button'.tr()));
    await tester.pump();
    expect(provider.calls, ['new@example.com=lessons']);
    expect(find.text('roles.access_saved'.tr()), findsOneWidget);
    // The toast's timer starts once it has slid in.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    // An address with no account yet waits for its first sign-in.
    provider.accountExists = false;
    await tester.enterText(find.byType(TextField), 'later@example.com');
    await tester.tap(find.text('roles.add_button'.tr()));
    await tester.pump();
    expect(find.text('roles.access_saved_waiting'.tr()), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('changing a line sends the new access at once', (tester) async {
    final provider = RecordingProvider()
      ..debugSetRoleDataForTests(emailGrants: [joined]);
    await pump(tester, provider);

    await tester.tap(find.byKey(const ValueKey('roles-access-menu-joined@example.com')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('roles.access_platform'.tr()).last);
    await tester.pump();
    expect(provider.calls, ['joined@example.com=platform']);
    expect(find.text('roles.access_changed'.tr()), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('removing a line asks first', (tester) async {
    final provider = RecordingProvider()
      ..debugSetRoleDataForTests(emailGrants: [joined]);
    await pump(tester, provider);
    final remove = inLine('joined@example.com', find.byType(IconButton));

    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('roles.remove_confirm'.tr(args: ['joined@example.com'])), findsOneWidget);
    await tester.tap(find.text('common.cancel'.tr()));
    await tester.pumpAndSettle();
    expect(provider.calls, isEmpty);

    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('roles-remove-confirm')));
    await tester.pump();
    expect(provider.calls, ['remove joined@example.com']);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('the owner and your own line cannot be changed', (tester) async {
    final mine = AdminEmailGrant(
        email: 'me@example.com',
        access: 'master',
        createdAt: DateTime(2026, 10, 3),
        appliedAt: DateTime(2026, 10, 3));
    final provider = RecordingProvider()
      ..debugSetSignedInForTests(email: 'Me@Example.com', isMasterAdmin: true)
      ..debugSetRoleDataForTests(emailGrants: [owner, mine, joined]);
    await pump(tester, provider);

    for (final email in ['owner@example.com', 'me@example.com']) {
      expect(inLine(email, find.byType(DropdownButton<String>)), findsNothing);
      expect(inLine(email, find.byType(IconButton)), findsNothing);
    }
    expect(inLine('owner@example.com', find.textContaining('roles.access_locked'.tr())),
        findsOneWidget);
    expect(inLine('me@example.com', find.textContaining('roles.access_you'.tr())),
        findsOneWidget);
    expect(inLine('joined@example.com', find.byType(IconButton)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('capability checkboxes sit on lines that open the platform page',
      (tester) async {
    final lessons = AdminEmailGrant(
        email: 'lessons@example.com',
        access: 'lessons',
        createdAt: DateTime(2026, 10, 22),
        appliedAt: DateTime(2026, 10, 22),
        profileId: 'p2');
    final provider = AppProvider()
      ..debugSetRoleDataForTests(emailGrants: [joined, lessons, waiting]);
    await pump(tester, provider);
    expect(inLine('joined@example.com', find.byType(Checkbox)),
        findsNWidgets(kKnownAdminCapabilities.length));
    expect(inLine('lessons@example.com', find.byType(Checkbox)), findsNothing);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  test('either admin page counts as an admin page', () {
    final platform = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(
          email: 'a@example.invalid', isAdmin: true, platformPageOnly: true);
    expect((platform.isAdminUser, platform.isLessonsAdmin, platform.hasAdminPage),
        (true, false, true));

    final lessons = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(email: 'b@example.invalid', isLessonsAdmin: true);
    expect((lessons.isAdminUser, lessons.isLessonsAdmin, lessons.hasAdminPage),
        (false, true, true));

    final viewer = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(email: 'c@example.invalid');
    expect(viewer.hasAdminPage, isFalse);
    platform.dispose();
    lessons.dispose();
    viewer.dispose();
  });

  Future<void> pumpSwitch(WidgetTester tester, AppProvider provider) async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: const MaterialApp(
            home: Scaffold(body: AdminAreaSwitch(current: AdminArea.platform))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the area switch shows only with both admin pages', (tester) async {
    final both = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(email: 'a@example.invalid', isAdmin: true);
    await pumpSwitch(tester, both);
    expect(find.byKey(const ValueKey('admin-area-lessons')), findsOneWidget);

    final platform = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(
          email: 'b@example.invalid', isAdmin: true, platformPageOnly: true);
    await pumpSwitch(tester, platform);
    expect(find.byKey(const ValueKey('admin-area-lessons')), findsNothing);

    final lessons = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(email: 'c@example.invalid', isLessonsAdmin: true);
    await pumpSwitch(tester, lessons);
    expect(find.byKey(const ValueKey('admin-area-lessons')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    both.dispose();
    platform.dispose();
    lessons.dispose();
  });

  testWidgets('a platform admin who opens the lessons page lands on /admin',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AppProvider(AdminDatabaseService(null))
      ..debugSetSignedInForTests(
          email: 'admin@example.invalid', isAdmin: true, platformPageOnly: true);
    final router = AppRouter.build(provider);
    router.go('/admin/lessons');
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(router.routeInformationProvider.value.uri.path, '/admin');
    await tester.pumpWidget(const SizedBox());
    router.dispose();
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
