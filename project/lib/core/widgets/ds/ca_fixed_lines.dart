import 'package:flutter/material.dart';

/// Text that always occupies exactly [lines] lines, however short it is, so
/// cards with different titles come out the same height. Line height is forced
/// (and scales with the user's text size), so Arabic and Latin lines match.
class CaFixedLines extends StatelessWidget {
  const CaFixedLines(this.text,
      {super.key, required this.style, this.lines = 2});
  final String text;
  final TextStyle? style;
  final int lines;

  /// Line height as a multiple of the font size.
  static const lineHeight = 1.3;

  /// The height [lines] lines take at the current text size.
  static double heightOf(BuildContext context, TextStyle? style, int lines) =>
      MediaQuery.textScalerOf(context).scale(style?.fontSize ?? 14) *
      lineHeight *
      lines;

  @override
  Widget build(BuildContext context) => SizedBox(
      height: heightOf(context, style, lines),
      child: Text(text,
          maxLines: lines,
          overflow: TextOverflow.ellipsis,
          style: style,
          strutStyle: StrutStyle(
              fontSize: style?.fontSize ?? 14,
              fontFamily: style?.fontFamily,
              fontFamilyFallback: style?.fontFamilyFallback,
              height: lineHeight,
              forceStrutHeight: true)));
}
