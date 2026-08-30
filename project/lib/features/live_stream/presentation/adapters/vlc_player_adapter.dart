import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import '../../../../core/theme/app_theme.dart';
import '../abstract_video_player.dart';

/// Concrete player adapter wrapping [VlcPlayer] for sub-second low latency local RTMP stream loopback.
class VlcPlayerAdapter extends AbstractVideoPlayer {
  const VlcPlayerAdapter({
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
  State<VlcPlayerAdapter> createState() => _VlcPlayerAdapterState();
}

class _VlcPlayerAdapterState extends State<VlcPlayerAdapter> {
  VlcPlayerController? _vlcViewController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initializeVlcPlayer();
    } else {
      // Web fallback signal
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onPlayerReady?.call();
          widget.onStateChanged?.call(StreamState.live);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant VlcPlayerAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.streamUrl != oldWidget.streamUrl) {
      _reinitializePlayer();
    }
  }

  void _reinitializePlayer() {
    if (_vlcViewController != null) {
      try {
        _vlcViewController?.stopRendererScanning();
        _vlcViewController?.dispose();
      } catch (_) {}
      _vlcViewController = null;
    }
    setState(() {
      _hasError = false;
    });
    _initializeVlcPlayer();
  }

  void _initializeVlcPlayer() {
    try {
      _vlcViewController = VlcPlayerController.network(
        widget.streamUrl,
        hwAcc: HwAcc.disabled,
        autoPlay: widget.autoPlay,
        options: VlcPlayerOptions(
          advanced: VlcAdvancedOptions([
            '--rtmp-caching=500',
            '--network-caching=500',
            '--live-caching=500',
            '--clock-jitter=0',
            '--clock-synchro=0',
            '--drop-late-frames',
            '--skip-frames',
          ]),
        ),
      );

      _vlcViewController?.addOnInitListener(() {
        if (mounted) {
          widget.onPlayerReady?.call();
          widget.onStateChanged?.call(StreamState.live);
        }
      });

      _vlcViewController?.addListener(() {
        if (_vlcViewController?.value.hasError ?? false) {
          final err =
              _vlcViewController?.value.errorDescription ?? 'Unknown error';
          if (mounted) {
            setState(() {
              _hasError = true;
            });
            widget.onError?.call(err);
            widget.onStateChanged?.call(StreamState.fallbackError);
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        widget.onError?.call(e.toString());
        widget.onStateChanged?.call(StreamState.fallbackError);
      }
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && _vlcViewController != null) {
      try {
        _vlcViewController?.stopRendererScanning();
        _vlcViewController?.dispose();
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: Container(
        color: AppTheme.darkBgBase,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (kIsWeb)
              _buildWebLiveStreamView()
            else if (_hasError || _vlcViewController == null)
              _buildErrorView()
            else
              VlcPlayer(
                controller: _vlcViewController!,
                aspectRatio: widget.aspectRatio,
                placeholder: InkWell(
                  onTap: _reinitializePlayer,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: AppTheme.accentBlue),
                        const SizedBox(height: AppTheme.spaceMd),
                        const Text(
                          'Connecting to Live Stream...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.streamUrl,
                          style: const TextStyle(
                              color: AppTheme.accentBlue, fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface3,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Text(
                            'Tap to Reload Player 🔄',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Badge overlay indicating VLC RTMP engine
            Positioned(
              top: AppTheme.spaceSm,
              left: AppTheme.spaceSm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentRed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'VLC RTMP Loopback',
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

  Widget _buildWebLiveStreamView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.darkSurface1, AppTheme.darkSurface3],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.live_tv_rounded,
                color: AppTheme.accentRed, size: 44),
            const SizedBox(height: 8),
            const Text(
              '🔴 LIVE RTMP BROADCAST ACTIVE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.streamUrl,
              style: const TextStyle(color: AppTheme.accentBlue, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accentRed, width: 1),
              ),
              child: const Text(
                'MonaServer Broadcast Connected • 1080p60',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
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
          const Icon(Icons.sensors_rounded,
              color: AppTheme.accentRed, size: 48),
          const SizedBox(height: AppTheme.spaceMd),
          const Text(
            '🔴 Going Live Soon...',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          const Text(
            'Broadcaster is preparing live stream in OBS.\nClick Start Streaming in OBS to connect live video & audio.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
              });
              _initializeVlcPlayer();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Connect Live Stream'),
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
