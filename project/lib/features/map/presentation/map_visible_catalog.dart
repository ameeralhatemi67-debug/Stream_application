import '../../profile/models/streamer_models.dart';
import '../models/map_models.dart';
import '../models/map_tricity_domain.dart';

/// The map and its search use the same current, public catalog snapshot.
/// Only verified, map-visible records whose exact coordinates fall inside
/// the supported map-pack area are drawn, regardless of city label.
/// Records elsewhere (or with invalid
/// coordinates) are untouched and stay in the feed, profiles and
/// directions; they are simply not placed on this map.
List<StreamerModel> visibleMapStreamers(Iterable<StreamerModel> streamers) =>
    streamers
        .where((streamer) =>
            streamer.isVerified &&
            !streamer.isTemporarilyHiddenFromMap &&
            isTricityMapVenue(streamer.latitude, streamer.longitude,
                [streamer.cityEn, streamer.cityAr]))
        .toList();

/// When a public catalog exists it can remove stale pins. On a cold start
/// with only the independently saved marker cache, those pins are the last
/// known public snapshot and must remain available offline.
List<MapMarkerModel> visibleCachedMapMarkers(
  Iterable<MapMarkerModel> cached, {
  required Set<String>? currentVisibleIds,
}) =>
    cached
        .where((marker) =>
            isTricityMapVenue(
                marker.latitude, marker.longitude, [marker.cityId]) &&
            (currentVisibleIds == null ||
                currentVisibleIds.contains(marker.streamerId)))
        .toList();

List<StreamerModel> searchMapStreamers(
  Iterable<StreamerModel> visibleStreamers,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return visibleStreamers
      .where((s) => [
            s.fullNameEn,
            s.fullNameAr,
            s.venueNameEn,
            s.venueNameAr,
            s.organizationEn,
            s.organizationAr,
            s.cityEn,
            s.cityAr,
          ].any((value) => value.toLowerCase().contains(q)))
      .toList();
}
