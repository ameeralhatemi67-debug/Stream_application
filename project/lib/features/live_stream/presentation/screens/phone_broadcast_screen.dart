import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_toast_overlay.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../discovery/models/academic_category_model.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../map/models/map_models.dart';
import '../../models/stream_privacy_models.dart';
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

  /// A note from the studio's watch-link check (not checked, or channel not
  /// matched), shown once when this screen opens.
  final String? watchLinkNoteKey;

  const PhoneBroadcastScreen(
      {super.key, this.quickLaunchPreset, this.watchLinkNoteKey});

  @override
  State<PhoneBroadcastScreen> createState() => _PhoneBroadcastScreenState();
}

class _PhoneBroadcastScreenState extends State<PhoneBroadcastScreen>
    with SingleTickerProviderStateMixin {
  final RtmpPublishEngine _engine = RtmpPublishEngine();
  final FloatingReactionsOverlayController _reactionsController =
      FloatingReactionsOverlayController();
  final TextEditingController _chatTextController = TextEditingController();
  final GlobalKey _previewKey = GlobalKey(debugLabel: 'phone-preview');
  final FocusNode _controlsFocus = FocusNode(debugLabel: 'phone-controls');
  final ScrollController _chatScrollController = ScrollController();

  late final LiveChatController _chatController;
  late TabController _tabController;

  String? _setupError;
  late BroadcastQualityPreset _preset;
  late bool _presetConfirmed;
  bool _isFullscreen = false;
  bool _isSideChatOpen = false;
  bool _controlsVisible = true;
  bool _wasLandscape = false;
  bool _isDescriptionExpanded = false;

  late AppProvider _appProvider;
  bool _appProviderCaptured = false;
  bool _weStartedBroadcast = false;
  bool _starting = false;
  bool _syncingLive = false;
  int _seenRemoteEnd = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (landscape && !_wasLandscape) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    _wasLandscape = landscape;
    if (!_appProviderCaptured) {
      _appProvider = Provider.of<AppProvider>(context, listen: false);
      _appProviderCaptured = true;
      _engine.authorizeRecovery = _appProvider.authorizeBroadcastRecovery;
      _engine.isOnline = () => _appProvider.isOnline;
      _seenRemoteEnd = _appProvider.remoteBroadcastEndGeneration;
      _appProvider.addListener(_onBroadcastSessionChanged);
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
      streamId: context.read<AppProvider>().customYouTubeVideoId,
      onReaction: (type) => _reactionsController.spawnReaction(type),
    );
    if (context.read<AppProvider>().customYouTubeVideoId.isNotEmpty) {
      _chatController.start();
    }
    _chatController.addListener(_handleChatConnectionChange);

    _setWakelock(true);

    final note = widget.watchLinkNoteKey;
    if (note != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        InteractiveToastOverlay.show(
          context,
          title: 'live_studio.watch_check_note_title'.tr(),
          message: note.tr(),
          icon: Icons.info_outline_rounded,
          accentColor: AppTheme.warning,
          duration: const Duration(seconds: 12),
          messageMaxLines: 8,
        );
      });
    }

    if (widget.quickLaunchPreset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirmPresetAndSetup();
      });
    }
  }

  void _setWakelock(bool enable) {
    try {
      final future = enable ? WakelockPlus.enable() : WakelockPlus.disable();
      future.catchError((Object e) {
        debugPrint('[PhoneBroadcastScreen] wakelock unavailable: $e');
      });
    } catch (e) {
      debugPrint('[PhoneBroadcastScreen] wakelock unavailable: $e');
    }
  }

  /// The studio's chat tab follows the real connection state. It used to fill
  /// with simulated comments while Realtime was unreachable (05 D-03).
  void _handleChatConnectionChange() {
    if (mounted) setState(() {});
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
      debugPrint('[PhoneBroadcastScreen] camera setup failed: $e');
      setState(() => _setupError = 'live.camera_setup_failed'.tr());
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
              backgroundColor: AppTheme.surface,
              title: Text(
                'design_ui.permission_required'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary),
              ),
              content: Text(
                (kind == BroadcastPermissionKind.camera
                        ? 'live.permission_required_body_camera'
                        : 'live.permission_required_body_microphone')
                    .tr(),
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text('design_ui.cancel'.tr()),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                  ),
                  child: Text('design_ui.open_settings'.tr()),
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
    if (_starting || _weStartedBroadcast) return;
    _starting = true;
    try {
      final permitted = await _appProvider.checkBroadcastPermission();
      if (!mounted) return;
      if (!permitted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                (_appProvider.broadcastSessionError ?? 'broadcast_state_failed')
                    .tr())));
        return;
      }
      _weStartedBroadcast = true;
      await _engine.startPublishing(_appProvider.phoneBroadcastFullUrl);
      final connected = await _engine.waitUntilLive();
      if (!mounted) return;
      if (!connected || !_weStartedBroadcast) {
        await _stopBroadcast();
        return;
      }
      _appProvider.setBroadcastSenderMode('phone_direct');
      await _appProvider.setBroadcasterLive(true, context);
      if (!_appProvider.isBroadcastingLive) await _stopBroadcast();
    } on Exception {
      await _stopBroadcast();
    } finally {
      _starting = false;
      if (mounted) {
        setState(() {});
        if (_weStartedBroadcast && _engine.state != RtmpPublishState.live) {
          _syncEncoderLiveState();
        }
      }
    }
  }

  void _onBroadcastSessionChanged() {
    if (!mounted) return;
    // Another device took the broadcaster role, or approval was withdrawn:
    // this device may not keep the camera open or publish, so leave.
    if (_appProvider.broadcastSessionError == 'broadcast_session_lost' ||
        !_appProvider.isApprovedStreamer) {
      _leaveAfterDisplacement();
      return;
    }
    // The server ended this broadcast (admin End, expiry). The device keeps
    // its role; stop sending once and never re-assert LIVE for it. The app
    // root explains the reason.
    if (_appProvider.remoteBroadcastEndGeneration != _seenRemoteEnd) {
      _seenRemoteEnd = _appProvider.remoteBroadcastEndGeneration;
      if (_weStartedBroadcast || _starting) {
        _weStartedBroadcast = false;
        _engine.stopPublishing();
      }
      setState(() {});
      return;
    }
    if (!_weStartedBroadcast) return;
    if (_appProvider.isBroadcastingLive) {
      _wasListed = true;
    } else if (_wasListed &&
        !_starting &&
        !_syncingLive &&
        _appProvider.broadcastSessionError == null) {
      // Something else in this app ended the listing (for example the
      // studio's End) while the encoder is still sending: stop sending too,
      // instead of re-listing on the next encoder event.
      _wasListed = false;
      _weStartedBroadcast = false;
      _engine.stopPublishing();
      setState(() {});
      return;
    }
    if (!_appProvider.isStreamerModeEnabled ||
        _appProvider.currentDeviceSession?.isPrimaryBroadcaster != true) {
      _stopBroadcast();
    }
    setState(() {});
  }

  bool _leavingAfterDisplacement = false;
  bool _wasListed = false;

  /// Stops the encoder, then removes this route; dispose() releases the
  /// camera, microphone, wakelock and orientation lock.
  Future<void> _leaveAfterDisplacement() async {
    if (_leavingAfterDisplacement) return;
    _leavingAfterDisplacement = true;
    await _stopBroadcast();
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route != null && route.isActive) {
      // An open "End this broadcast?" dialog would otherwise be left over
      // the previous page.
      if (!route.isCurrent) {
        Navigator.of(context).popUntil((r) => r == route);
      }
      Navigator.of(context).removeRoute(route);
    }
  }

  /// Whether this screen is sending, or about to. Leaving then ends the
  /// broadcast: capture is owned by this screen, and a foreground service
  /// that keeps broadcasting in the background is not built or verified yet.
  bool get _isSending =>
      _weStartedBroadcast ||
      _starting ||
      _engine.state == RtmpPublishState.connecting ||
      _engine.state == RtmpPublishState.live ||
      _engine.state == RtmpPublishState.reconnecting;

  bool _endDialogOpen = false;

  /// Set once End or Leave is under way: the button is disabled, Back is
  /// ignored and a second tap cannot pop the page underneath.
  bool _closing = false;

  /// Asks before ending a broadcast. Only the dialog; nothing is stopped.
  Future<bool> _askEnd() async {
    _endDialogOpen = true;
    final end = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            key: const Key('phone-end-confirm'),
            backgroundColor: AppTheme.surface,
            title: Text('live.end_confirm_title'.tr(),
                style: const TextStyle(color: AppTheme.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('live.end_confirm_body'.tr(),
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: AppTheme.spaceSm),
                Text('live.end_confirm_background_note'.tr(),
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('phone-end-stay'),
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('live.end_confirm_stay'.tr()),
              ),
              ElevatedButton(
                key: const Key('phone-end-confirm-end'),
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: AppTheme.onPrimary,
                ),
                child: Text('live.end_confirm_end'.tr()),
              ),
            ],
          ),
        ) ??
        false;
    _endDialogOpen = false;
    return end;
  }

  /// The End control, the studio's End and the Back gesture all come here.
  Future<void> _handleEndOrLeave() async {
    if (_closing || _endDialogOpen || _leavingAfterDisplacement) return;
    if (_isSending) {
      final end = await _askEnd();
      if (!end || !mounted || _closing || _leavingAfterDisplacement) return;
    }
    setState(() => _closing = true);
    var confirmed = true;
    // Only an end this screen asked the server for can fail to be confirmed;
    // a Leave with nothing listed makes no server call at all.
    final owned = _weStartedBroadcast;
    try {
      await _stopBroadcast();
      // The camera has stopped either way. A failed end call leaves the
      // listing in place (the provider restores it), so say so instead of
      // implying the listing is gone.
      confirmed = !owned || !_appProvider.isBroadcastingLive;
    } catch (e) {
      debugPrint('[PhoneBroadcastScreen] end failed: ${e.runtimeType}');
      confirmed = false;
    }
    if (!mounted) return;
    if (!confirmed) {
      InteractiveToastOverlay.show(
        context,
        title: 'live.end_unconfirmed_title'.tr(),
        message: 'live.end_unconfirmed_body'.tr(),
        icon: Icons.warning_amber_rounded,
        accentColor: AppTheme.warning,
        duration: const Duration(seconds: 10),
        messageMaxLines: 6,
      );
    }
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) Navigator.of(context).pop();
  }

  Future<void> _stopBroadcast() async {
    final owned = _weStartedBroadcast;
    _weStartedBroadcast = false;
    _wasListed = false;
    await _engine.stopPublishing();
    if (owned) await _appProvider.setBroadcasterLive(false);
  }

  int _seenRecovery = 0;

  void _onEngineChanged() {
    if (!mounted) return;
    if (_engine.recoveryCount > _seenRecovery) {
      _seenRecovery = _engine.recoveryCount;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('live.recovery_restored'.tr())));
    }
    setState(() {});
    if (_weStartedBroadcast && !_starting && !_syncingLive) {
      _syncEncoderLiveState();
    }
  }

  Future<void> _syncEncoderLiveState() async {
    if (_appProvider.hasLiveBroadcastSession) return _syncSessionIngest();
    _syncingLive = true;
    try {
      // Reconcile again if a disconnect arrives while the RPC is in flight.
      do {
        final live =
            _weStartedBroadcast && _engine.state == RtmpPublishState.live;
        await _appProvider.setBroadcasterLive(live);
        if (_appProvider.broadcastSessionError != null) break;
      } while (mounted &&
          _appProvider.isBroadcastingLive !=
              (_weStartedBroadcast && _engine.state == RtmpPublishState.live));
      if (_engine.state == RtmpPublishState.error ||
          _appProvider.broadcastSessionError != null) {
        await _stopBroadcast();
      }
    } finally {
      _syncingLive = false;
    }
  }

  /// With a server session the encoder's drops and recoveries are reported on
  /// that session; LIVE is not withdrawn and re-asserted on every blip. If
  /// the server says the session may no longer send (an admin ended it, the
  /// role moved to another device, it expired), the encoder stops here and
  /// only a new, explicit start can go live again.
  Future<void> _syncSessionIngest() async {
    _syncingLive = true;
    try {
      while (mounted && _weStartedBroadcast) {
        final state = _engine.state;
        if (state == RtmpPublishState.error) {
          await _stopBroadcast();
          return;
        }
        final bool sending;
        if (state == RtmpPublishState.live) {
          sending = true;
        } else if (state == RtmpPublishState.reconnecting ||
            state == RtmpPublishState.connecting) {
          sending = false;
        } else {
          // The encoder stopped on its own (idle/ready while this screen
          // still owns a broadcast): end the session rather than leave it
          // listed as sending.
          await _stopBroadcast();
          return;
        }
        final allowed =
            await _appProvider.reportBroadcastIngest(sending: sending);
        if (!allowed) {
          _weStartedBroadcast = false;
          await _engine.stopPublishing();
          if (mounted) setState(() {});
          return;
        }
        // Report again only if the encoder moved on while the call was out.
        final now = _engine.state;
        final nowSending = now == RtmpPublishState.live;
        if (now != RtmpPublishState.error &&
            (now == state || nowSending == sending)) {
          return;
        }
      }
    } finally {
      _syncingLive = false;
    }
  }

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
    if (_appProviderCaptured) {
      _appProvider.removeListener(_onBroadcastSessionChanged);
    }
    _setWakelock(false);
    _restorePortraitChrome();

    _tabController.dispose();
    _chatTextController.dispose();
    _controlsFocus.dispose();
    _chatScrollController.dispose();
    _chatController.removeListener(_handleChatConnectionChange);
    _chatController.dispose();
    _engine.removeListener(_onEngineChanged);
    _engine.isMicSilent.removeListener(_onMicSilenceChanged);
    if (_appProviderCaptured) _appProvider.setStreamerMicMuted(false);
    // A successful start RPC may still be pending when the route closes.
    // Queue stop behind it even while the visible state is still offline.
    if (_weStartedBroadcast) {
      final provider = _appProvider;
      Future.microtask(() => provider.setBroadcasterLive(false));
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
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSending && !_closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleEndOrLeave();
      },
      child: _buildScreen(context),
    );
  }

  Widget _buildScreen(BuildContext context) {
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
        backgroundColor: AppTheme.bg,
        appBar: AppBar(
          backgroundColor: AppTheme.surface,
          title: Text('live.broadcast_from_phone'.tr()),
        ),
        body: _buildPresetPicker(),
      );
    }

    if (_isFullscreen || isLandscape) {
      return Scaffold(
        backgroundColor: AppTheme.media,
        resizeToAvoidBottomInset: false,
        body: _buildFullscreenLandscapeLayout(title, streamer, langCode),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppTheme.textPrimary, size: 22),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _handleEndOrLeave,
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: AppTheme.surface,
              backgroundImage: resolveImageProviderOrNull(streamer.avatarUrl),
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
                            color: AppTheme.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (streamer.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 14, color: AppTheme.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.6),
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
                                color: AppTheme.danger,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (_engine.state == RtmpPublishState.live &&
                                          _appProvider.isBroadcastingLive
                                      ? 'design_ui.live'
                                      : 'live.not_live')
                                  .tr(),
                              style: const TextStyle(
                                color: AppTheme.danger,
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
                            color: AppTheme.textSecondary,
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
            margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSm, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.danger.withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.cell_tower_rounded,
                  color: AppTheme.danger, size: 20),
              tooltip: 'live.tooltip_studio'.tr(),
              onPressed: () => LiveBroadcasterStudioSheet.show(context,
                  onEndBroadcast: _handleEndOrLeave),
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
                  const VerticalDivider(width: 1, color: AppTheme.border),
                  Expanded(
                    flex: isDesktop ? 35 : 42,
                    child: _buildCinemaTabPanel(langCode),
                  ),
                ],
              )
            : Column(
                children: [
                  if (mediaQuery.viewInsets.bottom == 0) ...[
                    _buildVideoViewport(
                        isSideBySide: false, streamer: streamer),
                    _buildTitleAndDescriptionStrip(
                        title, description, streamer, langCode),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.all(AppTheme.spaceSm),
                      child: _endControl(),
                    ),
                  ],
                  Expanded(child: _buildCinemaTabPanel(langCode)),
                ],
              ),
      ),
    );
  }

  bool _checkingRetry = false;
  Future<void> _retryBroadcast() async {
    if (_checkingRetry || _closing || _isSending) return;
    setState(() => _checkingRetry = true);
    final user = _appProvider.currentUserSessionId;
    try {
      final check =
          await _appProvider.verifyWatchLink(_appProvider.customYouTubeVideoId);
      if (!mounted || _closing || user != _appProvider.currentUserSessionId) {
        return;
      }
      if (!check.allowsStart) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text((check.errorKey ?? 'live.channel_lookup_required').tr())));
        return;
      }
      await _startBroadcast();
    } finally {
      if (mounted) setState(() => _checkingRetry = false);
    }
  }

  Widget _recoveryStatus() {
    if (_engine.lastError != null && !_isSending) {
      return Material(
        key: const Key('sender-recovery-exhausted'),
        color: AppTheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('live.recovery_exhausted'.tr()),
            TextButton(
                onPressed: _starting || _checkingRetry ? null : _retryBroadcast,
                child: Text('live.recovery_retry'.tr())),
            TextButton(
                onPressed: _handleEndOrLeave,
                child: Text('live.recovery_leave'.tr())),
          ]),
        ),
      );
    }
    if (_engine.state == RtmpPublishState.reconnecting) {
      return _ReconnectingBanner(
          attempt: _engine.reconnectAttempt,
          maxAttempts: _engine.maxReconnectAttempts);
    }
    return const SizedBox.shrink();
  }

  Widget _buildVideoViewport({
    required bool isSideBySide,
    required StreamerModel streamer,
  }) {
    if (_setupError != null) {
      return Container(
        color: AppTheme.media,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _setupError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.danger),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            _endControl(),
          ],
        ),
      );
    }

    final loading = _engine.state == RtmpPublishState.idle ||
        _engine.state == RtmpPublishState.initializingCamera;

    final videoContent = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: Container(
        color: AppTheme.media,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Camera Platform View (or Camera Off Audio Poster)
            if (_engine.isCameraOff)
              Container(
                color: AppTheme.bg,
                alignment: Alignment.center,
                // Keeps the poster's button clear of the pinned End control.
                padding: const EdgeInsets.only(bottom: 56),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: AppTheme.surface,
                        backgroundImage:
                            resolveImageProviderOrNull(streamer.avatarUrl),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.videocam_off_rounded,
                                size: 14, color: AppTheme.warning),
                            const SizedBox(width: 6),
                            Text(
                              'live.video_hidden_badge'.tr(),
                              style: const TextStyle(
                                color: AppTheme.warning,
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
                        label: Text('design_ui.turn_on_camera'.tr(),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        style: TextButton.styleFrom(
                          // surfaceAlt is a near-white tint, not a media
                          // surface, so the label takes the primary accent
                          // rather than `onMedia` white on near-white.
                          foregroundColor: AppTheme.primary,
                          backgroundColor: AppTheme.surfaceAlt,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ClipRect(
                child: SizedBox.expand(
                  child: PhoneCameraPreview(key: _previewKey),
                ),
              ),

            // 2. Loading indicator
            if (loading && !_engine.isCameraOff)
              const ColoredBox(
                color: AppTheme.media,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.danger),
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
                    if (_engine.state == RtmpPublishState.live &&
                        _appProvider.isBroadcastingLive)
                      PositionedDirectional(
                        top: AppTheme.spaceSm,
                        start: AppTheme.spaceSm,
                        child: _LiveBadge(bitrateBps: _engine.lastBitrateBps),
                      ),

                    if (_engine.state == RtmpPublishState.connecting)
                      PositionedDirectional(
                        top: AppTheme.spaceSm,
                        start: AppTheme.spaceSm,
                        child: _StatusPill(
                            label: 'live.chat_status_connecting'.tr(),
                            color: AppTheme.warning),
                      ),

                    // Top Right: 3-Dots Streamer Controls Menu
                    PositionedDirectional(
                      top: AppTheme.spaceSm,
                      end: AppTheme.spaceSm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.media.withValues(alpha: 0.65),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                              color: AppTheme.onMedia.withValues(alpha: 0.24),
                              width: 0.8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: AppTheme.onMedia, size: 20),
                          tooltip: 'live.tooltip_controls'.tr(),
                          onPressed: () => _showStreamerControlsSheet(streamer),
                        ),
                      ),
                    ),

                    // Bottom Right: Fullscreen Button
                    PositionedDirectional(
                      bottom: AppTheme.spaceSm,
                      end: AppTheme.spaceSm,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.media.withValues(alpha: 0.65),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(
                              color: AppTheme.onMedia.withValues(alpha: 0.24),
                              width: 0.8),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.fullscreen_rounded,
                              color: AppTheme.onMedia, size: 20),
                          tooltip: 'live.tooltip_fullscreen'.tr(),
                          onPressed: _handleToggleFullscreen,
                        ),
                      ),
                    ),

                    // Mic Muted Pill
                    // Hidden while the audio-only poster shows: it would sit
                    // over the poster's button.
                    if (_engine.isMuted && !_engine.isCameraOff)
                      PositionedDirectional(
                        bottom: 60,
                        start: AppTheme.spaceSm,
                        child: _StatusPill(
                          label: 'live.mic_muted_badge'.tr(),
                          color: AppTheme.danger,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // End is never faded with the other controls.
            PositionedDirectional(
              bottom: AppTheme.spaceSm,
              start: 0,
              end: 0,
              child: Center(child: _endControl()),
            ),

            // 5. Error Banner
            if (_engine.state == RtmpPublishState.error &&
                _engine.lastError != null)
              PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child:
                    _StreamErrorBanner(message: 'live.connection_error'.tr()),
              ),

            // 6. Floating Reaction Hearts Overlay
            FloatingReactionsOverlay(controller: _reactionsController),
            PositionedDirectional(
                top: 64, start: 8, end: 8, child: _recoveryStatus()),

            // 7. Knocking Requests (Private Stream)
            Consumer<AppProvider>(
              builder: (context, provider, _) {
                if (provider.pendingKnockRequests.isEmpty) {
                  return const SizedBox.shrink();
                }
                final request = provider.pendingKnockRequests.first;
                return PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
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
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMuted = _engine.isMuted;
            final isCameraOff = _engine.isCameraOff;
            final isFrontCamera = _engine.isFrontCamera;

            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusLg)),
                border: Border(
                  top: BorderSide(color: AppTheme.borderStrong, width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
              child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.borderStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded,
                                color: AppTheme.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'design_ui.streamer_quick_controls'.tr(),
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spaceMd),

                        // 1.  Microphone Mute Toggle
                        ListenableBuilder(
                          listenable: _engine,
                          builder: (context, _) => _engine.state ==
                                  RtmpPublishState.live
                              ? _LiveBadge(bitrateBps: _engine.lastBitrateBps)
                              : Text(_engine.state ==
                                      RtmpPublishState.reconnecting
                                  ? 'live.stream_interrupted_reconnecting'.tr()
                                  : _engine.state == RtmpPublishState.error
                                      ? 'live.connection_error'.tr()
                                      : 'live.chat_status_connecting'.tr()),
                        ),
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          tileColor: isMuted
                              ? AppTheme.danger.withValues(alpha: 0.15)
                              : AppTheme.surfaceAlt,
                          leading: Icon(
                            isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: isMuted ? AppTheme.danger : AppTheme.success,
                          ),
                          title: Text(
                            (isMuted ? 'live.ctrl_unmute' : 'live.ctrl_mute')
                                .tr(),
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            (isMuted
                                    ? 'live.ctrl_mic_muted_sub'
                                    : 'live.ctrl_mic_active_sub')
                                .tr(),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          trailing: Switch(
                            value: !isMuted,
                            activeThumbColor: AppTheme.success,
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

                        // 2.  Flip Camera Toggle
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          tileColor: AppTheme.surfaceAlt,
                          leading: const Icon(Icons.flip_camera_ios_rounded,
                              color: AppTheme.primary),
                          title: Text(
                            (isFrontCamera
                                    ? 'live.ctrl_switch_to_back'
                                    : 'live.ctrl_switch_to_front')
                                .tr(),
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            (isFrontCamera
                                    ? 'live.ctrl_front_active_sub'
                                    : 'live.ctrl_back_active_sub')
                                .tr(),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          trailing: const Icon(Icons.sync_rounded,
                              color: AppTheme.textSecondary, size: 18),
                          onTap: isCameraOff
                              ? null
                              : () async {
                                  await _engine.switchCamera();
                                  setModalState(() {});
                                  setState(() {});
                                },
                        ),
                        const SizedBox(height: 8),

                        // 3.  Close Camera (Video / Audio-Only Toggle)
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          tileColor: isCameraOff
                              ? AppTheme.warning.withValues(alpha: 0.15)
                              : AppTheme.surfaceAlt,
                          leading: Icon(
                            isCameraOff
                                ? Icons.videocam_off_rounded
                                : Icons.videocam_rounded,
                            color: isCameraOff
                                ? AppTheme.warning
                                : AppTheme.primary,
                          ),
                          title: Text(
                            (isCameraOff
                                    ? 'live.ctrl_show_video'
                                    : 'live.ctrl_hide_video')
                                .tr(),
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            (isCameraOff
                                    ? 'live.ctrl_video_hidden_sub'
                                    : 'live.ctrl_video_shown_sub')
                                .tr(),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          trailing: Switch(
                            value: !isCameraOff,
                            activeThumbColor: AppTheme.primary,
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

                        // 4.  Private Attendees Admission (if private)
                        if (_appProvider.isActiveStreamPrivate) ...[
                          ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            tileColor: AppTheme.surfaceAlt,
                            leading: const Icon(Icons.people_alt_rounded,
                                color: AppTheme.warning),
                            title: Text(
                              'live.ctrl_manage_attendees'.tr(args: [
                                '${_appProvider.admittedAttendees.length}'
                              ]),
                              style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5),
                            ),
                            subtitle: Text(
                              'live.ctrl_waiting_queue'.tr(args: [
                                '${_appProvider.pendingKnockRequests.length}'
                              ]),
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _showDirectorPanel(context, _appProvider);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 5.  Studio & End Stream Shortcut
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          tileColor: AppTheme.danger.withValues(alpha: 0.1),
                          leading: const Icon(Icons.cell_tower_rounded,
                              color: AppTheme.danger),
                          title: Text(
                            'design_ui.broadcaster_studio_end_stream'.tr(),
                            style: const TextStyle(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            'design_ui.adjust_stream_settings_or_end_broadcast_session'
                                .tr(),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 11),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              color: AppTheme.danger, size: 14),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            LiveBroadcasterStudioSheet.show(context,
                                onEndBroadcast: _handleEndOrLeave);
                          },
                        ),
                      ],
                    ),
                  )),
            );
          },
        );
      },
    );
  }

  /// Always visible while this screen is open, in both orientations. While
  /// nothing is sending it reads "Leave" and closes without asking.
  Widget _endControl() {
    final sending = _isSending;
    return FilledButton.icon(
      key: const Key('phone-end-broadcast'),
      onPressed: _closing ? null : _handleEndOrLeave,
      icon: _closing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppTheme.onPrimary),
            )
          : Icon(sending ? Icons.stop_circle_rounded : Icons.logout_rounded,
              size: 18),
      label: Text(
          (_closing
                  ? 'live.ending'
                  : sending
                      ? 'live.end_broadcast'
                      : 'live.leave_screen')
              .tr(),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      style: FilledButton.styleFrom(
        backgroundColor: sending ? AppTheme.danger : AppTheme.surfaceAlt,
        foregroundColor: sending ? AppTheme.onPrimary : AppTheme.textPrimary,
        // "Ending..." keeps the danger colour and stays readable.
        disabledBackgroundColor: AppTheme.danger.withValues(alpha: 0.75),
        disabledForegroundColor: AppTheme.onPrimary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  String get _presetCompactLabel => '${_preset.height}p';

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
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
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
                      color: AppTheme.onMedia,
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
                  color: AppTheme.textSecondary,
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
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    categoryModel.getLocalizedName(langCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Text(
                  _presetCompactLabel,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.remove_red_eye_rounded,
                  size: 14, color: AppTheme.success),
              const SizedBox(width: 4),
              // YouTube's concurrent-viewer figure, labelled as YouTube's and
              // never merged with this platform's presence count (P3).
              Text(
                '${_appProvider.youTubeConcurrentViewers(streamer.streamerId) ?? '—'} on YouTube',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Row 3: Expanded Description & Organization (when expanded)
          if (_isDescriptionExpanded) ...[
            const SizedBox(height: 10),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty ? description : 'No description provided.',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  streamer.getLocalizedOrganization(langCode),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
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
      color: AppTheme.bg,
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
              color: AppTheme.surface,
              border: Border(
                top: BorderSide(color: AppTheme.border, width: 0.8),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.danger,
              labelColor: AppTheme.danger,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorWeight: 2.0,
              tabs: [
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                          child: Text('live.tab_chat'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
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
                      Flexible(
                          child: Text('live.tab_sources'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
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
                      Flexible(
                          child: Text('live.tab_venue'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold))),
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
    return ListenableBuilder(
      listenable: _chatController,
      builder: (context, _) {
        // Real messages only: an empty room stays empty (05 D-03).
        final messages = _chatController.messages;

        return LiveChatWidget(
          textController: _chatTextController,
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
      color: AppTheme.bg,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'live.slides_attached_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'live.slides_attached_subtitle'.tr(),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.slideshow_rounded,
                      size: 48, color: AppTheme.primary),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    streamer.getLocalizedTitle(langCode),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'design_ui.presentation_deck_pdf_attached'.tr(),
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11),
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
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'live.venue_details_title'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
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
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueInfo.getLocalizedAddress(langCode),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12.5),
                ),
                const Divider(color: AppTheme.border, height: 16),
                Text(
                  'Hall: ${venueInfo.getLocalizedAuditorium(langCode)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gate: ${venueInfo.getLocalizedGate(langCode)}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capacity: ${venueInfo.seatingCapacity} Seats',
                  style: const TextStyle(color: AppTheme.success, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLandscapeControls() {
    if (_controlsVisible &&
        (_controlsFocus.hasFocus ||
            MediaQuery.of(context).accessibleNavigation)) {
      return;
    }
    setState(() => _controlsVisible = !_controlsVisible);
  }

  Widget _buildFullscreenLandscapeLayout(
      String title, StreamerModel streamer, String langCode) {
    final visible =
        _controlsVisible || MediaQuery.of(context).accessibleNavigation;
    return Semantics(
      label: 'live.toggle_overlay_controls'.tr(),
      onTap: _toggleLandscapeControls,
      child: GestureDetector(
        key: const Key('phone-landscape-media'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggleLandscapeControls,
        child: Stack(fit: StackFit.expand, children: [
          if (_engine.isCameraOff)
            Center(
                child: Text('live.video_hidden_badge'.tr(),
                    style: const TextStyle(color: AppTheme.onMedia)))
          else
            PhoneCameraPreview(key: _previewKey),
          FloatingReactionsOverlay(controller: _reactionsController),
          PositionedDirectional(
              top: 64, start: 8, end: 8, child: _recoveryStatus()),
          if (visible)
            SafeArea(
                child: Focus(
              focusNode: _controlsFocus,
              child: Stack(children: [
                PositionedDirectional(
                  top: AppTheme.spaceSm,
                  start: AppTheme.spaceSm,
                  child: IconButton.filled(
                    tooltip: 'live.tooltip_exit_fullscreen'.tr(),
                    onPressed: _handleToggleFullscreen,
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
                ),
                PositionedDirectional(
                  top: AppTheme.spaceSm,
                  end: AppTheme.spaceSm,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton.filled(
                      tooltip: 'live.tooltip_controls'.tr(),
                      onPressed: () => _showStreamerControlsSheet(streamer),
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                    IconButton.filled(
                      tooltip: 'live.tooltip_toggle_chat'.tr(),
                      onPressed: () =>
                          setState(() => _isSideChatOpen = !_isSideChatOpen),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                    ),
                  ]),
                ),
                PositionedDirectional(
                  bottom: AppTheme.spaceSm,
                  start: AppTheme.spaceSm,
                  child: _endControl(),
                ),
              ]),
            )),
          if (visible && _isSideChatOpen)
            PositionedDirectional(
              top: 64,
              bottom: AppTheme.spaceSm,
              end: AppTheme.spaceSm,
              width: MediaQuery.sizeOf(context).width * 0.42,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: _buildLiveChatTab(),
              ),
            ),
        ]),
      ),
    );
  }

  void _showDirectorPanel(BuildContext context, AppProvider provider) {
    final handleController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
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
                    'live.attendees_count'
                        .tr(args: ['${provider.admittedAttendees.length}']),
                    style: const TextStyle(
                      color: AppTheme.onMedia,
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
                              color: AppTheme.onMedia, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'live.attendee_search_hint'.tr(),
                            hintStyle: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12),
                            filled: true,
                            fillColor: AppTheme.surfaceAlt,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusSm),
                              borderSide:
                                  const BorderSide(color: AppTheme.border),
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
                            color: AppTheme.success),
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
                        ? Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: AppTheme.spaceMd),
                            child: Text(
                              'design_ui.no_attendees_admitted_yet'.tr(),
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 12),
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
                                        color: AppTheme.warning,
                                        size: 20)
                                    : const Icon(Icons.person_rounded,
                                        color: AppTheme.textSecondary,
                                        size: 20),
                                title: Text(
                                  attendee.displayName,
                                  style: const TextStyle(
                                      color: AppTheme.onMedia, fontSize: 13),
                                ),
                                trailing: TextButton.icon(
                                  icon: const Icon(Icons.block_rounded,
                                      color: AppTheme.danger, size: 16),
                                  label: Text(
                                    'design_ui.kick_out'.tr(),
                                    style: const TextStyle(
                                        color: AppTheme.danger, fontSize: 12),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'design_ui.choose_a_broadcast_quality'.tr(),
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'design_copy.quality_help'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12.5),
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
                  backgroundColor: AppTheme.danger,
                  foregroundColor: AppTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('design_ui.continue'.tr(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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
              ? AppTheme.danger.withValues(alpha: 0.15)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.danger : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.danger : AppTheme.textMuted,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.labelKey.tr(),
                style: TextStyle(
                  color: selected ? AppTheme.primary : AppTheme.textSecondary,
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
    return _StatusPill(
      label: bitrateBps == null
          ? 'live.live_indicator'.tr()
          : 'live.live_badge_bitrate'
              .tr(args: ['${(bitrateBps! / 1000).round()}']),
      color: AppTheme.danger,
    );
  }
}

class _ReconnectingBanner extends StatelessWidget {
  final int? attempt;
  final int? maxAttempts;

  const _ReconnectingBanner({required this.attempt, required this.maxAttempts});

  @override
  Widget build(BuildContext context) {
    final message = (attempt != null && maxAttempts != null)
        ? 'live.stream_interrupted_reconnecting_attempt'
            .tr(namedArgs: {'current': '$attempt', 'total': '$maxAttempts'})
        : 'live.stream_interrupted_reconnecting'.tr();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: AppTheme.warning,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.onMedia, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.onMedia,
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
      color: AppTheme.danger,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.onMedia, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.onMedia,
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
      color: AppTheme.surface.withValues(alpha: 0.96),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppTheme.warning, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              ' ${request.displayName} wants to join',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.onMedia,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (queueLength > 1) ...[
            TextButton(
              onPressed: onAdmitAll,
              child: Text('live.admit_all'.tr(args: ['$queueLength']),
                  style:
                      const TextStyle(color: AppTheme.success, fontSize: 11)),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppTheme.danger, size: 20),
            tooltip: 'live.tooltip_deny'.tr(),
            onPressed: onDeny,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded,
                color: AppTheme.success, size: 20),
            tooltip: 'live.tooltip_admit'.tr(),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AppTheme.onMedia, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
