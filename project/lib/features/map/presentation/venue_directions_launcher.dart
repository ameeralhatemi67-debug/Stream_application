import 'package:flutter/foundation.dart';
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
