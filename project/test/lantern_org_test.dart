import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_navigation.dart';
import 'package:streamer_app/core/widgets/ds/ca_rows.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';
import 'package:streamer_app/features/organization/models/org_event.dart';
import 'package:streamer_app/features/organization/models/org_invitation.dart';
import 'package:streamer_app/features/organization/models/org_membership.dart';
import 'package:streamer_app/features/organization/models/channel_connection.dart';
import 'package:streamer_app/features/organization/presentation/lantern/lantern_channels_view.dart';
import 'package:streamer_app/features/organization/presentation/lantern/lantern_org_hub.dart';
import 'package:streamer_app/features/organization/presentation/lantern/lantern_org_shows.dart';
import 'package:streamer_app/features/organization/presentation/organization_surface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';
import 'support/scripted_broadcasts.dart';

/// The organization pages in Lantern and Arch (ADR-026): the organization
/// home and shows and assignments. Loads, rules and server calls are the
/// older screens'.
const org = '11111111-1111-4111-8111-111111111111';
const otherOrg = '22222222-2222-4222-8222-222222222222';
const session = '33333333-3333-4333-8333-333333333333';
const invite = '44444444-4444-4444-8444-444444444444';
const event = '55555555-5555-4555-8555-555555555555';
const me = '66666666-6666-4666-8666-666666666666';

OrgMembership membership(
        {String role = 'broadcaster',
        String id = org,
        bool v1 = true,
        bool transferToMe = false,
        String name = 'Pilot Academy'}) =>
    OrgMembership.fromRow({
      'organization_id': id,
      'profile_id': me,
      'role': role,
      'status': 'active',
      'permissions': const {'can_go_live_video': true},
      'organization_name_en': name,
      'organization_name_ar': 'أكاديمية تجريبية',
      'name_en': 'Member',
      'name_ar': 'عضو',
      'v1_enabled': v1,
      'transfer_to_me': transferToMe,
      'transfer_target_id': null,
      'transfer_expires_at': transferToMe ? '2026-12-08T09:00:00Z' : null,
    });

OrgInvitation invitation() => OrgInvitation.fromRow({
      'id': invite,
      'organization_id': org,
      'organization_name_en': 'Pilot Academy',
      'organization_name_ar': 'أكاديمية تجريبية',
      'role': 'manager',
      'permissions': {'can_go_audio_only': true},
      'expires_at': '2026-12-08T09:00:00Z',
      'email': 'invitee@example.invalid',
    });

OrgEvent orgEvent(String kind) => OrgEvent.fromRow({
      'id': event,
      'kind': kind,
      'organization_id': org,
      'session_id': session,
      'invitation_id': invite,
      'payload': {
        'organization_name_en': 'Pilot Academy',
        'organization_name_ar': 'أكاديمية',
        'title_en': 'Weekly lesson',
        'title_ar': 'الدرس الأسبوعي',
        'role': 'manager'
      },
      'created_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 1))
          .toIso8601String(),
      'read_at': null,
    });

