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
import 'package:streamer_app/core/widgets/ds/ca_surfaces.dart';
import 'package:streamer_app/features/admin/models/chat_mute_audit_entry.dart';
import 'package:streamer_app/features/admin/models/chat_report_model.dart';
import 'package:streamer_app/features/admin/presentation/lantern/lantern_chat_reports.dart';
import 'package:streamer_app/features/admin/presentation/widgets/chat_moderation_view.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/lantern/lantern_chat_moderation.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/chat_sender_profile_sheet.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';

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

  // ---- Chat moderation -----------------------------------------------------

  Future<_ChatDb> pumpChatQueue(WidgetTester tester,
      {String lang = 'en',
      Size size = phone,
      bool night = false,
      bool empty = false}) async {
    final db = _ChatDb(empty: empty);
    final provider = AppProvider(db)
      ..restoreAppSkin(AppSkin.lantern,
          appearance: night ? LanternAppearance.night : LanternAppearance.day)
      ..debugSetSignedInForTests(
          email: 'admin@example.invalid', name: 'Admin', isAdmin: true);
    await pumpLanternWidget(
        tester, const LanternSurface(child: ChatModerationView()),
        lang: lang, size: size, night: night, provider: provider);
    await tester.pump(const Duration(milliseconds: 200));
    return db;
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> hold(WidgetTester tester, Finder button) async {
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(Lantern.hold + const Duration(milliseconds: 150));
    await gesture.up();
    await frames(tester);
  }

  for (final lang in ['en', 'ar']) {
    for (final (label, size) in [('phone', phone), ('website', laptop)]) {
      for (final night in [false, true]) {
        testWidgets(
            'chat reports lay out: $lang $label ${night ? 'night' : 'day'}',
            (tester) async {
          await pumpChatQueue(tester, lang: lang, size: size, night: night);
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternChatReportsQueue), findsOneWidget);
          expect(find.byKey(const ValueKey('lantern-chat-report-r1')),
              findsOneWidget);
          expect(
              find.byKey(const ValueKey('lantern-muted-log')), findsOneWidget);
          expectNoOlderKit(find.byType(LanternChatReportsQueue), 'chat');
          expect(find.byType(ExpansionTile), findsNothing);
        });
      }
    }
  }

  testWidgets('no open reports shows the empty state', (tester) async {
    await pumpChatQueue(tester, empty: true);
    expect(find.byKey(const ValueKey('lantern-chat-reports-empty')),
        findsOneWidget);
    expect(find.text('No open chat reports.'), findsOneWidget);
  });

  testWidgets('dismiss clears the report through the provider', (tester) async {
    final db = await pumpChatQueue(tester);
    await tester.tap(find.byKey(const ValueKey('lantern-chat-dismiss-r1')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(db.dismissed, ['r1']);
    expect(find.byKey(const ValueKey('lantern-chat-report-r1')), findsNothing);
  });

  testWidgets('deleting the message is press-and-hold', (tester) async {
    final db = await pumpChatQueue(tester);
    await tester.tap(find.byKey(const ValueKey('lantern-chat-delete-r1')));
    await frames(tester);
    final button = find.byKey(const ValueKey('lantern-moderation-hold'));
    expect(button, findsOneWidget);
    // A tap is not enough.
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
    expect(db.deleted, isEmpty);
    await hold(tester, button);
    expect(db.deleted, ['m1']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mute asks for the duration, then is held', (tester) async {
    final db = await pumpChatQueue(tester);
    await tester.tap(find.byKey(const ValueKey('lantern-chat-mute-r1')));
    await frames(tester);
    expect(
        find.byKey(const ValueKey('lantern-mute-durations')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lantern-mute-1.0')));
    await frames(tester);
    await hold(tester, find.byKey(const ValueKey('lantern-moderation-hold')));
    expect(db.muted, [('u1', 1.0)]);
  });

  testWidgets('a ban needs a reason and is held', (tester) async {
    final db = await pumpChatQueue(tester, size: laptop);
    await tester.tap(find.byKey(const ValueKey('lantern-chat-ban-r1')));
    await frames(tester);
    final field = find.descendant(
        of: find.byKey(const ValueKey('lantern-ban-reason')),
        matching: find.byType(TextField));
    await tester.enterText(field, '');
    await tester.pump();
    final banHold = find.byKey(const ValueKey('lantern-ban-hold'));
    expect(tester.widget<LHoldButton>(banHold).enabled, isFalse);
    await tester.enterText(field, 'Repeated spam');
    await tester.pump();
    expect(tester.widget<LHoldButton>(banHold).enabled, isTrue);
    await hold(tester, banHold);
    expect(db.banned, [('u1', 'Repeated spam')]);
  });

  testWidgets('the room message menu and sender window are Lantern sheets',
      (tester) async {
    final controller = LiveChatController(streamId: 'stream-1');
    addTearDown(controller.dispose);
    final message = ChatMessageModel(
        id: 'm9',
        streamId: 'stream-1',
        senderId: 'u9',
        senderName: 'Yusuf',
        body: 'As-salamu alaykum',
        createdAt: DateTime(2026, 11, 11, 20));
    await pumpLanternWidget(
        tester,
        LanternSurface(
            night: true,
            child: Builder(
                builder: (context) => Column(children: [
                      LButton(
                          key: const ValueKey('open-menu'),
                          label: 'menu',
                          onPressed: () => showLanternChatMessageActions(
                              context,
                              message: message,
                              controller: controller)),
                      LButton(
                          key: const ValueKey('open-sender'),
                          label: 'sender',
                          onPressed: () => showLanternChatSenderProfile(context,
                              message: message, controller: controller)),
                    ]))));
    await tester.tap(find.byKey(const ValueKey('open-menu')));
    await frames(tester);
    expect(
        find.byKey(const ValueKey('lantern-message-actions')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('lantern-message-report')), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-message-hide')), findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-message-block')), findsOneWidget);
    // Moderating rows only for people who can moderate this room.
    expect(find.byKey(const ValueKey('lantern-message-mute')), findsNothing);
    expect(find.byType(CaSheet), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lantern-message-report')));
    await frames(tester);
    expect(find.byKey(const ValueKey('lantern-report-reason-spam')),
        findsOneWidget);
    Navigator.of(tester
            .element(find.byKey(const ValueKey('lantern-report-reason-spam'))))
        .pop();
    await frames(tester);

    await tester.tap(find.byKey(const ValueKey('open-sender')));
    await frames(tester);
    expect(find.byType(ChatSenderProfileSheet), findsOneWidget);
    expect(
        find.byKey(const ValueKey('lantern-sender-profile')), findsOneWidget);
    expect(find.byType(CaSheet), findsNothing);
    expect(find.byType(CaAvatar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the sender window shows moderation for a moderator',
      (tester) async {
    Duration? muted = const Duration(days: 1);
    await pumpLanternWidget(
        tester,
        SingleChildScrollView(
            child: LanternSenderProfile(
                name: 'Yusuf',
                avatarUrl: null,
                roleLabel: 'Viewer',
                ring: LRing.none,
                affiliation: null,
                moderatorSince: null,
                canAct: true,
                muteKnown: true,
                muted: false,
                muteLeft: null,
                isModerator: false,
                busy: false,
                error: null,
                history: [
                  ChatMessageModel(
                      id: 'a',
                      streamId: 's',
                      senderId: 'u',
                      senderName: 'Yusuf',
                      body: 'Hello',
                      createdAt: DateTime(2026, 11, 11, 20)),
                ],
                onMute: (d) => muted = d,
                onUnmute: () {},
                onToggleModerator: () {},
                onDeleteAll: () {})),
        lang: 'ar');
    await tester.tap(find.byKey(const ValueKey('lantern-sender-mute-10')));
    expect(muted, const Duration(minutes: 10));
    await tester.tap(find.byKey(const ValueKey('lantern-sender-mute-rest')));
    expect(muted, isNull);
    expect(find.byKey(const ValueKey('lantern-sender-delete-all')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// The chat-report tables in memory.
class _ChatDb extends FixtureApplicationDb {
  _ChatDb({bool empty = false}) {
    if (!empty) {
      reports.addAll([
        ChatReportModel(
            id: 'r1',
            messageId: 'm1',
            streamId: 'stream-1',
            reportedSenderId: 'u1',
            reporterId: 'v1',
            reason: 'spam',
            createdAt: DateTime(2026, 11, 11, 19, 30),
            messageBody: 'Visit my page for free gifts',
            reporterDisplayName: 'Umm Ahmad',
            reportedDisplayName: 'Yusuf',
            reportedEmail: 'yusuf@example.invalid'),
        ChatReportModel(
            id: 'r2',
            messageId: 'm2',
            streamId: 'stream-1',
            reportedSenderId: 'u1',
            reporterId: 'v2',
            reason: 'other',
            createdAt: DateTime(2026, 11, 11, 19, 40),
            messageBody: 'Another link',
            reporterDisplayName: 'Sarah',
            reportedDisplayName: 'Yusuf'),
      ]);
    }
  }

  final reports = <ChatReportModel>[];
  final dismissed = <String>[], deleted = <String>[];
  final muted = <(String, double?)>[];
  final banned = <(String, String)>[];

  @override
  Future<List<ChatReportModel>> loadChatReports() async =>
      List.unmodifiable(reports);

  @override
  Future<List<ChatMuteAuditEntry>> loadMutedChattersAuditLog() async => [
        ChatMuteAuditEntry(
            profileId: 'u7',
            displayName: 'Guest 1902',
            streamsMutedCount: 2,
            lastReason: 'Spam',
            lastMessages: const ['buy now'],
            lastMutedAt: DateTime(2026, 11, 10)),
      ];

  @override
  Future<void> dismissChatReport(String reportId) async {
    dismissed.add(reportId);
    reports.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<void> deleteChatMessageAndResolveReport(
      {required String messageId, required String reportId}) async {
    deleted.add(messageId);
    reports.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<void> muteChatSenderAndResolveReport(
      {required String streamId,
      required String senderId,
      required String reportId,
      double? muteDurationHours}) async {
    muted.add((senderId, muteDurationHours));
    reports.removeWhere((r) => r.id == reportId);
  }

  @override
  Future<void> banAccountPlatformWide(
      {required String profileId,
      required String email,
      required String reason,
      DateTime? expiresAt}) async {
    banned.add((profileId, reason));
  }
}
