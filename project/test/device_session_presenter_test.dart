import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/models/device_session_model.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/widgets/device_session_presenter.dart';

import 'support/localized_app.dart';

class _Auth extends SupabaseAuthService {
  final changes = StreamController<AuthState>.broadcast(sync: true);
  Session? session;
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => changes.stream;

  void signIn(String id) {
    session = Session(
        accessToken: 'test-only',
        tokenType: 'bearer',
        user: User(
            id: id,
            appMetadata: {},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: '2026-09-24T00:00:00Z',
            email: '$id@example.invalid'));
    changes.add(AuthState(AuthChangeEvent.signedIn, session));
  }
}

/// Approved broadcaster whose account is primary on another phone.
class _ConflictDb extends AdminDatabaseService {
  final devices = StreamController<List<DeviceSessionModel>>.broadcast();
  final other = DeviceSessionModel(
      deviceId: 'phone-1',
      deviceName: 'android Device',
      platform: 'android',
      lastActiveAt: DateTime.now());
  bool conflict = true;
  int forcedClaims = 0;
  int claims = 0;
  Object? heartbeatError;
  bool heartbeatPrimary = true;

  @override
  Future<bool> checkIsProfileStreamer(String id) async => true;
  @override
  Future<Map<String, dynamic>?> loadOwnProfile(String id) async =>
      {'display_name_en': 'C', 'is_streamer': true, 'is_verified': true};
  @override
  Future<DeviceClaimResult> claimDeviceState(DeviceSessionModel device,
      {bool force = false}) async {
    claims++;
    if (force) {
      forcedClaims++;
      conflict = false;
      return const DeviceClaimResult(claimed: true);
    }
    return conflict
        ? DeviceClaimResult(claimed: false, primary: other)
        : const DeviceClaimResult(claimed: true);
  }

