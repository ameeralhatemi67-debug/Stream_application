import 'package:flutter/widgets.dart';

/// The direction a piece of user-written text reads in, from its first
/// strongly directional letter: an English chat message in the Arabic app
/// reads left to right, and an Arabic one in the English app right to left.
/// Digits, punctuation, symbols and emoji are skipped. Null when the text has
/// no letters, so the caller keeps the surrounding direction (audit
/// 2026-10-21, P1-26).
///
/// intl's Bidi.startsWithLtr is not used: it counts emoji (surrogate pairs)
/// as left-to-right letters, so a smiley before Arabic text read left to right.
TextDirection? firstStrongTextDirection(String text) {
  for (final rune in text.runes) {
    if (_inRanges(rune, _rtlLetters)) return TextDirection.rtl;
    if (_inRanges(rune, _ltrLetters)) return TextDirection.ltr;
  }
  return null;
}

/// [text] wrapped in first-strong isolate marks (FSI ... PDI), so a name or
/// message of the other direction inside a sentence keeps its own order.
String isolateDirection(String text) =>
    '${String.fromCharCode(0x2068)}$text${String.fromCharCode(0x2069)}';

bool _inRanges(int rune, List<(int, int)> ranges) {
  for (final (start, end) in ranges) {
    if (rune < start) return false;
    if (rune <= end) return true;
  }
  return false;
}

/// Hebrew, Arabic, Syriac, Thaana, NKo, Samaritan, Mandaic, their
/// presentation forms and the historic right-to-left scripts. Sorted.
const _rtlLetters = [
  (0x0590, 0x08FF),
  (0xFB1D, 0xFDFF),
  (0xFE70, 0xFEFE),
  (0x10800, 0x10FFF),
  (0x1E800, 0x1EFFF),
];

/// Letters of the left-to-right scripts (Latin, Greek, Cyrillic, Armenian,
/// Indic, South-East Asian, CJK, Hangul...). Sorted.
const _ltrLetters = [
  (0x0041, 0x005A),
  (0x0061, 0x007A),
  (0x00C0, 0x00D6),
  (0x00D8, 0x00F6),
  (0x00F8, 0x02B8),
  (0x0370, 0x058F),
  (0x0900, 0x1FFF),
  (0x2C00, 0x2DFF),
  (0x3040, 0x9FFF),
  (0xA000, 0xD7AF),
  (0xF900, 0xFB1C),
  (0xFF21, 0xFF3A),
  (0xFF41, 0xFF5A),
  (0x10000, 0x107FF),
  (0x20000, 0x3FFFF),
];
