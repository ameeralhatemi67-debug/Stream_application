import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/features/live_stream/models/chat_message_model.dart';
import 'package:streamer_app/features/live_stream/services/chat_block_list.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/profile/presentation/settings/blocked_accounts_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/localized_app.dart';

/// P6 client side of `chat_user_blocks`. The server rules themselves (own-row
/// policies, the restrictive message-read policy) are covered by
/// `supabase/tests/chat_blocks_and_app_flags.test.sql`; these assert that the
/// client treats the server as the only source of truth.
class FakeBlockStore implements ChatBlockStore {
  FakeBlockStore({this.currentUserId = 'me'});

  @override
  String? currentUserId;

  /// blocker -> blocked ids, standing in for the server table.
  final Map<String, Set<String>> rows = {};
  Object? fetchError;
  Object? insertError;
  Object? deleteError;
  final Map<String, String> names = {};
  int inserts = 0;

  @override
  Future<Set<String>> fetchBlockedIds(String blockerId) async {
    if (fetchError != null) throw fetchError!;
    return {...?rows[blockerId]};
  }

  @override
  Future<void> insertBlock(String blockerId, String blockedId) async {
    inserts++;
    if (insertError != null) throw insertError!;
    final set = rows.putIfAbsent(blockerId, () => {});
    if (!set.add(blockedId)) {
      throw const PostgrestException(message: 'duplicate key', code: '23505');
    }
  }

  @override
  Future<void> deleteBlock(String blockerId, String blockedId) async {
    if (deleteError != null) throw deleteError!;
    rows[blockerId]?.remove(blockedId);
  }

  @override
  Future<Map<String, String>> resolveNames(List<String> profileIds) async =>
      {for (final id in profileIds) if (names[id] != null) id: names[id]!};
}

