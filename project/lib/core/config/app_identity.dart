/// Owner-supplied identity from brief/05_DECISIONS.md.
abstract final class AppIdentity {
  static const applicationId = 'sa.hadayah.streamer_app';
  static const nameEn = 'Hadayah Live';
  static const nameAr = 'منصة هدايه';
  static const supportEmail = 'ameeralhatemi67@gmail.com';
  static const privacyPolicyUrl = 'https://ameeralhatemi67-debug.github.io/privacy/';
  static String name(String languageCode) => languageCode == 'ar' ? nameAr : nameEn;
}
