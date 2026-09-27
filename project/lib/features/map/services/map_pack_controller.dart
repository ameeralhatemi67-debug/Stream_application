import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;

import 'local_pmtiles.dart';
import 'map_offline_store.dart';
import 'map_pack_platform.dart';

const String kTricityPackDir = 'assets/maps/tricity';

/// Credit shown only if the pack manifest cannot be read (the map itself is
/// then not shown). The normal credit, with the copyright sign, comes from
/// the manifest's `attribution.short`, so it always matches the bundled data.
const String kOsmCreditFallback = 'OpenStreetMap contributors';

enum MapPackStatus { loading, ready, unavailable }

/// Why the local map could not be shown. Codes map to localized copy.
enum MapPackProblem {
  /// A bundled file could not be read (or, on the web, downloaded).
  missingAsset,

  /// Size or SHA-256 differs from the manifest, or the archive is invalid.
  corrupt,

  /// Manifest schema, archive zoom range or style source is not the one
  /// this app release understands.
  incompatible,
}

class MapPackFile {
  const MapPackFile(this.bytes, this.sha256);
  final int bytes;
  final String sha256;
}

/// The pack's own description (assets/maps/tricity/manifest.json).
class MapPackManifest {
  MapPackManifest._(this.json);

  final Map<String, dynamic> json;

  static MapPackManifest? tryParse(String text) {
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) return null;
      return MapPackManifest._(json);
    } catch (_) {
      return null;
    }
  }

  int get schema => (json['schema'] as num?)?.toInt() ?? -1;
  String get packId => json['pack_id'] as String? ?? '';
  String get dataDate => json['data_date'] as String? ?? '';

  /// Map data older than this still works; the details sheet only adds a
  /// dated advisory (it never expires the offline map).
  static const Duration staleAfter = Duration(days: 90);

  /// Whether [now] is more than [staleAfter] past the data date.
  bool isStale(DateTime now) {
    final date = DateTime.tryParse(dataDate);
    return date != null && now.difference(date) > staleAfter;
  }

  List<int> get nativeZoom => ((json['native_zoom'] as List?) ?? const [])
      .cast<num>()
      .map((e) => e.toInt())
      .toList();
  String get attributionShort =>
      (json['attribution'] as Map?)?['short'] as String? ?? kOsmCreditFallback;
  String get attributionUrl =>
      (json['attribution'] as Map?)?['url'] as String? ??
      'https://www.openstreetmap.org/copyright';

  MapPackFile? file(String name) {
    final entry = (json['files'] as Map?)?[name];
    if (entry is! Map) return null;
    final bytes = (entry['bytes'] as num?)?.toInt();
    final sha = entry['sha256'] as String?;
    if (bytes == null || sha == null) return null;
    return MapPackFile(bytes, sha);
  }

  List<String> get fileNames =>
      ((json['files'] as Map?)?.keys ?? const <String>[])
          .cast<String>()
          .toList();
}

/// Owns the bundled three-city map pack: verifies it against its manifest,
/// opens the local archive reader and compiles the locale styles. It is
/// independent of backend connectivity: catalog/live state stays in
/// AppProvider, and a reachable or unreachable backend never changes
/// whether local streets can be drawn.
///
/// One process-wide instance ([shared]) serves the Spatial Map and the venue
/// location picker. It opens lazily on first use and keeps the ~11 MB
/// archive in memory while the app runs; nothing is written to device
/// storage on Android/Windows.
class MapPackController extends ChangeNotifier {
  MapPackController({
    AssetBundle? bundle,
    Future<String> Function(Uint8List bytes)? hasher,
    WebOfflineMapStore? webStore,
    bool useWebStore = true,
  })  : _bundle = bundle ?? rootBundle,
        _hasher = hasher ?? sha256Hex,
        _webStore = useWebStore ? (webStore ?? createWebOfflineStore()) : null;

  static MapPackController? _shared;
  static MapPackController get shared => _shared ??= MapPackController();

  /// Tests replace the process instance (and restore it with null).
  @visibleForTesting
  static set debugShared(MapPackController? controller) => _shared = controller;

  final AssetBundle _bundle;
  final Future<String> Function(Uint8List bytes) _hasher;
  final WebOfflineMapStore? _webStore;

  MapPackStatus _status = MapPackStatus.loading;
  MapPackProblem? _problem;
  MapPackManifest? _manifest;
  LocalPmTilesProvider? _provider;
  vt.TileProviders? _providers;
  final Map<String, Map<String, dynamic>> _styles = {};
  final Map<String, vt.Theme> _themes = {};
  final List<String> styleWarnings = [];
  Future<void>? _opening;
  bool _disposed = false;
  WebOfflineStatus? _webOffline;
  String? _notice;

