import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';

/// P6.2. The composer must never invite a viewer to type into a box whose
/// insert the server is going to refuse, and must say which rule is in the way.
///
/// These assert the client contract -- the precedence of the rules, the
/// slow-mode countdown, and the retry policy for a refused send. The
/// server-side enforcement of each of those rules is covered by
/// `supabase/tests/chat_rate_limit.test.sql` (rate limit, slow mode, chat off)
/// and `supabase/tests/chat_keyword_filter.test.sql` (blocklist), which run
/// against a real database.
///
/// No Supabase is initialized here: that is deliberate, because a chat room on
/// an unconfigured build has to render read-only rather than throw, and
/// `composerState` is what decides that.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  LiveChatController signedIn({
    bool chatEnabled = true,
    int slowModeSeconds = 0,
    bool isSelfBanned = false,
    bool isSelfMuted = false,
    bool canModerate = false,
    ChatConnectionState connectionState = ChatConnectionState.live,
  }) {
    final c = LiveChatController(streamId: 'stream-1');
    c.debugSetStateForTests(
      currentUserId: 'user-1',
      chatEnabled: chatEnabled,
      slowModeSeconds: slowModeSeconds,
      isSelfBanned: isSelfBanned,
      isSelfMuted: isSelfMuted,
      canModerate: canModerate,
      connectionState: connectionState,
    );
    return c;
  }

  group('composer state', () {
    test('a signed-in viewer on a healthy connection can send', () {
      final c = signedIn();
      expect(c.composerState, ChatComposerState.ready);
      expect(c.canSend, isTrue);
      addTearDown(c.dispose);
    });

    test('a guest is read-only and is told to sign in', () {
      final c = LiveChatController(streamId: 'stream-1');
      c.debugSetStateForTests(currentUserId: null);
      expect(c.isGuest, isTrue);
      expect(c.composerState, ChatComposerState.guest);
      expect(c.canSend, isFalse);
      addTearDown(c.dispose);
    });

    test('an unconfigured Supabase build is a guest, not a crash', () {
      // No debug override at all: _currentUserId has to swallow the
      // Supabase.instance failure rather than propagate it.
      final c = LiveChatController(streamId: 'stream-1');
      expect(() => c.composerState, returnsNormally);
      expect(c.composerState, ChatComposerState.guest);
      addTearDown(c.dispose);
    });

    test('a banned account outranks every other reason', () {
      // Banned AND muted AND chat off AND offline AND slow mode: the account
      // is told the one thing that is actually true of it.
      final c = signedIn(
        isSelfBanned: true,
        isSelfMuted: true,
        chatEnabled: false,
        slowModeSeconds: 30,
        connectionState: ChatConnectionState.reconnecting,
      );
      expect(c.composerState, ChatComposerState.banned);
      addTearDown(c.dispose);
    });

    test('chat turned off blocks a viewer', () {
      final c = signedIn(chatEnabled: false);
      expect(c.composerState, ChatComposerState.chatDisabled);
      addTearDown(c.dispose);
    });

    test('chat turned off does not block a moderator', () {
      // The broadcaster must still be able to explain why chat is off.
      final c = signedIn(chatEnabled: false, canModerate: true);
      expect(c.composerState, ChatComposerState.ready);
      addTearDown(c.dispose);
    });

    test('a muted viewer is told they are muted', () {
      final c = signedIn(isSelfMuted: true);
      expect(c.composerState, ChatComposerState.muted);
      addTearDown(c.dispose);
    });

    test('a dropped connection holds sending', () {
      final c = signedIn(connectionState: ChatConnectionState.reconnecting);
      expect(c.composerState, ChatComposerState.offline);
      expect(c.canSend, isFalse);
      addTearDown(c.dispose);
    });

    test('still connecting also holds sending', () {
      final c = signedIn(connectionState: ChatConnectionState.connecting);
      expect(c.composerState, ChatComposerState.offline);
      addTearDown(c.dispose);
    });

    test('a guest on a broken connection is told to sign in, not to wait', () {
      final c = LiveChatController(streamId: 'stream-1');
      c.debugSetStateForTests(
        currentUserId: null,
        connectionState: ChatConnectionState.reconnecting,
      );
      expect(c.composerState, ChatComposerState.guest);
      addTearDown(c.dispose);
    });
  });

  group('slow mode countdown', () {
    ChatMessageModel own(DateTime at, {String id = 'm1'}) => ChatMessageModel(
          id: id,
          streamId: 'stream-1',
          senderId: 'user-1',
          senderName: 'Me',
          body: 'hi',
          createdAt: at,
          isCurrentUser: true,
        );

    test('no countdown before the viewer has sent anything', () {
      final c = signedIn(slowModeSeconds: 30);
      expect(c.slowModeSecondsRemaining, 0);
      expect(c.composerState, ChatComposerState.ready);
      addTearDown(c.dispose);
    });

    test('counts down from the viewer own last message', () {
      final c = signedIn(slowModeSeconds: 30);
      c.debugAddMessageForTests(
          own(DateTime.now().subtract(const Duration(seconds: 10))));
      expect(c.slowModeSecondsRemaining, inInclusiveRange(19, 20));
      expect(c.composerState, ChatComposerState.slowMode);
      addTearDown(c.dispose);
    });

    test('elapsed slow mode stops holding the composer', () {
      final c = signedIn(slowModeSeconds: 30);
      c.debugAddMessageForTests(
          own(DateTime.now().subtract(const Duration(seconds: 31))));
      expect(c.slowModeSecondsRemaining, 0);
      expect(c.composerState, ChatComposerState.ready);
      addTearDown(c.dispose);
    });

    test('slow mode never holds a moderator back', () {
      final c = signedIn(slowModeSeconds: 30, canModerate: true);
      c.debugAddMessageForTests(own(DateTime.now()));
      expect(c.slowModeSecondsRemaining, 0);
      expect(c.composerState, ChatComposerState.ready);
      addTearDown(c.dispose);
    });

    test('a failed message does not start the countdown', () {
      // It never reached the server, so it cannot have consumed the window.
      final c = signedIn(slowModeSeconds: 30);
      c.debugAddMessageForTests(
        own(DateTime.now(), id: 'failed-1').copyWith(isFailed: true),
      );
      expect(c.slowModeSecondsRemaining, 0);
      addTearDown(c.dispose);
    });

    test('a dropped connection outranks the countdown', () {
      final c = signedIn(
        slowModeSeconds: 30,
        connectionState: ChatConnectionState.reconnecting,
      );
      c.debugAddMessageForTests(own(DateTime.now()));
      expect(c.composerState, ChatComposerState.offline);
      addTearDown(c.dispose);
    });
  });

  group('refused send: what the viewer is told, and whether retry is offered',
      () {
    test('a banned keyword is not retryable -- it will be refused forever', () {
      final c = signedIn();
      final f = c.debugClassifyForTests(
          'PostgrestException: Message rejected: contains a banned keyword.');
      expect(f.retryable, isFalse);
      expect(f.message, contains("isn't allowed here"));
      addTearDown(c.dispose);
    });

    test('chat being off is not retryable', () {
      final c = signedIn();
      final f = c.debugClassifyForTests('Chat is turned off for this stream');
      expect(f.retryable, isFalse);
      addTearDown(c.dispose);
    });

    test('the rate limit is retryable', () {
      final c = signedIn();
      expect(c.debugClassifyForTests('Sending too fast').retryable, isTrue);
      expect(
        c.debugClassifyForTests('Too many messages in one minute').retryable,
        isTrue,
      );
      addTearDown(c.dispose);
    });

    test('an unrecognized failure is retryable', () {
      // A dropped socket or a timeout: retrying is the reasonable default.
      final c = signedIn();
      expect(
        c.debugClassifyForTests('SocketException: connection closed').retryable,
        isTrue,
      );
      addTearDown(c.dispose);
    });

    test('a failed message stays in the list so it is not silently lost', () {
      final c = signedIn();
      c.debugAddMessageForTests(
        ChatMessageModel(
          id: 'failed-1',
          streamId: 'stream-1',
          senderId: 'user-1',
          senderName: 'Me',
          body: 'this did not send',
          createdAt: DateTime.now(),
          isCurrentUser: true,
          isFailed: true,
          failureReason: 'Slow down a moment before sending again.',
        ),
        retryable: true,
      );
      expect(c.messages.single.body, 'this did not send');
      expect(c.messages.single.isFailed, isTrue);
      expect(c.isRetryable('failed-1'), isTrue);

      c.discardFailedMessage('failed-1');
      expect(c.messages, isEmpty);
      addTearDown(c.dispose);
    });

    test('discard does not remove a confirmed message', () {
      final c = signedIn();
      c.debugAddMessageForTests(ChatMessageModel(
        id: 'ok-1',
        streamId: 'stream-1',
        senderId: 'user-1',
        senderName: 'Me',
        body: 'this one sent',
        createdAt: DateTime.now(),
        isCurrentUser: true,
      ));
      c.discardFailedMessage('ok-1');
      expect(c.messages.single.id, 'ok-1');
      addTearDown(c.dispose);
    });

    test('a non-retryable message is not retried even if asked', () {
      final c = signedIn();
      c.debugAddMessageForTests(
        ChatMessageModel(
          id: 'kw-1',
          streamId: 'stream-1',
          senderId: 'user-1',
          senderName: 'Me',
          body: 'blocked words',
          createdAt: DateTime.now(),
          isCurrentUser: true,
          isFailed: true,
          failureReason: "Message blocked: that language isn't allowed here.",
        ),
        retryable: false,
      );
      expect(c.isRetryable('kw-1'), isFalse);
      // Returns without attempting an insert (which would throw here, since
      // Supabase is not initialized).
      expect(c.retryFailedMessage('kw-1'), completes);
      addTearDown(c.dispose);
    });
  });
}
