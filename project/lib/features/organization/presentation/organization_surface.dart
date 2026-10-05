import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_navigation.dart';

/// Visual shell only: callers own every selector, route and server callback.
class OrganizationAppBar extends CaAppBar {
  OrganizationAppBar({super.key, Widget? title, super.leading, super.actions})
      : super(
            title: title == null ? null : _OrganizationBarTitle(child: title),
            toolbarHeight: CanopySize.appBarScaled,
            backgroundColor: Canopy.dawn,
            elevation: 0,
            compactLanguage: true,
            languageBare: true);
}

class _OrganizationBarTitle extends StatelessWidget {
  const _OrganizationBarTitle({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (child is! Text || (child as Text).data == null) return child;
    final text = child as Text;
    return LayoutBuilder(builder: (context, bounds) {
      final theme = Theme.of(context).textTheme;
      final style = text.style ?? theme.titleLarge!;
      final minimum = theme.labelSmall!.fontSize!;
      var size = style.fontSize ?? theme.titleLarge!.fontSize!;
      final painter = TextPainter(
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2);
      while (true) {
        painter.text =
            TextSpan(text: text.data, style: style.copyWith(fontSize: size));
        painter.layout(maxWidth: bounds.maxWidth);
        if ((!painter.didExceedMaxLines &&
                painter.height <= bounds.maxHeight - AppTheme.spaceSm) ||
            size <= minimum) {
          break;
        }
        size -= 1;
      }
      painter.dispose();
      return Text(text.data!,
          style: style.copyWith(fontSize: size),
          maxLines: 2,
          overflow: TextOverflow.ellipsis);
    });
  }
}

class OrganizationBody extends StatelessWidget {
  const OrganizationBody({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: CanopySize.organizationMax),
          child: SizedBox(width: double.infinity, child: child)));
}

class OrganizationCard extends StatelessWidget {
  const OrganizationCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTheme.spaceMd),
      child: CaCard(padding: EdgeInsets.zero, child: child));
}

class OrganizationTitle extends StatelessWidget {
  const OrganizationTitle({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CaAvatar(name: name, org: true),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
            child: Text(name, style: Theme.of(context).textTheme.titleMedium)),
      ]);
}

class OrganizationChip extends StatelessWidget {
  const OrganizationChip(
      {super.key,
      required this.label,
      this.icon = CaGlyph.user,
      this.available = false});
  final String label;
  final CaGlyph icon;
  final bool available;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
      decoration: BoxDecoration(
          color: Canopy.mint,
          borderRadius: BorderRadius.circular(CanopyRadius.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        CaIcon(icon,
            color: available ? Canopy.infoTeal : Canopy.brandGreen,
            size: CanopySize.inlineIcon),
        const SizedBox(width: AppTheme.spaceXs),
        Flexible(
            child: Text(label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: available ? Canopy.infoTeal : Canopy.brandGreen))),
      ]));
}

/// Independent server-backed checklist states; optional invite stays pending.
class OrganizationProgress extends StatelessWidget {
  const OrganizationProgress({super.key, required this.completed});
  final List<bool> completed;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: Padding(
          padding:
              const EdgeInsetsDirectional.symmetric(vertical: AppTheme.spaceMd),
          child: Row(children: [
            for (var i = 0; i < completed.length; i++) ...[
              if (i > 0) const SizedBox(width: AppTheme.spaceXs),
              Expanded(
                  child: Container(
                      height: CanopySize.stepBar,
                      decoration: BoxDecoration(
                          gradient: completed[i] ? AppGradients.pill : null,
                          color: completed[i] ? null : Canopy.mist,
                          borderRadius:
                              BorderRadius.circular(CanopyRadius.pill)))),
            ]
          ])));
}

/// A bounded dropdown retains its native transaction and menu semantics.
class OrganizationSwitcher extends StatelessWidget {
  const OrganizationSwitcher({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: AppTheme.spaceMd),
      child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
              color: Canopy.mint,
              borderRadius: BorderRadius.circular(CanopyRadius.card)),
          child: Row(children: [
            const CaIcon(CaGlyph.home),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(child: child)
          ])));
}

/// Stacked details/actions at every width keep 1.6 Arabic labels unconstrained.
class OrganizationDetailRow extends StatelessWidget {
  const OrganizationDetailRow(
      {super.key, required this.title, required this.details, this.action});
  final String title;
  final Widget details;
  final Widget? action;
  @override
  Widget build(BuildContext context) => OrganizationCard(
      child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CaAvatar(name: title, org: true),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleSmall)),
              if (action is PopupMenuButton<String>) action!,
            ]),
            const SizedBox(height: AppTheme.spaceSm),
            details,
            if (action != null && action is! PopupMenuButton<String>) ...[
              const SizedBox(height: AppTheme.spaceSm),
              action!,
            ],
          ])));
}