  /// Wall-clock time of the last successful open (read + verify + parse),
  /// recorded for evidence.
  Duration? lastOpenDuration;

  MapPackStatus get status => _status;
  MapPackProblem? get problem => _problem;
  MapPackManifest? get manifest => _manifest;
  vt.TileProviders? get providers => _providers;
  bool get isReady => _status == MapPackStatus.ready;
  int get servedRanges => _provider?.servedRanges ?? 0;

  /// Locally bundled notices (NOTICE.txt), read without network.
  String? get notice => _notice;

  /// Browser-only offline preparation state; null on native platforms.
  WebOfflineStatus? get webOffline => _webOffline;
  bool get supportsWebOffline => _webStore != null;
  bool get canPrepareWebOffline => isReady && browserNetworkAvailable;

  /// Starts (or joins) opening the pack. Safe to call from build paths.
  Future<void> ensureOpened() {
    if (_status == MapPackStatus.ready) return Future.value();
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  /// Re-reads and re-verifies the bundled pack after a failure.
  Future<void> retry() {
    if (_opening != null) return _opening!;
    _closeReader();
    _setStatus(MapPackStatus.loading, null);
    return ensureOpened();
  }

  Future<void> _open() async {
    final watch = Stopwatch()..start();
    _setStatus(MapPackStatus.loading, null);
    try {
      final manifestText = await _bundle
          .loadString('$kTricityPackDir/manifest.json', cache: false);
      final manifest = MapPackManifest.tryParse(manifestText);
      if (manifest == null) return _fail(MapPackProblem.corrupt);
      // Kept even if verification below fails: it names the credit and the
      // pack the browser offline copy is checked against.
      _manifest = manifest;
      if (manifest.schema != 1 ||
          manifest.nativeZoom.length != 2 ||
          manifest.nativeZoom[0] != 0 ||
          manifest.nativeZoom[1] != 15) {
        return _fail(MapPackProblem.incompatible);
      }
      final packFile = manifest.file('basemap.pmtiles');
      if (packFile == null) return _fail(MapPackProblem.incompatible);

      final Uint8List archive;
      try {
        final data = await _bundle.load('$kTricityPackDir/basemap.pmtiles');
        archive =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      } catch (_) {
        return _fail(MapPackProblem.missingAsset);
      }
      if (archive.length != packFile.bytes ||
          await _hasher(archive) != packFile.sha256) {
        return _fail(MapPackProblem.corrupt);
      }

      final styles = <String, Map<String, dynamic>>{};
      for (final lang in const ['en', 'ar']) {
        final style = await _loadVerifiedStyle(manifest, lang);
        if (style == null) return; // _fail already recorded
        styles[lang] = style;
      }
      try {
        _notice = await _bundle.loadString('$kTricityPackDir/NOTICE.txt',
            cache: false);
      } catch (_) {
        return _fail(MapPackProblem.missingAsset);
      }

      final LocalPmTilesProvider provider;
      try {
        provider = await LocalPmTilesProvider.open(archive,
            packSha256: packFile.sha256);
      } catch (_) {
        return _fail(MapPackProblem.corrupt);
      }
      if (provider.header.minZoom != 0 || provider.header.maxZoom != 15) {
        provider.dispose();
        return _fail(MapPackProblem.incompatible);
      }
      if (_disposed) {
        provider.dispose();
        return;
      }
      _manifest = manifest;
      _provider = provider;
      _providers = vt.TileProviders({'protomaps': provider});
      _styles
        ..clear()
        ..addAll(styles);
      _themes.clear();
      lastOpenDuration = watch.elapsed;
      _setStatus(MapPackStatus.ready, null);
      unawaited(refreshWebOffline());
    } catch (_) {
      _fail(MapPackProblem.missingAsset);
    }
  }

  Future<Map<String, dynamic>?> _loadVerifiedStyle(
      MapPackManifest manifest, String lang) async {
    final name = 'style-$lang.json';
    final expected = manifest.file(name);
    if (expected == null) {
      _fail(MapPackProblem.incompatible);
      return null;
    }
    final Uint8List bytes;
    try {
      final data = await _bundle.load('$kTricityPackDir/$name');
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      _fail(MapPackProblem.missingAsset);
      return null;
    }
    if (bytes.length != expected.bytes ||
        await _hasher(bytes) != expected.sha256) {
      _fail(MapPackProblem.corrupt);
      return null;
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      _fail(MapPackProblem.corrupt);
      return null;
    }
    if (json is! Map<String, dynamic> || !isLocalOnlyStyle(json)) {
      _fail(MapPackProblem.incompatible);
      return null;
    }
    return json;
  }

  /// A style may only name the in-app `protomaps` source, with no tile,
  /// TileJSON, glyph or sprite URL: anything else could reach the network.
  static bool isLocalOnlyStyle(Map<String, dynamic> style) {
    if (style.containsKey('glyphs') || style.containsKey('sprite')) {
      return false;
    }
    final sources = style['sources'];
    if (sources is! Map || sources.length != 1) return false;
    final source = sources['protomaps'];
    if (source is! Map || source['type'] != 'vector') return false;
    return !source.containsKey('url') && !source.containsKey('tiles');
  }

  /// Compiled style for [languageCode] with label sizes scaled for the
  /// user's text size ([textScale], clamped to 1.0-1.6 so labels stay
  /// placeable). Cached per locale and scale step.
  vt.Theme? themeFor(String languageCode, double textScale) {
    if (!isReady) return null;
    final lang = languageCode == 'ar' ? 'ar' : 'en';
    final scale = (textScale.clamp(1.0, 1.6) * 10).round() / 10;
    final key = '$lang@$scale';
    final cached = _themes[key];
    if (cached != null) return cached;
    final style = scaledStyle(_styles[lang]!, scale);
    final theme = vt.ThemeReader(
      logger: vt.Logger.custom(onWarn: (m) {
        if (styleWarnings.length < 50) styleWarnings.add('[$key] $m');
      }),
    ).read(style, id: 'tricity-$key-${_manifest!.packId}');
    return _themes[key] = theme;
  }

  /// Multiplies every `text-size` (a number, or an `interpolate` over zoom
  /// with literal outputs, as the style generator emits) by [scale].
  @visibleForTesting
  static Map<String, dynamic> scaledStyle(
      Map<String, dynamic> style, double scale) {
    if (scale == 1.0) return style;
    final copy = jsonDecode(jsonEncode(style)) as Map<String, dynamic>;
    for (final layer in (copy['layers'] as List).cast<Map<String, dynamic>>()) {
      final layout = layer['layout'];
      if (layout is! Map) continue;
      final size = layout['text-size'];
      if (size is num) {
        layout['text-size'] = size * scale;
      } else if (size is List &&
          size.isNotEmpty &&
          size.first == 'interpolate') {
        for (var i = 4; i < size.length; i += 2) {
          final value = size[i];
          if (value is num) size[i] = value * scale;
        }
      }
    }
    return copy;
  }

  Future<void> refreshWebOffline() async {
    final store = _webStore;
    final packSha = _manifest?.file('basemap.pmtiles')?.sha256;
    if (store == null || packSha == null) return;
    if (_webOffline?.state == WebOfflineState.preparing) return;
    _webOffline = await store.inspect(packSha256: packSha);
    if (!_disposed) notifyListeners();
  }

  /// Browser only: stores the app shell and the complete pack so a later
  /// visit can start without a network.
  Future<void> prepareWebOffline() async {
    final store = _webStore;
    final manifest = _manifest;
    final pack = manifest?.file('basemap.pmtiles');
    if (store == null || manifest == null || pack == null) return;
    if (_webOffline?.state == WebOfflineState.preparing) return;
    _webOffline = const WebOfflineStatus(WebOfflineState.preparing);
    notifyListeners();
    final result = await store.prepare(
      packSha256: pack.sha256,
      packAssetKey: '$kTricityPackDir/basemap.pmtiles',
      requiredAssetKeys: [
        for (final name in manifest.fileNames) '$kTricityPackDir/$name',
        '$kTricityPackDir/manifest.json',
        'assets/i18n/en.json',
        'assets/i18n/ar.json',
      ],
      packBytes: pack.bytes,
      onProgress: (done, total) {
        _webOffline = WebOfflineStatus(WebOfflineState.preparing,
            done: done, total: total);
        if (!_disposed) notifyListeners();
      },
    );
    _webOffline = result;
    if (!_disposed) notifyListeners();
  }

  /// Browser only: removes the offline copy and withdraws readiness. Does
  /// not touch sign-in, the public catalog or any other app storage.
  Future<void> resetWebOffline() async {
    final store = _webStore;
    if (store == null) return;
    await store.reset();
    await refreshWebOffline();
  }

  void _fail(MapPackProblem problem) {
    _closeReader();
    _setStatus(MapPackStatus.unavailable, problem);
    // On the web, say whether the browser still holds a prepared copy (for
    // example "removed by the browser") rather than only "unavailable".
    unawaited(refreshWebOffline());
  }

  void _setStatus(MapPackStatus status, MapPackProblem? problem) {
    _status = status;
    _problem = problem;
    if (!_disposed) notifyListeners();
  }

  void _closeReader() {
    // Layers already built keep their own reference until they rebuild;
    // the provider's dispose turns later loads into cancellations.
    _providers = null;
    _provider?.dispose();
    _provider = null;
    _themes.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeReader();
    super.dispose();
  }
}
