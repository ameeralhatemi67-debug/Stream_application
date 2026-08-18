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
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.darkSurface1,
            border: Border.all(
              color: isSelected ? AppTheme.accentBlue : AppTheme.textMutedDark,
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
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
              radius: 16,
              backgroundColor: AppTheme.darkSurface2,
              backgroundImage: _getAvatarProvider(marker.avatarUrl),
              onBackgroundImageError: (_, __) {},
            ),
          ),
        ),
      ),
    );
  }
}
