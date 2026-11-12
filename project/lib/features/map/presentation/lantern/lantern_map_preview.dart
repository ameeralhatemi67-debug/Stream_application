import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../lessons/domain/lessons_rules.dart' show MosqueStatus;
import '../../../lessons/presentation/lessons_in_app.dart';
import '../../../lessons/presentation/lessons_map.dart';
import '../../../lessons/state/lessons_controller.dart';
import '../../../profile/models/streamer_models.dart';
import '../map_visible_catalog.dart';

/// The picture in the map cards of Discover and Lessons on the website
/// layout: the real three-city map (the bundled pack, as on the map page),
/// held still, with the mosques that have lessons and, on Discover, the
/// channels that have a place. Phones keep the drawn picture (owner notes
/// 2026-11-12). The card around it opens the map.
class LanternMapPreview extends StatelessWidget implements LanternSkinWidget {
  const LanternMapPreview({super.key, this.streamers = const []});

  /// Channels to pin (Discover); none on the Lessons card.
  final List<StreamerModel> streamers;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final mosques = context.select<LessonsController?, List<MapMosque>>(
        (c) => c == null
            ? const []
            : mapMosques(c, lang)
                .where((m) => m.status != MosqueStatus.quiet)
                .toList());
    final pins = [
      for (final m in mosques)
        MosquePin(
            id: m.id,
            lat: m.point.latitude,
            lng: m.point.longitude,
            label: m.label,
            count: m.count,
            live: m.live,
            onSite: m.status == MosqueStatus.now && !m.live),
    ];
    final markers = [
      for (final s in visibleMapStreamers(streamers))
        Marker(
            point: LatLng(s.latitude, s.longitude),
            width: 34,
            height: 34,
            child: LAvatar(
                name: s.getLocalizedName(lang),
                image: resolveImageProviderOrNull(s.avatarUrl),
                org: s.isOrganization,
                ring: s.isAudioLive
                    ? LRing.audio
                    : s.isCurrentlyLive
                        ? LRing.live
                        : LRing.none,
                size: 32)),
    ];
    return ClipRRect(
        key: const ValueKey('lantern-map-preview'),
        borderRadius: BorderRadius.circular(Lantern.radiusCard),
        child: IgnorePointer(
            child: LessonsMap(pins: pins, markers: markers, interactive: false)));
  }
}
