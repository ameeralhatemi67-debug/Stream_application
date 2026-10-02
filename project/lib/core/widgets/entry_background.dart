import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Quiet, layered corners shared by the splash and welcome screens.
class EntryBackground extends StatelessWidget {
  const EntryBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = (constraints.maxWidth * 0.65).clamp(180.0, 320.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.bg, AppTheme.surfaceAlt],
                    stops: [0.55, 1],
                  ),
                ),
              ),
              PositionedDirectional(
                top: -size * 0.35,
                end: -size * 0.38,
                child: _LayeredCorner(size: size),
              ),
              PositionedDirectional(
                bottom: -size * 0.4,
                start: -size * 0.45,
                child: _LayeredCorner(size: size),
              ),
              child,
            ],
          );
        },
      );
}

class _LayeredCorner extends StatelessWidget {
  const _LayeredCorner({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(AppTheme.space2Xl),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(AppTheme.space2Xl),
                boxShadow: AppTheme.entrySurfaceShadow,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.bg, AppTheme.surfaceAlt],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.spaceXl),
                  boxShadow: AppTheme.entrySurfaceShadow,
                ),
              ),
            ),
          ),
        ),
      );
}
