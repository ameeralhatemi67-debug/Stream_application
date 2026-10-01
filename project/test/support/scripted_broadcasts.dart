import 'package:streamer_app/core/services/organization_broadcast_service.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';
import 'package:streamer_app/features/organization/models/org_event.dart';
import 'package:streamer_app/features/organization/models/org_invitation.dart';
import 'package:streamer_app/features/organization/models/org_membership.dart';

/// Organization backend double whose rows a test controls. Every mutation is
/// recorded so tests can assert the exact server call the UI issued.
class ScriptedBroadcasts extends OrganizationBroadcastService {
  List<OrgMembership> mine = [];
  Map<String, List<OrgMembership>> members = {};
  List<BroadcastSession> sessionRows = [];
  List<ChannelConnection> connectionRows = [];
  List<OrgInvitation> myInvitationRows = [];
  Map<String, List<OrgInvitation>> invitationRows = {};
  List<OrgEvent> eventRows = [];
  List<({String id, String nameEn, String nameAr, bool pilot})> pilots = [];
  final List<String> calls = [];
  Object? failure;

  void _check(String call) {
    calls.add(call);
    final error = failure;
    if (error != null) throw error;
  }

  @override
  Future<List<OrgMembership>> memberships({String? organizationId}) async =>
      organizationId == null ? mine : members[organizationId] ?? [];
  @override
  Future<List<BroadcastSession>> sessions(
          {String? organizationId, bool mine = false}) async =>
      sessionRows
          .where((s) => organizationId == null || s.organizationId == organizationId)
          .toList();
  @override
  Future<BroadcastSession?> session(String id) async =>
      sessionRows.where((s) => s.id == id).firstOrNull;
  @override
  Future<List<ChannelConnection>> connections() async => connectionRows;
  @override
  Future<void> answerAssignment(BroadcastSession session, bool accept) async =>
      _check('assignment:${session.id}:$accept');
  @override
  Future<void> answerInvite(String id, bool accept, {String? token}) async {
    _check('invite:$id:$accept:${token ?? ''}');
    myInvitationRows = myInvitationRows.where((i) => i.id != id).toList();
  }
  @override
  Future<void> transferOwner(String orgId, {String? toProfileId}) async =>
      _check('transfer:$orgId:${toProfileId ?? 'accept'}');
  @override
  Future<void> cancelTransfer(String orgId) async => _check('cancel-transfer:$orgId');
  @override
  Future<void> setMember(String orgId, String profileId, String role,
          String status, Map<String, bool> permissions) async =>
      _check('member:$orgId:$profileId:$role:$status');
  @override
  Future<void> cancelSchedule(String id) async => _check('cancel:$id');
  @override
  Future<List<OrgInvitation>> myInvitations() async => myInvitationRows;
  @override
  Future<List<OrgInvitation>> invitations(String orgId) async => invitationRows[orgId] ?? [];
  @override
  Future<void> revokeInvite(String id) async => _check('revoke-invite:$id');
  @override
  Future<List<OrgEvent>> events() async => eventRows;
  @override
  Future<void> markEventsRead([List<String>? ids]) async =>
      _check('read:${ids?.join(',') ?? 'all'}');
  @override
  Future<void> savePushPreferences({required bool live, required bool organization}) async =>
      _check('push-preferences:$live:$organization');
  @override
  Future<List<({String id, String nameEn, String nameAr, bool pilot})>> pilotStatus() async => pilots;
  @override
  Future<void> setPilot(String orgId, bool enabled) async => _check('pilot:$orgId:$enabled');
}
