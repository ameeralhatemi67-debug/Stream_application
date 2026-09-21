import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Renders the native RootEncoder camera preview (v0.7 Checkpoint 2,
/// Android only -- iOS gets its own native engine behind the same Dart
/// surface in v1.1). The Dart side never touches the camera itself; this
/// just mounts the platform view the native RtmpPublisherBridge renders into.
class PhoneCameraPreview extends StatelessWidget {
  static const String viewType = 'streamer_app/rtmp_camera_preview';

  const PhoneCameraPreview({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return ColoredBox(
        color: AppTheme.media,
        child: Center(
          child: Text('design_ui.phone_broadcasting_is_android_only_for_now'.tr(),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    return const AndroidView(
      viewType: viewType,
      creationParamsCodec: StandardMessageCodec(),
    );
  }
}
