import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'fixtures/admin_applications.dart';

void main() {
  test(
      'profile save uses server review decision and never falls back on failure',
      () async {
    var fail = false;
    final paths = <String>[];
    final application = sampleBroadcasterApplications().first;
    final client = SupabaseClient('http://127.0.0.1:1', 'test-only',
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      if (fail) {
        return http.Response(
            jsonEncode({'code': '42501', 'message': 'Denied'}), 403,
            request: request, headers: {'content-type': 'application/json'});
      }
      final body = jsonDecode(request.body) as Map;
      expect(body['p_application_id'], application.id);
      return http.Response(
          jsonEncode({
            ...body['p_changes'] as Map,
            'id': 'revision-1',
            'revision_of': application.id,
            'status': 'pending',
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    final service = AdminDatabaseService.withClient(client);
    final saved = await service.saveBroadcasterProfile(application);
    expect(saved.isPending, isTrue);
    expect(saved.revisionOf, application.id);
    expect(BroadcasterApplicationModel.fromJson(saved.toJson()).revisionOf,
        application.id);
    fail = true;
    await expectLater(service.saveBroadcasterProfile(application),
        throwsA(isA<PostgrestException>()));
    expect(paths, everyElement('/rest/v1/rpc/save_broadcaster_profile'));
    await client.dispose();
  });

  test('rejecting a profile revision does not revoke broadcaster credentials',
      () async {
    final paths = <String>[];
    final client = SupabaseClient('http://127.0.0.1:1', 'test-only',
        httpClient: MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
          jsonEncode({
            'id': 'revision-1',
            'revision_of': 'original',
            'applicant_profile_id': '69000000-0000-4000-8000-000000000001',
            'account_type': 'individualScholar',
            'status': 'rejected',
            'submitted_at': DateTime(2026).toIso8601String(),
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    final service = AdminDatabaseService.withClient(client);
    final result = await service.updateApplicationStatus(
        'revision-1', ApplicationStatus.rejected);
    expect(result!.isRejected, isTrue);
    expect(paths, ['/rest/v1/broadcaster_applications']);
    await client.dispose();
  });
}