BroadcastSession show({String presenter = me}) => BroadcastSession.fromRow({
      'id': session,
      'owner_id': presenter,
      'org_id': org,
      'state': 'awaiting_acceptance',
      'revision': 3,
      'title_en': 'Weekly lesson',
      'title_ar': 'الدرس الأسبوعي',
      'broadcast_type': 'liveVideo',
      'scheduled_start_at': '2026-12-02T15:00:00Z',
      'expected_end_at': '2026-12-02T16:00:00Z',
      'schedule_id': invite,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const phone = Size(390, 844), laptop = Size(1440, 900);

  Future<LanternApp> open(WidgetTester tester, ScriptedBroadcasts backend,
      {String location = '/organizations',
      String lang = 'en',
      Size size = phone,
      bool night = false,
      bool preload = false}) async {
    final provider = AppProvider.withServices(
        adminDbService: AdminDatabaseService(null),
        organizationBroadcastService: backend)
      ..restoreAppSkin(AppSkin.lantern,
          appearance: night ? LanternAppearance.night : LanternAppearance.day)
      ..debugSetSignedInForTests(
          email: 'member@example.invalid', isStreamer: false, userId: me);
    // /channels reads the memberships another page loaded.
    if (preload) await tester.runAsync(provider.refreshOrgMemberships);
    final app = await LanternApp.start(tester,
        provider: provider, location: location, lang: lang, size: size);
    await app.settle();
    return app;
  }

  void expectNoOlderKit(Finder within, String reason) {
    for (final type in [
      OrganizationAppBar,
      OrganizationCard,
      OrganizationChip,
      OrganizationProgress,
      CaAppBar,
      CaButton,
      CaBanner,
      CaSettingsRow,
      CaStatusChip,
      ListTile,
      TextButton,
      OutlinedButton,
      DropdownButtonFormField<String>,
    ]) {
      expect(find.descendant(of: within, matching: find.byType(type)),
          findsNothing,
          reason: '$type in $reason');
    }
  }

  ScriptedBroadcasts full() => ScriptedBroadcasts()
    ..myInvitationRows = [invitation()]
    ..mine = [
      membership(
          role: 'owner',
          v1: false,
          name: 'An organization with a very long name for wrapping checks'),
      membership(id: otherOrg, role: 'manager', transferToMe: true),
    ]
    ..eventRows = [orgEvent('assignment_reminder')];

  for (final lang in ['en', 'ar']) {
    for (final (label, size) in [('phone', phone), ('website', laptop)]) {
      for (final night in [false, true]) {
        testWidgets(
            'organization home lays out: $lang $label ${night ? 'night' : 'day'}',
            (tester) async {
          final app =
              await open(tester, full(), lang: lang, size: size, night: night);
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternOrganizationHub), findsOneWidget);
          expect(find.byKey(const ValueKey('lantern-org-invitation-$invite')),
              findsOneWidget);
          expect(find.byKey(const ValueKey('lantern-org-membership-$org')),
              findsOneWidget);
          final activity = find.byKey(const ValueKey('lantern-org-activity'));
          await tester.scrollUntilVisible(activity, 300,
              scrollable: find
                  .descendant(
                      of: find.byKey(const ValueKey('lantern-org-hub')),
                      matching: find.byType(Scrollable))
                  .first);
          expect(activity, findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(find.byType(size == phone ? LanternPageBar : LanternWebHeader),
              findsOneWidget);
          expectNoOlderKit(find.byType(LanternOrganizationHub), 'hub');
          await app.close();
        });

        testWidgets(
            'shows and assignments lay out: $lang $label ${night ? 'night' : 'day'}',
            (tester) async {
          final backend = ScriptedBroadcasts()
            ..mine = [membership()]
            ..sessionRows = [show()];
          final app = await open(tester, backend,
              location: '/shows', lang: lang, size: size, night: night);
          expect(tester.takeException(), isNull);
          expect(find.byType(LanternShowsView), findsOneWidget);
          expect(find.byKey(const ValueKey('lantern-show-$session')),
              findsOneWidget);
          expectNoOlderKit(find.byType(LanternShowsView), 'shows');
          await app.close();
        });
      }
    }
  }

  testWidgets('accepting an invitation answers it and says so', (tester) async {
    final backend = ScriptedBroadcasts()..myInvitationRows = [invitation()];
    final app = await open(tester, backend);
    await tester.tap(find.byKey(const ValueKey('lantern-org-accept-$invite')));
    await app.settle();
    expect(backend.calls, contains('invite:$invite:true:'));
    expect(find.byKey(const ValueKey('lantern-org-invitation-$invite')),
        findsNothing);
    expect(find.text('Invitation accepted.'), findsOneWidget);
    await app.close();
  });

  testWidgets('an incoming transfer is confirmed, then opens channels',
      (tester) async {
    final backend = ScriptedBroadcasts()
      ..mine = [membership(role: 'co_owner', transferToMe: true)];
    final app = await open(tester, backend);
    final accept =
        find.byKey(const ValueKey('lantern-org-accept-transfer-$org'));
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await app.settle();
    expect(find.textContaining('reconnect'), findsOneWidget);
    await tester
        .tap(find.byKey(const ValueKey('lantern-org-transfer-confirm')));
    await app.settle();
    expect(backend.calls, contains('transfer:$org:accept'));
    expect(app.location, '/channels');
    await app.close();
  });

  testWidgets('a refused action shows the server reason', (tester) async {
    final backend = ScriptedBroadcasts()
      ..mine = [membership(role: 'manager', transferToMe: true)]
      ..failure =
          const PostgrestException(message: 'active shows', code: '55000');
    final app = await open(tester, backend);
    final decline =
        find.byKey(const ValueKey('lantern-org-decline-transfer-$org'));
    await tester.ensureVisible(decline);
    await tester.tap(decline);
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-org-error')), findsOneWidget);
    await app.close();
  });

  testWidgets('activity opens its destination and marks the event read',
      (tester) async {
    final backend = ScriptedBroadcasts()
      ..eventRows = [orgEvent('assignment_reminder')];
    final app = await open(tester, backend);
    final entry = find.byKey(const ValueKey('lantern-org-event-$event'));
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await app.settle();
    expect(backend.calls, contains('read:$event'));
    expect(app.location, '/shows');
    await app.close();
  });

  testWidgets('no memberships shows the empty state', (tester) async {
    final app = await open(tester, ScriptedBroadcasts());
    expect(find.byKey(const ValueKey('lantern-org-empty')), findsOneWidget);
    await app.close();
  });

  testWidgets('an owner sees the setup steps and the destinations',
      (tester) async {
    final backend = ScriptedBroadcasts()..mine = [membership(role: 'owner')];
    final app = await open(tester, backend, size: laptop);
    expect(find.text('Owner setup'), findsOneWidget);
    expect(find.text('1 of 3 done'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('organization_v1.shows')));
    await app.settle();
    expect(app.location, '/shows');
    expect(find.byType(LanternShowsView), findsOneWidget);
    await app.close();
  });

  testWidgets('a presenter accepts an assignment', (tester) async {
    final backend = ScriptedBroadcasts()
      ..mine = [membership()]
      ..sessionRows = [show()];
    final app = await open(tester, backend, location: '/shows', lang: 'ar');
    final accept = find.byKey(const ValueKey('lantern-show-accept-$session'));
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await app.settle();
    expect(backend.calls, ['assignment:$session:true']);
    await app.close();
  });

  testWidgets('a presenter cannot schedule or answer someone else',
      (tester) async {
    final backend = ScriptedBroadcasts()
      ..mine = [membership()]
      ..sessionRows = [show(presenter: otherOrg)];
    final app = await open(tester, backend, location: '/shows?org=$org');
    expect(find.byKey(const ValueKey('lantern-shows-schedule')), findsNothing);
    expect(find.byKey(const ValueKey('lantern-show-accept-$session')),
        findsNothing);
    await app.close();
  });

  testWidgets('leaders schedule in a Lantern form that keeps its rule',
      (tester) async {
    final backend = ScriptedBroadcasts()
      ..mine = [membership(role: 'manager', v1: false)];
    final app = await open(tester, backend, location: '/shows?org=$org');
    expect(find.textContaining('is not enabled for this organization yet'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('lantern-shows-empty')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lantern-shows-schedule')));
    await app.settle();
    expect(find.byType(LanternScheduleForm), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.byType(SwitchListTile), findsNothing);
    final save = find.byKey(const ValueKey('lantern-schedule-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await app.settle(3);
    expect(
        find.byKey(const ValueKey('lantern-schedule-error')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.close();
  });

  testWidgets('a refused answer shows the reason', (tester) async {
    final backend = ScriptedBroadcasts()
      ..mine = [membership()]
      ..sessionRows = [show()];
    final app = await open(tester, backend, location: '/shows');
    backend.failure = const PostgrestException(message: 'stale', code: '42501');
    final decline = find.byKey(const ValueKey('lantern-show-decline-$session'));
    await tester.ensureVisible(decline);
    await tester.tap(decline);
    await app.settle();
    expect(find.byKey(const ValueKey('lantern-shows-error')), findsOneWidget);
    await app.close();
  });

  for (final lang in ['en', 'ar']) {
    for (final (label, size) in [('phone', phone), ('website', laptop)]) {
      testWidgets('YouTube connections lay out: $lang $label', (tester) async {
        final backend = ScriptedBroadcasts()
          ..mine = [membership(role: 'owner')]
          ..connectionRows = const [
            ChannelConnection(
                id: 'connection-1',
                ownerId: me,
                organizationId: org,
                channelId: 'UC_one',
                title: 'Pilot Academy channel',
                status: 'connected',
                revision: 1),
          ];
        final app = await open(tester, backend,
            location: '/channels', lang: lang, size: size, preload: true);
        expect(tester.takeException(), isNull);
        expect(find.byType(LanternChannelsView), findsOneWidget);
        expect(find.byKey(const ValueKey('lantern-channels-org-$org')),
            findsOneWidget);
        expect(find.byKey(const ValueKey('lantern-channel-connection-1')),
            findsOneWidget);
        expectNoOlderKit(find.byType(LanternChannelsView), 'channels');
        await app.close();
      });
    }
  }

  testWidgets('a consent return explains itself and no channel is empty',
      (tester) async {
    final app = await open(tester, ScriptedBroadcasts(),
        location: '/channels?status=failed');
    expect(find.byType(LanternChannelsView), findsOneWidget);
    expect(
        find.byKey(const ValueKey('lantern-channels-return')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('lantern-channels-empty')), findsOneWidget);
    await app.close();
  });
}
