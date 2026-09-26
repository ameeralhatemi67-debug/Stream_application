import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/chat_message_actions_sheet.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/live_chat_widget.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'support/localized_app.dart';

void main() {
  setUpAll(initializeTestLocalization);

  testWidgets('sender chat closes keyboard, preserves draft through rotation',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 915);
    addTearDown(tester.view.reset);
    final draft = TextEditingController();
    final sent = <String>[];
    await tester.pumpWidget(localizedApp(
        home: Scaffold(
            body: LiveChatWidget(
      messages: const [],
      connectionState: ChatConnectionState.live,
      textController: draft,
      onSendTextMessage: sent.add,
    ))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'keep this draft');
    expect(tester.testTextInput.isVisible, isTrue);
    tester.view.physicalSize = const Size(915, 412);
    tester.view.viewInsets = const FakeViewPadding(bottom: 240);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(draft.text, 'keep this draft');
    expect(sent, isEmpty);
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.physicalSize = const Size(412, 915);
    await tester.pumpAndSettle();
    expect(find.text('keep this draft'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    draft.dispose();
  });

  for (final moderate in [false, true]) {
    testWidgets(
        'message edit cannot open landscape keyboard (moderator=$moderate)',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(740, 320);
      addTearDown(tester.view.reset);
      final chat = LiveChatController(streamId: 'room');
      chat.debugSetStateForTests(currentUserId: 'self', canModerate: moderate);
      final own = ChatMessageModel(
          id: 'message',
          streamId: 'room',
          senderId: 'self',
          senderName: 'Me',
          body: 'original',
          createdAt: DateTime(2026),
          isCurrentUser: true);
      await tester.pumpWidget(localizedApp(
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showChatMessageActionsSheet(context,
                          message: own, controller: chat),
                      child: const Text('actions'))))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('live.edit_message'.tr()));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'edited draft');
      tester.view.physicalSize = const Size(740, 320);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpAndSettle();
      expect(find.text('edited draft'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      chat.dispose();
    });
  }
}
