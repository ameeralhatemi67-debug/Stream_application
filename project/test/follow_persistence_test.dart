import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/follow_action.dart';
import 'support/empty_broadcasts.dart';
import 'support/localized_app.dart';

class _Auth extends SupabaseAuthService {
  Session? session = Session(
      accessToken: 'test-only',
      tokenType: 'bearer',
      user: const User(
          id: 'viewer-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-10-28T00:00:00Z'));
  @override
  Session? get currentSession => session;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

class _FollowDb extends AdminDatabaseService {
  _FollowDb() : super(null);
  final rows = <String>{};
  bool refuse = false;
  int writes = 0;
  Completer<void>? hold;

  @override
  Future<Set<String>> loadFollowedTargetIds() async => {...rows};

  @override
  Future<bool> addFollow(String targetId) async {
    writes++;
    if (hold != null) await hold!.future;
    if (refuse) return false;
    rows.add(targetId);
    return true;
  }

  @override
  Future<bool> removeFollow(String targetId) async {
    writes++;
    if (refuse) return false;
    rows.remove(targetId);
    return true;
  }
}

AppProvider _provider(_FollowDb db) => AppProvider.withServices(
    adminDbService: db,
    authService: _Auth(),
    organizationBroadcastService: EmptyBroadcasts());

class _FollowProbe extends StatelessWidget {
  const _FollowProbe();
  @override
  Widget build(BuildContext context) {
    final following =
        context.select<AppProvider, bool>((p) => p.isFollowing('channel-1'));
    return Scaffold(
        body: Center(
            child: ElevatedButton(
                onPressed: () => toggleFollowWithFeedback(context, 'channel-1'),
                child: Text(following ? 'following' : 'follow'))));
  }
}

Widget _app(AppProvider provider, String lang) => EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    startLocale: Locale(lang),
    saveLocale: false,
    path: 'assets/i18n',
    assetLoader: const DirectJsonAssetLoader(),
    child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
            builder: (context) => MaterialApp(
                theme: AppTheme.forLocale(context.locale),
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                home: const _FollowProbe()))));

String _text(String lang, String key) =>
    (jsonDecode(File('assets/i18n/$lang.json').readAsStringSync())
        as Map<String, dynamic>)['profile'][key] as String;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);

  for (final lang in ['en', 'ar']) {
    testWidgets('$lang: a refused follow goes back and says so',
        (tester) async {
      final db = _FollowDb()..refuse = true;
      final provider = _provider(db);
      await tester.pumpWidget(_app(provider, lang));
      await tester.pumpAndSettle();
      await tester.tap(find.text('follow'));
      await tester.pumpAndSettle();
      expect(provider.isFollowing('channel-1'), isFalse);
      expect(find.text('follow'), findsOneWidget);
      expect(find.text(_text(lang, 'follow_failed')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  }

  testWidgets('a saved follow stays, with no message', (tester) async {
    final db = _FollowDb();
    final provider = _provider(db);
    await tester.pumpWidget(_app(provider, 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('follow'));
    await tester.pumpAndSettle();
    expect(provider.isFollowing('channel-1'), isTrue);
    expect(db.rows, {'channel-1'});
    expect(find.text(_text('en', 'follow_failed')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('a refused unfollow keeps the channel followed', (tester) async {
    final db = _FollowDb();
    final provider = _provider(db);
    await tester.pumpWidget(_app(provider, 'en'));
    await tester.pumpAndSettle();
    expect(await provider.toggleFollow('channel-1'), isTrue);
    db.refuse = true;
    expect(await provider.toggleFollow('channel-1'), isFalse);
    expect(provider.isFollowing('channel-1'), isTrue);
    expect(db.rows, {'channel-1'});
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });

  testWidgets('a second tap while the first is saving is ignored',
      (tester) async {
    final db = _FollowDb();
    final provider = _provider(db);
    await tester.pumpWidget(_app(provider, 'en'));
    await tester.pumpAndSettle();
    db.hold = Completer<void>();
    final first = provider.toggleFollow('channel-1');
    expect(provider.isFollowing('channel-1'), isTrue);
    expect(await provider.toggleFollow('channel-1'), isTrue);
    expect(provider.isFollowing('channel-1'), isTrue);
    db.hold!.complete();
    expect(await first, isTrue);
    expect(db.writes, 1);
    expect(db.rows, {'channel-1'});
    // Once the first write is done the next tap goes through.
    expect(await provider.toggleFollow('channel-1'), isTrue);
    expect(provider.isFollowing('channel-1'), isFalse);
    expect(db.writes, 2);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
