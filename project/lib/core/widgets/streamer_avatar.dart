import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'safe_image_provider.dart';

/// A round avatar that degrades to a neutral mark when there is no picture.
///
/// Five widgets each carried their own `_getImageProvider` that ended in
/// `NetworkImage(url)` with no empty-string guard, so a streamer without an
/// avatar produced a request for the app's own base URI, an HTTP 400 on every
/// rebuild, and a blank circle. This renders the person icon instead, and is
/// the one place that decision lives.
class StreamerAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;

  /// Ring drawn around the avatar, used by the feed card's live/offline state.
  final Color? borderColor;
  final double borderWidth;

  const StreamerAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 18,
    this.borderColor,
    this.borderWidth = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final provider = resolveImageProviderOrNull(avatarUrl);
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.surfaceAlt,
      backgroundImage: provider,
      // A URL that resolves but then fails (offline, 404) must not take the
      // surrounding screen down with it; the neutral circle is the fallback.
      onBackgroundImageError: provider == null ? null : (_, __) {},
      child: provider == null
          ? Icon(Icons.person_outline_rounded,
              size: radius, color: AppTheme.textMuted)
          : null,
    );
    final border = borderColor;
    if (border == null) return avatar;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: avatar,
    );
  }
}
