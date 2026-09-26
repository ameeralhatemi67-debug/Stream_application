import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';

import 'support/localized_app.dart';

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

/// Answers YouTube lookups without the network. The default says the link is
/// live on the approved test channel.
class _FakeYouTube extends YouTubeApiService {
  _FakeYouTube(
      {this.status = const YouTubeWatchStatus(YouTubeWatchState.live,
          channelId: 'UC_mine'),
      this.channelIdByHandle = const {'my_channel': 'UC_mine'},
      this.liveVideoId,
      this.searchUnavailable = false})
      : super(apiKey: '');
  final bool searchUnavailable;
  YouTubeWatchStatus status;
  final Map<String, String> channelIdByHandle;
  final String? liveVideoId;
  final checked = <String>[];
  final searchedChannels = <String>[];

  @override
  Future<YouTubeWatchStatus> fetchWatchStatus(String videoId) async {
    checked.add(videoId);
    return status;
  }

  @override
  Future<Map<String, String>> fetchChannelDetails(String handleOrUrl) async {
    final id = channelIdByHandle[handleOrUrl];
    return id == null ? {} : {'channelId': id};
  }

  @override
  Future<String?> fetchLiveVideoId(String channelId) async {
    searchedChannels.add(channelId);
    if (searchUnavailable) throw const YouTubeLookupUnavailable();
    return liveVideoId;
  }
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
  _StudioDb({this.primary = true, BroadcasterApplicationModel? app})
      : app = app ?? _approvedApp('my_channel');
  final bool primary;
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
      {'display_name_en': 'C', 'is_streamer': true, 'is_verified': true};
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

Future<AppProvider> _broadcaster(_StudioDb db, {_FakeYouTube? youTube}) async {
  final provider = AppProvider.withServices(
      authService: _Auth('c'),
      adminDbService: db,
      youTubeService: youTube ?? _FakeYouTube());
  for (var i = 0; i < 200 && provider.authHydrating; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  for (var i = 0; i < 50 && provider.currentDeviceSession == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openSheet(WidgetTester tester, AppProvider provider,
      {Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(412, 915);
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
          value: provider,
          child: MaterialApp(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            home: Scaffold(
              body: Builder(
                builder: (c) => Center(
                  child: TextButton(
                    onPressed: () => LiveBroadcasterStudioSheet.show(c),
                    child: const Text('open studio'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open studio'));
    await tester.pumpAndSettle();
  }

  /// The message must be the top-most thing under its own centre point:
  /// before this fix, feedback was a SnackBar painted beneath the sheet.
  void expectVisible(WidgetTester tester, Finder finder) {
    expect(finder, findsOneWidget);
    final result = HitTestResult();
    WidgetsBinding.instance
        .hitTestInView(result, tester.getCenter(finder), tester.view.viewId);
    final target = tester.renderObject(finder);
    expect(result.path.any((e) => identical(e.target, target)), isTrue,
        reason: 'message is covered by another layer');
  }

  Finder field(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == hint);
  final watchField = find.byKey(const Key('studio-watch-link-field'));
  final keyField = field('xxxx-xxxx-xxxx-xxxx-xxxx');

  Future<void> tapCta(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.text(key.tr()));
    await tester.tap(find.text(key.tr()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> close(WidgetTester tester, AppProvider provider,
      [_StudioDb? db]) async {
    InteractiveToastOverlay.dismiss();
    await tester.pumpWidget(const SizedBox.shrink());
    provider.dispose();
    await db?.devices.close();
    await tester.pump(const Duration(seconds: 1));
  }

  group('OBS', () {
    testWidgets('an unapproved account sees why, in front of the sheet',
        (tester) async {
      final provider = AppProvider();
      await openSheet(tester, provider);
      await tapCta(tester, 'live_studio.btn_go_live');
      expectVisible(tester, find.text('broadcast_approval_required'.tr()));
      expect(provider.isBroadcastingLive, isFalse);
      await close(tester, provider);
    });

    testWidgets(
        'a non-primary device is told so and can ask the server for the role',
        (tester) async {
      final db = _StudioDb(primary: false);
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tapCta(tester, 'live_studio.btn_go_live');
      expectVisible(tester, find.text('broadcast_primary_required'.tr()));
      final claimsBefore = db.claims;
      await tester.tap(find.text('live_studio.action_use_this_device'.tr()));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(db.claims, claimsBefore + 1);
      expect(db.liveCalls, 0);
      await close(tester, provider, db);
    });

    testWidgets('a missing watch ID is explained and nothing is sent',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tapCta(tester, 'live_studio.btn_go_live');
      expectVisible(
          tester, find.text('live_studio.error_watch_id_required'.tr()));
      expect(db.liveCalls, 0);
      await close(tester, provider, db);
    });

    testWidgets(
        'server acceptance closes the sheet with an app-only live label; '
        'a double tap sends one request', (tester) async {
      final db = _StudioDb()..liveGate = Completer<void>();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.enterText(watchField, 'https://youtu.be/abcdefghijk');
      await tester.ensureVisible(find.text('live_studio.btn_go_live'.tr()));
      await tester.tap(find.text('live_studio.btn_go_live'.tr()));
      await tester.tap(find.text('live_studio.btn_go_live'.tr()),
          warnIfMissed: false);
      await tester.pump();
      expect(provider.isBroadcastingLive, isFalse,
          reason: 'no LIVE before the server answers');
      db.liveGate!.complete();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pumpAndSettle();
      expect(db.liveCalls, 1);
      expect(provider.isBroadcastingLive, isTrue);
      expect(find.byType(LiveBroadcasterStudioSheet), findsNothing);
      expect(
          find.text('live_studio.obs_listed_live_title'.tr()), findsOneWidget);
      await close(tester, provider, db);
    });

    testWidgets('a server refusal stays offline and is shown in the sheet',
        (tester) async {
      final db = _StudioDb()
        ..refuseLive = const PostgrestException(
            message: 'Broadcast not permitted', code: '42501');
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.enterText(watchField, 'abcdefghijk');
      await tapCta(tester, 'live_studio.btn_go_live');
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(provider.isBroadcastingLive, isFalse);
      expectVisible(tester, find.text('broadcast_approval_required'.tr()));
      await close(tester, provider, db);
    });

    testWidgets('closing the sheet while the request is pending is safe',
        (tester) async {
      final db = _StudioDb()..liveGate = Completer<void>();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.enterText(watchField, 'abcdefghijk');
      await tapCta(tester, 'live_studio.btn_go_live');
      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();
      expect(find.byType(LiveBroadcasterStudioSheet), findsNothing);
      db.liveGate!.complete();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // The provider reflects the server's answer, not the closed sheet.
      expect(provider.isBroadcastingLive, isTrue);
      await close(tester, provider, db);
    });
  });

  group('Phone', () {
    testWidgets('missing key and missing watch link are each explained',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tapCta(tester, 'live_studio.btn_open_camera');
      expectVisible(tester,
          find.text('live_studio.toast_stream_key_required_message'.tr()));

      await tester.enterText(keyField, 'disposable-key');
      await tapCta(tester, 'live_studio.btn_open_camera');
      expectVisible(tester, find.text('live.watch_url_required'.tr()));
      expect(find.byType(PhoneBroadcastScreen), findsNothing);
      await close(tester, provider, db);
    });

    testWidgets('valid input opens PhoneBroadcastScreen once on a double tap',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tester.enterText(
          watchField, 'https://www.youtube.com/watch?v=abcdefghijk');
      await tester.enterText(keyField, 'disposable-key');
      await tester.pump();
      final cta = find.text('live_studio.btn_open_camera'.tr());
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.tap(cta, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PhoneBroadcastScreen), findsOneWidget);
      expect(find.text('open studio', skipOffstage: false), findsOneWidget,
          reason: 'the page under the sheet was not popped');
      expect(provider.isBroadcastingLive, isFalse,
          reason: 'opening the camera is not going live');
      // Only the typed key and watch ID are used -- no simulated session.
      expect(provider.phoneBroadcastStreamKey, 'disposable-key');
      expect(provider.customYouTubeVideoId, 'abcdefghijk');
      // Camera/permission plugins are absent in widget tests.
      tester.takeException();
      await close(tester, provider, db);
    });

    testWidgets(
        'outside the Android app, Phone explains that it is unavailable',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tapCta(tester, 'live_studio.btn_open_camera');
      expectVisible(
          tester, find.text('live_studio.error_phone_unsupported'.tr()));
      debugDefaultTargetPlatformOverride = null;
      await close(tester, provider, db);
    });

    testWidgets('Arabic: the refusal is visible and the sheet lays out',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!, locale: const Locale('ar'));
      await tester.tap(find.text('design_copy.phone'.tr()));
      await tester.pumpAndSettle();
      await tester.enterText(keyField, 'disposable-key');
      await tapCta(tester, 'live_studio.btn_open_camera');
      expectVisible(tester, find.text('live.watch_url_required'.tr()));
      expect(tester.takeException(), isNull);
      await close(tester, provider, db);
    });
  });

  group('Watch link and sender (P6S Group 2)', () {
    Future<void> goLive(WidgetTester tester, String link) async {
      await tester.enterText(watchField, link);
      await tapCta(tester, 'live_studio.btn_go_live');
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }

    for (final (state, key) in [
      (YouTubeWatchState.notFound, 'live_studio.watch_check_not_found'),
      (YouTubeWatchState.ended, 'live_studio.watch_check_ended'),
      (YouTubeWatchState.notLive, 'live_studio.watch_check_not_live'),
    ]) {
      testWidgets('a ${state.name} link is refused before anything is listed',
          (tester) async {
        final db = _StudioDb();
        final yt = _FakeYouTube(status: YouTubeWatchStatus(state));
        final provider =
            await tester.runAsync(() => _broadcaster(db, youTube: yt));
        await openSheet(tester, provider!);
        await goLive(tester, 'https://youtu.be/abcdefghijk');
        expect(yt.checked, ['abcdefghijk']);
        expectVisible(tester, find.text(key.tr()));
        expect(db.liveCalls, 0);
        expect(provider.isBroadcastingLive, isFalse);
        expect(provider.customYouTubeVideoId, isEmpty,
            reason: 'a refused link is not stored as the watch target');
        await close(tester, provider, db);
      });
    }

    testWidgets(
        'a live link on another channel than the approved one is refused',
        (tester) async {
      final db = _StudioDb(app: _approvedApp('my_channel'));
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.live,
              channelId: 'UC_someone_else'),
          channelIdByHandle: {'my_channel': 'UC_mine'});
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await openSheet(tester, provider!);
      await goLive(tester, 'abcdefghijk');
      expectVisible(
          tester, find.text('live_studio.watch_check_wrong_channel'.tr()));
      expect(db.liveCalls, 0);
      await close(tester, provider, db);
    });

    testWidgets('a live link on the approved channel is listed as verified',
        (tester) async {
      final db = _StudioDb(app: _approvedApp('my_channel'));
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.live,
              channelId: 'UC_mine'),
          channelIdByHandle: {'my_channel': 'UC_mine'});
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      final check =
          await tester.runAsync(() => provider!.verifyWatchLink('abcdefghijk'));
      expect(check!.verdict, WatchLinkVerdict.live);
      expect(check.channelVerified, isTrue);
      await close(tester, provider!, db);
    });

    testWidgets('YouTube outage fails closed before listing', (tester) async {
      final db = _StudioDb();
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.unavailable));
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await openSheet(tester, provider!);
      await goLive(tester, 'abcdefghijk');
      await tester.pumpAndSettle();
      expect(db.liveCalls, 0);
      expect(provider.isBroadcastingLive, isFalse);
      expect(find.textContaining('live_studio.watch_check_unavailable'.tr()),
          findsOneWidget);
      await close(tester, provider, db);
    });

    testWidgets(
        'a verified link lists without the unchecked note and records '
        'OBS on a computer as the sender', (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await goLive(tester, 'abcdefghijk');
      await tester.pumpAndSettle();
      expect(db.senderModes, ['obs_laptop']);
      expect(
          find.textContaining('live_studio.watch_check_unverified_note'.tr()),
          findsNothing);
      await close(tester, provider, db);
    });

    testWidgets('external phone is unavailable and cannot change sender mode',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      final chip = find.byKey(const Key('studio-sender-external_phone'));
      await tester.ensureVisible(chip);
      expect(tester.widget<ChoiceChip>(chip).onSelected, isNull);
      expect(find.text('live.external_phone_unavailable'.tr()), findsOneWidget);
      provider.setBroadcastSenderMode('external_phone');
      expect(provider.broadcastSenderMode, isNot('external_phone'));
      await close(tester, provider, db);
    });