  @override
  Stream<List<DeviceSessionModel>> watchDevices(String userId) =>
      devices.stream;
  @override
  Future<bool> heartbeatDevice(String deviceId) async {
    if (heartbeatError != null) throw heartbeatError!;
    return heartbeatPrimary;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<(AppProvider, GoRouter, DeviceSessionPresenter)> launch(
      WidgetTester tester, _Auth auth, _ConflictDb db) async {
    final provider =
        AppProvider.withServices(authService: auth, adminDbService: db);
    final router = AppRouter.build(provider);
    final presenter =
        DeviceSessionPresenter(provider: provider, router: router)..attach();
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: const Locale('en'),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: Builder(
        builder: (context) => ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp.router(
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            routerConfig: router,
          ),
        ),
      ),
    ));
    return (provider, router, presenter);
  }

  Future<void> settleRoutes(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> teardown(WidgetTester tester, AppProvider provider,
      GoRouter router, DeviceSessionPresenter presenter, _ConflictDb db) async {
    presenter.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    provider.dispose();
    await db.devices.close();
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets(
      'R02: a conflict found while signing in stays visible after the router '
      'leaves the splash page', (tester) async {
    final auth = _Auth();
    final db = _ConflictDb();
    final (provider, router, presenter) = await launch(tester, auth, db);
    await tester.pump();
    auth.signIn('c');
    await settleRoutes(tester);

    expect(provider.remoteBroadcasterSession?.deviceId, 'phone-1');
    expect(find.text('design_ui.multiple_device_login_detected'.tr()),
        findsOneWidget,
        reason: 'the second device must see the conflict dialog');

    await tester.tap(find.text('design_ui.continue_as_viewer'.tr()));
    await settleRoutes(tester);
    expect(provider.isStreamerModeEnabled, isFalse);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isFalse);
    expect(db.forcedClaims, 0);
    expect(
        (await SharedPreferences.getInstance())
            .getBool('broadcaster_viewer_device_c'),
        isTrue,
        reason: 'viewer choice survives a restart');
    await teardown(tester, provider, router, presenter, db);
  });

  testWidgets('R02: transfer from the dialog claims with force',
      (tester) async {
    final auth = _Auth();
    final db = _ConflictDb();
    final (provider, router, presenter) = await launch(tester, auth, db);
    await tester.pump();
    auth.signIn('c');
    await settleRoutes(tester);
    await tester.tap(find.text('design_ui.transfer_broadcaster_to_this_device'.tr()));
    await settleRoutes(tester);
    expect(db.forcedClaims, 1);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isTrue);
    expect(provider.remoteBroadcasterSession, isNull);
    expect(find.text('design_ui.multiple_device_login_detected'.tr()),
        findsNothing);
    await teardown(tester, provider, router, presenter, db);
  });

  testWidgets('R02: a restored session on cold start also shows the conflict',
      (tester) async {
    final auth = _Auth()..session = null;
    auth.signIn('c');
    final db = _ConflictDb();
    final (provider, router, presenter) = await launch(tester, auth, db);
    await settleRoutes(tester);
    expect(find.text('design_ui.multiple_device_login_detected'.tr()),
        findsOneWidget);
    await teardown(tester, provider, router, presenter, db);
  });

  testWidgets('R02: a persisted viewer choice survives restart without a claim',
      (tester) async {
    SharedPreferences.setMockInitialValues({'broadcaster_viewer_device_c': true});
    final auth = _Auth();
    auth.signIn('c');
    final db = _ConflictDb();
    final (provider, router, presenter) = await launch(tester, auth, db);
    await settleRoutes(tester);
    expect(db.claims, 0);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isFalse);
    expect(provider.isStreamerModeEnabled, isFalse);
    expect(find.text('design_ui.multiple_device_login_detected'.tr()),
        findsNothing);
    await teardown(tester, provider, router, presenter, db);
  });

  testWidgets(
      'R02: Realtime errors ask the server; only a definite answer demotes',
      (tester) async {
    final auth = _Auth();
    auth.signIn('c');
    final db = _ConflictDb()..conflict = false;
    final (provider, router, presenter) = await launch(tester, auth, db);
    await settleRoutes(tester);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isTrue);

    db.devices.addError(StateError('Device channel timedOut'));
    await settleRoutes(tester);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isTrue,
        reason: 'a channel error is not an ownership answer');

    db.heartbeatError = Exception('offline');
    db.devices.addError(StateError('Device channel channelError'));
    await settleRoutes(tester);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isTrue,
        reason: 'a short network failure does not end a live broadcast');

    db.heartbeatError = null;
    db.heartbeatPrimary = false;
    db.devices.addError(StateError('Device channel channelError'));
    await settleRoutes(tester);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isFalse);
    expect(provider.broadcastSessionError, 'broadcast_session_lost');
    expect(router.routerDelegate.currentConfiguration.uri.path, '/feed');
    expect(find.text('broadcast_session_lost'.tr()), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance())
            .getBool('broadcaster_viewer_device_c'),
        isTrue,
        reason: 'a displaced device must not reclaim after restart');
    await teardown(tester, provider, router, presenter, db);
  });

  testWidgets('R02: a transfer seen on the device stream demotes this device',
      (tester) async {
    final auth = _Auth();
    auth.signIn('c');
    final db = _ConflictDb()..conflict = false;
    final (provider, router, presenter) = await launch(tester, auth, db);
    await settleRoutes(tester);
    final mine = provider.currentDeviceSession!;
    db.devices.add([
      mine.copyWith(isPrimaryBroadcaster: false),
      db.other,
    ]);
    await settleRoutes(tester);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isFalse);
    expect(provider.isStreamerModeEnabled, isFalse);
    expect(provider.remoteBroadcasterSession, isNull);
    // A late row showing this device primary again cannot re-promote it.
    db.devices.add([mine.copyWith(isPrimaryBroadcaster: true)]);
    await settleRoutes(tester);
    expect(provider.currentDeviceSession?.isPrimaryBroadcaster, isFalse);
    await teardown(tester, provider, router, presenter, db);
  });
}
