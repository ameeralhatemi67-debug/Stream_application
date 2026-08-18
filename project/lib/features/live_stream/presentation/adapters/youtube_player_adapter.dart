import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';

/// Concrete player adapter using an optimized [WebViewController] with
/// Strategy 1 (strict-origin-when-cross-origin + youtube-nocookie.com)
/// to eliminate Error 150/152/153 across both Live Streams and Archived VODs.
class YouTubePlayerAdapter extends AbstractVideoPlayer {
  const YouTubePlayerAdapter({
    super.key,
    required super.streamUrl,
    super.autoPlay = true,
    super.onPlayerReady,
    super.onStateChanged,
    super.onError,
    super.aspectRatio = 16 / 9,
  });

  @override
  State<YouTubePlayerAdapter> createState() => _YouTubePlayerAdapterState();
}

class _YouTubePlayerAdapterState extends State<YouTubePlayerAdapter> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late String _currentVideoId;

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
                widget.onStateChanged?.call(StreamState.live);
              }
            },
            onWebResourceError: (WebResourceError error) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error.description;
                  _isLoading = false;
                });
                widget.onError?.call(error.description);
                widget.onStateChanged?.call(StreamState.fallbackError);
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

  void _loadVideoEmbed(String videoId) {
    if (kIsWeb) {
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
      src="https://www.youtube-nocookie.com/embed/$videoId?autoplay=${widget.autoPlay ? 1 : 0}&playsinline=1&controls=1&rel=0&modestbranding=1&enablejsapi=1"
      referrerpolicy="strict-origin-when-cross-origin"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
      allowfullscreen>
    </iframe>
  </div>
</body>
</html>
''';

      _webViewController.loadHtmlString(
        html,
        baseUrl: 'https://www.youtube-nocookie.com',
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

            if (_isLoading)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppTheme.accentRed),
                    SizedBox(height: AppTheme.spaceMd),
                    Text(
                      'Connecting to YouTube Feed...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

            if (_hasError)
              _buildErrorView(),

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

  Widget _buildErrorView() {
    return Container(
      color: Colors.black87,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.live_tv_rounded,
              color: AppTheme.accentRed, size: 44),
          const SizedBox(height: 12),
          const Text(
            'Live Stream Offline or Connecting',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage.isNotEmpty
                ? _errorMessage
                : 'Video ID: $_currentVideoId',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _isLoading = true;
              });
              _loadVideoEmbed(_currentVideoId);
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry Playback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