    testWidgets(
        'the Encoder tab never shows or offers to copy a stream key or '
        'ingest URL', (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      provider!.updatePhoneBroadcastTarget(
          rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2',
          streamKey: 'abcd-efgh-ijkl-mnop-qrst');
      await openSheet(tester, provider);
      expect(find.byKey(const Key('studio-encoder-key-note')), findsOneWidget);
      expect(find.textContaining('abcd-efgh'), findsNothing);
      expect(find.textContaining('rtmp://'), findsNothing);
      expect(find.text('design_copy.stream_key'.tr()), findsNothing);
      expect(find.text('design_copy.ingest_server_url'.tr()), findsNothing);
      await close(tester, provider, db);
    });

    testWidgets('a stream key pasted as the watch link is caught unsent',
        (tester) async {
      final db = _StudioDb();
      final yt = _FakeYouTube();
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await openSheet(tester, provider!);
      await goLive(tester, 'abcd-efgh-ijkl-mnop-qrst');
      expectVisible(
          tester, find.text('live_studio.error_key_in_watch_field'.tr()));
      expect(yt.checked, isEmpty, reason: 'the key never leaves the device');
      expect(db.liveCalls, 0);
      await close(tester, provider, db);
    });

    testWidgets('Phone: a watch link pasted as the stream key is caught',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tester.enterText(
          keyField, 'https://www.youtube.com/watch?v=abcdefghijk');
      await tapCta(tester, 'live_studio.btn_open_camera');
      expectVisible(
          tester, find.text('live_studio.error_watch_in_key_field'.tr()));
      expect(find.byType(PhoneBroadcastScreen), findsNothing);
      expect(provider.phoneBroadcastStreamKey, isEmpty);
      await close(tester, provider, db);
    });

    testWidgets('Phone: an ended watch link is refused before the camera',
        (tester) async {
      final db = _StudioDb();
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.ended));
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await openSheet(tester, provider!);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tester.enterText(watchField, 'abcdefghijk');
      await tester.enterText(keyField, 'disposable-key');
      await tapCta(tester, 'live_studio.btn_open_camera');
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
      expectVisible(tester, find.text('live_studio.watch_check_ended'.tr()));
      expect(find.byType(PhoneBroadcastScreen), findsNothing);
      expect(provider.phoneBroadcastStreamKey, isEmpty);
      await close(tester, provider, db);
    });

    testWidgets('Find my live broadcast searches only this account channel',
        (tester) async {
      final db = _StudioDb(app: _approvedApp('my_channel'));
      final yt = _FakeYouTube(
          channelIdByHandle: {'my_channel': 'UC_mine'},
          liveVideoId: 'zyxwvutsrqp');
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      final found =
          await tester.runAsync(() => provider!.findMyLiveBroadcast());
      expect(found, isTrue);
      expect(yt.searchedChannels, ['UC_mine']);
      expect(provider!.customYouTubeVideoId, 'zyxwvutsrqp');
      expect(provider.isBroadcastingLive, isFalse,
          reason: 'finding a link never marks anything live');
      await close(tester, provider, db);
    });

    testWidgets('Find my live broadcast without a channel on record explains',
        (tester) async {
      final db = _StudioDb(app: _approvedApp(''));
      final yt = _FakeYouTube(liveVideoId: 'zyxwvutsrqp');
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      final found =
          await tester.runAsync(() => provider!.findMyLiveBroadcast());
      expect(found, isFalse);
      expect(yt.searchedChannels, isEmpty);
      expect(provider!.findMyLiveBroadcastErrorKey,
          'live_studio.find_live_no_channel');
      expect(provider.customYouTubeVideoId, isEmpty);
      await close(tester, provider, db);
    });

    testWidgets(
        'a live link with no channel on record says the channel was not '
        'matched', (tester) async {
      final db = _StudioDb(app: _approvedApp(''));
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await goLive(tester, 'abcdefghijk');
      await tester.pumpAndSettle();
      expect(db.liveCalls, 0);
      expect(
          find.textContaining('live_studio.watch_check_channel_required'.tr()),
          findsOneWidget);
      await close(tester, provider, db);
    });

    testWidgets('a matched channel shows no channel note', (tester) async {
      final db = _StudioDb(app: _approvedApp('my_channel'));
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.live,
              channelId: 'UC_mine'),
          channelIdByHandle: {'my_channel': 'UC_mine'});
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await openSheet(tester, provider!);
      await goLive(tester, 'abcdefghijk');
      await tester.pumpAndSettle();
      expect(db.liveCalls, 1);
      expect(
          find.textContaining(
              'live_studio.watch_check_channel_unconfirmed_note'.tr()),
          findsNothing);
      await close(tester, provider, db);
    });

    testWidgets('a channel URL on record is compared without a lookup',
        (tester) async {
      const id = 'UCabcdefghijklmnopqrstuv';
      final db = _StudioDb(
          app: _approvedApp(id)
              .copyWith(youtubeChannelUrl: 'https://youtube.com/channel/$id'));
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.live,
              channelId: 'UCzzzzzzzzzzzzzzzzzzzzzz'));
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      final check =
          await tester.runAsync(() => provider!.verifyWatchLink('abcdefghijk'));
      expect(check!.verdict, WatchLinkVerdict.wrongChannel);
      await close(tester, provider!, db);
    });

    testWidgets('a broadcast scheduled hours ahead is refused for now',
        (tester) async {
      final db = _StudioDb();
      final yt = _FakeYouTube(
          status: YouTubeWatchStatus(YouTubeWatchState.upcoming,
              scheduledStart: DateTime.now().add(const Duration(hours: 5))));
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await openSheet(tester, provider!);
      await goLive(tester, 'abcdefghijk');
      expectVisible(
          tester, find.text('live_studio.watch_check_scheduled_later'.tr()));
      expect(db.liveCalls, 0);
      await close(tester, provider, db);
    });

    testWidgets('unavailable sender cannot silently replace OBS selection',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      final chip = find.byKey(const Key('studio-sender-external_phone'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      await goLive(tester, 'abcdefghijk');
      expect(db.senderModes, ['obs_laptop']);
      await close(tester, provider, db);
    });

    testWidgets('Phone: the server address pasted as the key is named',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tester.enterText(keyField, 'rtmp://a.rtmp.youtube.com/live2');
      await tapCta(tester, 'live_studio.btn_open_camera');
      expectVisible(
          tester, find.text('live_studio.error_ingest_in_key_field'.tr()));
      await close(tester, provider, db);
    });

    testWidgets('Find my live broadcast: a YouTube outage is not "none"',
        (tester) async {
      final db = _StudioDb(app: _approvedApp('my_channel'));
      final yt = _FakeYouTube(
          channelIdByHandle: {'my_channel': 'UC_mine'},
          searchUnavailable: true);
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      final found =
          await tester.runAsync(() => provider!.findMyLiveBroadcast());
      expect(found, isFalse);
      expect(provider!.findMyLiveBroadcastErrorKey,
          'live_studio.find_live_unavailable');
      await close(tester, provider, db);
    });

    testWidgets('Find my live broadcast is throttled to spare shared quota',
        (tester) async {
      final db = _StudioDb(app: _approvedApp('my_channel'));
      final yt = _FakeYouTube(
          channelIdByHandle: {'my_channel': 'UC_mine'}, liveVideoId: null);
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await tester.runAsync(() => provider!.findMyLiveBroadcast());
      await tester.runAsync(() => provider!.findMyLiveBroadcast());
      expect(yt.searchedChannels, ['UC_mine'], reason: 'one search only');
      expect(
          provider!.findMyLiveBroadcastErrorKey, 'live_studio.find_live_wait');
      await close(tester, provider, db);
    });

    testWidgets('Arabic: the Encoder tab and its sender choice lay out',
        (tester) async {
      final db = _StudioDb();
      final provider = await tester.runAsync(() => _broadcaster(db));
      await openSheet(tester, provider!, locale: const Locale('ar'));
      expect(find.text('live_studio.mode_encoder'.tr()), findsOneWidget);
      expect(find.byKey(const Key('studio-sender-obs_laptop')), findsOneWidget);
      final chip = find.byKey(const Key('studio-sender-external_phone'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      expect(find.text('live.external_phone_unavailable'.tr()),
          findsOneWidget);
      expect(find.byKey(const Key('studio-encoder-key-note')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester, provider, db);
    });

    testWidgets('a handle that merely starts with UC is looked up, not parsed',
        (tester) async {
      const handle = 'UCLA_Bruins_Official_Channel';
      final db = _StudioDb(app: _approvedApp(handle));
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.live,
              channelId: 'UC_real_bruins'),
          channelIdByHandle: {handle: 'UC_real_bruins'});
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      final check =
          await tester.runAsync(() => provider!.verifyWatchLink('abcdefghijk'));
      expect(check!.verdict, WatchLinkVerdict.live);
      expect(check.channelVerified, isTrue);
      await close(tester, provider!, db);
    });

    testWidgets('a handle on record that cannot be looked up gets its own note',
        (tester) async {
      final db = _StudioDb(app: _approvedApp('my_channel'));
      final provider = await tester.runAsync(() =>
          _broadcaster(db, youTube: _FakeYouTube(channelIdByHandle: const {})));
      final check =
          await tester.runAsync(() => provider!.verifyWatchLink('abcdefghijk'));
      expect(check!.errorKey, 'live_studio.watch_check_channel_required');
      await close(tester, provider!, db);
    });

    for (final (name, makeYouTube, key) in [
      (
        'wrong channel',
        () => _FakeYouTube(
            status: const YouTubeWatchStatus(YouTubeWatchState.live,
                channelId: 'UC_someone_else'),
            channelIdByHandle: {'my_channel': 'UC_mine'}),
        'live_studio.watch_check_wrong_channel'
      ),
      (
        'scheduled later',
        () => _FakeYouTube(
            status: YouTubeWatchStatus(YouTubeWatchState.upcoming,
                scheduledStart: DateTime.now().add(const Duration(hours: 3)))),
        'live_studio.watch_check_scheduled_later'
      ),
    ]) {
      testWidgets('Phone: a $name link is refused before the camera',
          (tester) async {
        final db = _StudioDb(app: _approvedApp('my_channel'));
        final provider = await tester
            .runAsync(() => _broadcaster(db, youTube: makeYouTube()));
        await openSheet(tester, provider!);
        await tester.tap(find.text('Phone'));
        await tester.pumpAndSettle();
        await tester.enterText(watchField, 'abcdefghijk');
        await tester.enterText(keyField, 'disposable-key');
        await tapCta(tester, 'live_studio.btn_open_camera');
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
        expectVisible(tester, find.text(key.tr()));
        expect(find.byType(PhoneBroadcastScreen), findsNothing);
        await close(tester, provider, db);
      });
    }

    testWidgets('Phone: lookup outage refuses before opening the camera',
        (tester) async {
      final db = _StudioDb();
      final yt = _FakeYouTube(
          status: const YouTubeWatchStatus(YouTubeWatchState.unavailable));
      final provider =
          await tester.runAsync(() => _broadcaster(db, youTube: yt));
      await openSheet(tester, provider!);
      await tester.tap(find.text('Phone'));
      await tester.pumpAndSettle();
      await tester.enterText(watchField, 'abcdefghijk');
      await tester.enterText(keyField, 'disposable-key');
      await tapCta(tester, 'live_studio.btn_open_camera');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PhoneBroadcastScreen), findsNothing);
      expect(find.text('live_studio.watch_check_unavailable'.tr()),
          findsOneWidget);
      expect(provider.phoneBroadcastStreamKey, isEmpty);
      expect(db.liveCalls, 0);
      expect(tester.takeException(), isNull);
      await close(tester, provider, db);
    });

    test('key and watch-link shapes are told apart', () {
      expect(looksLikeStreamKey('abcd-efgh-ijkl-mnop-qrst'), isTrue);
      expect(looksLikeStreamKey('abcd-1234-ef56-gh78'), isTrue);
      expect(looksLikeStreamKey('abcdefghijk'), isFalse);
      expect(looksLikeStreamKey('https://youtu.be/abcdefghijk'), isFalse);
      expect(looksLikeWatchLink('https://youtu.be/abcdefghijk'), isTrue);
      expect(looksLikeWatchLink('youtube.com/live/abcdefghijk'), isTrue);
      expect(looksLikeWatchLink('abcd-efgh-ijkl-mnop-qrst'), isFalse);
      expect(looksLikeWatchLink('abcdefghijk'), isTrue,
          reason: 'a bare video ID is not a key');
      expect(looksLikeIngestUrl('rtmps://a.rtmps.youtube.com/live2'), isTrue);
      expect(looksLikeIngestUrl('abcd-efgh-ijkl-mnop-qrst'), isFalse);
    });
  });

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

  testWidgets('Local is visibly unavailable and saves nothing', (tester) async {
    final provider = AppProvider();
    await openSheet(tester, provider);
    await tester.tap(find.text('Local'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('local-unavailable')), findsOneWidget);
    expect(
        find.byType(TextField).evaluate().any((e) =>
            (e.widget as TextField).decoration?.hintText ==
            'e.g. 192.168.1.100'),
        isFalse);
    await tapCta(tester, 'live_studio.btn_local_unavailable');
    expectVisible(
        tester,
        find.descendant(
            of: find.byKey(const ValueKey('studio-cta-error')),
            matching: find.text('live_studio.local_unavailable_body'.tr())));
    expect(find.byType(TextField), findsNothing);
    await close(tester, provider);
  });
}
