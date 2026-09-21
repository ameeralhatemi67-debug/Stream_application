import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Resolves an image reference, or null when there is nothing to show.
///
/// The difference from [buildSafeImageProvider] is the empty case: that one
/// substitutes a real person's photograph, which is only ever right where the
/// caller means *that* person. Everywhere else an absent avatar or thumbnail
/// has to stay absent, so the caller can paint a neutral placeholder.
///
/// Returning null also stops `NetworkImage('')`, which several widgets built
/// for a streamer with no avatar: it resolves against the app's own base URI
/// and fails with HTTP 400 on every rebuild, leaving an empty circle and a
/// repeated console error instead of a fallback.
ImageProvider? resolveImageProviderOrNull(String? path) {
  final cleanPath = path?.trim() ?? '';
  if (cleanPath.isEmpty) return null;
  if (cleanPath.startsWith('assets/')) return AssetImage(cleanPath);
  if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
    return NetworkImage(cleanPath);
  }
  if (!kIsWeb) {
    try {
      final file = File(cleanPath.replaceFirst('file://', ''));
      if (file.existsSync()) return FileImage(file);
    } catch (e) {
      debugPrint('resolveImageProviderOrNull file check error: $e');
    }
  }
  return null;
}

/// Robust ImageProvider resolver that prevents NetworkImage URI crashes on local file paths
ImageProvider buildSafeImageProvider({
  String? path,
  Uint8List? bytes,
  String defaultAsset = 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
}) {
  if (bytes != null && bytes.isNotEmpty) {
    return MemoryImage(bytes);
  }

  if (path != null && path.trim().isNotEmpty) {
    final cleanPath = path.trim();
    if (cleanPath.startsWith('assets/')) {
      return AssetImage(cleanPath);
    } else if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      return NetworkImage(cleanPath);
    } else if (!kIsWeb) {
      try {
        final file = File(cleanPath.replaceFirst('file://', ''));
        if (file.existsSync()) {
          return FileImage(file);
        }
      } catch (e) {
        debugPrint('SafeImageProvider file check error: $e');
      }
    }
  }

  return AssetImage(defaultAsset);
}
