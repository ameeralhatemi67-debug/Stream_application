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

  bool _hasFontEntry(String needle) => web.window.performance
      .getEntriesByType('resource')
      .toDart
      .any((e) => e.name.contains(needle));

  /// Map labels use the engine's default font, which on the web is Roboto
  /// plus Noto fallbacks fetched from the font CDN on first use. Shape a
  /// Latin and Arabic sample so both are fetched (and then stored below)
  /// even if this visit never showed Arabic labels.
  Future<void> _warmLabelFonts() async {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle())
      ..addText('Al Khobar Dhahran Dammam 0123456789 '
          'الخبر '
          'الظهران '
          'الدمام');
    builder.build().layout(const ui.ParagraphConstraints(width: 600));
    for (var i = 0; i < 40 && !_hasFontEntry('notosansarabic'); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  List<String> _shellUrls() {
    final origin = web.window.location.origin;
    final urls = <String>{_abs(''), _abs('index.html')};
    final entries = web.window.performance.getEntriesByType('resource').toDart;
    for (final entry in entries) {
      final name = entry.name;
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

  @override
  Future<WebOfflineStatus> prepare({
    required String packSha256,
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
    final required = [for (final key in requiredAssetKeys) _assetUrl(key)];
    final optional = _shellUrls().where((u) => !required.contains(u)).toList();
    final all = [...required, ...optional];
    final stored = <String>[];
    try {
      final cache = await web.window.caches.open(_cacheName).toDart;
      // Withdraw any earlier readiness first: an interrupted run must never
      // look ready.
      await cache.delete(_abs(_readyPath).toJS).toDart;
      var done = 0;
      for (final url in all) {
        final isRequired = done < required.length;
        web.Response response;
        try {
          response = await web.window.fetch(url.toJS).toDart;
        } catch (_) {
          if (isRequired) {
            return const WebOfflineStatus(WebOfflineState.failed,
                detail: 'network');
          }
          done++;
          continue;
        }
        if (!response.ok) {
          if (isRequired) {
            return const WebOfflineStatus(WebOfflineState.failed,
                detail: 'network');
          }
        } else {
          await cache.put(url.toJS, response).toDart;
          stored.add(url);
        }
        done++;
        onProgress?.call(done, all.length);
      }
      final now = DateTime.now().toUtc();
      final record = jsonEncode({
        'packSha256': packSha256,
        'preparedAt': now.toIso8601String(),
        'urls': stored,
      });
      await cache
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
      return WebOfflineStatus(WebOfflineState.ready,
          preparedAt: now, done: done, total: all.length);
    } catch (error) {
      final quota = error.toString().contains('Quota');
      return WebOfflineStatus(WebOfflineState.failed,
          detail: quota ? 'quota' : 'network');
    }
  }

  @override
  Future<void> reset() async {
    if (!_supported) return;
    await web.window.caches.delete(_cacheName).toDart;
  }
}
