import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';
// P6S wave 3, group 1: regressions for the completed 2026-09-25 owner retest.
//  * The viewer room played the IFrame API sample video instead of the phone
//    broadcast: it read the profile's featured youtube_video_id (never set by
//    a phone broadcast) and the adapter substituted M7lc1UVf-VE.
//  * The receiving phone kept showing LIVE after a transfer: the room ignored
//    catalog updates while online, its LIVE badge ignored server state, and a
//    catalog request could be answered by an older in-flight read.
//  * Admin End read as "this device lost its primary session".
//  * A refused Google sign-in was dropped without any explanation.
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/core/providers/app_flags.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/device_session_presenter.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_player_overlay_controls.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/live_stream/services/viewer_presence_service.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';
import 'support/empty_broadcasts.dart';

const _sampleVideo = 'M7lc1UVf-VE';

class _Counts {
  final urls = <String>[];
  int playersDisposed = 0;
  int chatsStarted = 0;
  int chatsDisposed = 0;
  int presenceDisposed = 0;
}

class _Player extends AbstractVideoPlayer {
  const _Player({required super.streamUrl, required this.counts, super.key});
  final _Counts counts;
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> {
  @override
  void initState() {
    super.initState();
    widget.counts.urls.add(widget.streamUrl);
  }

  @override
  void dispose() {
    widget.counts.playersDisposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

class _Chat extends LiveChatController {
  _Chat(String id, this.counts) : super(streamId: id);
  final _Counts counts;
  @override
  Future<void> start() async => counts.chatsStarted++;
  @override
  void dispose() {
    counts.chatsDisposed++;
    super.dispose();
  }
}

class _Presence extends ViewerPresenceService {
  _Presence(String id, this.counts) : super(streamId: id);
  final _Counts counts;
  @override
  Future<void> start() async {}
  @override
  void dispose() {
    counts.presenceDisposed++;
    super.dispose();
  }
}

class _Catalog extends AdminDatabaseService {
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

Widget _room(AppProvider provider, String streamId, {String lang = 'en'}) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
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
            home: LiveBroadcastScreen(streamId: streamId),
          ),
        ),
      ),
    );

class _Auth extends SupabaseAuthService {
  final changes = StreamController<AuthState>.broadcast(sync: true);
  Session? session;
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => changes.stream;
  int oauthLaunches = 0;
  @override
  Future<void> signInWithGoogle() async => oauthLaunches++;

  void signIn(String id) {
    session = Session(
        accessToken: 'test-only',
        tokenType: 'bearer',
        user: User(
            id: id,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-09-25T00:00:00Z',
            email: '$id@example.invalid'));
    changes.add(AuthState(AuthChangeEvent.signedIn, session));
  }
}

/// An approved broadcaster whose device claim succeeds; the broadcast status
/// read is scripted per test.
class _BroadcasterDb extends AdminDatabaseService {
  final devices = StreamController<List<DeviceSessionModel>>.broadcast();
  Completer<Map<String, dynamic>>? statusRead;
  Object? statusError;
  Map<String, dynamic> status = {'live': true, 'stream_id': 'LIVEvideo01'};
  int statusReads = 0;
  final liveWrites = <bool>[];
  String? sessionToReturn = 'session-1';
  Completer<String?>? startGate;
  Object? ingestError;
  final ingestReports = <bool>[];
  final endedSessions = <String>[];

  @override
  Future<String?> startBroadcastSession(
      {required String type,
      required String streamId,
      required String deviceId,
      required String senderMode,
      String? orgId}) async {
    liveWrites.add(true);
    if (startGate != null) return startGate!.future;
    return sessionToReturn;
  }

  @override
  Future<void> reportBroadcastIngest(
      {required String sessionId,
      required String deviceId,
      required bool sending}) async {
    if (ingestError != null) throw ingestError!;
    ingestReports.add(sending);
  }

  @override
  Future<void> endBroadcastSession(
      {required String sessionId, required String deviceId}) async {
    endedSessions.add(sessionId);
  }

