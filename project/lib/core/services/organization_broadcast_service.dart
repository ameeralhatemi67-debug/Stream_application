import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/organization/models/org_membership.dart';
import '../../features/organization/models/channel_connection.dart';
import '../../features/live_stream/models/broadcast_session.dart';

/// Stateless organization operations. The server checks authority on every call.
class OrganizationBroadcastService {
  OrganizationBroadcastService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

  Future<List<ChannelConnection>> connections() async {
    final rows = await client.from('channel_connections').select();
    return rows.map(ChannelConnection.fromRow).toList();
  }

  Future<List<BroadcastSession>> sessions({String? organizationId,bool mine=false}) async {
    final rows=await client.rpc('broadcast_list_sessions',params:{'p_org':organizationId,'p_mine':mine});
    return (rows as List).map((r)=>BroadcastSession.fromRow(Map<String,dynamic>.from(r as Map))).toList();
  }
  Future<BroadcastSession?> session(String id) async {
    final row=await client.from('broadcast_sessions').select().eq('id',id).maybeSingle();
    return row==null?null:BroadcastSession.fromRow(row);
  }
  Future<void> answerAssignment(BroadcastSession session,bool accept) => client.rpc('broadcast_accept_assignment',
    params:{'p_id':session.id,'p_accept':accept,'p_revision':session.revision});
  Future<String> createPersonal(String title,String type) async => await client.rpc('broadcast_create_personal',
    params:{'p_title':title,'p_type':type}) as String;
  Future<Map<String,dynamic>> control(String sessionId,String deviceId,String sender,String action) async {
    final result=await client.functions.invoke('broadcast-control',body:{'session_id':sessionId,
      'device_id':deviceId,'sender_mode':sender,'action':action});
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
    final response = await client.functions.invoke('channel-authorization',body:{
      'action':'connect','organization_id':organizationId,
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
}
