import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_feedback.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/chat_sender_profile_sheet.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';

class _Loader extends AssetLoader {
  const _Loader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync());
}

ChatMessageModel msg(String id, String sender, String name, String body,
        {Set<ChatSenderBadge> badges = const {}}) =>
    ChatMessageModel(
        id: id,
        streamId: 'room',
        senderId: sender,
        senderName: name,
        body: body,
        createdAt: DateTime(2026, 10, 5, 20, 30),
        badges: badges);

Widget host(Widget home, {String lang = 'en'}) => EasyLocalization(
      key: ValueKey(lang),
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const _Loader(),
      child: ChangeNotifierProvider<AppProvider>.value(
          value: AppProvider(AdminDatabaseService(null)),
          child: Builder(
              builder: (context) => MaterialApp(
                  locale: context.locale,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  theme: AppTheme.forLocale(context.locale),
                  home: Scaffold(body: home)))),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('a sender\'s ring follows the highest role they hold', () {
    expect(msg('1', 'a', 'A', 'x').chatRole, CaChatRole.viewer);
    expect(
        msg('1', 'a', 'A', 'x', badges: {ChatSenderBadge.moderator}).chatRole,
        CaChatRole.moderator);
    expect(
        msg('1', 'a', 'A', 'x',
                badges: {ChatSenderBadge.moderator, ChatSenderBadge.admin})
            .chatRole,
        CaChatRole.admin);
    expect(
        msg('1', 'a', 'A', 'x',
            badges: {ChatSenderBadge.admin, ChatSenderBadge.speaker}).chatRole,
        CaChatRole.broadcaster);
    expect(
        msg('1', 'a', 'A', 'x', badges: {ChatSenderBadge.organization})
            .chatRole,
        CaChatRole.broadcaster);
  });

  testWidgets('a long message shows two lines and an arrow that opens it',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final long = 'word ' * 60;
    await tester.pumpWidget(host(Column(children: [
      CaChatBubble(name: 'Reem', message: long.trim(), time: '8:30 PM'),
      const CaChatBubble(name: 'Mona', message: 'Short one', time: '8:31 PM'),
    ])));
    await tester.pumpAndSettle();
    // Only the long one has an arrow, and it points down.
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNothing);
    final collapsed = tester.getSize(find.byType(CaChatBubble).first).height;
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(CaChatBubble).first).height,
        greaterThan(collapsed));
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CaChatBubble).first).height, collapsed);
  });

  testWidgets('viewers show their name; admin, moderator and streamer do not',
      (tester) async {
    await tester.pumpWidget(host(const Column(children: [
      CaChatBubble(name: 'Reem', message: 'hello', time: ''),
      CaChatBubble(
          name: 'Sara', message: 'hi', time: '', role: CaChatRole.admin),
      CaChatBubble(
          name: 'Saud', message: 'hey', time: '', role: CaChatRole.moderator),
      CaChatBubble(
          name: 'Layla',
          message: 'welcome',
          time: '',
          role: CaChatRole.broadcaster),
    ])));
    // The live ring turns forever, so settle for a fixed time instead.
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Reem'), findsOneWidget);
    expect(find.textContaining('Sara'), findsNothing);
    expect(find.textContaining('Saud'), findsNothing);
    expect(find.textContaining('Layla'), findsNothing);
    // The role shows on the avatar: green, violet, and the live ring.
    final avatars = tester.widgetList<CaAvatar>(find.byType(CaAvatar)).toList();
    expect(avatars.map((a) => (a.ring, a.live)), [
      (CaAvatarRing.none, false),
      (CaAvatarRing.admin, false),
      (CaAvatarRing.moderator, false),
      (CaAvatarRing.none, true),
    ]);
  });

  testWidgets('the sender window lists their tag and this stream\'s messages',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chat = LiveChatController(streamId: 'room')
      ..debugSetStateForTests(currentUserId: 'self');
    final first = msg('1', 'mod', 'Saud', 'Slides are pinned',
        badges: {ChatSenderBadge.moderator});
    for (final m in [
      first,
      msg('2', 'other', 'Reem', 'Not by Saud'),
      msg('3', 'mod', 'Saud', 'Stay on topic please',
          badges: {ChatSenderBadge.moderator}),
    ]) {
      chat.debugAddMessageForTests(m);
    }
    await tester.pumpWidget(host(Builder(
        builder: (context) => TextButton(
            onPressed: () => showChatSenderProfile(context,
                message: first, controller: chat),
            child: const Text('open')))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    // The sheet's header texture loads asynchronously; give it fixed time.
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Saud'), findsOneWidget);
    expect(find.text('Moderator'), findsOneWidget);
    expect(find.text('Messages in this stream (2)'), findsOneWidget);
    expect(find.text('Slides are pinned'), findsOneWidget);
    expect(find.text('Stay on topic please'), findsOneWidget);
    expect(find.text('Not by Saud'), findsNothing);
  });
}
