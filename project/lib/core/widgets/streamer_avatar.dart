import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'safe_image_provider.dart';

/// A round (or rounded-square, for organizations) avatar that degrades to a
/// visible placeholder when there is no picture or the picture fails to load.
///
/// Five widgets each carried their own `_getImageProvider` that ended in
/// `NetworkImage(url)` with no empty-string guard, so a streamer without an
/// avatar produced a request for the app's own base URI, an HTTP 400 on every
/// rebuild, and a blank circle. A URL that resolves but then fails (a Google
/// photo returning 429, a deleted upload) also left only the pale background
/// -- the "blank white circle" in the P6 retest (S02). The placeholder is the
/// name's first letter when a name is known, otherwise a person icon.
class StreamerAvatar extends StatelessWidget {
  final String? avatarUrl;
  final double radius;

  /// Used for the initial shown when there is no usable picture.
  final String? name;

  /// Organizations use a rounded square instead of a circle.
  final bool square;

  /// Ring drawn around the avatar, used by the feed card's live/offline state.
  final Color? borderColor;
  final double borderWidth;
  final Widget? placeholder;
  /// Opt-in placeholder only until the image's first frame is ready.
  final Widget? loadingPlaceholder;
  final double? cornerRadius;

  const StreamerAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 18,
    this.name,
    this.square = false,
    this.borderColor,
    this.borderWidth = 1.2,
    this.placeholder,
    this.loadingPlaceholder,
    this.cornerRadius,
  });

  @override
  Widget build(BuildContext context) {
    final provider = resolveImageProviderOrNull(avatarUrl);
    final size = radius * 2;
    final fallback = placeholder ?? _Placeholder(name: name, radius: radius);
    final content = provider == null
        ? fallback
        : Image(
            // Decode at the pixel size actually drawn, not the source size.
            image: downscaledImage(
              provider,
              width: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            ),
            width: size,
            height: size,
            fit: BoxFit.cover,
            frameBuilder: loadingPlaceholder == null
                ? null
                : (_, child, frame, synchronous) =>
                    synchronous || frame != null ? child : loadingPlaceholder!,
            // A URL that resolves but then fails must not leave an empty
            // shape or take the surrounding screen down with it.
            errorBuilder: (_, __, ___) => fallback,
          );
    final shaped = square
        ? ClipRRect(
            borderRadius: BorderRadius.circular(cornerRadius ?? radius * 0.42),
            child: SizedBox.square(dimension: size, child: content),
          )
        : ClipOval(child: SizedBox.square(dimension: size, child: content));
    final border = borderColor;
    if (border == null) return shaped;
    return Container(
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius:
            square ? BorderRadius.circular((cornerRadius ?? radius * 0.42) + borderWidth) : null,
        border: Border.all(color: border, width: borderWidth),
      ),
      child: shaped,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.name, required this.radius});
  final String? name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final trimmed = name?.trim() ?? '';
    final initial =
        trimmed.isEmpty ? null : String.fromCharCodes(trimmed.runes.take(1));
    return ColoredBox(
      color: AppTheme.primary.withValues(alpha: 0.12),
      child: Center(
        child: initial == null
            ? Icon(Icons.person_outline_rounded,
                size: radius, color: AppTheme.primary)
            : Text(
                initial.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.9,
                ),
              ),
      ),
    );
  }
}
