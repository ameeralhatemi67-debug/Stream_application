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

    test('configureStreamPrivacy persists visibility and whitelist', () {
      final provider = AppProvider();
      provider.configureStreamPrivacy(
        visibility: StreamVisibility.private,
        whitelistHandles: ['@sarah', '@khalid'],
        requireKnockApproval: false,
      );

      expect(provider.streamVisibility, equals(StreamVisibility.private));
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

    test('simulateIncomingKnock enqueues a pending request', () {
      final provider = AppProvider();
      expect(provider.pendingKnockRequests, isEmpty);

      provider.simulateIncomingKnock();
      expect(provider.pendingKnockRequests.length, equals(1));
      expect(provider.pendingKnockRequests.first.displayName, isNotEmpty);
    });

    test('admitKnockRequest moves a request from pending to admitted', () {
      final provider = AppProvider();
      provider.simulateIncomingKnock();
      final id = provider.pendingKnockRequests.first.id;

      provider.admitKnockRequest(id);

      expect(provider.pendingKnockRequests, isEmpty);
      expect(provider.admittedAttendees.length, equals(1));
      expect(provider.admittedAttendees.first.id, equals(id));
    });

    test('denyKnockRequest drops a request without admitting it', () {
      final provider = AppProvider();
      provider.simulateIncomingKnock();
      final id = provider.pendingKnockRequests.first.id;

      provider.denyKnockRequest(id);

      expect(provider.pendingKnockRequests, isEmpty);
      expect(provider.admittedAttendees, isEmpty);
    });

    test('admitAllKnockRequests clears the whole queue into attendees', () {
      final provider = AppProvider();
      provider.simulateIncomingKnock();
      provider.simulateIncomingKnock();
      provider.simulateIncomingKnock();

      provider.admitAllKnockRequests();

      expect(provider.pendingKnockRequests, isEmpty);
      expect(provider.admittedAttendees.length, equals(3));
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

    test('generatePrivateInviteLink returns a shareable join link', () {
      final provider = AppProvider();
      final link = provider.generatePrivateInviteLink();
      expect(link, startsWith('https://streamer.app/join/'));
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
