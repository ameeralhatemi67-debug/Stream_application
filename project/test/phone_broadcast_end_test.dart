import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_icon.dart';
import 'package:streamer_app/core/widgets/ds/canopy_motion.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

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
import 'package:streamer_app/core/widgets/interactive_toast_overlay.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/phone_camera_preview.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_chat_widget.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';

import 'support/localized_app.dart';
import 'support/empty_broadcasts.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';

/// P6S Group 3: the phone broadcaster can always see how to end, and leaving
/// the screen never silently ends (or silently keeps) a broadcast.

class _Auth extends SupabaseAuthService {
  _Auth()
      : session = Session(
            accessToken: 'test-only',
            tokenType: 'bearer',
            user: const User(
                id: 'c',
                appMetadata: {},
                userMetadata: {},
                aud: 'authenticated',
                createdAt: '2026-09-25T00:00:00Z',
                email: 'c@example.invalid'));
  final Session? session;
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

class _Db extends AdminDatabaseService {
  final devices = StreamController<List<DeviceSessionModel>>.broadcast();
  int starts = 0;
  int stops = 0;
  bool failStop = false;
  int endRequests = 0;
  Completer<void>? endGate;
  bool useSession = false;
  bool rejectIngest = false;
  bool permitted = true;
  String? deviceId;
  final statusOverrides = <String, dynamic>{};
  Completer<Map<String, dynamic>>? statusGate;
  final reports = <bool>[];

  @override
  Future<void> reportBroadcastIngest(
      {required String sessionId,
      required String deviceId,
      required bool sending}) async {
    reports.add(sending);
    if (rejectIngest) {
      throw const PostgrestException(message: 'Ended', code: '55000');
    }
  }

  @override
  Future<Map<String, dynamic>> loadMyBroadcastStatus() async =>
      statusGate != null
          ? await statusGate!.future
          : {
              'live': !rejectIngest,
              'stream_id': 'abcdefghijk',
              'session_id': 'phone-session',
              'device_id': deviceId,
              'last_ended': {'reason': 'admin_end'},
              ...statusOverrides,
            };

