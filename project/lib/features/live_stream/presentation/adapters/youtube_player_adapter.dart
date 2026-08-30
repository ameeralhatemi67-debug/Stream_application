import 'dart:convert';
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
  });

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

class _YouTubePlayerAdapterState extends State<YouTubePlayerAdapter> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late String _currentVideoId;
  int _currentFallbackIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentVideoId = _extractVideoId(widget.streamUrl);
    _initializeWebPlayer();
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
      controller.setBackgroundColor(Colors.black);
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
                // The iframe only exists once the document is parsed, so a
                // quality chosen before this point is applied here.
                _applyPreferredQuality();
                if (widget.autoPlay) {
                  unMuteAndPlay();
                }
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                _handleStreamFailure(error.description);
              }
            },
            onNavigationRequest: (NavigationRequest request) {
              return NavigationDecision.navigate;
            },
          ),
        );
      } catch (_) {}

      if (controller.platform is AndroidWebViewController) {
        final androidController =
            controller.platform as AndroidWebViewController;
        androidController.setMediaPlaybackRequiresUserGesture(false);
      }
    } else {
      // On Web: navigation callbacks are handled by browser iframe, mark loaded
      _isLoading = false;
      widget.onPlayerReady?.call();
      widget.onStateChanged?.call(StreamState.live);
    }

    _webViewController = controller;
    _loadVideoEmbed(_currentVideoId);
  }

  void _handleBridgeMessage(String jsonStr) {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final type = data['type'] as String?;
      if (type == 'state') {
        final stateVal = data['value'] as int?;
        if (stateVal == 1) {
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
      debugPrint('[YouTubePlayerAdapter] Failover to fallback stream ($nextId): $reason');
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

  void unMuteAndPlay() {
    try {
      _webViewController.runJavaScript('forceUnmuteAndPlay();');
    } catch (e) {
      debugPrint('[YouTubePlayerAdapter] unMuteAndPlay failed: $e');
    }
  }

  void _loadVideoEmbed(String videoId) {
    if (kIsWeb) {
      // No `origin` on web: the real origin there is the host page, which
      // this adapter cannot know, and a mismatched origin is exactly what
      // ADR-006's Error 150/153 work was about.
      final embedUrl =
          'https://www.youtube-nocookie.com/embed/$videoId?autoplay=${widget.autoPlay ? 1 : 0}&playsinline=1&controls=1&rel=0&modestbranding=1&enablejsapi=1';
      try {
        _webViewController.loadRequest(Uri.parse(embedUrl));
      } catch (e) {
        debugPrint('[YouTubePlayerAdapter] Web loadRequest error: $e');
      }
    } else {
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <meta name="referrer" content="strict-origin-when-cross-origin">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; background-color: #000; }
    html, body { width: 100%; height: 100%; overflow: hidden; background-color: #000; }
    .video-container { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
    iframe { width: 100%; height: 100%; border: 0; }
  </style>
</head>
<body>
  <div class="video-container">
    <iframe
      src="https://www.youtube-nocookie.com/embed/$videoId?autoplay=${widget.autoPlay ? 1 : 0}&playsinline=1&controls=1&rel=0&modestbranding=1&enablejsapi=1&origin=$_embedBaseUrl"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen>
    </iframe>
  </div>
  <script>
    window.addEventListener('message', function(event) {
      try {
        var data = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
        if (data && data.event === 'onStateChange') {
          // -1: unstarted, 0: ended, 1: playing, 2: paused, 3: buffering, 5: cued
          if (window.FlutterYouTubeBridge) {
            FlutterYouTubeBridge.postMessage(JSON.stringify({ type: 'state', value: data.info }));
          }
        }
        if (data && data.event === 'onError') {
          // 2: invalid param, 5: HTML5 error, 100: not found, 101/150: embed blocked
          if (window.FlutterYouTubeBridge) {
            FlutterYouTubeBridge.postMessage(JSON.stringify({ type: 'error', code: data.info }));
          }
        }
      } catch(e) {}
    });

    function forceUnmuteAndPlay() {
      try {
        var frame = document.querySelector('iframe');
        if (frame && frame.contentWindow) {
          frame.contentWindow.postMessage(JSON.stringify({ event: 'command', func: 'unMute', args: [] }), '*');
          frame.contentWindow.postMessage(JSON.stringify({ event: 'command', func: 'playVideo', args: [] }), '*');
        }
      } catch(e) {}
    }
  </script>
</body>
</html>
''';

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
        _loadVideoEmbed(_currentVideoId);
      }
    }
    if (widget.preferredQuality != oldWidget.preferredQuality) {
      _applyPreferredQuality();
    }
  }

  /// YouTube's rendition names for the resolutions the overlay selector
  /// offers. `auto` maps to `default`, which hands control back to
  /// YouTube's own adaptive logic.
  static const Map<String, String> _youtubeQualityNames = {
    'auto': 'default',
    '1080': 'hd1080',
    '720': 'hd720',
    '480': 'large',
    '360': 'medium',
  };

  /// Pushes the viewer's chosen rendition to the embedded player over the
  /// `enablejsapi=1` postMessage channel -- the same protocol the IFrame
  /// Player API itself uses, so it needs no extra script in the page and,
  /// crucially, does not reload the embed (which would interrupt a live
  /// broadcast every time someone touched the selector).
  ///
  /// YouTube treats `setPlaybackQuality` as a *request*: it will refuse a
  /// rendition the current stream does not publish, or override it when
  /// bandwidth drops. That is the documented behaviour of the platform, not
  /// a gap here -- the selector expresses a preference, it does not promise
  /// a bitrate.
  void _applyPreferredQuality() {
    final quality = _youtubeQualityNames[widget.preferredQuality];
    if (quality == null) return;
    final js = '''
(function() {
  var frame = document.querySelector('iframe');
  if (!frame || !frame.contentWindow) return;
  frame.contentWindow.postMessage(JSON.stringify({
    event: 'command',
    func: 'setPlaybackQuality',
    args: ['$quality']
  }), '*');
})();
''';
    try {
      _webViewController.runJavaScript(js);
    } catch (e) {
      debugPrint('[YouTubePlayerAdapter] setPlaybackQuality failed: $e');
    }
  }

  String _extractVideoId(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return 'M7lc1UVf-VE';

    // 1. Raw 11-char video ID (e.g. 8Y1RaecJ-mo or M7lc1UVf-VE)
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }

    // 2. youtube.com/live/VIDEO_ID format (e.g. https://youtube.com/live/8Y1RaecJ-mo?feature=share)
    final liveMatch = RegExp(r'youtube\.com\/live\/([a-zA-Z0-9_-]{11})',
            caseSensitive: false)
        .firstMatch(trimmed);
    if (liveMatch != null && liveMatch.groupCount >= 1) {
      return liveMatch.group(1)!;
    }

    // 3. youtu.be/VIDEO_ID format (e.g. https://youtu.be/8Y1RaecJ-mo)
    final youtuBeMatch = RegExp(r'youtu\.be\/([a-zA-Z0-9_-]{11})',
            caseSensitive: false)
        .firstMatch(trimmed);
    if (youtuBeMatch != null && youtuBeMatch.groupCount >= 1) {
      return youtuBeMatch.group(1)!;
    }

    // 4. Standard youtube.com/watch?v=VIDEO_ID format
    final vMatch =
        RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})', caseSensitive: false)
            .firstMatch(trimmed);
    if (vMatch != null && vMatch.groupCount >= 1) {
      return vMatch.group(1)!;
    }

    return trimmed.length == 11 ? trimmed : 'M7lc1UVf-VE';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!_hasError)
              WebViewWidget(controller: _webViewController),

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
                onRetry: _hasError ? _retryPlayback : null,
                onOpenInYouTube: _hasError ? _openInYouTubeApp : null,
              ),

            // Engine badge overlay
            Positioned(
              top: AppTheme.spaceSm,
              left: AppTheme.spaceSm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'YouTube Player',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
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
