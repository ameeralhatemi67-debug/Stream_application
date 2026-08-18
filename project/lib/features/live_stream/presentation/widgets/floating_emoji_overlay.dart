import 'dart:math';
import 'package:flutter/material.dart';

/// Overlay widget that floats animated emoji keyframes upward over its child viewport.
class FloatingEmojiOverlay extends StatefulWidget {
  final Widget child;

  const FloatingEmojiOverlay({
    super.key,
    required this.child,
  });

  @override
  State<FloatingEmojiOverlay> createState() => FloatingEmojiOverlayState();
}

class FloatingEmojiOverlayState extends State<FloatingEmojiOverlay>
    with TickerProviderStateMixin {
  final List<_Particle> _particles = [];
  final Random _random = Random();

  /// Programmatically spawns a floating animated keyframe emoji particle over the viewport.
  void spawnEmoji(String emoji) {
    if (!mounted) return;

    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1800 + _random.nextInt(700)),
    );

    final startX = 0.15 + _random.nextDouble() * 0.70;
    final sway = (_random.nextDouble() * 40.0 - 20.0); // -20 to +20 px sway
    final particle = _Particle(
      id: UniqueKey().toString(),
      emoji: emoji,
      startXRatio: startX,
      swayAmplitude: sway,
      controller: controller,
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          setState(() {
            _particles.removeWhere((p) => p.id == particle.id);
          });
        }
        controller.dispose();
      }
    });

    setState(() {
      _particles.add(particle);
    });

    controller.forward();
  }

  @override
  void dispose() {
    for (final p in _particles) {
      p.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                return Stack(
                  children: _particles.map((p) {
                    return AnimatedBuilder(
                      animation: p.controller,
                      builder: (context, child) {
                        final progress = p.controller.value; // 0.0 -> 1.0
                        final yPos = height * (0.85 - (0.75 * progress));
                        final xSway = sin(progress * 2 * pi) * p.swayAmplitude;
                        final xPos = (width * p.startXRatio) + xSway;

                        // Opacity: stay 1.0 until 0.6 progress, then fade out
                        final opacity = (1.0 - progress).clamp(0.0, 1.0);

                        // Scale: quick pop scale up then steady
                        final scale = progress < 0.2
                            ? 0.5 + (progress / 0.2) * 0.7
                            : 1.2 - ((progress - 0.2) * 0.2);

                        return Positioned(
                          left: xPos.clamp(8.0, width - 40.0),
                          top: yPos,
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: Text(
                                p.emoji,
                                style: const TextStyle(
                                  fontSize: 28,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Particle {
  final String id;
  final String emoji;
  final double startXRatio;
  final double swayAmplitude;
  final AnimationController controller;

  _Particle({
    required this.id,
    required this.emoji,
    required this.startXRatio,
    required this.swayAmplitude,
    required this.controller,
  });
}
