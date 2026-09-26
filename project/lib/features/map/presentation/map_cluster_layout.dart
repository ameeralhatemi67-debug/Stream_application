import 'dart:ui' show Offset;

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

List<MapClusterGroup> clusterMapPoints(
  Iterable<MapClusterPoint> points, {
  required Offset Function(LatLng) project,
  required LatLng Function(Offset) unproject,
  double cellSize = 72,
}) {
  assert(cellSize > 0);
  final cells = <(int, int), List<(MapClusterPoint, Offset)>>{};
  for (final point in points) {
    final pixel = project(point.coordinates);
    final cell = ((pixel.dx / cellSize).floor(), (pixel.dy / cellSize).floor());
    cells.putIfAbsent(cell, () => []).add((point, pixel));
  }

  final groups = <MapClusterGroup>[];
  for (final members in cells.values) {
    members.sort((a, b) => a.$1.id.compareTo(b.$1.id));
    final ids = members.map((m) => m.$1.id).toList(growable: false);
    final x =
        members.fold<double>(0, (sum, m) => sum + m.$2.dx) / members.length;
    final y =
        members.fold<double>(0, (sum, m) => sum + m.$2.dy) / members.length;
    groups.add(MapClusterGroup(
      ids.length == 1 ? 'marker_${ids.single}' : 'cluster_${ids.join('|')}',
      ids,
      ids.length == 1 ? members.single.$1.coordinates : unproject(Offset(x, y)),
    ));
  }
  groups.sort((a, b) => a.id.compareTo(b.id));
  return groups;
}
