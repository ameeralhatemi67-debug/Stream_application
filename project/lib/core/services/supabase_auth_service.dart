import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Stateless wrapper around Supabase Auth's Google and native Apple flows.
///
/// Unlike the old GoogleAuthService, a failed or cancelled sign-in always
/// surfaces as a thrown exception -- it never fabricates a session.
class SupabaseAuthService {
  SupabaseClient get _client => Supabase.instance.client;

  /// Launches the Google OAuth web flow. Returns once the browser has been
  /// opened -- actual sign-in completion arrives later via the OAuth
  /// redirect deep link and is observed through [onAuthStateChange].
  Future<void> signInWithGoogle() async {
    final launched = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? Uri.base.origin : SupabaseConfig.oauthRedirectUrl,
      queryParams: {
        'prompt': 'select_account',
      },
    );
    if (!launched) {
      throw Exception('Could not launch the Google sign-in screen.');
    }
  }

  /// Exchanges a native Apple credential for the same Supabase session used
  /// by Google. The raw nonce stays local; Apple receives only its SHA-256.
  Future<void> signInWithApple() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        !await SignInWithApple.isAvailable()) {
      throw const AuthException('Sign-in unavailable.');
    }
    final rawNonce = _client.auth.generateRawNonce();
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName
      ],
      nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
    );
    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthException('Sign-in unavailable.');
    }
    await _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
      nonce: rawNonce,
    );
  }

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get currentSession {
    try {
      if (!Supabase.instance.isInitialized) return null;
      return _client.auth.currentSession;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (!Supabase.instance.isInitialized) return;
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase sign-out failed: $e');
    }
  }

  Future<void> signOutOthers() async {
    await _client.auth.signOut(scope: SignOutScope.others);
  }
}
