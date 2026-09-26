import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:streamer_app/features/map/models/map_tricity_domain.dart';
import 'package:streamer_app/features/map/services/local_pmtiles.dart';
import 'package:streamer_app/features/map/services/map_offline_store.dart';
import 'package:streamer_app/features/map/services/map_pack_controller.dart';

/// Serves the real bundled pack files from disk, optionally altered, so the
/// controller's verification runs against the actual shipped bytes.
class _PackBundle extends CachingAssetBundle {
  _PackBundle({this.replaced = const {}, Set<String>? missing})
      : missing = missing ?? {};

  final Map<String, Uint8List> replaced;
  final Set<String> missing;
  int loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    if (missing.contains(key)) throw StateError('missing $key');
    final bytes = replaced[key] ?? File(key).readAsBytesSync();
    return ByteData.sublistView(bytes);
  }
}

String _sha(Uint8List b) => crypto.sha256.convert(b).toString();
Future<String> _hasher(Uint8List b) async => _sha(b);

Uint8List _file(String name) =>
    File('assets/maps/tricity/$name').readAsBytesSync();

MapPackController _controller(_PackBundle bundle,
        {WebOfflineMapStore? store}) =>
    MapPackController(
      bundle: bundle,
      hasher: _hasher,
      webStore: store,
      useWebStore: store != null,
    );

class _FakeWebStore implements WebOfflineMapStore {
  WebOfflineStatus next = const WebOfflineStatus(WebOfflineState.notPrepared);
  WebOfflineStatus prepareResult =
      const WebOfflineStatus(WebOfflineState.ready);
  List<String>? requested;
  int resets = 0;

  @override
  Future<WebOfflineStatus> inspect({required String packSha256}) async => next;

  @override
  Future<WebOfflineStatus> prepare({
    required String packSha256,
    required List<String> requiredAssetKeys,
    required int packBytes,
    void Function(int done, int total)? onProgress,
  }) async {
    requested = requiredAssetKeys;
    onProgress?.call(1, 2);
    next = prepareResult;
    return prepareResult;
  }

