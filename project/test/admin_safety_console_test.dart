import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_flags.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/admin_safety_backend.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/admin/presentation/widgets/admin_safety_view.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/live_stream/services/chat_block_list.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fixtures/streamer_fixtures.dart';

/// P6 admin safety console, platform switches and deleted-account cleanup.
/// The server side of each action is covered by
/// `supabase/tests/admin_safety_actions.test.sql`,
/// `chat_blocks_and_app_flags.test.sql` and `chat_keyword_audit.test.sql`.
late Map<String, dynamic> enData, arData;

class JsonLoader extends AssetLoader {
  const JsonLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      locale.languageCode == 'ar' ? arData : enData;
}

class FakeFlagsStore implements AppFlagsStore {
  final Map<String, bool> values = {
    'chat_enabled': true,
    'registrations_open': true,
  };
  Object? fetchError;
  Object? setError;
  final List<String> writes = [];

  @override
  Future<Map<String, ({bool enabled, DateTime? updatedAt})>> fetch() async {
    if (fetchError != null) throw fetchError!;
    return {
      for (final e in values.entries)
        e.key: (enabled: e.value, updatedAt: null),
    };
  }

  @override
  Future<void> set(String key, bool enabled, String reason) async {
    if (setError != null) throw setError!;
    writes.add('$key:$enabled:$reason');
    values[key] = enabled;
  }
}

class FakeSafetyBackend implements AdminSafetyBackend {
  List<LiveBroadcastRow> live = [];
  final List<AdminAuditEntry> audit = [];
  final List<BlocklistKeyword> keywords = [];
  Object? error;
  Object? writeError;
  final List<String?> auditFilters = [];
  final List<int> auditOffsets = [];

  @override
  Future<List<LiveBroadcastRow>> loadLiveBroadcasts() async {
    if (error != null) throw error!;
    return live;
  }

  @override
  Future<AuditPage> loadAudit({String? action, int offset = 0}) async {
    if (error != null) throw error!;
    auditFilters.add(action);
    auditOffsets.add(offset);
    final matching =
        audit.where((e) => action == null || e.action == action).toList();
    final page = matching.skip(offset).take(2).toList();
    return AuditPage(page, hasMore: offset + 2 < matching.length);
  }

  @override
  Future<List<BlocklistKeyword>> loadKeywords() async {
    if (error != null) throw error!;
    return List.of(keywords);
  }

  @override
  Future<void> addKeyword(String keyword, String matchMode) async {
    if (writeError != null) throw writeError!;
    keywords.add(BlocklistKeyword(
        id: 'k${keywords.length}',
        keyword: keyword,
        matchMode: matchMode,
        createdAt: DateTime(2026, 9, 23)));
  }

  @override
  Future<void> setKeywordMode(String id, String matchMode) async {
    if (writeError != null) throw writeError!;
    final i = keywords.indexWhere((k) => k.id == id);
    keywords[i] = BlocklistKeyword(
        id: id,
        keyword: keywords[i].keyword,
        matchMode: matchMode,
        createdAt: keywords[i].createdAt);
  }

  @override
  Future<void> removeKeyword(String id) async {
    if (writeError != null) throw writeError!;
    keywords.removeWhere((k) => k.id == id);
  }
}

class RecordingDbService extends AdminDatabaseService {
  final List<String> actions = [];
  Object? fail;
  @override
  Future<void> updateAdminAccount(
      String id, String action, String reason) async {
    if (fail != null) throw fail!;
    actions.add('$id:$action:$reason');
  }
}

