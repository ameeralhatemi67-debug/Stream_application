import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/admin_safety_backend.dart';
import 'package:streamer_app/core/services/youtube_api_service.dart';

class TestAuth extends SupabaseAuthService {
  final changes = StreamController<AuthState>.broadcast(sync: true);
  Session? session;
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => changes.stream;
  void signIn(String id, [AuthChangeEvent event = AuthChangeEvent.signedIn]) {
    session = Session(
        accessToken: 'test-only',
        tokenType: 'bearer',
        user: User(
            id: id,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-09-23T00:00:00Z',
            email: '$id@example.invalid'));
    changes.add(AuthState(event, session));
  }

  void signOutNow() {
    session = null;
    changes.add(const AuthState(AuthChangeEvent.signedOut, null));
  }
}

class SessionDb extends AdminDatabaseService {
  final devices =
      StreamController<List<DeviceSessionModel>>.broadcast(sync: true);
  bool approved = false;
  bool allowed = false;
  int claims = 0;
  Completer<void>? profileDelay;
  bool delayFirstProfileOnly = false;
  int profileReads = 0;
  Completer<void>? liveDelay;
  bool rejectLive = false;
  @override
  Future<bool> checkIsProfileStreamer(String id) async => approved;
  @override
  Future<Map<String, dynamic>?> loadOwnProfile(String id) async {
    final read = ++profileReads;
    if (id == 'a' && (!delayFirstProfileOnly || read == 1)) {
      await profileDelay?.future;
    }
    return {
      'display_name_en': 'Profile $id',
      'banner_url': delayFirstProfileOnly ? '$id-$read.png' : '$id.png'
    };
  }

  @override
  Future<bool> claimDevice(DeviceSessionModel device,
      {bool force = false}) async {
    claims++;
    return true;
  }

  @override
  Stream<List<DeviceSessionModel>> watchDevices(String userId) =>
      devices.stream;
  @override
  Future<bool> canBroadcast({String? orgId, required String type}) async =>
      allowed;
  @override
  Future<void> setLiveState(
      {required bool live,
      required String type,
      required String? streamId,
      required String deviceId,
      String? orgId}) async {
    await liveDelay?.future;
    if (rejectLive) {
      throw const PostgrestException(
          message: 'Broadcast not permitted', code: '42501');
    }
  }
}

