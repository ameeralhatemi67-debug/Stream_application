import 'package:flutter/material.dart';

/// A rotated phone can exceed 900 logical pixels along its long edge.
bool isLaptopLiveLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width >= 900 && size.height >= 600;
}

/// Only compact, rotated layouts need read-only chat and fullscreen video.
bool isCompactLandscapeChat(BuildContext context) {
  final media = MediaQuery.of(context);
  return !isLaptopLiveLayout(context) &&
      media.orientation == Orientation.landscape;
}
