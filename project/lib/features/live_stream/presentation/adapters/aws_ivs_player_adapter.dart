import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';
import '../widgets/stream_state_placeholder_overlay.dart';

/// Concrete player adapter stub for AWS IVS (Interactive Video Service) HLS Low-Latency streams.
class AwsIvsPlayerAdapter extends AbstractVideoPlayer {
  const AwsIvsPlayerAdapter({
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
  State<AwsIvsPlayerAdapter> createState() => _AwsIvsPlayerAdapterState();
}

class _AwsIvsPlayerAdapterState extends State<AwsIvsPlayerAdapter> {
  bool _isPlaying = true;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _connectIvsStream();
  }

  Future<void> _connectIvsStream() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Simulate AWS IVS Low-Latency player connection setup
    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _isPlaying = widget.autoPlay;
      });
      widget.onPlayerReady?.call();
      widget.onStateChanged?.call(StreamState.live);
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
            // Video Surface simulation
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_sync_rounded,
                        color: AppTheme.accentBlue, size: 56),
                    const SizedBox(height: AppTheme.spaceSm),
                    Text(
                      'AWS IVS HLS Low-Latency Stream',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.streamUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // Cluster 1 Task 4a -- one placeholder surface for every
            // adapter, replacing this one's bare spinner and its own
            // hardcoded-English error card.
            if (_isLoading || _hasError)
              StreamStatePlaceholderOverlay(
                streamState: _hasError
                    ? StreamState.fallbackError
                    : StreamState.initializing,
                errorDetail: _hasError ? widget.streamUrl : null,
                onRetry: _hasError ? _connectIvsStream : null,
              ),

            // Controls & Engine badge overlay
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
                        color: AppTheme.accentBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'AWS IVS HLS (<1.5s latency)',
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

            // Play/Pause Overlay Toggle
            if (!_isLoading && !_hasError)
              Positioned(
                bottom: AppTheme.spaceSm,
                right: AppTheme.spaceSm,
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                    });
                    widget.onStateChanged?.call(
                      _isPlaying ? StreamState.live : StreamState.paused,
                    );
                  },
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
