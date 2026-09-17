import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../discovery/models/academic_category_model.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../map/models/map_models.dart';
import '../../models/chat_message_model.dart';
import '../../models/stream_privacy_models.dart';
import '../../services/ghost_chat_fallback_controller.dart';
import '../../services/live_chat_controller.dart';
import '../../services/rtmp_publish_engine.dart';
import '../widgets/chat_message_actions_sheet.dart';
import '../widgets/floating_reactions_overlay.dart';
import '../widgets/live_chat_widget.dart';
import '../widgets/permission_rationale_dialog.dart';
import '../widgets/phone_camera_preview.dart';
import '../widgets/rtmp_ip_dialog.dart';

/// Full-featured Stream Page for Phone Broadcasters:
/// Unifies the broadcaster's phone camera stream with the exact same
/// rich stream page interface (16:9 player viewport, live chat, lecture slides,
/// venue info, viewer reactions, and integrated broadcaster studio controls).
class PhoneBroadcastScreen extends StatefulWidget {
  final BroadcastQualityPreset? quickLaunchPreset;

  const PhoneBroadcastScreen({super.key, this.quickLaunchPreset});

  @override
  State<PhoneBroadcastScreen> createState() => _PhoneBroadcastScreenState();
}

class _PhoneBroadcastScreenState extends State<PhoneBroadcastScreen>
    with SingleTickerProviderStateMixin {
  final RtmpPublishEngine _engine = RtmpPublishEngine();
  final FloatingReactionsOverlayController _reactionsController =
      FloatingReactionsOverlayController();
  final TextEditingController _chatTextController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  late final LiveChatController _chatController;
  late final GhostChatFallbackController _ghostChatController;
  late TabController _tabController;

  String? _setupError;
  late BroadcastQualityPreset _preset;
  late bool _presetConfirmed;
  bool _isFullscreen = false;
  bool _isSideChatOpen = false;
  bool _controlsVisible = true;
  bool _isDescriptionExpanded = false;

  late AppProvider _appProvider;
  bool _appProviderCaptured = false;
  bool _weStartedBroadcast = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_appProviderCaptured) {
      _appProvider = Provider.of<AppProvider>(context, listen: false);
      _appProviderCaptured = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngineChanged);
    _engine.isMicSilent.addListener(_onMicSilenceChanged);
    _preset = widget.quickLaunchPreset ?? BroadcastQualityPreset.medium;
    _presetConfirmed = widget.quickLaunchPreset != null;

    _tabController = TabController(length: 3, vsync: this);
    _chatController = LiveChatController(
      streamId: 'phone_broadcast_${DateTime.now().millisecondsSinceEpoch}',
      onReaction: (type) => _reactionsController.spawnReaction(type),
    )..start();
    _ghostChatController = GhostChatFallbackController(
        streamId: 'phone_broadcast_stream');
    _chatController.addListener(_handleChatConnectionChange);

    _setWakelock(true);

    if (widget.quickLaunchPreset != null) {
      _weStartedBroadcast = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirmPresetAndSetup();
      });
    }
  }

  void _setWakelock(bool enable) {
    try {
      final future =
          enable ? WakelockPlus.enable() : WakelockPlus.disable();
      future.catchError((Object e) {
        debugPrint('[PhoneBroadcastScreen] wakelock unavailable: $e');
      });
    } catch (e) {
      debugPrint('[PhoneBroadcastScreen] wakelock unavailable: $e');
    }
  }

  void _handleChatConnectionChange() {
    final disconnected =
        _chatController.connectionState == ChatConnectionState.reconnecting;
    if (disconnected && !_ghostChatController.isActive) {
      _ghostChatController.start();
    } else if (!disconnected && _ghostChatController.isActive) {
      _ghostChatController.stop();
    }
  }

  Future<void> _confirmPresetAndSetup() async {
    setState(() => _presetConfirmed = true);

    final cameraGranted = await _ensurePermission(
      Permission.camera,
      BroadcastPermissionKind.camera,
    );
    if (!cameraGranted) return;

    final micGranted = await _ensurePermission(
      Permission.microphone,
      BroadcastPermissionKind.microphone,
    );
    if (!micGranted) return;

    await Permission.notification.request();

    try {
      await _engine.initializeCamera(preset: _preset);
      if (_appProvider.customBroadcastType == BroadcastType.liveAudio) {
        await _engine.setAudioOnly(true);
      }
      if (widget.quickLaunchPreset != null && mounted) {
        await _startBroadcast();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _setupError = 'Could not start the camera: $e');
    }
  }

  Future<bool> _ensurePermission(
    Permission permission,
    BroadcastPermissionKind kind,
  ) async {
    var status = await permission.status;
    if (status.isGranted) return true;

    if (!mounted) return false;
    final rationaleGranted = await PermissionRationaleDialog.show(
      context,
      kind,
    );
    if (!rationaleGranted) return false;

    status = await permission.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied && mounted) {
      final openSettings = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: AppTheme.darkSurface1,
              title: const Text(
                'Permission required',
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                'The app needs ${kind == BroadcastPermissionKind.camera ? 'camera' : 'microphone'} access to broadcast. Please enable it in Settings.',
                style: const TextStyle(color: AppTheme.textSecondaryDark),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                  ),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ) ??
          false;
      if (openSettings) {
        await openAppSettings();
      }
    }
    return false;
  }

  Future<void> _startBroadcast() async {
    try {
      await _engine.startPublishing(_appProvider.phoneBroadcastFullUrl);
      if (!mounted) return;
      if (!_appProvider.isBroadcastingLive) {
        await _appProvider.toggleBroadcasterGoLive(context);
        _weStartedBroadcast = true;
      }
    } on Exception {
      // The engine's error state drives the UI.
    }
  }

  Future<void> _stopBroadcast() async {
    await _engine.stopPublishing();
    if (_weStartedBroadcast && _appProvider.isBroadcastingLive) {
      await _appProvider.toggleBroadcasterGoLive(mounted ? context : null);
    }
    _weStartedBroadcast = false;
  }

  void _onEngineChanged() => setState(() {});

  void _onMicSilenceChanged() {
    if (!_appProviderCaptured) return;
    _appProvider.setStreamerMicMuted(_engine.isMicSilent.value);
  }

  void _handleToggleFullscreen() {
    final entering = !_isFullscreen;
    setState(() => _isFullscreen = entering);

    if (entering) {
      _engine.setOrientation(90);
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _engine.setOrientation(0);
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _restorePortraitChrome() {
    _engine.setOrientation(0);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _setWakelock(false);
    _restorePortraitChrome();
    if (_weStartedBroadcast) {
      _stopBroadcast();
    }
    _tabController.dispose();
    _chatTextController.dispose();
    _chatScrollController.dispose();
    _chatController.removeListener(_handleChatConnectionChange);
    _chatController.dispose();
    _ghostChatController.dispose();
    _engine.removeListener(_onEngineChanged);
    _engine.isMicSilent.removeListener(_onMicSilenceChanged);
    if (_appProviderCaptured) _appProvider.setStreamerMicMuted(false);
    if (_weStartedBroadcast && _appProvider.isBroadcastingLive) {
      final provider = _appProvider;
      Future.microtask(() => provider.toggleBroadcasterGoLive());
    }
    _engine.dispose();
    super.dispose();
  }

  void _handleSendChatMessage(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _chatController.sendMessage(trimmed).then((_) {
      if (!mounted || !_chatScrollController.hasClients) return;
      _chatScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }).catchError((Object e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.accentRed),
      );
    });
  }

  ImageProvider _getAvatarProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final title = _appProvider.customLiveTitle.isEmpty
        ? 'live.phone_broadcast_default_title'.tr()
        : _appProvider.customLiveTitle;
    final description = _appProvider.customLiveDescription;
    final langCode = context.locale.languageCode;
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 900;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSideBySide = isDesktop || (isLandscape && !_isFullscreen);
    final streamer = _appProvider.currentBroadcasterStreamer;

    if (!_presetConfirmed) {
      return Scaffold(
        backgroundColor: AppTheme.darkBgBase,
        appBar: AppBar(
          backgroundColor: AppTheme.darkSurface1,
          title: Text('live.broadcast_from_phone'.tr()),
        ),
        body: _buildPresetPicker(),
      );
    }

    if (_isFullscreen || isLandscape) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: _buildFullscreenLandscapeLayout(title, streamer, langCode),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface1,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.darkSurface3,
              backgroundImage: _getAvatarProvider(streamer.avatarUrl),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          streamer.getLocalizedName(langCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (streamer.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppTheme.accentBlue),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.accentRed.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppTheme.accentRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: AppTheme.accentRed,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          streamer.getLocalizedOrganization(langCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textSecondaryDark,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.accentRed.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.cell_tower_rounded,
                  color: AppTheme.accentRed, size: 20),
              tooltip: 'Broadcaster Studio & End Stream',
              onPressed: () => LiveBroadcasterStudioSheet.show(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: isSideBySide
            ? Row(
                children: [
                  Expanded(
                    flex: isDesktop ? 65 : 58,
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildVideoViewport(
                            isSideBySide: true,
                            streamer: streamer,
                          ),
                        ),
                        _buildTitleAndDescriptionStrip(
                            title, description, streamer, langCode),
                      ],
                    ),
                  ),
                  const VerticalDivider(
                      width: 1, color: AppTheme.darkBorderSubtle),
                  Expanded(
                    flex: isDesktop ? 35 : 42,
                    child: _buildCinemaTabPanel(langCode),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildVideoViewport(
                    isSideBySide: false,
                    streamer: streamer,
                  ),
                  _buildTitleAndDescriptionStrip(
                      title, description, streamer, langCode),
                  Expanded(child: _buildCinemaTabPanel(langCode)),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoViewport({
    required bool isSideBySide,
    required StreamerModel streamer,
  }) {
    if (_setupError != null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Text(
          _setupError!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      );
    }

    final loading = _engine.state == RtmpPublishState.idle ||
        _engine.state == RtmpPublishState.initializingCamera;

    final videoContent = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Camera Platform View (or Camera Off Audio Poster)
            if (_engine.isCameraOff)
              Container(
                color: AppTheme.darkBgBase,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: AppTheme.darkSurface3,
                      backgroundImage: _getAvatarProvider(streamer.avatarUrl),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(
                            color: AppTheme.accentAmber.withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off_rounded,
                              size: 14, color: AppTheme.accentAmber),
                          SizedBox(width: 6),
                          Text(
                            'Camera is Off • Audio Only',
                            style: TextStyle(
                              color: AppTheme.accentAmber,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _engine.toggleCamera(false),
                      icon: const Icon(Icons.videocam_rounded, size: 16),
                      label: const Text('Turn On Camera',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppTheme.darkSurface2,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
              )
            else
              const ClipRect(
                child: SizedBox.expand(
                  child: PhoneCameraPreview(),
                ),
              ),

            // 2. Loading indicator
            if (loading && !_engine.isCameraOff)
              const ColoredBox(
                color: Colors.black,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentRed),
                ),
              ),

            // 3. Overlay Controls (Tap to hide for clean video)
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 240),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
                    // Top Left: Live Bitrate Badge
                    if (_engine.state == RtmpPublishState.live)
                      Positioned(
                        top: AppTheme.spaceSm,
                        left: AppTheme.spaceSm,
                        child: _LiveBadge(bitrateBps: _engine.lastBitrateBps),
                      ),

                    if (_engine.state == RtmpPublishState.connecting)
                      const Positioned(
                        top: AppTheme.spaceSm,
                        left: AppTheme.spaceSm,
                        child: _StatusPill(
                            label: 'Connecting...', color: Colors.amber),
                      ),

                    // Top Right: 3-Dots Streamer Controls Menu
                    Positioned(
                      top: AppTheme.spaceSm,
                      right: AppTheme.spaceSm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: Colors.white, size: 20),
                          tooltip: 'Streamer Controls',
                          onPressed: () =>
                              _showStreamerControlsSheet(streamer),
                        ),
                      ),
                    ),

                    // Bottom Right: Fullscreen Button
                    Positioned(
                      bottom: AppTheme.spaceSm,
                      right: AppTheme.spaceSm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen_rounded,
                              color: Colors.white, size: 20),
                          tooltip: 'Fullscreen',
                          onPressed: _handleToggleFullscreen,
                        ),
                      ),
                    ),

                    // Mic Muted Pill
                    if (_engine.isMuted)
                      const Positioned(
                        bottom: AppTheme.spaceSm,
                        left: AppTheme.spaceSm,
                        child: _StatusPill(
                          label: 'MIC MUTED',
                          color: AppTheme.accentRed,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 4. Reconnecting Banner
            if (_engine.state == RtmpPublishState.reconnecting)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _ReconnectingBanner(
                  attempt: _engine.reconnectAttempt,
                  maxAttempts: _engine.maxReconnectAttempts,
                ),
              ),

            // 5. Error Banner
            if (_engine.state == RtmpPublishState.error &&
                _engine.lastError != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _StreamErrorBanner(message: _engine.lastError!),
              ),

            // 6. Floating Reaction Hearts Overlay
            FloatingReactionsOverlay(controller: _reactionsController),

            // 7. Knocking Requests (Private Stream)
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                if (provider.pendingKnockRequests.isEmpty) {
                  return const SizedBox.shrink();
                }
                final request = provider.pendingKnockRequests.first;
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _KnockingBanner(
                    request: request,
                    queueLength: provider.pendingKnockRequests.length,
                    onAdmit: () => provider.admitKnockRequest(request.id),
                    onDeny: () => provider.denyKnockRequest(request.id),
                    onAdmitAll: provider.admitAllKnockRequests,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );

    if (isSideBySide) return videoContent;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: videoContent,
    );
  }

  void _showStreamerControlsSheet(StreamerModel streamer) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMuted = _engine.isMuted;
            final isCameraOff = _engine.isCameraOff;
            final isFrontCamera = _engine.isFrontCamera;

            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.darkSurface1,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusLg)),
                border: Border(
                  top:
                      BorderSide(color: AppTheme.darkBorderHighlight, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.darkBorderHighlight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            color: AppTheme.accentRed, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Streamer Quick Controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // 1. 🎤 Microphone Mute Toggle
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      tileColor: isMuted
                          ? AppTheme.accentRed.withValues(alpha: 0.15)
                          : AppTheme.darkSurface2,
                      leading: Icon(
                        isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        color: isMuted
                            ? AppTheme.accentRed
                            : AppTheme.accentGreen,
                      ),
                      title: Text(
                        isMuted ? 'Unmute Microphone' : 'Mute Microphone',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5),
                      ),
                      subtitle: Text(
                        isMuted
                            ? 'Your mic is currently silent'
                            : 'Live audio input active',
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 11),
                      ),
                      trailing: Switch(
                        value: !isMuted,
                        activeThumbColor: AppTheme.accentGreen,
                        onChanged: (val) async {
                          await _engine.setMuted(!val);
                          setModalState(() {});
                          setState(() {});
                        },
                      ),
                      onTap: () async {
                        await _engine.setMuted(!isMuted);
                        setModalState(() {});
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),

                    // 2. 🔄 Flip Camera Toggle
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      tileColor: AppTheme.darkSurface2,
                      leading: const Icon(Icons.flip_camera_ios_rounded,
                          color: AppTheme.accentBlue),
                      title: Text(
                        isFrontCamera
                            ? 'Switch to Back Camera'
                            : 'Switch to Front Camera',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5),
                      ),
                      subtitle: Text(
                        isFrontCamera
                            ? 'Front selfie camera active'
                            : 'Rear environment camera active',
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.sync_rounded,
                          color: AppTheme.textSecondaryDark, size: 18),
                      onTap: isCameraOff
                          ? null
                          : () async {
                              await _engine.switchCamera();
                              setModalState(() {});
                              setState(() {});
                            },
                    ),
                    const SizedBox(height: 8),

                    // 3. 📷 Close Camera (Video / Audio-Only Toggle)
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      tileColor: isCameraOff
                          ? AppTheme.accentAmber.withValues(alpha: 0.15)
                          : AppTheme.darkSurface2,
                      leading: Icon(
                        isCameraOff
                            ? Icons.videocam_off_rounded
                            : Icons.videocam_rounded,
                        color: isCameraOff
                            ? AppTheme.accentAmber
                            : AppTheme.accentBlue,
                      ),
                      title: Text(
                        isCameraOff
                            ? 'Turn On Camera'
                            : 'Close Camera (Audio-Only)',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5),
                      ),
                      subtitle: Text(
                        isCameraOff
                            ? 'Displaying profile poster to viewers'
                            : 'Live camera video stream active',
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 11),
                      ),
                      trailing: Switch(
                        value: !isCameraOff,
                        activeThumbColor: AppTheme.accentBlue,
                        onChanged: (val) async {
                          await _engine.toggleCamera(!val);
                          setModalState(() {});
                          setState(() {});
                        },
                      ),
                      onTap: () async {
                        await _engine.toggleCamera(!isCameraOff);
                        setModalState(() {});
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),

                    // 4. 🔒 Private Attendees Admission (if private)
                    if (_appProvider.isActiveStreamPrivate) ...[
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        tileColor: AppTheme.darkSurface2,
                        leading: const Icon(Icons.people_alt_rounded,
                            color: AppTheme.accentAmber),
                        title: Text(
                          'Manage Attendees (${_appProvider.admittedAttendees.length})',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5),
                        ),
                        subtitle: Text(
                          '${_appProvider.pendingKnockRequests.length} waiting in admission queue',
                          style: const TextStyle(
                              color: AppTheme.textSecondaryDark, fontSize: 11),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: AppTheme.textSecondaryDark),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          _showDirectorPanel(context, _appProvider);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // 5. 🗼 Studio & End Stream Shortcut
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      tileColor: AppTheme.accentRed.withValues(alpha: 0.1),
                      leading: const Icon(Icons.cell_tower_rounded,
                          color: AppTheme.accentRed),
                      title: const Text(
                        'Broadcaster Studio & End Stream',
                        style: TextStyle(
                            color: AppTheme.accentRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5),
                      ),
                      subtitle: const Text(
                        'Adjust stream settings or end broadcast session',
                        style: TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 11),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          color: AppTheme.accentRed, size: 14),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        LiveBroadcasterStudioSheet.show(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String get _presetCompactLabel {
    switch (_preset) {
      case BroadcastQualityPreset.low:
        return '480p SD';
      case BroadcastQualityPreset.medium:
        return '720p HD';
      case BroadcastQualityPreset.high:
        return '1080p FHD';
    }
  }

  Widget _buildTitleAndDescriptionStrip(String title, String description,
      StreamerModel streamer, String langCode) {
    final effectiveTitle =
        title.isNotEmpty ? title : streamer.getLocalizedTitle(langCode);
    final categoryModel = _appProvider.academicCategories.firstWhere(
      (c) => c.id == streamer.categoryId,
      orElse: () => _appProvider.academicCategories.isNotEmpty
          ? _appProvider.academicCategories.first
          : const AcademicCategoryModel(
              id: 'cat_cs',
              nameEn: 'Computer Science',
              nameAr: 'علوم الحاسب',
            ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: 10.0,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface1,
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Title + Chevron Expand Button
          InkWell(
            onTap: () => setState(
                () => _isDescriptionExpanded = !_isDescriptionExpanded),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    effectiveTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: _isDescriptionExpanded ? null : 1,
                    overflow:
                        _isDescriptionExpanded ? null : TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  _isDescriptionExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.textSecondaryDark,
                  size: 22,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Row 2: Metadata Badges (Category, Quality, Viewers)
          Row(
            children: [
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface2,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.darkBorderSubtle),
                  ),
                  child: Text(
                    categoryModel.getLocalizedName(langCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.accentBlue,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.darkBorderSubtle),
                ),
                child: Text(
                  _presetCompactLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.remove_red_eye_rounded,
                  size: 14, color: AppTheme.accentGreen),
              const SizedBox(width: 4),
              Text(
                '${streamer.activeViewerCount} viewers',
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Row 3: Expanded Description & Organization (when expanded)
          if (_isDescriptionExpanded) ...[
            const SizedBox(height: 10),
            const Divider(color: AppTheme.darkBorderSubtle, height: 1),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty
                  ? description
                  : 'No description provided.',
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    size: 13, color: AppTheme.textMutedDark),
                const SizedBox(width: 4),
                Text(
                  streamer.getLocalizedOrganization(langCode),
                  style: const TextStyle(
                    color: AppTheme.textSecondaryDark,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCinemaTabPanel(String langCode) {
    final streamer = _appProvider.currentBroadcasterStreamer;

    return Container(
      color: AppTheme.darkBgBase,
      child: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Live Chat
                _buildLiveChatTab(),
                // Tab 2: Slides
                _buildSlidesTab(streamer, langCode),
                // Tab 3: Venue Info
                _buildVenueTab(streamer, langCode),
              ],
            ),
          ),
          Container(
            height: 45,
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface1,
              border: Border(
                top: BorderSide(color: AppTheme.darkBorderSubtle, width: 0.8),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accentRed,
              labelColor: AppTheme.accentRed,
              unselectedLabelColor: AppTheme.textMutedDark,
              indicatorWeight: 2.0,
              tabs: [
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                      const SizedBox(width: 5),
                      Text('live.tab_chat'.tr(),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.picture_as_pdf_outlined, size: 14),
                      const SizedBox(width: 5),
                      Text('live.tab_sources'.tr(),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14),
                      const SizedBox(width: 5),
                      Text('live.tab_venue'.tr(),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveChatTab() {
    final langCode = context.locale.languageCode;
    return ListenableBuilder(
      listenable: _chatController,
      builder: (context, _) {
        final messages = _chatController.messages.isNotEmpty
            ? _chatController.messages
            : _ghostChatController.messages
                .map((m) => ChatMessageModel(
                      id: m.messageId,
                      streamId: m.streamId,
                      senderId: 'ghost_${m.messageId}',
                      senderName: m.getLocalizedSender(langCode),
                      senderAvatarUrl: m.senderAvatar,
                      body: m.getLocalizedMessage(langCode),
                      createdAt: DateTime.tryParse(m.timestamp) ??
                          DateTime.now(),
                      isCurrentUser: m.isCurrentUser,
                      badges: const {},
                      isPending: false,
                    ))
                .toList();

        return LiveChatWidget(
          messages: messages,
          connectionState: _chatController.connectionState,
          onSendTextMessage: _handleSendChatMessage,
          onMessageLongPress: (msg) {
            showChatMessageActionsSheet(
              context,
              message: msg,
              controller: _chatController,
            );
          },
        );
      },
    );
  }

  Widget _buildSlidesTab(StreamerModel streamer, String langCode) {
    return Container(
      color: AppTheme.darkBgBase,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'live.slides_attached_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'live.slides_attached_subtitle'.tr(),
            style: const TextStyle(
                color: AppTheme.textSecondaryDark, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.darkSurface1,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.darkBorderSubtle),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.slideshow_rounded,
                      size: 48, color: AppTheme.accentBlue),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    streamer.getLocalizedTitle(langCode),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Presentation Deck (PDF Attached)',
                    style: TextStyle(
                        color: AppTheme.textMutedDark, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVenueTab(StreamerModel streamer, String langCode) {
    final venueInfo = getAuditoriumInfoForStreamer(streamer);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_rounded,
                  color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'live.venue_details_title'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface1,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.darkBorderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueInfo.getLocalizedAddress(langCode),
                  style: const TextStyle(
                      color: AppTheme.textPrimaryDark, fontSize: 12.5),
                ),
                const Divider(color: AppTheme.darkBorderSubtle, height: 16),
                Text(
                  'Hall: ${venueInfo.getLocalizedAuditorium(langCode)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondaryDark, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gate: ${venueInfo.getLocalizedGate(langCode)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondaryDark, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capacity: ${venueInfo.seatingCapacity} Seats',
                  style: const TextStyle(
                      color: AppTheme.accentGreen, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenLandscapeLayout(
      String title, StreamerModel streamer, String langCode) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: Stack(
        children: [
          // 1. Fullscreen Camera Preview / Audio Poster
          if (_engine.isCameraOff)
            Container(
              color: AppTheme.darkBgBase,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.darkSurface3,
                    backgroundImage: _getAvatarProvider(streamer.avatarUrl),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                          color: AppTheme.accentAmber.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'Camera is Off • Audio Only',
                      style: TextStyle(
                        color: AppTheme.accentAmber,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox.expand(
              child: PhoneCameraPreview(),
            ),

          // 2. Reactions Overlay
          FloatingReactionsOverlay(controller: _reactionsController),

          // 3. Top Translucent Overlay Bar
          AnimatedOpacity(
            opacity: _controlsVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 240),
            child: IgnorePointer(
              ignoring: !_controlsVisible,
              child: Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceLg, vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit_rounded,
                            color: Colors.white, size: 24),
                        tooltip: 'Exit Fullscreen',
                        onPressed: _handleToggleFullscreen,
                      ),
                      const SizedBox(width: AppTheme.spaceSm),
                      if (_engine.state == RtmpPublishState.live)
                        _LiveBadge(bitrateBps: _engine.lastBitrateBps),
                      const SizedBox(width: AppTheme.spaceMd),
                      Expanded(
                        child: Text(
                          title.isNotEmpty
                              ? title
                              : streamer.getLocalizedTitle(langCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Colors.white, size: 22),
                        tooltip: 'Streamer Controls',
                        onPressed: () => _showStreamerControlsSheet(streamer),
                      ),
                      IconButton(
                        icon: Icon(
                          _isSideChatOpen
                              ? Icons.chat_bubble_rounded
                              : Icons.chat_bubble_outline_rounded,
                          color: _isSideChatOpen
                              ? AppTheme.accentRed
                              : Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Toggle Live Chat',
                        onPressed: () {
                          setState(() => _isSideChatOpen = !_isSideChatOpen);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Side Chat Drawer Overlay (when active in fullscreen)
          if (_isSideChatOpen)
            Positioned(
              top: 60,
              bottom: 80,
              right: 16,
              width: 320,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkBgBase.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.darkBorderSubtle),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  child: _buildLiveChatTab(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDirectorPanel(BuildContext context, AppProvider provider) {
    final handleController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Consumer<AppProvider>(
            builder: (context, provider, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔒 ${provider.admittedAttendees.length} Attendees',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: handleController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search or add @username',
                            hintStyle: const TextStyle(
                                color: AppTheme.textMutedDark, fontSize: 12),
                            filled: true,
                            fillColor: AppTheme.darkSurface2,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              borderSide: const BorderSide(
                                  color: AppTheme.darkBorderSubtle),
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isEmpty) return;
                            provider.admitAttendeeByHandle(value.trim());
                            handleController.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            color: AppTheme.accentGreen),
                        onPressed: () {
                          final value = handleController.text.trim();
                          if (value.isEmpty) return;
                          provider.admitAttendeeByHandle(value);
                          handleController.clear();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: provider.admittedAttendees.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: AppTheme.spaceMd),
                            child: Text(
                              'No attendees admitted yet.',
                              style: TextStyle(
                                  color: AppTheme.textMutedDark,
                                  fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.admittedAttendees.length,
                            itemBuilder: (context, index) {
                              final attendee =
                                  provider.admittedAttendees[index];
                              return ListTile(
                                dense: true,
                                leading: attendee.isVip
                                    ? const Icon(
                                        Icons.workspace_premium_rounded,
                                        color: AppTheme.accentAmber,
                                        size: 20)
                                    : const Icon(Icons.person_rounded,
                                        color: AppTheme.textSecondaryDark,
                                        size: 20),
                                title: Text(
                                  attendee.displayName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                                trailing: TextButton.icon(
                                  icon: const Icon(Icons.block_rounded,
                                      color: AppTheme.accentRed, size: 16),
                                  label: const Text(
                                    'Kick Out',
                                    style: TextStyle(
                                        color: AppTheme.accentRed,
                                        fontSize: 12),
                                  ),
                                  onPressed: () =>
                                      provider.kickAttendee(attendee.id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ).whenComplete(handleController.dispose);
  }

  Widget _buildPresetPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a broadcast quality',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            const Text(
              "Higher quality looks better but needs a stronger upload. "
              "You can't change this once you start the camera.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondaryDark, fontSize: 12.5),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ...BroadcastQualityPreset.values.map(
              (preset) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                child: _PresetOption(
                  preset: preset,
                  selected: _preset == preset,
                  onTap: () => setState(() => _preset = preset),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmPresetAndSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Continue',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetOption extends StatelessWidget {
  final BroadcastQualityPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentRed.withValues(alpha: 0.15)
              : AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.accentRed : AppTheme.textMutedDark,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondaryDark,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final int? bitrateBps;

  const _LiveBadge({required this.bitrateBps});

  @override
  Widget build(BuildContext context) {
    final bitrateLabel =
        bitrateBps == null ? '' : ' -- ${(bitrateBps! / 1000).round()} kbps';
    return _StatusPill(
      label: 'LIVE$bitrateLabel',
      color: AppTheme.accentRed,
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  final int? attempt;
  final int? maxAttempts;

  const _ReconnectingBanner({required this.attempt, required this.maxAttempts});

  @override
  Widget build(BuildContext context) {
    final attemptLabel = (attempt != null && maxAttempts != null)
        ? ' (attempt $attempt/$maxAttempts)'
        : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: Colors.orange.shade900,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              'Stream interrupted -- reconnecting$attemptLabel...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreamErrorBanner extends StatelessWidget {
  final String message;

  const _StreamErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: Colors.red.shade900,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KnockingBanner extends StatelessWidget {
  final StreamKnockRequest request;
  final int queueLength;
  final VoidCallback onAdmit;
  final VoidCallback onDeny;
  final VoidCallback onAdmitAll;

  const _KnockingBanner({
    required this.request,
    required this.queueLength,
    required this.onAdmit,
    required this.onDeny,
    required this.onAdmitAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: AppTheme.darkSurface1.withValues(alpha: 0.96),
      child: Row(
        children: [
          const Icon(Icons.person_rounded,
              color: AppTheme.accentAmber, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              '👤 ${request.displayName} wants to join',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (queueLength > 1) ...[
            TextButton(
              onPressed: onAdmitAll,
              child: Text('Admit All ($queueLength)',
                  style: const TextStyle(
                      color: AppTheme.accentGreen, fontSize: 11)),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppTheme.accentRed, size: 20),
            tooltip: 'Deny',
            onPressed: onDeny,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded,
                color: AppTheme.accentGreen, size: 20),
            tooltip: 'Admit',
            onPressed: onAdmit,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
