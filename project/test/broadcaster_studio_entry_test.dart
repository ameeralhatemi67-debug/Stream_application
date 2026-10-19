import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/services/youtube_api_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/core/widgets/interactive_toast_overlay.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';

import 'support/localized_app.dart';
import 'package:streamer_app/core/services/organization_broadcast_service.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';
import 'package:streamer_app/features/organization/models/org_membership.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';
import 'package:streamer_app/features/live_stream/services/broadcast_publishing_controller.dart';

class _Auth extends SupabaseAuthService {
  _Auth(String id)
      : session = Session(
            accessToken: 'test-only',
            tokenType: 'bearer',
            user: User(
                id: id,
                appMetadata: {},
                userMetadata: {},
                aud: 'authenticated',
                createdAt: '2026-09-24T00:00:00Z',
                email: '$id@example.invalid'));
  final Session? session;
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

BroadcasterApplicationModel _approvedApp(String handle) =>
    BroadcasterApplicationModel(
      id: 'app-c',
      applicantProfileId: 'c',
      accountType: ApplicationAccountType.individualScholar,
      applicantNameEn: 'C',
      applicantNameAr: 'C',
      email: 'c@example.invalid',
      phone: '',
      categoryId: 'computer_science',
      tags: const [],
      venueNameEn: '',
      venueNameAr: '',
      latitude: 0,
      longitude: 0,
      seatingCapacity: 0,
      youtubeChannelUrl: 'https://youtube.com/@$handle',
      youtubeHandle: handle,
      bioEn: '',
      bioAr: '',
      avatarUrl: '',
      bannerUrl: '',
      status: ApplicationStatus.approved,
      submittedAt: DateTime.utc(2026, 9, 1),
    );

class _StudioDb extends AdminDatabaseService {
  _StudioDb({BroadcasterApplicationModel? app})
      : app = app ?? _approvedApp('my_channel');
  final bool primary=true;
  final BroadcasterApplicationModel? app;
  final senderModes = <String>[];
  final devices = StreamController<List<DeviceSessionModel>>.broadcast();
  int claims = 0;
  int liveCalls = 0;
  Completer<void>? liveGate;
  PostgrestException? refuseLive;

  @override
  Future<bool> checkIsProfileStreamer(String id) async => true;
  @override
  Future<BroadcasterApplicationModel?> loadMyApplication(
          String profileId) async =>
      app;
  @override
  Future<Map<String, dynamic>?> loadOwnProfile(String id) async =>
      {'display_name_en': 'C', 'is_streamer': true, 'is_verified': true,
       'personal_broadcast_approved': true};
  @override
  Future<DeviceClaimResult> claimDeviceState(DeviceSessionModel device,
      {bool force = false}) async {
    claims++;
    return primary || force
        ? const DeviceClaimResult(claimed: true)
        : DeviceClaimResult(
            claimed: false,
            primary: DeviceSessionModel(
                deviceId: 'other',
                deviceName: 'android Device',
                platform: 'android',
                lastActiveAt: DateTime.now()));
  }

  @override
  Stream<List<DeviceSessionModel>> watchDevices(String userId) =>
      devices.stream;
  @override
  Future<bool> heartbeatDevice(String deviceId) async => true;
  @override
  Future<void> setLiveState(
      {required bool live,
      required String type,
      required String? streamId,
      required String deviceId,
      String? orgId}) async {
    liveCalls++;
    await liveGate?.future;
    if (refuseLive != null) throw refuseLive!;
  }

