import 'dart:async';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/connectivity_service.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/connectivity_banner.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/streamer_grid_card.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_room_connection_view.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/live_stream/services/viewer_presence_service.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/discovery/models/academic_category_model.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';

class _RoomCounts {
  int playersStarted = 0;
  int playersDisposed = 0;
  int chatsStarted = 0;
  int chatsDisposed = 0;
  int presenceStarted = 0;
  int presenceDisposed = 0;
}

class _RoomPlayer extends AbstractVideoPlayer {
  const _RoomPlayer(
      {required super.streamUrl, required this.counts, super.key});
  final _RoomCounts counts;
  @override
  State<_RoomPlayer> createState() => _RoomPlayerState();
}

class _RoomPlayerState extends State<_RoomPlayer> {
  @override
  void initState() {
    super.initState();
    widget.counts.playersStarted++;
  }

  @override
  void dispose() {
    widget.counts.playersDisposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _RoomChat extends LiveChatController {
  _RoomChat(String streamId, this.counts) : super(streamId: streamId);
  final _RoomCounts counts;
  @override
  Future<void> start() async => counts.chatsStarted++;
  @override
  void dispose() {
    counts.chatsDisposed++;
    super.dispose();
  }
}

class _RoomPresence extends ViewerPresenceService {
  _RoomPresence(String streamId, this.counts) : super(streamId: streamId);
  final _RoomCounts counts;
  @override
  Future<void> start() async => counts.presenceStarted++;
  @override
  void dispose() {
    counts.presenceDisposed++;
    super.dispose();
  }
}

class _RoomCatalog extends AdminDatabaseService {
  final pending = <Completer<List<StreamerModel>>>[];
  @override
  Future<int> sweepStaleLiveFlags() async => 0;
  @override
  Future<List<StreamerModel>> loadVerifiedStreamersFromBackend(
      {bool requireSuccess = false}) {
    final request = Completer<List<StreamerModel>>();
    pending.add(request);
    return request.future;
  }
}

class _CategoryCatalog extends AdminDatabaseService {
  final pending = <Completer<List<AcademicCategoryModel>>>[];
  @override
  Future<int> sweepStaleLiveFlags() async => 0;
  @override
  Future<List<StreamerModel>> loadVerifiedStreamersFromBackend(
          {bool requireSuccess = false}) async =>
      [];
  @override
  Future<List<AcademicCategoryModel>> loadAcademicCategories(
      {bool requireSuccess = false}) {
    final request = Completer<List<AcademicCategoryModel>>();
    pending.add(request);
    return request.future;
  }
}

Widget harness(AppProvider provider, String language, Widget home) =>
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
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.forLocale(context.locale),
            home: Scaffold(body: home),
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['en', 'ar']) {
    testWidgets(
        '$language offline banner gives a local retry in the right layout',
        (tester) async {
      final service = ConnectivityService(
        endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
        checkConnectivity: () async => [ConnectivityResult.none],
        connectivityChanges: const Stream.empty(),
        probe: (_) async => throw StateError('Probe must not run offline'),
      );
      final provider = AppProvider.withServices(connectivityService: service);
      provider.debugSetOnlineForTests(false);
      await tester.pumpWidget(harness(
          provider, language, const Column(children: [ConnectivityBanner()])));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('connectivity_banner')), findsOneWidget);
      expect(find.text(language == 'ar' ? 'إعادة المحاولة' : 'Retry'),
          findsOneWidget);
      final bannerContext = tester.element(find.byType(ConnectivityBanner));
      expect(Directionality.of(bannerContext),
          language == 'ar' ? ui.TextDirection.rtl : ui.TextDirection.ltr);
      await tester
          .tap(find.text(language == 'ar' ? 'إعادة المحاولة' : 'Retry'));
      await tester.pumpAndSettle();
      expect(provider.networkStatus, NetworkStatus.offline);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  }

