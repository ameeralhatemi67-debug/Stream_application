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
        'revision-1', ApplicationStatus.rejected,
        expectedStatus: ApplicationStatus.pending);
    expect(result!.isRejected, isTrue);
    expect(paths, ['/rest/v1/broadcaster_applications']);
    await client.dispose();
  });

  test('queue removal archives only the application row', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient('http://127.0.0.1:1', 'test-only',
        httpClient: MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode([
            {'id': 'approved-1'}
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json'});
    }));
    final service = AdminDatabaseService.withClient(client);
    expect(await service.deleteApplication('approved-1'), isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/rest/v1/broadcaster_applications');
    expect(jsonDecode(requests.single.body),
        containsPair('queue_archived_at', isA<String>()));
    await client.dispose();
  });

  test('reapproving a rejection reopens the review as pending', () async {
    late http.Request request;
    final client = SupabaseClient('http://127.0.0.1:1', 'test-only',
        httpClient: MockClient((incoming) async {
      request = incoming;
      return http.Response(
          jsonEncode({
            'id': 'revision-1',
            'revision_of': 'original',
            'account_type': 'individualScholar',
            'status': 'pending',
            'submitted_at': DateTime(2026).toIso8601String(),
          }),
          200,
          request: incoming,
          headers: {'content-type': 'application/json'});
    }));
    final service = AdminDatabaseService.withClient(client);
    final reopened = await service.restoreApplicationToQueue('revision-1');
    expect(reopened.status, ApplicationStatus.pending);
    expect(request.method, 'PATCH');
    expect(jsonDecode(request.body),
        {'queue_archived_at': null, 'status': 'pending'});
    expect(request.url.queryParameters['status'], 'eq.rejected');
    await client.dispose();
  });
}
