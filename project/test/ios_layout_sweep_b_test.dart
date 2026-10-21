import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/profile/presentation/widgets/viewer_profile_editor_dialog.dart';
import 'package:streamer_app/features/notifications/presentation/notification_center_sheet.dart';
import 'package:streamer_app/features/organization/presentation/organization_hub_screen.dart';
import 'package:streamer_app/features/organization/presentation/channel_connections_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/chat_message_actions_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPage;
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/widgets/ds/ca_navigation.dart';
import 'package:streamer_app/core/widgets/ds/ca_fields.dart';
import 'package:streamer_app/core/widgets/floating_stream_mini_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/core/providers/app_flags.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/providers/app_experience.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/profile/presentation/settings/privacy_settings_section.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures/streamer_fixtures.dart';
import 'fixtures/dialog_fixtures.dart';
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
  @override
  Future<void> loadYouTubeChannelData(
      {required String streamerId, required String handle}) async {
    setStreamerMediaForTests(streamerId,
        vods: speakerVodsFixture(), playlists: [playlistFixture()]);
  }
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
      child: MultiProvider(
          providers: [
            ChangeNotifierProvider<AppProvider>.value(value: provider),
            ChangeNotifierProvider<AppExperience>(create: (_) => AppExperience()),
          ],
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
      for (final path in font.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });
  final chromeCalls = <MethodCall>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    chromeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      chromeCalls.add(call);
      return null;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    debugDefaultTargetPlatformOverride = null;
    LiveBroadcastScreen.debugChatFactory = null;
  });
  const phones = [Size(375, 667), Size(393, 852), Size(430, 932)];
  final cases =
      <({String surface, Size size, double scale, bool keyboard, bool a11y})>[
    for (final size in [const Size(852, 393), const Size(932, 430)])
      for (final surface in ['live/chat', 'discovery', 'settings'])
        (
          surface: surface,
          size: size,
          scale: 1.0,
          keyboard: false,
          a11y: false
        ),
    for (final size in phones)
      for (final surface in [
        'welcome/sign-in',
        'live/chat',
        'search',
        'wizard 0',
        'wizard 2',
        'wizard 3'
      ])
        (surface: surface, size: size, scale: 1.0, keyboard: true, a11y: false),
    for (final size in phones)
      for (final scale in [2.0, 3.0])
        for (final surface in ['welcome/sign-in', 'settings', 'delete flow'])
          (
            surface: surface,
            size: size,
            scale: scale,
            keyboard: false,
            a11y: false
          ),
    for (final size in phones)
      for (final surface in [
        'studio notice',
        'channel notice',
        'publisher unavailable',
        'profile',
        'viewer profile',
        'notifications',
        'organization',
        'organization profile',
        'wizard 0',
        'wizard 1',
        'wizard 2',
        'wizard 3',
        'wizard 4'
      ])
        (
          surface: surface,
          size: size,
          scale: 1.5,
          keyboard: false,
          a11y: false
        ),
    for (final size in phones)
      for (final surface in [
        'welcome/sign-in',
        'chat actions',
        'settings',
        'delete flow'
      ])
        (surface: surface, size: size, scale: 1.0, keyboard: false, a11y: true),
  ];
  for (final language in ['en', 'ar']) {
    for (final c in cases) {
      testWidgets(
          'iOS B ${c.surface} ${c.size} $language text=${c.scale} keyboard=${c.keyboard} a11y=${c.a11y}',
          (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = c.size;
        tester.view.padding =
            FakeViewPadding(top: 59, bottom: c.keyboard ? 0 : 34);
        tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
        final provider = _Provider();
        final flags = AppFlags(store: _Flags());
        final chat = _Chat('stream_live_992');
        final semantics = c.a11y ? tester.ensureSemantics() : null;
        StubVideoPlayer.install(addTearDown: addTearDown);
        LiveBroadcastScreen.debugChatFactory = (id, _) => _Chat(id);
        try {
          provider.debugSetSignedInForTests(
              email: 'viewer@example.invalid',
              isStreamer: false,
              personalBroadcastApproved: true);
          await provider.recordConsent();
          for (final item in mockStreamers) {
            provider.addStreamerForTests(item.copyWith(
                avatarUrl: '', bannerUrl: '', isCurrentlyLive: false));
          }
          provider.addStreamerForTests(mockStreamers.first.copyWith(
              avatarUrl: '',
              bannerUrl: '',
              isCurrentlyLive: true,
              broadcastType: BroadcastType.liveVideo,
              activeStreamId: 'stream_live_992'));
          Widget home = switch (c.surface) {
            'welcome/sign-in' => WelcomeScreen(appFlags: flags),
            'discovery' || 'search' => const DiscoveryFeedScreen(),
            'live/chat' =>
              const LiveBroadcastScreen(streamId: 'stream_live_992'),
            'settings' => const SettingsScreen(),
            'delete flow' => const Scaffold(
                body: SafeArea(
                    child: SingleChildScrollView(
                        child: PrivacySettingsSection(dangerOnly: true)))),
            'profile' => BroadcasterProfileScreen(
                streamerId: mockStreamers.first.streamerId),
            'organization profile' => BroadcasterProfileScreen(
                streamerId: mockStreamers
                    .firstWhere((s) => s.affiliatedSpeakers.isNotEmpty)
                    .streamerId),
            'viewer profile' =>
              const Scaffold(body: ViewerProfileEditorDialog()),
            'notifications' => const Scaffold(body: NotificationCenterSheet()),
            'organization' => const OrganizationHubScreen(),
            'channel notice' => const ChannelConnectionsScreen(),
            'publisher unavailable' => const PhoneBroadcastScreen(
                autoStart: false,
                quickLaunchPreset: BroadcastQualityPreset.low),
            'studio notice' => Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () =>
                            LiveBroadcasterStudioSheet.show(context),
                        child: const Text('Open studio')))),
            'chat actions' => Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () => showChatMessageActionsSheet(context,
                            message: chat.messages.single, controller: chat),
                        child: const Text('Actions')))),
            _ => const StreamerApplyScreen(),
          };
          await tester.pumpWidget(_app(provider, home, language, c.scale));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          if (c.surface.startsWith('wizard')) {
            tester
                .widget<PageView>(find.byType(PageView))
                .controller!
                .jumpToPage(int.parse(c.surface.split(' ').last));
            await tester.pump();
          }
          if (c.keyboard) {
            if (c.surface != 'welcome/sign-in') {
              final fields = find.byType(EditableText);
              expect(fields, findsWidgets);
              // Exercise every text field, including the lower wizard fields.
              for (var index = 0; index < fields.evaluate().length; index++) {
                final finder = find.byType(EditableText).at(index);
                await tester.ensureVisible(finder);
                await tester.tap(finder);
                tester.view.viewInsets = const FakeViewPadding(bottom: 336);
                await tester.pump(const Duration(milliseconds: 400));
                expect(tester.takeException(), isNull);
                await tester.enterText(finder, 'Keyboard نص');
                await tester.pump(const Duration(milliseconds: 400));
                expect(tester.getRect(finder).bottom,
                    lessThanOrEqualTo(c.size.height - 336));
              }
            } else {
              tester.view.viewInsets = const FakeViewPadding(bottom: 336);
              await tester.pump(const Duration(milliseconds: 400));
              final apple = find.byType(SignInWithAppleButton);
              await tester.ensureVisible(apple);
              expect(tester.getRect(apple).bottom,
                  lessThanOrEqualTo(c.size.height - 336));
            }
          }
          if (c.surface == 'delete flow') {
            final button = find.widgetWithText(
                OutlinedButton, 'settings.delete_account_btn'.tr());
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.text('settings.delete_account_confirm_body'.tr()),
                findsOneWidget);
            await tester.ensureVisible(
                find.text('settings.delete_account_confirm_btn'.tr()));
          } else if (c.surface == 'studio notice' ||
              c.surface == 'chat actions') {
            await tester.tap(find.text(
                c.surface == 'studio notice' ? 'Open studio' : 'Actions'));
            await tester.pumpAndSettle();
            if (c.surface == 'studio notice') {
              expect(find.byType(FeatureInProgressModal), findsOneWidget);
            } else {
              expect(find.text('live.report_message'.tr()), findsOneWidget);
              expect(find.text('live.block_user'.tr()), findsOneWidget);
            }
          } else if (c.surface == 'channel notice') {
            final button = find.text('organization_v1.connect'.tr());
            await tester.ensureVisible(button);
            await tester.tap(button);
            await tester.pumpAndSettle();
            expect(find.byType(FeatureInProgressModal), findsOneWidget);
          } else if (c.surface == 'publisher unavailable') {
            expect(find.text('live.ios_publisher_unavailable'.tr()),
                findsOneWidget);
          } else if (c.surface == 'live/chat') {
            expect(find.textContaining(_Chat.messageBody, findRichText: true),
                findsOneWidget);
          }
          if (c.surface == 'profile' || c.surface == 'organization profile') {
            final id = c.surface == 'profile'
                ? mockStreamers.first.streamerId
                : mockStreamers
                    .firstWhere((s) => s.affiliatedSpeakers.isNotEmpty)
                    .streamerId;
            final follow = find.text('profile.follow_btn'.tr()).first;
            await tester.ensureVisible(follow);
            await tester.tap(follow);
            await tester.pumpAndSettle();
            expect(provider.followedStreamerIds, contains(id));
            final following = find.text('profile.following_btn'.tr()).first;
            await tester.ensureVisible(following);
            await tester.tap(following);
            await tester.pumpAndSettle();
            expect(provider.followedStreamerIds, isNot(contains(id)));
          }
          if (c.a11y) {
            Future<void> checkGuidelines() async {
              await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
              await expectLater(
                  tester, meetsGuideline(labeledTapTargetGuideline));
              await expectLater(tester, meetsGuideline(textContrastGuideline));
            }

            await checkGuidelines();
            if (c.surface == 'settings') {
              final scrollable = find
                  .descendant(
                      of: find.byType(ListView).first,
                      matching: find.byType(Scrollable))
                  .first;
              final position =
                  tester.state<ScrollableState>(scrollable).position;
              while (position.pixels < position.maxScrollExtent) {
                await tester.drag(
                    find.byType(ListView).first, const Offset(0, -350));
                await tester.pumpAndSettle();
                await checkGuidelines();
              }
            }
          }
          expect(tester.takeException(), isNull);
        } finally {
          semantics?.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          if (c.surface == 'live/chat') {
            final orientation = chromeCalls
                .lastWhere((call) =>
                    call.method == 'SystemChrome.setPreferredOrientations')
                .arguments;
            expect(
                orientation,
                containsAll([
                  'DeviceOrientation.portraitUp',
                  'DeviceOrientation.landscapeLeft',
                  'DeviceOrientation.landscapeRight'
                ]));
          }
          provider.dispose();
          flags.dispose();
          chat.dispose();
          debugDefaultTargetPlatformOverride = null;
          LiveBroadcastScreen.debugChatFactory = null;
          tester.view.resetViewInsets();
          tester.view.resetPadding();
          tester.view.resetViewPadding();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        }
      });
    }
    testWidgets('iOS route swipe-back $language preserves the feed stack',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = phones.first;
      final provider = _Provider()
        ..debugSetSignedInForTests(email: 'viewer@example.invalid');
      provider.addStreamerForTests(
          mockStreamers.first.copyWith(avatarUrl: '', bannerUrl: ''));
      final router = AppRouter.build(provider);
      try {
        await tester.pumpWidget(EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: Locale(language),
            saveLocale: false,
            path: 'assets/i18n',
            assetLoader: const DirectJsonAssetLoader(),
            child: ChangeNotifierProvider<AppProvider>.value(
                value: provider,
                child: Builder(
                    builder: (context) => MaterialApp.router(
                        theme: AppTheme.forLocale(context.locale),
                        locale: context.locale,
                        supportedLocales: context.supportedLocales,
                        localizationsDelegates: context.localizationDelegates,
                        builder: (context, child) => MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(disableAnimations: true),
                            child: child!),
                        routerConfig: router)))));
        router.go('/feed');
        await tester.pumpAndSettle();
        router.push('/profile/${mockStreamers.first.streamerId}');
        await tester.pumpAndSettle();
        final route = ModalRoute.of(
            tester.element(find.byType(BroadcasterProfileScreen)))!;
        expect(route.settings, isA<CupertinoPage<void>>());
        expect(route.popGestureEnabled, isTrue);
        final rtl = language == 'ar';
        await tester.dragFrom(
            Offset(rtl ? 374 : 1, 330), Offset(rtl ? -330 : 330, 0));
        await tester.pumpAndSettle();
        expect(find.byType(BroadcasterProfileScreen), findsNothing);
        expect(find.byType(DiscoveryFeedScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
    testWidgets('iOS return chip clears bottom navigation $language',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = phones.first;
      tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
      final provider = _Provider();
      provider.openMiniPlayer(
          videoId: 'mock',
          title: 'Title عنوان',
          streamerName: 'Name',
          streamId: 'room');
      try {
        await tester.pumpWidget(_app(
            provider,
            Scaffold(
                bottomNavigationBar: CaNavBar(index: 0, onChanged: (_) {}),
                body: const Stack(children: [FloatingStreamMiniPlayer()])),
            language,
            1.5));
        await tester.pumpAndSettle();
        final chip = find.byKey(const ValueKey('mini_player_return_chip'));
        await tester.drag(chip, const Offset(0, 1000));
        await tester.pumpAndSettle();
        expect(tester.getRect(chip).bottom,
            lessThanOrEqualTo(tester.getRect(find.byType(CaNavBar)).top));
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
        tester.view.resetPadding();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    });
    testWidgets('iOS text selection and outside keyboard dismissal $language',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = _Provider();
      final controller = TextEditingController(text: 'Selectable نص');
      final focus = FocusNode();
      try {
        await tester.pumpWidget(_app(
            provider,
            Scaffold(
                body: Column(children: [
              CaInput(label: 'Input', controller: controller, focusNode: focus),
              const SizedBox(height: 100),
              const Text('Outside'),
            ])),
            language,
            1));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(EditableText));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.text('Outside'));
        await tester.pumpAndSettle();
        expect(focus.hasFocus, isFalse);
        final field = tester.getRect(find.byType(EditableText));
        await tester.longPressAt(Offset(
            language == 'ar' ? field.right - 20 : field.left + 20,
            field.center.dy));
        await tester.pumpAndSettle();
        expect(controller.selection.isCollapsed, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        focus.dispose();
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
    testWidgets(
        'iOS CaInput related actions fire after outside dismissal $language',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = _Provider();
      final controller = TextEditingController(text: 'Saved نص');
      final focus = FocusNode();
      final actions = <String>[];
      try {
        await tester.pumpWidget(_app(
            provider,
            Scaffold(
                body: Builder(
                    builder: (context) => Column(children: [
                          CaInput(
                              label: 'Input',
                              controller: controller,
                              focusNode: focus,
                              trailing: IconButton(
                                  tooltip: 'Suffix',
                                  icon: const Icon(Icons.check),
                                  onPressed: () => actions
                                      .add('suffix:${controller.text}'))),
                          TextButton(
                              onPressed: () =>
                                  actions.add('submit:${controller.text}'),
                              child: const Text('Submit')),
                          IconButton(
                              tooltip: 'Add',
                              icon: const Icon(Icons.add),
                              onPressed: () =>
                                  actions.add('add:${controller.text}')),
                          TextButton(
                              onPressed: () {
                                actions.add('picker:${controller.text}');
                                showDialog<void>(
                                    context: context,
                                    builder: (_) => const AlertDialog(
                                        content: Text('Picker opened')));
                              },
                              child: const Text('Picker')),
                        ]))),
            language,
            1));
        await tester.pumpAndSettle();
        for (final action in ['Suffix', 'Submit', 'Add', 'Picker']) {
          await tester.tap(find.byType(EditableText));
          await tester.pump();
          await tester.tap(action == 'Suffix' || action == 'Add'
              ? find.byTooltip(action)
              : find.text(action));
          await tester.pumpAndSettle();
          expect(actions.last, '${action.toLowerCase()}:Saved نص');
          expect(focus.hasFocus, action == 'Suffix');
        }
        expect(find.text('Picker opened'), findsOneWidget);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        focus.dispose();
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
    testWidgets('Android CaInput outside touch retains focus $language',
        (tester) async {
      final provider = _Provider();
      final focus = FocusNode();
      try {
        await tester.pumpWidget(_app(
            provider,
            Scaffold(
                body: Column(children: [
              CaInput(label: 'Input', focusNode: focus),
              const SizedBox(height: 100),
              const Text('Outside'),
            ])),
            language,
            1));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(EditableText));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.text('Outside'));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        expect(tester.testTextInput.hasAnyClients, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        focus.dispose();
        provider.dispose();
      }
    });
    test('iOS app bars use legible system icons $language', () {
      expect(CaAppBar(backgroundColor: AppTheme.media).systemOverlayStyle,
          SystemUiOverlayStyle.light);
      expect(CaAppBar(backgroundColor: AppTheme.surface).systemOverlayStyle,
          SystemUiOverlayStyle.dark);
    });
    testWidgets('iOS dark back control overrides the light theme $language',
        (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = _Provider();
      try {
        await tester.pumpWidget(_app(
            provider,
            Scaffold(
              appBar: CaAppBar(
                  backgroundColor: AppTheme.media,
                  leading: BackButton(onPressed: () {})),
            ),
            language,
            1));
        await tester.pumpAndSettle();
        final iconContext = tester.element(find.byType(BackButtonIcon));
        expect(IconTheme.of(iconContext).color, Canopy.paper);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        provider.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
    for (final apple in [true, false]) {
      testWidgets(
          'restricted result $language apple=$apple shows relevant sentence',
          (tester) async {
        final provider = _Provider();
        try {
          await tester.pumpWidget(_app(
              provider,
              Scaffold(
                  body: Builder(
                      builder: (_) => Text(deleteAccountErrorText(apple
                          ? 'account_restricted_apple'
                          : 'account_restricted')))),
              language,
              1));
          await tester.pumpAndSettle();
          final text = tester.widget<Text>(find.byType(Text).last).data!;
          expect(text.contains('Apple'), apple);
          expect(
              text,
              startsWith('settings.delete_account_blocked_account_restricted'
                  .tr(namedArgs: {'email': AppIdentity.supportEmail})));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          provider.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
