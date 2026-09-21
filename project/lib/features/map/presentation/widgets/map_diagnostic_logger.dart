import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../../../core/theme/app_theme.dart';

/// Built-in Diagnostic Logger & Real-Time Terminal Messenger
/// Logs detailed spatial map metrics, HTTP tile loading events, zoom threshold crossings,
/// network tile errors, and main-thread performance directly to the terminal console
/// and an optional floating debug diagnostic pill.
class MapDiagnosticLogger {
  static int _tileLoadSuccessCount = 0;
  static int _tileLoadErrorCount = 0;

  /// Log a diagnostic message to the Flutter terminal with timestamp & severity tag
  static void log(String category, String message, {bool isError = false}) {
    final now = DateTime.now();
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}";
    final prefix =
        isError ? " [MAP DIAGNOSTIC ERROR]" : " [MAP DIAGNOSTIC]";

    debugPrint("$prefix [$timeStr] [$category] $message");
  }

  /// Called when map camera zoom level changes
  static void logZoomEvent(double currentZoom, bool areMarkersVisible) {
    log("ZOOM_CAMERA",
        "Camera Zoom: ${currentZoom.toStringAsFixed(2)} | Marker Layer Threshold (>=10.2): ${areMarkersVisible ? 'VISIBLE (ACTIVE)' : 'HIDDEN (ZOOM OUT)'}");
  }

  /// Called when a tile fails to load over HTTP
  static void logTileError(TileImage tile, Object error, [StackTrace? stackTrace]) {
    _tileLoadErrorCount++;
    log("TILE_HTTP_ERROR",
        "Failed to load tile x=${tile.coordinates.x}, y=${tile.coordinates.y}, z=${tile.coordinates.z} | Total Errors: $_tileLoadErrorCount | Error: $error",
        isError: true);
  }

  /// Called when a tile loads successfully
  static void logTileSuccess(TileImage tile) {
    _tileLoadSuccessCount++;
    if (_tileLoadSuccessCount % 10 == 0) {
      log("TILE_HTTP_SUCCESS",
          "Tiles Successfully Loaded: $_tileLoadSuccessCount | Errors: $_tileLoadErrorCount");
    }
  }

  /// Reset session counters
  static void reset() {
    _tileLoadSuccessCount = 0;
    _tileLoadErrorCount = 0;
    log("DIAGNOSTIC_SYSTEM",
        "Map Diagnostic Session Initialized & Counters Reset");
  }
}

/// Floating Live Terminal Diagnostic Messenger Bar Widget
class MapDiagnosticMessengerBar extends StatelessWidget {
  final double currentZoom;
  final bool areMarkersVisible;

  const MapDiagnosticMessengerBar({
    super.key,
    required this.currentZoom,
    required this.areMarkersVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.media.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: areMarkersVisible ? AppTheme.danger : AppTheme.primary,
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
                color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(
              areMarkersVisible
                  ? Icons.bug_report_rounded
                  : Icons.info_outline_rounded,
              color:
                  areMarkersVisible ? AppTheme.danger : AppTheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "DIAGNOSTIC | Zoom: ${currentZoom.toStringAsFixed(2)} | Markers: ${areMarkersVisible ? 'ACTIVE (ZOOMED IN)' : 'HIDDEN'} | Check Terminal Logs",
                style: const TextStyle(
                  color: AppTheme.onMedia,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
