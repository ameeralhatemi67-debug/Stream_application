import 'package:streamer_app/core/widgets/ds/ca_surfaces.dart';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_flags.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/notifications/notification_models.dart';
import 'package:streamer_app/core/services/organization_broadcast_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_button.dart';
import 'package:streamer_app/features/auth/presentation/steps/apply_step_3_professional.dart';
import 'package:streamer_app/features/organization/models/org_event.dart';
import 'package:streamer_app/features/organization/models/org_event_text.dart';
import 'package:streamer_app/features/organization/models/org_invitation.dart';
import 'package:streamer_app/features/organization/models/org_membership.dart';
import 'package:streamer_app/features/organization/presentation/org_invitation_screen.dart';
import 'package:streamer_app/features/organization/presentation/org_membership_panel.dart';
import 'package:streamer_app/features/organization/presentation/organization_hub_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/scripted_broadcasts.dart';
import 'package:streamer_app/features/organization/presentation/organization_shows_screen.dart';
import 'package:streamer_app/features/organization/presentation/channel_connections_screen.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';

const org = '11111111-1111-4111-8111-111111111111';
const otherOrg = '22222222-2222-4222-8222-222222222222';
const session = '33333333-3333-4333-8333-333333333333';
const invite = '44444444-4444-4444-8444-444444444444';
const event = '55555555-5555-4555-8555-555555555555';
const me = '66666666-6666-4666-8666-666666666666';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(
          File('assets/i18n/${locale.languageCode}.json').readAsStringSync());
}

OrgMembership membership(
        {String role = 'broadcaster',
        String status = 'active',
        String id = org,
        bool v1 = true,
        Map<String, bool> grants = const {'can_go_live_video': true},
        bool transferToMe = false,
        String? transferTarget,
        String name = 'Pilot Academy'}) =>
    OrgMembership.fromRow({
      'organization_id': id,
      'profile_id': me,
      'role': role,
      'status': status,
      'permissions': grants,
      'organization_name_en': name,
      'organization_name_ar': 'أكاديمية تجريبية',
      'name_en': 'Member',
      'name_ar': 'عضو',
      'v1_enabled': v1,
      'transfer_to_me': transferToMe,
      'transfer_target_id': transferTarget,
      'transfer_expires_at': transferToMe || transferTarget != null
          ? '2026-10-08T09:00:00Z'
          : null,
    });

OrgEvent orgEvent(String kind,
        {String id = event, String? readAt, Map<String, dynamic>? payload}) =>
    OrgEvent.fromRow({
      'id': id, 'kind': kind, 'organization_id': org, 'session_id': session,
      'invitation_id': invite,
      'payload': payload ??
          {
            'organization_name_en': 'Pilot Academy',
            'organization_name_ar': 'أكاديمية',
            'title_en': 'Weekly lesson',
            'title_ar': 'الدرس الأسبوعي',
            'role': 'manager'
          },
      // Relative: the provider drops notifications older than 12 h, so a fixed date
      // made this test fail the day after it was written.
      'created_at': DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 1))
          .toIso8601String(),
      'read_at': readAt,
    });

OrgInvitation invitation({String role = 'manager'}) => OrgInvitation.fromRow({
      'id': invite,
      'organization_id': org,
      'organization_name_en': 'Pilot Academy',
      'organization_name_ar': 'أكاديمية تجريبية',
      'role': role,
      'permissions': {'can_go_audio_only': true},
      'expires_at': '2026-10-08T09:00:00Z',
      'email': 'invitee@example.invalid',
    });

AppProvider signedIn(ScriptedBroadcasts backend) {
  final provider = AppProvider.withServices(
      adminDbService: AdminDatabaseService(null),
      organizationBroadcastService: backend);
  provider.debugSetSignedInForTests(
      email: 'member@example.invalid', isStreamer: false, userId: me);
  return provider;
}

BroadcastSession show(
        {String state = 'awaiting_acceptance',
        String presenter = me,
        String title = 'Weekly lesson'}) =>
    BroadcastSession.fromRow({
      'id': session,
      'owner_id': presenter,
      'org_id': org,
      'state': state,
      'revision': 3,
      'title_en': title,
      'title_ar': 'الدرس الأسبوعي',
      'broadcast_type': 'liveVideo',
      'scheduled_start_at': '2026-10-02T15:00:00Z',
      'expected_end_at': '2026-10-02T16:00:00Z',
      'schedule_id': invite,
    });

