import 'package:flutter/material.dart';
import '../../../../core/layout/window_class.dart';

/// Phones retain their fullscreen controls; wider windows use the pane rule.
bool isLaptopLiveLayout(BuildContext context) =>
    !context.isPhone && context.usesTwoPanes;

/// Browser and tablet text input remains editable, including short windows.
bool isCompactLandscapeChat(BuildContext context) => context.isPhoneLandscape;