ChatMessageModel msg(String id, String sender) => ChatMessageModel(
      id: id,
      streamId: 'stream-1',
      senderId: sender,
      senderName: sender,
      body: 'hi $id',
      createdAt: DateTime(2026, 9, 23),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ChatBlockList', () {
    test('refresh replaces local state with the server rows', () async {
      final store = FakeBlockStore()..rows['me'] = {'a', 'b'};
      final list = ChatBlockList(store: store);
      await list.refresh();
      expect(list.blockedIds, {'a', 'b'});
      expect(list.isStale, isFalse);

      // Unblocked on another device: the next refresh drops it here too.
      store.rows['me']!.remove('a');
      await list.refresh();
      expect(list.blockedIds, {'b'});
    });

    test('a refused block leaves the sender visible', () async {
      final store = FakeBlockStore()
        ..insertError = const PostgrestException(
            message: 'new row violates row-level security policy',
            code: '42501');
      final list = ChatBlockList(store: store);
      await expectLater(
        list.block('a'),
        throwsA(isA<ChatBlockException>().having(
            (e) => e.failure, 'failure', ChatBlockFailure.notPermitted)),
      );
      expect(list.isBlocked('a'), isFalse);
    });

    test('network, deleted-target and signed-out failures are distinct',
        () async {
      final store = FakeBlockStore()..insertError = Exception('socket');
      final list = ChatBlockList(store: store);
      await expectLater(
          list.block('a'),
          throwsA(isA<ChatBlockException>().having(
              (e) => e.failure, 'failure', ChatBlockFailure.network)));

      store.insertError =
          const PostgrestException(message: 'fk', code: '23503');
      await expectLater(
          list.block('a'),
          throwsA(isA<ChatBlockException>().having(
              (e) => e.failure, 'failure', ChatBlockFailure.targetGone)));

      store.currentUserId = null;
      await expectLater(
          list.block('a'),
          throwsA(isA<ChatBlockException>().having(
              (e) => e.failure, 'failure', ChatBlockFailure.signedOut)));
    });

    test('a block the server already holds counts as success', () async {
      final store = FakeBlockStore()..rows['me'] = {'a'};
      final list = ChatBlockList(store: store);
      await list.block('a');
      expect(list.isBlocked('a'), isTrue);
    });

    test('blocking yourself is refused before any write', () async {
      final store = FakeBlockStore();
      final list = ChatBlockList(store: store);
      await expectLater(list.block('me'), throwsA(isA<ChatBlockException>()));
      expect(store.inserts, 0);
    });

    test('a refused unblock keeps the block', () async {
      final store = FakeBlockStore()..rows['me'] = {'a'};
      final list = ChatBlockList(store: store);
      await list.refresh();
      store.deleteError = Exception('offline');
      await expectLater(list.unblock('a'), throwsA(isA<ChatBlockException>()));
      expect(list.isBlocked('a'), isTrue);

      store.deleteError = null;
      await list.unblock('a');
      expect(list.isBlocked('a'), isFalse);
      expect(store.rows['me'], isEmpty);
    });

    test('offline start uses the last server copy and marks it stale',
        () async {
      SharedPreferences.setMockInitialValues({
        '${ChatBlockList.cachePrefsPrefix}me': ['a'],
      });
      final store = FakeBlockStore()..fetchError = Exception('offline');
      final list = ChatBlockList(store: store);
      await list.refresh();
      expect(list.isBlocked('a'), isTrue);
      expect(list.isStale, isTrue);
    });

    test('a failed refresh never clears a confirmed list', () async {
      final store = FakeBlockStore()..rows['me'] = {'a'};
      final list = ChatBlockList(store: store);
      await list.refresh();
      store.fetchError = Exception('offline');
      await list.refresh();
      expect(list.isBlocked('a'), isTrue);
      expect(list.isStale, isTrue);
    });

    test('switching accounts drops the previous account\'s blocks',
        () async {
      final store = FakeBlockStore()
        ..rows['me'] = {'a'}
        ..rows['other'] = {'z'};
      final list = ChatBlockList(store: store);
      await list.refresh();
      store.currentUserId = 'other';
      await list.refresh();
      expect(list.blockedIds, {'z'});
      store.currentUserId = null;
      await list.refresh();
      expect(list.blockedIds, isEmpty);
    });

    test('device-only blocks are uploaded, then the old key is removed',
        () async {
      SharedPreferences.setMockInitialValues({
        '${ChatBlockList.legacyPrefsPrefix}me': ['a', 'b'],
      });
      final store = FakeBlockStore();
      final list = ChatBlockList(store: store);
      await list.refresh();
      expect(store.rows['me'], {'a', 'b'});
      expect(list.blockedIds, {'a', 'b'});
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('${ChatBlockList.legacyPrefsPrefix}me'),
          isNull);
    });

    test('a failed upload keeps the device-only blocks for the next try',
        () async {
      SharedPreferences.setMockInitialValues({
        '${ChatBlockList.legacyPrefsPrefix}me': ['a'],
      });
      final store = FakeBlockStore()..insertError = Exception('offline');
      final list = ChatBlockList(store: store);
      await list.refresh();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('${ChatBlockList.legacyPrefsPrefix}me'),
          ['a']);
    });
  });

  group('LiveChatController', () {
    test('filters senders from the shared list and follows its changes',
        () async {
      final store = FakeBlockStore();
      final list = ChatBlockList(store: store);
      final c = LiveChatController(streamId: 'stream-1', blockList: list);
      addTearDown(c.dispose);
      c.debugAddMessageForTests(msg('1', 'a'));
      c.debugAddMessageForTests(msg('2', 'b'));
      var notified = 0;
      c.addListener(() => notified++);

      await c.blockUser('a');
      expect(c.messages.map((m) => m.id), ['2']);
      expect(notified, greaterThan(0));

      // Unblocked elsewhere (Settings) through the same list.
      await list.unblock('a');
      expect(c.messages.map((m) => m.id), ['1', '2']);
    });

    test('a refused block is surfaced and filters nothing', () async {
      final store = FakeBlockStore()..insertError = Exception('offline');
      final c = LiveChatController(
          streamId: 'stream-1', blockList: ChatBlockList(store: store));
      addTearDown(c.dispose);
      c.debugAddMessageForTests(msg('1', 'a'));
      await expectLater(c.blockUser('a'), throwsA(isA<ChatBlockException>()));
      expect(c.messages, hasLength(1));
    });
  });

  group('report reasons', () {
    test('only the server-accepted codes are sent', () async {
      final c = LiveChatController(streamId: 'stream-1');
      addTearDown(c.dispose);
      c.debugSetStateForTests(currentUserId: 'me');
      await expectLater(
        c.reportMessage(
            messageId: 'm', reportedSenderId: 'a', reason: 'rude words'),
        throwsA(isA<ArgumentError>()),
      );
      expect(ChatReportReason.all,
          {'spam', 'harassment', 'hate_speech', 'other'});
    });

    test('server refusals map to messages, never raw text', () {
      expect(
          reportFailureKey(
              const PostgrestException(message: 'dup', code: '23505')),
          'live.report_already_submitted_toast');
      expect(
          reportFailureKey(const PostgrestException(
              message: 'violates check constraint', code: '23514')),
          'live.report_invalid_toast');
      expect(
          reportFailureKey(const PostgrestException(
              message: 'Report does not match message', code: '22023')),
          'live.report_invalid_toast');
      expect(reportFailureKey(Exception('socket')),
          'live.report_failed_toast');
      expect(ChatReportReason.labelKey('hate_speech'),
          'live.report_reason_hate');
      expect(ChatReportReason.labelKey('old free text'), isNull);
    });
  });

  group('BlockedAccountsSheet', () {
    setUpAll(initializeTestLocalization);

    testWidgets('lists server blocks by name and unblocks one',
        (tester) async {
      final store = FakeBlockStore()
        ..rows['me'] = {'a', 'b'}
        ..names.addAll({'a': 'Alice', 'b': 'Bob'});
      final list = ChatBlockList(store: store);
      await tester.pumpWidget(localizedApp(
          home: Scaffold(body: BlockedAccountsSheet(blockList: list))));
      await tester.pumpAndSettle();

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);

      await tester.tap(find.descendant(
          of: find.byKey(const Key('blocked-account-a')),
          matching: find.text('Unblock')));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsNothing);
      expect(store.rows['me'], {'b'});
      expect(find.textContaining('Unblocked'), findsOneWidget);
    });

    testWidgets('a refused unblock keeps the row and says why',
        (tester) async {
      final store = FakeBlockStore()
        ..rows['me'] = {'a'}
        ..names['a'] = 'Alice'
        ..deleteError = Exception('offline');
      final list = ChatBlockList(store: store);
      await tester.pumpWidget(localizedApp(
          home: Scaffold(body: BlockedAccountsSheet(blockList: list))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.textContaining("Couldn't reach the server"), findsOneWidget);
    });

    testWidgets('an unreachable server shows the cached list as stale',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        '${ChatBlockList.cachePrefsPrefix}me': ['a'],
      });
      final store = FakeBlockStore()..fetchError = Exception('offline');
      final list = ChatBlockList(store: store);
      await tester.pumpWidget(localizedApp(
          home: Scaffold(body: BlockedAccountsSheet(blockList: list))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('blocked-accounts-stale')), findsOneWidget);
      expect(find.byKey(const Key('blocked-account-a')), findsOneWidget);
    });

    testWidgets('no blocks shows an empty state', (tester) async {
      final list = ChatBlockList(store: FakeBlockStore());
      await tester.pumpWidget(localizedApp(
          home: Scaffold(body: BlockedAccountsSheet(blockList: list))));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('blocked-accounts-empty')), findsOneWidget);
    });
  });
}
