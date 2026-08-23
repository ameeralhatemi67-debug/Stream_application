import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Thin wrapper around Supabase Auth's Google OAuth flow.
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

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signOut() => _client.auth.signOut();
}
