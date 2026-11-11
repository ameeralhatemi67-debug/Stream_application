import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/content_report_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/moderation/presentation/lantern/lantern_report_sheet.dart';
import 'package:streamer_app/features/moderation/presentation/lantern/lantern_reports_queue.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/empty_broadcasts.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

/// Reporting a broadcast or a channel (Lantern and Arch). Google Play asks
/// for a way to report content and its publisher inside the app.
class _Reports extends ContentReportService {
  final sent = <Map<String, Object?>>[];
  Object? failure;

  @override
  Future<void> submit(
      {required ContentReportKind kind,
      required String channelProfileId,
      required String reason,
      String? streamId,
      String? note}) async {
    final error = failure;
    if (error != null) throw error;
    sent.add({
      'kind': kind,
      'channel': channelProfileId,
      'stream': streamId,
      'reason': reason,
      'note': note
    });
  }

  List<ContentReport> queue = [];
  final cleared = <String>[];
  bool failClear = false;

  @override
  Future<List<ContentReport>> loadOpen() async => queue;

  @override
  Future<void> dismiss(String id) async {
    if (failClear) throw StateError('offline');
    cleared.add(id);
    queue = [
      for (final r in queue)
        if (r.id != id) r
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppProvider provider(_Reports reports, {bool signedIn = true}) {
    final p = AppProvider.withServices(
        organizationBroadcastService: EmptyBroadcasts(),
        contentReportService: reports)
      ..restoreAppSkin(AppSkin.lantern);
    if (signedIn) {
      p.debugSetSignedInForTests(
          email: 'viewer@example.invalid', isStreamer: false, userId: 'viewer');
    }
    return p;
  }

  Future<void> open(WidgetTester tester, AppProvider p,
      {String lang = 'en',
      bool night = false,
      ContentReportKind kind = ContentReportKind.stream}) async {
    await pumpLanternWidget(
        tester,
        Builder(
            builder: (context) => Center(
                child: LButton(
                    label: 'open',
                    onPressed: () => showLanternReportSheet(context,
                        kind: kind,
                        channelProfileId: 'channel-1',
                        streamId:
                            kind == ContentReportKind.stream ? 'stream-1' : null,
                        name: 'Tafsir of Juz Amma')))),
        provider: p,
        lang: lang,
        night: night);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the outcome a person is told', () {
    test('a guest is asked to sign in and nothing is sent', () async {
      final reports = _Reports();
      final p = provider(reports, signedIn: false);
      expect(
          await p.submitContentReport(
              kind: ContentReportKind.channel,
              channelProfileId: 'c',
              reason: ContentReportReason.spam),
          ContentReportOutcome.signIn);
      expect(reports.sent, isEmpty);
      p.dispose();
    });

    test('an unknown reason, or a broadcast without its id, is not sent',
        () async {
      final reports = _Reports();
      final p = provider(reports);
      expect(
          await p.submitContentReport(
              kind: ContentReportKind.channel,
              channelProfileId: 'c',
              reason: 'made-up'),
          ContentReportOutcome.failed);
      expect(
          await p.submitContentReport(
              kind: ContentReportKind.stream,
              channelProfileId: 'c',
              reason: ContentReportReason.spam),
          ContentReportOutcome.failed);
      expect(reports.sent, isEmpty);
      p.dispose();
    });

    test('the database answers: already reported, too many, anything else',
        () async {
      final reports = _Reports();
      final p = provider(reports);
      Future<ContentReportOutcome> send() => p.submitContentReport(
          kind: ContentReportKind.channel,
          channelProfileId: 'c',
          reason: ContentReportReason.other);
      expect(await send(), ContentReportOutcome.sent);
      reports.failure = const PostgrestException(message: 'dup', code: '23505');
      expect(await send(), ContentReportOutcome.already);
      reports.failure = const PostgrestException(message: 'many', code: '53400');
      expect(await send(), ContentReportOutcome.tooMany);
      reports.failure = const PostgrestException(message: 'no', code: '42501');
      expect(await send(), ContentReportOutcome.failed);
      reports.failure = StateError('offline');
      expect(await send(), ContentReportOutcome.failed);
      p.dispose();
    });

    test('a channel report carries no broadcast id', () async {
      final reports = _Reports();
      final p = provider(reports);
      await p.submitContentReport(
          kind: ContentReportKind.channel,
          channelProfileId: 'c',
          streamId: 'left-over',
          reason: ContentReportReason.impersonation);
      expect(reports.sent.single['stream'], isNull);
      p.dispose();
    });
  });

  group('the sheet', () {
    for (final (lang, night) in [
      ('en', false),
      ('ar', false),
      ('en', true),
      ('ar', true)
    ]) {
      testWidgets('it lays out with every reason ($lang, night $night)',
          (tester) async {
        await open(tester, provider(_Reports()), lang: lang, night: night);
        expect(tester.takeException(), isNull);
        expect(
            find.byKey(const ValueKey('lantern-report-form')), findsOneWidget);
        for (final reason in ContentReportReason.all) {
          expect(find.byKey(ValueKey('lantern-report-reason-$reason')),
              findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('a guest is asked to sign in instead', (tester) async {
      await open(tester, provider(_Reports(), signedIn: false));
      expect(find.byKey(const ValueKey('lantern-report-form')), findsNothing);
      expect(find.text('Sign in to report'), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-report-sign-in')),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a reason is needed; then the report goes with its note',
        (tester) async {
      final reports = _Reports();
      await open(tester, provider(reports));
      final send = find.byKey(const ValueKey('lantern-report-send'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Choose a reason first.'), findsOneWidget);
      expect(reports.sent, isEmpty);

      final reason = find.byKey(const ValueKey(
          'lantern-report-reason-${ContentReportReason.wrongTeaching}'));
      await tester.ensureVisible(reason);
      await tester.tap(reason);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Choose a reason first.'), findsNothing);
      await tester.enterText(
          find.descendant(
              of: find.byKey(const ValueKey('lantern-report-note')),
              matching: find.byType(TextField)),
          '  At minute 12  ');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(reports.sent.single, {
        'kind': ContentReportKind.stream,
        'channel': 'channel-1',
        'stream': 'stream-1',
        'reason': ContentReportReason.wrongTeaching,
        'note': '  At minute 12  '
      });
      // The sheet is gone and the page says it was sent.
      expect(find.byKey(const ValueKey('lantern-report-form')), findsNothing);
      expect(find.text('Report sent. The team will review it.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a failure stays in the sheet and keeps the choice',
        (tester) async {
      final reports = _Reports()..failure = StateError('offline');
      await open(tester, provider(reports), kind: ContentReportKind.channel);
      expect(find.text('Report this channel'), findsOneWidget);
      final reason = find.byKey(
          const ValueKey('lantern-report-reason-${ContentReportReason.spam}'));
      await tester.ensureVisible(reason);
      await tester.tap(reason);
      final send = find.byKey(const ValueKey('lantern-report-send'));
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lantern-report-form')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('lantern-report-failure')), findsOneWidget);
      // A second try works once the connection is back.
      reports.failure = null;
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(reports.sent.single['reason'], ContentReportReason.spam);
      expect(find.byKey(const ValueKey('lantern-report-form')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('in the live room', () {
    testWidgets('a viewer can report the broadcast; its broadcaster cannot',
        (tester) async {
      StubVideoPlayer.install(state: StreamState.live, addTearDown: addTearDown);
      const report = ValueKey('lantern-room-report');
      var app = await LanternApp.start(tester,
          size: const Size(1440, 900), lang: 'en');
      await app.push('/live/lanternLive');
      await app.settle(10);
      tester.takeException();
      expect(find.byKey(report), findsOneWidget);
      // A guest is asked to sign in first.
      await tester.tap(find.byKey(report));
      await app.settle(6);
      expect(find.text('Sign in to report'), findsOneWidget);
      await app.close();

      StubVideoPlayer.install(state: StreamState.live, addTearDown: addTearDown);
      final own = lanternProvider()
        ..debugSetSignedInForTests(
            email: 'streamer@example.invalid',
            name: 'Streamer',
            ownedStreamerId: mockStreamers.first.streamerId);
      app = await LanternApp.start(tester,
          provider: own, size: const Size(1440, 900), lang: 'en');
      await app.push('/live/lanternLive');
      await app.settle(10);
      tester.takeException();
      expect(find.byKey(report), findsNothing);
      await app.close();
    });
  });

  group('the admin queue', () {
    ContentReport row(String id, ContentReportKind kind, {String? note}) =>
        ContentReport(
            id: id,
            kind: kind,
            channelProfileId: mockStreamers.first.streamerId,
            streamId: kind == ContentReportKind.stream ? 'lanternLive' : null,
            reporterId: 'viewer',
            reason: ContentReportReason.wrongTeaching,
            note: note,
            createdAt: DateTime.now().subtract(const Duration(minutes: 12)));

    Future<AppProvider> pumpQueue(WidgetTester tester, _Reports reports,
        {String lang = 'en', bool night = false}) async {
      final p = provider(reports)..addStreamerForTests(mockStreamers.first);
      await pumpLanternWidget(tester, const LanternContentReportsQueue(),
          provider: p, lang: lang, night: night);
      await tester.pump(const Duration(milliseconds: 200));
      return p;
    }

    for (final (lang, night) in [('en', false), ('ar', true)]) {
      testWidgets('it lists reports, newest first ($lang)', (tester) async {
        final reports = _Reports()
          ..queue = [
            row('r1', ContentReportKind.stream, note: 'At minute 12'),
            row('r2', ContentReportKind.channel),
          ];
        await pumpQueue(tester, reports, lang: lang, night: night);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('lantern-content-report-r1')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('lantern-content-report-r2')),
            findsOneWidget);
        expect(find.text('At minute 12'), findsOneWidget);
        expect(find.text(mockStreamers.first.getLocalizedName(lang)),
            findsNWidgets(2));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('nothing reported says so', (tester) async {
      await pumpQueue(tester, _Reports());
      expect(find.byKey(const ValueKey('lantern-content-reports-empty')),
          findsOneWidget);
      expect(find.text('No reports'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('clearing asks first, then removes the report', (tester) async {
      final reports = _Reports()
        ..queue = [row('r1', ContentReportKind.stream)];
      await pumpQueue(tester, reports);
      await tester.tap(find.byKey(const ValueKey('lantern-report-clear-r1')));
      await tester.pumpAndSettle();
      expect(find.text('Clear this report?'), findsOneWidget);
      expect(reports.cleared, isEmpty);
      await tester
          .tap(find.byKey(const ValueKey('lantern-report-clear-confirm')));
      await tester.pumpAndSettle();
      expect(reports.cleared, ['r1']);
      expect(find.byKey(const ValueKey('lantern-content-report-r1')),
          findsNothing);
      expect(find.text('Report cleared.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a clear that fails keeps the report and says so',
        (tester) async {
      final reports = _Reports()
        ..queue = [row('r1', ContentReportKind.channel)]
        ..failClear = true;
      await pumpQueue(tester, reports);
      await tester.tap(find.byKey(const ValueKey('lantern-report-clear-r1')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('lantern-report-clear-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lantern-content-report-r1')),
          findsOneWidget);
      expect(find.text('The report could not be cleared.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('the tab keeps the chat reports and adds this queue beside them',
        (tester) async {
      final reports = _Reports()
        ..queue = [row('r1', ContentReportKind.stream)];
      final p = provider(reports)..addStreamerForTests(mockStreamers.first);
      await pumpLanternWidget(
          tester,
          const LanternModerationTab(
              chat: Center(child: Text('chat reports here'))),
          provider: p);
      expect(find.text('chat reports here'), findsOneWidget);
      // The queue is not read until it is asked for.
      expect(find.byType(LanternContentReportsQueue), findsNothing);
      await tester.tap(find.text('Broadcasts and channels'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lantern-content-report-r1')),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