  @override
  Future<bool> checkIsProfileStreamer(String id) async => true;
  @override
  Future<Map<String, dynamic>?> loadOwnProfile(String id) async =>
      {'display_name_en': 'C', 'is_streamer': true, 'is_verified': true};
  @override
  Future<DeviceClaimResult> claimDeviceState(DeviceSessionModel device,
          {bool force = false}) async =>
      const DeviceClaimResult(claimed: true);
  @override
  Stream<List<DeviceSessionModel>> watchDevices(String userId) =>
      devices.stream;
  @override
  Future<bool> heartbeatDevice(String deviceId) async => true;
  @override
  Future<int> sweepStaleLiveFlags() async => 0;
  @override
  Future<List<StreamerModel>> loadVerifiedStreamersFromBackend(
          {bool requireSuccess = false}) async =>
      [];
  @override
  Future<void> setLiveState(
      {required bool live,
      required String type,
      required String? streamId,
      required String deviceId,
      String? orgId}) async {
    liveWrites.add(live);
  }

  @override
  Future<Map<String, dynamic>> loadMyBroadcastStatus() {
    statusReads++;
    if (statusError != null) return Future.error(statusError!);
    return statusRead?.future ?? Future.value(status);
  }
}

class _CanonicalBroadcasts extends EmptyBroadcasts {
  _CanonicalBroadcasts(this.db);
  final _BroadcasterDb db;
  static const destination=ChannelConnection(id:'connection',ownerId:'c',organizationId:null,channelId:'UC_test',title:'Channel',status:'connected',revision:1);
  final row=<String,dynamic>{'id':'session-1','owner_id':'c','state':'preparing','revision':1,
    'title_en':'Phone','broadcast_type':'liveVideo','channel_connection_id':'connection',
    'sender_mode':'phone_direct','stream_id':'LIVEvideo01','accepted_at':'2026-10-01'};
  @override Future<BroadcastSession?> session(String id) async=>BroadcastSession.fromRow(row);
  @override Future<Map<String,dynamic>> control(String sessionId,String deviceId,String sender,String action,{ChannelConnection? destination}) async {
    if(action=='prepare') {row['state']='preparing';return {'session':Map<String,dynamic>.of(row),'ingest_url':'rtmps://a.rtmps.youtube.com/live2','ingest_key':'test-key'};}
    if(action=='start') {db.liveWrites.add(true);if(db.startGate!=null)await db.startGate!.future;row['state']='live';}
    if(action=='end') {db.endedSessions.add(sessionId);row['state']='completed';}
    return {'session':Map<String,dynamic>.of(row)};
  }
}

class _RoomBroadcasts extends EmptyBroadcasts {
  final rows=<String,Map<String,dynamic>>{};
  @override Future<List<BroadcastSession>> sessions({String? organizationId,bool mine=false}) async =>
    rows.values.where((r)=>r['hidden_from_discovery']!=true).map(BroadcastSession.fromRow).toList();
  @override Future<BroadcastSession?> session(String id) async=>rows[id]==null?null:BroadcastSession.fromRow(rows[id]!);
}
class _RoomCatalog extends AdminDatabaseService {
  @override Future<int> sweepStaleLiveFlags() async=>0;
  @override Future<List<StreamerModel>> loadVerifiedStreamersFromBackend({bool requireSuccess=false}) async=>[
    mockStreamers.first.copyWith(avatarUrl:'',bannerUrl:'',isCurrentlyLive:false,clearLiveState:true)];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('viewer room identity', () {
    late _Counts counts;
    setUp(() {
      counts = _Counts();
      LiveBroadcastScreen.debugChatFactory = (id, _) => _Chat(id, counts);
      LiveBroadcastScreen.debugPresenceFactory = (id) => _Presence(id, counts);
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
          _Player(key: key, streamUrl: streamUrl, counts: counts);
    });
    tearDown(() {
      LiveBroadcastScreen.debugChatFactory = null;
      LiveBroadcastScreen.debugPresenceFactory = null;
      AbstractVideoPlayer.debugPlayerFactory = null;
    });

    Future<(AppProvider, _Catalog)> openRoom(
        WidgetTester tester, StreamerModel streamer, String roomId,
        {List<StreamerModel> others = const []}) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = _Catalog();
      final provider = AppProvider.withServices(organizationBroadcastService:EmptyBroadcasts(),adminDbService: catalog);
      for (final s in [...others, streamer]) {
        provider.addStreamer(s);
      }
      await tester.pumpWidget(_room(provider, roomId));
      await tester.pump();
      catalog.pending.removeAt(0).complete([...others, streamer]);
      await tester.pump();
      await tester.pump();
      return (provider, catalog);
    }

    final phoneLive = mockStreamers.first.copyWith(
      isCurrentlyLive: true,
      broadcastType: BroadcastType.liveVideo,
      activeStreamId: 'LIVEvideo01',
      youtubeVideoId: '',
      avatarUrl: '',
      bannerUrl: '',
    );

    testWidgets('hidden canonical room uses exact chat ID and becomes a read-only replay', (tester) async {
      tester.view.physicalSize=const Size(1280,800);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.reset);
      const id='11111111-1111-4111-8111-111111111111';
      final broadcasts=_RoomBroadcasts();
      broadcasts.rows[id]={'id':id,'owner_id':'presenter','org_id':mockStreamers.first.streamerId,
        'state':'live','revision':1,'title_en':'Hidden show','broadcast_type':'liveVideo',
        'stream_id':'LIVEvideo01','hidden_from_discovery':true};
      final chatIds=<String>[];
      LiveBroadcastScreen.debugChatFactory=(id,_) {chatIds.add(id);return _Chat(id,counts);};
      final p=AppProvider.withServices(organizationBroadcastService:broadcasts,adminDbService:_RoomCatalog());
      await tester.pumpWidget(_room(p,id));
      await tester.pump(const Duration(milliseconds:100));await tester.pump();
      expect(counts.urls,['LIVEvideo01']);expect(chatIds,[id]);
      expect(p.streamers.any((s)=>s.streamerId==id),isFalse);
      broadcasts.rows[id]!['state']='processing_replay';
      broadcasts.rows[id]!['replay_status']='processing';
      await p.refreshBroadcastRoom(id);await tester.pump(const Duration(milliseconds:100));await tester.pump();
      expect(find.text('organization_v1.replay_processing'.tr()),findsOneWidget);
      expect(counts.chatsDisposed,1);
      broadcasts.rows[id]!['state']='completed';
      broadcasts.rows[id]!['replay_status']='available';
      await p.refreshBroadcastRoom(id);await tester.pump(const Duration(milliseconds:100));await tester.pump();
      expect(counts.urls,['LIVEvideo01','LIVEvideo01']);
      expect(find.text('organization_v1.replay_chat_read_only'.tr()),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());p.dispose();
    });

