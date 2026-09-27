import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/auth/presentation/steps/apply_step_4_location.dart';
import 'package:streamer_app/features/map/models/map_tricity_domain.dart';
import 'fixtures/admin_applications.dart';

void main() {
  test(
      'all offered application cities persist through creation and catalog reload',
      () async {
    expect(ApplyStep4Location.cityOptions.keys.toSet(),
        BroadcasterApplicationModel.cityNames.keys.toSet());
    for (final city in ApplyStep4Location.cityOptions.keys) {
      final app = sampleBroadcasterApplications().first.copyWith(cityId: city);
      Map<String, dynamic>? inserted;
      final client = SupabaseClient('http://127.0.0.1:1', 'test-only',
          httpClient: MockClient((request) async {
        Object body;
        if (request.method == 'POST') {
          inserted = jsonDecode(request.body) as Map<String, dynamic>;
          body = {'id': '59000000-0000-4000-8000-000000000001'};
        } else if (request.url.path.endsWith('/organization_public_profiles')) {
          body = [
            {
              'id': 'org',
              'name_en': app.applicantNameEn,
              'name_ar': app.applicantNameAr,
              'city_id': city,
              'latitude': app.latitude,
              'longitude': app.longitude,
              'venue_name_en': app.venueNameEn,
              'venue_name_ar': app.venueNameAr
            },
            {'id': 'unknown', 'name_en': 'No public pin', 'name_ar': 'بلا موقع'}
          ];
        } else {
          body = [];
        }
        return http.Response(jsonEncode(body), 200, request: request,
            headers: {'content-type': 'application/json'});
      }));
      final service = AdminDatabaseService.withClient(client);
      await service.createOrganizationFromApplication(app, 'owner');
      expect(inserted!['approved_application_id'], app.id);
      expect(inserted!['owner_profile_id'], 'owner');
      final reloaded =
          await service.loadVerifiedStreamersFromBackend(requireSuccess: true);
      expect(reloaded.first.cityEn, app.city!.nameEn);
      expect(reloaded.first.cityAr, app.city!.nameAr);
      expect(reloaded.first.latitude, app.latitude);
      expect(reloaded.first.longitude, app.longitude);
      expect(reloaded.first.venueNameEn, app.venueNameEn);
      expect(isTricityVenueCity(reloaded.first.cityEn),
          ['khobar', 'dhahran', 'dammam'].contains(city));
      expect(reloaded.last.latitude, 0);
      expect(reloaded.last.longitude, 0);
      expect(reloaded.last.cityEn, isEmpty);
      await client.dispose();
    }
  });
}
