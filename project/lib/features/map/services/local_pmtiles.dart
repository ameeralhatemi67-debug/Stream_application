import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:http/http.dart' as http;

/// Serves HTTP-style byte-range reads from an archive already held in
/// memory, so flutter_map_vector_tiles' published PMTiles reader (which only
/// speaks HTTP range requests) can read the bundled pack without a network,
/// a localhost server or a fork of its parser.
///
/// Only `GET` for the one internal [archiveUri] with a single
/// `Range: bytes=a-b` header is accepted; anything else is a local error,
/// never forwarded anywhere. Reads are bounded by [maxRangeBytes].
class LocalRangeClient extends http.BaseClient {
  LocalRangeClient(this.archiveUri, this._bytes,
      {this.maxRangeBytes = 4 << 20});

  /// Internal identity only (`streamer-pack://<sha>/basemap.pmtiles`); it is
  /// never resolvable on any network.
  final Uri archiveUri;
  final Uint8List _bytes;
  final int maxRangeBytes;
  bool _closed = false;

  /// Number of served ranges, for tests and evidence.
  int servedRanges = 0;

  static final _range = RegExp(r'^bytes=(\d+)-(\d+)$');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('local pack closed', request.url);
    if (request.method != 'GET' || request.url != archiveUri) {
      throw http.ClientException(
          'local pack only serves its own archive', request.url);
    }
    final header = request.headers['range'] ?? request.headers['Range'];
    final match = header == null ? null : _range.firstMatch(header.trim());
    if (match == null) {
      return _status(400, request);
    }
    final start = int.parse(match.group(1)!);
    final requestedEnd = int.parse(match.group(2)!);
    final size = _bytes.length;
    if (start >= size || requestedEnd < start) return _status(416, request);
    final end = requestedEnd >= size ? size - 1 : requestedEnd;
    final length = end - start + 1;
    if (length > maxRangeBytes) return _status(416, request);
    servedRanges++;
    final body = Uint8List.sublistView(_bytes, start, end + 1);
    return http.StreamedResponse(
      Stream.value(body),
      206,
      contentLength: length,
      request: request,
      headers: {
        'content-range': 'bytes $start-$end/$size',
        'content-length': '$length',
      },
    );
  }

  http.StreamedResponse _status(int code, http.BaseRequest request) =>
      http.StreamedResponse(const Stream.empty(), code,
          contentLength: 0, request: request);

  @override
  void close() => _closed = true;
}

/// A local-archive provider: delegates tile reads to the package's PMTiles
/// reader over [LocalRangeClient], disables the package's disk tile cache
/// (the archive already is local), and keys decoded-tile caches by the pack
/// hash so a new pack can never be served stale tiles of an old one.
class LocalPmTilesProvider extends vt.VectorTileProvider {
  LocalPmTilesProvider._(this._delegate, this._client, this._cacheKey);

  static Future<LocalPmTilesProvider> open(
    Uint8List archive, {
    required String packSha256,
  }) async {
    final uri = Uri.parse('streamer-pack://$packSha256/basemap.pmtiles');
    final client = LocalRangeClient(uri, archive);
    try {
      final delegate = await vt.PmTilesVectorTileProvider.open(
        uri.toString(),
        client: client,
        maxRetries: 0,
      );
      return LocalPmTilesProvider._(
          delegate, client, 'tricity-pack:$packSha256');
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  final vt.PmTilesVectorTileProvider _delegate;
  final LocalRangeClient _client;
  final String _cacheKey;

  vt.PmTilesHeader get header => _delegate.header;
  int get servedRanges => _client.servedRanges;

  @override
  int get maximumZoom => _delegate.maximumZoom;

  @override
  int get minimumZoom => _delegate.minimumZoom;

  @override
  String get cacheKey => _cacheKey;

  @override
  bool get cacheBytesToDisk => false;

  @override
  Future<vt.TileResponse> load(vt.TileKey tile,
          {vt.CancellationToken? cancellation}) =>
      _delegate.load(tile, cancellation: cancellation);

  @override
  void dispose() {
    _delegate.dispose();
    _client.close();
  }
}
