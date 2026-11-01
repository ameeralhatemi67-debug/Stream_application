import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/hidayah_gold.dart';

/// A bubble standing for pins that would otherwise touch. The ring shows the
/// mix: gold for mosques, slate for streamers. The small badges count what is
/// happening inside it: red is live in the app, green is at a mosque now.
class MapClusterBadge extends StatelessWidget {
  const MapClusterBadge({
    super.key,
    required this.count,
    required this.semanticLabel,
    required this.onTap,
    this.mosques = 0,
    this.live = 0,
    this.onSite = 0,
  });

  final int count, mosques, live, onSite;
  final String semanticLabel;
  final VoidCallback onTap;

  /// Grows with what it holds, within reason. The room around it is for the
  /// small badges.
  static double diameterFor(int count) => 46 + math.min(16, count * 1.6);
  static double boxFor(int count) => diameterFor(count) + 16;

  @override
  Widget build(BuildContext context) {
    final share = count == 0 ? 0.0 : mosques / count;
    final diameter = diameterFor(count);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: diameter,
                height: diameter,
                padding: const EdgeInsets.all(4.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    transform: const GradientRotation(-math.pi / 2),
                    stops: [0, share, share, 1],
                    colors: const [
                      HidayahGold.g500,
                      HidayahGold.g500,
                      HidayahGold.s500,
                      HidayahGold.s500
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x73151D24),
                        blurRadius: 10,
                        spreadRadius: -3,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: HidayahGold.s900),
                  child: Text('$count',
                      style: const TextStyle(
                          color: HidayahGold.g50,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
              ),
              if (live > 0 || onSite > 0)
                Positioned(
                  top: 0,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (live > 0) _CountDot(live, HidayahGold.live),
                    if (live > 0 && onSite > 0) const SizedBox(width: 2),
                    if (onSite > 0) _CountDot(onSite, HidayahGold.success),
                  ]),
                ),
            ]),
      ),
    );
  }
}

class _CountDot extends StatelessWidget {
  const _CountDot(this.count, this.color);
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 17),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: HidayahGold.card, width: 1.5),
        ),
        child: Text('$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: HidayahGold.card,
                fontSize: 9.5,
                height: 1.2,
                fontWeight: FontWeight.bold)),
      );
}
