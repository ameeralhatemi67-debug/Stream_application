import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/theme/app_theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  test('scheme A surfaces, accents and gradient stops meet AA', () {
    for (final bg in [AppTheme.bg, AppTheme.surface, AppTheme.surfaceAlt]) {
      for (final fg in [AppTheme.textPrimary, AppTheme.textSecondary,
        AppTheme.textMuted, AppTheme.primary, AppTheme.success,
        AppTheme.warning, AppTheme.danger]) {
        expect(contrast(fg, bg), greaterThanOrEqualTo(4.5), reason: '$fg on $bg');
      }
    }
    for (final bg in AppGradients.brand.colors) {
      expect(contrast(AppTheme.onPrimary, bg), greaterThanOrEqualTo(4.5));
    }
    for (final bg in AppGradients.soft.colors) {
      expect(contrast(AppTheme.textPrimary, bg), greaterThanOrEqualTo(4.5));
    }
    expect(contrast(AppTheme.onMedia, AppTheme.media), greaterThanOrEqualTo(4.5));
    expect(contrast(AppTheme.borderStrong, AppTheme.surface), greaterThanOrEqualTo(3));
    expect(contrast(AppTheme.textMuted, AppTheme.disabled), greaterThanOrEqualTo(4.5));
  });

  test('locale typography matches the selected specification and bundled fonts', () {
    final spec = jsonDecode(File('../brief/assets/design_options/tokens_A.json').readAsStringSync());
    for (final lang in ['en', 'ar']) {
      final theme = AppTheme.forLocale(Locale(lang));
      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(theme.textTheme.bodyLarge!.fontSize, spec['typeScale']['body']['size']);
      expect(theme.textTheme.bodyLarge!.height, lang == 'ar' ? 1.8 : 1.4);
      expect(theme.textTheme.titleLarge!.height, lang == 'ar' ? 1.6 : 1.4);
    }
    for (final name in ['IBMPlexSans-Variable.ttf', 'IBMPlexSansArabic-400.ttf', 'IBMPlexSansArabic-700.ttf']) {
      expect(File('assets/fonts/$name').lengthSync(), greaterThan(200000));
    }
  });
}
