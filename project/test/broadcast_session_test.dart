import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';

void main() {
  test('provider lifecycle and replay status remain independent', () {
    final row = <String, dynamic>{'id':'session','owner_id':'presenter','org_id':'org','state':'preparing',
      'revision':2,'title_en':'First show','title_ar':'','broadcast_type':'liveVideo',
      'scheduled_start_at':'2026-10-01T18:00:00+03:00','expected_end_at':'2026-10-01T19:00:00+03:00',
      'accepted_at':'2026-10-01T00:00:00Z','channel_connection_id':'connection','stream_id':'abcdefghijk'};
    final preparing = BroadcastSession.fromRow(row);
    expect(preparing.live, isFalse);
    expect(preparing.active, isTrue);
    expect(preparing.frozen, isTrue);
    expect(preparing.startUtc, DateTime.utc(2026,10,1,15));
    final ending = BroadcastSession.fromRow({...row,'state':'ending','termination_pending':true});
    expect(ending.live, isFalse);
    expect(ending.terminationPending, isTrue);
    final replay = BroadcastSession.fromRow({...row,'state':'completed','replay_status':'missing'});
    expect(replay.active, isFalse);
    expect(replay.replayStatus, 'missing');
  });
}
