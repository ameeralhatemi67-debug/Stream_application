import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:streamer_app/core/providers/app_flags.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';
import 'package:streamer_app/features/map/presentation/venue_directions_launcher.dart';
import 'package:streamer_app/features/organization/presentation/channel_connections_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/localized_app.dart';

class _Auth extends SupabaseAuthService {
  int appleCalls = 0;
  int googleCalls = 0;
  Object appleFailure = const AuthException('private native failure detail');
  @override
  Session? get currentSession => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  Future<void> signInWithApple() async {
    appleCalls++;
    throw appleFailure;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleCalls++;
  }
}

class _FlagsStore implements AppFlagsStore {
  _FlagsStore({this.open = true});
  final bool open;
  @override
  Future<Map<String, ({bool enabled, DateTime? updatedAt})>> fetch() async =>
      {'registrations_open': (enabled: open, updatedAt: null)};
  @override
  Future<void> set(String key, bool enabled, String reason) async {}
}

class _ChannelsProvider extends AppProvider {
  _ChannelsProvider() : super.withServices(authService: _Auth());
  int connects = 0;
  @override
  bool get personalBroadcastApproved => true;
  @override
  Future<void> refreshChannelConnections() async {}
  @override
  Future<Uri> connectYouTubeChannel({String? organizationId}) async {
    connects++;
    throw StateError('iOS must never request channel authorization');
  }
}

