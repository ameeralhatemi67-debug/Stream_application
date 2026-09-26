import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'map_offline_store.dart';

/// SHA-256 of the bundled pack, off the UI isolate.
Future<String> sha256Hex(Uint8List bytes) =>
    Isolate.run(() => crypto.sha256.convert(bytes).toString());

/// Native builds carry the pack inside the app; there is nothing to prepare.
WebOfflineMapStore? createWebOfflineStore() => null;
