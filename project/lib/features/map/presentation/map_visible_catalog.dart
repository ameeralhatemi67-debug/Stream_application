import '../../profile/models/streamer_models.dart';
import '../models/map_models.dart';
import 'package:latlong2/latlong.dart';

/// The map and its search use the same current, public catalog snapshot.
List<StreamerModel> visibleMapStreamers(Iterable<StreamerModel> streamers) =>
    streamers
        .where((streamer) =>
            streamer.isVerified &&
            !streamer.isTemporarilyHiddenFromMap &&
            saudiMapBounds
                .contains(LatLng(streamer.latitude, streamer.longitude)))
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
