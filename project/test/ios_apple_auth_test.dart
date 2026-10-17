import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:streamer_app/core/services/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <Map<String, dynamic>>[];
  final appleHashes = <String>[];
  bool available = true;
  String? identityToken;
  bool cancel = false;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    appleHashes.clear();
    available = true;
    identityToken = 'unit-test-identity-token';
    cancel = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SignInWithApple.channel, (call) async {
      if (call.method == 'isAvailable') return available;
      if (call.method == 'performAuthorizationRequest') {
        if (cancel) {
          throw PlatformException(code: 'authorization-error/canceled');
        }
        appleHashes.add((call.arguments as List).single['nonce'] as String);
        return {
          'type': 'appleid',
          'authorizationCode': 'unit-test-authorization-code',
          'identityToken': identityToken,
        };
      }
      throw StateError('Unexpected Apple method');
    });
    await Supabase.initialize(
      url: 'https://apple-auth-test.invalid',
      publishableKey: 'unit-test-public-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        persistSession: false,
      ),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/auth/v1/token');
        expect(request.url.queryParameters['grant_type'], 'id_token');
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        // Reject the fake token: this test must never fabricate a session.
        return http.Response('{"msg":"Test token rejected"}', 400);
      }),
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SignInWithApple.channel, null);
    await Supabase.instance.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test('Apple receives a fresh hash; Supabase receives matching raw nonce',
      () async {
    final service = SupabaseAuthService();
    for (var i = 0; i < 2; i++) {
      await expectLater(
          service.signInWithApple(), throwsA(isA<AuthException>()));
      final body = requests[i];
      final raw = body['nonce'] as String;
      expect(raw.length, greaterThanOrEqualTo(24));
      expect(appleHashes[i], sha256.convert(utf8.encode(raw)).toString());
      expect(appleHashes[i], isNot(raw));
      expect(body['provider'], 'apple');
      expect(body['id_token'], identityToken);
    }
    expect(requests[0]['nonce'], isNot(requests[1]['nonce']));
    expect(Supabase.instance.client.auth.currentSession, isNull);
  });

  test('missing identity token never reaches Supabase', () async {
    identityToken = null;
    await expectLater(
        SupabaseAuthService().signInWithApple(), throwsA(isA<AuthException>()));
    expect(requests, isEmpty);
  });

  test('unavailable capability rejects without requesting credentials',
      () async {
    available = false;
    await expectLater(
        SupabaseAuthService().signInWithApple(), throwsA(isA<AuthException>()));
    expect(appleHashes, isEmpty);
    expect(requests, isEmpty);
  });

  test('native cancellation never reaches Supabase', () async {
    cancel = true;
    await expectLater(
      SupabaseAuthService().signInWithApple(),
      throwsA(isA<SignInWithAppleAuthorizationException>().having(
          (error) => error.code, 'code', AuthorizationErrorCode.canceled)),
    );
    expect(requests, isEmpty);
  });
}