  @override
  Future<void> endBroadcastSession(
      {required String sessionId, required String deviceId}) async {
    stops++;
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
  Future<bool> canBroadcast({String? orgId, required String type}) async =>
      permitted;
  @override
  Future<void> setLiveState(
      {required bool live,
      required String type,
      required String? streamId,
      required String deviceId,
      String? orgId}) async {
    if (!live && failStop) {
      throw const PostgrestException(message: 'offline', code: '08006');
    }
    live ? starts++ : stops++;
  }

  @override
  Future<String?> startBroadcastSession(
      {required String type,
      required String streamId,
      required String deviceId,
      required String senderMode,
      String? orgId}) async {
    this.deviceId = deviceId;
    starts++;
    return useSession ? 'phone-session' : null;
  }
}

class _CanonicalBroadcasts extends EmptyBroadcasts {
  _CanonicalBroadcasts(this.db);
  final _Db db;
  static const destination = ChannelConnection(
      id: 'connection',
      ownerId: 'c',
      organizationId: null,
      channelId: 'UC_test',
      title: 'Channel',
      status: 'connected',
      revision: 1);
  final row = <String, dynamic>{
    'id': 'phone-session',
    'owner_id': 'c',
    'state': 'preparing',
    'revision': 1,
    'title_en': 'Phone',
    'title_ar': 'هاتف',
    'broadcast_type': 'liveVideo',
    'channel_connection_id': 'connection',
    'sender_mode': 'phone_direct',
    'stream_id': 'abcdefghijk',
    'accepted_at': '2026-10-01'
  };
  @override
  Future<BroadcastSession?> session(String id) async =>
      BroadcastSession.fromRow(row);
  @override
  Future<Map<String, dynamic>> control(
      String sessionId, String deviceId, String sender, String action,
      {ChannelConnection? destination}) async {
    db.deviceId = deviceId;
    if (action == 'prepare') {
      if (!db.permitted) throw const FunctionException(status: 403);
      return {
        'session': Map<String, dynamic>.of(row),
        'ingest_url': 'rtmps://a.rtmps.youtube.com/live2',
        'ingest_key': 'test-key'
      };
    }
    if (action == 'start') {
      db.starts++;
      row['state'] = 'live';
    }
    if (action == 'end') {
      db.endRequests++;
      if (db.endGate != null) await db.endGate!.future;
      if (db.failStop) throw StateError('offline');
      db.stops++;
      row['state'] = 'completed';
    }
    return {'session': Map<String, dynamic>.of(row)};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  const rtmp = MethodChannel('streamer_app/rtmp_publisher');
  const events = EventChannel('streamer_app/rtmp_publisher/events');
  late List<String> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(
        permissions,
        (call) async =>
            call.method == 'requestPermissions' ? <int, int>{1: 1, 7: 1} : 1);
    messenger.setMockMethodCallHandler(rtmp, (call) async {
      calls.add(call.method);
      return null;
    });
    messenger.setMockMessageHandler(
        events.name, (_) async => events.codec.encodeSuccessEnvelope(null));
    // The camera preview is a native view; the test only needs it to exist.
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async {
      if (call.method == 'create') return 0;
      if (call.method == 'resize') {
        final args = call.arguments as Map;
        return {'width': args['width'], 'height': args['height']};
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(permissions, null);
    messenger.setMockMethodCallHandler(rtmp, null);
    messenger.setMockMessageHandler(events.name, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  Future<AppProvider> broadcaster(_Db db) async {
    final p = AppProvider.withServices(
        authService: _Auth(),
        adminDbService: db,
        organizationBroadcastService: _CanonicalBroadcasts(db));
    for (var i = 0; i < 200 && p.authHydrating; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    for (var i = 0; i < 50 && p.currentDeviceSession == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    p.setCustomStreamerYouTubeUrl('https://youtu.be/abcdefghijk');
    await p.prepareBroadcast(
        'phone-session', 'phone_direct', _CanonicalBroadcasts.destination);
    return p;
  }

  /// Opens the phone screen over a home page and lets it start sending (the
  /// encoder stays "connecting": no native connection event arrives).
  Future<void> open(WidgetTester tester, AppProvider p,
      {Locale locale = const Locale('en'),
      Size size = const Size(412, 915),
      double textScale = 1,
      bool wideConfirmation = false,
      bool canopyTheme = false,
      bool autoStart = true}) async {
    // These fixtures keep the unchanged wider-screen confirmation contract.
    // Separate native-phone cases below exercise its deliberate hold replacement.
    if (wideConfirmation) {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: locale,
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
        builder: (context) => ChangeNotifierProvider.value(
          value: p,
          child: MaterialApp(
            theme: canopyTheme ? AppTheme.forLocale(context.locale) : null,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(textScale),
                  disableAnimations: true),
              child: child!,
            ),
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Builder(
              builder: (c) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(c).push(MaterialPageRoute(
                      builder: (_) => PhoneBroadcastScreen(
                          quickLaunchPreset: BroadcastQualityPreset.medium,
                          autoStart: autoStart))),
                  child: const Text('home'),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('home'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester tester, AppProvider p, _Db db) async {
    InteractiveToastOverlay.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
    await db.devices.close();
    await tester.pump(const Duration(seconds: 1));
    debugDefaultTargetPlatformOverride = null;
  }

  for (final (locale, size, scale) in [
    (const Locale('en'), const Size(412, 915), 1.0),
    (const Locale('ar'), const Size(412, 915), 1.0),
    (const Locale('en'), const Size(915, 412), 1.0),
    (const Locale('ar'), const Size(915, 412), 1.0),
    (const Locale('ar'), const Size(360, 780), 2.0),
  ]) {
    testWidgets('camera preview stays private and Back cancels preparation: $locale $size $scale',
        (tester) async {
      final db = _Db();
      final p = await tester.runAsync(() => broadcaster(db));
      await open(tester, p!, locale: locale, size: size, textScale: scale, autoStart: false);
      expect(calls, contains('prepare'));
      expect(calls, isNot(contains('startStream')));
      expect(db.starts, 0);
      expect(find.byKey(const Key('phone-start-broadcast')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(db.stops, 1);
      expect(p.publishingSession, isNull);
      expect(find.byType(PhoneBroadcastScreen), findsNothing);
      await close(tester, p, db);
    });
  }

  testWidgets('Go live sends the encoder before requesting public live state',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, autoStart: false);
    await tester.tap(find.byKey(const Key('phone-start-broadcast')));
    await tester.pump();
    expect(calls.where((c) => c == 'startStream'), hasLength(1));
    expect(db.starts, 0);
    messenger.handlePlatformMessage(events.name,
        events.codec.encodeSuccessEnvelope({'type': 'live'}), (_) {});
    await tester.pump();
    expect(db.starts, 1);
    expect(p.isBroadcastingLive, isTrue);
    await close(tester, p, db);
  });

  for (final size in [const Size(412, 915), const Size(915, 412)]) {
    testWidgets('one sender recovery surface at $size', (tester) async {
      final db = _Db()..useSession = true;
      final p = await tester.runAsync(() => broadcaster(db));
      await open(tester, p!, size: size);
      for (final event in ['live', 'disconnected']) {
        messenger.handlePlatformMessage(events.name,
            events.codec.encodeSuccessEnvelope({'type': event}), (_) {});
        await tester.pump();
      }
      expect(
          find.text('live.stream_interrupted_reconnecting_attempt'
              .tr(namedArgs: {'current': '0', 'total': '10'})),
          findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.text('live.recovery_retry'.tr()), findsOneWidget);
      final panel = find.byKey(const Key('sender-recovery-exhausted'));
      expect(panel, findsOneWidget);
      expect(
          find.descendant(
              of: panel, matching: find.text('live.recovery_leave'.tr())),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester, p, db);
    });
  }

  for (final fault in [
    'none',
    'end',
    'replacement',
    'device',
    'revoke',
    'unreachable',
    'lateEnd'
  ]) {
    test('recovery authorization checks exact live authority: $fault',
        () async {
      final db = _Db()..useSession = true;
      final p = await broadcaster(db);
      await p.setBroadcasterLive(true);
      expect(p.isBroadcastingLive, isTrue);
      if (fault == 'end') db.statusOverrides['live'] = false;
      if (fault == 'replacement') {
        db.statusOverrides['session_id'] = 'replacement';
      }
      if (fault == 'device') db.statusOverrides['device_id'] = 'other';
      if (fault == 'revoke') db.permitted = false;
      if (fault == 'unreachable' || fault == 'lateEnd') {
        db.statusGate = Completer();
      }
      final pending = p.authorizeBroadcastRecovery();
      if (fault == 'unreachable') {
        db.statusGate!.completeError(StateError('offline'));
      }
      if (fault == 'lateEnd') {
        await p.setBroadcasterLive(false);
        db.statusGate!.complete({
          'live': true,
          'session_id': 'phone-session',
          'stream_id': 'abcdefghijk',
          'device_id': db.deviceId
        });
      }
      expect(
          await pending,
          fault == 'none'
              ? true
              : fault == 'unreachable'
                  ? null
                  : false);
      expect(db.reports, fault == 'none' ? [false] : isEmpty);
      p.dispose();
      await db.devices.close();
    });
  }

  final endButton = find.byKey(const Key('phone-end-broadcast'));
  // Golden font preloading lives on the design branch; nothing to load here.
  Future<void> captureFonts() async {}
  const hudSizes = <Size>[
    Size(320, 640), Size(360, 780), Size(393, 852), Size(412, 915),
    Size(600, 900), Size(852, 393), Size(820, 1100), Size(1024, 720),
    Size(1280, 760), Size(1600, 900),
  ];
  Iterable<double> hudScales(Size size) =>
      [1.0, 1.6, if (size.shortestSide < 600) 1.3];

  Future<void> finalCapture(WidgetTester tester, String name) async {
    final directory = Platform.environment['HADAYAH_FINAL_CAPTURE_DIR'];
    if (directory == null) return;
    await tester.pump();
    final boundary = tester.renderObject<RenderRepaintBoundary>(find
        .ancestor(
            of: find.byType(PhoneBroadcastScreen),
            matching: find.byType(RepaintBoundary))
        .first);
    await tester.runAsync(() async {
      final picture = await boundary.toImage();
      try {
        final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
        File('$directory/$name.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      } finally {
        picture.dispose();
      }
    });
  }

  testWidgets(
      'phone hold starts, cancels early, and completes the existing end path',
      (tester) async {
    await captureFonts();
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, canopyTheme: true);
    await finalCapture(tester, 'phone-video-412-en');
    expect(tester.widget<CaButton>(endButton).holdToConfirm, isTrue);
    final early = await tester.startGesture(tester.getCenter(endButton));
    await tester.pump(CanopyMotion.holdToEnd ~/ 2);
    await finalCapture(tester, 'phone-hold-half-412-en');
    expect(calls, isNot(contains('stopStream')));
    await early.up();
    await tester.pump(CanopyMotion.holdRelease);
    expect(calls, isNot(contains('stopStream')));
    expect(find.byKey(const Key('phone-end-confirm')), findsNothing);
    final complete = await tester.startGesture(tester.getCenter(endButton));
    await tester.pump(CanopyMotion.holdToEnd);
    await complete.up();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(calls, contains('stopStream'));
    expect(db.stops, 1);
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester, p, db);
  });

  for (final key in [LogicalKeyboardKey.space, LogicalKeyboardKey.enter]) {
    testWidgets('phone hold keyboard cancel and complete: $key',
        (tester) async {
      final db = _Db();
      final p = await tester.runAsync(() => broadcaster(db));
      await open(tester, p!);
      Focus.of(tester.element(find
              .descendant(of: endButton, matching: find.byType(Text))
              .first))
          .requestFocus();
      await tester.pump();
      await tester.sendKeyDownEvent(key);
      await tester.pump(CanopyMotion.holdToEnd ~/ 2);
      await tester.sendKeyUpEvent(key);
      await tester.pump(CanopyMotion.holdRelease);
      expect(calls, isNot(contains('stopStream')));
      await tester.sendKeyDownEvent(key);
      await tester.pump(CanopyMotion.holdToEnd);
      await tester.sendKeyUpEvent(key);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
      expect(calls, contains('stopStream'));
      expect(db.stops, 1);
      expect(find.byKey(const Key('phone-end-confirm')), findsNothing);
      await close(tester, p, db);
    });
  }

  testWidgets(
      'audio meter is idle without a native sample and follows only RMS events',
      (tester) async {
    await captureFonts();
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    p!.setBroadcastType(BroadcastType.liveAudio);
    await open(tester, p, canopyTheme: true);
    await finalCapture(tester, 'phone-audio-idle-412-en');
    expect(
        tester
            .widget<CaLevelMeter>(
                find.byKey(const Key('broadcast-audio-meter')))
            .level,
        0);
    expect(find.text('live.audio_level_unavailable'.tr()), findsOneWidget);
    await tester.runAsync(() => messenger.handlePlatformMessage(
        events.name,
        events.codec.encodeSuccessEnvelope({'type': 'audioLevel', 'rms': .75}),
        (_) {}));
    await tester.pump(CanopyMotion.meterRise);
    expect(
        tester
            .widget<CaLevelMeter>(
                find.byKey(const Key('broadcast-audio-meter')))
            .level,
        .75);
    expect(find.text('live.audio_level_unavailable'.tr()), findsNothing);
    expect(tester.takeException(), isNull);
    await close(tester, p, db);
  });

  Future<void> goLive(WidgetTester tester) async {
    // The native encoder reports a connection.
    await tester.runAsync(() => messenger.handlePlatformMessage(events.name,
        events.codec.encodeSuccessEnvelope({'type': 'live'}), (_) {}));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
  }

  testWidgets('phone hold reports an unconfirmed end and keeps the listing',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await goLive(tester);
    InteractiveToastOverlay.dismiss();
    db.failStop = true;
    final hold = await tester.startGesture(tester.getCenter(endButton));
    await tester.pump(CanopyMotion.holdToEnd);
    await hold.up();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('live.end_unconfirmed_title'.tr()), findsOneWidget);
    expect(p.isBroadcastingLive, isTrue,
        reason: 'server did not remove the listing');
    expect(p.publishingSession, isNotNull);
    expect(db.endRequests, 1);
    expect(db.stops, 0);
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(find.text('home'), findsOneWidget,
        reason: 'only the camera route closed');
    await close(tester, p, db);
  });

  testWidgets('phone Back during hold-end never pops the underlying page',
      (tester) async {
    final db = _Db()..endGate = Completer<void>();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await goLive(tester);
    InteractiveToastOverlay.dismiss();
    final hold = await tester.startGesture(tester.getCenter(endButton));
    await tester.pump(CanopyMotion.holdToEnd);
    await hold.up();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    expect(db.endRequests, 1);
    expect(find.byType(PhoneBroadcastScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(PhoneBroadcastScreen), findsOneWidget);
    expect(db.endRequests, 1);
    db.endGate!.complete();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(db.stops, 1);
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester, p, db);
  });

  testWidgets('device displacement cancels the phone hold without server End',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await goLive(tester);
    final hold = await tester.startGesture(tester.getCenter(endButton));
    await tester.pump(CanopyMotion.holdToEnd ~/ 2);
    db.devices.add([
      p.currentDeviceSession!.copyWith(isPrimaryBroadcaster: false),
      DeviceSessionModel(
          deviceId: 'other',
          deviceName: 'android Device',
          platform: 'android',
          lastActiveAt: DateTime.now()),
    ]);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await hold.up();
    await tester.pump(CanopyMotion.holdToEnd);
    expect(db.endRequests, 0,
        reason: 'displaced device cannot end the active session');
    expect(db.stops, 0);
    expect(calls.where((c) => c == 'stopStream').length, 1,
        reason: 'only the existing displacement cleanup stops this encoder');
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester, p, db);
  });

  for (final size in hudSizes) {
    for (final lang in ['en', 'ar']) {
      for (final scale in hudScales(size)) {
        testWidgets('phone HUD $size $lang $scale', (tester) async {
          await captureFonts();
          final db = _Db();
          final p = await tester.runAsync(() => broadcaster(db));
          await open(tester, p!,
              size: size,
              locale: Locale(lang),
              textScale: scale,
              canopyTheme: true);
          final phone = size.shortestSide < 600;
          expect(
              find.text(
                  (phone ? 'live.hold_to_end' : 'live.end_broadcast').tr()),
              findsOneWidget);
          final chip = find.byType(CaLanguageChip);
          if (phone) {
            expect(tester.getSize(chip).height, CanopySize.target);
            expect(tester.getSize(chip).width, CanopySize.target);
            expect(
                find.byTooltip('live.tooltip_controls'.tr()), findsOneWidget);
          } else {
            expect(tester.getSize(chip).height,
                greaterThanOrEqualTo(CanopySize.target));
            expect(tester.getSize(chip).width,
                greaterThanOrEqualTo(CanopySize.target));
            expect(tester.widget<FilledButton>(endButton).onPressed, isNotNull);
          }
          expect(endButton.hitTestable(), findsOneWidget);
          if (phone && size.width > size.height) {
            await tester.tap(find.byTooltip('live.tooltip_toggle_chat'.tr()));
            await tester.pumpAndSettle();
            expect(find.byType(TextField), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await close(tester, p, db);
        });
      }
    }
  }

  testWidgets('wide End retains its button and confirmation dialog',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, size: const Size(1024, 768), wideConfirmation: true);
    expect(tester.widget(endButton), isA<FilledButton>());
    await tester.tap(endButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsOneWidget);
    expect(calls, isNot(contains('stopStream')));
    await tester.tap(find.byKey(const Key('phone-end-stay')));
    await tester.pumpAndSettle();
    await close(tester, p, db);
  });

  testWidgets('phone landscape hold HUD and chat remain keyboard-free',
      (tester) async {
    await captureFonts();
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, size: const Size(740, 360), canopyTheme: true);
    expect(tester.widget<CaButton>(endButton).holdToConfirm, isTrue);
    await tester.tap(find.byTooltip('live.tooltip_toggle_chat'.tr()));
    await tester.pumpAndSettle();
    await finalCapture(tester, 'phone-landscape-chat-740-en');
    expect(find.byType(TextField), findsNothing);
    expect(find.text('live.landscape_chat_read_only'.tr()), findsOneWidget);
    expect(tester.widget<LiveChatWidget>(find.byType(LiveChatWidget)).cinema,
        isTrue);
    expect(tester.takeException(), isNull);
    await close(tester, p, db);
  });

  testWidgets('portrait: End is on screen while sending and asks first',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, wideConfirmation: true);
    expect(calls, contains('startStream'));
    expect(find.descendant(of: endButton, matching: find.text('End broadcast')),
        findsOneWidget);

    await tester.tap(endButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsOneWidget);
    expect(find.text('live.end_confirm_background_note'.tr()), findsOneWidget);

    await tester.tap(find.byKey(const Key('phone-end-stay')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneBroadcastScreen), findsOneWidget);
    expect(calls, isNot(contains('stopStream')), reason: 'Stay keeps sending');

    await tester.tap(endButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('phone-end-confirm-end')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(calls, contains('stopStream'));
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester, p, db);
  });

  testWidgets('system Back while sending asks instead of silently ending',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsOneWidget);
    expect(find.byType(PhoneBroadcastScreen), findsOneWidget);
    expect(calls, isNot(contains('stopStream')));
    await tester.tap(find.byKey(const Key('phone-end-stay')));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneBroadcastScreen), findsOneWidget);

