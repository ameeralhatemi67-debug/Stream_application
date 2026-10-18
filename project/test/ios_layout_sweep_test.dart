import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/core/providers/app_flags.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/consent_dialog.dart';
import 'package:streamer_app/core/widgets/ios_support_contact.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/presentation/settings/privacy_settings_section.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

class _Auth extends SupabaseAuthService {
  @override
  Session? get currentSession => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  Future<void> signInWithApple() async => throw const AuthException('mock');
  @override
  Future<void> signInWithGoogle() async => throw const AuthException('mock');
}

class _Provider extends AppProvider {
  _Provider() : super.withServices(authService: _Auth());
  @override
  Future<String?> deleteOwnAccount() async => 'apple_revocation_unavailable';
}

class _Flags implements AppFlagsStore {
  @override
  Future<Map<String, ({bool enabled, DateTime? updatedAt})>> fetch() async => {
        'registrations_open': (enabled: true, updatedAt: null),
      };
  @override
  Future<void> set(String key, bool enabled, String reason) async {}
}

class _Chat extends LiveChatController {
  static const messageBody =
      'Welcome to the live discussion. مرحبًا بكم في الحوار المباشر.';
  _Chat(String streamId) : super(streamId: streamId);
  @override
  Future<void> start() async => debugSetStateForTests(
      currentUserId: 'layout-viewer',
      chatEnabled: true,
      connectionState: ChatConnectionState.live);
  @override
  List<ChatMessageModel> get messages => [
        ChatMessageModel(
            id: 'layout-message',
            streamId: streamId,
            senderId: 'layout-sender',
            senderName: 'قارئ الرسائل الطويلة',
            body: messageBody,
            createdAt: DateTime(2026, 10, 18)),
      ];
}