Future<void> pumpApp(WidgetTester tester, AppProvider provider, Widget home,
    {String locale = 'en', double width = 390, double textScale = 1}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => home),
    for (final path in [
      '/shows',
      '/channels',
      '/organizations',
      '/feed',
      '/live/:id',
      '/org-invite/:id'
    ])
      GoRoute(
          path: path,
          builder: (_, state) => Scaffold(body: Text('route:${state.uri}'))),
  ]);
  await tester.pumpWidget(EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    startLocale: Locale(locale),
    saveLocale: false,
    path: 'assets/i18n',
    assetLoader: const _Loader(),
    child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
            builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(textScale),
                      disableAnimations: true),
                  child: MaterialApp.router(
                      theme: AppTheme.forLocale(context.locale),
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      routerConfig: router),
                ))),
  ));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Organization V1 models', () {
    test('events route to exact destinations and reject unknown kinds', () {
      expect(orgEvent('invitation').route, '/org-invite/$invite');
      expect(orgEvent('show_live').route, '/live/$session');
      expect(orgEvent('assignment_reminder').route, '/shows');
      expect(orgEvent('transfer_proposed').route, '/organizations');
      expect(() => orgEvent('anything_else'), throwsFormatException);
    });

    test('push routes come from validated identifiers only', () {
      expect(
          AppProvider.organizationEventRoute(
              {'kind': 'show_live', 'event_id': event, 'session_id': session}),
          '/live/$session');
      expect(
          AppProvider.organizationEventRoute({
            'kind': 'show_live',
            'event_id': event,
            'session_id': '../admin'
          }),
          '/organizations');
      expect(
          AppProvider.organizationEventRoute(
              {'kind': 'admin', 'event_id': event}),
          isNull);
      expect(
          AppProvider.organizationEventRoute(
              {'kind': 'invitation', 'event_id': 'x'}),
          isNull);
    });

    test('every event kind has complete wording in both languages', () {
      for (final kind in OrgEvent.kinds) {
        for (final language in ['en', 'ar']) {
          final text = orgEventText(orgEvent(kind), language);
          expect(text.title, isNotEmpty);
          expect(text.body, isNot(contains('null')));
        }
      }
      expect(orgEventText(orgEvent('invitation', payload: {}), 'en').body,
          contains('Your organization'));
      expect(
          orgEventText(
                  orgEvent('assignment', payload: {'title_en': 'English only'}),
                  'ar')
              .body,
          contains('English only'));
    });

    test('membership rows carry availability and transfer state', () {
      final m = membership(role: 'owner', v1: false, transferTarget: me);
      expect(m.v1Enabled, isFalse);
      expect(m.transferTargetId, me);
      expect(m.transferExpiresAt, isNotNull);
      expect(membership(transferToMe: true).transferToMe, isTrue);
    });

    test('invitation links route through the URL fragment', () {
      final link = organizationInvitationLink(
          Uri.parse('https://stream-application-ten.vercel.app/#/welcome'),
          invite,
          'secret token');
      expect(
          link.toString(),
          startsWith(
              'https://stream-application-ten.vercel.app/#/org-invite/$invite?token='));
      expect(link.path, '/');
      expect(Uri.parse(link.fragment).queryParameters['token'], 'secret token');
      expect(
          () =>
              organizationInvitationLink(Uri.parse('file:///app'), invite, 't'),
          throwsStateError);
    });

    test('rollout switches count as off until the server answers', () {
      final flags = AppFlags();
      expect(flags.isEnabled(AppFlagKey.chatEnabled), isTrue);
      expect(flags.isEnabled(AppFlagKey.organizationsV1Enabled), isFalse);
      expect(flags.organizationApplicationsOpen, isFalse);
      flags.debugSetValues({AppFlagKey.organizationApplicationsOpen: true});
      expect(flags.organizationApplicationsOpen, isTrue);
      flags.debugSetValues({AppFlagKey.organizationsV1Enabled: true});
      expect(flags.organizationApplicationsOpen, isTrue);
    });

    test('server refusals map to specific organization messages', () {
      String key(String code) => OrganizationBroadcastService.actionErrorKey(
          PostgrestException(message: 'x', code: code));
      expect(key('42501'), 'organization_v1.denied_failed');
      expect(key('23P01'), 'organization_v1.overlap_failed');
      expect(key('55000'), 'organization_v1.conflict_failed');
      expect(key('23505'), 'organization_v1.duplicate_failed');
      expect(OrganizationBroadcastService.actionErrorKey(StateError('x')),
          'organization_v1.failure');
    });
  });

  group('Organization V1 provider inbox', () {
    test(
        'unread events reach the notification center once, with their destination',
        () async {
      final backend = ScriptedBroadcasts()
        ..eventRows = [
          orgEvent('show_live', id: event),
          orgEvent('assignment', id: invite, readAt: '2026-10-01T10:00:00Z')
        ];
      final provider = signedIn(backend);
      await provider.refreshOrganizationEvents();
      await provider.refreshOrganizationEvents();
      final org = provider.enhancedNotifications
          .where((n) => n.id.startsWith('org:'))
          .toList();
      expect(org, hasLength(1));
      expect(org.single.type, NotificationType.orgStreamerLiveStatus);
      expect(org.single.streamId, session);
      provider.markNotificationAsRead('org:$event');
      await Future<void>.delayed(Duration.zero);
      expect(backend.calls, contains('read:$event'));
      expect(provider.organizationEvents.firstWhere((e) => e.id == event).read,
          isTrue);
      provider.dispose();
    });

    test('signed-out accounts never load organization events', () async {
      final backend = ScriptedBroadcasts()
        ..eventRows = [orgEvent('assignment')];
      final provider = AppProvider.withServices(
          adminDbService: AdminDatabaseService(null),
          organizationBroadcastService: backend);
      await provider.refreshOrganizationEvents();
      expect(provider.organizationEvents, isEmpty);
      provider.dispose();
    });
  });

  group('Organization hub', () {
    for (final locale in ['en', 'ar']) {
      for (final width in [320.0, 600.0]) {
        testWidgets(
            'invitation, transfer and owner setup render ($locale, $width)',
            (tester) async {
          final backend = ScriptedBroadcasts()
            ..myInvitationRows = [invitation()]
            ..mine = [
              membership(
                  role: 'owner',
                  v1: false,
                  name:
                      'An organization with a very long name for wrapping checks'),
              membership(id: otherOrg, role: 'manager', transferToMe: true),
            ];
          final provider = signedIn(backend);
          await pumpApp(tester, provider, const OrganizationHubScreen(),
              locale: locale, width: width, textScale: width == 320 ? 2 : 1);
          expect(tester.takeException(), isNull);
          expect(find.text('organization_v1.pending_invitations'.tr()),
              findsWidgets);
          for (final key in [
            'organization_v1.setup',
            'organization_v1.not_enabled',
            'organization_v1.accept_transfer'
          ]) {
            await tester.scrollUntilVisible(find.text(key.tr()), 200,
                scrollable: find.byType(Scrollable).first);
            expect(find.text(key.tr()), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox.shrink());
          provider.dispose();
        });
      }
    }

    testWidgets(
        'accepting an invitation answers it in-app and refreshes the list',
        (tester) async {
      final backend = ScriptedBroadcasts()..myInvitationRows = [invitation()];
      final provider = signedIn(backend);
      await pumpApp(tester, provider, const OrganizationHubScreen());
      await tester.tap(find.widgetWithText(CaButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('invite:$invite:true:'));
      expect(find.text('Pilot Academy'), findsNothing);
      expect(find.text('Invitation accepted.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'incoming transfer requires confirmation and leads to channel reconnection',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership(role: 'co_owner', transferToMe: true)];
      final provider = signedIn(backend);
      await pumpApp(tester, provider, const OrganizationHubScreen());
      await tester
          .tap(find.widgetWithText(CaButton, 'Accept ownership transfer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('reconnect'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(CaAlertDialog),
          matching:
              find.widgetWithText(CaButton, 'Accept ownership transfer')));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('transfer:$org:accept'));
      expect(find.text('route:/channels'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('a refused action shows the server reason, not a success',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership(role: 'manager', transferToMe: true)]
        ..failure =
            const PostgrestException(message: 'active shows', code: '55000');
      final provider = signedIn(backend);
      await pumpApp(tester, provider, const OrganizationHubScreen());
      await tester.tap(find.widgetWithText(CaButton, 'Decline'));
      await tester.pumpAndSettle();
      expect(find.text('organization_v1.conflict_failed'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets(
        'activity entries open their destination and mark the event read',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..eventRows = [orgEvent('assignment_reminder')];
      final provider = signedIn(backend);
      await pumpApp(tester, provider, const OrganizationHubScreen());
      await tester.ensureVisible(find.text('Your show starts soon'));
      await tester.tap(find.text('Your show starts soon'));
      await tester.pumpAndSettle();
      expect(backend.calls, contains('read:$event'));
      expect(find.text('route:/shows'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('no memberships shows a truthful empty state', (tester) async {
      final provider = signedIn(ScriptedBroadcasts());
      await pumpApp(tester, provider, const OrganizationHubScreen());
      expect(
          find.text('organization_v1.no_organizations'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });

  group('Membership management', () {
    testWidgets('leaders see pending invitations and must confirm withdrawal',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership(role: 'manager')]
        ..members = {
          org: [membership(role: 'manager')]
        }
        ..invitationRows = {
          org: [invitation(role: 'broadcaster')]
        };
      final provider = signedIn(backend);
      await provider.refreshOrgMemberships();
      await pumpApp(
          tester,
          provider,
          const Scaffold(
              body: SingleChildScrollView(
                  child: OrgMembershipPanel(orgId: org))));
      expect(find.text('invitee@example.invalid'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Withdraw invitation'));
      await tester.pumpAndSettle();
      expect(backend.calls, isEmpty);
      await tester.tap(find.widgetWithText(CaButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(backend.calls, ['revoke-invite:$invite']);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('owner sees a pending transfer and can withdraw it',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership(role: 'owner', transferTarget: otherOrg)]
        ..members = {
          org: [membership(role: 'owner', transferTarget: otherOrg)]
        };
      final provider = signedIn(backend);
      await provider.refreshOrgMemberships();
      await pumpApp(
          tester,
          provider,
          const Scaffold(
              body: SingleChildScrollView(
                  child: OrgMembershipPanel(orgId: org))));
      await tester.tap(find.widgetWithText(TextButton, 'Withdraw transfer'));
      await tester.pumpAndSettle();
      expect(backend.calls, ['cancel-transfer:$org']);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('moderators get no member management actions', (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership(role: 'moderator')]
        ..members = {
          org: [membership(role: 'moderator')]
        };
      final provider = signedIn(backend);
      await provider.refreshOrgMemberships();
      await pumpApp(
          tester,
          provider,
          const Scaffold(
              body: SingleChildScrollView(
                  child: OrgMembershipPanel(orgId: org))));
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      expect(find.text('Invite'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });

  group('Invitation link', () {
    testWidgets('wrong account is explained instead of a generic failure',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..failure =
            const PostgrestException(message: 'other account', code: '42501');
      final provider = signedIn(backend);
      await pumpApp(tester, provider,
          const OrgInvitationScreen(id: invite, token: 'token'));
      await tester.tap(find.widgetWithText(CaButton, 'Accept'));
      await tester.pumpAndSettle();
      expect(find.text('organization_v1.invite_wrong_account'.tr()),
          findsOneWidget);
      expect(backend.calls, ['invite:$invite:true:token']);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('bound invitation shows organization and role before answering',
        (tester) async {
      final backend = ScriptedBroadcasts()..myInvitationRows = [invitation()];
      final provider = signedIn(backend);
      await pumpApp(tester, provider, const OrgInvitationScreen(id: invite),
          locale: 'ar');
      expect(find.text('أكاديمية تجريبية'), findsOneWidget);
      await tester
          .tap(find.widgetWithText(CaButton, 'organization_v1.accept'.tr()));
      await tester.pumpAndSettle();
      expect(find.text('route:/organizations'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });

  group('Shows and assignments', () {
    for (final locale in ['en', 'ar']) {
      testWidgets('presenter answers an assignment at narrow width ($locale)',
          (tester) async {
        final backend = ScriptedBroadcasts()
          ..mine = [membership()]
          ..sessionRows = [
            show(
                title:
                    'A long weekly lesson title that must wrap on a narrow phone screen')
          ];
        final provider = signedIn(backend);
        await pumpApp(tester, provider, const OrganizationShowsScreen(),
            locale: locale, width: 320, textScale: 1.5);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
            find.text('organization_v1.accept'.tr()), 200,
            scrollable: find.byType(Scrollable).first);
        await tester.tap(find.text('organization_v1.accept'.tr()));
        await tester.pumpAndSettle();
        expect(backend.calls, ['assignment:$session:true']);
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
      });
    }

    testWidgets('leadership sees scheduling and the not-enabled explanation',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership(role: 'manager', v1: false)];
      final provider = signedIn(backend);
      await pumpApp(tester, provider,
          const OrganizationShowsScreen(initialOrganizationId: org));
      expect(
          find.text('organization_v1.not_enabled_hint'.tr()), findsOneWidget);
      expect(find.text('organization_v1.schedule'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('a presenter cannot schedule or answer someone else',
        (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership()]
        ..sessionRows = [show(presenter: otherOrg)];
      final provider = signedIn(backend);
      await pumpApp(tester, provider,
          const OrganizationShowsScreen(initialOrganizationId: org));
      expect(find.text('organization_v1.schedule'.tr()), findsNothing);
      expect(find.text('organization_v1.accept'.tr()), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('a refused answer shows the reason', (tester) async {
      final backend = ScriptedBroadcasts()
        ..mine = [membership()]
        ..sessionRows = [show()];
      final provider = signedIn(backend);
      await pumpApp(tester, provider, const OrganizationShowsScreen());
      backend.failure =
          const PostgrestException(message: 'stale', code: '42501');
      await tester.tap(find.text('organization_v1.decline'.tr()));
      await tester.pumpAndSettle();
      expect(find.text('organization_v1.denied_failed'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });

    testWidgets('a stale organization link falls back to my assignments',
        (tester) async {
      final backend = ScriptedBroadcasts()..mine = [membership()];
      final provider = signedIn(backend);
      await pumpApp(tester, provider,
          const OrganizationShowsScreen(initialOrganizationId: otherOrg));
      expect(tester.takeException(), isNull);
      expect(find.text('organization_v1.my_assignments'.tr()), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
    });
  });

  group('Channel consent return', () {
    for (final status in ['connected', 'failed']) {
      testWidgets('explains a $status return', (tester) async {
        final provider = signedIn(ScriptedBroadcasts());
        await pumpApp(
            tester, provider, ChannelConnectionsScreen(returnStatus: status));
        expect(
            find.text('organization_v1.consent_$status'.tr()), findsOneWidget);
        // Google's return replaces the history; the page must still offer a way out.
        expect(find.byTooltip('organization_v1.close'.tr()), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
      });
    }
  });

  group('Organization applications', () {
    Future<bool?> pickOrganization(WidgetTester tester, bool open) async {
      bool? chosen;
      final provider = AppProvider(AdminDatabaseService(null));
      await pumpApp(
          tester,
          provider,
          Scaffold(
              body: ApplyStep3Professional(
                  affiliationController: TextEditingController(),
                  youtubeController: TextEditingController(),
                  orgNameController: TextEditingController(),
                  selectedCategories: const [],
                  isOrganization: false,
                  selectedTags: const [],
                  onCategoriesChanged: (_) {},
                  onTypeChanged: (v) => chosen = v,
                  onTagToggled: (_) {},
                  organizationApplicationsOpen: open)));
      await tester.tap(find.text('Organization / Center'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      provider.dispose();
      return chosen;
    }

    testWidgets('closed switch keeps organization applications unavailable',
        (tester) async {
      expect(await pickOrganization(tester, false), isNull);
    });

    testWidgets('open switch lets an organization apply', (tester) async {
      expect(await pickOrganization(tester, true), isTrue);
    });
  });
}
