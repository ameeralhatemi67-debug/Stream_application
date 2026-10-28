import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/notifications/notification_models.dart';
import 'package:streamer_app/features/organization/models/org_event.dart';
import 'package:streamer_app/features/organization/models/org_event_text.dart';
import 'fixtures/admin_applications.dart';
import 'support/fixture_application_db.dart';
import 'support/scripted_broadcasts.dart';

const _applicant = '82000000-0000-4000-8000-000000000001';
const _presenter = '82000000-0000-4000-8000-000000000003';

OrgEvent _event(String kind, Map<String, dynamic> payload,
        {String id = '83000000-0000-4000-8000-000000000001'}) =>
    OrgEvent(id: id, kind: kind, createdAt: DateTime.now(), payload: payload);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('decision wording', () {
    test('a rejection quotes the note once and points to Settings', () {
      final event = _event('application_rejected',
          {'reason': 'Add a clearer photo.', 'name_en': 'Omar', 'name_ar': 'عمر'});
      expect(orgEventText(event, 'en').title, 'Your application needs changes');
      expect(orgEventText(event, 'en').body,
          "Reviewer's note: Add a clearer photo. Update it in Settings and apply again.");
      expect(orgEventText(event, 'ar').title, 'طلبك يحتاج إلى تعديل');
      expect(orgEventText(event, 'ar').body,
          'ملاحظة المراجع: Add a clearer photo. عدّله من الإعدادات وأعد التقديم.');
      expect(event.route, '/settings');
    });

    test('an approval welcomes the applicant by name', () {
      final event =
          _event('application_approved', {'name_en': 'Omar', 'name_ar': 'عمر'});
      expect(orgEventText(event, 'en').body,
          'Welcome, Omar. Your channel is verified and you can go live.');
      expect(orgEventText(event, 'ar').body,
          'أهلاً عمر، قناتك موثّقة ويمكنك البث الآن.');
    });

    test('a profile edit decision says the approved details stay', () {
      final refused = _event('application_rejected', {'edit': true});
      expect(orgEventText(refused, 'en').title, 'Your changes were not approved');
      expect(orgEventText(refused, 'en').body,
          'Your channel keeps its approved details.');
      expect(orgEventText(_event('application_approved', {'edit': true}), 'ar').title,
          'اعتُمدت تعديلاتك');
    });

    test('a personal live names its presenter', () {
      final event = _event('show_live', {
        'title_en': 'Tafsir',
        'title_ar': 'تفسير',
        'presenter_name_en': 'Sheikh Presenter',
        'presenter_name_ar': 'الشيخ المقدم',
        'presenter_id': _presenter,
      });
      expect(orgEventText(event, 'en').body, 'Tafsir — Sheikh Presenter');
      expect(orgEventText(event, 'ar').body, 'تفسير — الشيخ المقدم');
      expect(orgEventText(event, 'en').body, isNot(contains('organization')));
    });

    test('a decision push opens Settings', () {
      expect(
          AppProvider.organizationEventRoute({
            'kind': 'application_rejected',
            'event_id': '83000000-0000-4000-8000-000000000001',
          }),
          '/settings');
    });
  });

  test('the applicant\'s inbox shows the decision from the server', () async {
    final broadcasts = ScriptedBroadcasts()
      ..eventRows = [
        _event('application_rejected', {'reason': 'Add a bio'}),
        _event('show_live',
            {'title_en': 'Tafsir', 'presenter_id': _presenter, 'presenter_name_en': 'Sheikh'},
            id: '83000000-0000-4000-8000-000000000002'),
      ];
    final provider = AppProvider.withServices(
        adminDbService: FixtureApplicationDb(),
        organizationBroadcastService: broadcasts);
    provider.debugSetSignedInForTests(
        email: 'applicant@example.invalid', isStreamer: false, userId: _applicant);
    await provider.refreshOrganizationEvents();
    final decision = provider.enhancedNotifications
        .firstWhere((n) => n.id == 'org:83000000-0000-4000-8000-000000000001');
    expect(decision.type, NotificationType.streamerApplicationRejected);
    expect(decision.bodyEn, contains('Add a bio'));
    expect(decision.actionUrl, '/settings');
    final live = provider.enhancedNotifications
        .firstWhere((n) => n.id == 'org:83000000-0000-4000-8000-000000000002');
    // Muting a channel finds its personal live alerts.
    expect(live.streamerId, _presenter);
    provider.dispose();
  });

  test('approving or rejecting adds nothing to the admin\'s own inbox',
      () async {
    final provider = AppProvider.withServices(
        adminDbService: FixtureApplicationDb(),
        organizationBroadcastService: ScriptedBroadcasts());
    provider.debugSetSignedInForTests(
        email: 'admin@example.invalid', isAdmin: true);
    final fixtures = sampleBroadcasterApplications();
    for (final fixture in fixtures.take(2)) {
      await provider.submitBroadcasterApplication(fixture);
    }
    final pending = provider.pendingApplications.toList();
    expect(pending.length, greaterThanOrEqualTo(2));
    final before = provider.enhancedNotifications.length;
    expect(await provider.approveBroadcasterApplication(pending[0].id), isTrue);
    expect(await provider.rejectBroadcasterApplication(pending[1].id,
        reason: 'Add a bio'), isTrue);
    expect(
        provider.enhancedNotifications.where((n) =>
            n.type == NotificationType.streamerApplicationApproved ||
            n.type == NotificationType.streamerApplicationRejected),
        isEmpty);
    expect(provider.enhancedNotifications.length, before);
    provider.dispose();
  });
}
