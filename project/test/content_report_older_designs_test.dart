import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/content_report_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/moderation/presentation/content_report_sheet.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/empty_broadcasts.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

/// Reporting a broadcast or a channel in the gold & black and Hedayah
/// designs (owner decision 2026-11-12: Google's reviewer sees gold & black,
/// and Google Play asks for a way to report content and its publisher).
class _Reports extends ContentReportService {
  final sent = <Map<String, Object?>>[];
  Object? failure;
  List<ContentReport> queue = [];
  final cleared = <String>[];

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
    });
  }

  @override
  Future<List<ContentReport>> loadOpen() async => queue;

  @override
  Future<void> dismiss(String id) async {
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

  const channelReport = ValueKey('channel-report');
  const roomReport = ValueKey('room-report');
  const sheet = ValueKey('content-report-sheet');
  final lantern = find.byWidgetPredicate((w) => w is LanternSkinWidget);

  /// The sample channels (the first one is live), with a report service that
  /// records what is sent.
  AppProvider provider(AppSkin skin, _Reports reports,
      {bool signedIn = true, String? owns}) {
    final p = AppProvider.withServices(
        organizationBroadcastService: EmptyBroadcasts(),
        contentReportService: reports)
      ..restoreAppSkin(skin);
    for (final (i, s) in mockStreamers.indexed) {
      p.addStreamerForTests(i == 0
          ? s.copyWith(
              isCurrentlyLive: true,
              broadcastType: BroadcastType.liveVideo,
              activeStreamId: 'olderLive')
          : s);
    }
    if (owns != null) {
      p.debugSetSignedInForTests(
          email: 'streamer@example.invalid',
          name: 'Streamer',
          ownedStreamerId: owns);
    } else if (signedIn) {
      p.debugSetSignedInForTests(
          email: 'viewer@example.invalid', isStreamer: false, userId: 'viewer');
    }
    return p;
  }

  for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
    group('${skin.id}: the channel page', () {
      final id = mockStreamers[1].streamerId;

      testWidgets('a signed-in visitor picks a reason and the report goes',
          (tester) async {
        final reports = _Reports();
        final app = await LanternApp.start(tester,
            provider: provider(skin, reports), location: '/profile/$id');
        await app.settle(10);
        tester.takeException();
        expect(find.byKey(channelReport), findsOneWidget);
        expect(lantern, findsNothing);

        await tester.tap(find.byKey(channelReport));
        await app.settle(6);
        expect(find.byKey(sheet), findsOneWidget);
        expect(find.text('Report this channel'), findsOneWidget);
        for (final reason in ContentReportReason.all) {
          expect(find.byKey(ValueKey('content-report-reason-$reason')),
              findsOneWidget);
        }
        expect(lantern, findsNothing);

        await tester
            .tap(find.byKey(const ValueKey('content-report-reason-spam')));
        await app.settle(6);
        expect(find.byKey(sheet), findsNothing);
        expect(reports.sent, [
          {
            'kind': ContentReportKind.channel,
            'channel': mockStreamers[1].channelProfileId,
            'stream': null,
            'reason': ContentReportReason.spam,
          }
        ]);
        expect(find.text('Report sent. The team will review it.'),
            findsOneWidget);
        await app.close();
      });

      testWidgets('a guest is asked to sign in and nothing is sent',
          (tester) async {
        final reports = _Reports();
        final app = await LanternApp.start(tester,
            provider: provider(skin, reports, signedIn: false),
            location: '/profile/$id');
        await app.settle(10);
        tester.takeException();
        await tester.tap(find.byKey(channelReport));
        await app.settle(6);
        expect(find.byKey(sheet), findsNothing);
        expect(
            find.text(
                'A report needs an account behind it, so the team can trust it and follow up.'),
            findsOneWidget);
        expect(reports.sent, isEmpty);
        await app.close();
      });

      testWidgets('a report that cannot be sent says so', (tester) async {
        final reports = _Reports()..failure = StateError('offline');
        final app = await LanternApp.start(tester,
            provider: provider(skin, reports), location: '/profile/$id');
        await app.settle(10);
        tester.takeException();
        await tester.tap(find.byKey(channelReport));
        await app.settle(6);
        await tester
            .tap(find.byKey(const ValueKey('content-report-reason-other')));
        await app.settle(6);
        expect(
            find.text(
                'The report could not be sent. Check your connection and try again.'),
            findsOneWidget);
        await app.close();
      });

      testWidgets('the owner of the channel has no report button',
          (tester) async {
        final app = await LanternApp.start(tester,
            provider: provider(skin, _Reports(), owns: id),
            location: '/profile/$id');
        await app.settle(10);
        tester.takeException();
        expect(find.byKey(channelReport), findsNothing);
        await app.close();
      });
    });

    group('${skin.id}: the live room', () {
      testWidgets('a viewer reports the broadcast; its broadcaster cannot',
          (tester) async {
        StubVideoPlayer.install(
            state: StreamState.live, addTearDown: addTearDown);
        final reports = _Reports();
        var app = await LanternApp.start(tester,
            provider: provider(skin, reports),
            size: const Size(1440, 900),
            location: '/live/olderLive');
        await app.settle(10);
        tester.takeException();
        expect(find.byKey(roomReport), findsOneWidget);
        expect(lantern, findsNothing);
        await tester.tap(find.byKey(roomReport));
        await app.settle(6);
        expect(find.text('Report this broadcast'), findsOneWidget);
        await tester.tap(
            find.byKey(const ValueKey('content-report-reason-wrong_teaching')));
        await app.settle(6);
        expect(reports.sent.single, {
          'kind': ContentReportKind.stream,
          'channel': mockStreamers.first.channelProfileId,
          'stream': 'olderLive',
          'reason': ContentReportReason.wrongTeaching,
        });
        await app.close();

        StubVideoPlayer.install(
            state: StreamState.live, addTearDown: addTearDown);
        app = await LanternApp.start(tester,
            provider: provider(skin, _Reports(),
                owns: mockStreamers.first.streamerId),
            size: const Size(1440, 900),
            location: '/live/olderLive');
        await app.settle(10);
        tester.takeException();
        expect(find.byKey(roomReport), findsNothing);
        await app.close();
      });
    });

    group('${skin.id}: the live room on a phone', () {
      for (final lang in ['en', 'ar']) {
        testWidgets('the top bar has the report button ($lang)',
            (tester) async {
          StubVideoPlayer.install(
              state: StreamState.live, addTearDown: addTearDown);
          final app = await LanternApp.start(tester,
              provider: provider(skin, _Reports()),
              lang: lang,
              location: '/live/olderLive');
          await app.settle(10);
          expect(tester.takeException(), isNull);
          expect(find.byKey(roomReport), findsOneWidget);
          await tester.tap(find.byKey(roomReport));
          await app.settle(6);
          expect(find.byKey(sheet), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(lantern, findsNothing);
          await app.close();
        });
      }
    });

    group('${skin.id}: the admin list', () {
      ContentReport row(String id, ContentReportKind kind) => ContentReport(
          id: id,
          kind: kind,
          channelProfileId: mockStreamers.first.streamerId,
          streamId: kind == ContentReportKind.stream ? 'olderLive' : null,
          reporterId: 'viewer',
          reason: ContentReportReason.wrongTeaching,
          note: 'At minute 12',
          createdAt: DateTime(2026, 11, 12, 9));

      Future<AppProvider> pumpSection(
          WidgetTester tester, _Reports reports) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final p = provider(skin, reports);
        addTearDown(p.dispose);
        await tester.pumpWidget(EasyLocalization(
            key: UniqueKey(),
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: const Locale('en'),
            saveLocale: false,
            path: 'assets/i18n',
            assetLoader: const DirectJsonAssetLoader(),
            child: ChangeNotifierProvider<AppProvider>.value(
                value: p,
                child: Builder(
                    builder: (context) => MaterialApp(
                        debugShowCheckedModeBanner: false,
                        theme: AppTheme.forLocale(context.locale, skin: skin),
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        home: const Scaffold(
                            body: SingleChildScrollView(
                                child: ContentReportsSection())))))));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        return p;
      }

      testWidgets('it draws nothing while there are no reports',
          (tester) async {
        await pumpSection(tester, _Reports());
        expect(find.byKey(const ValueKey('content-reports-section')),
            findsNothing);
        expect(tester.getSize(find.byType(ContentReportsSection)).height, 0);
      });

      testWidgets('it lists the reports and clears one after asking',
          (tester) async {
        final reports = _Reports()
          ..queue = [
            row('r1', ContentReportKind.stream),
            row('r2', ContentReportKind.channel)
          ];
        await pumpSection(tester, reports);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('content-report-r1')), findsOneWidget);
        expect(find.byKey(const ValueKey('content-report-r2')), findsOneWidget);
        expect(find.text('Wrong or misleading religious content'),
            findsNWidgets(2));
        expect(find.text('At minute 12'), findsNWidgets(2));
        expect(find.text('Open the broadcast'), findsOneWidget);
        expect(lantern, findsNothing);

        Future<void> settle() async {
          for (var i = 0; i < 8; i++) {
            await tester.pump(const Duration(milliseconds: 120));
          }
        }

        await tester.tap(find.byKey(const ValueKey('content-report-clear-r1')));
        await settle();
        expect(find.text('Clear this report?'), findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey('content-report-clear-confirm')));
        await settle();
        expect(reports.cleared, ['r1']);
        expect(find.byKey(const ValueKey('content-report-r1')), findsNothing);
        expect(find.byKey(const ValueKey('content-report-r2')), findsOneWidget);
        expect(find.text('Report cleared.'), findsOneWidget);
      });
    });
  }
}
