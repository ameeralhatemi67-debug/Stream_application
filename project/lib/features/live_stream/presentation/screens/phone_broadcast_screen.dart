import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/language_switcher.dart';
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
        body: _buildFullscreenLandscapeLayout(title, langCode),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSecondaryDark,
                ),
              ),
          ],
        ),
        actions: const [
          LanguageSwitcher(),
          SizedBox(width: AppTheme.spaceSm),
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
                        Expanded(child: _buildVideoViewport(isSideBySide: true)),
                        _buildBroadcasterControlsStrip(),
                        _buildBroadcasterHeader(title, description, langCode),
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
                  _buildVideoViewport(isSideBySide: false),
                  _buildBroadcasterControlsStrip(),
                  _buildBroadcasterHeader(title, description, langCode),
                  Expanded(child: _buildCinemaTabPanel(langCode)),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoViewport({required bool isSideBySide}) {
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

    final videoContent = Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Camera Platform View (properly clipped with 0 distortion)
          const ClipRect(
            child: SizedBox.expand(
              child: PhoneCameraPreview(),
            ),
          ),

          // 2. Loading indicator
          if (loading)
            const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.accentRed),
              ),
            ),

          // 3. Live Bitrate Badge (Top Left)
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
              child: _StatusPill(label: 'Connecting...', color: Colors.amber),
            ),

          // 4. Fullscreen Button (Bottom Right of player)
          Positioned(
            bottom: AppTheme.spaceSm,
            right: AppTheme.spaceSm,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: IconButton(
                icon: const Icon(Icons.fullscreen_rounded,
                    color: Colors.white, size: 20),
                tooltip: 'Fullscreen',
                onPressed: _handleToggleFullscreen,
              ),
            ),
          ),

          // 5. Audio Only Pill
          if (_engine.isAudioOnly)
            const Positioned(
              top: AppTheme.spaceSm,
              right: AppTheme.spaceSm,
              child: _StatusPill(label: 'AUDIO ONLY', color: AppTheme.accentBlue),
            ),

          // 6. Reconnecting Banner
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

          // 7. Error Banner
          if (_engine.state == RtmpPublishState.error &&
              _engine.lastError != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _StreamErrorBanner(message: _engine.lastError!),
            ),

          // 8. Floating Reaction Hearts Overlay
          FloatingReactionsOverlay(controller: _reactionsController),

          // 9. Knocking Requests (Private Stream)
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
    );

    if (isSideBySide) return videoContent;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: videoContent,
    );
  }

  Widget _buildBroadcasterControlsStrip() {
    final ready = _engine.state == RtmpPublishState.ready ||
        _engine.state == RtmpPublishState.stopped;
    final live = _engine.state == RtmpPublishState.live;
    final connecting = _engine.state == RtmpPublishState.connecting;
    final broadcastActive =
        live || _engine.state == RtmpPublishState.reconnecting;
    final canToggleGoLive =
        ready || broadcastActive || _engine.state == RtmpPublishState.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceLg,
        vertical: 8.0,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface1,
        border: Border(
          bottom: BorderSide(color: AppTheme.darkBorderSubtle, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🎤 Mic Mute Toggle
          Container(
            decoration: BoxDecoration(
              color: _engine.isMuted
                  ? AppTheme.accentRed.withValues(alpha: 0.2)
                  : AppTheme.darkSurface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                color: _engine.isMuted
                    ? AppTheme.accentRed
                    : AppTheme.darkBorderSubtle,
              ),
            ),
            child: IconButton(
              iconSize: 20,
              onPressed: broadcastActive || ready
                  ? () => _engine.setMuted(!_engine.isMuted)
                  : null,
              icon: Icon(
                _engine.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: _engine.isMuted ? AppTheme.accentRed : Colors.white,
              ),
              tooltip:
                  _engine.isMuted ? 'Unmute microphone' : 'Mute microphone',
            ),
          ),

          // 🛑 Go Live / End Broadcast Button
          ElevatedButton.icon(
            onPressed: connecting
                ? null
                : canToggleGoLive
                    ? (broadcastActive ? _stopBroadcast : _startBroadcast)
                    : null,
            icon: Icon(
              broadcastActive
                  ? Icons.stop_circle_rounded
                  : Icons.sensors_rounded,
              size: 18,
            ),
            label: Text(
              connecting
                  ? 'Connecting...'
                  : broadcastActive
                      ? 'End Broadcast'
                      : 'Go Live',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: broadcastActive
                  ? Colors.red.shade800
                  : AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),

          // 🔄 Flip Camera Button
          Container(
            decoration: BoxDecoration(
              color: AppTheme.darkSurface2,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(color: AppTheme.darkBorderSubtle),
            ),
            child: IconButton(
              iconSize: 20,
              onPressed: (ready || broadcastActive) && !_engine.isAudioOnly
                  ? _engine.switchCamera
                  : null,
              icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
              tooltip: _engine.isAudioOnly
                  ? 'Not available in audio-only'
                  : 'Flip camera',
            ),
          ),

          // 🔒 Private Stream Attendees Button (if active)
          Consumer<AppProvider>(
            builder: (context, provider, _) {
              if (!provider.isActiveStreamPrivate) {
                return const SizedBox.shrink();
              }
              return Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                      color: AppTheme.accentAmber.withValues(alpha: 0.5)),
                ),
                child: IconButton(
                  iconSize: 20,
                  icon: const Icon(Icons.lock_rounded,
                      color: AppTheme.accentAmber),
                  tooltip: '${provider.admittedAttendees.length} Attendees',
                  onPressed: () => _showDirectorPanel(context, provider),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcasterHeader(
      String title, String description, String langCode) {
    final streamer = _appProvider.activeStreamer ?? _appProvider.streamers.first;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface1,
        border: Border(
            bottom: BorderSide(color: AppTheme.darkBorderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.darkSurface3,
            backgroundImage: _getAvatarProvider(streamer.avatarUrl),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        streamer.getLocalizedName(langCode),
                        style: const TextStyle(
                          color: AppTheme.textPrimaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        color: AppTheme.accentBlue, size: 14),
                  ],
                ),
                Text(
                  streamer.getLocalizedOrganization(langCode),
                  style: const TextStyle(
                      color: AppTheme.textSecondaryDark, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              border: Border.all(
                  color: AppTheme.accentRed.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_rounded,
                    color: AppTheme.accentRed, size: 13),
                const SizedBox(width: 4),
                Text(
                  'live.broadcaster_mode'.tr(),
                  style: const TextStyle(
                    color: AppTheme.accentRed,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaTabPanel(String langCode) {
    final streamer = _appProvider.activeStreamer ?? _appProvider.streamers.first;

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

  Widget _buildFullscreenLandscapeLayout(String title, String langCode) {
    final live = _engine.state == RtmpPublishState.live;
    final broadcastActive =
        live || _engine.state == RtmpPublishState.reconnecting;

    return Stack(
      children: [
        // 1. Fullscreen Camera Preview
        const SizedBox.expand(
          child: PhoneCameraPreview(),
        ),

        // 2. Reactions Overlay
        FloatingReactionsOverlay(controller: _reactionsController),

        // 3. Top Translucent Overlay Bar
        Positioned(
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
                    title,
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

        // 5. Floating Bottom Control Capsule
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 22,
                    onPressed: () => _engine.setMuted(!_engine.isMuted),
                    icon: Icon(
                      _engine.isMuted
                          ? Icons.mic_off_rounded
                          : Icons.mic_rounded,
                      color: _engine.isMuted
                          ? AppTheme.accentRed
                          : Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: broadcastActive
                        ? _stopBroadcast
                        : _startBroadcast,
                    icon: Icon(
                      broadcastActive
                          ? Icons.stop_circle_rounded
                          : Icons.sensors_rounded,
                      size: 18,
                    ),
                    label: Text(
                      broadcastActive ? 'End' : 'Go Live',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: broadcastActive
                          ? Colors.red.shade800
                          : AppTheme.accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 22,
                    onPressed: !_engine.isAudioOnly
                        ? _engine.switchCamera
                        : null,
                    icon: const Icon(Icons.cameraswitch_rounded,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
