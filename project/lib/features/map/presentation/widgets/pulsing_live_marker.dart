import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/streamer_avatar.dart';
import '../../models/map_models.dart';

class PulsingLiveMarker extends StatefulWidget {
  final MapMarkerModel marker;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final bool isSelected;
  final bool isVisible;

  const PulsingLiveMarker({
    super.key,
    required this.marker,
    required this.onTap,
    required this.onDoubleTap,
    this.isSelected = false,
    this.isVisible = true,
  });

  @override
  State<PulsingLiveMarker> createState() => _PulsingLiveMarkerState();
}

class _PulsingLiveMarkerState extends State<PulsingLiveMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    if (widget.isVisible) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(PulsingLiveMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.repeat();
      } else {
        _animationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Animated Radar Pulsing Ring
            if (widget.isVisible)
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.danger
                            .withValues(alpha: _opacityAnimation.value * 0.4),
                        border: Border.all(
                          color: AppTheme.danger
                              .withValues(alpha: _opacityAnimation.value * 0.7),
                          width: 1.2,
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Core Marker Pin Body
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Transparent background with outer stroke ring (floating avatar gap)
                color: Colors.transparent,
                border: Border.all(
                  color: widget.isSelected
                      ? AppTheme.primary
                      : AppTheme.danger,
                  width: widget.isSelected ? 2.2 : 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.danger.withValues(alpha: 0.5),
                    blurRadius: widget.isSelected ? 12 : 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Center(
                child: StreamerAvatar(
                    radius: 17, avatarUrl: widget.marker.avatarUrl),
              ),
            ),

            // Live Pill Badge at top
            Positioned(
              top: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppTheme.onMedia,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.marker.viewerCount}',
                      style: const TextStyle(
                        color: AppTheme.onMedia,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
