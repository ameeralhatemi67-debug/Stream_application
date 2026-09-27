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

/// A venue point directions can use: finite, in range and not 0,0 (the
/// app's "no location pinned" value).
bool isUsableVenuePoint(double lat, double lng) =>
    lat.isFinite &&
    lng.isFinite &&
    lat.abs() <= 90 &&
    lng.abs() <= 180 &&
    !(lat == 0 && lng == 0);

Future<bool> launchVenueDirections(double lat, double lng,
    {bool googleOnly = false}) async {
  if (!isUsableVenuePoint(lat, lng)) return false;
  final fallback = googleVenueDirectionsUri(lat, lng);
  final preferred = googleOnly
      ? fallback
      : nativeVenueDirectionsUri(lat, lng, defaultTargetPlatform);
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
  bool googleOnly = false,
  @visibleForTesting Future<bool> Function(double lat, double lng)? launcher,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!isUsableVenuePoint(lat, lng)) {
    messenger?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('map.no_venue_location'.tr()),
      ),
    );
    return false;
  }
  final opened = await (launcher?.call(lat, lng) ??
      launchVenueDirections(lat, lng, googleOnly: googleOnly));
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
