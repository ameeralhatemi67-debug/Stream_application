import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
