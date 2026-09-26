import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

import 'map_offline_store.dart';

/// SHA-256 through the browser's native SubtleCrypto.
Future<String> sha256Hex(Uint8List bytes) async {
  final digest =
      await web.window.crypto.subtle.digest('SHA-256'.toJS, bytes.toJS).toDart;
  final out = (digest as JSArrayBuffer).toDart.asUint8List();
  final sb = StringBuffer();
  for (final b in out) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

WebOfflineMapStore? createWebOfflineStore() => _BrowserOfflineMapStore();

/// Must match CACHE in web/streamer_offline_sw.js.
const _cacheName = 'streamer-offline-v1';
const _stagingName = 'streamer-offline-v1-staging';
const _readyPath = '__streamer_offline_ready__.json';

/// Origins whose public, immutable files the shell needs: this site, the
/// Flutter engine CDN and the font CDN the engine uses. Everything else
/// (Supabase, YouTube, avatars on storage buckets) is deliberately excluded.
const _publicCdns = {'https://www.gstatic.com', 'https://fonts.gstatic.com'};

class _BrowserOfflineMapStore implements WebOfflineMapStore {
  bool get _supported {
    try {
      return web.window.isSecureContext &&
          (web.window as JSObject).has('caches') &&
          (web.window.navigator as JSObject).has('serviceWorker');
    } catch (_) {
      return false;
    }
  }

  String _abs(String relative) =>
      Uri.parse(web.document.baseURI).resolve(relative).toString();

  String _assetUrl(String key) => _abs(ui_web.assetManager.getAssetUrl(key));

  @override
  Future<WebOfflineStatus> inspect({required String packSha256}) async {
    if (!_supported) return const WebOfflineStatus(WebOfflineState.unsupported);
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      final record = await cache.match(_abs(_readyPath).toJS).toDart;
      if (record == null) {
        return const WebOfflineStatus(WebOfflineState.notPrepared);
      }
      final text = (await record.text().toDart).toDart;
      final json = jsonDecode(text) as Map<String, dynamic>;
      final preparedAt = DateTime.tryParse(json['preparedAt'] as String? ?? '');
      if (json['packSha256'] != packSha256) {
        // A different pack (older app release) was prepared: the current
        // map is not stored yet.
        return const WebOfflineStatus(WebOfflineState.notPrepared);
      }
      final urls = (json['urls'] as List).cast<String>();
      for (final url in urls) {
        if (await cache.match(url.toJS).toDart == null) {
          return WebOfflineStatus(WebOfflineState.evicted,
              preparedAt: preparedAt);
        }
      }
      return WebOfflineStatus(WebOfflineState.ready, preparedAt: preparedAt);
    } catch (_) {
      // Cache Storage can throw in some private windows.
      return const WebOfflineStatus(WebOfflineState.failed, detail: 'private');
    }
  }

  /// Every resource this page has loaded from its own origin or the
  /// Flutter/Google font CDNs. `web/index.html` records them from page start
  /// with a PerformanceObserver, so a long session cannot push early shell
  /// files out of the browser's 250-entry resource-timing buffer; that
  /// buffer is only a fallback.
  List<String> _observedUrls() {
    final names = <String>[];
    final recorded = (web.window as JSObject)['__streamerResources'];
    final list = recorded?.dartify();
    if (list is List) {
      names.addAll(list.whereType<String>());
    }
    for (final entry
        in web.window.performance.getEntriesByType('resource').toDart) {
      names.add(entry.name);
    }
    final origin = web.window.location.origin;
    final urls = <String>{};
    for (final name in names) {
      final uri = Uri.tryParse(name);
      if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
        continue;
      }
      final entryOrigin = '${uri.scheme}://${uri.authority}';
      if (entryOrigin == origin || _publicCdns.contains(entryOrigin)) {
        urls.add(uri.removeFragment().toString());
      }
    }
    return urls.toList()..sort();
  }

  /// Map labels use the engine's default font, which on the web is Roboto
  /// plus Noto fallbacks fetched from the font CDN on first use. Shape a
  /// Latin and Arabic sample so both are fetched (and then stored below)
  /// even if this visit never showed Arabic labels. Returns whether the
  /// Arabic fallback font was seen.
  Future<bool> _warmLabelFonts() async {
    // Not shown to anyone: it only makes the engine fetch the fallback fonts.
    const sample = 'Al Khobar Dhahran Dammam 0123456789 '
        'الخبر '
        'الظهران '
        'الدمام';
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle())..addText(sample);
    builder.build().layout(const ui.ParagraphConstraints(width: 600));
    for (var i = 0; i < 40; i++) {
      if (_observedUrls().any((u) => u.contains('notosansarabic'))) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  /// Files without which a later offline start would not work or would draw
  /// broken labels: the page and bootstrap, compiled app, asset and font
  /// manifests, every font the app declares, the rendering engine (JS and
  /// wasm), and the engine's Latin and Arabic label fonts. Returns null when
  /// any of them cannot be identified, so preparation fails rather than
  /// reporting a shell that cannot start.
  Future<List<String>?> _requiredShellUrls(List<String> observed) async {
    final required = <String>{
      _abs(''),
      _abs('index.html'),
      _abs('flutter_bootstrap.js'),
      _abs('manifest.json'),
      _abs('assets/FontManifest.json'),
      _abs('assets/AssetManifest.bin.json'),
    };
    final program = RegExp(r'/main\.dart\.(js|mjs|wasm)$');
    final mains = observed.where((u) => program.hasMatch(Uri.parse(u).path));
    required.addAll(mains.isEmpty ? [_abs('main.dart.js')] : mains);

    try {
      final response = await web.window
          .fetch(_abs('assets/FontManifest.json').toJS,
              web.RequestInit(cache: 'reload'))
          .toDart;
      if (!response.ok) return null;
      final text = (await response.text().toDart).toDart;
      for (final family in (jsonDecode(text) as List).cast<Map>()) {
        for (final font in (family['fonts'] as List).cast<Map>()) {
          required.add(_assetUrl(font['asset'] as String));
        }
      }
    } catch (_) {
      return null;
    }

    final engine = observed.where((u) {
      final path = Uri.parse(u).path;
      return (path.contains('canvaskit') || path.contains('skwasm')) &&
          (path.endsWith('.js') || path.endsWith('.wasm'));
    }).toList();
    if (!engine.any((u) => u.endsWith('.wasm')) ||
        !engine.any((u) => u.endsWith('.js'))) {
      return null;
    }
    required.addAll(engine);

    // The engine's fallback fonts come from the font CDN by default, or from
    // this site when the build is configured to host them itself.
    final labelFonts = observed.where((u) {
      final path = Uri.parse(u).path.toLowerCase();
      return (path.contains('/roboto') || path.contains('notosansarabic')) &&
          RegExp(r'\.(woff2?|ttf|otf)$').hasMatch(path);
    });
    if (!labelFonts.any((u) => u.toLowerCase().contains('/roboto')) ||
        !labelFonts.any((u) => u.toLowerCase().contains('notosansarabic'))) {
      return null;
    }
    required.addAll(labelFonts);
    return required.toList();
  }

  @override
  Future<WebOfflineStatus> prepare({
    required String packSha256,
    required String packAssetKey,
    required List<String> requiredAssetKeys,
    required int packBytes,
    void Function(int done, int total)? onProgress,
  }) async {
    if (!_supported) return const WebOfflineStatus(WebOfflineState.unsupported);
    try {
      // The worker must control later visits for the cache to be used.
      await web.window.navigator.serviceWorker.ready.toDart
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      return const WebOfflineStatus(WebOfflineState.failed,
          detail: 'unsupported');
    }
    try {
      final estimate = await web.window.navigator.storage.estimate().toDart;
      final free = estimate.quota - estimate.usage;
      if (free < packBytes * 2 + (32 << 20)) {
        return const WebOfflineStatus(WebOfflineState.failed, detail: 'quota');
      }
      // Best effort; browsers may still evict under pressure.
      unawaited(web.window.navigator.storage.persist().toDart);
    } catch (_) {
      // estimate()/persist() are optional; the put below reports quota.
    }

    await _warmLabelFonts();
    final observed = _observedUrls();
    final shell = await _requiredShellUrls(observed);
    if (shell == null) {
      return const WebOfflineStatus(WebOfflineState.failed,
          detail: 'incomplete');
    }
    final required = <String>{
      for (final key in requiredAssetKeys) _assetUrl(key),
      ...shell,
    }.toList();
    final packUrl = _assetUrl(packAssetKey);
    // Everything else this visit loaded (images, other screens' assets) is
    // stored when possible but does not decide readiness.
    // The worker matches stored files ignoring the query string, so one
    // copy per path is enough (a long session can load the same file with
    // many different queries).
    String pathKey(String u) => Uri.parse(u).replace(query: '').toString();
    final seenPaths = required.map(pathKey).toSet();
    final optional = observed.where((u) => seenPaths.add(pathKey(u))).toList();
    final all = [...required, ...optional];
    final stored = <String>[];
    try {
      // Download into a staging cache; the live offline copy is replaced
      // only after every required file arrived and the pack verified, so an
      // interrupted or failed run never damages an existing offline copy.
      await web.window.caches.delete(_stagingName).toDart;
      final staging = await web.window.caches.open(_stagingName).toDart;
      var done = 0;
      for (final url in all) {
        final isRequired = done < required.length;
        web.Response? response;
        try {
          // `reload` tells the worker not to answer from the old offline
          // copy: preparation must read the network, or fail honestly.
          response = await web.window
              .fetch(url.toJS, web.RequestInit(cache: 'reload'))
              .toDart;
        } catch (_) {
          response = null;
        }
        if (response == null || !response.ok) {
          if (isRequired) {
            await web.window.caches.delete(_stagingName).toDart;
            return const WebOfflineStatus(WebOfflineState.failed,
                detail: 'network');
          }
        } else {
          if (url == packUrl) {
            final buffer = await response.clone().arrayBuffer().toDart;
            if (await sha256Hex(buffer.toDart.asUint8List()) != packSha256) {
              await web.window.caches.delete(_stagingName).toDart;
              return const WebOfflineStatus(WebOfflineState.failed,
                  detail: 'mismatch');
            }
          }
          await staging.put(url.toJS, response).toDart;
          stored.add(url);
        }
        done++;
        onProgress?.call(done, all.length);
      }

      final live = await web.window.caches.open(_cacheName).toDart;
      await live.delete(_abs(_readyPath).toJS).toDart;
      for (final url in stored) {
        final copy = await staging.match(url.toJS).toDart;
        if (copy != null) await live.put(url.toJS, copy).toDart;
      }
      // Drop files an older shell stored that this one no longer uses.
      final keep = {...stored, _abs(_readyPath)};
      for (final request in (await live.keys().toDart).toDart) {
        if (!keep.contains(request.url)) {
          await live.delete(request).toDart;
        }
      }
      final now = DateTime.now().toUtc();
      final record = jsonEncode({
        'packSha256': packSha256,
        'preparedAt': now.toIso8601String(),
        'urls': stored,
      });
      // Readiness is written last.
      await live
          .put(
            _abs(_readyPath).toJS,
            web.Response(
              record.toJS,
              web.ResponseInit(
                headers: {'content-type': 'application/json'}.jsify()
                    as web.HeadersInit,
              ),
            ),
          )
          .toDart;
      await web.window.caches.delete(_stagingName).toDart;
      return WebOfflineStatus(WebOfflineState.ready,
          preparedAt: now, done: done, total: all.length);
    } catch (error) {
      try {
        await web.window.caches.delete(_stagingName).toDart;
      } catch (_) {}
      final quota = error.toString().contains('Quota');
      return WebOfflineStatus(WebOfflineState.failed,
          detail: quota ? 'quota' : 'network');
    }
  }

  @override
  Future<void> reset() async {
    if (!_supported) return;
    await web.window.caches.delete(_stagingName).toDart;
    await web.window.caches.delete(_cacheName).toDart;
  }
}
