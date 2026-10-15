import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/features/profile/presentation/settings/privacy_settings_section.dart';

import 'support/localized_app.dart';

void main() {
  setUpAll(initializeTestLocalization);

  test('export is refused while signed out instead of returning a partial file',
      () async {
    expect(await AppProvider().exportMyData(), isNull);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets(
        'every deletion refusal explains the next step (${locale.languageCode})',
        (tester) async {
      final texts = <String, String>{};
      await tester.pumpWidget(localizedApp(
        home: Builder(builder: (context) {
          if (context.locale != locale) {
            context.setLocale(locale);
          } else {
            for (final code in [
              ...AppProvider.accountDeletionBlockers,
              'failed',
            ]) {
              texts[code] = deleteAccountErrorText(code);
            }
          }
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();

      expect(texts.keys,
          containsAll([...AppProvider.accountDeletionBlockers, 'failed']));
      for (final entry in texts.entries) {
        expect(entry.value, isNot(startsWith('settings.')), reason: entry.key);
      }
      expect(texts['failed'], 'settings.delete_account_error_toast'.tr());
      expect(texts['account_restricted'], contains(AppIdentity.supportEmail));
      expect(texts['storage_cleanup_required'],
          contains(AppIdentity.supportEmail));
      expect(texts.values.toSet().length, texts.length,
          reason: 'each refusal has its own explanation');
    });
  }
}
