import 'dart:math';
import 'package:flutter/material.dart';

class FloatingParticleData {
  final String id;
  final String emoji;
  final double startX;
  final AnimationController controller;
  final Animation<double> yAnimation;
  final Animation<double> opacityAnimation;
  final Animation<double> scaleAnimation;

  FloatingParticleData({
    required this.id,
    required this.emoji,
    required this.startX,
    required this.controller,
    required this.yAnimation,
    required this.opacityAnimation,
    required this.scaleAnimation,
  });
}

/// Keyframe floating emoji animation overlay drifting upward over the video viewport.
class FloatingReactionsOverlay extends StatefulWidget {
  final FloatingReactionsOverlayController? controller;

  const FloatingReactionsOverlay({super.key, this.controller});

  @override
  State<FloatingReactionsOverlay> createState() => FloatingReactionsOverlayState();
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

class FloatingReactionsOverlayState extends State<FloatingReactionsOverlay>
    with TickerProviderStateMixin {
  final List<FloatingParticleData> _particles = [];
  final Random _random = Random();

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
    for (var particle in _particles) {
      particle.controller.dispose();
    }
    _particles.clear();
    super.dispose();
  }

  void spawnReaction(String reactionType) {
    String emoji = '❤️';
    if (reactionType == 'clap') {
      emoji = '👏';
    } else if (reactionType == 'raise_hand') {
      emoji = '✋';
    } else if (reactionType == 'heart') {
      emoji = '❤️';
    }

    final id = 'particle_${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1000)}';
    final startX = 0.65 + _random.nextDouble() * 0.25; // 65% to 90% of screen width

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    final yAnimation = Tween<double>(begin: 0.85, end: 0.15).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
    );

    final opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(controller);

    final scaleAnimation = Tween<double>(begin: 0.6, end: 1.2).animate(
      CurvedAnimation(parent: controller, curve: Curves.elasticOut),
    );

    final particle = FloatingParticleData(
      id: id,
      emoji: emoji,
      startX: startX,
      controller: controller,
      yAnimation: yAnimation,
      opacityAnimation: opacityAnimation,
      scaleAnimation: scaleAnimation,
    );

    setState(() {
      _particles.add(particle);
    });

    controller.forward().then((_) {
      if (mounted) {
        setState(() {
          _particles.removeWhere((p) => p.id == id);
        });
        controller.dispose();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;

          return Stack(
            children: _particles.map((particle) {
              return AnimatedBuilder(
                animation: particle.controller,
                builder: (context, child) {
                  final x = width * particle.startX + sin(particle.controller.value * 6) * 12;
                  final y = height * particle.yAnimation.value;

                  return Positioned(
                    left: x,
                    top: y,
                    child: Opacity(
                      opacity: particle.opacityAnimation.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: particle.scaleAnimation.value,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.2),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            particle.emoji,
                            style: const TextStyle(fontSize: 24),
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
    );
  }
}
