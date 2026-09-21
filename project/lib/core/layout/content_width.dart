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

/// Centers its child, and scrolls rather than overflowing when the viewport is
/// too short to hold it.
///
/// Empty states, gates and short explanatory panels are written as a centered
/// [Column]. Such a column is taller than the space it gets on a landscape
/// phone (320 logical pixels tall, less the player and the tab bar) and at a
/// text scale of 2.0, and Flutter reports the difference as an overflow. This
/// keeps the centered composition wherever there is room for it and degrades
/// to a scroll where there is not, which is what the layout sweep checks at
/// 568x320 and scale 2.0.
class CenteredScrollable extends StatelessWidget {
  const CenteredScrollable({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final resolved = padding.resolve(Directionality.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight.isFinite
            ? (constraints.maxHeight - resolved.vertical)
                .clamp(0.0, double.infinity)
            : 0.0;
        return SingleChildScrollView(
          padding: resolved,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: available),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}
