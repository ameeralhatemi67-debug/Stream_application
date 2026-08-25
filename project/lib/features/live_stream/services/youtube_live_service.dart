import 'package:flutter/foundation.dart';
import 'rtmp_publish_engine.dart' show BroadcastQualityPreset;

/// Everything [RtmpPublishEngine]/`AppProvider` need to actually push
/// video/audio to the broadcast this service just created.
typedef YouTubeBroadcastSession = ({
  String broadcastId,
  String videoId,
  String rtmpUrl,
  String streamKey,
});

/// Automated client for the YouTube Live Streaming API v3's *write*
/// endpoints (`liveBroadcasts.insert`, `liveStreams.insert`,
/// `liveBroadcasts.bind`) -- distinct from the existing read-only
/// `YouTubeApiService` (Data API v3, plain API-key auth, no ability to
/// create anything on a user's behalf).
///
/// Creating a live broadcast for a signed-in streamer requires an OAuth
/// access token carrying the `https://www.googleapis.com/auth/youtube`
/// scope. This app's Google sign-in goes through Supabase Auth
/// (`SupabaseAuthService`), which today only requests basic profile/email
/// scopes -- there is no such access token anywhere in this codebase yet.
/// Until that OAuth plumbing exists, this service runs entirely in
/// simulation mode: deterministic, offline, and safe for every test and
/// demo build. When real OAuth is wired up, `createBroadcastSession` and
/// `endBroadcastSession` are the two call sites to swap for real
/// `POST https://www.googleapis.com/youtube/v3/liveBroadcasts` (etc.) calls
/// -- the [YouTubeBroadcastSession] contract they return is already what
/// the rest of the app (`RtmpPublishEngine`, `AppProvider`) expects.
class YouTubeLiveService {
  /// Creates (simulates) a bound YouTube Live broadcast + stream pair ready
  /// to receive RTMP video/audio immediately.
  Future<YouTubeBroadcastSession> createBroadcastSession({
    required String title,
    required String description,
    required bool isAudioOnly,
    required BroadcastQualityPreset quality,
  }) async {
    // Mimics real network latency so QuickGoLiveSheet's loading state reads
    // naturally rather than flashing instantly.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final videoId = 'sim_$suffix';
    final broadcastId = 'bcast_$suffix';

    debugPrint(
      'YouTubeLiveService (simulated): created broadcast "$title" '
      '(${isAudioOnly ? 'audio-only' : 'video'}, ${quality.name}) -> $videoId',
    );

    return (
      broadcastId: broadcastId,
      videoId: videoId,
      rtmpUrl: 'rtmp://a.rtmp.youtube.com/live2',
      streamKey: 'sim-key-$suffix',
    );
  }

  /// Transitions the broadcast to `complete` so YouTube saves it as a
  /// permanent VOD (simulated -- see class doc).
  Future<void> endBroadcastSession({required String broadcastId}) async {
    debugPrint('YouTubeLiveService (simulated): ended broadcast $broadcastId');
  }
}
