import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/rtmp_publish_engine.dart';

/// Mounts the platform preview only after the opted-in iOS bridge is present.
class PhoneCameraPreview extends StatefulWidget {
  static const String viewType = 'streamer_app/rtmp_camera_preview';

  const PhoneCameraPreview({super.key});

  @override
  State<PhoneCameraPreview> createState() => _PhoneCameraPreviewState();
}

class _PhoneCameraPreviewState extends State<PhoneCameraPreview> {
  late final Future<bool> _iosAvailable =
      RtmpPublishEngine.iosNativePublisherAvailable();

  Widget _unavailable(String key) => ColoredBox(
        color: AppTheme.media,
        child: Center(
            child: Text(key.tr(),
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: AppTheme.onMedia.withValues(alpha: 0.7)))),
      );

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return const IgnorePointer(
          child: AndroidView(
        viewType: PhoneCameraPreview.viewType,
        creationParamsCodec: StandardMessageCodec(),
      ));
    }
    if (iosPhonePublishingEnabled) {
      return FutureBuilder<bool>(
        future: _iosAvailable,
        builder: (context, snapshot) => snapshot.data == true
            ? const IgnorePointer(
                child: UiKitView(
                viewType: PhoneCameraPreview.viewType,
                creationParamsCodec: StandardMessageCodec(),
              ))
            : _unavailable('live.ios_publisher_unavailable'),
      );
    }
    return _unavailable(!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
        ? 'live.ios_publisher_unavailable'
        : 'design_ui.phone_broadcasting_is_android_only_for_now');
  }
}