  // Behaves like a backend without broadcast sessions: the start goes through
  // the legacy live-state call, so these tests keep exercising that path.
  @override
  Future<String?> startBroadcastSession(
      {required String type,
      required String streamId,
      required String deviceId,
      required String senderMode,
      String? orgId}) async {
    senderModes.add(senderMode);
    await setLiveState(
        live: true,
        type: type,
        streamId: streamId,
        deviceId: deviceId,
        orgId: orgId);
    return null;
  }
}

Future<AppProvider> _broadcaster(_StudioDb db, {_Broadcasts? broadcasts}) async {
  final provider = AppProvider.withServices(
      authService: _Auth('c'),
      organizationBroadcastService: broadcasts ?? _Broadcasts(),
      adminDbService: db,
      youTubeService: YouTubeApiService(apiKey:''));
  for (var i = 0; i < 200 && provider.authHydrating; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  for (var i = 0; i < 50 && provider.currentDeviceSession == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  return provider;
}

class _Broadcasts extends OrganizationBroadcastService {
  static const destination=ChannelConnection(id:'connection',ownerId:'c',organizationId:null,
    channelId:'UC_test',title:'Confirmed channel',status:'connected',revision:2);
  int creates=0,prepares=0;
  String? createdTitle;
  bool failPrepare=false,failEnd=false;
  Completer<void>? startGate;
  Object? startError;
  final actions=<String>[];
  Map<String,dynamic> row={'id':'session','owner_id':'c','org_id':null,'state':'scheduled',
    'revision':1,'title_en':'A show','title_ar':'برنامج','broadcast_type':'liveVideo','accepted_at':'2026-10-01',
    'sender_mode':'obs_laptop','stream_id':'abcdefghijk'};
  @override Future<List<ChannelConnection>> connections() async=>[destination];
  @override Future<List<OrgMembership>> memberships({String? organizationId}) async=>[];
  @override Future<List<BroadcastSession>> sessions({String? organizationId,bool mine=false}) async=>creates==0?[]:[BroadcastSession.fromRow(row)];
  int reads=0;
  final updates=<(String,String)>[], hideChoices=<bool>[];
  @override Future<BroadcastSession?> session(String id) async {reads++;return BroadcastSession.fromRow(row);}
  @override Future<String> createPersonal(String title,String type) async {creates++;createdTitle=title;return 'session';}
  @override Future<Map<String,dynamic>> updatePersonal(String id,String title,String type) async {
    updates.add((title,type));row['title_en']=title;row['broadcast_type']=type;return Map<String,dynamic>.of(row);}
  @override Future<void> setHideReplay(String id,bool hidden) async {hideChoices.add(hidden);row['hide_replay']=hidden;}
  @override Future<Map<String,dynamic>> control(String sessionId,String deviceId,String sender,String action,{ChannelConnection? destination}) async {
    actions.add(action);
    if(action=='prepare') {
      prepares++;row['channel_connection_id']='connection';row['sender_mode']=sender;row['state']='preparing';
      if(failPrepare)throw const FunctionException(status:409,details:{'error':'feed_creation_unresolved'});
      return {'session':Map<String,dynamic>.of(row),'ingest_url':'rtmps://a.rtmps.youtube.com/live2','ingest_key':'test-only-key'};
    }
    if(action=='start') {await startGate?.future;if(startError!=null)throw startError!;row['state']='live';}
    if(action=='end') {row['state']=failEnd?'ending':'completed';row['termination_pending']=failEnd;if(failEnd)throw StateError('Provider unavailable');}
    return {'session':Map<String,dynamic>.of(row)};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  Future<void> close(WidgetTester tester, AppProvider provider,
      [_StudioDb? db]) async {
    InteractiveToastOverlay.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    await db?.devices.close();
    await tester.pump(const Duration(seconds: 1));
  }


  test('only the explicit encoder-wait response is retryable',() {
    expect(OrganizationBroadcastService.waitingForEncoder(const FunctionException(status:409,details:{'error':'waiting_for_encoder'})),isTrue);
    for(final status in [401,403,409,429,500]) {
      expect(OrganizationBroadcastService.waitingForEncoder(FunctionException(status:status,details:{'error':'quotaExceeded'})),isFalse);
    }
  });

  test('partial preparation retries the same session and restores sender without saved credentials',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts()..failPrepare=true;
    final p=await _broadcaster(db,broadcasts:broadcasts);
    final studio=BroadcastPublishingController(p)..destination=_Broadcasts.destination..sender='phone_direct'..confirmed=true;
    expect(await studio.prepare('Show','liveVideo'),isFalse);
    expect(studio.frozen,isTrue);expect(broadcasts.creates,1);
    broadcasts.failPrepare=false;
    expect(await studio.prepare('Show','liveVideo'),isTrue);
    expect(broadcasts.creates,1);expect(broadcasts.prepares,2);
    studio.dispose();
    final restored=BroadcastPublishingController(p);await restored.load();
    expect(restored.sender,'phone_direct');expect(restored.ingestKey,isEmpty);expect(restored.confirmed,isTrue);
    p.applyDeviceSessions([]);
    expect(restored.session,isNull);expect(p.publishingSession,isNull);expect(p.phoneBroadcastStreamKey,isEmpty);
    restored.dispose();p.dispose();await db.devices.close();
  });

  test('an empty title falls back to the channel name and still prepares',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    final studio=BroadcastPublishingController(p)..destination=_Broadcasts.destination..sender='obs_laptop'..confirmed=true;
    expect(await studio.prepare('  ','liveVideo'),isTrue);
    expect(broadcasts.createdTitle,'Confirmed channel');expect(studio.errorKey,isNull);
    studio.dispose();p.dispose();await db.devices.close();
  });

  test('consent return keeps the page stack once, briefly, and only for app paths',()async {
    final p=AppProvider.withServices(organizationBroadcastService:_Broadcasts());
    expect(await p.takeChannelConsentReturn(),isNull);
    await p.rememberChannelConsentReturn(['/feed','/settings'],studio:false);
    final saved=await p.takeChannelConsentReturn();
    expect(saved?.stack,['/feed','/settings']);expect(saved?.studio,isFalse);
    expect(await p.takeChannelConsentReturn(),isNull,reason:'Consumed by the first return');
    await p.rememberChannelConsentReturn(['/broadcaster/abc'],studio:true);
    expect((await p.takeChannelConsentReturn())?.studio,isTrue);
    for(final bad in [['https://evil.invalid/'],['/feed','//evil.invalid'],<String>[]]) {
      await p.rememberChannelConsentReturn(bad,studio:true);
      expect(await p.takeChannelConsentReturn(),isNull,reason:'$bad');
    }
    SharedPreferences.setMockInitialValues({'channel_consent_return':
      '{"at":"${DateTime.now().toUtc().subtract(const Duration(hours:1)).toIso8601String()}","stack":["/feed"],"studio":true}'});
    expect(await p.takeChannelConsentReturn(),isNull,reason:'A stale consent attempt does not reopen anything');
    p.dispose();
  });

  test('authorization errors surface once and pending termination retains exact session',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    await p.prepareBroadcast('session','obs_laptop',_Broadcasts.destination);
    broadcasts.startError=const FunctionException(status:403,details:{'error':'forbidden'});
    await p.setBroadcasterLive(true);
    expect(broadcasts.actions.where((a)=>a=='start'),hasLength(1));
    expect(p.broadcastSessionError,'organization_v1.authorization_failed');expect(p.isBroadcastingLive,isFalse);
    broadcasts.failEnd=true;await p.setBroadcasterLive(false);
    expect(p.publishingSession?.terminationPending,isTrue);expect(p.phoneBroadcastStreamKey,isEmpty);
    expect(p.broadcastSessionError,'organization_v1.termination_pending');
    p.dispose();await db.devices.close();
  });

  test('End waits for in-flight Start and does not leave a published session',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts()..startGate=Completer<void>();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    await p.prepareBroadcast('session','obs_laptop',_Broadcasts.destination);
    final start=p.setBroadcasterLive(true);final end=p.setBroadcasterLive(false);
    expect(p.broadcastOperationBusy,isTrue);
    broadcasts.startGate!.complete();await Future.wait([start,end]);
    expect(broadcasts.actions,['prepare','start','end']);expect(p.publishingSession,isNull);expect(p.isBroadcastingLive,isFalse);
    p.dispose();await db.devices.close();
  });

