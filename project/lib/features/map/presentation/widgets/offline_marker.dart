import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/map_models.dart';

class OfflineMarker extends StatelessWidget {
  final MapMarkerModel marker;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final bool isSelected;

  const OfflineMarker({
    super.key,
    required this.marker,
    required this.onTap,
    required this.onDoubleTap,
    this.isSelected = false,
  });

  ImageProvider _getAvatarProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.onMedia,
              width: isSelected ? 2.2 : 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.media.withValues(alpha: 0.4),
                blurRadius: isSelected ? 10 : 4,
              ),
            ],
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(
              Colors.grey,
              BlendMode.saturation,
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.surfaceAlt,
              backgroundImage: _getAvatarProvider(marker.avatarUrl),
              onBackgroundImageError: (_, __) {},
            ),
          ),
        ),
      ),
    );
  }
}
