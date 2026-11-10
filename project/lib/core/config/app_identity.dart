/// Owner-supplied identity from brief/05_DECISIONS.md.
///
/// The public pages all live on one origin (the web app's own domain) because
/// Google sign-in verification requires the privacy policy to be on the same
/// domain as the app's home page. Since 2026-11-10 that domain is
/// live.hedayh.org.sa; to move again, change [websiteUrl] only (the page URLs
/// derive from it).
abstract final class AppIdentity {
  static const applicationId = 'sa.hadayah.streamer_app';
  static const nameEn = 'Hadayah Live';
  static const nameAr = 'منصة هدايه';
  static const supportEmail = 'livesupport@hedayh.org.sa';
  static const websiteUrl = 'https://live.hedayh.org.sa';
  /// Static home page for Google verification and the store listing. The web
  /// root is the Flutter app itself, which has no crawlable text.
  static const homePageUrl = '$websiteUrl/about.html';
  static const privacyPolicyUrl = '$websiteUrl/privacy.html';
  static const termsUrl = '$websiteUrl/terms.html';
  static const deleteAccountUrl = '$websiteUrl/delete-account.html';
  static String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}
