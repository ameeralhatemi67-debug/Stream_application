import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_fields.dart';
import 'package:streamer_app/core/widgets/ds/ca_navigation.dart';
import 'package:streamer_app/core/widgets/ds/ca_rows.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/admin/presentation/admin_surface.dart';
import 'package:streamer_app/features/admin/presentation/lantern/lantern_admin_frame.dart';
import 'package:streamer_app/features/admin/presentation/lantern/lantern_admin_overview.dart';
import 'package:streamer_app/features/admin/presentation/lantern/lantern_verification_queue.dart';

import 'fixtures/admin_applications.dart';
import 'support/fixture_application_db.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The admin page in Lantern and Arch (ADR-026): the frame with its grouped
/// rail or sections sheet, the overview and the verification queue. The tabs,
/// their order and every review action are the older admin page's.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const phone = Size(390, 844), laptop = Size(1440, 900);

  Future<(LanternApp, FixtureApplicationDb)> openAdmin(WidgetTester tester,
      {String lang = 'en',
      Size size = phone,
      bool night = false,
      bool applications = true,
      bool lessons = false}) async {
    final db = FixtureApplicationDb();
    final provider = AppProvider(db)
      ..restoreAppSkin(AppSkin.lantern,
          appearance: night ? LanternAppearance.night : LanternAppearance.day)
      ..debugSetSignedInForTests(
          email: 'master@example.invalid',
          name: 'Master',
          isMasterAdmin: true,
          isLessonsAdmin: lessons);
    if (applications) {
      for (final a in sampleBroadcasterApplications()) {
        await tester.runAsync(() => provider.submitBroadcasterApplication(a));
      }
    }
    final app = await LanternApp.start(tester,
        provider: provider, size: size, lang: lang, location: '/admin');
    return (app, db);
  }

  int tabIndex(WidgetTester tester) => tester
      .widget<TabBarView>(find.byType(TabBarView).first)
      .controller!
      .index;

  Future<void> showQueue(WidgetTester tester, LanternApp app) async {
    await tester.tap(find.byKey(const ValueKey('lantern-overview-review')));
    await app.settle();
    expect(tabIndex(tester), 1);
  }

  /// Older-kit widgets that must not be drawn by a Lantern view.
  void expectNoOlderKit(Finder within, String reason) {
    for (final type in [
      CaAppBar,
      CaKpiTile,
      CaAvatar,
      CaChip,
      CaButton,
      AdminCard,
      AdminCount,
      ChoiceChip,
      Checkbox,
      ElevatedButton,
      OutlinedButton,
      ListTile,
    ]) {
      expect(find.descendant(of: within, matching: find.byType(type)),
          findsNothing,
          reason: '$type in $reason');
    }
  }

  for (final lang in ['en', 'ar']) {
    for (final (label, size) in [('phone', phone), ('website', laptop)]) {
      for (final night in [false, true]) {
        testWidgets(
            'admin frame, overview and queue lay out: $lang $label ${night ? 'night' : 'day'}',
            (tester) async {
          final (app, _) =
              await openAdmin(tester, lang: lang, size: size, night: night);
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternAdminFrame), findsOneWidget);
          expect(find.byType(CaAppBar), findsNothing);
          expect(find.byType(Drawer), findsNothing);
          expect(find.byKey(const ValueKey('admin-navigation')), findsNothing);
          if (size == laptop) {
            expect(find.byKey(const ValueKey('lantern-admin-rail')),
                findsOneWidget);
            expect(find.byType(LanternWebHeader), findsOneWidget);
          } else {
            expect(find.byType(LanternPageBar), findsOneWidget);
          }
          expect(find.byType(LanternAdminOverview), findsOneWidget);
          expectNoOlderKit(find.byType(LanternAdminOverview), 'overview');
          await showQueue(tester, app);
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternVerificationQueue), findsOneWidget);
          expect(
              find.byKey(const ValueKey('lantern-application-app_kfupm_ai_01')),
              findsOneWidget);
          expectNoOlderKit(find.byType(LanternVerificationQueue), 'queue');
          await app.close();
        });
      }
    }
  }

  testWidgets('the rail groups the tabs and changes the same tab controller',
      (tester) async {
    final (app, _) = await openAdmin(tester, size: laptop, lessons: true);
    expect(find.byKey(const ValueKey('lantern-admin-area-switch')),
        findsOneWidget);
    for (final group in ['Review', 'Moderate', 'Directory', 'Configure']) {
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('lantern-admin-rail')),
              matching: find.text(group)),
          findsOneWidget,
          reason: group);
    }
    // Viewer Analytics is the fifth tab in the older navigation too.
    await tester.tap(find.byKey(const ValueKey('lantern-admin.tab_viewers')));
    await app.settle();
    expect(tabIndex(tester), 4);
    // Roles are offered to a master admin.
    final roles = find.byKey(const ValueKey('lantern-admin.tab_roles'));
    await tester.ensureVisible(roles);
    await tester.tap(roles);
    await app.settle();
    // The older hub's roles index: 11, plus the testing tab of a debug build.
    expect(tabIndex(tester), 12);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('on a phone the sections sheet lists the same tabs',
      (tester) async {
    final (app, _) = await openAdmin(tester, lang: 'ar');
    await tester.tap(find.byKey(const ValueKey('lantern-admin-sections')));
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-admin-sheet')), findsOneWidget);
    final viewers = find.byKey(const ValueKey('lantern-admin.tab_viewers'));
    await tester.ensureVisible(viewers);
    await tester.tap(viewers);
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-admin-sheet')), findsNothing);
    expect(tabIndex(tester), 4);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('the overview shows the loaded counts and its shortcuts',
      (tester) async {
    final (app, _) = await openAdmin(tester);
    final pending = app.provider.pendingApplications.length;
    expect(pending, greaterThan(0));
    expect(
        find.descendant(
            of: find.byType(LanternAdminOverview),
            matching: find.text('$pending')),
        findsWidgets);
    // Viewers and seats are not measured: they say so.
    expect(find.text('Unavailable'), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('lantern-overview-terms')));
    await app.settle();
    expect(tabIndex(tester), 5);
    await app.close();
  });

  testWidgets('filters carry counts and an empty filter says so',
      (tester) async {
    final (app, _) = await openAdmin(tester);
    await showQueue(tester, app);
    final all = sampleBroadcasterApplications().length;
    final allChip = tester
        .widget<LChip>(find.byKey(const ValueKey('lantern-queue-filter-all')));
    expect(allChip.count, all);
    await tester
        .tap(find.byKey(const ValueKey('lantern-queue-filter-approved')));
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-queue-empty')), findsOneWidget);
    expect(find.text('No applications match the selected filter.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('an empty queue shows the empty state', (tester) async {
    final (app, _) = await openAdmin(tester, applications: false);
    await showQueue(tester, app);
    expect(find.byKey(const ValueKey('lantern-queue-empty')), findsOneWidget);
    await app.close();
  });

  testWidgets('refreshing shows the loading state until the reload returns',
      (tester) async {
    final reload = Completer<void>();
    final search = TextEditingController();
    addTearDown(search.dispose);
    await pumpLanternWidget(
        tester,
        LanternVerificationQueue(
            rows: const [],
            filter: null,
            onFilter: (_) {},
            search: search,
            onSearchChanged: () {},
            showLog: false,
            onShowLog: (_) {},
            selected: const {},
            onSelect: (_, __) {},
            onSelectAll: (_, __) {},
            onClearSelection: () {},
            onRefresh: () => reload.future,
            onInspect: (_) {},
            onApprove: (_) {},
            onReject: (_) {},
            onRemove: (_) {},
            onApproveSelected: () {},
            onRejectSelected: () {},
            events: const [],
            isReversible: (_) => false,
            onEventDetails: (_) {},
            onReverse: (_) {}));
    expect(find.byKey(const ValueKey('lantern-queue-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lantern-queue-refresh')));
    await tester.pump();
    expect(find.byKey(const ValueKey('lantern-queue-loading')), findsOneWidget);
    reload.complete();
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('lantern-queue-loading')), findsNothing);
    expect(find.byKey(const ValueKey('lantern-queue-empty')), findsOneWidget);
  });

  testWidgets('rejecting one application needs a reason, then rejects it',
      (tester) async {
    final (app, _) = await openAdmin(tester);
    await showQueue(tester, app);
    final id = app.provider.pendingApplications.first.id;
    final reject = find.byKey(ValueKey('lantern-application-reject-$id'));
    await tester.ensureVisible(reject);
    await tester.tap(reject);
    await app.settle();
    await tester.tap(find.byKey(const ValueKey('lantern-reject-confirm')));
    await app.settle();
    expect(
        find.text('Write a reason the applicant can act on.'), findsOneWidget);
    expect(app.provider.applications.firstWhere((a) => a.id == id).status,
        ApplicationStatus.pending);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('lantern-reject-reason')),
            matching: find.byType(TextField)),
        'Add the accreditation letter.');
    await tester.tap(find.byKey(const ValueKey('lantern-reject-confirm')));
    await app.settle();
    final rejected = app.provider.applications.firstWhere((a) => a.id == id);
    expect(rejected.status, ApplicationStatus.rejected);
    expect(rejected.adminReviewNotes, 'Add the accreditation letter.');
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('approving runs the pipeline and approves the application',
      (tester) async {
    final (app, _) = await openAdmin(tester, lang: 'ar');
    await showQueue(tester, app);
    final id = app.provider.pendingApplications.first.id;
    final before = app.provider.streamers.length;
    final approve = find.byKey(ValueKey('lantern-application-approve-$id'));
    await tester.ensureVisible(approve);
    await tester.tap(approve);
    await tester.pump();
    await app.settle(12);
    expect(app.provider.applications.firstWhere((a) => a.id == id).status,
        ApplicationStatus.approved);
    expect(app.provider.streamers.length, before + 1);
    expect(
        find.byKey(const ValueKey('lantern-approve-pipeline')), findsNothing);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets(
      'the batch bar appears with a selection and rejects with one reason',
      (tester) async {
    final (app, _) = await openAdmin(tester);
    await showQueue(tester, app);
    expect(find.byKey(const ValueKey('lantern-queue-batch')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lantern-queue-select-all')));
    await app.settle();
    final ids = app.provider.pendingApplications.map((a) => a.id).toList();
    expect(ids.length, greaterThan(1));
    expect(find.byKey(const ValueKey('lantern-queue-batch')), findsOneWidget);
    expect(find.text('${ids.length} applications selected'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lantern-batch-reject')));
    await app.settle();
    await tester.tap(find.byKey(const ValueKey('lantern-reason-confirm')));
    await app.settle();
    expect(
        find.text('Write a reason the applicant can act on.'), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('lantern-reason-field')),
            matching: find.byType(TextField)),
        'Missing documents.');
    await tester.tap(find.byKey(const ValueKey('lantern-reason-confirm')));
    await app.settle();
    for (final id in ids) {
      final a = app.provider.applications.firstWhere((a) => a.id == id);
      expect(a.status, ApplicationStatus.rejected);
      expect(a.adminReviewNotes, 'Missing documents.');
    }
    expect(find.byKey(const ValueKey('lantern-queue-batch')), findsNothing);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('batch approve approves every selected application',
      (tester) async {
    final (app, _) = await openAdmin(tester, size: laptop);
    await showQueue(tester, app);
    final ids = app.provider.pendingApplications.map((a) => a.id).toList();
    for (final id in ids) {
      final box = find.byKey(ValueKey('lantern-application-select-$id'));
      await tester.ensureVisible(box);
      await tester.tap(box);
      await app.settle(2);
    }
    await tester.tap(find.byKey(const ValueKey('lantern-batch-approve')));
    await app.settle();
    await tester
        .tap(find.byKey(const ValueKey('lantern-batch-approve-confirm')));
    await app.settle();
    for (final id in ids) {
      expect(app.provider.applications.firstWhere((a) => a.id == id).status,
          ApplicationStatus.approved);
    }
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('inspect opens the application and the action log lists reviews',
      (tester) async {
    final (app, _) = await openAdmin(tester);
    await showQueue(tester, app);
    final id = app.provider.pendingApplications.first.id;
    final inspect = find.byKey(ValueKey('lantern-application-inspect-$id'));
    await tester.ensureVisible(inspect);
    await tester.tap(inspect);
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-application-details')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lantern-details-reject')));
    await app.settle();
    await tester.enterText(
        find.descendant(
            of: find.byKey(const ValueKey('lantern-reject-reason')),
            matching: find.byType(TextField)),
        'Not yet.');
    await tester.tap(find.byKey(const ValueKey('lantern-reject-confirm')));
    await app.settle();
    await tester.tap(find.text('Action log'));
    await app.settle();
    expect(
        find.byKey(const ValueKey('lantern-review-log-empty')), findsNothing);
    expect(find.text('Rejected'), findsWidgets);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a signed-in account without admin access is refused',
      (tester) async {
    await pumpLanternWidget(tester, const LanternAdminDenied());
    expect(find.byKey(const ValueKey('lantern-admin-denied')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
