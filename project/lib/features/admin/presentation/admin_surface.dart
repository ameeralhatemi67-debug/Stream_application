import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds/ca_cards.dart';

/// Quiet admin surfaces; existing controllers and actions own all state.
class AdminCard extends StatelessWidget {
  const AdminCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(AppTheme.spaceLg),
      this.margin,
      this.width,
      this.height,
      this.constraints});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? width, height;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) => Container(
      margin: margin,
      width: width,
      height: height,
      constraints: constraints,
      child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
              border: Border.all(color: Canopy.hairline),
              borderRadius: BorderRadius.circular(CanopyRadius.card)),
          child: CaCard(
              variant: CaCardVariant.flat, padding: padding, child: child)));
}

class AdminCount extends StatelessWidget {
  const AdminCount({super.key, required this.count, required this.label});
  final int count;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$label: $count',
      child: ExcludeSemantics(
          child: Container(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
              decoration: BoxDecoration(
                  gradient: CanopyGradients.pill,
                  borderRadius: BorderRadius.circular(CanopyRadius.pill)),
              child: Text('$count',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: Canopy.paper)))));
}

/// Reflows dense identity/action rows when translated or scaled text needs room.
class AdminFlow extends StatelessWidget {
  const AdminFlow(
      {super.key,
      required this.children,
      this.mainAxisAlignment = MainAxisAlignment.start,
      this.crossAxisAlignment = CrossAxisAlignment.center});
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        if (box.maxWidth >= CanopyWindow.medium) {
          return Row(
              mainAxisAlignment: mainAxisAlignment,
              crossAxisAlignment: crossAxisAlignment,
              children: children);
        }
        final content = <Widget>[];
        final actions = <Widget>[];
        for (final child in children) {
          if (child is Spacer) continue;
          if (child is SizedBox && child.width != null && child.child == null) {
            continue;
          }
          if (child is IconButton || child is ButtonStyleButton) {
            actions.add(child);
          } else {
            content.add(child is Flexible ? child.child : child);
          }
        }
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < content.length; i++) ...[
                if (i > 0) const SizedBox(height: AppTheme.spaceSm),
                Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: content[i]),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Wrap(
                    spacing: AppTheme.spaceSm,
                    runSpacing: AppTheme.spaceSm,
                    children: actions),
              ],
            ]);
      });
}