AdminAuditEntry auditEntry(String id, String action) => AdminAuditEntry(
      id: id,
      action: action,
      actorName: 'Admin One',
      actorEmail: 'admin@example.invalid',
      descriptionEn: 'Reason $id',
      descriptionAr: 'سبب $id',
      createdAt: DateTime.utc(2026, 9, 23, 10),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    enData = jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    arData = jsonDecode(File('assets/i18n/ar.json').readAsStringSync());
    await EasyLocalization.ensureInitialized();
  });

  Widget app(AppProvider provider, Widget home, {String locale = 'en'}) =>
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('ar')],
        path: 'assets/i18n',
        assetLoader: const JsonLoader(),
        startLocale: Locale(locale),
        fallbackLocale: const Locale('en'),
        saveLocale: false,
        child: ChangeNotifierProvider.value(
          value: provider,
          child: Builder(
            builder: (context) => MaterialApp(
              locale: context.locale,
              localizationsDelegates: context.localizationDelegates,
              supportedLocales: context.supportedLocales,
              theme: AppTheme.forLocale(context.locale),
              home: Scaffold(body: home),
            ),
          ),
        ),
      );

  AppProvider admin({bool master = false, AdminDatabaseService? service}) {
    final p = AppProvider(service ?? RecordingDbService());
    p.debugSetSignedInForTests(
        email: 'admin@example.invalid', isAdmin: true, isMasterAdmin: master);
    return p;
  }

  Future<void> enterReason(WidgetTester tester, String reason) async {
    await tester.enterText(find.byKey(const Key('safety-reason-field')), reason);
    await tester.pump();
    await tester.tap(find.byKey(const Key('safety-reason-confirm')));
    await tester.pumpAndSettle();
  }

  group('AppFlags', () {
    test('reads the server values', () async {
      final store = FakeFlagsStore()..values['chat_enabled'] = false;
      final flags = AppFlags(store: store);
      await flags.refresh();
      expect(flags.chatEnabled, isFalse);
      expect(flags.registrationsOpen, isTrue);
      expect(flags.status, AppFlagsStatus.loaded);
      expect(flags.isKnown(AppFlagKey.chatEnabled), isTrue);
    });

    test('an unreadable table reports failure and locks nobody out',
        () async {
      final flags = AppFlags(store: FakeFlagsStore()..fetchError = 'offline');
      await flags.refresh();
      expect(flags.status, AppFlagsStatus.failed);
      expect(flags.chatEnabled, isTrue);
      expect(flags.isKnown(AppFlagKey.chatEnabled), isFalse);
    });

    test('a change needs a reason and shows the server result', () async {
      final store = FakeFlagsStore();
      final flags = AppFlags(store: store);
      await expectLater(flags.setFlag(AppFlagKey.chatEnabled, false, '  '),
          throwsA(isA<AppFlagException>()));
      expect(store.writes, isEmpty);
      await flags.setFlag(AppFlagKey.chatEnabled, false, ' spam wave ');
      expect(store.writes, ['chat_enabled:false:spam wave']);
      expect(flags.chatEnabled, isFalse);
    });

    test('server refusals are classified', () async {
      final store = FakeFlagsStore()
        ..setError = const PostgrestException(message: 'no', code: '42501');
      final flags = AppFlags(store: store);
      await expectLater(
          flags.setFlag(AppFlagKey.chatEnabled, false, 'r'),
          throwsA(isA<AppFlagException>().having((e) => e.failure, 'failure',
              AppFlagFailure.notPermitted)));
    });
  });

  group('platform chat pause', () {
    LiveChatController controller(AppFlags flags,
        {bool canModerate = false, bool banned = false, String? user = 'me'}) {
      final c = LiveChatController(
          streamId: 's',
          appFlags: flags,
          blockList: ChatBlockList(store: _NoBlocks()));
      c.debugSetStateForTests(
          currentUserId: user,
          canModerate: canModerate,
          isSelfBanned: banned,
          connectionState: ChatConnectionState.live);
      addTearDown(c.dispose);
      return c;
    }

    test('pauses everyone, moderators included', () {
      final flags = AppFlags()..debugSetValues({AppFlagKey.chatEnabled: false});
      expect(controller(flags).composerState, ChatComposerState.platformPaused);
      expect(controller(flags, canModerate: true).composerState,
          ChatComposerState.platformPaused);
      expect(controller(flags, user: null).composerState,
          ChatComposerState.platformPaused);
      expect(controller(flags, banned: true).composerState,
          ChatComposerState.banned);
    });

    test('follows the switch without rebuilding the room', () {
      final flags = AppFlags()..debugSetValues({AppFlagKey.chatEnabled: true});
      final c = controller(flags);
      var notified = 0;
      c.addListener(() => notified++);
      expect(c.canSend, isTrue);
      flags.debugSetValues({AppFlagKey.chatEnabled: false});
      expect(notified, greaterThan(0));
      expect(c.canSend, isFalse);
    });

    test('a server refusal from the switch is not offered for retry', () {
      final c = controller(AppFlags());
      final f = c.debugClassifyForTests(
          'PostgrestException(message: Feature temporarily disabled, code: 42501)');
      expect(f.retryable, isFalse);
      expect(f.message, contains('paused'));
    });
  });

  group('welcome screen', () {
    testWidgets('paused sign-ups disable Sign up but keep Log in',
        (tester) async {
      final store = FakeFlagsStore()..values['registrations_open'] = false;
      final flags = AppFlags(store: store);
      final provider = AppProvider();
      addTearDown(provider.dispose);
      await tester.binding.setSurfaceSize(const Size(500, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(provider, WelcomeScreen(appFlags: flags)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('registrations-paused-notice')),
          findsOneWidget);
      final signup = tester
          .widget<ElevatedButton>(find.byKey(const Key('welcome-signup')));
      expect(signup.onPressed, isNull);
      expect(
          tester
              .widget<OutlinedButton>(find.byType(OutlinedButton).first)
              .onPressed,
          isNotNull);
    });

    testWidgets('open sign-ups show no notice', (tester) async {
      final flags = AppFlags(store: FakeFlagsStore());
      final provider = AppProvider();
      addTearDown(provider.dispose);
      await tester.pumpWidget(app(provider, WelcomeScreen(appFlags: flags)));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('registrations-paused-notice')), findsNothing);
    });
  });

  group('Safety console', () {
    testWidgets('denies non-admins before any read', (tester) async {
      final backend = FakeSafetyBackend();
      final p = AppProvider(RecordingDbService());
      addTearDown(p.dispose);
      await tester.pumpWidget(app(p, AdminSafetyView(backend: backend)));
      await tester.pumpAndSettle();
      expect(find.text('Administrator access required.'), findsOneWidget);
      expect(backend.auditFilters, isEmpty);
    });

    testWidgets('platform switches are Master Admin only', (tester) async {
      final p = admin();
      addTearDown(p.dispose);
      await tester.pumpWidget(app(p, AdminSafetyView(backend: FakeSafetyBackend())));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-section-switches')), findsNothing);
      expect(find.byKey(const Key('safety-section-keywords')), findsOneWidget);
    });

    testWidgets('live list shows counts and ends a broadcast with a reason',
        (tester) async {
      final service = RecordingDbService();
      final p = admin(service: service);
      addTearDown(p.dispose);
      final backend = FakeSafetyBackend()
        ..live = const [
          LiveBroadcastRow(
              profileId: 'p1',
              name: 'Dr Amal',
              broadcastType: 'liveVideo',
              streamId: 'v1',
              viewerCount: 7),
          LiveBroadcastRow(
              profileId: 'p2',
              name: 'Radio',
              broadcastType: 'liveAudio',
              streamId: 'v2'),
        ];
      await tester.pumpWidget(app(p, AdminSafetyView(backend: backend)));
      await tester.pumpAndSettle();
      expect(find.text('2 live · 7 watching'), findsOneWidget);
      expect(find.textContaining('could not be read'), findsOneWidget);
      expect(find.text('Viewer count unavailable', findRichText: true),
          findsNothing);
      expect(find.textContaining('Viewer count unavailable'), findsOneWidget);

      await tester.tap(find.byKey(const Key('safety-end-p1')));
      await tester.pumpAndSettle();
      // A blank reason cannot be submitted.
      expect(
          tester
              .widget<ElevatedButton>(
                  find.byKey(const Key('safety-reason-confirm')))
              .onPressed,
          isNull);
      await enterReason(tester, 'abusive stream');
      expect(service.actions, ['p1:force_end:abusive stream']);
      expect(find.text('Broadcast ended in the app.'), findsOneWidget);
    });

    testWidgets('a refused live action says why and changes nothing',
        (tester) async {
      final service = RecordingDbService()
        ..fail = const PostgrestException(message: 'x', code: '42501');
      final p = admin(service: service);
      addTearDown(p.dispose);
      final backend = FakeSafetyBackend()
        ..live = const [
          LiveBroadcastRow(
              profileId: 'p1',
              name: 'Dr Amal',
              broadcastType: 'liveVideo',
              streamId: 'v1',
              viewerCount: 1),
        ];
      await tester.pumpWidget(app(p, AdminSafetyView(backend: backend)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-remove-p1')));
      await tester.pumpAndSettle();
      await enterReason(tester, 'reason');
      expect(find.textContaining('not allowed'), findsOneWidget);
    });

    testWidgets('empty and error states are distinct', (tester) async {
      final p = admin();
      addTearDown(p.dispose);
      final backend = FakeSafetyBackend();
      await tester.pumpWidget(app(p, AdminSafetyView(backend: backend)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-live-empty')), findsOneWidget);

      backend.error = Exception('offline');
      await tester.pumpWidget(app(p, AdminSafetyView(
          key: const Key('again'), backend: backend)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-live-error')), findsOneWidget);
      expect(find.byKey(const Key('safety-live-empty')), findsNothing);
    });

    testWidgets('audit log filters and pages from the server',
        (tester) async {
      final p = admin();
      addTearDown(p.dispose);
      final backend = FakeSafetyBackend()
        ..audit.addAll([
          auditEntry('a1', 'accountDeleted'),
          auditEntry('a2', 'chatKeywordAdded'),
          auditEntry('a3', 'accountDeleted'),
        ]);
      await tester.pumpWidget(app(p, AdminSafetyView(backend: backend)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-section-audit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-audit-a1')), findsOneWidget);
      expect(find.byKey(const Key('safety-audit-a3')), findsNothing);
      expect(find.textContaining('By Admin One'), findsNWidgets(2));

      await tester.tap(find.byKey(const Key('safety-audit-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-audit-a3')), findsOneWidget);
      expect(backend.auditOffsets.last, 2);

      await tester.tap(find.byKey(const Key('safety-audit-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find
          .byWidgetPredicate((w) =>
              w is DropdownMenuItem<String?> && w.value == 'accountDeleted')
          .last);
      await tester.pumpAndSettle();
      expect(backend.auditFilters.last, 'accountDeleted');
      expect(backend.auditOffsets.last, 0);
      expect(find.byKey(const Key('safety-audit-a1')), findsOneWidget);
      expect(find.byKey(const Key('safety-audit-a3')), findsOneWidget);
      expect(find.byKey(const Key('safety-audit-a2')), findsNothing);
    });

    testWidgets('keyword manager adds, changes mode and removes',
        (tester) async {
      final p = admin();
      addTearDown(p.dispose);
      final backend = FakeSafetyBackend();
      await tester.pumpWidget(app(p, AdminSafetyView(backend: backend)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-section-keywords')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-keyword-empty')), findsOneWidget);

      await tester.tap(find.byKey(const Key('safety-keyword-add')));
      await tester.pumpAndSettle();
      expect(find.textContaining('up to 100 characters'), findsOneWidget);
      expect(backend.keywords, isEmpty);

      await tester.enterText(
          find.byKey(const Key('safety-keyword-input')), '  spamword ');
      await tester.tap(find.byKey(const Key('safety-keyword-add')));
      await tester.pumpAndSettle();
      expect(backend.keywords.single.keyword, 'spamword');
      expect(backend.keywords.single.matchMode, 'word');
      expect(find.byKey(const Key('safety-keyword-k0')), findsOneWidget);

      await tester.tap(find.byKey(const Key('safety-keyword-mode-k0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anywhere in text').last);
      await tester.pumpAndSettle();
      expect(backend.keywords.single.matchMode, 'substring');

      await tester.tap(find.byKey(const Key('safety-keyword-remove-k0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-keyword-remove-confirm')));
      await tester.pumpAndSettle();
      expect(backend.keywords, isEmpty);
      expect(find.byKey(const Key('safety-keyword-empty')), findsOneWidget);
    });

    testWidgets('a duplicate keyword is reported, not silently accepted',
        (tester) async {
      final p = admin();
      addTearDown(p.dispose);
      final backend = FakeSafetyBackend()
        ..writeError =
            const AdminSafetyException(AdminSafetyFailure.duplicate);
      await tester.pumpWidget(app(p, AdminSafetyView(backend: backend)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-section-keywords')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('safety-keyword-input')), 'dup');
      await tester.tap(find.byKey(const Key('safety-keyword-add')));
      await tester.pumpAndSettle();
      expect(find.text('That entry already exists.'), findsOneWidget);
    });

    testWidgets('master admin toggles a switch with a reason',
        (tester) async {
      final p = admin(master: true);
      addTearDown(p.dispose);
      final store = FakeFlagsStore();
      final flags = AppFlags(store: store);
      await tester.pumpWidget(app(p,
          AdminSafetyView(backend: FakeSafetyBackend(), appFlags: flags)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-section-switches')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await enterReason(tester, 'raid in progress');
      expect(store.writes, ['chat_enabled:false:raid in progress']);
      expect(flags.chatEnabled, isFalse);
      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('unreadable switches cannot be toggled blind',
        (tester) async {
      final p = admin(master: true);
      addTearDown(p.dispose);
      final flags = AppFlags(store: FakeFlagsStore()..fetchError = 'offline');
      await tester.pumpWidget(app(p,
          AdminSafetyView(backend: FakeSafetyBackend(), appFlags: flags)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-section-switches')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('safety-switches-error')), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch).first).onChanged,
          isNull);
    });
  });

  group('deleted account caches', () {
    test('a confirmed deletion removes every local trace', () async {
      final service = RecordingDbService();
      final p = admin(service: service);
      addTearDown(p.dispose);
      final s = mockStreamers.first;
      p.addStreamerForTests(s);
      final profileId = s.streamerId.replaceFirst('streamer_', '');
      await p.toggleFollow(s.streamerId);
      p.toggleReminder(s.streamerId);
      p.launchMiniPlayer(
          videoId: s.youtubeVideoId, title: 't', streamerName: 'n');
      expect(p.isFollowing(s.streamerId), isTrue);

      await p.updateAdminAccount(profileId, 'delete_account', 'erasure');
      expect(service.actions, ['$profileId:delete_account:erasure']);
      expect(p.streamers.where((x) => x.streamerId == s.streamerId), isEmpty);
      expect(p.isFollowing(s.streamerId), isFalse);
      expect(p.hasReminder(s.streamerId), isFalse);
      expect(p.isMiniPlayerActive, isFalse);
    });

    test('a refused deletion keeps everything', () async {
      final service = RecordingDbService()..fail = Exception('offline');
      final p = admin(service: service);
      addTearDown(p.dispose);
      final s = mockStreamers.first;
      p.addStreamerForTests(s);
      await p.toggleFollow(s.streamerId);
      await expectLater(
          p.updateAdminAccount(s.streamerId, 'delete_account', 'r'),
          throwsA(isA<Exception>()));
      expect(p.isFollowing(s.streamerId), isTrue);
      expect(p.streamers.where((x) => x.streamerId == s.streamerId),
          isNotEmpty);
    });
  });
}

class _NoBlocks implements ChatBlockStore {
  @override
  String? get currentUserId => 'me';
  @override
  Future<void> deleteBlock(String blockerId, String blockedId) async {}
  @override
  Future<Set<String>> fetchBlockedIds(String blockerId) async => {};
  @override
  Future<void> insertBlock(String blockerId, String blockedId) async {}
  @override
  Future<Map<String, String>> resolveNames(List<String> profileIds) async =>
      {};
}
