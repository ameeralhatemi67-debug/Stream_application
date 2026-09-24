import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// A screen-space grid keeps layout work bounded as the catalog grows.
/// Membership and IDs are deterministic for a given camera and catalog.
class MapClusterPoint {
  const MapClusterPoint(this.id, this.coordinates);

  final String id;
  final LatLng coordinates;
}

class MapClusterGroup {
  const MapClusterGroup(this.id, this.memberIds, this.center);

  final String id;
  final List<String> memberIds;
  final LatLng center;
  bool get isSingle => memberIds.length == 1;
}

/// At the last zoom level, a cluster tap opens its member list instead.
double? clusterTapZoom(double currentZoom) =>
    currentZoom < 17.0 ? (currentZoom + 2).clamp(5.0, 17.5) : null;

List<MapClusterGroup> clusterMapPoints(
  Iterable<MapClusterPoint> points, {
  required math.Point<double> Function(LatLng) project,
  required LatLng Function(math.Point<double>) unproject,
  double cellSize = 72,
}) {
  assert(cellSize > 0);
  final cells = <(int, int), List<(MapClusterPoint, math.Point<double>)>>{};
  for (final point in points) {
    final pixel = project(point.coordinates);
    final cell = ((pixel.x / cellSize).floor(), (pixel.y / cellSize).floor());
    cells.putIfAbsent(cell, () => []).add((point, pixel));
  }

  final groups = <MapClusterGroup>[];
  for (final members in cells.values) {
    members.sort((a, b) => a.$1.id.compareTo(b.$1.id));
    final ids = members.map((m) => m.$1.id).toList(growable: false);
    final x =
        members.fold<double>(0, (sum, m) => sum + m.$2.x) / members.length;
    final y =
        members.fold<double>(0, (sum, m) => sum + m.$2.y) / members.length;
    groups.add(MapClusterGroup(
      ids.length == 1 ? 'marker_${ids.single}' : 'cluster_${ids.join('|')}',
      ids,
      ids.length == 1
          ? members.single.$1.coordinates
          : unproject(math.Point(x, y)),
    ));
  }
  groups.sort((a, b) => a.id.compareTo(b.id));
  return groups;
}
