import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/services/upcoming_schedule_service.dart';
import 'package:streamer_app/core/services/youtube_api_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_icon.dart';
import 'package:streamer_app/features/discovery/models/bookmark_entry.dart';
import 'package:streamer_app/features/discovery/presentation/bookmarks_sheet.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/bookmark_button.dart';
import 'package:streamer_app/features/profile/models/upcoming_schedule.dart';
import 'package:streamer_app/features/profile/presentation/widgets/vod_grid_tile.dart';
import 'package:streamer_app/features/profile/presentation/widgets/vod_player_modal_sheet.dart';
import 'fixtures/streamer_fixtures.dart';
import 'fixtures/vod_fixtures.dart';
import 'support/empty_broadcasts.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

final _vod = MockVodArchivePool.sampleVods.first.copyWith(
    vodId: 'vod_yt_bl60n6uuvWE',
    youtubeVideoId: 'bl60n6uuvWE',
    streamerId: mockStreamers.first.streamerId,
    titleEn: 'Saved lecture',
    thumbnailUrl: '');
UpcomingSchedule _schedule() => UpcomingSchedule(
    id: 'schedule-one',
    streamerId: mockStreamers.first.streamerId,
    kind: 'once',
    localTime: '12:00',
    weekdays: const [],
    oneTimeStartUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
    titleEn: 'Upcoming seminar',
    titleAr: 'ندوة قادمة',
    descriptionEn: '',
    descriptionAr: '',
    tags: const [],
    colorKey: 'green');

