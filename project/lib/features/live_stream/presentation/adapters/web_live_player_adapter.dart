import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../abstract_video_player.dart';
import '../widgets/stream_state_placeholder_overlay.dart';

/// Concrete player adapter using an embedded WebViewController to render
/// MediaMTX's working HLS live stream player (http://IP:8888/live/demo/).
class WebLivePlayerAdapter extends AbstractVideoPlayer {
  const WebLivePlayerAdapter({
    super.key,
    required super.streamUrl,
    super.autoPlay = true,
    super.onPlayerReady,
    super.onStateChanged,
    super.onError,
    super.aspectRatio = 16 / 9,
    super.preferredQuality = 'auto',
  });

  @override
  State<WebLivePlayerAdapter> createState() => _WebLivePlayerAdapterState();
}

class _WebLivePlayerAdapterState extends State<WebLivePlayerAdapter> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeWebPlayer();
  }

  void _initializeWebPlayer() {
    final controller = WebViewController();
    try {
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    } catch (_) {}

    try {
      controller.setBackgroundColor(AppTheme.media);
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
          ),
        );
      } catch (_) {}
    } else {
      _isLoading = false;
      widget.onPlayerReady?.call();
      widget.onStateChanged?.call(StreamState.live);
    }

    try {
      controller.loadRequest(Uri.parse(widget.streamUrl));
    } catch (e) {
      debugPrint('[WebLivePlayerAdapter] loadRequest error: $e');
    }
    _webViewController = controller;
  }

  @override
  void didUpdateWidget(covariant WebLivePlayerAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streamUrl != oldWidget.streamUrl) {
      _webViewController.loadRequest(Uri.parse(widget.streamUrl));
    }
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
            if (!_hasError)
              WebViewWidget(controller: _webViewController),

            // Cluster 1 Task 4a -- loading and error share the one
            // placeholder surface every adapter now uses, instead of this
            // adapter's own hardcoded-English spinner and error card.
            if (_isLoading || _hasError)
              StreamStatePlaceholderOverlay(
                streamState: _hasError
                    ? StreamState.fallbackError
                    : StreamState.initializing,
                errorDetail: _hasError
                    ? (_errorMessage.isNotEmpty
                        ? _errorMessage
                        : widget.streamUrl)
                    : null,
                onRetry: _hasError ? _reloadStream : null,
              ),
          ],
        ),
      ),
    );
  }

  void _reloadStream() {
    setState(() {
      _hasError = false;
      _isLoading = true;
    });
    _webViewController.loadRequest(Uri.parse(widget.streamUrl));
  }
}
