import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DeletionAuth extends SupabaseAuthService {
  _DeletionAuth(this.calls);
  final List<String> calls;
  String? failure;
  @override
  Session? get currentSession => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
  @override
  Future<void> signOut() async {}
  @override
  Future<void> revokeAppleAuthorizationForDeletion() async {
    calls.add('revoke');
    if (failure != null) throw AppleAccountDeletionException(failure!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  final bodies = <Map<String, dynamic>>[];
  bool? requiresApple = true;
  var available = true;
  var cancelled = false;
  var code = 'MOCK_CODE';
  var functionStatus = 200;
  var functionError = 'apple_revocation_failed';
  var credentialCount = 0;
  var changeAccount = false;
  String? rotatedAccessToken;
  var clearSession = false;
  var expectedFunctionToken = 'MOCK_SESSION';
  String? preparedBlocker;

  Future<void> session(
          {bool apple = true,
          String? id,
          String accessToken = 'MOCK_SESSION'}) =>
      Supabase.instance.client.auth.setInitialSession(jsonEncode({
        'access_token': accessToken,
        'token_type': 'bearer',
        'refresh_token': 'MOCK_REFRESH',
        'user': {
          'id': id ?? '00000000-0000-4000-8000-000000000001',
          'aud': 'authenticated',
          'created_at': '2026-10-18T00:00:00Z',
          'app_metadata': {},
          'user_metadata': {},
          'identities': [
            {
              'id': 'MOCK_PROVIDER_SUBJECT',
              'identity_id': '00000000-0000-4000-8000-000000000002',
              'user_id': id ?? '00000000-0000-4000-8000-000000000001',
              'provider': apple ? 'apple' : 'google',
              'identity_data': {},
              'created_at': '2026-10-18T00:00:00Z',
            }
          ],
        },
      }));

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    bodies.clear();
    requiresApple = true;
    available = true;
    cancelled = false;
    changeAccount = false;
    rotatedAccessToken = null;
    clearSession = false;
    expectedFunctionToken = 'MOCK_SESSION';
    preparedBlocker = null;
    code = 'MOCK_CODE';
    credentialCount = 0;
    functionStatus = 200;
    functionError = 'apple_revocation_failed';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SignInWithApple.channel, (call) async {
      if (call.method == 'isAvailable') return available;
      if (call.method == 'performAuthorizationRequest') {
        credentialCount++;
        if (cancelled) {
          throw PlatformException(code: 'authorization-error/canceled');
        }
        final args = (call.arguments as List).single as Map;
        bodies.add({'apple_nonce': args['nonce']});
        if (changeAccount) {
          await session(id: '00000000-0000-4000-8000-000000000099');
        }
        if (rotatedAccessToken != null) {
          await session(accessToken: rotatedAccessToken!);
        }
        if (clearSession) {
          await Supabase.instance.client.auth
              .signOut(scope: SignOutScope.local);
        }
        return {
          'type': 'appleid',
          'authorizationCode': code,
          'identityToken': 'MOCK_IDENTITY'
        };
      }
      throw StateError('Unexpected Apple call');
    });
    await Supabase.initialize(
      url: 'https://apple-deletion-test.invalid',
      publishableKey: 'MOCK_PUBLIC_KEY',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        persistSession: false,
      ),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/prepare_account_deletion')) {
          calls.add('prepare');
          return http.Response(
              jsonEncode({
                'blocker': preparedBlocker,
                if (requiresApple != null)
                  'requires_apple_revocation': requiresApple,
                'storage_paths': ['MOCK_USER/avatar.png'],
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'});
        }
        if (path.endsWith('/apple-account-revocation')) {
          calls.add('function');
          expect(request.headers['Authorization'],
              'Bearer $expectedFunctionToken');
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
              jsonEncode(functionStatus == 200
                  ? {'status': 'revoked'}
                  : {
                      'error': functionError,
                      'diagnostic': 'MOCK_SENSITIVE_VALUE'
                    }),
              functionStatus,
              request: request,
              headers: {'content-type': 'application/json'});
        }
        if (path.endsWith('/object/streamer-assets')) {
          calls.add('storage');
          return http.Response('[]', 200,
              request: request, headers: {'content-type': 'application/json'});
        }
        if (path.endsWith('/delete_own_account')) {
          calls.add('delete');
          return http.Response('', 204, request: request);
        }
        if (path.endsWith('/logout')) {
          return http.Response('', 204, request: request);
        }
        return http.Response('[]', 200,
            request: request, headers: {'content-type': 'application/json'});
      }),
    );
    await session();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SignInWithApple.channel, null);
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('native code and matching fresh nonce reach the authenticated function',
      () async {
    final auth = SupabaseAuthService();
    await auth.revokeAppleAuthorizationForDeletion();
    final first = bodies[1]['nonce'];
    expect(first, bodies[0]['apple_nonce']);
    expect(first, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(bodies[1]['authorization_code'], 'MOCK_CODE');
    expect(bodies[1].containsKey('identity_token'), isFalse);
    await auth.revokeAppleAuthorizationForDeletion();
    expect(bodies[3]['nonce'], isNot(first));
    expect(calls, ['function', 'function']);
  });

  test('missing setup produces only the safe unavailable code', () async {
    functionStatus = 503;
    functionError = 'apple_revocation_unavailable';
    await expectLater(
        SupabaseAuthService().revokeAppleAuthorizationForDeletion(),
        throwsA(isA<AppleAccountDeletionException>()
            .having((e) => e.code, 'code', 'apple_revocation_unavailable')));
  });

  test('failed exchange is sanitized into a stable localized error code',
      () async {
    functionStatus = 409;
    await expectLater(
        SupabaseAuthService().revokeAppleAuthorizationForDeletion(),
        throwsA(isA<AppleAccountDeletionException>()
            .having((e) => e.code, 'code', 'apple_revocation_failed')));
  });

  test('native cancellation never calls the function', () async {
    cancelled = true;
    await expectLater(
        SupabaseAuthService().revokeAppleAuthorizationForDeletion(),
        throwsA(isA<AppleAccountDeletionException>()
            .having((e) => e.code, 'code', 'apple_revocation_cancelled')));
    expect(calls, isEmpty);
  });

  test('unavailable native capability never requests an Apple credential',
      () async {
    available = false;
    await expectLater(
        SupabaseAuthService().revokeAppleAuthorizationForDeletion(),
        throwsA(isA<AppleAccountDeletionException>()));
    expect(credentialCount, 0);
    expect(calls, isEmpty);
  });

  test('empty native authorization code never reaches the function', () async {
    code = '';
    await expectLater(
        SupabaseAuthService().revokeAppleAuthorizationForDeletion(),
        throwsA(isA<AppleAccountDeletionException>()));
    expect(calls, isEmpty);
  });

  test('account change during Apple authorization cannot use the new session',
      () async {
    changeAccount = true;
    await expectLater(
        SupabaseAuthService().revokeAppleAuthorizationForDeletion(),
        throwsA(isA<AppleAccountDeletionException>()));
    expect(calls, isEmpty);
  });

  test('session rotated during the Apple sheet uses the new access token',
      () async {
    rotatedAccessToken = 'MOCK_ROTATED_SESSION';
    expectedFunctionToken = rotatedAccessToken!;
    await SupabaseAuthService().revokeAppleAuthorizationForDeletion();
    expect(calls, ['function']);
  });

  test('session lost during the Apple sheet never calls the function',
      () async {
    clearSession = true;
    await expectLater(
        SupabaseAuthService().revokeAppleAuthorizationForDeletion(),
        throwsA(isA<AppleAccountDeletionException>()
            .having((e) => e.code, 'code', 'apple_revocation_failed')));
    expect(calls, isEmpty);
  });

  for (final scenario in [
    (serverFlag: false, clientApple: true, needsRevocation: false),
    (serverFlag: true, clientApple: false, needsRevocation: true),
    (serverFlag: null, clientApple: true, needsRevocation: true),
    (serverFlag: null, clientApple: false, needsRevocation: false),
  ]) {
    test(
        'server flag ${scenario.serverFlag} with client Apple '
        '${scenario.clientApple} selects revocation ${scenario.needsRevocation}',
        () async {
      requiresApple = scenario.serverFlag;
      await session(apple: scenario.clientApple);
      final provider =
          AppProvider.withServices(authService: _DeletionAuth(calls));
      try {
        expect(await provider.deleteOwnAccount(), isNull);
        expect(calls, [
          'prepare',
          if (scenario.needsRevocation) 'revoke',
          'storage',
          'delete',
        ]);
      } finally {
        provider.dispose();
      }
    });
  }

  test('revocation precedes storage removal and existing deletion RPC',
      () async {
    final auth = _DeletionAuth(calls);
    final provider = AppProvider.withServices(authService: auth);
    try {
      final result = await provider.deleteOwnAccount();
      expect(calls, ['prepare', 'revoke', 'storage', 'delete']);
      expect(result, isNull);
    } finally {
      provider.dispose();
    }
  });

  test('Apple revocation failure preserves both uploads and account', () async {
    final auth = _DeletionAuth(calls)..failure = 'apple_revocation_unavailable';
    final provider = AppProvider.withServices(authService: auth);
    try {
      expect(await provider.deleteOwnAccount(), 'apple_revocation_unavailable');
      expect(calls, ['prepare', 'revoke']);
    } finally {
      provider.dispose();
    }
  });

  test('existing deletion blockers run before Apple authorization', () async {
    preparedBlocker = 'broadcast_active';
    final provider =
        AppProvider.withServices(authService: _DeletionAuth(calls));
    try {
      expect(await provider.deleteOwnAccount(), 'broadcast_active');
      expect(calls, ['prepare']);
    } finally {
      provider.dispose();
    }
  });

  test('non-Apple Android account retains the existing deletion sequence',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    requiresApple = false;
    await session(apple: false);
    final provider =
        AppProvider.withServices(authService: _DeletionAuth(calls));
    try {
      expect(await provider.deleteOwnAccount(), isNull);
      expect(calls, ['prepare', 'storage', 'delete']);
    } finally {
      provider.dispose();
    }
  });

  for (final linked in [true, false]) {
    test('restricted account Apple-linked $linked selects only relevant copy',
        () async {
      preparedBlocker = 'account_restricted';
      requiresApple = linked;
      // Server binding takes precedence over the opposite cached identity.
      await session(apple: !linked);
      final provider =
          AppProvider.withServices(authService: _DeletionAuth(calls));
      try {
        expect(await provider.deleteOwnAccount(),
            linked ? 'account_restricted_apple' : 'account_restricted');
        expect(calls, ['prepare']);
        for (final language in ['en', 'ar']) {
          final settings =
              (jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
                  as Map)['settings'] as Map;
          expect(settings['delete_account_blocked_account_restricted'],
              isNot(contains('Apple')));
          expect(settings['delete_account_apple_linked_requirement'],
              contains('Apple'));
        }
      } finally {
        provider.dispose();
      }
    });
  }

  test('all Apple deletion errors have clear EN/AR text and symmetric keys',
      () {
    for (final language in ['en', 'ar']) {
      final catalog =
          jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
              as Map<String, dynamic>;
      final settings = catalog['settings'] as Map<String, dynamic>;
      for (final code in ['required', 'unavailable', 'failed', 'cancelled']) {
        final key = 'delete_account_blocked_apple_revocation_$code';
        expect(settings[key], isA<String>());
        expect((settings[key] as String).length, greaterThan(30));
        expect(AppProvider.accountDeletionBlockers,
            contains('apple_revocation_$code'));
        expect(
            (settings[key] as String)
                .endsWith(language == 'ar' ? ' حاول مرة أخرى.' : ' Try again.'),
            code == 'failed');
      }
    }
  });
}