class _Auth extends SupabaseAuthService {
  Session? session;
  void signIn(String id) {
    session = Session(
        accessToken: 'test-only',
        tokenType: 'bearer',
        user: User(
            id: id,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-10-06T00:00:00Z'));
  }

  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  Future<void> signOut() async {
    session = null;
  }
}

class _Db extends AdminDatabaseService {
  final rows = <String, BookmarkEntry>{};
  bool fail = false;
  int adds = 0;
  Completer<void>? write;
  Completer<List<BookmarkEntry>>? read;
  @override
  Future<List<BookmarkEntry>> loadBookmarks() async {
    if (fail) throw StateError('offline');
    return read == null ? rows.values.toList() : await read!.future;
  }

  @override
  Future<void> addBookmark(BookmarkEntry entry) async {
    adds++;
    if (write != null) await write!.future;
    if (fail) throw StateError('offline');
    rows.putIfAbsent(entry.id, () => entry);
  }

  @override
  Future<void> removeBookmark(String id) async {
    if (fail) throw StateError('offline');
    rows.remove(id);
  }
}

class _Schedules extends UpcomingScheduleService {
  List<UpcomingSchedule> rows = [];
  @override
  Future<List<UpcomingSchedule>> load(String id) async => rows;
}

AppProvider _provider(
        {_Db? db,
        _Auth? auth,
        YouTubeApiService? youtube,
        UpcomingScheduleService? schedules}) =>
    AppProvider.withServices(
        adminDbService: db ?? _Db(),
        authService: auth ?? _Auth(),
        youTubeService: youtube,
        upcomingService: schedules,
        organizationBroadcastService: EmptyBroadcasts());

Widget _app(AppProvider provider, Widget child,
        {String language = 'en', double scale = 1}) =>
    EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: Locale(language),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: Builder(
                builder: (context) => MaterialApp(
                    theme: AppTheme.forLocale(context.locale),
                    locale: context.locale,
                    localizationsDelegates: context.localizationDelegates,
                    supportedLocales: context.supportedLocales,
                    builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            disableAnimations: true,
                            textScaler: TextScaler.linear(scale)),
                        child: child!),
                    home: Scaffold(body: child)))));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('archive and playlist share one bookmark and removal clears both',
      () async {
    final p = _provider();
    await p.toggleVodBookmark(_vod);
    expect(p.isBookmarked('vod_pl_bl60n6uuvWE'), isTrue);
    expect(p.bookmarks.single.vod?.youtubeVideoId, 'bl60n6uuvWE');
    await p.toggleVodBookmark(_vod.copyWith(vodId: 'vod_pl_bl60n6uuvWE'));
    expect(p.bookmarks, isEmpty);
    p.dispose();
  });

  test('failed save rolls back; failed removal restores saved item', () async {
    final auth = _Auth();
    final db = _Db();
    final p = _provider(db: db, auth: auth);
    auth.signIn('a');
    db.fail = true;
    await expectLater(p.toggleVodBookmark(_vod), throwsStateError);
    expect(p.bookmarks, isEmpty);
    expect(p.isBookmarkPending('bl60n6uuvWE'), isFalse);
    db.fail = false;
    await p.toggleVodBookmark(_vod);
    db.fail = true;
    await expectLater(
        p.removeSavedBookmark(p.bookmarks.single), throwsStateError);
    expect(p.isBookmarked(_vod.vodId), isTrue);
    p.dispose();
  });

  test('rapid clicks write once and refresh cannot overwrite a pending save',
      () async {
    final auth = _Auth();
    final db = _Db()..write = Completer<void>();
    final p = _provider(db: db, auth: auth);
    auth.signIn('a');
    final saving = p.toggleVodBookmark(_vod);
    await p.toggleVodBookmark(_vod);
    await p.loadBookmarks();
    expect(p.isBookmarked(_vod.vodId), isTrue);
    expect(db.adds, 1);
    db.write!.complete();
    await saving;
    expect(p.isBookmarkPending('bl60n6uuvWE'), isFalse);
    p.dispose();
  });

  test('a stale library response cannot restore a removed bookmark', () async {
    final auth = _Auth();
    final db = _Db();
    final p = _provider(db: db, auth: auth);
    auth.signIn('a');
    await p.toggleVodBookmark(_vod);
    final old = p.bookmarks.single;
    db.read = Completer<List<BookmarkEntry>>();
    final loading = p.loadBookmarks();
    await p.removeSavedBookmark(old);
    db.read!.complete([old]);
    await loading;
    expect(p.bookmarks, isEmpty);
    p.dispose();
  });

  test('load failure preserves the library and exposes retry state', () async {
    final auth = _Auth();
    final db = _Db();
    final p = _provider(db: db, auth: auth);
    auth.signIn('a');
    await p.toggleVodBookmark(_vod);
    db.fail = true;
    await p.loadBookmarks();
    expect(p.bookmarkLoadFailed, isTrue);
    expect(p.bookmarks, hasLength(1));
    db.fail = false;
    await p.loadBookmarks();
    expect(p.bookmarkLoadFailed, isFalse);
    p.dispose();
  });

  test('old ID-only saves resolve video metadata through the web proxy',
      () async {
    final auth = _Auth();
    final db = _Db();
    db.rows['bl60n6uuvWE'] = BookmarkEntry.fromRow(
        {'vod_id': 'vod_pl_bl60n6uuvWE', 'streamer_id': _vod.streamerId});
    final youtube = YouTubeApiService(
        useWebProxy: true,
        apiKey: '',
        client: MockClient((request) async {
          expect(request.url.path, '/api/youtube');
          expect(request.url.queryParameters['part'], 'snippet,statistics');
          expect(request.url.queryParameters.containsKey('key'), isFalse);
          return http.Response(
              jsonEncode({
                'items': [
                  {
                    'id': 'bl60n6uuvWE',
                    'snippet': {
                      'title': 'Original saved lecture',
                      'publishedAt': '2026-10-01T00:00:00Z'
                    },
                    'statistics': {'viewCount': '12'}
                  }
                ]
              }),
              200);
        }));
    final p = _provider(db: db, auth: auth, youtube: youtube);
    auth.signIn('a');
    await p.loadBookmarks();
    expect(p.bookmarks.single.vod?.titleEn, 'Original saved lecture');
    expect(p.bookmarks.single.vod?.streamerId, _vod.streamerId);
    p.dispose();
  });

  test('upcoming bookmarks refresh changed announcements and mark removals',
      () async {
    final auth = _Auth();
    final db = _Db();
    final schedules = _Schedules()..rows = [_schedule()];
    final p = _provider(db: db, auth: auth, schedules: schedules);
    auth.signIn('a');
    await p.toggleUpcomingBookmark(_schedule());
    expect(p.hasCardReminder('schedule-one'), isFalse);
    await p.loadBookmarks();
    expect(p.bookmarks.single.scheduleUnavailable, isFalse);
    schedules.rows = [];
    await p.loadBookmarks();
    expect(p.bookmarks.single.scheduleUnavailable, isTrue);
    expect(p.isUpcomingBookmarked('schedule-one'), isTrue);
    p.dispose();
  });

  test('another account or disposed provider ignores an old library response',
      () async {
    for (final dispose in [false, true]) {
      final auth = _Auth();
      final db = _Db()..read = Completer<List<BookmarkEntry>>();
      final p = _provider(db: db, auth: auth);
      auth.signIn('a');
      final loading = p.loadBookmarks();
      if (dispose) {
        p.dispose();
      } else {
        auth.signIn('b');
      }
      db.read!.complete([BookmarkEntry.recording(_vod)]);
      await loading;
      expect(p.bookmarks, isEmpty);
      if (!dispose) p.dispose();
    }
  });

  testWidgets('saving adds a checkmark and a Saved badge to the video tile',
      (tester) async {
    final p = _provider();
    await tester.pumpWidget(_app(
        p,
        Column(children: [
          SizedBox(width: 280, child: VodGridTile(vod: _vod)),
          BookmarkButton(vod: _vod)
        ])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save lecture'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNWidgets(2));
    expect(
        tester
            .widgetList<CaIcon>(find.byType(CaIcon))
            .where((i) => i.glyph == CaGlyph.check),
        hasLength(2));
    final button = tester.widget<CaButton>(find.byType(CaButton));
    expect(button.variant, CaButtonVariant.primary);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('library selection returns the saved playable recording',
      (tester) async {
    final p = _provider()..addStreamerForTests(mockStreamers.first);
    await p.toggleVodBookmark(_vod);
    BookmarkEntry? selected;
    await tester.pumpWidget(_app(
        p,
        Builder(
            builder: (context) => TextButton(
                child: const Text('Open saved'),
                onPressed: () async {
                  selected = await Navigator.of(context).push<BookmarkEntry>(
                      MaterialPageRoute(
                          builder: (_) => ChangeNotifierProvider.value(
                              value: p, child: const BookmarksSheet())));
                }))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved lecture'));
    await tester.pumpAndSettle();
    expect(selected?.vod?.youtubeVideoId, 'bl60n6uuvWE');
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });

  testWidgets('video sheet avatar has no ring', (tester) async {
    StubVideoPlayer.install(addTearDown: addTearDown);
    final p = _provider();
    await tester.pumpWidget(
        _app(p, VodPlayerModalSheet(vod: _vod, streamer: mockStreamers.first)));
    await tester.pumpAndSettle();
    expect(
        tester.widget<CaAvatar>(find.byType(CaAvatar)).ring, CaAvatarRing.none);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });

  for (final language in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('saved library filters and removes $language $width $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final p = _provider()..addStreamerForTests(mockStreamers.first);
          await p.toggleVodBookmark(_vod);
          await p.toggleUpcomingBookmark(_schedule());
          await tester.pumpWidget(_app(p, const BookmarksSheet(),
              language: language, scale: scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final recordingLabel = language == 'en' ? 'Recordings' : 'التسجيلات';
          await tester.tap(find.text(recordingLabel));
          await tester.pumpAndSettle();
          expect(find.text('Upcoming seminar'), findsNothing);
          final remove = find.byWidgetPredicate((w) =>
              w is CaIconButton &&
              w.label ==
                  (language == 'en'
                      ? 'Remove bookmark'
                      : 'إزالة من المحفوظات'));
          await tester.ensureVisible(remove);
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(p.bookmarks, hasLength(1));
          expect(p.bookmarks.single.kind, BookmarkKind.upcoming);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          p.dispose();
        });
      }
    }
  }
}