    // The app-bar back arrow takes the same path.
    await tester.tap(
        find.byTooltip(const DefaultMaterialLocalizations().backButtonTooltip));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('phone-end-stay')));
    await tester.pumpAndSettle();
    await close(tester, p, db);
  });

  testWidgets('landscape: tapping media hides and restores focused End',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, size: const Size(568, 412), wideConfirmation: true);
    expect(endButton, findsOneWidget);
    Focus.of(tester.element(
            find.descendant(of: endButton, matching: find.byType(Text)).first))
        .requestFocus();
    await tester.pump();
    // Tap the picture to hide the overlay controls.
    await tester.tapAt(const Offset(450, 200));
    await tester.pumpAndSettle();
    expect(endButton.hitTestable(), findsNothing);
    await tester.tapAt(const Offset(450, 200));
    await tester.pumpAndSettle();
    expect(endButton.hitTestable(), findsOneWidget);
    await tester.tap(endButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('phone-end-stay')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await close(tester, p, db);
  });

  testWidgets('landscape has three toggled controls and End at the top left',
      (tester) async {
    final orientations = <List<dynamic>>[];
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') {
        orientations.add(List<dynamic>.from(call.arguments as List));
      }
      return null;
    });
    addTearDown(() =>
        messenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, size: const Size(915, 412));
    expect(orientations.single, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
    expect(tester.getTopLeft(endButton).dx, lessThan(20));
    expect(tester.getTopLeft(endButton).dy, lessThan(20));
    expect(find.byIcon(Icons.fullscreen_exit_rounded), findsNothing);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    final starts = calls.where((c) => c == 'startStream').length;
    await tester.tapAt(const Offset(450, 200));
    await tester.pump();
    expect(endButton, findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    await tester.tapAt(const Offset(450, 200));
    await tester.pump();
    expect(endButton.hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('live.tooltip_controls'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('live.front_camera_coming_soon'.tr()));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is AlertDialog), findsOneWidget);
    expect(calls, isNot(contains('switchCamera')));
    expect(calls.where((c) => c == 'startStream').length, starts);
    await tester.tap(find.text('common.close'.tr()));
    await tester.pumpAndSettle();
    Navigator.of(
            tester.element(find.text('live.front_camera_coming_soon'.tr())))
        .pop();
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-landscape-media')), findsNothing);
    expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
    expect(calls.where((c) => c == 'startStream').length, starts);
    expect(tester.takeException(), isNull);
    await close(tester, p, db);
  });

  testWidgets('Arabic: End and its confirmation are localized and lay out',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, locale: const Locale('ar'), wideConfirmation: true);
    expect(find.descendant(of: endButton, matching: find.text('إنهاء البث')),
        findsOneWidget);
    await tester.tap(endButton);
    await tester.pumpAndSettle();
    expect(find.text('إنهاء هذا البث؟'), findsOneWidget);
    expect(find.text('البقاء'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('phone-end-stay')));
    await tester.pumpAndSettle();
    await close(tester, p, db);
  });

  testWidgets('controls sheet copy is localized and says the camera stays on',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await tester.tap(find.byTooltip('live.tooltip_controls'.tr()).first);
    await tester.pumpAndSettle();
    expect(find.text('live.ctrl_mute'.tr()), findsOneWidget);
    expect(find.text('live.ctrl_hide_video'.tr()), findsOneWidget);
    expect(find.text('Close Camera (Audio-Only)'), findsNothing);
    expect(find.textContaining('poster'), findsNothing);
    expect('live.ctrl_video_hidden_sub'.tr(), contains('camera stays on'));
    await close(tester, p, db);
  });

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    testWidgets('End confirmation at 568x240 and 2x text: $locale',
        (tester) async {
      final db = _Db();
      final p = await tester.runAsync(() => broadcaster(db));
      await open(tester, p!,
          locale: locale,
          size: const Size(568, 240),
          textScale: 2,
          wideConfirmation: true);
      await tester.tap(endButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final stay = find.byKey(const Key('phone-end-stay'));
      await tester.ensureVisible(stay);
      expect(stay.hitTestable(), findsOneWidget);
      await tester.tap(stay);
      await tester.pumpAndSettle();
      await close(tester, p, db);
    });
  }

  for (final locale in [const Locale('en'), const Locale('ar')]) {
    for (final size in [
      const Size(568, 240),
      const Size(740, 360),
      const Size(1366, 768)
    ]) {
      testWidgets('landscape settings and chat at 2x: $locale $size',
          (tester) async {
        final db = _Db();
        final p = await tester.runAsync(() => broadcaster(db));
        await open(tester, p!, locale: locale, size: size, textScale: 2);
        tester.view.viewInsets = const FakeViewPadding(bottom: 190);
        await tester.pump();
        if (size.width >= 900 && size.height >= 600) {
          expect(find.byType(TextField), findsWidgets);
          expect(find.text('live.landscape_chat_read_only'.tr()), findsNothing);
          expect(tester.takeException(), isNull);
          await close(tester, p, db);
          return;
        }
        await tester.tap(find.byTooltip('live.tooltip_toggle_chat'.tr()));
        await tester.pump();
        expect(find.byType(TextField), findsNothing);
        expect(find.text('live.landscape_chat_read_only'.tr()), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('live.tooltip_controls'.tr()));
        await tester.pumpAndSettle();
        expect(find.byType(SingleChildScrollView), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
            find.text('design_ui.broadcaster_studio_end_stream'.tr()));
        await tester
            .tap(find.text('design_ui.broadcaster_studio_end_stream'.tr()));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNothing);
        expect(
            find.text('live.landscape_settings_portrait'.tr()), findsOneWidget);
        expect(tester.takeException(), isNull);
        await close(tester, p, db);
      });
    }
  }

  testWidgets('a second Back while ending never pops the page underneath',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, wideConfirmation: true);
    await tester.tap(endButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('phone-end-confirm-end')));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.tap(endButton, warnIfMissed: false);
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(find.text('home'), findsOneWidget, reason: 'home was not popped');
    await close(tester, p, db);
  });

  testWidgets('losing the device while the End dialog is open closes both',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, wideConfirmation: true);
    await tester.tap(endButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsOneWidget);
    db.devices.add([
      p.currentDeviceSession!.copyWith(isPrimaryBroadcaster: false),
      DeviceSessionModel(
          deviceId: 'other',
          deviceName: 'android Device',
          platform: 'android',
          lastActiveAt: DateTime.now()),
    ]);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsNothing);
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester, p, db);
  });

  testWidgets('live: the studio End goes through this screen and stops it',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await goLive(tester);
    expect(p.isBroadcastingLive, isTrue);
    InteractiveToastOverlay.dismiss();
    await tester.pump();
    await tester.tap(find.byTooltip('live.tooltip_studio'.tr()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('organization_v1.end'.tr()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('organization_v1.end'.tr()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phone-end-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('phone-end-confirm-end')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(calls, contains('stopStream'));
    expect(p.isBroadcastingLive, isFalse);
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    await close(tester, p, db);
  });

  testWidgets('live: a listing ended elsewhere in the app stops the encoder',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await goLive(tester);
    expect(p.isBroadcastingLive, isTrue);
    await tester.runAsync(() => p.setBroadcasterLive(false));
    await tester.pump();
    expect(calls, contains('stopStream'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(p.isBroadcastingLive, isFalse, reason: 'not re-listed');
    expect(find.descendant(of: endButton, matching: find.text('Leave')),
        findsOneWidget);
    await close(tester, p, db);
  });

  testWidgets(
      'remote End stops encoder, changes End to Leave and cannot relist',
      (tester) async {
    final db = _Db()..useSession = true;
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await goLive(tester);
    p.endBroadcastRemotelyForTesting('admin_end');
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
    expect(calls, contains('stopStream'));
    expect(find.descendant(of: endButton, matching: find.text('Leave')),
        findsOneWidget);
    await goLive(tester);
    expect(db.starts, 1,
        reason: 'a late encoder event cannot create a new session');
    expect(p.isBroadcastingLive, isFalse);
    expect(find.descendant(of: endButton, matching: find.text('Leave')),
        findsOneWidget);
    await close(tester, p, db);
  });

  testWidgets('portrait End remains reachable above the keyboard',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    expect(find.byType(PhoneCameraPreview), findsOneWidget);
    expect(
        tester
            .getRect(endButton)
            .overlaps(tester.getRect(find.byType(PhoneCameraPreview))),
        isTrue,
        reason:
            'Owner 5B supersedes D22: End belongs in the full-bleed camera HUD');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(find.byType(PhoneCameraPreview), findsOneWidget);
    expect(tester.getSize(find.byType(PhoneCameraPreview)).height, 100);
    expect(find.byType(TextField), findsWidgets);
    expect(endButton.hitTestable(), findsOneWidget);
    expect(tester.getBottomLeft(endButton).dy, lessThan(615));
    expect(tester.takeException(), isNull);
    await close(tester, p, db);
  });

  testWidgets(
      'a session ingest rejection stops the encoder without another start',
      (tester) async {
    final db = _Db()..useSession = true;
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await goLive(tester);
    db.rejectIngest = true;
    await tester.runAsync(() => messenger.handlePlatformMessage(
        events.name,
        events.codec
            .encodeSuccessEnvelope({'type': 'reconnecting', 'attempt': 1}),
        (_) {}));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(db.reports, [false]);
    expect(calls, contains('stopStream'));
    expect(db.starts, 1);
    expect(p.isBroadcastingLive, isFalse);
    expect(p.currentDeviceSession?.isPrimaryBroadcaster, isTrue);
    await close(tester, p, db);
  });

  testWidgets('360 px: End clears the muted badge and stays tappable',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, size: const Size(360, 780));
    await tester.tap(find.byTooltip('live.tooltip_controls'.tr()).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('live.ctrl_mute'.tr()));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    final badge = find.text('live.mic_muted_badge'.tr());
    expect(badge, findsOneWidget);
    expect(tester.getRect(badge).overlaps(tester.getRect(endButton)), isFalse);
    expect(endButton.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester, p, db);
  });

  testWidgets('live: an End the server does not confirm is said plainly',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!, wideConfirmation: true);
    await goLive(tester);
    InteractiveToastOverlay.dismiss();
    db.failStop = true;
    await tester.tap(endButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('phone-end-confirm-end')));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(calls, contains('stopStream'));
    expect(find.text('live.end_unconfirmed_title'.tr()), findsOneWidget);
    expect(find.byType(PhoneBroadcastScreen), findsNothing);
    await close(tester, p, db);
  });

  testWidgets('the studio opened here cannot open a second camera screen',
      (tester) async {
    final db = _Db();
    final p = await tester.runAsync(() => broadcaster(db));
    await open(tester, p!);
    await tester.tap(find.byTooltip('live.tooltip_studio'.tr()));
    await tester.pumpAndSettle();
    expect(find.text('organization_v1.prepare'.tr()), findsNothing);
    expect(calls.where((c) => c == 'startStream').length, 1);
    expect(find.byType(PhoneBroadcastScreen), findsOneWidget);
    await close(tester, p, db);
  });
}
