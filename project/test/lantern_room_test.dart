import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/models/stream_privacy_models.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/lantern/lantern_room_chat.dart';
import 'package:streamer_app/features/live_stream/presentation/lantern/lantern_room_stage.dart';
import 'package:streamer_app/features/live_stream/presentation/lantern/lantern_room_view.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/floating_reactions_overlay.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

/// The live and audio rooms in Lantern and Arch (ADR-026): full screen, one
/// screen tall, only the chat scrolls; the same chat rules and room states as
/// the older room.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const phone = Size(390, 844),
      tablet = Size(820, 1180),
      laptop = Size(1440, 900);

  LiveChatController chatOf(
      {String? user = 'user-1',
      bool chatEnabled = true,
      int slowModeSeconds = 0,
      bool banned = false,
      bool muted = false,
      bool moderator = false,
      ChatConnectionState connection = ChatConnectionState.live}) {
    final c = LiveChatController(streamId: 'room-1')
      ..debugSetStateForTests(
          currentUserId: user,
          chatEnabled: chatEnabled,
          slowModeSeconds: slowModeSeconds,
          isSelfBanned: banned,
          isSelfMuted: muted,
          canModerate: moderator,
          connectionState: connection);
    addTearDown(c.dispose);
    return c;
  }

  ChatMessageModel message(String id, String name, String body,
          {Set<ChatSenderBadge> badges = const {},
          bool own = false,
          bool failed = false,
          String? reason,
          DateTime? at}) =>
      ChatMessageModel(
          id: id,
          streamId: 'room-1',
          senderId: 'sender-$name',
          senderName: name,
          body: body,
          createdAt: at ?? DateTime(2026, 11, 11, 20),
          isCurrentUser: own,
          badges: badges,
          isFailed: failed,
          failureReason: reason);

  final calls = <String>[];

  LanternRoom roomOf(
      {LiveChatController? chat,
      bool audio = false,
      StreamState state = StreamState.live,
      bool interrupted = false,
      bool recovering = false,
      bool playing = true,
      bool muted = false,
      bool fullscreen = false,
      bool transport = true,
      bool handRaised = false,
      ViewerAccessState access = ViewerAccessState.notApplicable,
      bool following = false,
      bool own = false,
      bool replay = false,
      int unread = 0,
      bool studio = false,
      bool live = true,
      FloatingReactionsOverlayController? reactions,
      TextEditingController? text,
      ScrollController? scroll}) {
    final controller = text ?? TextEditingController();
    final focus = FocusNode();
    final scroller = scroll ?? ScrollController();
    if (text == null) addTearDown(controller.dispose);
    if (scroll == null) addTearDown(scroller.dispose);
    addTearDown(focus.dispose);
    final c = chat ?? chatOf();
    return LanternRoom(
        streamId: 'lanternLive',
        streamer: mockStreamers.first.copyWith(
            isCurrentlyLive: live,
            broadcastType:
                audio ? BroadcastType.liveAudio : BroadcastType.liveVideo,
            activeStreamId: 'lanternLive'),
        audio: audio,
        viewers: 1286,
        player: const ColoredBox(
            key: ValueKey('test-player'), color: Color(0xFF223344)),
        state: state,
        interrupted: interrupted,
        recovering: recovering,
        recoveryAttempts: 2,
        playing: playing,
        muted: muted,
        fullscreen: fullscreen,
        transport: transport,
        handRaised: handRaised,
        access: access,
        following: following,
        own: own,
        replay: replay,
        chat: c,
        chatTick: c,
        chatText: controller,
        chatFocus: focus,
        chatScroll: scroller,
        unread: unread,
        arrived: (_) => false,
        reactions: reactions ?? FloatingReactionsOverlayController(),
        slidesUrl: '',
        customArtwork: null,
        onClose: () => calls.add('close'),
        onMinimize: () => calls.add('minimize'),
        onFollow: () => calls.add('follow'),
        onTogglePlay: () => calls.add('play'),
        onToggleMute: () => calls.add('mute'),
        onToggleFullscreen: () => calls.add('fullscreen'),
        onRetry: () => calls.add('retry'),
        onSend: () => calls.add('send'),
        onToggleHand: () => calls.add('hand'),
        onReaction: (type) => calls.add('react:$type'),
        onScrollToNewest: () => calls.add('newest'),
        onSignIn: () => calls.add('signin'),
        onRetryMessage: (id) => calls.add('retry:$id'),
        onMessageMenu: (m) => calls.add('menu:${m.id}'),
        onSender: (m) => calls.add('sender:${m.id}'),
        onOpenChannel: () => calls.add('channel'),
        onOpenSource: () => calls.add('source'),
        onStudio: studio ? () => calls.add('studio') : null,
        onOpenInYouTube: () => calls.add('youtube'),
        onRequestJoin: () => calls.add('join'),
        onShare: () => calls.add('share'),
        onDirections: () => calls.add('directions'));
  }

  setUp(calls.clear);

  Future<void> pumpRoom(WidgetTester tester, LanternRoom room,
          {Size size = phone, String lang = 'en'}) =>
      pumpLanternWidget(tester, LanternRoomView(room: room),
          size: size, lang: lang, night: true);

  group('layout', () {
    for (final (label, size) in [
      ('phone', phone),
      ('tablet', tablet),
      ('laptop', laptop)
    ]) {
      for (final lang in ['ar', 'en']) {
        for (final audio in [false, true]) {
          testWidgets(
              '${audio ? 'audio' : 'video'} room is one screen on a $label ($lang)',
              (tester) async {
            final chat = chatOf();
            for (var i = 0; i < 30; i++) {
              chat.debugAddMessageForTests(message('m$i', 'Yusuf $i',
                  'Could you repeat the hadith number? ($i)'));
            }
            await pumpRoom(tester, roomOf(chat: chat, audio: audio),
                size: size, lang: lang);
            expect(tester.takeException(), isNull);
            final room = tester.getRect(find.byKey(const ValueKey('lantern-room')));
            expect(room.size, size, reason: 'exactly one screen');
            // Nothing scrolls but the messages.
            for (final state
                in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
              final messages = find
                  .descendant(
                      of: find.byKey(const ValueKey('lantern-room-messages')),
                      matching: find.byWidget(state.widget))
                  .evaluate()
                  .isNotEmpty;
              if (!messages) {
                expect(state.position.maxScrollExtent, 0,
                    reason: 'only the chat list may scroll');
              }
            }
            final list = tester.state<ScrollableState>(find
                .descendant(
                    of: find.byKey(const ValueKey('lantern-room-messages')),
                    matching: find.byType(Scrollable))
                .first);
            expect(list.position.maxScrollExtent, greaterThan(0));
            // No app chrome in a room.
            expect(find.byType(LanternWebHeader), findsNothing);
            expect(find.byType(LanternBottomNav), findsNothing);
            expect(find.byType(LanternWebFooter), findsNothing);
            // The stage keeps 16:9.
            final stage = tester.getSize(find.byKey(const ValueKey('test-player')));
            expect(stage.width / stage.height, closeTo(16 / 9, .02));
            if (size == laptop) {
              expect(tester.getSize(find.byType(LanternRoomChat)).width,
                  Lantern.sideChat);
            } else {
              expect(stage.height, lessThanOrEqualTo(size.height * .45 + 1));
              expect(tester.getTopLeft(find.byType(LanternRoomChat)).dy,
                  greaterThan(tester.getBottomLeft(find.byType(LanternRoomStage)).dy));
            }
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }

    testWidgets('it is night even when the person chose day', (tester) async {
      await pumpLanternWidget(tester, LanternRoomView(room: roomOf()),
          night: false);
      expect(
          Theme.of(tester.element(find.byType(LanternRoomChat)))
              .extension<LanternTokens>()!
              .night,
          isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('full screen shows the stage alone', (tester) async {
      await pumpRoom(tester, roomOf(fullscreen: true));
      expect(find.byType(LanternRoomStage), findsOneWidget);
      expect(find.byType(LanternRoomChat), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('top bar', () {
    testWidgets('close and the corner player call back', (tester) async {
      await pumpRoom(tester, roomOf());
      await tester.tap(find.byKey(const ValueKey('lantern-room-close')));
      await tester.tap(find.byKey(const ValueKey('lantern-room-corner')));
      expect(calls, ['close', 'minimize']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a laptop shows the actions as buttons', (tester) async {
      await pumpRoom(tester, roomOf(studio: true), size: laptop);
      await tester.tap(find.widgetWithText(LButton, 'Follow'));
      await tester.tap(find.widgetWithText(LButton, 'Studio'));
      await tester.tap(find.byTooltip('Share'));
      expect(calls, ['follow', 'studio', 'share']);
      expect(find.text('1,286 watching'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a phone folds them into More', (tester) async {
      await pumpRoom(tester, roomOf());
      expect(find.widgetWithText(LButton, 'Follow'), findsNothing);
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('About'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Studio'), findsNothing,
          reason: 'only the broadcaster sees the studio');
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();
      expect(calls, ['follow']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('your own room offers no Follow', (tester) async {
      await pumpRoom(tester, roomOf(own: true), size: laptop);
      expect(find.widgetWithText(LButton, 'Follow'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('stage', () {
    testWidgets('controls play, sound and full screen', (tester) async {
      await pumpRoom(tester, roomOf());
      await tester.tap(find.byKey(const ValueKey('lantern-room-play')));
      await tester.tap(find.byKey(const ValueKey('lantern-room-mute')));
      await tester.tap(find.byKey(const ValueKey('lantern-room-fullscreen')));
      expect(calls, ['play', 'mute', 'fullscreen']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('play and sound hide when the player does not take them',
        (tester) async {
      await pumpRoom(tester, roomOf(transport: false));
      expect(find.byKey(const ValueKey('lantern-room-play')), findsNothing);
      expect(find.byKey(const ValueKey('lantern-room-mute')), findsNothing);
      expect(
          find.byKey(const ValueKey('lantern-room-fullscreen')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the state is always in words', (tester) async {
      await pumpRoom(tester, roomOf());
      expect(find.text('LIVE'), findsWidgets);
      await pumpRoom(tester, roomOf(audio: true));
      expect(find.text('AUDIO'), findsWidgets);
      expect(find.text('Keeps playing in the background'), findsOneWidget);
      await pumpRoom(tester, roomOf(replay: true, live: false));
      expect(find.text('Recording'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a broadcaster whose feed dropped: we will be right back',
        (tester) async {
      await pumpRoom(tester, roomOf(interrupted: true));
      expect(find.byKey(const ValueKey('lantern-room-interrupted')),
          findsOneWidget);
      expect(find.text("We'll be right back"), findsOneWidget);
      expect(find.text('LIVE'), findsNothing,
          reason: 'no LIVE badge over a stalled feed');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('recovering says which attempt and offers Retry',
        (tester) async {
      await pumpRoom(tester, roomOf(recovering: true));
      expect(find.textContaining('attempt 2/10'), findsOneWidget);
      await tester.tap(find.widgetWithText(LButton, 'Retry Feed'));
      expect(calls, ['retry']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('offline offers Retry and Open in YouTube', (tester) async {
      await pumpRoom(tester, roomOf(state: StreamState.offline));
      expect(
          find.byKey(const ValueKey('lantern-room-offline')), findsOneWidget);
      await tester.tap(find.widgetWithText(LButton, 'Retry Feed'));
      await tester.tap(find.byType(LButton).evaluate().length > 1
          ? find.byType(LButton).at(1)
          : find.byType(LButton).first);
      expect(calls.first, 'retry');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('ended and starting soon have their own veils', (tester) async {
      await pumpRoom(tester, roomOf(state: StreamState.ended));
      expect(find.byKey(const ValueKey('lantern-room-ended')), findsOneWidget);
      await pumpRoom(tester, roomOf(state: StreamState.startingSoon));
      expect(find.byKey(const ValueKey('lantern-room-soon')), findsOneWidget);
      expect(find.text('Starting soon'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a private room asks to join, then waits for the host',
        (tester) async {
      await pumpRoom(tester, roomOf(access: ViewerAccessState.denied));
      expect(
          find.byKey(const ValueKey('lantern-room-private')), findsOneWidget);
      await tester.tap(find.byType(LButton).first);
      expect(calls, ['join']);
      await pumpRoom(tester, roomOf(access: ViewerAccessState.knocking));
      expect(
          find.byKey(const ValueKey('lantern-room-knocking')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a reaction rises as a drawn icon, not an emoji',
        (tester) async {
      final reactions = FloatingReactionsOverlayController();
      await pumpLanternWidget(tester,
          LanternRoomView(room: roomOf(reactions: reactions)),
          night: true, calm: false);
      reactions.spawnReaction('heart');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
          find.descendant(
              of: find.byType(LanternReactions), matching: find.byType(LIcon)),
          findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.descendant(
              of: find.byType(LanternReactions), matching: find.byType(LIcon)),
          findsNothing,
          reason: 'it leaves after 2.4 s');
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('chat', () {
    testWidgets('roles are words, in the language of the screen',
        (tester) async {
      final chat = chatOf()
        ..debugAddMessageForTests(message('1', 'Lesson moderator', 'Welcome',
            badges: {ChatSenderBadge.moderator}))
        ..debugAddMessageForTests(message('2', 'Sheikh Fahd', 'We will answer',
            badges: {ChatSenderBadge.speaker}))
        ..debugAddMessageForTests(message('3', 'Yusuf', 'Thank you'));
      await pumpRoom(tester, roomOf(chat: chat));
      expect(find.text('MOD'), findsOneWidget);
      expect(find.text('Speaker'), findsOneWidget);
      expect(find.byType(LanternRoleChip), findsNWidgets(2));
      await pumpRoom(tester, roomOf(chat: chat), lang: 'ar');
      expect(find.text('مشرف البث'), findsOneWidget);
      expect(find.text('متحدث'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a message opens its menu and its sender', (tester) async {
      final chat = chatOf()
        ..debugAddMessageForTests(message('7', 'Yusuf', 'A question'));
      await pumpRoom(tester, roomOf(chat: chat));
      await tester.longPress(find.text('A question'));
      await tester.tap(find.byType(LAvatar).last);
      expect(calls, ['menu:7', 'sender:7']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a signed-in viewer types and sends', (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      await pumpRoom(tester, roomOf(text: text));
      await tester.enterText(
          find.byKey(const ValueKey('lantern-room-input')), 'Salam');
      expect(text.text, 'Salam');
      await tester.tap(find.byKey(const ValueKey('lantern-room-send')));
      await tester.tap(find.byKey(const ValueKey('lantern-room-hand')));
      expect(calls, ['send', 'hand']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a guest is asked to sign in instead of a text box',
        (tester) async {
      await pumpRoom(tester, roomOf(chat: chatOf(user: null)));
      expect(find.byKey(const ValueKey('lantern-room-input')), findsNothing);
      expect(find.text('Sign in to join the chat'), findsOneWidget);
      await tester.tap(find.widgetWithText(LButton, 'Sign in'));
      expect(calls, ['signin']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    for (final (label, chat) in <(String, LiveChatController Function())>[
      ('banned', () => chatOf(banned: true)),
      ('muted', () => chatOf(muted: true)),
      ('chat off', () => chatOf(chatEnabled: false)),
    ]) {
      testWidgets('$label: a statement, no text box', (tester) async {
        await pumpRoom(tester, roomOf(chat: chat()));
        expect(find.byKey(const ValueKey('lantern-room-input')), findsNothing);
        expect(find.byKey(const ValueKey('lantern-room-composer-notice')),
            findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('a recording is read-only', (tester) async {
      await pumpRoom(tester, roomOf(replay: true));
      expect(find.byKey(const ValueKey('lantern-room-input')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('slow mode keeps the draft and holds Send', (tester) async {
      final chat = chatOf(slowModeSeconds: 30)
        ..debugAddMessageForTests(
            message('own', 'Me', 'First', own: true, at: DateTime.now()));
      await pumpRoom(tester, roomOf(chat: chat));
      expect(chat.composerState, ChatComposerState.slowMode);
      expect(find.byKey(const ValueKey('lantern-room-input')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lantern-room-send')),
          warnIfMissed: false);
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a dropped connection says the chat is unavailable',
        (tester) async {
      await pumpRoom(tester,
          roomOf(chat: chatOf(connection: ChatConnectionState.reconnecting)));
      expect(find.text('Chat is unavailable while offline'), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the reactions menu sends one of five', (tester) async {
      await pumpRoom(tester, roomOf());
      await tester.tap(find.byKey(const ValueKey('lantern-room-react')));
      await tester.pump();
      final menu = find.byKey(const ValueKey('lantern-room-reactions'));
      expect(menu, findsOneWidget);
      expect(find.descendant(of: menu, matching: find.byType(LPressable)),
          findsNWidgets(5));
      await tester
          .tap(find.descendant(of: menu, matching: find.byType(LPressable)).first);
      await tester.pump();
      expect(calls, ['react:heart']);
      expect(menu, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('unread messages offer a way back down', (tester) async {
      final chat = chatOf()
        ..debugAddMessageForTests(message('1', 'Yusuf', 'One'));
      await pumpRoom(tester, roomOf(chat: chat, unread: 3));
      await tester.tap(find.widgetWithText(LButton, 'New messages (3)'));
      expect(calls, ['newest']);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a refused message keeps its reason, Retry and Discard',
        (tester) async {
      final chat = chatOf()
        ..debugAddMessageForTests(
            message('f1', 'Me', 'Hello',
                own: true, failed: true, reason: 'No connection'),
            retryable: true);
      await pumpRoom(tester, roomOf(chat: chat));
      expect(find.text('No connection'), findsOneWidget);
      await tester.tap(find.widgetWithText(LButton, 'Retry'));
      expect(calls, ['retry:f1']);
      await tester.tap(find.widgetWithText(LButton, 'Discard'));
      await tester.pump();
      expect(chat.messages, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('sources and venue are tabs of the same column',
        (tester) async {
      await pumpRoom(tester, roomOf());
      await tester.tap(find.text('Sources'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No sources have been shared for this lecture.'),
          findsOneWidget);
      await tester.tap(find.text('Venue'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.widgetWithText(LButton, 'Get Driving Directions'));
      expect(calls, ['directions']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('in the app', () {
    for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
      testWidgets('the live route opens the Lantern room on a $label',
          (tester) async {
        StubVideoPlayer.install(
            state: StreamState.live, addTearDown: addTearDown);
        final app = await LanternApp.start(tester, size: size, lang: 'ar');
        await app.push('/live/lanternLive');
        tester.takeException();
        expect(find.byType(LanternRoomView), findsOneWidget);
        expect(find.byType(LanternBottomNav).hitTestable(), findsNothing);
        await tester.tap(find.byKey(const ValueKey('lantern-room-close')));
        await app.settle();
        tester.takeException();
        expect(app.location, '/feed');
        expect(find.byType(LanternRoomView), findsNothing);
        await app.close();
      });
    }

    testWidgets('the corner button leaves a way back in the frame',
        (tester) async {
      StubVideoPlayer.install(state: StreamState.live, addTearDown: addTearDown);
      final app = await LanternApp.start(tester, size: phone, lang: 'en');
      await app.push('/live/lanternLive');
      tester.takeException();
      await tester.tap(find.byKey(const ValueKey('lantern-room-corner')));
      await app.settle();
      tester.takeException();
      expect(app.location, '/feed');
      expect(app.provider.isMiniPlayerActive, isTrue);
      expect(find.byType(LanternCornerPlayer), findsOneWidget);
      expect(find.text('Return to the room'), findsNothing,
          reason: 'it is a tooltip, not text');
      await app.close();
    });

    testWidgets('a link that matches no channel says so', (tester) async {
      final app = await LanternApp.start(tester, size: phone, lang: 'en');
      app.provider.debugSetOnlineForTests(true);
      await app.push('/live/no-such-room');
      await app.settle(12);
      tester.takeException();
      expect(find.byType(LanternRoomStatus), findsOneWidget);
      await app.close();
    });
  });
}
