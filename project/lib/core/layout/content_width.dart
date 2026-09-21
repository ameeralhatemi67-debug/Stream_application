import 'package:flutter/material.dart';

abstract final class AppBreakpoints {
  static const compact = 600.0;
  static const expanded = 900.0;
  static const content = 720.0;
}

/// Centers forms and lists while preserving the available viewport height.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = AppBreakpoints.content});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
  );
}
