import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';
import 'package:streamer_app/core/services/organization_broadcast_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('channel errors distinguish sign-in, setup, ownership and active shows', () {
    final cases = <FunctionException,String>{
      const FunctionException(status:401):'channel_sign_in_required',
      const FunctionException(status:403):'channel_permission_required',
      const FunctionException(status:404):'channel_setup_required',
      const FunctionException(status:503):'channel_setup_required',
      const FunctionException(status:409,details:{'error':'channel_active_show'}):'channel_active_show',
      const FunctionException(status:503,details:{'error':'channel_browser_failed'}):'channel_browser_failed',
    };
    for(final entry in cases.entries) {
      expect(OrganizationBroadcastService.channelErrorKey(entry.key),'organization_v1.${entry.value}');
    }
    expect(OrganizationBroadcastService.channelErrorKey(StateError('internal detail')),
      'organization_v1.channel_failure');
  });
  test('only connected identities are usable publishing destinations', () {
    final row = <String, dynamic>{
      'id': 'connection', 'owner_profile_id': 'owner', 'organization_id': 'org',
      'youtube_channel_id': 'UCaaaaaaaaaaaaaaaaaaaaaa', 'channel_title': 'Pilot',
      'status': 'connected', 'revision': 2,
    };
    final connection = ChannelConnection.fromRow(row);
    expect(connection.connected, isTrue);
    expect(connection.organizationId, 'org');
    expect(connection.revision, 2);
    for (final status in ['disconnected', 'reconnect_required', 'unknown']) {
      expect(ChannelConnection.fromRow({...row, 'status': status}).connected, isFalse);
    }
  });
}
