import 'dart:ui' show Offset, Size;

import 'package:latlong2/latlong.dart';

/// Pins closer than this on screen become one bubble, and bubbles sit on one
/// of their pins, so two markers can never touch.
const double kMapClusterRadius = 64;

/// The same, once streamers are shown as wider channel cards.
const double kMapCardClusterRadius = 104;

/// From this zoom a streamer is drawn as its channel card.
const double kMapChannelCardZoom = 14.6;

/// From this zoom mosques with nothing coming up are drawn too.
const double kMapQuietMosqueZoom = 12.4;

/// Membership and IDs are deterministic for a given camera and catalog.
class MapClusterPoint {
  const MapClusterPoint(this.id, this.coordinates, {this.priority = 0});

  final String id;
  final LatLng coordinates;

  /// The highest in a group anchors its bubble: something happening now
  /// stays where it really is.
  final int priority;
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
  double radius = kMapClusterRadius,
}) {
  assert(radius > 0);
  final placed = [for (final p in points) (point: p, pixel: project(p.coordinates))]
    ..sort((a, b) {
      final byPriority = b.point.priority.compareTo(a.point.priority);
      return byPriority != 0 ? byPriority : a.point.id.compareTo(b.point.id);
    });
  // Pins are bucketed by the radius, so each looks only at its neighbours
  // and layout work stays bounded as the catalog grows.
  (int, int) cellOf(Offset pixel) =>
      ((pixel.dx / radius).floor(), (pixel.dy / radius).floor());
  final cells = <(int, int), List<int>>{};
  for (var i = 0; i < placed.length; i++) {
    cells.putIfAbsent(cellOf(placed[i].pixel), () => []).add(i);
  }

  final taken = List<bool>.filled(placed.length, false);
  final groups = <MapClusterGroup>[];
  for (var i = 0; i < placed.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    final seed = placed[i];
    final (cx, cy) = cellOf(seed.pixel);
    final ids = [seed.point.id];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final j in cells[(cx + dx, cy + dy)] ?? const <int>[]) {
          if (taken[j] || (placed[j].pixel - seed.pixel).distance >= radius) {
            continue;
          }
          taken[j] = true;
          ids.add(placed[j].point.id);
        }
      }
    }
    ids.sort();
    groups.add(MapClusterGroup(
      ids.length == 1 ? 'marker_${ids.single}' : 'cluster_${ids.join('|')}',
      ids,
      seed.point.coordinates,
    ));
  }
  groups.sort((a, b) => a.id.compareTo(b.id));
  return groups;
}

/// A pin measured together with the label under it (Lantern and Arch,
/// ADR-026): 84 wide and 74 tall. Markers are grouped until no two of these
/// boxes touch, so labels cannot cover each other either.
const Size kMapPinFootprint = Size(84, 74);

/// The same rule as [clusterMapPoints] (highest priority first, the bubble
/// sits on that pin), with a box in place of the circle: two pins join when
/// their [footprint] boxes would overlap. Every marker left on the map then
/// has its own box to itself.
List<MapClusterGroup> clusterMapFootprints(
  Iterable<MapClusterPoint> points, {
  required Offset Function(LatLng) project,
  Size footprint = kMapPinFootprint,
}) {
  assert(footprint.width > 0 && footprint.height > 0);
  final placed = [for (final p in points) (point: p, pixel: project(p.coordinates))]
    ..sort((a, b) {
      final byPriority = b.point.priority.compareTo(a.point.priority);
      return byPriority != 0 ? byPriority : a.point.id.compareTo(b.point.id);
    });
  // Bucketed by the box, so each pin looks only at its neighbours.
  (int, int) cellOf(Offset pixel) => (
        (pixel.dx / footprint.width).floor(),
        (pixel.dy / footprint.height).floor()
      );
  final cells = <(int, int), List<int>>{};
  for (var i = 0; i < placed.length; i++) {
    cells.putIfAbsent(cellOf(placed[i].pixel), () => []).add(i);
  }

  final taken = List<bool>.filled(placed.length, false);
  final groups = <MapClusterGroup>[];
  for (var i = 0; i < placed.length; i++) {
    if (taken[i]) continue;
    taken[i] = true;
    final seed = placed[i];
    final (cx, cy) = cellOf(seed.pixel);
    final ids = [seed.point.id];
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final j in cells[(cx + dx, cy + dy)] ?? const <int>[]) {
          if (taken[j]) continue;
          final gap = placed[j].pixel - seed.pixel;
          if (gap.dx.abs() >= footprint.width ||
              gap.dy.abs() >= footprint.height) {
            continue;
          }
          taken[j] = true;
          ids.add(placed[j].point.id);
        }
      }
    }
    ids.sort();
    groups.add(MapClusterGroup(
      ids.length == 1 ? 'marker_${ids.single}' : 'cluster_${ids.join('|')}',
      ids,
      seed.point.coordinates,
    ));
  }
  groups.sort((a, b) => a.id.compareTo(b.id));
  return groups;
}

/// The first zoom above [from] at which the pins of one bubble come apart
/// into more than one marker, in steps of [step] up to [max]. Null when they
/// never do (a broadcaster streaming from a mosque shares its spot): the
/// bubble then opens a short list instead of zooming.
double? mapSeparationZoom(
  Iterable<MapClusterPoint> members, {
  required Offset Function(LatLng coordinates, double zoom) projectAt,
  required double from,
  required double max,
  double step = .5,
  Size footprint = kMapPinFootprint,
}) {
  final pins = members.toList();
  if (pins.length < 2) return null;
  for (var zoom = from + step; zoom <= max + 1e-9; zoom += step) {
    final z = zoom > max ? max : zoom;
    final groups = clusterMapFootprints(pins,
        project: (c) => projectAt(c, z), footprint: footprint);
    if (groups.length > 1) return z;
  }
  return null;
}
