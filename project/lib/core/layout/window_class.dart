import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/canopy_tokens.dart';

enum WindowClass { compact, medium, expanded, large }

WindowClass windowClassFor(double width) => switch (width) {
      < CanopyWindow.medium => WindowClass.compact,
      < CanopyWindow.expanded => WindowClass.medium,
      < CanopyWindow.large => WindowClass.expanded,
      _ => WindowClass.large,
    };

extension WindowClassX on BuildContext {
  Size get _windowSize => MediaQuery.sizeOf(this);
  WindowClass get windowClass => windowClassFor(_windowSize.width);
  bool get isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) &&
      _windowSize.shortestSide < CanopyWindow.phoneShortestSideMax;
  bool get isLandscape => _windowSize.width >= _windowSize.height;
  bool get isPhoneLandscape => isPhone && isLandscape;
  bool get isShort => _windowSize.height < CanopySize.entryShortHeight;
  bool get usesTwoPanes =>
      _windowSize.width >= CanopyWindow.expanded ||
      (_windowSize.width >= CanopyWindow.paneLandscapeMinWidth && isLandscape);
  bool get usesPillNav =>
      windowClass == WindowClass.compact || isPhoneLandscape;
  double get windowInset => switch (windowClass) {
        WindowClass.compact => CanopyWindow.insetCompact,
        WindowClass.medium => CanopyWindow.insetMedium,
        WindowClass.expanded => CanopyWindow.insetExpanded,
        WindowClass.large => CanopyWindow.insetLarge,
      };
}
