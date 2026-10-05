import 'package:flutter/material.dart';
import '../../layout/content_width.dart';
import '../../layout/window_class.dart';
import '../../theme/app_theme.dart';
import 'ca_navigation.dart';

/// The navigation branch stays under the same Row/Expanded/content ancestors
/// when the pill, rail and content cap change on resize.
class CaShell extends StatelessWidget {
  const CaShell(
      {super.key,
      required this.child,
      required this.index,
      required this.onChanged,
      required this.role,
      this.overlay});
  final Widget child;
  final int index;
  final ValueChanged<int> onChanged;
  final String role;
  final Widget? overlay;
  @override
  Widget build(BuildContext context) {
    final pill = context.usesPillNav;
    final content = SafeArea(
        top: false,
        bottom: false,
        child: ContentWidth(
            maxWidth: context.windowClass == WindowClass.large
                ? CanopyWindow.contentMax
                : double.infinity,
            child: child));
    return Scaffold(
        backgroundColor: Canopy.dawn,
        extendBody: pill,
        body: Stack(children: [
          Row(children: [
            if (!pill)
              CaRail(
                  index: index,
                  onChanged: onChanged,
                  role: role,
                  expanded:
                      context.windowClass.index >= WindowClass.expanded.index),
            Expanded(child: Semantics(container: true, child: content)),
          ]),
          if (overlay != null) overlay!
        ]),
        bottomNavigationBar:
            pill ? CaNavBar(index: index, onChanged: onChanged) : null);
  }
}

/// The caller supplies its compact composition (tabs/forms can differ there).
/// The fixed pane uses directional row order, so RTL mirrors automatically.
class CaPane extends StatelessWidget {
  const CaPane(
      {super.key,
      required this.single,
      required this.primary,
      required this.secondary,
      this.secondaryAtStart = false,
      this.secondaryWidth = CanopySize.paneMedium,
      this.largeSecondaryWidth = CanopySize.paneLarge});
  final Widget single, primary, secondary;
  final bool secondaryAtStart;
  final double secondaryWidth, largeSecondaryWidth;
  @override
  Widget build(BuildContext context) {
    if (!context.usesTwoPanes) return single;
    final side = SizedBox(
        width: context.windowClass == WindowClass.large
            ? largeSecondaryWidth
            : secondaryWidth,
        child: secondary);
    final main = Expanded(child: primary);
    const gap = SizedBox(width: AppTheme.spaceLg);
    return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: secondaryAtStart ? [side, gap, main] : [main, gap, side]);
  }
}