Future<void> hydrated(AppProvider p) async {
  for (var i = 0; i < 100 && p.authHydrating; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(p.authHydrating, isFalse);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('role choice survives restart for its account, not the next account',
      () async {
    final auth = TestAuth();
    final db = SessionDb();
    var p = AppProvider.withServices(authService: auth, adminDbService: db);
    auth.signIn('a');
    await hydrated(p);
    expect(p.hasCompletedRoleSelection, isFalse);
    p.selectViewerRole();
    await Future<void>.delayed(Duration.zero);
    expect(
        (await SharedPreferences.getInstance())
            .getBool('has_completed_role_selection_a'),
        isTrue);
    p.dispose();
    p = AppProvider.withServices(authService: auth, adminDbService: db);
    await hydrated(p);
    expect(p.hasCompletedRoleSelection, isTrue);
    auth.signIn('b');
    await hydrated(p);
    expect(p.hasCompletedRoleSelection, isFalse);
    expect(p.userProfile.bannerUrl, 'b.png');
    p.dispose();
    await auth.changes.close();
    await db.devices.close();
  });

  test(
      'late hydration from account A cannot overwrite B or a signed-out session',
      () async {
    final auth = TestAuth();
    final db = SessionDb()..profileDelay = Completer<void>();
    final p = AppProvider.withServices(authService: auth, adminDbService: db);
    auth.signIn('a');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    auth.signIn('b');
    await hydrated(p);
    db.profileDelay!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(p.userProfile.bannerUrl, 'b.png');
    auth.signOutNow();
    expect(p.isLoggedInStreamer, isFalse);
    expect(p.hasCompletedRoleSelection, isFalse);
    p.dispose();
    await auth.changes.close();
    await db.devices.close();
  });

  test('sign out and back into the same account discards the old hydration',
      () async {
    final auth = TestAuth();
    final db = SessionDb()
      ..profileDelay = Completer<void>()
      ..delayFirstProfileOnly = true;
    final p = AppProvider.withServices(authService: auth, adminDbService: db);
    auth.signIn('a');
    for (var i = 0; i < 100 && db.profileReads == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    expect(db.profileReads, 1);
    auth.signOutNow();
    auth.signIn('a');
    await hydrated(p);
    expect(p.userProfile.bannerUrl, 'a-2.png');
    db.profileDelay!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(p.userProfile.bannerUrl, 'a-2.png');
    p.dispose();
    await auth.changes.close();
    await db.devices.close();
  });

  test(
      'transfer demotes old device; viewer choice survives refresh and realtime',
      () async {
    final auth = TestAuth();
    final db = SessionDb()..approved = true;
    final p = AppProvider.withServices(authService: auth, adminDbService: db);
    auth.signIn('a');
    await hydrated(p);
    expect(p.currentDeviceSession!.isPrimaryBroadcaster, isTrue);
    final other = DeviceSessionModel(
        deviceId: 'other',
        deviceName: 'Other phone',
        platform: 'android',
        lastActiveAt: DateTime.now(),
        isPrimaryBroadcaster: true);
    db.devices.add([other]);
    expect(p.currentDeviceSession!.isPrimaryBroadcaster, isFalse);
    expect(p.isStreamerModeEnabled, isFalse);
    expect(p.isBroadcastingLive, isFalse);
    expect(p.broadcastSessionError, 'broadcast_session_lost');
    p.continueAsViewerOnCurrentDevice();
    final claims = db.claims;
    auth.signIn('a', AuthChangeEvent.tokenRefreshed);
    await hydrated(p);
    db.devices.add([other]);
    expect(db.claims, claims);
    expect(p.remoteBroadcasterSession, isNull);
    expect(p.isStreamerModeEnabled, isFalse);
    await p.transferBroadcasterToCurrentDevice();
    expect(p.isStreamerModeEnabled, isTrue);
    expect(p.currentDeviceSession!.isPrimaryBroadcaster, isTrue);
    p.dispose();
    await auth.changes.close();
    await db.devices.close();
  });

  test(
      'live state waits for RPC success; denial stays offline and explains approval',
      () async {
    final auth = TestAuth();
    final db = SessionDb()
      ..approved = true
      ..liveDelay = Completer<void>()
      ..rejectLive = true;
    final p = AppProvider.withServices(authService: auth, adminDbService: db);
    auth.signIn('a');
    await hydrated(p);
    expect(await p.checkBroadcastPermission(), isFalse);
    expect(p.broadcastSessionError, 'broadcast_approval_required');
    final attempt = p.setBroadcasterLive(true);
    expect(p.isBroadcastingLive, isFalse);
    db.liveDelay!.complete();
    await attempt;
    expect(p.isBroadcastingLive, isFalse);
    expect(p.broadcastSessionError, 'broadcast_approval_required');
    p.dispose();
    await auth.changes.close();
    await db.devices.close();
  });

  test('stop queued during a pending start cannot leave server-confirmed LIVE',
      () async {
    final auth = TestAuth();
    final db = SessionDb()
      ..approved = true
      ..liveDelay = Completer<void>();
    final p = AppProvider.withServices(authService: auth, adminDbService: db);
    auth.signIn('a');
    await hydrated(p);
    final start = p.setBroadcasterLive(true);
    final stop = p.setBroadcasterLive(false);
    expect(p.isBroadcastingLive, isFalse);
    db.liveDelay!.complete();
    await Future.wait([start, stop]);
    expect(p.isBroadcastingLive, isFalse);
    p.dispose();
    await auth.changes.close();
    await db.devices.close();
  });

  test(
      'audit filters are server-side with UTC bounds and stable timestamp/id cursor',
      () async {
    final requests = <Uri>[];
    final client = SupabaseClient('http://localhost:9999', 'test-only',
        httpClient: MockClient((r) async {
      requests.add(r.url);
      return http.Response('[]', 200,
          request: r, headers: {'content-type': 'application/json'});
    }));
    final backend = SupabaseAdminSafetyBackend(client: client);
    final cursor = AdminAuditEntry(
        id: '00000000-0000-4000-8000-000000000001',
        action: 'accountBanned',
        actorName: '',
        actorEmail: '',
        descriptionEn: '',
        descriptionAr: '',
        createdAt: DateTime.utc(2026, 9, 22, 12));
    await backend.loadAudit(
        action: 'accountBanned',
        actorEmail: ' admin@example.invalid ',
        since: DateTime.utc(2026, 9, 21),
        until: DateTime.utc(2026, 9, 24),
        after: cursor,
        offset: 50);
    final q = requests.single.queryParametersAll;
    expect(q['actor_email'], ['eq.admin@example.invalid']);
    expect(q['action'], ['eq.accountBanned']);
    expect(
        q['created_at'],
        containsAll(
            ['gte.2026-09-21T00:00:00.000Z', 'lt.2026-09-24T00:00:00.000Z']));
    expect(q['order'], ['created_at.desc.nullslast,id.desc.nullslast']);
    expect(q['or']!.single, contains('id.lt.${cursor.id}'));
    expect(q['offset'], ['0']);
    await client.dispose();
  });

  test(
      'absent and failed YouTube channel data never requests an unrelated playlist',
      () async {
    final requests = <Uri>[];
    final service = YouTubeApiService(
        apiKey: 'test-only',
        client: MockClient((r) async {
          requests.add(r.url);
          return http.Response(jsonEncode({'items': []}), 200);
        }));
    expect(await service.fetchChannelVideos(streamerId: 'a'), isEmpty);
    expect(requests, isEmpty);
    expect(await service.fetchChannelVideos(streamerId: 'a', handle: 'unknown'),
        isEmpty);
    expect(requests.length, 1);
    expect(requests.single.path, endsWith('/channels'));
  });
}
