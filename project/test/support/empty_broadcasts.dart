import 'package:streamer_app/core/services/organization_broadcast_service.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';
import 'package:streamer_app/features/organization/models/org_membership.dart';

/// Viewer tests that model the legacy catalog have no canonical sessions.
class EmptyBroadcasts extends OrganizationBroadcastService {
  @override
  Future<List<BroadcastSession>> sessions({String? organizationId,bool mine=false}) async=>[];
  @override
  Future<BroadcastSession?> session(String id) async=>null;
  @override
  Future<List<ChannelConnection>> connections() async=>[];
  @override
  Future<List<OrgMembership>> memberships({String? organizationId}) async=>[];
}
