import 'support/localized_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/widgets/device_session_conflict_dialog.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/streamer_grid_card.dart';
import 'package:streamer_app/features/live_stream/models/stream_privacy_models.dart';
import 'package:streamer_app/features/live_stream/services/stream_decay_engine.dart';

import 'fixtures/streamer_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Issue Log Fix QF-06: Multi-Device Session Conflict Management', () {
    test(
        'DeviceSessionModel round-trips through JSON serialization and copyWith',
        () {
      final now = DateTime.now();
      final session = DeviceSessionModel(
        deviceId: 'device_win_123',
        deviceName: 'Windows Desktop (Chrome)',
        platform: 'windows',
        lastActiveAt: now,
        isPrimaryBroadcaster: true,
      );

      final json = session.toJson();
      expect(json['device_id'], equals('device_win_123'));
      expect(json['platform'], equals('windows'));
      expect(json['is_primary_broadcaster'], isTrue);

      final deserialized = DeviceSessionModel.fromJson(json);
      expect(deserialized.deviceId, equals('device_win_123'));
      expect(deserialized.deviceName, equals('Windows Desktop (Chrome)'));
      expect(deserialized.isPrimaryBroadcaster, isTrue);

      final updated = deserialized.copyWith(isPrimaryBroadcaster: false);
      expect(updated.isPrimaryBroadcaster, isFalse);
      expect(updated.deviceId, equals('device_win_123'));
    });

    test('AppProvider cannot claim a broadcaster session without a backend',
        () async {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      await provider.initDeviceSession();

      expect(provider.currentDeviceSession, isNotNull);
      expect(provider.currentDeviceSession!.isPrimaryBroadcaster, isFalse);

      // Simulate remote device holding broadcaster session
      final remoteDevice = DeviceSessionModel(
        deviceId: 'device_phone_99',
        deviceName: 'iPhone 15 Pro',
        platform: 'ios',
        lastActiveAt: DateTime.now(),
        isPrimaryBroadcaster: true,
      );
      provider.setRemoteBroadcasterSession(remoteDevice);
      expect(provider.remoteBroadcasterSession, isNotNull);

      // User chooses to continue as viewer on current device
      provider.continueAsViewerOnCurrentDevice();
      expect(provider.currentDeviceSession!.isPrimaryBroadcaster, isFalse);
      expect(provider.isStreamerModeEnabled, isFalse);

      // User chooses to transfer broadcaster to current device
      await provider.transferBroadcasterToCurrentDevice();
      expect(provider.currentDeviceSession!.isPrimaryBroadcaster, isFalse);
      expect(provider.remoteBroadcasterSession, isNotNull);
      provider.applyDeviceSessions([
        provider.currentDeviceSession!.copyWith(isPrimaryBroadcaster: true)
      ]);
      provider.applyDeviceSessions([remoteDevice]);
      expect(provider.broadcastSessionError, 'broadcast_session_lost');
      expect(provider.isBroadcastingLive, isFalse);
      provider.dispose();
    });

    testWidgets(
        'DeviceSessionConflictDialog renders device options and returns choice',
        (WidgetTester tester) async {
      final currentDevice = DeviceSessionModel(
        deviceId: 'cur_dev',
        deviceName: 'Windows Workstation',
        platform: 'windows',
        lastActiveAt: DateTime.now(),
        isPrimaryBroadcaster: false,
      );
      final existingDevice = DeviceSessionModel(
        deviceId: 'exist_dev',
        deviceName: 'Pixel 8 Pro',
        platform: 'android',
        lastActiveAt: DateTime.now(),
        isPrimaryBroadcaster: true,
      );

      DeviceSessionChoice? selectedChoice;

      await tester.pumpWidget(
        localizedApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedChoice = await DeviceSessionConflictDialog.show(
                    context: context,
                    currentDevice: currentDevice,
                    existingDevice: existingDevice,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Multiple Device Login Detected'), findsOneWidget);
      expect(find.text('Pixel 8 Pro'), findsOneWidget);
      expect(find.text('Windows Workstation (This Device)'), findsOneWidget);

      // Tap Transfer Broadcaster
      await tester.tap(find.text('Transfer Broadcaster to This Device'));
      await tester.pumpAndSettle();

      expect(selectedChoice, equals(DeviceSessionChoice.transferBroadcaster));
    });
  });

  group('Issue Log Fix QF-09: Discovery Feed Own-Card Highlight', () {
    testWidgets(
        'StreamerGridCard renders white border and Your Channel badge for own profile',
        (WidgetTester tester) async {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      // Ownership comes from an approved application for that channel, never
      // from the signed-in email (P1.6).
      provider.debugSetSignedInForTests(
        email: 'owner@example.com',
        isStreamer: true,
        ownedStreamerId: 'prof_alghamdi_01',
      );

      final ownStreamer =
          mockStreamers.firstWhere((s) => s.streamerId == 'prof_alghamdi_01');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: localizedApp(
            home: Scaffold(
              body: SizedBox(
                width: 250,
                height: 300,
                child: StreamerGridCard(
                  streamer: ownStreamer,
                  langCode: 'en',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Your Channel" badge is present
      expect(find.text('Your Channel'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets(
        'StreamerGridCard does NOT render Your Channel badge for other streamers',
        (WidgetTester tester) async {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      provider.setBroadcasterStatusForTesting(
          isLoggedIn: true, isApproved: true);

      final otherStreamer =
          mockStreamers.firstWhere((s) => s.streamerId != 'prof_alghamdi_01');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: localizedApp(
            home: Scaffold(
              body: SizedBox(
                width: 250,
                height: 300,
                child: StreamerGridCard(
                  streamer: otherStreamer,
                  langCode: 'en',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your Channel'), findsNothing);
    });
  });

  group('Issue Log Fix QF-10: Cell Tower Permission Boundaries', () {
    test(
        'isOwnStreamerProfile correctly identifies own channel vs other channels',
        () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      provider.debugSetSignedInForTests(
        email: 'owner@example.com',
        isStreamer: true,
        ownedStreamerId: 'prof_alghamdi_01',
      );

      // Own profile: the account's approved application points at it
      expect(provider.isOwnStreamerProfile('prof_alghamdi_01'), isTrue);

      // Other streamer channel
      expect(provider.isOwnStreamerProfile('dr_alshammari_02'), isFalse);
      expect(provider.isOwnStreamerProfile('quran_live_01'), isFalse);
    });

    test(
        'arbitrary email logins do not inherit prof_alghamdi_01 (Cluster 2 Task 10)',
        () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      provider.debugSetSignedInForTests(
        email: 'some.random.viewer@gmail.com',
        isStreamer: true,
      );

      // Being an approved streamer alone must NOT grant ownership of the
      // demo channel -- previously any signed-in approved streamer
      // inherited 'prof_alghamdi_01' (issue_log.md: "I signed in using 3
      // different accounts, all of them have the streamer account 'Amir
      // Al-Hatemi' as their channel").
      expect(provider.isOwnStreamerProfile('prof_alghamdi_01'), isFalse);
    });

    test('no email grants ownership of a channel (P1.6 dev identity removed)',
        () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      // The developer account that used to be hardcoded into
      // primaryOwnedStreamerId gets no special treatment any more.
      provider.debugSetSignedInForTests(
        email: 'polkgvd2@gmail.com',
        isStreamer: true,
      );

      expect(provider.isOwnStreamerProfile('prof_alghamdi_01'), isFalse);
      expect(provider.primaryOwnedStreamerId, isNull);
      expect(provider.currentUserStreamerId, isNull);
      expect(provider.detectDuplicateChannels(), isEmpty);
    });

    test('admin status alone does not grant ownership of another channel', () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      provider.debugSetSignedInForTests(
        email: 'admin@streamer.app',
        isAdmin: true,
      );

      // The cell tower guard in broadcaster_profile_screen.dart is driven
      // solely by isOwnStreamerProfile -- being platform admin must not
      // make it return true for someone else's channel (issue_log.md: "an
      // admin account does not give ability to see and use others accounts
      // cell tower").
      expect(provider.isOwnStreamerProfile('prof_alghamdi_01'), isFalse);
      expect(provider.isOwnStreamerProfile('dr_alshammari_02'), isFalse);
    });
  });

  group('Issue Log Fix QF-11: Stream Decay Engine', () {
    test('StreamDecayEngine monitors heartbeats and decays on timeout',
        () async {
      bool decayed = false;

      final engine = StreamDecayEngine(
        inactivityThreshold: const Duration(milliseconds: 50),
        checkInterval: const Duration(milliseconds: 10),
        onStreamDecayed: () {
          decayed = true;
        },
      );

      engine.startMonitoring(streamId: 'test_stream_01');
      expect(engine.isBroadcasting, isTrue);
      expect(engine.activeStreamId, equals('test_stream_01'));

      // Keep alive with heartbeat
      await Future.delayed(const Duration(milliseconds: 20));
      engine.recordHeartbeat();
      expect(decayed, isFalse);

      // Wait for inactivity threshold to elapse
      await Future.delayed(const Duration(milliseconds: 80));
      expect(decayed, isTrue);
      expect(engine.isBroadcasting, isFalse);

      engine.dispose();
    });
  });

  group('Issue Log Fix QF-12: Private Stream Access & Feed Filtering', () {
    test(
        'private mode remains public until server entitlements exist',
        () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      // Configure a private stream with specific whitelist
      provider.configureStreamPrivacy(
        visibility: StreamVisibility.private,
        whitelistHandles: ['vip_student_1', 'vip_student_2'],
      );

      // Streamers list contains public and private broadcasts
      expect(provider.streamVisibility, equals(StreamVisibility.public));
      expect(provider.generatePrivateInviteLink(), isEmpty);
      expect(provider.isActiveStreamPrivate, isFalse);
      expect(provider.streamWhitelistHandles, contains('vip_student_1'));
    });
  });

  group('Issue Log Fix: Single Channel Ownership & Duplicate Resolution', () {
    test(
        'detectDuplicateChannels and resolveDuplicateChannels keeps chosen channel only',
        () {
      final provider = AppProvider();
      seedStreamerFixtures(provider);
      // The account owns 'prof_alghamdi_01' through its approved application
      // and also still has a card under the application's YouTube handle --
      // the real duplicate case (P1.6: ownership decides, not a name match).
      provider.debugSetSignedInForTests(
        email: 'owner@example.com',
        isStreamer: true,
        ownedStreamerId: 'prof_alghamdi_01',
        ownedYoutubeHandle: 'applied_channel',
      );

      // Add a duplicate applied channel
      final duplicateApplied = provider.streamers.first.copyWith(
        streamerId: 'applied_channel',
        fullNameEn: 'Applied Channel',
      );
      provider.addStreamerForTests(duplicateApplied);

      // Detect duplicates
      final duplicates = provider.detectDuplicateChannels();
      expect(duplicates.length, greaterThanOrEqualTo(2));

      // Resolve duplicates by keeping prof_alghamdi_01
      provider.resolveDuplicateChannels(keptStreamerId: 'prof_alghamdi_01');

      // Verify only single channel remains
      expect(provider.isOwnStreamerProfile('prof_alghamdi_01'), isTrue);
      final remaining = provider.detectDuplicateChannels();
      expect(remaining.length, lessThanOrEqualTo(1));
    });
  });
}