    test('concurrent shows keep separate identities and denied room reads invalidate the catalog',() async {
      final broadcasts=_RoomBroadcasts();
      for(final id in ['one','two']) {
        broadcasts.rows[id]={'id':id,'owner_id':'presenter-$id','org_id':mockStreamers.first.streamerId,
          'state':'live','revision':1,'title_en':id,'broadcast_type':'liveVideo','stream_id':'LIVEvideo01'};
      }
      final p=AppProvider.withServices(organizationBroadcastService:broadcasts,adminDbService:_RoomCatalog());
      await p.loadVerifiedStreamersFromBackend();
      expect(p.roomChoices(mockStreamers.first.streamerId).map((s)=>s.id),['one','two']);
      expect(p.getRoomStreamer(mockStreamers.first.streamerId),isNull);
      expect(p.getRoomStreamer('two')?.liveSessionId,'two');
      broadcasts.rows.remove('two');await p.refreshBroadcastRoom('two');
      expect(p.getRoomStreamer('two'),isNull);
      expect(p.getRoomStreamer('one')?.liveSessionId,'one');
      p.dispose();
    });

    testWidgets('a phone broadcast plays its exact live watch ID',
        (tester) async {
      await openRoom(tester, phoneLive, phoneLive.streamerId);
      expect(counts.urls, ['LIVEvideo01']);
      expect(counts.urls, isNot(contains(_sampleVideo)));
    });

    testWidgets('a live room never plays the profile featured video',
        (tester) async {
      await openRoom(tester, phoneLive.copyWith(youtubeVideoId: 'FEATURED001'),
          phoneLive.streamerId);
      expect(counts.urls, ['LIVEvideo01']);
    });

    testWidgets('a live channel with no valid watch ID plays nothing',
        (tester) async {
      await openRoom(
          tester,
          phoneLive.copyWith(activeStreamId: 'not-an-id', youtubeVideoId: ''),
          phoneLive.streamerId);
      expect(counts.urls, isEmpty,
          reason: 'no substitute video, sample or otherwise');
    });

    testWidgets('an unknown room never borrows another streamer',
        (tester) async {
      await openRoom(tester, phoneLive, 'no-such-room',
          others: [mockStreamers[1].copyWith(youtubeVideoId: 'OTHERvideo1')]);
      expect(find.byKey(const Key('live-room-unavailable')), findsOneWidget);
      expect(counts.urls, isEmpty);
      expect(counts.chatsStarted, 0);
    });

