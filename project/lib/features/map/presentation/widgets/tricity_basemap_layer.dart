import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

import '../../services/map_pack_controller.dart';

/// The bundled three-city streets-and-labels layer, drawn from the local
/// pack whether or not the backend is reachable. Renders nothing until the
/// pack is verified; callers show pack status separately.
///
/// Shared by the Spatial Map and the venue location picker so both use the
/// same data, style, fonts and zoom semantics.
class TricityBasemapLayer extends StatefulWidget {
  const TricityBasemapLayer({super.key, required this.controller});

  final MapPackController controller;

  /// Decoded-tile budget (package default) and a bounded finished-tile
  /// budget, so the map stays modest beside video playback.
  static const int memoryCacheBytes = 24 << 20;
  static const int rasterCacheBytes = 96 << 20;

  @override
  State<TricityBasemapLayer> createState() => _TricityBasemapLayerState();
}

class _TricityBasemapLayerState extends State<TricityBasemapLayer> {
  /// flutter_map_vector_tiles 2.9.0 shapes each label once and keeps the
  /// result for the life of the layer. On the web the engine may still be
  /// downloading a fallback font (Arabic) at that moment, which would leave
  /// labels as empty boxes. When the engine reports new fonts, a fresh
  /// layer instance re-shapes them; decoded tiles stay in the package's
  /// process-wide caches, so this costs no data reads.
  int _fontGeneration = 0;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  void _onFontsChanged() {
    if (mounted) setState(() => _fontGeneration++);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = context.locale.languageCode;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final providers = widget.controller.providers;
        final theme = widget.controller.themeFor(languageCode, textScale);
        if (providers == null || theme == null) return const SizedBox.shrink();
        return vt.VectorTileLayer(
          key: ValueKey('tricity_basemap_$_fontGeneration'),
          theme: theme,
          tileProviders: providers,
          // The pack is local already: no second on-disk tile copy.
          diskCacheMaximumSizeInBytes: 0,
          memoryCacheMaxBytes: TricityBasemapLayer.memoryCacheBytes,
          rasterCacheMaxBytes: TricityBasemapLayer.rasterCacheBytes,
        );
      },
    );
  }
}
