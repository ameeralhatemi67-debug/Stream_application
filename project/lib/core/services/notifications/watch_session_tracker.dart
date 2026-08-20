import 'dart:async';

/// Tracks active viewing duration of live broadcasts and dispatches
/// a milestone thank-you alert when the stream concludes if watched >= 1 hour.
class WatchSessionTracker {
  static final Map<String, int> _streamWatchedSeconds = {};
  static final Map<String, String> _streamerNames = {};
  static final Map<String, String> _streamerIds = {};

  static String? _activeStreamId;
  static DateTime? _sessionStartTime;
  static Timer? _ticker;

  /// Starts or resumes tracking for a live stream session
  static void startWatching({
    required String streamId,
    required String streamerId,
    required String streamerName,
  }) {
    if (_activeStreamId == streamId && _ticker != null) return;

    // Save previous active session if switching streams
    if (_activeStreamId != null && _activeStreamId != streamId) {
      _flushCurrentSession();
    }

    _activeStreamId = streamId;
    _streamerIds[streamId] = streamerId;
    _streamerNames[streamId] = streamerName;
    _sessionStartTime = DateTime.now();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_sessionStartTime != null && _activeStreamId != null) {
        final currentTotal = _streamWatchedSeconds[_activeStreamId!] ?? 0;
        _streamWatchedSeconds[_activeStreamId!] = currentTotal + 1;
      }
    });
  }

  /// Stops tracking active viewing when the user leaves the player
  static void stopWatching() {
    _flushCurrentSession();
  }

  static void _flushCurrentSession() {
    _ticker?.cancel();
    _ticker = null;
    _sessionStartTime = null;
    _activeStreamId = null;
  }

  /// Gets the total accumulated seconds watched for a specific broadcast stream
  static int getWatchedSeconds(String streamId) {
    return _streamWatchedSeconds[streamId] ?? 0;
  }

  /// For testing and manual simulation: injects watched seconds directly
  static void simulateWatchedSeconds(String streamId, String streamerId, String streamerName, int seconds) {
    _streamWatchedSeconds[streamId] = seconds;
    _streamerIds[streamId] = streamerId;
    _streamerNames[streamId] = streamerName;
  }

  /// Evaluates whether the user watched >= 60 minutes (3600s) upon stream conclusion.
  /// If threshold is met, calls [onMilestoneReached] and clears the session.
  static bool onStreamEnded(
    String streamId, {
    int thresholdSeconds = 3600, // 1 hour default
    required void Function(String streamerId, String streamerName, Duration watchedDuration) onMilestoneReached,
  }) {
    final totalSeconds = _streamWatchedSeconds[streamId] ?? 0;
    final streamerId = _streamerIds[streamId] ?? '';
    final streamerName = _streamerNames[streamId] ?? 'Broadcaster';

    if (totalSeconds >= thresholdSeconds) {
      onMilestoneReached(
        streamerId,
        streamerName,
        Duration(seconds: totalSeconds),
      );
      _streamWatchedSeconds.remove(streamId);
      _streamerIds.remove(streamId);
      _streamerNames.remove(streamId);
      return true;
    }

    _streamWatchedSeconds.remove(streamId);
    _streamerIds.remove(streamId);
    _streamerNames.remove(streamId);
    return false;
  }

  /// Resets all tracking state (e.g. on user logout)
  static void reset() {
    _flushCurrentSession();
    _streamWatchedSeconds.clear();
    _streamerIds.clear();
    _streamerNames.clear();
  }
}