  testWidgets('retry keeps the banner until a fresh catalog succeeds',
      (tester) async {
    var reachable = false;
    final service = ConnectivityService(
      endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
      checkConnectivity: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
      probe: (_) async => reachable,
    );
    final provider = AppProvider.withServices(connectivityService: service);
    await provider.refreshConnectivityNow();
    await tester.pumpWidget(harness(
        provider, 'en', const Column(children: [ConnectivityBanner()])));
    await tester.pumpAndSettle();
    expect(find.text('The service is hard to reach'), findsOneWidget);
    reachable = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(provider.networkStatus, NetworkStatus.online);
    expect(provider.isUsingCachedCatalog, isTrue);
    expect(find.byKey(const ValueKey('connectivity_banner')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('lost connection hides stale LIVE badge and viewer claim',
      (tester) async {
    final provider = AppProvider();
    final staleLive = mockStreamers.first.copyWith(
        isCurrentlyLive: true,
        activeStreamId: 'stale-room',
        activeViewerCount: 88);
    provider.addStreamer(staleLive);
    provider.debugSetOnlineForTests(false);
    expect(provider.streamers.single.activeStreamId, isNull);
    expect(provider.streamers.single.activeViewerCount, 0);
    await tester.pumpWidget(harness(
        provider,
        'en',
        SizedBox(
            width: 220,
            child: StreamerGridCard(streamer: staleLive, langCode: 'en'))));
    await tester.pumpAndSettle();
    expect(
        find.text('Saved listing · live status unavailable'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('degraded room gives a reason and retry without a player',
      (tester) async {
    final service = ConnectivityService(
      endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
      checkConnectivity: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
      probe: (_) async => false,
    );
    final provider = AppProvider.withServices(connectivityService: service);
    await tester.pumpWidget(harness(provider, 'ar',
        const LiveRoomConnectionView(status: NetworkStatus.degraded)));
    await tester.pumpAndSettle();
    expect(find.text('غرفة البث غير متاحة'), findsOneWidget);
    expect(find.text('تعذّر الوصول إلى الخدمة'), findsOneWidget);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(provider.networkStatus, NetworkStatus.degraded);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('wizard input survives a recoverable connection loss',
      (tester) async {
    final provider = AppProvider();
    await tester
        .pumpWidget(harness(provider, 'en', const StreamerApplyScreen()));
    await tester.pumpAndSettle();
    final nameField = find.byType(TextField).first;
    await tester.enterText(nameField, 'Unsent applicant name');
    provider.debugSetOnlineForTests(false);
    await tester.pump();
    expect(find.text('Unsent applicant name'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('whole room stops media and services, then cleanly restarts',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final counts = _RoomCounts();
    final catalog = _RoomCatalog();
    final provider = AppProvider.withServices(adminDbService: catalog);
    final live = mockStreamers.first.copyWith(
      isCurrentlyLive: true,
      broadcastType: BroadcastType.liveVideo,
      activeStreamId: 'verifiedRm1',
      avatarUrl: '',
      bannerUrl: '',
    );
    provider.addStreamer(live);
    LiveBroadcastScreen.debugChatFactory =
        (id, reaction) => _RoomChat(id, counts);
    LiveBroadcastScreen.debugPresenceFactory =
        (id) => _RoomPresence(id, counts);
    AbstractVideoPlayer.debugPlayerFactory = ({
      Key? key,
      required StreamSourceType sourceType,
      required String streamUrl,
      bool autoPlay = true,
      VoidCallback? onPlayerReady,
      ValueChanged<StreamState>? onStateChanged,
      ValueChanged<String>? onError,
      double aspectRatio = 16 / 9,
      String preferredQuality = 'auto',
      List<String> fallbackUrls = const [],
      bool initialMuted = false,
    }) =>
        _RoomPlayer(key: key, streamUrl: streamUrl, counts: counts);
    addTearDown(() {
      LiveBroadcastScreen.debugChatFactory = null;
      LiveBroadcastScreen.debugPresenceFactory = null;
      AbstractVideoPlayer.debugPlayerFactory = null;
    });

    await tester.pumpWidget(harness(
        provider, 'en', const LiveBroadcastScreen(streamId: 'verifiedRm1')));
    await tester.pump();
    expect(catalog.pending, hasLength(1));
    catalog.pending.removeAt(0).complete([live]);
    await tester.pump();
    expect(counts.playersStarted, 1);
    expect(counts.chatsStarted, 1);
    expect(counts.presenceStarted, 1);

    provider.debugSetOnlineForTests(false);
    await tester.pump();
    expect(find.byType(LiveRoomConnectionView), findsOneWidget);
    expect(counts.playersDisposed, 1);
    expect(counts.chatsDisposed, 1);
    expect(counts.presenceDisposed, 1);

    provider.debugSetOnlineForTests(true);
    await tester.pump();
    await tester.pump();
    expect(catalog.pending, hasLength(1));
    expect(counts.playersStarted, 1);
    expect(find.text('Checking this live room'), findsOneWidget);
    for (final request in List.of(catalog.pending)) {
      request.complete([live]);
    }
    catalog.pending.clear();
    await tester.pump();
    await tester.pump();
    expect(counts.playersStarted, 2);
    expect(counts.chatsStarted, 2);
    expect(counts.presenceStarted, 2);

    provider.debugSetOnlineForTests(false);
    await tester.pump();
    provider.debugSetOnlineForTests(true);
    await tester.pump();
    await tester.pump();
    expect(catalog.pending, hasLength(1));
    for (final request in List.of(catalog.pending)) {
      request.complete([
        live.copyWith(
            isCurrentlyLive: false,
            broadcastType: BroadcastType.offline,
            clearLiveState: true)
      ]);
    }
    catalog.pending.clear();
    await tester.pump();
    await tester.pump();
    // A fresh successful catalog confirmed that this previously live session
    // ended. Only failed/stale reads should retain the uncertainty message.
    expect(find.text('This broadcast has ended'), findsOneWidget);
    expect(counts.playersStarted, 2);
    expect(counts.playersDisposed, 2);
    expect(counts.chatsDisposed, 2);
    expect(counts.presenceDisposed, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  testWidgets('banner Retry coalesces recovery and ignores stale catalog',
      (tester) async {
    var reachable = false;
    final service = ConnectivityService(
      endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
      checkConnectivity: () async => [ConnectivityResult.wifi],
      connectivityChanges: const Stream.empty(),
      probe: (_) async => reachable,
    );
    final catalog = _RoomCatalog();
    final provider = AppProvider.withServices(
        adminDbService: catalog, connectivityService: service);
    final live = mockStreamers.first.copyWith(
      isCurrentlyLive: true,
      broadcastType: BroadcastType.liveVideo,
      activeStreamId: 'outage-room',
    );
    provider.addStreamer(live);
    await tester.pumpWidget(harness(
        provider, 'en', const Column(children: [ConnectivityBanner()])));
    await tester.pump();
    expect(catalog.pending, hasLength(1));
    final oldRequest = catalog.pending.removeAt(0);

    await provider.refreshConnectivityNow();
    await tester.pump();
    expect(provider.networkStatus, NetworkStatus.degraded);
    expect(provider.isUsingCachedCatalog, isTrue);
    expect(provider.streamers.single.isCurrentlyLive, isFalse);

    reachable = true;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(provider.networkStatus, NetworkStatus.online);
    expect(catalog.pending, hasLength(1));
    final recoveryRequest = catalog.pending.removeAt(0);
    final duplicate = provider.loadVerifiedStreamersFromBackend();
    expect(catalog.pending, isEmpty);

    oldRequest.complete([live]);
    await tester.pump();
    expect(provider.isUsingCachedCatalog, isTrue);
    expect(provider.streamers.single.isCurrentlyLive, isFalse);

    recoveryRequest.completeError(StateError('backend outage'));
    await tester.pump();
    // The duplicate was asked after the recovery read began, so it is
    // answered by exactly one fresh read, never by the older response
    // (P6S wave 3: stale catalog responses).
    expect(catalog.pending, hasLength(1));
    catalog.pending.removeAt(0).completeError(StateError('backend outage'));
    await duplicate;
    await tester.pump();
    await tester.pump();
    expect(provider.isUsingCachedCatalog, isTrue);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(catalog.pending, hasLength(1));
    catalog.pending.removeAt(0).complete([live]);
    await tester.pump();
    await tester.pump();
    expect(provider.isUsingCachedCatalog, isFalse);
    expect(provider.streamers.single.isCurrentlyLive, isTrue);
    expect(find.byKey(const ValueKey('connectivity_banner')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
  });

  test('category loading shares one request and retries after failure',
      () async {
    final catalog = _CategoryCatalog();
    final provider = AppProvider.withServices(adminDbService: catalog);
    final first = provider.ensureAcademicCategoriesLoaded();
    final duplicate = provider.ensureAcademicCategoriesLoaded();
    expect(catalog.pending, hasLength(1));
    catalog.pending.removeAt(0).completeError(StateError('offline'));
    await Future.wait([first, duplicate]);
    expect(provider.isUsingCachedCatalog, isFalse);
    final retry = provider.ensureAcademicCategoriesLoaded();
    expect(catalog.pending, hasLength(1));
    catalog.pending.removeAt(0).complete([
      const AcademicCategoryModel(
          id: 'science', nameEn: 'Science', nameAr: 'علوم')
    ]);
    await retry;
    expect(provider.academicCategories.single.id, 'science');
    provider.dispose();
  });
}
