import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';

import '../../features/organization/models/org_membership.dart';
import '../../features/organization/models/channel_connection.dart';
import '../../features/organization/models/org_event.dart';
import '../../features/organization/models/org_invitation.dart';
import '../../features/live_stream/models/broadcast_session.dart';

/// Stateless organization operations. The server checks authority on every call.
class OrganizationBroadcastService {
  OrganizationBroadcastService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  static bool waitingForEncoder(FunctionException error) =>
      error.status == 409 && error.details is Map &&
      error.details['error'] == 'waiting_for_encoder';

  static String channelErrorKey(Object error) {
    if (error is FunctionException) {
      final reason = error.details is Map ? error.details['error'] : null;
      if (reason == 'channel_active_show') return 'organization_v1.channel_active_show';
      if (reason == 'channel_browser_failed') return 'organization_v1.channel_browser_failed';
      if (error.status == 401) return 'organization_v1.channel_sign_in_required';
      if (error.status == 403) return 'organization_v1.channel_permission_required';
      if (error.status == 404 || error.status == 503) return 'organization_v1.channel_setup_required';
    }
    if (error is PostgrestException) {
      if (error.code == '55000') return 'organization_v1.channel_active_show';
      if (error.code == '42501') return 'organization_v1.channel_permission_required';
    }
    return 'organization_v1.channel_failure';
  }

  Map<String, String> _sessionHeaders() {
    final session = client.auth.currentSession;
    if (session == null) throw const FunctionException(status: 401);
    return {'Authorization': 'Bearer ${session.accessToken}'};
  }

  static String errorKey(Object error) {
    if (error is FunctionException) {
      if (error.status == 401 || error.status == 403) return 'organization_v1.authorization_failed';
      if (error.status == 429) return 'organization_v1.quota_failed';
      if (waitingForEncoder(error)) return 'organization_v1.waiting_encoder';
    }
    return 'organization_v1.publish_failure';
  }

