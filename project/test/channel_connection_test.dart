import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';

void main() {
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
