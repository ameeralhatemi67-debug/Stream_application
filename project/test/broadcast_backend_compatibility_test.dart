import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';

void main() {
  test('missing session migration never falls back to an unfenced live write',
      () async {
    final requests = <String>[];
    final client = SupabaseClient('http://127.0.0.1:1', 'test-only',
        httpClient: MockClient((request) async {
      requests.add(request.url.path);
      return http.Response(
          jsonEncode({'code': 'PGRST202', 'message': 'Missing session RPC'}),
          404,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    final service = AdminDatabaseService.withClient(client);
    await expectLater(
        service.startBroadcastSession(
            type: 'liveVideo',
            streamId: 'abcdefghijk',
            deviceId: 'device',
            senderMode: 'phone_direct'),
        throwsA(isA<PostgrestException>()));
    expect(requests, ['/rest/v1/rpc/start_broadcast_session']);
    await client.dispose();
  });
}