  @override
  Future<void> reset() async {
    resets++;
    next = const WebOfflineStatus(WebOfflineState.notPrepared);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalRangeClient', () {
    final bytes = Uint8List.fromList(List.generate(100, (i) => i));
    final uri = Uri.parse('streamer-pack://abc/basemap.pmtiles');

    test('serves an exact range as 206 with Content-Range', () async {
      final client = LocalRangeClient(uri, bytes);
      final r = await client.get(uri, headers: {'range': 'bytes=10-19'});
      expect(r.statusCode, 206);
      expect(r.bodyBytes, List.generate(10, (i) => 10 + i));
      expect(r.headers['content-range'], 'bytes 10-19/100');
    });

    test('clamps a range that runs past the end (header prefix read)',
        () async {
      final client = LocalRangeClient(uri, bytes);
      final r = await client.get(uri, headers: {'range': 'bytes=90-16383'});
      expect(r.statusCode, 206);
      expect(r.bodyBytes.length, 10);
    });

    test('rejects missing, reversed, out-of-file and oversized ranges',
        () async {
      final client = LocalRangeClient(uri, bytes, maxRangeBytes: 8);
      expect((await client.get(uri)).statusCode, 400);
      expect(
          (await client.get(uri, headers: {'range': 'bytes=5-2'})).statusCode,
          416);
      expect(
          (await client.get(uri, headers: {'range': 'bytes=100-120'}))
              .statusCode,
          416);
      expect(
          (await client.get(uri, headers: {'range': 'bytes=0-50'})).statusCode,
          416);
    });

    test('never serves any other URL or method, and stops after close',
        () async {
      final client = LocalRangeClient(uri, bytes);
      expect(
          () => client.get(Uri.parse('https://build.protomaps.com/x.pmtiles'),
              headers: {'range': 'bytes=0-1'}),
          throwsA(isA<http.ClientException>()));
      expect(() => client.post(uri), throwsA(isA<http.ClientException>()));
      client.close();
      expect(() => client.get(uri, headers: {'range': 'bytes=0-1'}),
          throwsA(isA<http.ClientException>()));
    });
  });

  group('MapPackController with the shipped pack', () {
    test('verifies, opens and reads real tiles for all three cities locally',
        () async {
      final controller = _controller(_PackBundle());
      await controller.ensureOpened();
      expect(controller.status, MapPackStatus.ready);
      expect(controller.problem, isNull);
      expect(controller.manifest!.nativeZoom, [0, 15]);
      expect(controller.notice, contains('OpenStreetMap'));
      final provider = controller.providers!['protomaps']!;
      expect(provider.cacheBytesToDisk, isFalse);
      expect(provider.maximumZoom, 15);
      expect(provider.cacheKey,
          contains(controller.manifest!.file('basemap.pmtiles')!.sha256));
      // z14 tiles over each city core (Al Khobar, Dhahran/KFUPM, Dammam).
      for (final (lat, lng) in [
        (26.2890, 50.2170), // Al Khobar corniche
        (26.3070, 50.1440), // KFUPM, Dhahran
        (26.4280, 50.0950), // Dammam centre
      ]) {
        const n = 1 << 14;
        final x = (longitudeToMercatorX(lng) * n).floor();
        final y = (latitudeToMercatorY(lat) * n).floor();
        final r = await provider.load(vt.TileKey(14, x, y));
        expect(r, isA<vt.TileResponseData>(), reason: 'tile 14/$x/$y');
        expect((r as vt.TileResponseData).bytes, isNotEmpty);
      }
      // Beyond native data the source reports nothing rather than guessing.
      expect(await provider.load(const vt.TileKey(16, 0, 0)),
          isA<vt.TileResponseNotFound>());
      controller.dispose();
    });

    test('compiles both locale styles and scales label sizes for large text',
        () async {
      final controller = _controller(_PackBundle());
      await controller.ensureOpened();
      final en = controller.themeFor('en', 1.0)!;
      final ar = controller.themeFor('ar', 1.0)!;
      expect(en.id, isNot(ar.id));
      expect(identical(controller.themeFor('en', 1.0), en), isTrue);
      expect(controller.themeFor('en', 1.3)!.id, contains('en@1.3'));
      // Scale is clamped so labels stay placeable.
      expect(controller.themeFor('en', 3.0)!.id, contains('en@1.6'));
      expect(controller.styleWarnings, isEmpty,
          reason: controller.styleWarnings.join('\n'));
      final style = jsonDecode(utf8.decode(_file('style-en.json')))
          as Map<String, dynamic>;
      final scaled = MapPackController.scaledStyle(style, 1.5);
      final layer = (scaled['layers'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((l) => l['id'] == 'places-city');
      expect((layer['layout'] as Map)['text-size'], [
        'interpolate',
        ['linear'],
        ['zoom'],
        8,
        21.0,
        12,
        27.0,
        15,
        30.0
      ]);
      controller.dispose();
    });
  });

  group('MapPackController rejects unusable packs (A04)', () {
    Future<MapPackController> openWith(_PackBundle bundle) async {
      final c = _controller(bundle);
      await c.ensureOpened();
      return c;
    }

    test('flipped byte in the archive fails the hash check', () async {
      final pack = Uint8List.fromList(_file('basemap.pmtiles'));
      pack[pack.length ~/ 2] ^= 0xFF;
      final c = await openWith(
          _PackBundle(replaced: {'assets/maps/tricity/basemap.pmtiles': pack}));
      expect(c.status, MapPackStatus.unavailable);
      expect(c.problem, MapPackProblem.corrupt);
      expect(c.providers, isNull);
    });

    test('truncated archive fails the size check', () async {
      final pack = _file('basemap.pmtiles');
      final c = await openWith(_PackBundle(replaced: {
        'assets/maps/tricity/basemap.pmtiles':
            Uint8List.sublistView(pack, 0, pack.length - 1000)
      }));
      expect(c.problem, MapPackProblem.corrupt);
    });

    test('missing archive, style or notice is reported as missing', () async {
      for (final name in ['basemap.pmtiles', 'style-ar.json', 'NOTICE.txt']) {
        final c =
            await openWith(_PackBundle(missing: {'assets/maps/tricity/$name'}));
        expect(c.status, MapPackStatus.unavailable, reason: name);
        expect(c.problem, MapPackProblem.missingAsset, reason: name);
      }
    });

    test('edited style fails its hash even if it is valid JSON', () async {
      final style = jsonDecode(utf8.decode(_file('style-en.json')))
          as Map<String, dynamic>;
      (style['sources'] as Map)['protomaps']['url'] =
          'pmtiles://https://build.protomaps.com/20260926.pmtiles';
      final c = await openWith(_PackBundle(replaced: {
        'assets/maps/tricity/style-en.json':
            Uint8List.fromList(utf8.encode(jsonEncode(style)))
      }));
      expect(c.problem, MapPackProblem.corrupt);
    });

    test('incompatible manifest schema or zoom range is refused', () async {
      final manifest = jsonDecode(utf8.decode(_file('manifest.json')))
          as Map<String, dynamic>;
      for (final change in <void Function(Map<String, dynamic>)>[
        (m) => m['schema'] = 2,
        (m) => m['native_zoom'] = [0, 14],
      ]) {
        final copy = jsonDecode(jsonEncode(manifest)) as Map<String, dynamic>;
        change(copy);
        final c = await openWith(_PackBundle(replaced: {
          'assets/maps/tricity/manifest.json':
              Uint8List.fromList(utf8.encode(jsonEncode(copy)))
        }));
        expect(c.problem, MapPackProblem.incompatible);
      }
    });

    test('a style naming any remote source, glyph or sprite is not local-only',
        () {
      final style = jsonDecode(utf8.decode(_file('style-en.json')))
          as Map<String, dynamic>;
      expect(MapPackController.isLocalOnlyStyle(style), isTrue);
      for (final change in <void Function(Map<String, dynamic>)>[
        (s) => s['glyphs'] = 'https://example.com/{fontstack}/{range}.pbf',
        (s) => s['sprite'] = 'https://example.com/sprite',
        (s) => (s['sources'] as Map)['protomaps']
            ['tiles'] = ['https://example.com/{z}/{x}/{y}.mvt'],
        (s) => (s['sources'] as Map)['other'] = {'type': 'vector'},
      ]) {
        final copy = jsonDecode(jsonEncode(style)) as Map<String, dynamic>;
        change(copy);
        expect(MapPackController.isLocalOnlyStyle(copy), isFalse);
      }
    });

    test('retry stays unavailable while broken and recovers once intact',
        () async {
      final bundle =
          _PackBundle(missing: {'assets/maps/tricity/manifest.json'});
      final c = _controller(bundle);
      await c.ensureOpened();
      expect(c.problem, MapPackProblem.missingAsset);
      await c.retry();
      expect(c.status, MapPackStatus.unavailable);
      bundle.missing.clear();
      await c.retry();
      expect(c.status, MapPackStatus.ready);
      expect(c.problem, isNull);
    });
  });

  group(
      'Browser offline preparation state (fake store; real browser '
      'behaviour is covered by the Chrome acceptance run)', () {
    test('prepare stores pack, styles, manifest, notice and both catalogs',
        () async {
      final store = _FakeWebStore();
      final c = _controller(_PackBundle(), store: store);
      await c.ensureOpened();
      await Future<void>.delayed(Duration.zero);
      expect(c.webOffline!.state, WebOfflineState.notPrepared);
      await c.prepareWebOffline();
      expect(c.webOffline!.state, WebOfflineState.ready);
      expect(
          store.requested,
          containsAll([
            'assets/maps/tricity/basemap.pmtiles',
            'assets/maps/tricity/style-en.json',
            'assets/maps/tricity/style-ar.json',
            'assets/maps/tricity/NOTICE.txt',
            'assets/maps/tricity/manifest.json',
            'assets/i18n/en.json',
            'assets/i18n/ar.json',
          ]));
      await c.resetWebOffline();
      expect(store.resets, 1);
      expect(c.webOffline!.state, WebOfflineState.notPrepared);
    });

    test('an interrupted preparation is reported as failed, never ready',
        () async {
      final store = _FakeWebStore()
        ..prepareResult =
            const WebOfflineStatus(WebOfflineState.failed, detail: 'network');
      final c = _controller(_PackBundle(), store: store);
      await c.ensureOpened();
      await c.prepareWebOffline();
      expect(c.webOffline!.state, WebOfflineState.failed);
      expect(c.webOffline!.detail, 'network');
      expect(c.isReady, isTrue, reason: 'the in-memory map keeps working');
    });

    test('native builds have no browser offline state', () async {
      final c = _controller(_PackBundle());
      await c.ensureOpened();
      expect(c.supportsWebOffline, isFalse);
      expect(c.webOffline, isNull);
    });
  });
}
