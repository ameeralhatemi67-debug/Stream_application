import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Uri googleVenueDirectionsUri(double lat, double lng) => Uri.https(
      'www.google.com',
      '/maps/dir/',
      {'api': '1', 'destination': '$lat,$lng', 'dir_action': 'navigate'},
    );

Uri nativeVenueDirectionsUri(double lat, double lng, TargetPlatform platform) {
  final point = '$lat,$lng';
  if (platform == TargetPlatform.android) {
    return googleVenueDirectionsUri(lat, lng);
  }
  if (platform == TargetPlatform.iOS) {
    return Uri.https('maps.apple.com', '/', {'daddr': point});
  }
  return googleVenueDirectionsUri(lat, lng);
}

Future<bool> launchVenueDirections(double lat, double lng) async {
  final fallback = googleVenueDirectionsUri(lat, lng);
  final preferred = nativeVenueDirectionsUri(lat, lng, defaultTargetPlatform);
  try {
    if (await launchUrl(preferred,
        mode: LaunchMode.externalNonBrowserApplication)) {
      return true;
    }
  } catch (_) {
    // A phone may have no handler for the native URI.
  }
  try {
    return await launchUrl(fallback, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Opens directions to the exact venue coordinates and tells the user when
/// no maps app or browser could take them (A18), instead of doing nothing.
Future<bool> openVenueDirections(
  BuildContext context,
  double lat,
  double lng, {
  @visibleForTesting Future<bool> Function(double lat, double lng) launcher =
      launchVenueDirections,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final opened = await launcher(lat, lng);
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('map.directions_failed'.tr()),
      ),
    );
  }
  return opened;
}
