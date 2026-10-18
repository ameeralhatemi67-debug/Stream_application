import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_fields.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

class _Chat extends LiveChatController {
  _Chat() : super(streamId: 'stream_live_992');

  @override
  Future<void> start() async {
    debugSetStateForTests(
        currentUserId: 'keyboard-viewer',
        chatEnabled: true,
        connectionState: ChatConnectionState.live);
    debugAddMessageForTests(ChatMessageModel(
        id: 'welcome',
        streamId: streamId,
        senderId: 'other',
        senderName: 'Host',
        body: 'Welcome',
        createdAt: DateTime(2026, 10, 18)));
  }

  @override
  Future<void> sendMessage(String body) async {
    debugAddMessageForTests(ChatMessageModel(
        id: 'sent-${messages.length}',
        streamId: streamId,
        senderId: 'keyboard-viewer',
        senderName: 'Viewer',
        body: body,
        createdAt: DateTime(2026, 10, 18)));
  }

  @override
  Future<void> sendReaction(String type) async {}
}

Widget _app(AppProvider provider, Widget home, String language) =>
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
                    // Freeze decorative live pulses so pumpAndSettle can test input lifecycle.
                    builder: (context, child) => TickerMode(
                        enabled: false,
                        child: MediaQuery(
                            data: MediaQuery.of(context)
                                .copyWith(disableAnimations: true),
                            child: child!)),
                    home: home))));

Future<_Chat> _room(
    WidgetTester tester, AppProvider provider, String language) async {
  StubVideoPlayer.install(addTearDown: addTearDown);
  final chat = _Chat();
  LiveBroadcastScreen.debugChatFactory = (id, provider) => chat;
  provider.debugSetSignedInForTests(
      email: 'viewer@example.invalid', isStreamer: false);
  await provider.recordConsent();
  provider.addStreamerForTests(mockStreamers.first.copyWith(
      avatarUrl: '',
      bannerUrl: '',
      isCurrentlyLive: true,
      broadcastType: BroadcastType.liveVideo,
      activeStreamId: 'stream_live_992'));
  await tester.pumpWidget(_app(provider,
      const LiveBroadcastScreen(streamId: 'stream_live_992'), language));
  await tester.pumpAndSettle(const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
  return chat;
}

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    LiveBroadcastScreen.debugChatFactory = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final platform in [null, TargetPlatform.iOS]) {
    for (final language in ['en', 'ar']) {
      for (final action in ['Send', 'reaction', 'hand', 'outside', 'drag']) {
        testWidgets('composer $action ${platform ?? "Android"} $language',
            (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(430, 932);
          final provider = AppProvider();
          try {
            final chat = await _room(tester, provider, language);
            final field = find.byType(EditableText);
            await tester.tap(field);
            await tester.pump();
            final focus = tester.widget<EditableText>(field).focusNode;
            expect(focus.hasFocus, isTrue);
            expect(tester.testTextInput.hasAnyClients, isTrue);
            if (action == 'Send') {
              tester.testTextInput.enterText('Message مرحبا');
              await tester.pump();
              await tester.tap(find.byTooltip('live.send'.tr()));
              await tester.pump();
              expect(chat.messages.last.body, 'Message مرحبا');
              expect(find.textContaining('Message مرحبا', findRichText: true),
                  findsOneWidget);
            } else if (action == 'reaction') {
              final menu = find.byTooltip('live.reaction_menu_tooltip'.tr());
              expect(find.text('❤️'), findsNothing);
              await tester.tap(menu);
              await tester.pump();
              expect(find.text('❤️'), findsOneWidget);
            } else if (action == 'hand') {
              final hand = find.byTooltip('live.raise_hand_toggle'.tr());
              final before = tester
                  .widget<Icon>(
                      find.descendant(of: hand, matching: find.byType(Icon)))
                  .color;
              await tester.tap(hand);
              await tester.pump();
              expect(chat.messages.length, 2);
              expect(
                  find.textContaining('live.hand_raised_message'.tr(),
                      findRichText: true),
                  findsOneWidget);
              expect(
                  tester
                      .widget<Icon>(find.descendant(
                          of: hand, matching: find.byType(Icon)))
                      .color,
                  isNot(before));
            } else {
              final list = find.byType(ListView);
              // The welcome row is at the bottom of this reversed list.
              final blank =
                  tester.getRect(list).topCenter + const Offset(0, 10);
              if (action == 'outside') {
                await tester.tapAt(blank);
              } else {
                await tester.dragFrom(blank, const Offset(0, 60));
              }
              await tester.pump();
            }
            final keepFocus = action != 'drag' &&
                !(action == 'outside' && platform == TargetPlatform.iOS);
            expect(focus.hasFocus, keepFocus, reason: 'focus after $action');
            expect(tester.testTextInput.hasAnyClients, keepFocus);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            provider.dispose();
            tester.view.resetViewInsets();
            tester.view.resetPadding();
            tester.view.resetViewPadding();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
      for (final size in [const Size(375, 667), const Size(430, 932)]) {
        testWidgets(
            'keyboard connection ${platform ?? "Android"} $language $size',
            (tester) async {
          debugDefaultTargetPlatformOverride = platform;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = const FakeViewPadding(top: 59);
          tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
          final provider = AppProvider();
          try {
            await _room(tester, provider, language);
            final field = find.byType(EditableText);
            await tester.tap(field);
            await tester.pumpAndSettle(const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
            final focus = tester.widget<EditableText>(field).focusNode;
            expect(tester.testTextInput.hasAnyClients, isTrue);
            tester.view.viewInsets = const FakeViewPadding(bottom: 336);
            for (var frame = 0; frame < 4; frame++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            await tester.pumpAndSettle(const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
            expect(tester.testTextInput.hasAnyClients, isTrue,
                reason:
                    'Opening the keyboard must retain the attached input client');
            expect(tester.testTextInput.isVisible, isTrue);
            expect(focus.hasFocus, isTrue);
            final log = tester.testTextInput.log;
            final firstShow =
                log.indexWhere((call) => call.method == 'TextInput.show');
            expect(firstShow, greaterThanOrEqualTo(0));
            expect(
                log.skip(firstShow + 1).map((call) => call.method),
                isNot(anyElement(
                    isIn(['TextInput.hide', 'TextInput.clearClient']))));
            // Do not use tester.enterText/showKeyboard: they would repair a lost client.
            tester.testTextInput.enterText('مرحبا hi');
            await tester.pump();
            await tester.tap(find.byTooltip('live.send'.tr()));
            await tester.pumpAndSettle(const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
            expect(find.textContaining('مرحبا hi', findRichText: true),
                findsOneWidget);
            expect(tester.getRect(field).bottom,
                lessThanOrEqualTo(size.height - 336));
            expect(tester.getRect(find.byType(TextFieldTapRegion).first).bottom,
                lessThanOrEqualTo(size.height - 336));
            tester.view.viewInsets = const FakeViewPadding();
            await tester.pumpAndSettle(const Duration(milliseconds: 100),
                EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
            expect(find.byType(CaSegmentedTabs).hitTestable(), findsOneWidget);
            expect(
                find
                    .text(mockStreamers.first.getLocalizedName(language))
                    .hitTestable(),
                findsWidgets);
            expect(tester.takeException(), isNull);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            provider.dispose();
            tester.view.resetViewInsets();
            tester.view.resetPadding();
            tester.view.resetViewPadding();
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  }
}
