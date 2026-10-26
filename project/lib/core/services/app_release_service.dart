import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_distribution.dart';
import '../config/app_identity.dart';
import '../config/supabase_config.dart';

/// One published release of the phone app (`public.app_releases`, ADR-017).
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.minSupportedCode,
    required this.downloadUrl,
    this.notesEn = '',
    this.notesAr = '',
  });

  factory AppRelease.fromRow(Map<String, dynamic> row) => AppRelease(
        versionCode: (row['version_code'] as num).toInt(),
        versionName: row['version_name'] as String,
        minSupportedCode: (row['min_supported_code'] as num?)?.toInt() ?? 0,
        downloadUrl: Uri.parse(row['download_url'] as String),
        notesEn: row['notes_en'] as String? ?? '',
        notesAr: row['notes_ar'] as String? ?? '',
      );

  final int versionCode;
  final String versionName;

  /// Installs below this version code must update before using the app.
  final int minSupportedCode;
  final Uri downloadUrl;
  final String notesEn, notesAr;

  /// The notes in [languageCode], or the other language's when that is empty.
  String notes(String languageCode) {
    final (first, second) =
        languageCode == 'ar' ? (notesAr, notesEn) : (notesEn, notesAr);
    return first.trim().isNotEmpty ? first.trim() : second.trim();
  }

  /// Whether [distribution] may open [downloadUrl]. The Play build only ever
  /// opens this app's own Play listing. The APK opens HTTPS links on the
  /// website or the Supabase project (where the files are stored), or that
  /// listing once the app has moved to Play, so a mistyped or tampered row
  /// cannot send people to another site's file.
  bool linkAllowedFor(AppDistribution distribution) {
    final url = downloadUrl;
    if (url.scheme != 'https' || url.hasPort && url.port != 443) return false;
    final playListing = url.host == 'play.google.com' &&
        url.path == '/store/apps/details' &&
        url.queryParameters['id'] == AppIdentity.applicationId;
    return switch (distribution) {
      AppDistribution.play => playListing,
      AppDistribution.apk => playListing ||
          {
            Uri.parse(AppIdentity.websiteUrl).host,
            if (SupabaseConfig.isConfigured) Uri.parse(SupabaseConfig.url).host,
          }.contains(url.host),
      AppDistribution.none => false,
    };
  }
}

/// Reads the newest published release of a channel. A stateless helper for
/// [AppUpdateController]; null when the backend is not configured or the
/// channel has no published release.
class AppReleaseService {
  const AppReleaseService();

  Future<AppRelease?> latest(String channel) async {
    if (!SupabaseConfig.isConfigured) return null;
    // Guests only see published rows (RLS); a master admin also sees drafts
    // and scheduled releases, so the filter is repeated here.
    final row = await Supabase.instance.client
        .from('app_releases')
        .select('version_code, version_name, min_supported_code, download_url, '
            'notes_en, notes_ar')
        .eq('channel', channel)
        .not('published_at', 'is', null)
        .lte('published_at', DateTime.now().toUtc().toIso8601String())
        .order('version_code', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : AppRelease.fromRow(row);
  }
}
