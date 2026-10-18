import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/config/app_identity.dart';
import 'package:streamer_app/features/admin/models/terms_and_conditions_model.dart';

Iterable<String> _values(Object? value) sync* {
  if (value is String) {
    yield value;
  } else if (value is Map) {
    for (final child in value.values) {
      yield* _values(child);
    }
  } else if (value is List) {
    for (final child in value) {
      yield* _values(child);
    }
  }
}

void main() {
  const sentences = {
    'en':
        'Support cannot complete deletion of an Apple-linked account by email alone.',
    'ar':
        'لا يستطيع الدعم إكمال حذف الحساب المرتبط بـ Apple بالبريد الإلكتروني وحده.',
  };
  const unqualified = [
    'Support cannot complete deletion by email alone',
    'لا يستطيع الدعم إكمال الحذف بالبريد الإلكتروني وحده',
  ];
  for (final language in sentences.keys) {
    test('deletion catalog qualifies email limit $language', () {
      final catalog =
          jsonDecode(File('assets/i18n/$language.json').readAsStringSync())
              as Map;
      expect(catalog['settings']['delete_account_confirm_body'],
          contains(sentences[language]));
      for (final value in _values(catalog)) {
        for (final old in unqualified) {
          expect(value, isNot(contains(old)));
        }
      }
    });
    test('legal sections 7 and 9 qualify email limit $language', () {
      final legal = TermsAndConditionsModel.createDefault();
      final terms = legal.getLocalizedTerms(language);
      final privacy = legal.getLocalizedPrivacy(language);
      final section7 = terms
          .split(RegExp(r'^## 7\.', multiLine: true))
          .last
          .split(RegExp(r'^## 8\.', multiLine: true))
          .first;
      final section9 = privacy
          .split(RegExp(r'^## 9\.', multiLine: true))
          .last
          .split(RegExp(r'^## 10\.', multiLine: true))
          .first;
      expect(section7, contains(sentences[language]));
      expect(section9, contains(sentences[language]));
      expect(section9, contains(AppIdentity.deleteAccountUrl));
      expect(section9, contains(AppIdentity.supportEmail));
      for (final value in _values(legal.toJson())) {
        for (final old in unqualified) {
          expect(value, isNot(contains(old)));
        }
      }
    });
  }
}
