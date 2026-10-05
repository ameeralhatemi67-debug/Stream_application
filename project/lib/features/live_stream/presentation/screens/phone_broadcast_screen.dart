import '../../../../core/widgets/phone_input_guard.dart';
import '../../../../core/widgets/ds/ca_navigation.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/ds/ca_rows.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/canopy_motion.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/layout/window_class.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
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
import '../widgets/live_chat_layout.dart';
import '../widgets/permission_rationale_dialog.dart';
import '../widgets/phone_camera_preview.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';

/// Full-featured Stream Page for Phone Broadcasters:
/// Unifies the broadcaster's phone camera stream with the exact same
/// rich stream page interface (16:9 player viewport, live chat, lecture slides,
/// venue info, viewer reactions, and integrated broadcaster studio controls).
class PhoneBroadcastScreen extends StatefulWidget {
  final BroadcastQualityPreset? quickLaunchPreset;
  final bool autoStart;

  /// A note from the studio's watch-link check (not checked, or channel not
  /// matched), shown once when this screen opens.
  final String? watchLinkNoteKey;

  const PhoneBroadcastScreen(
      {super.key, this.quickLaunchPreset, this.watchLinkNoteKey, this.autoStart=true});

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
  bool _isSideChatOpen = false;
  bool _controlsVisible = true;
  bool _wasLandscape = false;
  bool _isDescriptionExpanded = false;

