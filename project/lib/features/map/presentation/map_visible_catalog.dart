import '../../profile/models/streamer_models.dart';
import '../models/map_models.dart';
import '../models/map_tricity_domain.dart';

/// The map and its search use the same current, public catalog snapshot.
/// Only verified, map-visible records whose exact coordinates fall inside
/// the three-city map domain are drawn. Records elsewhere (or with invalid
/// coordinates) are untouched and stay in the feed, profiles and
/// directions; they are simply not placed on this map.
List<StreamerModel> visibleMapStreamers(Iterable<StreamerModel> streamers) =>
    streamers
        .where((streamer) =>
            streamer.isVerified &&
            !streamer.isTemporarilyHiddenFromMap &&
            (isTricityVenueCity(streamer.cityEn) ||
                isTricityVenueCity(streamer.cityAr)) &&
            isInTricityMapDomain(streamer.latitude, streamer.longitude))
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
            isTricityVenueCity(marker.cityId) &&
            isInTricityMapDomain(marker.latitude, marker.longitude) &&
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
