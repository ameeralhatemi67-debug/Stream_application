import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/map_models.dart';

/// High-Performance, Glitch-Free Spatial Streamer Marker Widget
/// Renders streamer & organization avatars across 3 streaming states:
/// 1. Offline (Static, zero CPU/GPU overhead)
/// 2. Live Video (Animated pinkish-red radar pulse & live viewer badge)
/// 3. Live Audio (Animated atmospheric gray radar pulse & headphone/mic badge)
/// Supports Organizations (squircle) vs Individuals (circle).
class SpatialStreamerMarker extends StatefulWidget {
  final MapMarkerModel marker;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final bool isSelected;

  const SpatialStreamerMarker({
    super.key,
    required this.marker,
    required this.onTap,
    required this.onDoubleTap,
    this.isSelected = false,
  });

  @override
  State<SpatialStreamerMarker> createState() => _SpatialStreamerMarkerState();
}

class _SpatialStreamerMarkerState extends State<SpatialStreamerMarker>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.85).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutCubic,
      ),
    );
    _opacityAnimation = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeOutCubic,
      ),
    );

    if (widget.marker.isLive) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(SpatialStreamerMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.marker.isLive != oldWidget.marker.isLive) {
      if (widget.marker.isLive) {
        if (!_pulseController.isAnimating) {
          _pulseController.repeat();
        }
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    if (widget.marker.isVideoLive) {
      return AppTheme.danger; // Pinkish-red
    } else if (widget.marker.isAudioLive) {
      return AppTheme.textMuted; // Atmospheric gray
    }
    return widget.isSelected
        ? AppTheme.primary
        : AppTheme.borderStrong;
  }

  Widget _buildAvatarImage() {
    final url = widget.marker.avatarUrl;
    final isAsset = url.startsWith('assets/');

    Widget imageWidget;
    if (isAsset) {
      imageWidget = Image.asset(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      );
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
      );
    } else {
      imageWidget = _buildFallbackIcon();
    }

    if (widget.marker.isOrganization) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10.0),
        child: imageWidget,
      );
    }

    return ClipOval(
      child: imageWidget,
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      color: AppTheme.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(
        widget.marker.isOrganization
            ? Icons.apartment_rounded
            : Icons.person_rounded,
        size: 20.0,
        color: AppTheme.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOrg = widget.marker.isOrganization;
    final isLive = widget.marker.isLive;
    final isVideo = widget.marker.isVideoLive;
    final isAudio = widget.marker.isAudioLive;
    final primaryAccent = _accentColor;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: isLive ? 52.0 : 44.0,
          height: isLive ? 52.0 : 44.0,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // 1. Radar Pulse Ring (Active only when streaming video or audio)
              if (isLive)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final opacity = _opacityAnimation.value.clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 40.0,
                        height: 40.0,
                        decoration: BoxDecoration(
                          shape: isOrg ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius:
                              isOrg ? BorderRadius.circular(14.0) : null,
                          color:
                              primaryAccent.withValues(alpha: opacity * 0.35),
                          border: Border.all(
                            color:
                                primaryAccent.withValues(alpha: opacity * 0.75),
                            width: 1.5,
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // 2. Main Avatar Body Container with Outer Stroke Ring & Transparent Gap
              Container(
                width: isLive ? 48.0 : 42.0,
                height: isLive ? 48.0 : 42.0,
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  shape: isOrg ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isOrg ? BorderRadius.circular(14.0) : null,
                  // Transparent background with outer stroke ring (floating avatar gap)
                  color: Colors.transparent,
                  border: Border.all(
                    color: widget.isSelected
                        ? AppTheme.primary
                        : (isLive ? primaryAccent : AppTheme.onMedia),
                    width: widget.isSelected ? 2.2 : 1.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isLive
                          ? primaryAccent.withValues(alpha: 0.45)
                          : AppTheme.media.withValues(alpha: 0.4),
                      blurRadius: widget.isSelected ? 10 : (isLive ? 8 : 4),
                      spreadRadius: isLive ? 1 : 0,
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: isLive ? 36.0 : 30.0,
                    height: isLive ? 36.0 : 30.0,
                    child: _buildAvatarImage(),
                  ),
                ),
              ),

              // 3. Status Badge Pill at Top (Live Video vs Live Audio)
              if (isLive)
                Positioned(
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5.0, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isVideo
                          ? AppTheme.danger
                          : AppTheme.media,
                      borderRadius: BorderRadius.circular(8.0),
                      border: isAudio
                          ? Border.all(
                              color: AppTheme.textMuted, width: 0.8)
                          : null,
                      boxShadow: const [
                        BoxShadow(
                          color: AppTheme.shadow,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isVideo) ...[
                          Container(
                            width: 4.5,
                            height: 4.5,
                            decoration: const BoxDecoration(
                              color: AppTheme.onMedia,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3.0),
                          Text(
                            widget.marker.viewerCount > 0
                                ? '${widget.marker.viewerCount}'
                                : 'LIVE',
                            style: const TextStyle(
                              color: AppTheme.onMedia,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                        ] else if (isAudio) ...[
                          const Icon(
                            Icons.mic_rounded,
                            size: 9.0,
                            color: AppTheme.onMedia,
                          ),
                          const SizedBox(width: 2.5),
                          Text('design_ui.audio'.tr(),
                            style: const TextStyle(
                              color: AppTheme.onMedia,
                              fontSize: 8.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // 4. Organization Indicator Icon at Bottom Right
              if (isOrg)
                PositionedDirectional(
                  bottom: -1,
                  end: -1,
                  child: Container(
                    width: 13.0,
                    height: 13.0,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryAccent,
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      size: 8.0,
                      color: primaryAccent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