  /// Management RPC failures, by the SQLSTATE the server raises.
  static String actionErrorKey(Object error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '42501': return 'organization_v1.denied_failed';
        case '23P01': return 'organization_v1.overlap_failed';
        case '55000': return 'organization_v1.conflict_failed';
        case '23505': return 'organization_v1.duplicate_failed';
        case '22023': return 'organization_v1.invalid_failed';
      }
    }
    return 'organization_v1.failure';
  }

  Future<List<ChannelConnection>> connections() async {
    final rows = await client.from('channel_connections').select();
    return rows.map(ChannelConnection.fromRow).toList();
  }

  Future<List<BroadcastSession>> sessions({String? organizationId,bool mine=false}) async {
    final rows=await client.rpc('broadcast_list_sessions',params:{'p_org':organizationId,'p_mine':mine});
    return (rows as List).map((r)=>BroadcastSession.fromRow(Map<String,dynamic>.from(r as Map))).toList();
  }
  Future<BroadcastSession?> session(String id) async {
    final row=await client.rpc('broadcast_room',params:{'p_id':id});
    return row==null?null:BroadcastSession.fromRow(Map<String,dynamic>.from(row as Map));
  }
  Future<void> cancelSchedule(String id) => client.rpc('broadcast_cancel_schedule',params:{'p_id':id});
  Future<void> answerAssignment(BroadcastSession session,bool accept) => client.rpc('broadcast_accept_assignment',
    params:{'p_id':session.id,'p_accept':accept,'p_revision':session.revision});
  Future<String> createPersonal(String title,String type) async => await client.rpc('broadcast_create_personal',
    params:{'p_title':title,'p_type':type}) as String;
  Future<Map<String,dynamic>> control(String sessionId,String deviceId,String sender,String action,{ChannelConnection? destination}) async {
    final result=await client.functions.invoke('broadcast-control',headers:_sessionHeaders(),body:{'session_id':sessionId,
      'device_id':deviceId,'sender_mode':sender,'action':action,
      'connection_id':destination?.id,'channel_revision':destination?.revision});
    if(result.status!=200 || result.data is! Map) throw StateError('Broadcast operation unavailable');
    return Map<String,dynamic>.from(result.data as Map);
  }
  Future<String> saveSchedule({required String orgId,String? scheduleId,required String presenterId,
    required String kind,required String localTime,required List<int> weekdays,DateTime? once,
    required String titleEn,required String titleAr,required String type,int duration=60,String? venueId}) async {
    return await client.rpc('broadcast_save_schedule',params:{'p_org_id':orgId,'p_schedule_id':scheduleId,'p_presenter':presenterId,
      'p_kind':kind,'p_local_time':localTime,'p_weekdays':weekdays,'p_once':once?.toUtc().toIso8601String(),
      'p_title_en':titleEn,'p_title_ar':titleAr,'p_type':type,'p_duration':duration,'p_venue':venueId}) as String;
  }
  Future<void> editOccurrence(BroadcastSession session,{required String presenterId,required DateTime start,
    required DateTime end,required String type,String? venueId}) => client.rpc('broadcast_edit_occurrence',params:{
      'p_id':session.id,'p_presenter':presenterId,'p_start':start.toUtc().toIso8601String(),
      'p_end':end.toUtc().toIso8601String(),'p_type':type,'p_venue':venueId});

  Future<Uri> connectChannel({String? organizationId}) async {
    final response = await client.functions.invoke('channel-authorization',headers:_sessionHeaders(),body:{
      'action':'connect','organization_id':organizationId,
      'return_platform':!kIsWeb && defaultTargetPlatform==TargetPlatform.android
        ? (Uri.parse(SupabaseConfig.oauthRedirectUrl).scheme.endsWith('.wave4v2')?'android_test':'android') : 'web',
    });
    if (response.status != 200) throw StateError('Channel consent unavailable');
    final url = Uri.parse(response.data['authorization_url'] as String);
    if (url.scheme != 'https' || url.host != 'accounts.google.com') {
      throw StateError('Invalid authorization destination');
    }
    return url;
  }

  Future<void> disconnectChannel(String id) async {
    await client.rpc('channel_disconnect',params:{'p_connection_id':id});
  }

  Future<List<OrgMembership>> memberships({String? organizationId}) async {
    final rows = await client.rpc('org_v1_memberships',
        params: {'p_org_id': organizationId});
    return (rows as List)
        .map((row) => OrgMembership.fromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<Map<String, dynamic>> invite(String orgId, String email, String role,
      Map<String, bool> permissions) async {
    final result = await client.rpc('org_v1_invite', params: {
      'p_org_id': orgId,
      'p_email': email,
      'p_role': role,
      'p_permissions': permissions,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> answerInvite(String id, bool accept, {String? token}) async {
    await client.rpc('org_v1_answer_invite', params: {
      'p_invitation_id': id, 'p_accept': accept, 'p_token': token,
    });
  }

  Future<void> setMember(String orgId, String profileId, String role,
      String status, Map<String, bool> permissions) async {
    await client.rpc('org_v1_set_member', params: {
      'p_org_id': orgId, 'p_profile_id': profileId, 'p_role': role,
      'p_status': status, 'p_permissions': permissions,
    });
  }

  Future<void> transferOwner(String orgId, {String? toProfileId}) async {
    await client.rpc('org_v1_transfer_owner', params: {
      'p_org_id': orgId, 'p_to_profile_id': toProfileId,
    });
  }

  Future<void> cancelTransfer(String orgId) =>
      client.rpc('org_v1_cancel_transfer', params: {'p_org_id': orgId});

  Future<List<OrgInvitation>> myInvitations() async {
    final rows = await client.rpc('org_v1_my_invitations');
    return (rows as List)
        .map((row) => OrgInvitation.fromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<OrgInvitation>> invitations(String orgId) async {
    final rows = await client.rpc('org_v1_invitations', params: {'p_org_id': orgId});
    return (rows as List)
        .map((row) => OrgInvitation.fromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<void> revokeInvite(String id) =>
      client.rpc('org_v1_revoke_invite', params: {'p_invitation_id': id});

  Future<List<OrgEvent>> events() async {
    final rows = await client.rpc('org_v1_events', params: {'p_limit': 50});
    return (rows as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => OrgEvent.kinds.contains(row['kind']))
        .map(OrgEvent.fromRow)
        .toList();
  }

  /// Null marks every unread event of the signed-in account.
  Future<void> markEventsRead([List<String>? ids]) =>
      client.rpc('org_v1_mark_events_read', params: {'p_ids': ids});

  Future<void> savePushPreferences({required bool live, required bool organization}) async {
    final user = client.auth.currentUser?.id;
    if (user == null) return;
    await client.from('notification_push_preferences').upsert({
      'viewer_profile_id': user, 'live_enabled': live,
      'organization_enabled': organization,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<({String id, String nameEn, String nameAr, bool pilot})>> pilotStatus() async {
    final rows = await client.rpc('org_v1_pilot_status');
    return [
      for (final raw in rows as List)
        if (raw is Map)
          (id: raw['id'] as String, nameEn: raw['name_en'] as String? ?? '',
           nameAr: raw['name_ar'] as String? ?? '', pilot: raw['pilot'] == true),
    ];
  }

  Future<void> setPilot(String orgId, bool enabled) => client.rpc('org_v1_set_pilot',
      params: {'p_org_id': orgId, 'p_enabled': enabled});
}
