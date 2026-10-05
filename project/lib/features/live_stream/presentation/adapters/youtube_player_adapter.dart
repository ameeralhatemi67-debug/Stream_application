import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'dart:convert';
import 'youtube_navigation_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';
import '../widgets/stream_state_placeholder_overlay.dart';

/// Concrete player adapter using an optimized [WebViewController] with
/// Strategy 1 (strict-origin-when-cross-origin + youtube-nocookie.com)
/// to eliminate Error 150/152/153 across both Live Streams and Archived VODs.
class YouTubePlayerAdapter extends AbstractVideoPlayer {
  const YouTubePlayerAdapter({
    super.key,
    required super.streamUrl,
    super.fallbackUrls = const [],
    super.autoPlay = true,
    super.onPlayerReady,
    super.onStateChanged,
    super.onError,
    super.aspectRatio = 16 / 9,
    super.preferredQuality = 'auto',
    this.initialMuted = false,
  });

  /// Start muted: the viewer muted the room before this player was created
  /// (Retry or a reload makes a new player).
  final bool initialMuted;

  @override
  State<YouTubePlayerAdapter> createState() => _YouTubePlayerAdapterState();
}

/// The one origin this adapter ever loads from. ADR-006: the embed base URL
/// and the referrer policy are load-bearing (they are what keeps YouTube from
/// rejecting the embed with Error 150/152/153), so the `origin` query param
/// below is derived from this constant rather than written out separately --
/// an origin that disagrees with the document's own base URL is worse than
/// no origin at all.
const String _embedBaseUrl = 'https://www.youtube-nocookie.com';

