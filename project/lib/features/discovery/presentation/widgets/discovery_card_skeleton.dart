import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_feedback.dart';

/// Discovery-only loading shape matching StreamerGridCard's banner and avatar.
class DiscoveryCardSkeleton extends StatelessWidget {
  const DiscoveryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const CaCard(
      padding: EdgeInsets.zero,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CaSkeleton(width: double.infinity, height: 128),
        Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceLg),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  height: 38,
                  child: Stack(clipBehavior: Clip.none, children: [
                    PositionedDirectional(
                        start: 0,
                        top: -34,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: Canopy.paper, shape: BoxShape.circle),
                            child: Padding(
                                padding: EdgeInsets.all(2),
                                child: CaSkeleton(
                                    shape: CaSkeletonShape.avatar,
                                    width: 68,
                                    height: 68)))),
                    PositionedDirectional(
                        start: 84,
                        end: 0,
                        top: AppTheme.spaceMd,
                        child: FractionallySizedBox(
                            alignment: AlignmentDirectional.centerStart,
                            widthFactor: .65,
                            child: CaSkeleton(height: 12))),
                  ])),
              SizedBox(height: AppTheme.spaceXs),
              FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: .58,
                  child: CaSkeleton(height: 12)),
              SizedBox(height: AppTheme.spaceMd),
              Row(children: [
                CaSkeleton(width: 42, height: 24),
                SizedBox(width: AppTheme.spaceXs),
                CaSkeleton(width: 72, height: 24),
              ]),
            ])),
      ]));
}

class DiscoveryCardSkeletonGrid extends StatelessWidget {
  const DiscoveryCardSkeletonGrid({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
      label: 'ds.loading'.tr(),
      liveRegion: true,
      child: ExcludeSemantics(
          child: LayoutBuilder(builder: (context, constraints) {
        final columns = (constraints.maxWidth / 300).floor().clamp(1, 4);
        final width =
            ((constraints.maxWidth - AppTheme.spaceMd * (columns - 1)) /
                    columns)
                .clamp(0.0, 420.0);
        return Wrap(
            spacing: AppTheme.spaceMd,
            runSpacing: AppTheme.spaceMd,
            children: List.generate(
                5,
                (_) => SizedBox(
                    width: width, child: const DiscoveryCardSkeleton())));
      })));
}
