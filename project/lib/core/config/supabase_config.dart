/// Supabase project credentials, injected at build/run time via `--dart-define`.
///
/// Never hardcode real values here. Pass them at build time, e.g.:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=xxxx
class SupabaseConfig {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