  late AppProvider _appProvider;
  bool _appProviderCaptured = false;
  bool _weStartedBroadcast = false;
  String? _openedSessionId;
  bool get _ownsPreparedSession => !widget.autoStart && _openedSessionId != null &&
      _appProvider.publishingSession?.id == _openedSessionId &&
      _appProvider.publishingSession?.state == 'preparing' &&
      _appProvider.currentDeviceSession?.isPrimaryBroadcaster == true;
  bool _starting = false;
  bool get _showingPreview => !widget.autoStart && !_weStartedBroadcast &&
      !_starting && !_appProvider.isBroadcastingLive;
  bool get _canStartPreview => !widget.autoStart && !_weStartedBroadcast &&
      !_starting && !_closing && _engine.state == RtmpPublishState.ready;
  bool _syncingLive = false;
  int _seenRemoteEnd = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    if (context.isPhoneLandscape && !_wasLandscape) {
      FocusManager.instance.primaryFocus?.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    if (landscape != _wasLandscape) {
      SystemChrome.setEnabledSystemUIMode(
          landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
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
    _openedSessionId = context.read<AppProvider>().publishingSession?.id;
    _engine.addListener(_onEngineChanged);
    _engine.isMicSilent.addListener(_onMicSilenceChanged);
    _preset = widget.quickLaunchPreset ?? BroadcastQualityPreset.medium;
    _presetConfirmed = widget.quickLaunchPreset != null;

    _tabController = TabController(length: 3, vsync: this);
    _chatController = LiveChatController(
      streamId: context.read<AppProvider>().liveSessionId ?? '',
      onReaction: (type) => _reactionsController.spawnReaction(type),
    );
    if (context.read<AppProvider>().liveSessionId != null) {
      _chatController.start();
    }
    _chatController.addListener(_handleChatConnectionChange);

    _setWakelock(true);
    // Leaving a previous room can lock portrait. Enable rotation on every entry;
    // physical orientation owns fullscreen, so there is no exit-icon lock trap.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
      if (widget.quickLaunchPreset != null && widget.autoStart && mounted) {
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
      final openSettings = await showCaDialog<bool>(
            context: context,
            builder: (dialogContext) => CaAlertDialog(
              backgroundColor: AppTheme.surface,
              title: Text(
                'design_ui.permission_required'.tr(),
                style: const TextStyle(color: Canopy.ink),
              ),
              content: Text(
                (kind == BroadcastPermissionKind.camera
                        ? 'live.permission_required_body_camera'
                        : 'live.permission_required_body_microphone')
                    .tr(),
                style: const TextStyle(color: Canopy.slate),
              ),
              actions: [
                CaButton(
                    label: 'design_ui.cancel'.tr(),
                    variant: CaButtonVariant.text,
                    onPressed: () => Navigator.pop(dialogContext, false)),
                CaButton(
                    label: 'design_ui.open_settings'.tr(),
                    variant: CaButtonVariant.primary,
                    onPressed: () => Navigator.pop(dialogContext, true)),
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
    setState(() => _starting = true);
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
    final end = await showCaDialog<bool>(
          context: context,
          builder: (dialogContext) => CaAlertDialog(
            key: const Key('phone-end-confirm'),
            scrollable: true,
            backgroundColor: AppTheme.surface,
            title: Text('live.end_confirm_title'.tr(),
                style: const TextStyle(color: Canopy.ink)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('live.end_confirm_body'.tr(),
                    style: const TextStyle(color: Canopy.slate)),
                const SizedBox(height: AppTheme.spaceSm),
                Text('live.end_confirm_background_note'.tr(),
                    style: const TextStyle(
                        color: Canopy.haze, fontSize: 12)),
              ],
            ),
            actions: [
              CaButton(
                  label: 'live.end_confirm_stay'.tr(),
                  variant: CaButtonVariant.text,
                  key: const Key('phone-end-stay'),
                  onPressed: () => Navigator.pop(dialogContext, false)),
              CaButton(
                  label: 'live.end_confirm_end'.tr(),
                  variant: CaButtonVariant.destructive,
                  key: const Key('phone-end-confirm-end'),
                  onPressed: () => Navigator.pop(dialogContext, true)),
            ],
          ),
        ) ??
        false;
    _endDialogOpen = false;
    return end;
  }

  /// The End control, the studio's End and the Back gesture all come here.
  Future<void> _handleEndOrLeave({bool holdConfirmed = false}) async {
    if (_closing || _endDialogOpen || _leavingAfterDisplacement) return;
    if (_isSending && !(context.isPhone && holdConfirmed)) {
      final end = await _askEnd();
      if (!end || !mounted || _closing || _leavingAfterDisplacement) return;
    }
    setState(() => _closing = true);
    var confirmed = true;
    // Only an end this screen asked the server for can fail to be confirmed;
    // a Leave with nothing listed makes no server call at all.
    final owned = _weStartedBroadcast || _ownsPreparedSession;
    try {
      await _stopBroadcast();
      // The camera has stopped either way. A failed end call leaves the
      // listing in place (the provider restores it), so say so instead of
      // implying the listing is gone.
      confirmed = !owned ||
          (_appProvider.publishingSession == null &&
              !_appProvider.isBroadcastingLive);
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
    final owned = _weStartedBroadcast || _ownsPreparedSession;
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
    if (mounted) setState(() {});
  }

  void _restorePortraitChrome() {
    _engine.setOrientation(0);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // YouTube's viewer figure is only shown here, so only the studio polls it
    // (and only for this broadcaster's own stream).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      provider.startStudioViewerPolling(
        provider.currentBroadcasterStreamer.streamerId,
      );
    });
  }

  @override
  void dispose() {
    if (_appProviderCaptured) {
      _appProvider.removeListener(_onBroadcastSessionChanged);
      _appProvider.stopStudioViewerPolling();
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
        SnackBar(content: Text('$e'), backgroundColor: Canopy.liveCrimson),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSending && !_closing && !_ownsPreparedSession,
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
    final isDesktop = isLaptopLiveLayout(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSideBySide = isDesktop || isLandscape;
    final streamer = _appProvider.currentBroadcasterStreamer;

    if (!_presetConfirmed) {
      return Scaffold(
        backgroundColor: Canopy.dawn,
        appBar: CaAppBar(
          backgroundColor: AppTheme.surface,
          title: Text('live.broadcast_from_phone'.tr()),
        ),
        body: _buildPresetPicker(),
      );
    }

    if (isLandscape && !isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.media,
        resizeToAvoidBottomInset: false,
        body: _buildFullscreenLandscapeLayout(title, streamer, langCode),
      );
    }

    if (context.isPhone &&
        mediaQuery.viewInsets.bottom == 0 &&
        _setupError == null) {
      return Scaffold(
          backgroundColor: Canopy.forestDeep,
          body: Stack(fit: StackFit.expand, children: [
            _buildVideoViewport(isSideBySide: true, streamer: streamer),
            if (_controlsVisible || mediaQuery.accessibleNavigation) ...[
              PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: SafeArea(
                      child: _glassHud(Row(children: [
                    IconButton(
                        onPressed: _handleEndOrLeave,
                        tooltip:
                            MaterialLocalizations.of(context).backButtonTooltip,
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Canopy.paper)),
                    Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Canopy.paper)),
                          if (!(_engine.state == RtmpPublishState.live &&
                              _appProvider.isBroadcastingLive))
                            Text('live.not_live'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: Canopy.mist)),
                        ])),
                    IconButton(
                        tooltip: 'live.tooltip_controls'.tr(),
                        icon: const Icon(Icons.more_vert_rounded,
                            color: Canopy.paper),
                        onPressed: () => _showStreamerControlsSheet(streamer)),
                  ])))),
              if (!_showingPreview)
              PositionedDirectional(
                  bottom: AppTheme.spaceMd,
                  start: AppTheme.spaceMd,
                  end: AppTheme.spaceMd,
                  child: SafeArea(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        _broadcastChatPreview(),
                        const SizedBox(height: AppTheme.spaceSm),
                        _glassHud(Row(children: [
                          IconButton(
                              tooltip: 'live.tooltip_toggle_chat'.tr(),
                              icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Canopy.paper),
                              onPressed: () => showCaSheet<void>(context,
                                  title: 'live.tab_chat'.tr(),
                                  framed: false,
                                  fullWidthOnPhone: true,
                                  edgeColor: Canopy.forestDeep,
                                  body: Builder(
                                      builder: (sheetContext) => SizedBox(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              CanopySize
                                                  .broadcastChatSheetFraction,
                                          child: _buildLiveChatTab(
                                              onClose: () =>
                                                  Navigator.pop(sheetContext)))))),
                          Expanded(child: _endControl()),
                        ])),
                      ]))),
            ],
            // The camera preview is private until the presenter goes live.
            if (_showingPreview)
              PositionedDirectional(
                  bottom: AppTheme.spaceMd,
                  start: AppTheme.spaceMd,
                  end: AppTheme.spaceMd,
                  child: SafeArea(
                      child: _glassHud(Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text('organization_v1.public_start_hint'.tr(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: Canopy.paper)),
                        const SizedBox(height: AppTheme.spaceSm),
                        _startControl(),
                      ])))),
          ]));
    }

    return Scaffold(
      backgroundColor: Canopy.dawn,
      resizeToAvoidBottomInset: true,
      appBar: CaAppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: Canopy.ink, size: 22),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _handleEndOrLeave,
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            if (mediaQuery.size.width >= CanopyWindow.medium) ...[
              CircleAvatar(
                radius: 17,
                backgroundColor: AppTheme.surface,
                backgroundImage: resolveImageProviderOrNull(streamer.avatarUrl),
              ),
              const SizedBox(width: 10),
            ],
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
                            color: Canopy.ink,
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
                          color: Canopy.liveCrimson.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Canopy.liveCrimson.withValues(alpha: 0.6),
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
                                color: Canopy.liveCrimson,
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
                                color: Canopy.liveCrimson,
                                fontSize: AppTheme.captionFont,
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
                            color: Canopy.slate,
                            fontSize: AppTheme.captionFont,
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
      ),
      body: SafeArea(
        child: _showingPreview
          ? Column(children: [
              Expanded(child: _buildVideoViewport(isSideBySide: true, streamer: streamer)),
              Padding(padding: const EdgeInsets.all(AppTheme.spaceSm),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('organization_v1.public_start_hint'.tr(), textAlign: TextAlign.center),
                  _startControl(),
                ])),
            ])
          : isSideBySide
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
                        Padding(
                          padding: const EdgeInsets.all(AppTheme.spaceSm),
                          child: _endControl(),
                        ),
                        _buildTitleAndDescriptionStrip(
                            title, description, streamer, langCode),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1, color: Canopy.hairline),
                  Expanded(
                    flex: isDesktop ? 35 : 42,
                    child: _buildCinemaTabPanel(langCode),
                  ),
                ],
              )
            : Column(
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    alignment: Alignment.topCenter,
                    child: _buildVideoViewport(
                        isSideBySide: false, streamer: streamer),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceLg,
                        vertical: AppTheme.spaceSm),
                    child: _endControl(),
                  ),
                  if (mediaQuery.viewInsets.bottom == 0)
                    _buildTitleAndDescriptionStrip(
                        title, description, streamer, langCode),
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
              style: const TextStyle(color: Canopy.liveCrimson),
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
              _audioBroadcastStage()
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
                  child: HadayahLoadingIndicator(color: Canopy.liveCrimson),
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
                        top: context.isPhone && !context.isLandscape
                            ? MediaQuery.textScalerOf(context)
                                    .scale(CanopySize.target) +
                                AppTheme.spaceLg +
                                MediaQuery.paddingOf(context).top
                            : AppTheme.spaceSm,
                        start: AppTheme.spaceSm,
                        child: _LiveBadge(bitrateBps: _engine.lastBitrateBps),
                      ),

                    if (_engine.state == RtmpPublishState.connecting)
                      PositionedDirectional(
                        top: context.isPhone && !context.isLandscape
                            ? MediaQuery.textScalerOf(context)
                                    .scale(CanopySize.target) +
                                AppTheme.spaceLg +
                                MediaQuery.paddingOf(context).top
                            : AppTheme.spaceSm,
                        start: AppTheme.spaceSm,
                        child: _StatusPill(
                            label: 'live.chat_status_connecting'.tr(),
                            color: AppTheme.warning),
                      ),

                    // Top Right: 3-Dots Streamer Controls Menu
                    if (!(context.isPhone &&
                        MediaQuery.viewInsetsOf(context).bottom == 0 &&
                        _setupError == null))
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
                            onPressed: () =>
                                _showStreamerControlsSheet(streamer),
                          ),
                        ),
                      ),

                    // Bottom Right: Fullscreen Button
                    // Mic Muted Pill
                    // Hidden while the audio-only poster shows: it would sit
                    // over the poster's button.
                    if (_engine.isMuted && !_engine.isCameraOff)
                      PositionedDirectional(
                        bottom: 60,
                        start: AppTheme.spaceSm,
                        child: _StatusPill(
                          label: 'live.mic_muted_badge'.tr(),
                          color: Canopy.liveCrimson,
                        ),
                      ),
                  ],
                ),
              ),
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

    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return SizedBox(width: double.infinity, height: 100, child: videoContent);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: videoContent,
    );
  }

  void _showStreamerControlsSheet(StreamerModel streamer) {
    showCaSheet<void>(
      context,
      title: 'live.tooltip_controls'.tr(),
      framed: false,
      fullWidthOnPhone: true,
      edgeColor: AppTheme.surface,
      body: Builder(builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isMuted = _engine.isMuted;
            final isCameraOff = _engine.isCameraOff;

            return Container(
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppTheme.radiusLg)),
                border: Border(
                  top: BorderSide(color: Canopy.hairlineStrong, width: 1),
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
                              color: Canopy.hairlineStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded,
                                color: Canopy.liveCrimson, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'design_ui.streamer_quick_controls'.tr(),
                                style: const TextStyle(
                                  color: Canopy.ink,
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
                              ? Canopy.liveCrimson.withValues(alpha: 0.15)
                              : Canopy.mint,
                          leading: Icon(
                            isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: isMuted ? Canopy.liveCrimson : Canopy.leaf,
                          ),
                          title: Text(
                            (isMuted ? 'live.ctrl_unmute' : 'live.ctrl_mute')
                                .tr(),
                            style: const TextStyle(
                                color: Canopy.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            (isMuted
                                    ? 'live.ctrl_mic_muted_sub'
                                    : 'live.ctrl_mic_active_sub')
                                .tr(),
                            style: const TextStyle(
                                color: Canopy.slate,
                                fontSize: AppTheme.captionFont),
                          ),
                          trailing: Switch(
                            value: !isMuted,
                            activeThumbColor: Canopy.leaf,
                            onChanged: (val) async {
                              await _engine.setMuted(!val);
                              if (context.mounted) setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                          onTap: () async {
                            await _engine.setMuted(!isMuted);
                            if (context.mounted) setModalState(() {});
                            if (mounted) setState(() {});
                          },
                        ),
                        const SizedBox(height: 8),

                        // Front camera is deferred; this action only explains it.
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          tileColor: Canopy.mint,
                          leading: const Icon(Icons.flip_camera_ios_rounded,
                              color: AppTheme.primary),
                          title: Text(
                            'live.front_camera_coming_soon'.tr(),
                            style: const TextStyle(
                                color: Canopy.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            'live.ctrl_back_active_sub'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate,
                                fontSize: AppTheme.captionFont),
                          ),
                          trailing: const Icon(Icons.info_outline_rounded,
                              color: Canopy.slate, size: 18),
                          onTap: () => showCaDialog<void>(
                            context: sheetContext,
                            builder: (context) => CaAlertDialog(
                              scrollable: true,
                              title: Text('live.front_camera_coming_soon'.tr()),
                              content: Text('live.ctrl_back_active_sub'.tr()),
                              actions: [
                                CaButton(
                                    label: 'common.close'.tr(),
                                    variant: CaButtonVariant.text,
                                    onPressed: () => Navigator.pop(context))
                              ],
                            ),
                          ),
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
                              : Canopy.mint,
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
                                color: Canopy.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            (isCameraOff
                                    ? 'live.ctrl_video_hidden_sub'
                                    : 'live.ctrl_video_shown_sub')
                                .tr(),
                            style: const TextStyle(
                                color: Canopy.slate,
                                fontSize: AppTheme.captionFont),
                          ),
                          trailing: Switch(
                            value: !isCameraOff,
                            activeThumbColor: AppTheme.primary,
                            onChanged: (val) async {
                              await _engine.toggleCamera(!val);
                              if (context.mounted) setModalState(() {});
                              if (mounted) setState(() {});
                            },
                          ),
                          onTap: () async {
                            await _engine.toggleCamera(!isCameraOff);
                            if (context.mounted) setModalState(() {});
                            if (mounted) setState(() {});
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
                            tileColor: Canopy.mint,
                            leading: const Icon(Icons.people_alt_rounded,
                                color: AppTheme.warning),
                            title: Text(
                              'live.ctrl_manage_attendees'.tr(args: [
                                '${_appProvider.admittedAttendees.length}'
                              ]),
                              style: const TextStyle(
                                  color: Canopy.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5),
                            ),
                            subtitle: Text(
                              'live.ctrl_waiting_queue'.tr(args: [
                                '${_appProvider.pendingKnockRequests.length}'
                              ]),
                              style: const TextStyle(
                                  color: Canopy.slate,
                                  fontSize: AppTheme.captionFont),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: Canopy.slate),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _showDirectorPanel(context, _appProvider);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],

                        // 5.  Language (moved here from the live HUD)
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          tileColor: Canopy.mint,
                          leading: SvgPicture.asset('assets/Language.svg',
                              width: 22,
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                  AppTheme.primary, BlendMode.srcIn)),
                          title: Text(
                            'language.switch_lang'.tr(),
                            style: const TextStyle(
                                color: Canopy.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            (context.locale.languageCode == 'ar'
                                    ? 'language.en'
                                    : 'language.ar')
                                .tr(),
                            style: const TextStyle(
                                color: Canopy.slate,
                                fontSize: AppTheme.captionFont),
                          ),
                          trailing: const Icon(Icons.swap_horiz_rounded,
                              color: Canopy.slate),
                          onTap: () async {
                            await LanguageSwitcher.toggle(context);
                            if (context.mounted) setModalState(() {});
                          },
                        ),
                        const SizedBox(height: 8),

                        // 6.  End the broadcast (the studio is not needed live)
                        ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                          tileColor: Canopy.liveCrimson.withValues(alpha: 0.1),
                          leading: const Icon(Icons.stop_circle_outlined,
                              color: Canopy.liveCrimson),
                          title: Text(
                            'live.end_broadcast'.tr(),
                            style: const TextStyle(
                                color: Canopy.liveCrimson,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5),
                          ),
                          subtitle: Text(
                            'live.ctrl_end_sub'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate,
                                fontSize: AppTheme.captionFont),
                          ),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _handleEndOrLeave();
                          },
                        ),
                      ],
                    ),
                  )),
            );
          },
        );
      }),
    );
  }

  Widget _startControl() => CaButton(
        key: const Key('phone-start-broadcast'),
        label: 'organization_v1.go_live'.tr(),
        icon: CaGlyph.video,
        loading: _starting,
        onPressed: _canStartPreview ? _startBroadcast : null,
      );

  /// Revealed with the landscape controls; Back keeps the same confirmation.
  /// While nothing is sending it reads "Leave" and closes without asking.
  Widget _endControl() {
    final sending = _isSending;
    if (context.isPhone) {
      return CaButton(
          key: const Key('phone-end-broadcast'),
          label: (_closing
                  ? 'live.ending'
                  : sending
                      ? 'live.hold_to_end'
                      : 'live.leave_screen')
              .tr(),
          variant:
              sending ? CaButtonVariant.destructive : CaButtonVariant.secondary,
          holdToConfirm: sending,
          loading: _closing,
          onPressed:
              _closing ? null : () => _handleEndOrLeave(holdConfirmed: true));
    }
    return FilledButton.icon(
      key: const Key('phone-end-broadcast'),
      onPressed: _closing ? null : _handleEndOrLeave,
      icon: _closing
          ? const SizedBox(
              width: 16,
              height: 16,
              child: HadayahLoadingIndicator(
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
        backgroundColor: sending ? Canopy.liveCrimson : Canopy.mint,
        foregroundColor: sending ? AppTheme.onPrimary : Canopy.ink,
        // "Ending..." keeps the danger colour and stays readable.
        disabledBackgroundColor: Canopy.liveCrimson.withValues(alpha: 0.75),
        disabledForegroundColor: AppTheme.onPrimary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
    );
  }

  Widget _glassHud(Widget child) => Container(
      decoration: BoxDecoration(
          color: Canopy.broadcastGlass,
          borderRadius: BorderRadius.circular(CanopyRadius.input),
          border: Border.all(color: Canopy.cinemaBubble)),
      padding: const EdgeInsets.all(AppTheme.spaceXs),
      child: child);

  Widget _broadcastChatPreview() {
    final messages =
        _chatController.messages.reversed.take(3).toList().reversed.toList();
    if (messages.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height *
                CanopySize.broadcastChatPreviewFraction),
        child: _glassHud(SingleChildScrollView(
            reverse: true,
            child: Column(
                key: const Key('broadcast-last-three'),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final message in messages)
                    Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceSm),
                        child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                  text: '\u2068${message.senderName}\u2069  ',
                                  style: const TextStyle(
                                      color: Canopy.mist,
                                      fontWeight: FontWeight.bold)),
                              TextSpan(text: message.body),
                            ]),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Canopy.paper))),
                ]))));
  }

  Widget _audioBroadcastStage() {
    final level = _engine.lastMicRms;
    return ColoredBox(
        color: Canopy.forestDeep,
        child: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spaceXl),
                child: Container(
                    constraints: const BoxConstraints(
                        maxWidth: CanopySize.dialogCompactMax),
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    decoration: BoxDecoration(
                        color: Canopy.paper,
                        borderRadius: BorderRadius.circular(CanopyRadius.card)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.mic_rounded, color: Canopy.brandGreen),
                      const SizedBox(height: AppTheme.spaceSm),
                      Text('live_studio.audio_only_title'.tr(),
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppTheme.spaceMd),
                      CaLevelMeter(
                          key: const Key('broadcast-audio-meter'),
                          level: level ?? 0,
                          label: level == null
                              ? 'live.audio_level_unavailable'.tr()
                              : 'ds.audio_level'.tr()),
                      const SizedBox(height: AppTheme.spaceSm),
                      Text(
                          level == null
                              ? 'live.audio_level_unavailable'.tr()
                              : 'ds.audio_level'.tr(),
                          style: Theme.of(context).textTheme.bodySmall),
                    ])))));
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
          bottom: BorderSide(color: Canopy.hairline, width: 1),
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
                  color: Canopy.slate,
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
                    color: Canopy.mint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: Canopy.hairline),
                  ),
                  child: Text(
                    categoryModel.getLocalizedName(langCode),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: AppTheme.captionFont,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Canopy.mint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: Canopy.hairline),
                ),
                child: Text(
                  _presetCompactLabel,
                  style: const TextStyle(
                    color: Canopy.slate,
                    fontSize: AppTheme.captionFont,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.remove_red_eye_rounded,
                  size: 14, color: Canopy.leaf),
              const SizedBox(width: 4),
              // YouTube's concurrent-viewer figure, labelled as YouTube's and
              // never merged with this platform's presence count (P3).
              Text(
                '${_appProvider.youTubeConcurrentViewers(streamer.streamerId) ?? '—'} on YouTube',
                style: const TextStyle(
                  color: Canopy.slate,
                  fontSize: AppTheme.captionFont,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Row 3: Expanded Description & Organization (when expanded)
          if (_isDescriptionExpanded) ...[
            const SizedBox(height: 10),
            const Divider(color: Canopy.hairline, height: 1),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty ? description : 'No description provided.',
              style: const TextStyle(
                color: Canopy.ink,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.account_balance_rounded,
                    size: 13, color: Canopy.haze),
                const SizedBox(width: 4),
                Text(
                  streamer.getLocalizedOrganization(langCode),
                  style: const TextStyle(
                    color: Canopy.slate,
                    fontSize: AppTheme.captionFont,
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
      color: Canopy.dawn,
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
                top: BorderSide(color: Canopy.hairline, width: 0.8),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Canopy.liveCrimson,
              labelColor: Canopy.liveCrimson,
              unselectedLabelColor: Canopy.haze,
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
                                  fontSize: AppTheme.captionFont,
                                  fontWeight: FontWeight.bold))),
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
                                  fontSize: AppTheme.captionFont,
                                  fontWeight: FontWeight.bold))),
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
                                  fontSize: AppTheme.captionFont,
                                  fontWeight: FontWeight.bold))),
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

  Widget _buildLiveChatTab({VoidCallback? onClose}) {
    return ListenableBuilder(
      listenable: _chatController,
      builder: (context, _) {
        // Real messages only: an empty room stays empty (05 D-03).
        final messages = _chatController.messages;

        return LiveChatWidget(
          cinema: context.isPhone,
          onClose: onClose,
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
      color: Canopy.dawn,
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'live.slides_attached_title'.tr(),
            style: const TextStyle(
              color: Canopy.ink,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'live.slides_attached_subtitle'.tr(),
            style: const TextStyle(color: Canopy.slate, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: Canopy.hairline),
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
                      color: Canopy.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'design_ui.presentation_deck_pdf_attached'.tr(),
                    style: const TextStyle(
                        color: Canopy.haze,
                        fontSize: AppTheme.captionFont),
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
                  color: Canopy.ink,
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
              border: Border.all(color: Canopy.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueInfo.getLocalizedAddress(langCode),
                  style: const TextStyle(
                      color: Canopy.ink, fontSize: 12.5),
                ),
                const Divider(color: Canopy.hairline, height: 16),
                Text(
                  'Hall: ${venueInfo.getLocalizedAuditorium(langCode)}',
                  style: const TextStyle(
                      color: Canopy.slate, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gate: ${venueInfo.getLocalizedGate(langCode)}',
                  style: const TextStyle(
                      color: Canopy.slate, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Capacity: ${venueInfo.seatingCapacity} Seats',
                  style: const TextStyle(color: Canopy.leaf, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLandscapeControls() {
    if (MediaQuery.of(context).accessibleNavigation) return;
    setState(() => _controlsVisible = !_controlsVisible);
  }

  Widget _buildFullscreenLandscapeLayout(
      String title, StreamerModel streamer, String langCode) {
    final hudInset = MediaQuery.textScalerOf(context)
            .scale(CanopySize.target)
            .clamp(CanopySize.target, double.infinity) +
        AppTheme.spaceLg;
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
            _audioBroadcastStage()
          else
            PhoneCameraPreview(key: _previewKey),
          FloatingReactionsOverlay(controller: _reactionsController),
          PositionedDirectional(
              top: 64, start: 8, end: 8, child: _recoveryStatus()),
          if (visible)
            SafeArea(
                child: Focus(
              focusNode: _controlsFocus,
              canRequestFocus: false,
              child: Stack(children: [
                PositionedDirectional(
                  top: AppTheme.spaceSm,
                  start: AppTheme.spaceSm,
                  end: AppTheme.spaceSm,
                  child: _glassHud(Row(children: [
                    Expanded(
                        child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _endControl())),
                    const SizedBox(width: AppTheme.spaceSm),
                    if (_canStartPreview) Tooltip(
                      message: 'organization_v1.public_start_hint'.tr(),
                      child: _startControl(),
                    ),
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
                  ])),
                ),
              ]),
            )),
          if (visible && !_isSideChatOpen)
            PositionedDirectional(
                bottom: AppTheme.spaceSm,
                start: AppTheme.spaceSm,
                end: AppTheme.spaceSm,
                child: SafeArea(child: _broadcastChatPreview())),
          if (visible && _isSideChatOpen)
            PositionedDirectional(
              top: hudInset,
              bottom: MediaQuery.paddingOf(context).bottom + AppTheme.spaceSm,
              end: (Directionality.of(context) == TextDirection.rtl
                      ? MediaQuery.paddingOf(context).left
                      : MediaQuery.paddingOf(context).right) +
                  AppTheme.spaceSm,
              width: MediaQuery.sizeOf(context).width * 0.42,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                        reverse: true,
                        child: SizedBox(
                            height: constraints.maxHeight.clamp(
                                MediaQuery.textScalerOf(context).scale(
                                    CanopySize.broadcastReadOnlyChatFloor),
                                double.infinity),
                            child: _buildLiveChatTab()))),
              ),
            ),
        ]),
      ),
    );
  }

  void _showDirectorPanel(BuildContext context, AppProvider provider) {
    final handleController = TextEditingController();
    showCaSheet<void>(context,
        title: 'live.tab_chat'.tr(),
        framed: false,
        body: ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: Builder(
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
                            'live.attendees_count'.tr(
                                args: ['${provider.admittedAttendees.length}']),
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
                                child: PhoneInputGuard(builder: (context, blocked) => TextField(
                                          readOnly: blocked,
                                          controller: handleController,
                                          style: const TextStyle(
                                              color: AppTheme.onMedia,
                                              fontSize: 13),
                                          decoration: InputDecoration(
                                            hintText:
                                                'live.attendee_search_hint'
                                                    .tr(),
                                            hintStyle: const TextStyle(
                                                color: Canopy.haze,
                                                fontSize: 12),
                                            filled: true,
                                            fillColor: Canopy.mint,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 10),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppTheme.radiusSm),
                                              borderSide: const BorderSide(
                                                  color: Canopy.hairline),
                                            ),
                                          ),
                                          onSubmitted: (value) {
                                            if (value.trim().isEmpty) return;
                                            provider.admitAttendeeByHandle(
                                                value.trim());
                                            handleController.clear();
                                          },
                                        )),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.person_add_alt_1_rounded,
                                    color: Canopy.leaf),
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
                                      'design_ui.no_attendees_admitted_yet'
                                          .tr(),
                                      style: const TextStyle(
                                          color: Canopy.haze,
                                          fontSize: 12),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount:
                                        provider.admittedAttendees.length,
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
                                                color: Canopy.slate,
                                                size: 20),
                                        title: Text(
                                          attendee.displayName,
                                          style: const TextStyle(
                                              color: AppTheme.onMedia,
                                              fontSize: 13),
                                        ),
                                        trailing: TextButton.icon(
                                          icon: const Icon(Icons.block_rounded,
                                              color: Canopy.liveCrimson, size: 16),
                                          label: Text(
                                            'design_ui.kick_out'.tr(),
                                            style: const TextStyle(
                                                color: Canopy.liveCrimson,
                                                fontSize: 12),
                                          ),
                                          onPressed: () => provider
                                              .kickAttendee(attendee.id),
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
            ))).whenComplete(handleController.dispose);
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
                  color: Canopy.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              'design_copy.quality_help'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Canopy.slate, fontSize: 12.5),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            CaQualityPresets<BroadcastQualityPreset>(
                options: [
                  for (final preset in BroadcastQualityPreset.values)
                    (
                      value: preset,
                      label: '${preset.height}p',
                      detail: '${preset.videoBitrateBps ~/ 1000} kbps'
                    )
                ],
                value: _preset,
                onChanged: (preset) => setState(() => _preset = preset)),
            const SizedBox(height: AppTheme.spaceMd),
            SizedBox(
              width: double.infinity,
              child: CaButton(
                  label: 'design_ui.continue'.tr(),
                  onPressed: _confirmPresetAndSetup),
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
      color: Canopy.liveCrimson,
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
      color: Canopy.liveCrimson,
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
                  style: const TextStyle(
                      color: Canopy.leaf, fontSize: AppTheme.captionFont)),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: Canopy.liveCrimson, size: 20),
            tooltip: 'live.tooltip_deny'.tr(),
            onPressed: onDeny,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded,
                color: Canopy.leaf, size: 20),
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
            color: AppTheme.onMedia,
            fontSize: AppTheme.captionFont,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}