Widget _app(AppProvider provider, Widget home, String language) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
            builder: (context) => MaterialApp(
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  theme: AppTheme.forLocale(context.locale),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: true),
                    child: child!,
                  ),
                  home: home,
                )),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlChannel, null);
  });

  if (!iosPhonePublishingFlag) {
    for (final language in ['en', 'ar']) {
      testWidgets(
          'direct iOS phone setup never requests capture when off ($language)',
          (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final provider = AppProvider.withServices(authService: _Auth());
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const permissions =
            MethodChannel('flutter.baseflow.com/permissions/methods');
        const publisher = MethodChannel('streamer_app/rtmp_publisher');
        final calls = <String>[];
        messenger.setMockMethodCallHandler(permissions, (call) async {
          calls.add(call.method);
          return <int, int>{};
        });
        messenger.setMockMethodCallHandler(publisher, (call) async {
          calls.add(call.method);
          return false;
        });
        try {
          tester.view.physicalSize = const Size(360, 900);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(_app(
              provider,
              const PhoneBroadcastScreen(
                  quickLaunchPreset: BroadcastQualityPreset.low),
              language));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(
              find.text('live.ios_publisher_unavailable'.tr()), findsWidgets);
          expect(calls, isEmpty);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          provider.dispose();
          messenger.setMockMethodCallHandler(permissions, null);
          messenger.setMockMethodCallHandler(publisher, null);
          debugDefaultTargetPlatformOverride = null;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });
    }
  }

  for (final language in ['en', 'ar']) {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('Apple button is iOS only ($platform, $language)',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final provider = AppProvider.withServices(authService: _Auth());
        final flags = AppFlags(store: _FlagsStore());
        try {
          await tester.binding.setSurfaceSize(const Size(360, 900));
          await tester.pumpWidget(
              _app(provider, WelcomeScreen(appFlags: flags), language));
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('welcome-signup')), findsOneWidget);
          if (platform == TargetPlatform.iOS) {
            final apple = find.byType(SignInWithAppleButton);
            expect(apple, findsOneWidget);
            expect(tester.widget<SignInWithAppleButton>(apple).text,
                'auth_welcome.btn_apple'.tr());
            expect(
                tester.getSize(apple).height,
                greaterThanOrEqualTo(tester
                    .getSize(find.byKey(const Key('welcome-signup')))
                    .height));
            expect(Directionality.of(tester.element(apple)),
                language == 'ar' ? TextDirection.rtl : TextDirection.ltr);
          } else {
            expect(find.byType(SignInWithAppleButton), findsNothing);
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          provider.dispose();
          flags.dispose();
          debugDefaultTargetPlatformOverride = null;
          await tester.binding.setSurfaceSize(null);
        }
      });
    }

    testWidgets('Apple failure is friendly; Google remains usable ($language)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final auth = _Auth();
      final provider = AppProvider.withServices(authService: auth);
      final flags = AppFlags(store: _FlagsStore());
      try {
        await provider.recordConsent();
        await tester.binding.setSurfaceSize(const Size(390, 1000));
        await tester.pumpWidget(
            _app(provider, WelcomeScreen(appFlags: flags), language));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(SignInWithAppleButton));
        await tester.tap(find.byType(SignInWithAppleButton));
        await tester.pumpAndSettle();
        expect(auth.appleCalls, 1);
        expect(find.text('auth_welcome.sign_in_failed'.tr()), findsOneWidget);
        expect(find.text('private native failure detail'), findsNothing);
        expect(
            tester
                .widget<SignInWithAppleButton>(
                    find.byType(SignInWithAppleButton))
                .onPressed,
            isNotNull);
        await tester.ensureVisible(find.byType(OutlinedButton));
        await tester.tap(find.byType(OutlinedButton));
        await tester.pumpAndSettle();
        expect(auth.googleCalls, 1);
        expect(provider.currentUserSessionId, isNull);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        flags.dispose();
        debugDefaultTargetPlatformOverride = null;
        await tester.binding.setSurfaceSize(null);
      }
    });

    testWidgets('iOS channel button never starts authorization ($language)',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = _ChannelsProvider();
      try {
        await tester.pumpWidget(
            _app(provider, const ChannelConnectionsScreen(), language));
        await tester.pumpAndSettle();
        await tester.tap(find.text('organization_v1.connect'.tr()));
        await tester.pumpAndSettle();
        expect(provider.connects, 0);
        expect(find.byType(FeatureInProgressModal), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('Apple consent can be declined before native credentials',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final auth = _Auth();
    final provider = AppProvider.withServices(authService: auth);
    final flags = AppFlags(store: _FlagsStore());
    try {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      await tester
          .pumpWidget(_app(provider, WelcomeScreen(appFlags: flags), 'en'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SignInWithAppleButton));
      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();
      expect(auth.appleCalls, 0);
      await tester.tap(find.text('common.decline'.tr()));
      await tester.pumpAndSettle();
      expect(auth.appleCalls, 0);
      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      await tester.tap(find.text('consent.accept_btn'.tr()));
      await tester.pumpAndSettle();
      expect(provider.hasAcceptedCurrentConsent, isTrue);
      expect(auth.appleCalls, 1);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      flags.dispose();
      debugDefaultTargetPlatformOverride = null;
      await tester.binding.setSurfaceSize(null);
    }
  });

  testWidgets('Apple cancellation is quiet and permits another attempt',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final auth = _Auth()
      ..appleFailure = const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled, message: 'Cancelled');
    final provider = AppProvider.withServices(authService: auth);
    final flags = AppFlags(store: _FlagsStore());
    try {
      await provider.recordConsent();
      await tester
          .pumpWidget(_app(provider, WelcomeScreen(appFlags: flags), 'en'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(SignInWithAppleButton));
      await tester.tap(find.byType(SignInWithAppleButton));
      await tester.pumpAndSettle();
      expect(find.text('auth_welcome.sign_in_failed'.tr()), findsNothing);
      expect(
          tester
              .widget<SignInWithAppleButton>(find.byType(SignInWithAppleButton))
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      flags.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('paused registrations still permit existing Apple sign-in',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final provider = AppProvider.withServices(authService: _Auth());
    final flags = AppFlags(store: _FlagsStore(open: false));
    try {
      await tester
          .pumpWidget(_app(provider, WelcomeScreen(appFlags: flags), 'en'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ElevatedButton>(find.byKey(const Key('welcome-signup')))
              .onPressed,
          isNull);
      expect(
          tester
              .widget<SignInWithAppleButton>(find.byType(SignInWithAppleButton))
              .onPressed,
          isNotNull);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
      flags.dispose();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final fallback in [false, true]) {
    test('iOS directions prefer Apple Maps and fall back if needed ($fallback)',
        () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final urls = <Uri>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlChannel, (call) async {
        urls.add(Uri.parse((call.arguments as Map)['url'] as String));
        return !fallback || urls.length > 1;
      });
      expect(await launchVenueDirections(26.3042, 50.1462), isTrue);
      expect(urls.first.host, 'maps.apple.com');
      expect(urls.first.queryParameters['daddr'], '26.3042,50.1462');
      expect(urls.length, fallback ? 2 : 1);
      if (fallback) {
        expect(urls.last.host, 'www.google.com');
        expect(urls.last.queryParameters['destination'], '26.3042,50.1462');
      }
    });
  }

  test('device-session identity uses ios on the actual provider path',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final provider = AppProvider.withServices(authService: _Auth());
    try {
      await provider.initDeviceSession();
      expect(provider.currentDeviceSession?.platform, 'ios');
      expect(provider.currentDeviceSession?.deviceName, 'ios Device');
      expect(provider.currentDeviceSession?.deviceId, isNotEmpty);
    } finally {
      provider.dispose();
    }
  });
}