  Future<void> settle()=>Future<void>.delayed(const Duration(milliseconds:20));

  test('opening the studio prepares YouTube in the background; Preview adopts it',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    final studio=BroadcastPublishingController(p)..destination=_Broadcasts.destination..sender='phone_direct'..confirmed=true;
    studio.prewarm(title:'Default',type:'liveVideo');
    await settle();
    expect(broadcasts.creates,1);expect(broadcasts.prepares,1);
    expect(studio.frozen,isFalse,reason:'the options stay open while it prepares');
    expect(p.publishingSession,isNull);
    expect(p.phoneBroadcastStreamKey,isEmpty,reason:'not the publishing session until Preview');
    expect(await studio.prepare('Default','liveVideo'),isTrue);
    expect(broadcasts.creates,1);expect(broadcasts.prepares,1,reason:'Preview had nothing left to wait for');
    expect(broadcasts.updates,isEmpty);
    expect(p.publishingSession?.id,'session');expect(p.phoneBroadcastStreamKey,'test-only-key');
    expect(await p.checkBroadcastPermission(),isTrue);
    expect(broadcasts.prepares,1,reason:'Go live does not prepare a second time');
    studio.dispose();p.dispose();await db.devices.close();
  });

  test('a title or audio choice made after the pre-warm is applied on Preview',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    final studio=BroadcastPublishingController(p)..destination=_Broadcasts.destination..sender='phone_direct'..confirmed=true;
    studio.prewarm(title:'Default',type:'liveVideo');
    // Preview while the handshake is still running waits for it.
    expect(await studio.prepare('My lesson','liveAudio'),isTrue);
    expect(broadcasts.creates,1);expect(broadcasts.prepares,1);
    expect(broadcasts.updates,[('My lesson','liveAudio')]);
    expect(p.publishingSession?.titleEn,'My lesson');expect(p.publishingSession?.broadcastType,'liveAudio');
    studio.dispose();p.dispose();await db.devices.close();
  });

  test('switching to OBS ends the unused phone preparation first',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    final studio=BroadcastPublishingController(p)..destination=_Broadcasts.destination..sender='phone_direct'..confirmed=true;
    studio.prewarm(title:'Default',type:'liveVideo');
    await settle();
    studio.sender='obs_laptop';studio.discardWarm();
    expect(await studio.prepare('Default','liveVideo'),isTrue);
    expect(broadcasts.actions,['prepare','end','prepare']);
    expect(broadcasts.creates,2);
    studio.dispose();p.dispose();await db.devices.close();
  });

  test('closing and reopening the studio reuses the preparation; unused, it is ended after the grace',()async {
    final grace=AppProvider.warmReleaseGrace;
    addTearDown(()=>AppProvider.warmReleaseGrace=grace);
    AppProvider.warmReleaseGrace=const Duration(milliseconds:50);
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    broadcasts.row['device_id']=p.currentDeviceSession!.deviceId;
    broadcasts.row['expected_end_at']=DateTime.now().toUtc().add(const Duration(hours:1)).toIso8601String();
    final first=BroadcastPublishingController(p)..destination=_Broadcasts.destination..sender='phone_direct'..confirmed=true;
    first.prewarm(title:'Default',type:'liveVideo');
    await settle();first.dispose();
    final reopened=BroadcastPublishingController(p)..sender='phone_direct';
    await reopened.load();
    expect(reopened.frozen,isFalse,reason:'an unused preparation is not shown as a frozen show');
    reopened.prewarm(title:'Default',type:'liveVideo');
    await Future<void>.delayed(const Duration(milliseconds:120));
    expect(broadcasts.actions,isNot(contains('end')),reason:'reclaimed before the grace ran out');
    expect(broadcasts.creates,1);
    reopened.dispose();
    // Closed again and not reopened: ended once the grace passes.
    await Future<void>.delayed(const Duration(milliseconds:120));
    expect(broadcasts.actions.last,'end');
    expect(broadcasts.creates,1);
    p.dispose();await db.devices.close();
  });

  test('the hide-the-video choice is saved with the prepared session',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    final studio=BroadcastPublishingController(p)..destination=_Broadcasts.destination..sender='obs_laptop'..confirmed=true;
    await studio.setHideReplay(true);
    expect(broadcasts.hideChoices,isEmpty,reason:'nothing prepared yet');
    expect(await studio.prepare('Show','liveVideo'),isTrue);
    expect(broadcasts.hideChoices,[true]);expect(studio.session?.hideReplay,isTrue);
    await studio.setHideReplay(false);
    expect(broadcasts.hideChoices,[true,false]);expect(studio.session?.hideReplay,isFalse);
    await p.setBroadcastHideReplay('session',true);
    expect(p.publishingSession?.hideReplay,isTrue);
    studio.dispose();p.dispose();await db.devices.close();
  });

  test('a confirmed start or end needs no extra session read',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts();
    final p=await _broadcaster(db,broadcasts:broadcasts);
    await p.prepareBroadcast('session','obs_laptop',_Broadcasts.destination);
    await p.setBroadcasterLive(true);
    expect(p.isBroadcastingLive,isTrue);expect(broadcasts.reads,0);
    await p.setBroadcasterLive(false);
    expect(p.publishingSession,isNull);expect(broadcasts.reads,0);
    p.dispose();await db.devices.close();
  });

  test('End during a start that waits for the encoder stops its retries',()async {
    final db=_StudioDb(), broadcasts=_Broadcasts()
      ..startError=const FunctionException(status:409,details:{'error':'waiting_for_encoder'});
    final p=await _broadcaster(db,broadcasts:broadcasts);
    await p.prepareBroadcast('session','obs_laptop',_Broadcasts.destination);
    final start=p.setBroadcasterLive(true);final end=p.setBroadcasterLive(false);
    await Future.wait([start,end]).timeout(const Duration(seconds:5));
    expect(broadcasts.actions,['prepare','start','end']);
    expect(p.publishingSession,isNull);expect(p.isBroadcastingLive,isFalse);
    p.dispose();await db.devices.close();
  });

  for(final locale in [const Locale('en'),const Locale('ar')]) {
    testWidgets('one personal channel is selected without extra confirmation: $locale',(tester)async {
      final db=_StudioDb();final p=await tester.runAsync(()=>_broadcaster(db));
      tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
      await tester.pumpWidget(EasyLocalization(supportedLocales:const [Locale('en'),Locale('ar')],startLocale:locale,
        saveLocale:false,path:'assets/i18n',assetLoader:const DirectJsonAssetLoader(),child:Builder(builder:(context)=>
        ChangeNotifierProvider.value(value:p!,child:MaterialApp(locale:context.locale,localizationsDelegates:context.localizationDelegates,
          supportedLocales:context.supportedLocales,home:const Scaffold(body:LiveBroadcasterStudioSheet()))))));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile),findsNothing);
      expect(find.byType(DropdownButtonFormField<String>),findsNothing);
      expect(find.textContaining('Confirmed channel'),findsOneWidget);
      expect(find.byType(TextField),findsOneWidget);
      expect(find.byKey(const Key('studio-hide-replay')),findsOneWidget);
      // The title is optional: Preview is available before anything is typed.
      final preview=find.widgetWithText(CaButton,'organization_v1.preview'.tr());
      expect(tester.widget<CaButton>(preview).onPressed,isNotNull);
      expect(find.text('organization_v1.reconnect'.tr()),findsOneWidget);
      expect(find.text('organization_v1.channels'.tr()),findsNothing);
      await tester.enterText(find.byType(TextField),'My lesson');await tester.pump();
      expect(tester.widget<CaButton>(preview).onPressed,isNotNull);
      expect(find.textContaining('rtmp://'),findsNothing);expect(tester.takeException(),isNull);
      await close(tester,p!,db);
    });
  }
  testWidgets(
      'a displaced device leaves the phone screen and releases the native '
      'camera/encoder', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const rtmp = MethodChannel('streamer_app/rtmp_publisher');
    const events = EventChannel('streamer_app/rtmp_publisher/events');
    final calls = <String>[];
    messenger.setMockMethodCallHandler(rtmp, (call) async {
      calls.add(call.method);
      return null;
    });
    messenger.setMockMessageHandler(
        events.name, (_) async => events.codec.encodeSuccessEnvelope(null));
    addTearDown(() {
      messenger.setMockMethodCallHandler(rtmp, null);
      messenger.setMockMessageHandler(events.name, null);
    });

    final db = _StudioDb();
    final provider = await tester.runAsync(() => _broadcaster(db));
    expect(provider!.currentDeviceSession?.isPrimaryBroadcaster, isTrue);
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(c).push(MaterialPageRoute(
                      builder: (_) => const PhoneBroadcastScreen())),
                  child: const Text('open phone'),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open phone'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(PhoneBroadcastScreen), findsOneWidget);

    // The other phone transfers the broadcaster role to itself.
    db.devices.add([
      provider.currentDeviceSession!.copyWith(isPrimaryBroadcaster: false),
      DeviceSessionModel(
          deviceId: 'other',
          deviceName: 'android Device',
          platform: 'android',
          lastActiveAt: DateTime.now()),
    ]);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(provider.broadcastSessionError, 'broadcast_session_lost');
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(calls, contains('dispose'),
        reason: 'engine disposal releases camera, microphone and encoder');
    expect(db.liveCalls, 0, reason: 'nothing claimed LIVE');
    tester.takeException();
    await close(tester, provider, db);
  });

}