class _YouTubePlayerAdapterState extends State<YouTubePlayerAdapter>
    implements PlayerTransport {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late String _currentVideoId;
  int _currentFallbackIndex = 0;

  /// The viewer's mute choice, re-applied after the embed (re)loads. A new
  /// player starts from the room's current choice (see [initialMuted]).
  late bool _viewerMuted = widget.initialMuted;
  late final ValueNotifier<bool> _mutedNotifier =
      ValueNotifier<bool>(widget.initialMuted);

  @override
  ValueListenable<bool> get mutedListenable => _mutedNotifier;

  /// Set only by the supported IFrame API's onReady callback.
  bool _heardFromPlayer = false;

  /// A playback state (not just "ready") has been reported.
  Timer? _silentPlayerTimer;

  @override
  void dispose() {
    _silentPlayerTimer?.cancel();
    _mutedNotifier.dispose();
    super.dispose();
  }

  // Commands need the app's JavaScript channel into the page, which exists
  // only in the Android and iOS web views. The web build embeds a plain
  // iframe (no channel), and desktop has no web view.
  @override
  bool get supportsCommands =>
      _heardFromPlayer &&
      !_hasError &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Sends a command only after the supported IFrame API reports ready.
  /// Delivery does not prove playback: the room follows onStateChange.
  Future<bool> _postCommand(String func) async {
    if (!supportsCommands || _isLoading || _hasError) return false;
    final js = "playerCommand('$func');";
    try {
      final result = await _webViewController.runJavaScriptReturningResult(js);
      return result == 'ok' || result == '"ok"';
    } catch (e) {
      debugPrint('[YouTubePlayerAdapter] $func failed: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> play() => _postCommand('playVideo');

  @override
  Future<bool> pause() => _postCommand('pauseVideo');

  @override
  Future<bool> setMuted(bool muted) async {
    final sent = await _postCommand(muted ? 'mute' : 'unMute');
    if (sent) {
      _viewerMuted = muted;
    }
    return sent;
  }

  @override
  void initState() {
    super.initState();
    _currentVideoId = _extractVideoId(widget.streamUrl);
    _initializeWebPlayer();
  }

  /// Nothing loads without a valid video ID. The adapter used to substitute
  /// the IFrame API sample video (M7lc1UVf-VE), which is how a viewer room
  /// played "YouTube Developers Live: Embedded Web Player Customization"
  /// instead of a phone broadcast (owner retest 2026-09-25).
  void _showMissingVideo() {
    _isLoading = false;
    _hasError = true;
    _errorMessage = 'live.no_valid_watch_id'.tr();
  }

  void _initializeWebPlayer() {
    late final PlatformWebViewControllerCreationParams params;
    if (!kIsWeb && WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    try {
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    } catch (_) {}

    try {
      controller.setBackgroundColor(AppTheme.media);
    } catch (_) {}

    if (!kIsWeb) {
      try {
        controller.addJavaScriptChannel(
          'FlutterYouTubeBridge',
          onMessageReceived: (JavaScriptMessage message) {
            _handleBridgeMessage(message.message);
          },
        );
      } catch (_) {}

      try {
        controller.setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (String url) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
                widget.onPlayerReady?.call();
                // If the embed never reports (the handshake failed), stop
                // covering it with the "starting" placeholder after a while
                // and let its own controls be used. As on web, this means
                // "show the player", not "live"; the room's LIVE badge
                // follows the server.
                _silentPlayerTimer?.cancel();
                _silentPlayerTimer = Timer(const Duration(seconds: 10), () {
                  if (mounted && !_heardFromPlayer && !_hasError) {
                    widget.onStateChanged?.call(StreamState.unconfirmed);
                  }
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                _handleStreamFailure(error.description);
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              return isAllowedYouTubeNavigation(request.url)
                  ? NavigationDecision.navigate
                  : NavigationDecision.prevent;
            },
          ),
        );
      } catch (_) {}

      if (controller.platform is AndroidWebViewController) {
        final androidController =
            controller.platform as AndroidWebViewController;
        androidController.setMediaPlaybackRequiresUserGesture(false);
      }
    }

    _webViewController = controller;
    if (_currentVideoId.isEmpty) {
      _showMissingVideo();
      return;
    }
    _loadVideoEmbed(_currentVideoId);
  }

  void _handleBridgeMessage(String jsonStr) {
    // Dedicated owner-run diagnostic build; unreachable in release builds.
    if (kDebugMode &&
        const bool.fromEnvironment('WAVE4V2_SUPPRESS_PLAYER_READY')) {
      return;
    }
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final type = data['type'] as String?;
      if (!mounted ||
          !const {'ready', 'muted', 'state', 'error'}.contains(type)) {
        return;
      }
      if (type == 'ready') {
        _heardFromPlayer = true;
        _silentPlayerTimer?.cancel();
        widget.onPlayerReady?.call();
        // The bridge reports getPlayerState immediately after ready. Wait
        // for that acknowledgement instead of inventing a playback state.
        return;
      }
      if (type == 'muted') {
        final muted = data['value'] == true;
        _viewerMuted = muted;
        if (mounted) _mutedNotifier.value = muted;
        return;
      }
      if (type == 'state') {
        final stateVal = data['value'] as int?;
        if (stateVal == -1 || stateVal == 5) {
          // Unstarted or cued: loaded but not playing.
          widget.onStateChanged?.call(StreamState.paused);
        } else if (stateVal == 1) {
          // Playing
          if (mounted) {
            setState(() {
              _hasError = false;
              _isLoading = false;
            });
          }
          widget.onStateChanged?.call(StreamState.live);
        } else if (stateVal == 2) {
          // Paused
          widget.onStateChanged?.call(StreamState.paused);
        } else if (stateVal == 3) {
          // Buffering
          widget.onStateChanged?.call(StreamState.buffering);
        } else if (stateVal == 0) {
          // Ended -> Try fallback stream or trigger offline/ended
          _handleStreamFailure('Stream ended (code 0)');
        }
      } else if (type == 'error') {
        final code = data['code'];
        _handleStreamFailure('YouTube playback error: $code');
      }
    } catch (e) {
      debugPrint('[YouTubePlayerAdapter] Bridge parse error: $e');
    }
  }

  void _handleStreamFailure(String reason) {
    final fallbacks = widget.fallbackUrls;
    if (_currentFallbackIndex < fallbacks.length) {
      final nextId = _extractVideoId(fallbacks[_currentFallbackIndex]);
      _currentFallbackIndex++;
      if (nextId.isEmpty) {
        _handleStreamFailure(reason);
        return;
      }
      debugPrint(
          '[YouTubePlayerAdapter] Failover to fallback stream ($nextId): $reason');
      _currentVideoId = nextId;
      _loadVideoEmbed(_currentVideoId);
    } else {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = reason;
          _isLoading = false;
        });
        widget.onError?.call(reason);
        widget.onStateChanged?.call(StreamState.fallbackError);
      }
    }
  }

  void _loadVideoEmbed(String videoId) {
    _silentPlayerTimer?.cancel();
    _heardFromPlayer = false;
    if (kIsWeb) {
      // No `origin` on web: the real origin there is the host page, which
      // this adapter cannot know, and a mismatched origin is exactly what
      // ADR-006's Error 150/153 work was about.
      final embedUrl =
          'https://www.youtube-nocookie.com/embed/$videoId?autoplay=${widget.autoPlay ? 1 : 0}&playsinline=1&controls=1&rel=0&modestbranding=1&enablejsapi=1&mute=${_viewerMuted ? 1 : 0}';
      try {
        _webViewController.loadRequest(Uri.parse(embedUrl)).then((_) {
          if (!mounted || _currentVideoId != videoId) return;
          // The web plugin sets iframe.src and has no page-finished callback.
          // Remove our loading cover on every load, including Retry/watch
          // changes, so YouTube can show its own controls or error. This is
          // not a playback acknowledgement; app transport remains disabled.
          setState(() => _isLoading = false);
          widget.onPlayerReady?.call();
          widget.onStateChanged?.call(StreamState.unconfirmed);
        }).catchError((Object error) {
          if (mounted && _currentVideoId == videoId) {
            _handleStreamFailure('live.player_not_ready'.tr());
          }
        });
      } catch (e) {
        _handleStreamFailure('live.player_not_ready'.tr());
      }
    } else {
      final html = buildYouTubeEmbedHtml(
          videoId: videoId, autoPlay: widget.autoPlay, muted: _viewerMuted);

      _webViewController.loadHtmlString(
        html,
        baseUrl: _embedBaseUrl,
      );
    }
  }

  @override
  void didUpdateWidget(YouTubePlayerAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streamUrl != oldWidget.streamUrl) {
      final newVideoId = _extractVideoId(widget.streamUrl);
      if (newVideoId != _currentVideoId) {
        _currentVideoId = newVideoId;
        _currentFallbackIndex = 0;
        if (newVideoId.isEmpty) {
          setState(_showMissingVideo);
        } else {
          setState(() {
            _hasError = false;
            _isLoading = true;
          });
          _loadVideoEmbed(_currentVideoId);
        }
      }
    }
  }

  /// The 11-character video ID in [url], or '' when there is none. Never a
  /// substitute video.
  String _extractVideoId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';

    // 1. Raw 11-char video ID (e.g. 8Y1RaecJ-mo or M7lc1UVf-VE)
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }

    // 2. youtube.com/live/VIDEO_ID format (e.g. https://youtube.com/live/8Y1RaecJ-mo?feature=share)
    final liveMatch =
        RegExp(r'youtube\.com\/live\/([a-zA-Z0-9_-]{11})', caseSensitive: false)
            .firstMatch(trimmed);
    if (liveMatch != null && liveMatch.groupCount >= 1) {
      return liveMatch.group(1)!;
    }

    // 3. youtu.be/VIDEO_ID format (e.g. https://youtu.be/8Y1RaecJ-mo)
    final youtuBeMatch =
        RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})', caseSensitive: false)
            .firstMatch(trimmed);
    if (youtuBeMatch != null && youtuBeMatch.groupCount >= 1) {
      return youtuBeMatch.group(1)!;
    }

    // 4. Standard youtube.com/watch?v=VIDEO_ID format
    final vMatch = RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})', caseSensitive: false)
        .firstMatch(trimmed);
    if (vMatch != null && vMatch.groupCount >= 1) {
      return vMatch.group(1)!;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        color: AppTheme.media,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_hasError) WebViewWidget(controller: _webViewController),

            // Task 4a: loading and error no longer get bespoke views here --
            // both route through the one placeholder surface every adapter
            // and the broadcast screen share.
            if (_isLoading || _hasError)
              StreamStatePlaceholderOverlay(
                streamState: _hasError
                    ? StreamState.fallbackError
                    : StreamState.initializing,
                errorDetail: _hasError
                    ? (_errorMessage.isNotEmpty
                        ? _errorMessage
                        : 'Video ID: $_currentVideoId')
                    : null,
                onRetry: _hasError && _currentVideoId.isNotEmpty
                    ? _retryPlayback
                    : null,
                onOpenInYouTube: _hasError && _currentVideoId.isNotEmpty
                    ? _openInYouTubeApp
                    : null,
              ),

            // Engine badge overlay
            PositionedDirectional(
              top: AppTheme.spaceSm,
              start: AppTheme.spaceSm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.media.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Canopy.liveCrimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'design_ui.youtube_player'.tr(),
                      style: const TextStyle(
                        color: AppTheme.onMedia,
                        fontSize: AppTheme.captionFont,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _retryPlayback() {
    if (_currentVideoId.isEmpty) return;
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _loadVideoEmbed(_currentVideoId);
  }

  /// Task 5 -- the escape hatch for an embed YouTube refuses to serve in a
  /// WebView at all (age-gated, embedding-disabled, or a device whose
  /// WebView is too old). The native YouTube app has none of those
  /// restrictions, so hand the video off rather than leaving the viewer
  /// staring at a retry button that will keep failing.
  Future<void> _openInYouTubeApp() async {
    final videoId = _currentVideoId.trim();
    if (videoId.isEmpty) return;

    // 1. Try launching native YouTube app via custom scheme
    final appUri = Uri.parse('vnd.youtube:$videoId');
    try {
      final launched =
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 2. Fallback: Launch standard web URL in external browser/app
    final webUri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    try {
      final launched =
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (launched) return;
    } catch (_) {}

    // 3. Last-resort fallback: platformDefault
    try {
      await launchUrl(webUri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('[YouTubePlayerAdapter] openInYouTube failed: $e');
    }
  }
}

/// The page the Android and iOS web views load: the youtube-nocookie embed
/// (ADR-006 origin and referrer policy), the supported IFrame API, and the
/// bridge that forwards player events to the app.
@visibleForTesting
String buildYouTubeEmbedHtml({
  required String videoId,
  required bool autoPlay,
  required bool muted,
}) =>
    '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport"content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer"content="strict-origin-when-cross-origin">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; background-color: #000; }
    html, body { width: 100%; height: 100%; overflow: hidden; background-color: #000; }
    .video-container { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
    iframe { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <div class="video-container">
    <iframe id="youtube-player"
      src="https://www.youtube-nocookie.com/embed/$videoId?autoplay=${autoPlay ? 1 : 0}&playsinline=1&controls=1&rel=0&modestbranding=1&enablejsapi=1&mute=${muted ? 1 : 0}&origin=$_embedBaseUrl"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen>
    </iframe>
  </div>
  <script>
    // Use the supported IFrame API. No application message listener accepts
    // cross-window events, and commands remain disabled until onReady.
    var player = null;
    var playerReady = false;
    var lastMuted;
    function bridge(message) {
      if (window.FlutterYouTubeBridge) {
        FlutterYouTubeBridge.postMessage(JSON.stringify(message));
      }
    }
    function reportMute() {
      if (!playerReady) return;
      var value = player.isMuted();
      if (typeof value === 'boolean' && value !== lastMuted) {
        lastMuted = value;
        bridge({type: 'muted', value: value});
      }
    }
    function playerCommand(command) {
      if (!playerReady || !['playVideo','pauseVideo','mute','unMute'].includes(command)) return 'none';
      player[command]();
      reportMute();
      return 'ok';
    }
    function onYouTubeIframeAPIReady() {
      player = new YT.Player('youtube-player', {
        events: {
          onReady: function(event) {
            if (event.target !== player) return;
            playerReady = true;
            if ($muted) player.mute();
            bridge({type: 'ready'});
            bridge({type: 'state', value: player.getPlayerState()});
            reportMute();
            if ($autoPlay) player.playVideo();
          },
          onStateChange: function(event) {
            if (event.target === player) bridge({type: 'state', value: event.data});
          },
          onError: function(event) {
            if (event.target === player) bridge({type: 'error', code: event.data});
          },
          onAutoplayBlocked: function(event) {
            if (event.target === player) bridge({type: 'state', value: player.getPlayerState()});
          }
        }
      });
    }
    setInterval(reportMute, 500);
  </script>
  <script src="https://www.youtube.com/iframe_api" async></script>
</body>
</html>
''';
