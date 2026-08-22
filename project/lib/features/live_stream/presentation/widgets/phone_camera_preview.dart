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
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Phone broadcasting is Android-only for now.',
            style: TextStyle(color: Colors.white70),
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
