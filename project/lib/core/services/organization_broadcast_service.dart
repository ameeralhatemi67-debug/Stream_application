import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/organization/models/org_membership.dart';

/// Stateless organization operations. The server checks authority on every call.
class OrganizationBroadcastService {
  OrganizationBroadcastService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get client => _client ?? Supabase.instance.client;

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
