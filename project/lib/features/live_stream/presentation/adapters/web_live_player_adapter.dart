import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';

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
                    CircularProgressIndicator(color: AppTheme.accentBlue),
                    SizedBox(height: AppTheme.spaceMd),
                    Text(
                      'Loading Live Stream Viewport...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

            if (_hasError)
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wifi_off_rounded,
                        color: AppTheme.accentRed, size: 44),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to Connect to Web Stream',
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
                          : widget.streamUrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppTheme.accentBlue, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isLoading = true;
                        });
                        _webViewController
                            .loadRequest(Uri.parse(widget.streamUrl));
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reload Live Player'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentRed,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