Widget _app(AppProvider provider, Widget home, String language, double scale) =>
    EasyLocalization(
      key: UniqueKey(),
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(language),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: Builder(
              builder: (context) => MaterialApp(
                  theme: AppTheme.forLocale(context.locale),
                  locale: context.locale,
                  supportedLocales: context.supportedLocales,
                  localizationsDelegates: context.localizationDelegates,
                  builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                          textScaler: TextScaler.linear(scale),
                          disableAnimations: true),
                      child: child!),
                  home: home))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const urlChannel = MethodChannel('plugins.flutter.io/url_launcher');
  setUpAll(() async {
    await initializeTestLocalization();
    for (final font in {
      'IBM Plex Sans': ['assets/fonts/IBMPlexSans-Variable.ttf'],
      'IBM Plex Sans Arabic': [
        'assets/fonts/IBMPlexSansArabic-400.ttf',
        'assets/fonts/IBMPlexSansArabic-700.ttf'
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(font.key);
      for (final file in font.value) {
        loader.addFont(rootBundle.load(file));
      }
      await loader.load();
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    LiveBroadcastScreen.debugChatFactory = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlChannel, null);
  });

  for (final size in [
    const Size(375, 667),
    const Size(393, 852),
    const Size(430, 932)
  ]) {
    for (final language in ['en', 'ar']) {
      for (final scale in [1.0, 1.5]) {
        for (final surface in [
          'welcome/sign-in',
          'discovery',
          'live/chat',
          'map',
          'settings',
          'delete flow',
          'consent',
          'support'
        ]) {
          testWidgets('iOS $surface $size $language text=$scale',
              (tester) async {
            debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = size;
            tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
            tester.view.viewPadding =
                const FakeViewPadding(top: 59, bottom: 34);
            final provider = _Provider();
            final flags = AppFlags(store: _Flags());
            StubVideoPlayer.install(addTearDown: addTearDown);
            LiveBroadcastScreen.debugChatFactory = (id, _) => _Chat(id);
            try {
              if (surface != 'welcome/sign-in') {
                provider.debugSetSignedInForTests(
                    email: 'layout@example.invalid');
              } else {
                await provider.recordConsent();
              }
              for (final item in mockStreamers) {
                provider.addStreamerForTests(item.copyWith(
                    avatarUrl: '',
                    bannerUrl: '',
                    isCurrentlyLive: true,
                    broadcastType: BroadcastType.liveVideo,
                    activeStreamId: item == mockStreamers.first
                        ? 'stream_live_992'
                        : null));
              }
              final home = switch (surface) {
                'welcome/sign-in' => WelcomeScreen(appFlags: flags),
                'discovery' => const DiscoveryFeedScreen(),
                'live/chat' =>
                  const LiveBroadcastScreen(streamId: 'stream_live_992'),
                'map' => const SpatialMapScreen(),
                'settings' => const SettingsScreen(),
                'delete flow' => const Scaffold(
                    body: SafeArea(
                        child: SingleChildScrollView(
                            child: PrivacySettingsSection(dangerOnly: true)))),
                'consent' => Scaffold(
                    body: Builder(
                        builder: (context) => TextButton(
                            onPressed: () => ConsentDialog.show(context),
                            child: const Text('Open consent')))),
                _ => const Scaffold(body: SafeArea(child: IosSupportContact())),
              };
              await tester.pumpWidget(_app(provider, home, language, scale));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              expect(tester.takeException(), isNull);
              if (surface == 'welcome/sign-in') {
                expect(find.byType(SignInWithAppleButton), findsOneWidget);
                expect(find.byKey(const Key('welcome-signup')), findsOneWidget);
                await tester.ensureVisible(find.byType(SignInWithAppleButton));
                await tester.tap(find.byType(SignInWithAppleButton));
                await tester.pumpAndSettle();
                expect(find.text('auth_welcome.sign_in_failed'.tr()),
                    findsOneWidget);
                await tester.ensureVisible(find.byType(OutlinedButton));
                await tester.tap(find.byType(OutlinedButton));
                await tester.pumpAndSettle();
              } else if (surface == 'live/chat') {
                expect(
                    find.textContaining(_Chat.messageBody, findRichText: true),
                    findsOneWidget);
              } else if (surface == 'delete flow') {
                final delete = find.widgetWithText(
                    OutlinedButton, 'settings.delete_account_btn'.tr());
                await tester.ensureVisible(delete);
                await tester.tap(delete);
                await tester.pumpAndSettle();
                expect(find.text('settings.delete_account_confirm_body'.tr()),
                    findsOneWidget);
                await tester.tap(find.text('settings.cancel'.tr()));
                await tester.pumpAndSettle();
                await tester.tap(delete);
                await tester.pumpAndSettle();
                final confirm =
                    find.text('settings.delete_account_confirm_btn'.tr());
                await tester.ensureVisible(confirm);
                await tester.tap(confirm);
                await tester.pumpAndSettle();
                expect(find.byType(SnackBar), findsOneWidget);
              } else if (surface == 'consent') {
                await tester.tap(find.text('Open consent'));
                await tester.pumpAndSettle();
                expect(find.byType(ConsentDialog), findsOneWidget);
                await tester
                    .ensureVisible(find.text('consent.view_full_policy'.tr()));
                await tester.tap(find.text('consent.view_full_policy'.tr()));
                await tester.pumpAndSettle();
                expect(find.text('settings.view_privacy'.tr()), findsWidgets);
              } else if (surface == 'support') {
                TestDefaultBinaryMessengerBinding
                    .instance.defaultBinaryMessenger
                    .setMockMethodCallHandler(urlChannel, (_) async => false);
                await tester.tap(find.byKey(const Key('ios-support-contact')));
                await tester.pumpAndSettle();
                expect(find.text(AppIdentity.supportEmail), findsWidgets);
                expect(find.byType(AlertDialog), findsOneWidget);
              }
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              provider.dispose();
              flags.dispose();
              LiveBroadcastScreen.debugChatFactory = null;
              debugDefaultTargetPlatformOverride = null;
              tester.view.resetPadding();
              tester.view.resetViewPadding();
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            }
          });
        }
      }
    }
  }
}
