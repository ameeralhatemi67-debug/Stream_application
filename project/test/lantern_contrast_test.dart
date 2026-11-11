import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/theme/lantern/lantern_tokens.dart';

/// Contrast of the Lantern and Arch colours (ADR-026), by the WCAG 2
/// formula. Text needs 4.5:1. The pairs below are the ones the kit and the
/// screens put together; a new pairing belongs here before it is used.
double _channel(double c) =>
    c <= .03928 ? c / 12.92 : math.pow((c + .055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    .2126 * _channel(c.r) + .7152 * _channel(c.g) + .0722 * _channel(c.b);

double contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

void main() {
  for (final (name, t) in [
    ('day', LanternTokens.day),
    ('night', LanternTokens.dark)
  ]) {
    group(name, () {
      final grounds = {
        'bg': t.bg,
        'surface': t.surface,
        'raised': t.raised,
        'sunk': t.sunk
      };

      test('main, secondary and gold text pass on every ground', () {
        for (final MapEntry(key: ground, value: colour) in grounds.entries) {
          for (final (label, text) in [
            ('fg', t.fg),
            ('muted', t.muted),
            ('goldInk', t.goldInk)
          ]) {
            expect(contrast(text, colour), greaterThanOrEqualTo(4.5),
                reason: '$label on $ground');
          }
        }
      });

      test('each state colour passes on its own soft ground', () {
        for (final (label, text, ground) in [
          ('live', t.liveText, t.liveSoft),
          ('audio', t.audio, t.audioSoft),
          ('ok', t.ok, t.okSoft),
          ('warn', t.warn, t.warnSoft),
          ('mod', t.mod, t.modSoft),
        ]) {
          expect(contrast(text, ground), greaterThanOrEqualTo(4.5),
              reason: label);
        }
        expect(contrast(t.liveText, t.surface), greaterThanOrEqualTo(4.5));
      });

      test('faint is for captions that do not matter: below 4.5, above 3', () {
        final ratio = contrast(t.faint, t.surface);
        expect(ratio, lessThan(4.5));
        expect(ratio, greaterThanOrEqualTo(3));
      });
    });
  }

  test('ink passes on gold, and white on the solid state grounds', () {
    expect(contrast(LanternTokens.onGold, LanternTokens.gold),
        greaterThanOrEqualTo(4.5));
    expect(contrast(LanternTokens.onGold, LanternTokens.goldHi),
        greaterThanOrEqualTo(4.5));
    expect(contrast(LanternTokens.onGold, LanternTokens.goldTop),
        greaterThanOrEqualTo(4.5));
    for (final fill in [
      LanternTokens.liveFill,
      LanternTokens.okFill,
      LanternTokens.audioFill,
      LanternTokens.ink,
      LanternTokens.nightGround,
    ]) {
      expect(contrast(LanternTokens.white, fill), greaterThanOrEqualTo(4.5),
          reason: '$fill');
    }
  });

  test('white on the night state colours fails, which is why the fills exist',
      () {
    // If these ever pass, the fills can go.
    expect(contrast(LanternTokens.white, LanternTokens.dark.ok), lessThan(4.5));
    expect(
        contrast(LanternTokens.white, LanternTokens.dark.audio), lessThan(4.5));
    expect(
        contrast(LanternTokens.white, LanternTokens.dark.live), lessThan(4.5));
  });

  test('gold on the night ground passes; gold on white is for marks only', () {
    expect(contrast(LanternTokens.goldHi, LanternTokens.nightGround),
        greaterThanOrEqualTo(4.5));
    expect(contrast(LanternTokens.dark.muted, LanternTokens.nightGround),
        greaterThanOrEqualTo(4.5));
    // Plain gold as text on white is below AA: use goldInk for text.
    expect(contrast(LanternTokens.gold, LanternTokens.white), lessThan(4.5));
  });
}
