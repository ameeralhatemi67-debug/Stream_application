import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/live_stream/models/stream_privacy_models.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/private_stream_viewer_gate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppProvider: Private & Restricted Streaming (client-simulated)', () {
    test('defaults to public with no whitelist and knock approval enabled',
        () {
      final provider = AppProvider();
      expect(provider.streamVisibility, equals(StreamVisibility.public));
      expect(provider.streamWhitelistHandles, isEmpty);
      expect(provider.requireKnockApproval, isTrue);
      expect(provider.isActiveStreamPrivate, isFalse);
    });

    test('configureStreamPrivacy retains the whitelist but forces public mode', () {
      final provider = AppProvider();
      provider.configureStreamPrivacy(
        visibility: StreamVisibility.private,
        whitelistHandles: ['@sarah', '@khalid'],
        requireKnockApproval: false,
      );

      expect(provider.streamVisibility, equals(StreamVisibility.public));
      expect(provider.streamWhitelistHandles,
          containsAll(['@sarah', '@khalid']));
      expect(provider.requireKnockApproval, isFalse);
    });

    test('add/removeStreamWhitelistHandle mutate the roster without dupes',
        () {
      final provider = AppProvider();
      provider.addStreamWhitelistHandle('@sarah');
      provider.addStreamWhitelistHandle('@sarah');
      expect(provider.streamWhitelistHandles, equals(['@sarah']));

      provider.removeStreamWhitelistHandle('@sarah');
      expect(provider.streamWhitelistHandles, isEmpty);
    });

    test('simulateIncomingKnock is disabled with private mode', () {
      final provider = AppProvider();
      expect(provider.pendingKnockRequests, isEmpty);

      provider.simulateIncomingKnock();
      expect(provider.pendingKnockRequests, isEmpty);
    });

    test('admitKnockRequest cannot admit a disabled simulated request', () {
      final provider = AppProvider();
      provider.simulateIncomingKnock();
      const id = 'disabled-request';

      provider.admitKnockRequest(id);

      expect(provider.pendingKnockRequests, isEmpty);
      expect(provider.admittedAttendees, isEmpty);
    });

    test('denyKnockRequest handles the disabled empty queue', () {
      final provider = AppProvider();
      provider.simulateIncomingKnock();
      const id = 'disabled-request';

      provider.denyKnockRequest(id);

      expect(provider.pendingKnockRequests, isEmpty);
      expect(provider.admittedAttendees, isEmpty);
    });

    test('admitAllKnockRequests cannot admit disabled simulated requests', () {
      final provider = AppProvider();
      provider.simulateIncomingKnock();
      provider.simulateIncomingKnock();
      provider.simulateIncomingKnock();

      provider.admitAllKnockRequests();

      expect(provider.pendingKnockRequests, isEmpty);
      expect(provider.admittedAttendees, isEmpty);
    });

    test('admitAttendeeByHandle adds a VIP attendee when the handle is '
        'whitelisted', () {
      final provider = AppProvider();
      provider.addStreamWhitelistHandle('@sarah');

      provider.admitAttendeeByHandle('@sarah');

      expect(provider.admittedAttendees.length, equals(1));
      expect(provider.admittedAttendees.first.isVip, isTrue);
    });

    test('kickAttendee removes an admitted attendee', () {
      final provider = AppProvider();
      provider.admitAttendeeByHandle('@khalid');
      expect(provider.admittedAttendees.length, equals(1));

      provider.kickAttendee('@khalid');

      expect(provider.admittedAttendees, isEmpty);
    });

    test('generatePrivateInviteLink does not share a fake private link', () {
      final provider = AppProvider();
      final link = provider.generatePrivateInviteLink();
      expect(link, isEmpty);
    });

    test('localViewerAccessState is notApplicable when no stream is live',
        () {
      final provider = AppProvider();
      expect(provider.localViewerAccessState,
          equals(ViewerAccessState.notApplicable));
    });
  });

  group('PrivateStreamViewerGate: renders the correct overlay per state', () {
    Widget wrap(ViewerAccessState state) {
      return MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              PrivateStreamViewerGate(
                accessState: state,
                onRequestToJoin: () {},
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('notApplicable renders nothing', (tester) async {
      await tester.pumpWidget(wrap(ViewerAccessState.notApplicable));
      expect(find.text('VIP Invited'), findsNothing);
      expect(find.text('This broadcast is private'), findsNothing);
    });

    testWidgets('admitted renders nothing', (tester) async {
      await tester.pumpWidget(wrap(ViewerAccessState.admitted));
      expect(find.text('VIP Invited'), findsNothing);
      expect(find.text('Waiting for host to admit you...'), findsNothing);
    });

    testWidgets('vipPreApproved shows the gold VIP badge', (tester) async {
      await tester.pumpWidget(wrap(ViewerAccessState.vipPreApproved));
      expect(find.text('VIP Invited'), findsOneWidget);
    });

    testWidgets('knocking shows the waiting-room overlay', (tester) async {
      await tester.pumpWidget(wrap(ViewerAccessState.knocking));
      expect(find.text('Waiting for host to admit you...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'denied shows the unauthorized notice with a Request to Join button',
        (tester) async {
      var requested = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                PrivateStreamViewerGate(
                  accessState: ViewerAccessState.denied,
                  onRequestToJoin: () => requested = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('This broadcast is private'), findsOneWidget);
      await tester.tap(find.text('Request to Join'));
      expect(requested, isTrue);
    });
  });
}
