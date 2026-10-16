import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/config/app_identity.dart';

void main() {
  test('public pages share one https origin (Google verification needs this)', () {
    final site = Uri.parse(AppIdentity.websiteUrl);
    final privacy = Uri.parse(AppIdentity.privacyPolicyUrl);
    final delete = Uri.parse(AppIdentity.deleteAccountUrl);

    final home = Uri.parse(AppIdentity.homePageUrl);

    expect(site.scheme, 'https');
    expect(home.host, site.host);
    expect(home.path, '/about.html');
    expect(privacy.host, site.host);
    expect(delete.host, site.host);
    expect(privacy.path, '/privacy.html');
    expect(delete.path, '/delete-account.html');
  });

  test('each public page is shipped in the web build and names the app', () {
    for (final name in ['about.html', 'privacy.html', 'delete-account.html']) {
      final page = File('web/$name');
      expect(page.existsSync(), isTrue, reason: '$name missing from project/web');
      final html = page.readAsStringSync();
      expect(html, contains(AppIdentity.nameEn), reason: name);
      expect(html, contains(AppIdentity.nameAr), reason: name);
      expect(html, contains(AppIdentity.supportEmail), reason: name);
      expect(html.toLowerCase(), isNot(contains('dalilk')),
          reason: '$name still carries the old product name');
    }
  });

  test('the privacy page covers the YouTube scope and the Limited Use promise', () {
    final html = File('web/privacy.html').readAsStringSync();
    expect(html, contains('youtube.force-ssl'));
    expect(html, contains('Limited Use'));
    expect(html, contains('/delete-account.html'));
  });
}
