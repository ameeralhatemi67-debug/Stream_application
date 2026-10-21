import '../../../../core/widgets/ds/canopy_motion.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'dart:math';
import 'package:flutter/material.dart';

const raisedHandGlyph = '✋';
const loweredHandGlyph = '$raisedHandGlyph↓';

/// Keyframe floating emoji animation overlay drifting upward over the video viewport.
class FloatingReactionsOverlay extends StatefulWidget {
  final FloatingReactionsOverlayController? controller;

  const FloatingReactionsOverlay({super.key, this.controller});

  @override
  State<FloatingReactionsOverlay> createState() =>
      FloatingReactionsOverlayState();
}

class FloatingReactionsOverlayController {
  FloatingReactionsOverlayState? _state;

  void attach(FloatingReactionsOverlayState state) {
    _state = state;
  }

  void detach() {
    _state = null;
  }

  void spawnReaction(String reactionType) {
    _state?.spawnReaction(reactionType);
  }
}

class FloatingReactionsOverlayState extends State<FloatingReactionsOverlay> {
  final List<({String id, String glyph, double start})> _particles = [];
  final Random _random = Random();
  static const int maxConcurrentParticles = 20;
  @override
  void initState() {
    super.initState();
    widget.controller?.attach(this);
  }

  @override
  void didUpdateWidget(FloatingReactionsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach();
      widget.controller?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach();
    super.dispose();
  }

  void spawnReaction(String reactionType) {
    if (_particles.length >= maxConcurrentParticles) return;
    final glyph = switch (reactionType) {
      'clap' => liveReactionGlyphs['clap']!,
      'raise_hand' => raisedHandGlyph,
      'idea' => liveReactionGlyphs['idea']!,
      'fire' => liveReactionGlyphs['fire']!,
      'scholar' => liveReactionGlyphs['scholar']!,
      _ => liveReactionGlyphs['heart']!,
    };
    final particle = (
      id: 'particle_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1000)}',
      glyph: glyph,
      start: .65 + _random.nextDouble() * .25
    );
    setState(() => _particles.add(particle));
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: LayoutBuilder(
          builder: (context, constraints) => Stack(children: [
                for (final particle in _particles)
                  PositionedDirectional(
                    start: constraints.maxWidth * particle.start,
                    bottom: AppTheme.spaceLg,
                    child: RepaintBoundary(
                        child: CaFloatingReaction(
                            key: ValueKey(particle.id),
                            onComplete: () {
                              if (mounted) {
                                setState(() => _particles
                                    .removeWhere((p) => p.id == particle.id));
                              }
                            },
                            child: Container(
                                padding: const EdgeInsets.all(AppTheme.spaceSm),
                                decoration: BoxDecoration(
                                    color: Canopy.canopy900,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Canopy.mist)),
                                child: Text(particle.glyph,
                                    style: const TextStyle(
                                        fontSize: CanopySize.reactionIcon))))),
                  ),
              ])));
}

const liveReactionGlyphs = <String, String>{
  'heart': '❤️',
  'clap': '👏',
  'hand': '✋',
  'fire': '🔥',
  'idea': '💡',
  'scholar': '🎓'
};
