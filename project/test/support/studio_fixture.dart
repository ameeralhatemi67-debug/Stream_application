import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/organization_broadcast_service.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/services/youtube_api_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';
import 'package:streamer_app/features/organization/models/org_membership.dart';

/// A signed-in, approved broadcaster on the device that holds the broadcast,
/// with a scripted backend. The same doubles as in
/// `broadcaster_studio_entry_test.dart`, shared so other studio tests can
/// walk the real prepare, start and end flow.

class StudioAuth extends SupabaseAuthService {
  StudioAuth(String id)
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

BroadcasterApplicationModel studioApprovedApp(String handle) =>
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

class StudioDb extends AdminDatabaseService {
  StudioDb({BroadcasterApplicationModel? app})
      : app = app ?? studioApprovedApp('my_channel');
  final bool primary = true;
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
  Future<Map<String, dynamic>?> loadOwnProfile(String id) async => {
        'display_name_en': 'C',
        'is_streamer': true,
        'is_verified': true,
        'personal_broadcast_approved': true
      };
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

Future<AppProvider> studioBroadcaster(StudioDb db,
    {StudioBroadcasts? broadcasts}) async {
  final provider = AppProvider.withServices(
      authService: StudioAuth('c'),
      organizationBroadcastService: broadcasts ?? StudioBroadcasts(),
      adminDbService: db,
      youTubeService: YouTubeApiService(apiKey: ''));
  for (var i = 0; i < 200 && provider.authHydrating; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  for (var i = 0; i < 50 && provider.currentDeviceSession == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  return provider;
}

class StudioBroadcasts extends OrganizationBroadcastService {
  static const destination = ChannelConnection(
      id: 'connection',
      ownerId: 'c',
      organizationId: null,
      channelId: 'UC_test',
      title: 'Confirmed channel',
      status: 'connected',
      revision: 2);
  int creates = 0, prepares = 0;
  String? createdTitle;
  bool failPrepare = false, failEnd = false;
  Completer<void>? startGate;
  Object? startError;
  final actions = <String>[];
  Map<String, dynamic> row = {
    'id': 'session',
    'owner_id': 'c',
    'org_id': null,
    'state': 'scheduled',
    'revision': 1,
    'title_en': 'A show',
    'title_ar': 'برنامج',
    'broadcast_type': 'liveVideo',
    'accepted_at': '2026-10-01',
    'sender_mode': 'obs_laptop',
    'stream_id': 'abcdefghijk'
  };

  /// What the account has connected; one personal channel by default.
  List<ChannelConnection> channels = const [destination];
  @override
  Future<List<ChannelConnection>> connections() async => channels;
  @override
  Future<List<OrgMembership>> memberships({String? organizationId}) async => [];
  @override
  Future<List<BroadcastSession>> sessions(
          {String? organizationId, bool mine = false}) async =>
      creates == 0 ? [] : [BroadcastSession.fromRow(row)];
  int reads = 0;
  final updates = <(String, String)>[], hideChoices = <bool>[];
  @override
  Future<BroadcastSession?> session(String id) async {
    reads++;
    return BroadcastSession.fromRow(row);
  }

  @override
  Future<String> createPersonal(String title, String type) async {
    creates++;
    createdTitle = title;
    return 'session';
  }

  @override
  Future<Map<String, dynamic>> updatePersonal(
      String id, String title, String type) async {
    updates.add((title, type));
    row['title_en'] = title;
    row['broadcast_type'] = type;
    return Map<String, dynamic>.of(row);
  }

  @override
  Future<void> setHideReplay(String id, bool hidden) async {
    hideChoices.add(hidden);
    row['hide_replay'] = hidden;
  }

  @override
  Future<Map<String, dynamic>> control(
      String sessionId, String deviceId, String sender, String action,
      {ChannelConnection? destination}) async {
    actions.add(action);
    if (action == 'prepare') {
      prepares++;
      row['channel_connection_id'] = destination?.id ?? 'connection';
      row['sender_mode'] = sender;
      row['state'] = 'preparing';
      if (failPrepare) {
        throw const FunctionException(
            status: 409, details: {'error': 'feed_creation_unresolved'});
      }
      return {
        'session': Map<String, dynamic>.of(row),
        'ingest_url': 'rtmps://a.rtmps.youtube.com/live2',
        'ingest_key': 'test-only-key'
      };
    }
    if (action == 'start') {
      await startGate?.future;
      if (startError != null) throw startError!;
      row['state'] = 'live';
    }
    if (action == 'end') {
      row['state'] = failEnd ? 'ending' : 'completed';
      row['termination_pending'] = failEnd;
      if (failEnd) throw StateError('Provider unavailable');
    }
    return {'session': Map<String, dynamic>.of(row)};
  }
}