    testWidgets(
        'fresh catalog data that ends the broadcast closes the room, its '
        'player, chat and LIVE badge', (tester) async {
      final (provider, catalog) =
          await openRoom(tester, phoneLive, phoneLive.streamerId);
      expect(counts.urls, ['LIVEvideo01']);
      unawaited(provider.loadVerifiedStreamersFromBackend());
      await tester.pump();
      catalog.pending.removeAt(0).complete([
        phoneLive.copyWith(
            isCurrentlyLive: false,
            broadcastType: BroadcastType.offline,
            clearLiveState: true),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('live-room-ended')), findsOneWidget);
      expect(find.text('This broadcast has ended'), findsOneWidget);
      expect(find.text('LIVE'), findsNothing);
      expect(counts.playersDisposed, 1);
      expect(counts.chatsDisposed, 1);
      expect(counts.presenceDisposed, 1);
    });

    testWidgets(
        'without any Realtime event the room re-reads the catalog and closes '
        'within about 20 seconds of the broadcast ending', (tester) async {
      final (_, catalog) =
          await openRoom(tester, phoneLive, phoneLive.streamerId);
      expect(catalog.pending, isEmpty);
      await tester.pump(const Duration(seconds: 21));
      expect(catalog.pending, hasLength(1),
          reason: 'viewers are not sent other accounts profile changes');
      catalog.pending.removeAt(0).complete(
          [phoneLive.copyWith(isCurrentlyLive: false, clearLiveState: true)]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('live-room-ended')), findsOneWidget);
    });

    testWidgets('a different broadcast on the same channel also ends the room',
        (tester) async {
      final (provider, catalog) =
          await openRoom(tester, phoneLive, phoneLive.streamerId);
      unawaited(provider.loadVerifiedStreamersFromBackend());
      await tester.pump();
      catalog.pending
          .removeAt(0)
          .complete([phoneLive.copyWith(activeStreamId: 'NEWvideo002')]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('live-room-ended')), findsOneWidget);
      expect(counts.urls, ['LIVEvideo01']);
    });

    testWidgets('ordinary End during a viewer network interruption is terminal',
        (tester) async {
      final (provider, catalog) =
          await openRoom(tester, phoneLive, phoneLive.streamerId);
      provider.debugSetOnlineForTests(false);
      await tester.pump();
      provider.debugSetOnlineForTests(true);
      await tester.pump();
      for (final request in List.of(catalog.pending)) {
        request.complete([
          phoneLive.copyWith(isCurrentlyLive: false, clearLiveState: true),
        ]);
      }
      catalog.pending.clear();
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('live-room-ended')), findsOneWidget);
      expect(counts.playersDisposed, 1);
      expect(counts.urls, ['LIVEvideo01']);
    });

    testWidgets('same-watch replacement cannot take over an open viewer',
        (tester) async {
      final (provider, catalog) = await openRoom(
          tester,
          phoneLive.copyWith(liveSessionId: 'session-old'),
          phoneLive.streamerId);
      unawaited(provider.loadVerifiedStreamersFromBackend());
      await tester.pump();
      catalog.pending.removeAt(0).complete([
        phoneLive.copyWith(liveSessionId: 'session-new'),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('live-room-ended')), findsOneWidget);
      expect(counts.urls, ['LIVEvideo01']);
    });

    testWidgets('a broadcast hidden from discovery still plays in its room',
        (tester) async {
      final hidden =
          phoneLive.copyWith(isCurrentlyLive: false, isHiddenLiveSession: true);
      expect(hidden.isCurrentlyLive, isFalse,
          reason: 'feed and map do not list it as live');
      await openRoom(tester, hidden, 'LIVEvideo01');
      expect(counts.urls, ['LIVEvideo01']);
      expect(find.byKey(const Key('live-room-ended')), findsNothing);
    });

    testWidgets('a hidden broadcast room recovers after a connection drop',
        (tester) async {
      final hidden =
          phoneLive.copyWith(isCurrentlyLive: false, isHiddenLiveSession: true);
      final (provider, catalog) = await openRoom(tester, hidden, 'LIVEvideo01');
      provider.debugSetOnlineForTests(false);
      await tester.pump();
      provider.debugSetOnlineForTests(true);
      await tester.pump();
      await tester.pump();
      for (final r in List.of(catalog.pending)) {
        r.complete([hidden]);
      }
      catalog.pending.clear();
      await tester.pump();
      await tester.pump();
      expect(counts.urls, ['LIVEvideo01', 'LIVEvideo01'],
          reason: 'the room restarts on the same broadcast');
      expect(find.byKey(const Key('live-room-ended')), findsNothing);
    });

    testWidgets('a room opened before the catalog has it keeps looking',
        (tester) async {
      final (provider, catalog) =
          await openRoom(tester, mockStreamers[1], 'LIVEvideo01');
      expect(find.byKey(const Key('live-room-unavailable')), findsOneWidget);
      expect(find.byKey(const Key('live-room-check-again')), findsOneWidget);
      await tester.pump(const Duration(seconds: 11));
      expect(catalog.pending, isNotEmpty);
      catalog.pending.removeAt(0).complete([mockStreamers[1], phoneLive]);
      await tester.pump();
      await tester.pump();
      expect(counts.urls, ['LIVEvideo01']);
      expect(provider.streamers.any((s) => s.liveWatchId == 'LIVEvideo01'),
          isTrue);
    });

    testWidgets(
        'an interrupted phone broadcast shows reconnecting, not a LIVE badge',
        (tester) async {
      final interrupted = phoneLive.copyWith(liveIngestState: 'interrupted');
      expect(interrupted.isIngestInterrupted, isTrue);
      await openRoom(tester, interrupted, interrupted.streamerId);
      expect(counts.urls, ['LIVEvideo01'],
          reason: 'the room keeps the same player while the phone reconnects');
      expect(find.byKey(const Key('live-room-reconnecting')), findsOneWidget);
      expect(find.textContaining("broadcaster's connection dropped"),
          findsOneWidget);
    });

    testWidgets('the ended room reads correctly in Arabic', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final catalog = _Catalog();
      final provider = AppProvider.withServices(organizationBroadcastService:EmptyBroadcasts(),adminDbService: catalog);
      provider.addStreamer(phoneLive);
      await tester
          .pumpWidget(_room(provider, phoneLive.streamerId, lang: 'ar'));
      await tester.pump();
      catalog.pending.removeAt(0).complete([phoneLive]);
      await tester.pump();
      unawaited(provider.loadVerifiedStreamersFromBackend());
      await tester.pump();
      catalog.pending.removeAt(0).complete(
          [phoneLive.copyWith(isCurrentlyLive: false, clearLiveState: true)]);
      await tester.pump();
      await tester.pump();
      expect(find.text('انتهى هذا البث'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('catalog freshness', () {
    test('a request made during a load gets one fresh follow-up read',
        () async {
      final catalog = _Catalog();
      final provider = AppProvider.withServices(organizationBroadcastService:EmptyBroadcasts(),adminDbService: catalog);
      addTearDown(provider.dispose);
      await Future<void>.delayed(Duration.zero);
      expect(catalog.pending, hasLength(1));
      final first = catalog.pending.removeAt(0);
      final live = mockStreamers.first
          .copyWith(isCurrentlyLive: true, activeStreamId: 'LIVEvideo01');
      final asked = provider.loadVerifiedStreamersFromBackend();
      final askedAgain = provider.loadVerifiedStreamersFromBackend();
      expect(catalog.pending, isEmpty);
      first.complete([live]);
      await Future<void>.delayed(Duration.zero);
      expect(catalog.pending, hasLength(1),
          reason: 'the older response cannot answer the newer request');
      catalog.pending.removeAt(0).complete([
        live.copyWith(isCurrentlyLive: false, clearLiveState: true),
      ]);
      await asked;
      await askedAgain;
      expect(catalog.pending, isEmpty,
          reason: 'several requests during one load share one follow-up');
      expect(
          provider.streamers
              .firstWhere((s) => s.streamerId == live.streamerId)
              .isCurrentlyLive,
          isFalse);
    });
  });

  group('broadcast ended by the server', () {
    Future<(AppProvider, GoRouter, DeviceSessionPresenter, _Auth)> launch(
        WidgetTester tester, _BroadcasterDb db) async {
      final auth = _Auth();
      final provider =
          AppProvider.withServices(organizationBroadcastService:_CanonicalBroadcasts(db),authService: auth, adminDbService: db);
      final router = AppRouter.build(provider);
      final presenter =
          DeviceSessionPresenter(provider: provider, router: router)..attach();
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: Builder(
          builder: (context) => ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ));
      await tester.pump();
      auth.signIn('c');
      await settle(tester);
      return (provider, router, presenter, auth);
    }

    Future<void> teardown(
        WidgetTester tester,
        AppProvider provider,
        GoRouter router,
        DeviceSessionPresenter presenter,
        _BroadcasterDb db) async {
      presenter.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      provider.dispose();
      await db.devices.close();
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets(
        'admin End stops LIVE but keeps the device, mode and approval, and '
        'says who ended it', (tester) async {
      final db = _BroadcasterDb();
      final (provider, router, presenter, _) = await launch(tester, db);
      expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isTrue);
      provider.setBroadcastingLiveForTesting(true);
      db.status = {
        'live': false,
        'last_ended': {'reason': 'admin_end'},
      };
      await provider.onAppResumed();
      await settle(tester);

      expect(provider.isBroadcastingLive, isFalse);
      expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isTrue);
      expect(provider.isStreamerModeEnabled, isTrue);
      expect(provider.isApprovedStreamer, isTrue);
      expect(provider.broadcastSessionError, isNull,
          reason: 'not the "lost its primary session" message');
      expect(provider.remoteBroadcastEndReason, 'admin_end');
      expect(
          find.byKey(const Key('broadcast-remote-end-dialog')), findsOneWidget);
      expect(find.textContaining('An administrator ended this broadcast'),
          findsOneWidget);
      expect(find.text('broadcast_session_lost'.tr()), findsNothing);
      await teardown(tester, provider, router, presenter, db);
    });

    testWidgets('a real device transfer still reports the lost device',
        (tester) async {
      final db = _BroadcasterDb();
      final (provider, router, presenter, _) = await launch(tester, db);
      provider.setBroadcastingLiveForTesting(true);
      db.status = {
        'live': false,
        'last_ended': {'reason': 'device_transfer'},
      };
      await provider.onAppResumed();
      await settle(tester);
      expect(provider.broadcastSessionError, 'broadcast_session_lost');
      expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isFalse);
      await teardown(tester, provider, router, presenter, db);
    });

    testWidgets(
        'a status read that started before this device went live is ignored',
        (tester) async {
      final db = _BroadcasterDb();
      final (provider, router, presenter, _) = await launch(tester, db);
      provider.setBroadcastingLiveForTesting(true);
      final read = Completer<Map<String, dynamic>>();
      db.statusRead = read;
      final resumed = provider.onAppResumed();
      await tester.pump();
      expect(db.statusReads, greaterThanOrEqualTo(1));
      // This device withdraws and re-asserts LIVE while the read is out.
      await provider.setBroadcasterLive(false);
      await provider.prepareBroadcast('session-1','phone_direct',_CanonicalBroadcasts.destination);
      await provider.setBroadcasterLive(true);
      read.complete({
        'live': false,
        'last_ended': {'reason': 'admin_end'},
      });
      await resumed;
      await settle(tester);
      expect(provider.isBroadcastingLive, isTrue);
      expect(provider.remoteBroadcastEndReason, isNull);
      await teardown(tester, provider, router, presenter, db);
    });

    testWidgets('an unreadable status changes nothing', (tester) async {
      final db = _BroadcasterDb();
      final (provider, router, presenter, _) = await launch(tester, db);
      provider.setBroadcastingLiveForTesting(true);
      db.statusError = Exception('offline');
      await provider.onAppResumed();
      await settle(tester);
      expect(provider.isBroadcastingLive, isTrue);
      await teardown(tester, provider, router, presenter, db);
    });
  });

  group('session-fenced broadcasting', () {
    testWidgets(
        'a late start response cannot restore a displaced device session',
        (tester) async {
      final auth = _Auth();
      final db = _BroadcasterDb();
      final provider =
          AppProvider.withServices(organizationBroadcastService:_CanonicalBroadcasts(db),authService: auth, adminDbService: db);
      auth.signIn('c');
      await settle(tester);
      provider.setCustomStreamerYouTubeUrl('LIVEvideo01');
      await provider.prepareBroadcast('session-1','phone_direct',_CanonicalBroadcasts.destination);
      db.startGate = Completer<String?>();
      final starting = provider.setBroadcasterLive(true);
      await tester.pump();
      provider.applyDeviceSessions([
        DeviceSessionModel(
            deviceId: 'other-device',
            deviceName: 'Other',
            platform: 'android',
            lastActiveAt: DateTime.now(),
            isPrimaryBroadcaster: true)
      ]);
      db.startGate!.complete('displaced-session');
      await starting;
      expect(provider.liveSessionId, isNull);
      expect(provider.isBroadcastingLive, isFalse);
      provider.dispose();
      await db.devices.close();
    });
    Future<(AppProvider, GoRouter, DeviceSessionPresenter)> start(
        WidgetTester tester, _BroadcasterDb db) async {
      final auth = _Auth();
      final provider =
          AppProvider.withServices(organizationBroadcastService:_CanonicalBroadcasts(db),authService: auth, adminDbService: db);
      final router = AppRouter.build(provider);
      final presenter =
          DeviceSessionPresenter(provider: provider, router: router)..attach();
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: Builder(
          builder: (context) => ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ));
      await tester.pump();
      auth.signIn('c');
      await settle(tester);
      provider.setCustomStreamerYouTubeUrl('LIVEvideo01');
      provider.setBroadcastSenderMode('phone_direct');
      await provider.prepareBroadcast('session-1','phone_direct',_CanonicalBroadcasts.destination);
      await provider.setBroadcasterLive(true);
      expect(provider.isBroadcastingLive, isTrue);
      expect(provider.liveSessionId, 'session-1');
      return (provider, router, presenter);
    }

    Future<void> stop(
        WidgetTester tester,
        AppProvider provider,
        GoRouter router,
        DeviceSessionPresenter presenter,
        _BroadcasterDb db) async {
      presenter.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      provider.dispose();
      await db.devices.close();
      await tester.pump(const Duration(seconds: 2));
    }

    testWidgets(
        'a reconnect after an admin End is refused and stops the phone; LIVE '
        'is not re-asserted', (tester) async {
      final db = _BroadcasterDb();
      final (provider, router, presenter) = await start(tester, db);
      expect(await provider.reportBroadcastIngest(sending: false), isTrue,
          reason: 'a network blip is reported, LIVE is not withdrawn');
      expect(provider.isBroadcastingLive, isTrue);
      db.ingestError = const PostgrestException(
          message: 'Broadcast session ended', code: '55000');
      db.status = {
        'live': false,
        'last_ended': {'reason': 'admin_end'},
      };
      expect(await provider.reportBroadcastIngest(sending: true), isFalse);
      await settle(tester);
      expect(provider.isBroadcastingLive, isFalse);
      expect(provider.remoteBroadcastEndReason, 'admin_end');
      expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isTrue);
      expect(db.liveWrites, [true], reason: 'no automatic second start');
      await stop(tester, provider, router, presenter, db);
    });

    testWidgets('editing the watch link while live does not end the broadcast',
        (tester) async {
      final db = _BroadcasterDb();
      final (provider, router, presenter) = await start(tester, db);
      provider.setCustomStreamerYouTubeUrl('OTHERlink02');
      db.status = {
        'live': true,
        'stream_id': 'LIVEvideo01',
        'session_id': 'session-1',
      };
      await provider.onAppResumed();
      await settle(tester);
      expect(provider.isBroadcastingLive, isTrue);
      expect(provider.remoteBroadcastEndReason, isNull);
      await stop(tester, provider, router, presenter, db);
    });

    testWidgets('ending uses the exact session', (tester) async {
      final db = _BroadcasterDb();
      final (provider, router, presenter) = await start(tester, db);
      await provider.setBroadcasterLive(false);
      expect(db.endedSessions, ['session-1']);
      expect(provider.liveSessionId, isNull);
      await stop(tester, provider, router, presenter, db);
    });
  });

  group('refused Google sign-in', () {
    testWidgets(
        'paused sign-ups explain the refusal and name the account still '
        'signed in', (tester) async {
      final db = _BroadcasterDb();
      final auth = _Auth();
      final provider =
          AppProvider.withServices(organizationBroadcastService:_CanonicalBroadcasts(db),authService: auth, adminDbService: db);
      final router = AppRouter.build(provider);
      final presenter =
          DeviceSessionPresenter(provider: provider, router: router)..attach();
      await tester.pumpWidget(EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        startLocale: const Locale('en'),
        saveLocale: false,
        path: 'assets/i18n',
        assetLoader: const DirectJsonAssetLoader(),
        child: Builder(
          builder: (context) => ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp.router(
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              locale: context.locale,
              routerConfig: router,
            ),
          ),
        ),
      ));
      await tester.pump();
      auth.signIn('existing');
      await settle(tester);
      AppFlags.instance.debugSetValues({AppFlagKey.registrationsOpen: false});
      addTearDown(() => AppFlags.instance
          .debugSetValues({AppFlagKey.registrationsOpen: true}));

      // A token refresh failure is not a sign-in refusal.
      auth.changes.addError(AuthRetryableFetchException(message: 'offline'));
      await settle(tester);
      expect(find.byKey(const Key('auth-refusal-dialog')), findsNothing);
      // Nor is an auth error when this client started no sign-in.
      auth.changes
          .addError(const AuthException('Database error saving new user'));
      await settle(tester);
      expect(find.byKey(const Key('auth-refusal-dialog')), findsNothing);

      await provider.loginWithGoogle();
      expect(auth.oauthLaunches, 1);
      auth.changes.addError(const AuthException(
          'Database error saving new user',
          statusCode: 'unexpected_failure',
          code: 'server_error'));
      await settle(tester);

      expect(find.byKey(const Key('auth-refusal-dialog')), findsOneWidget);
      expect(find.text('No new account was created'), findsOneWidget);
      expect(find.textContaining('New sign-ups are paused'), findsOneWidget);
      expect(find.textContaining('existing@example.invalid'), findsOneWidget);
      expect(provider.currentUserEmail, 'existing@example.invalid',
          reason: 'the refusal signs nobody in or out');
      presenter.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      provider.dispose();
      await db.devices.close();
      await tester.pump(const Duration(seconds: 2));
    });

    test('without a paused switch the refusal stays generic', () {
      final provider = AppProvider.withServices(organizationBroadcastService:EmptyBroadcasts(),
          authService: _Auth(), adminDbService: _BroadcasterDb());
      addTearDown(provider.dispose);
      provider.applyAuthRefusal(const AuthException('refused'),
          registrationsOpen: true);
      expect(provider.authRefusalKey, 'auth_refusal.generic');
      provider.applyAuthRefusal(const AuthException('refused'),
          registrationsOpen: null);
      expect(provider.authRefusalKey, 'auth_refusal.generic');
      provider.applyAuthRefusal(const AuthException('refused'),
          registrationsOpen: false);
      expect(provider.authRefusalKey, 'auth_refusal.signups_paused');
      expect(provider.authRefusalGeneration, 3);
    });
  });

  testWidgets('the LIVE badge follows the server, not the player',
      (tester) async {
    Future<void> pumpControls(bool serverLive) => tester.pumpWidget(
          localizedApp(
            home: Scaffold(
              body: SizedBox(
                width: 640,
                height: 360,
                child: LivePlayerOverlayControls(
                  streamState: StreamState.live,
                  showLiveBadge: serverLive,
                  viewerCount: 1,
                  isPlaying: true,
                  isMuted: false,
                  isFullscreen: false,
                  selectedQuality: StreamQualityLevel.auto,
                  onTogglePlayPause: () {},
                  onToggleMute: () {},
                  onToggleFullscreen: () {},
                  onSelectQuality: (_) {},
                  onRetryConnection: () {},
                ),
              ),
            ),
          ),
        );
    await pumpControls(true);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('live.live_indicator'.tr()), findsOneWidget);
    await pumpControls(false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('live.live_indicator'.tr()), findsNothing,
        reason: 'a playing video is not proof of a live broadcast');
  });

  test('a live mini-player closes when its broadcast ends', () async {
    final catalog = _Catalog();
    final provider = AppProvider.withServices(organizationBroadcastService:EmptyBroadcasts(),adminDbService: catalog);
    addTearDown(provider.dispose);
    final live = mockStreamers.first
        .copyWith(isCurrentlyLive: true, activeStreamId: 'LIVEvideo01');
    provider.addStreamer(live);
    await Future<void>.delayed(Duration.zero);
    catalog.pending.removeAt(0).complete([live]);
    await Future<void>.delayed(Duration.zero);
    provider.openMiniPlayer(
        videoId: 'LIVEvideo01',
        title: 't',
        streamerName: 'n',
        streamId: live.streamerId);
    expect(provider.isMiniPlayerActive, isTrue);
    final load = provider.loadVerifiedStreamersFromBackend();
    catalog.pending.removeAt(0).complete(
        [live.copyWith(isCurrentlyLive: false, clearLiveState: true)]);
    await load;
    expect(provider.isMiniPlayerActive, isFalse);
    expect(provider.miniPlayerEndedGeneration, 1,
        reason: 'the app says why the player disappeared');
  });

  test('remote end reasons map to explicit copy in both languages', () {
    for (final reason in [
      'admin_end',
      'admin_remove',
      'stale_expired',
      'replaced',
      'ended',
      null
    ]) {
      final key = DeviceSessionPresenter.remoteEndMessageKey(reason);
      expect(key, startsWith('broadcast_ended.'));
    }
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
