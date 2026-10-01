import 'package:flutter/foundation.dart' show ValueListenable, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../../core/config/feature_flags.dart';
import '../models/chat_message_model.dart';
import '../services/live_chat_controller.dart';
import '../services/viewer_presence_service.dart';
import '../../../core/layout/content_width.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/streamer_avatar.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../../map/presentation/widgets/venue_navigation_sheet.dart';
import '../../map/presentation/venue_directions_launcher.dart';
import 'abstract_video_player.dart';
import 'widgets/chat_message_actions_sheet.dart';
import 'widgets/live_chat_layout.dart';
import 'widgets/live_audio_stage_multi_speaker.dart';
import 'widgets/floating_reactions_overlay.dart';
import 'widgets/live_player_overlay_controls.dart';
import 'widgets/live_multi_speaker_overlay.dart';
import 'widgets/private_stream_viewer_gate.dart';
import 'widgets/stream_state_placeholder_overlay.dart';
import 'widgets/live_room_connection_view.dart';
import '../../../core/services/connectivity_service.dart';
import '../../admin/models/streamer_custom_placeholder_model.dart';
import 'widgets/rtmp_ip_dialog.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';

class LiveBroadcastScreen extends StatefulWidget {
  final String streamId;

  const LiveBroadcastScreen({super.key, required this.streamId});

  @visibleForTesting
  static LiveChatController Function(String, void Function(String))?
      debugChatFactory;
  @visibleForTesting
  static ViewerPresenceService Function(String)? debugPresenceFactory;

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen>
    with SingleTickerProviderStateMixin {
  final FloatingReactionsOverlayController _reactionsController =
      FloatingReactionsOverlayController();
  final TextEditingController _chatTextController = TextEditingController();
  final FocusNode _chatFocus = FocusNode(debugLabel: 'viewer-chat');
  final ScrollController _chatScrollController = ScrollController();
  late LiveChatController _chatController;

  late TabController _tabController;
  // Fixed to the YouTube embed engine (ADR-002). The overlay's selector no
  // longer switches engines -- as of Cluster 1 Task 2 it picks a *resolution*
  // (StreamQualityLevel), which is what its "1080p/720p/480p"labels always
  // claimed to do.
  final StreamSourceType _sourceType = StreamSourceType.youtubeEmbed;
  StreamState _streamState = StreamState.live;
  bool _isPlaying = true;
  final _overlayKey = GlobalKey<LivePlayerOverlayControlsState>();
  Offset? _mediaPointerDown;
  bool _isMuted = false;

  /// One player instance per watch identity. A GlobalKey keeps the same
  /// player (and its web view) when the viewport moves between the portrait
  /// column, the side-by-side row and fullscreen, so rotating or entering
  /// fullscreen does not restart the video. A new identity (another watch
  /// ID, a provider reload, or Retry) gets a fresh key and a fresh player.
  GlobalKey _playerKey = GlobalKey(debugLabel: 'room-player');
  String? _playerIdentity;
  int _playerReloads = 0;

  /// Whether the current player can take play/pause/mute commands; the
  /// buttons are shown only then (otherwise the player's own controls are
  /// the transport). Known once the player is built.
  bool _transportAvailable = false;

  /// A play/pause/mute command is on its way; further taps wait for it.
  bool _commandInFlight = false;
  bool _isFullscreen = false;
  bool _isHandRaised = false;
  bool _isReactionMenuOpen = false;
  StreamQualityLevel _selectedQuality = StreamQualityLevel.auto;
  late ViewerPresenceService _presenceService;
  AppProvider? _roomProvider;
  bool _roomActive = false;
  int? _requiredCatalogRevision;
  int _roomGeneration = 0;
  Timer? _recoveryTimer;
  Timer? _recoveryDeadline;
  Timer? _recoveryStable;
  DateTime? _recoveryUntil;
  int _recoveryEpoch = 0;
  int _recoveryAttempts = 0;
  bool _recovering = false;
  bool _recoveryExhausted = false;
  bool _playIntent = true;

  void _cancelViewerRecovery() {
    _recoveryEpoch++;
    _recoveryTimer?.cancel();
    _recoveryDeadline?.cancel();
    _recoveryStable?.cancel();
    _recoveryStable = null;
    _recoveryTimer = null;
    _recovering = false;
  }

  void _exhaustViewerRecovery() {
    _cancelViewerRecovery();
    _stopRoom();
    if (mounted && !_roomEnded) {
      setState(() {
        _recoveryExhausted = true;
        _streamState = StreamState.fallbackError;
      });
    }
  }

  void _beginViewerRecovery() {
    if (!_openedLive || _roomEnded || _recoveryExhausted || !mounted) return;
    _recoveryStable?.cancel();
    _recoveryStable = null;
    if (!_recovering) {
      _recovering = true;
      _recoveryAttempts = 0;
      _recoveryUntil = DateTime.now().add(const Duration(seconds: 60));
      _recoveryDeadline =
          Timer(const Duration(seconds: 60), _exhaustViewerRecovery);
    }
    _scheduleViewerRecovery();
  }

  void _scheduleViewerRecovery() {
    if (!_recovering || _recoveryTimer != null) return;
    if (_recoveryAttempts >= 10) {
      _exhaustViewerRecovery();
      return;
    }
    final epoch = _recoveryEpoch;
    _recoveryTimer = Timer(const Duration(seconds: 3), () async {
      final provider = _roomProvider;
      if (!mounted || !_recovering || provider == null) return;
      if (DateTime.now().isAfter(_recoveryUntil!)) {
        _exhaustViewerRecovery();
        return;
      }
      if (!provider.isOnline) {
        _recoveryTimer = null;
        _scheduleViewerRecovery();
        return;
      }
      final revision = provider.roomRevision(widget.streamId);
      _recoveryAttempts++;
      try {
        await provider
            .loadVerifiedStreamersFromBackend()
            .timeout(const Duration(seconds: 7));
      } catch (_) {/* no fresh truth: never reload blindly */}
      if (!mounted || epoch != _recoveryEpoch || _roomEnded) return;
      _recoveryTimer = null;
      if (DateTime.now().isAfter(_recoveryUntil!)) {
        _exhaustViewerRecovery();
        return;
      }
      _syncRoomConnection();
      if (_roomEnded || !_recovering) return;
      if (provider.isOnline &&
          provider.roomRevision(widget.streamId) > revision &&
          _roomActive) {
        setState(() {
          _playerReloads++;
          _streamState = StreamState.initializing;
          // Chrome's native iframe controls have no confirmed state bridge.
          // Recovery there requires a native Play tap, never unsolicited audio.
          if (kIsWeb) {
            _playIntent = false;
            _isMuted = true;
          }
        });
        // Allow the provider handshake its full 10 seconds before another
        // attempt. An explicit failure schedules the next attempt after 3s.
        _recoveryTimer = Timer(const Duration(seconds: 10), () {
          _recoveryTimer = null;
          _scheduleViewerRecovery();
        });
      } else {
        _scheduleViewerRecovery();
      }
    });
  }

  // What this room was opened for. A room opened on a live broadcast plays
  // that exact watch ID; once fresh catalog data says the broadcast ended (or
  // a different broadcast replaced it) the room closes instead of leaving a
  // player and a LIVE badge running (P6S wave 3, stale LIVE after transfer).
  bool _openedLive = false;
  String? _openedWatchId;
  String? _openedSessionId;
  String? _openedStreamerId;
  int _openedCatalogRevision = 0;
  bool _roomEnded = false;
  Timer? _liveStateTimer;
  Timer? _lookupTimer;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Chat, Sources, Venue
    _tabController = TabController(length: 3, vsync: this);
    _chatScrollController.addListener(_handleChatScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (isCompactLandscapeChat(context)) {
      _chatFocus.unfocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    }
    final provider = context.read<AppProvider>();
    if (identical(provider, _roomProvider)) return;
    _roomProvider?.removeListener(_syncRoomConnection);
    _roomProvider = provider..addListener(_syncRoomConnection);
    _syncRoomConnection();
    WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(widget.streamId)) _refreshRoom(); });
  }

  Future<void> _refreshRoom() async {
    final p=_roomProvider;
    if(p==null || !p.isOnline)return;
    if(RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(widget.streamId)) {
      try {await p.refreshBroadcastRoom(widget.streamId);} catch(_) {}
    }
    await p.loadVerifiedStreamersFromBackend();
  }

  void _syncRoomConnection() {
    final provider = _roomProvider;
    if (provider == null) return;
    final session=provider.roomSession(widget.streamId);
    if(session!=null && !session.live) {
      if(session.replayStatus!='available') {
        _stopRoom();
        _liveStateTimer?.cancel();_liveStateTimer=null;
        _scheduleLookup();
        return;
      }
      if(_openedLive || _roomEnded) {
        _stopRoom();_roomEnded=false;_openedLive=false;
        _openedWatchId=null;_openedSessionId=null;_requiredCatalogRevision=null;
        _playerReloads++;
      }
    }
    if (_roomEnded) return;
    if (!provider.isOnline) {
      _beginViewerRecovery();
      _requiredCatalogRevision ??= provider.roomRevision(widget.streamId);
      _stopRoom();
      return;
    }
    final current = _findStreamer(provider);
    final fresh = provider.roomRevision(widget.streamId) >
        (_requiredCatalogRevision ?? _openedCatalogRevision);
    // A network interruption disposes media, not the identity of this room.
    // Reconcile End before requiring a live catalog entry for recovery.
    if (_openedLive &&
        fresh &&
        (current == null ||
            !current.isLiveForRoom ||
            current.liveWatchId != _openedWatchId ||
            (_openedSessionId != null &&
                current.liveSessionId != _openedSessionId))) {
      _endRoom();
      return;
    }
    if (_requiredCatalogRevision case final revision?) {
      if (provider.roomRevision(widget.streamId) <= revision) {
        _stopRoom();
        return;
      }
      final confirmedLive = current?.isLiveForRoom == true || provider.streamers.any((s) =>
          s.isLiveForRoom &&
          (s.streamerId == widget.streamId ||
              s.activeStreamId == widget.streamId ||
              s.youtubeVideoId == widget.streamId));
      if (!confirmedLive) {
        _stopRoom();
        return;
      }
      _requiredCatalogRevision = null;
    }
    if (_recoveryExhausted) return;
    if (current == null && !_roomActive) {
      // Nothing to join yet (or at all): no chat or presence for a room that
      // names no known channel. Keep looking, since a link opened right after
      // go-live can arrive before this device's catalog has the broadcast.
      _scheduleLookup();
      return;
    }
    _lookupTimer?.cancel();
    _lookupTimer = null;
    if (!_openedLive && current?.isLiveForRoom == true) {
      _openedLive = true;
      _openedStreamerId = current!.streamerId;
      _openedWatchId = current.liveWatchId;
      _openedSessionId = current.liveSessionId;
      _openedCatalogRevision = provider.roomRevision(widget.streamId);
    }
    _startRoom();
  }

  // Looking for a room's channel backs off 10, 20, 40 then every 60 s.
  Duration _lookupDelay = const Duration(seconds: 10);

  void _scheduleLookup() {
    if (_lookupTimer != null) return;
    _lookupTimer = Timer(_lookupDelay, () {
      _lookupTimer = null;
      final next = _lookupDelay * 2;
      _lookupDelay = next > const Duration(seconds: 60)
          ? const Duration(seconds: 60)
          : next;
      final p = _roomProvider;
      if (p != null && p.isOnline) {
        unawaited(_refreshRoom());
      }
      if (mounted && p != null && _findStreamer(p) == null) _scheduleLookup();
    });
  }

  /// The broadcast this room was opened for is over. Stops chat, presence
  /// and the player; the viewer gets an explicit ended state with a way back.
  void _endRoom() {
    _roomEnded = true;
    _cancelViewerRecovery();
    _liveStateTimer?.cancel();
    _liveStateTimer=null;
    _stopRoom();
    if (mounted) setState(() {});
  }

  void _startRoom() {
    if (_roomActive) return;
    _roomActive = true;
    _roomGeneration++;
    _streamState = StreamState.initializing;
    final provider = _roomProvider;
    final opened = provider == null ? null : _findStreamer(provider);
    _openedStreamerId ??= opened?.streamerId;
    // Viewers get no Realtime event when another account's broadcast ends,
    // so the room re-reads the catalog itself; an ended broadcast closes the
    // room within about 20 seconds.
    _liveStateTimer ??= Timer.periodic(const Duration(seconds: 20), (_) {
      final p = _roomProvider;
      if (p != null && p.isOnline) {
        unawaited(_refreshRoom());
      }
    });
    final roomId=opened?.liveSessionId ?? widget.streamId;
    _chatController = LiveBroadcastScreen.debugChatFactory?.call(
            roomId,
            (type) => _reactionsController.spawnReaction(type)) ??
        LiveChatController(
          streamId: roomId,
          onReaction: (type) => _reactionsController.spawnReaction(type),
        );
    _chatController.addListener(_handleChatConnectionChange);
    _presenceService =
        LiveBroadcastScreen.debugPresenceFactory?.call(roomId) ??
            ViewerPresenceService(streamId: roomId);
    _presenceService.addListener(_onPresenceChanged);
    final generation = _roomGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_roomActive || generation != _roomGeneration) return;
      unawaited(_chatController.start());
      unawaited(_presenceService.start());
    });
    _setWakelock(true);
  }

  void _stopRoom() {
    if (!_roomActive) return;
    _roomActive = false;
    _roomGeneration++;
    _streamState = StreamState.offline;
    _setWakelock(false);
    _chatController.removeListener(_handleChatConnectionChange);
    _chatController.dispose();
    _presenceService.removeListener(_onPresenceChanged);
    _presenceService.dispose();
  }

  void _onPresenceChanged() {
    if (mounted) setState(() {});
  }

  /// Cluster 1 Task 1 -- the audio-dropping fix. When the screen dims and
  /// the OS suspends, Android throttles the WebView hosting the YouTube
  /// embed and the audio track dies with it; holding a wakelock for the
  /// lifetime of this screen is what keeps a lecture playing while the
  /// viewer is not touching the phone.
  ///
  /// Best-effort by design: wakelock_plus has no implementation on some
  /// desktop/test targets, and failing to hold a wakelock must never take
  /// the broadcast screen down with it.
  void _setWakelock(bool enable) {
    try {
      final future = enable ? WakelockPlus.enable() : WakelockPlus.disable();
      future.catchError((Object e) {
        debugPrint('[LiveBroadcastScreen] wakelock unavailable: $e');
      });
    } catch (e) {
      debugPrint('[LiveBroadcastScreen] wakelock unavailable: $e');
    }
  }

  @override
  void dispose() {
    _cancelViewerRecovery();
    _liveStateTimer?.cancel();
    _mutedSource?.removeListener(_onPlayerMutedChanged);
    _lookupTimer?.cancel();
    _roomProvider?.removeListener(_syncRoomConnection);
    _stopRoom();
    // Always restore portrait + the normal system chrome, even if the user
    // backed out of the room while still in fullscreen landscape -- leaving
    // the app locked to landscape after this screen is gone would strand
    // every other screen sideways.
    _restorePortraitChrome();
    _tabController.dispose();
    _chatTextController.dispose();
    _chatFocus.dispose();
    _chatScrollController.removeListener(_handleChatScroll);
    _chatScrollController.dispose();
    super.dispose();
  }

  void _restorePortraitChrome() {
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  /// Cluster 1 Task 3 -- the expand button is a *viewport* control, not just
  /// a layout toggle: it rotates the device into landscape and hides the
  /// system bars, then puts both back on exit.
  void _handleToggleFullscreen() {
    final entering = !_isFullscreen;
    setState(() => _isFullscreen = entering);

    if (entering) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // One-way exit action: unlock orientation freedom rather than violently
      // forcing the physical device back into portrait.
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Leave the room with a shortcut back ("Return to broadcast") and drop
  /// back to whichever tab (Feed or Map) the viewer came from. The room's
  /// player is owned by this screen, so playback stops here; the shortcut
  /// only reopens the room (P6S G5). It used to be described as a mini-player
  /// that kept the audio going, which it never did.
  void _minimizeToMiniPlayer(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    appProvider.openMiniPlayer(
      videoId: _getStreamUrl(streamer),
      title: streamer.getLocalizedTitle(langCode),
      streamerName: streamer.getLocalizedName(langCode),
      streamId: widget.streamId,
      isAudioOnly: streamer.isAudioLive,
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// Keeps the chat tab in step with the Realtime connection: a drop shows
  /// the "chat unavailable"banner over the real (possibly empty) message
  /// list. It used to swap in simulated comments instead (05 D-03).
  void _handleChatConnectionChange() {
    if (!mounted) return;
    _trackChatArrivals();
    setState(() {});
  }

  void _handleSendLocalMessage() {
    final text = _chatTextController.text.trim();
    if (text.isEmpty) return;

    // The composer already renders a reason and disables Send for every
    // blocked state (P6.2), so reaching here without canSend would be a bug --
    // guard anyway rather than posting into a refusal.
    if (!_chatController.canSend || _roomProvider?.roomSession(widget.streamId)?.live==false) return;
    _chatTextController.clear();

    _chatController.sendMessage(text).then((_) {
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

  void _handleQuickReaction(String reactionType, String emoji) {
    // Shown immediately/locally rather than waiting on the broadcast round
    // trip; other viewers see it via LiveChatController.onReaction above.
    _reactionsController.spawnReaction(reactionType);
    _chatController.sendReaction(reactionType);
    setState(() => _isReactionMenuOpen = false);
  }

  Future<void> _toggleRaiseHand() async {
    final raising = !_isHandRaised;
    setState(() => _isHandRaised = raising);
    try {
      // A chat row gives the hand an authenticated sender and reaches people
      // who join after the transient reaction has passed.
      await _chatController.sendMessage(raising ? '✋' : '✋↓');
      if (raising) {
        _reactionsController.spawnReaction('raise_hand');
        _chatController.sendReaction('raise_hand');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isHandRaised = !raising);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppTheme.danger),
      );
    }
  }

  /// The channel this room belongs to, or null. Never another streamer: the
  /// room used to fall back to the "active" or first catalog entry, which
  /// could put a stranger's broadcast behind this room's chat and title.
  StreamerModel? _findStreamer(AppProvider appProvider) {
    final opened = _openedStreamerId;
    return appProvider.getRoomStreamer(opened ?? widget.streamId);
  }

  /// Which of the three streamer-brandable states (Task 4b) the current
  /// [_streamState] maps to, or null for the failure states -- a custom card
  /// must never paper over "offline"or "playback failed", since hiding a
  /// real fault behind branded artwork is worse than the plain default.
  StreamPlaceholderType? get _brandablePlaceholderType {
    switch (_streamState) {
      case StreamState.startingSoon:
        return StreamPlaceholderType.startingSoon;
      case StreamState.paused:
        return StreamPlaceholderType.intermission;
      case StreamState.ended:
        return StreamPlaceholderType.ending;
      case StreamState.initializing:
      case StreamState.unconfirmed:
      case StreamState.live:
      case StreamState.buffering:
      case StreamState.reconnecting:
      case StreamState.offline:
      case StreamState.noAudioToken:
      case StreamState.fallbackError:
        return null;
    }
  }

  /// The streamer's approved artwork for the state on screen, or null to let
  /// StreamStatePlaceholderOverlay use the default system placeholder.
  /// Nothing is shown until an admin has approved it -- pending and rejected
  /// cards are not even readable by a viewer at the RLS layer.
  String? _customPlaceholderUrl(
      AppProvider appProvider, StreamerModel streamer) {
    final type = _brandablePlaceholderType;
    if (type == null) return null;
    final url =
        appProvider.approvedPlaceholderImageUrl(streamer.streamerId, type);
    if (url == null) {
      // Fire-and-forget: populates the cache and notifies, so the next build
      // paints the custom card. Deferred past this build to avoid mutating
      // provider state mid-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        appProvider.ensureApprovedPlaceholderLoaded(streamer.streamerId, type);
      });
    }
    return url;
  }

  /// Retry reloads the player; it used to only change the label.
  void _retryStream() {
    if (_roomEnded) return;
    _cancelViewerRecovery();
    setState(() => _recoveryExhausted = false);
    if (_openedLive) {
      _beginViewerRecovery();
    } else {
      setState(() {
        _playerReloads++;
        _streamState = StreamState.initializing;
      });
    }
  }

  PlayerTransport? get _transport {
    final state = _playerKey.currentState;
    if (state is PlayerTransport) {
      final transport = state as PlayerTransport;
      if (transport.supportsCommands) return transport;
    }
    return null;
  }

  void _explainNoTransport() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('live.player_controls_use_youtube'.tr())),
    );
  }

  /// Sends play or pause to the player, and shows the new state only once
  /// the command went through.
  Future<void> _togglePlayPause() async {
    if (_commandInFlight) return;
    final transport = _transport;
    if (transport == null) return _explainNoTransport();
    final key = _playerKey;
    final playing = _isPlaying;
    _commandInFlight = true;
    try {
      final sent = playing ? await transport.pause() : await transport.play();
      // A Retry or reload replaced the player meanwhile: this answer is
      // about a player that no longer exists.
      if (!mounted || key != _playerKey) return;
      if (!sent) return _explainNotReady();
      _playIntent = !playing;
      // Delivery is not playback confirmation. The player's state callback
      // updates the icon, including when autoplay is blocked.
    } finally {
      _commandInFlight = false;
    }
  }

  Future<void> _toggleMute() async {
    if (_commandInFlight) return;
    final transport = _transport;
    if (transport == null) return _explainNoTransport();
    final key = _playerKey;
    final muted = _isMuted;
    _commandInFlight = true;
    try {
      final sent = await transport.setMuted(!muted);
      if (!mounted || key != _playerKey) return;
      if (!sent) return _explainNotReady();
      // The player's mutedListenable confirms the actual mute state.
    } finally {
      _commandInFlight = false;
    }
  }

  ValueListenable<bool>? _mutedSource;

  /// Re-reads whether the player takes commands (after it is built), and
  /// follows its mute state, including its own built-in mute button.
  void _refreshTransportAvailability() {
    if (!mounted) return;
    final transport = _transport;
    final source = transport?.mutedListenable;
    if (!identical(source, _mutedSource)) {
      _mutedSource?.removeListener(_onPlayerMutedChanged);
      _mutedSource = source;
      source?.addListener(_onPlayerMutedChanged);
    }
    final available = transport != null;
    if (available != _transportAvailable) {
      setState(() => _transportAvailable = available);
    }
  }

  void _onPlayerMutedChanged() {
    final muted = _mutedSource?.value;
    if (!mounted || muted == null || muted == _isMuted) return;
    setState(() => _isMuted = muted);
  }

  /// A command the player could not take yet (still loading) is said, not
  /// silently dropped.
  void _explainNotReady() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('live.player_not_ready'.tr())),
    );
  }

  GlobalKey _playerKeyFor(String identity) {
    if (identity != _playerIdentity) {
      _playerIdentity = identity;
      _playerKey = GlobalKey(debugLabel: 'room-player');
      // Known again once the new player is built.
      _transportAvailable = false;
    }
    return _playerKey;
  }

  bool _hasYouTubeId(StreamerModel streamer) =>
      _getStreamUrl(streamer).isNotEmpty;

  /// Task 5 -- same escape hatch the YouTube adapter offers inside its own
  /// error view, surfaced here too so it is reachable from the unified
  /// placeholder regardless of which layer noticed the failure.
  Future<void> _openStreamInYouTube(StreamerModel streamer) async {
    final videoId = _getStreamUrl(streamer);
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
      debugPrint('[LiveBroadcastScreen] openInYouTube failed: $e');
    }
  }

  /// The exact video this room plays, or '' when there is nothing valid to
  /// play. While the channel is live that is the server's live watch ID
  /// (profiles.active_stream_id) and nothing else: the room used to play the
  /// profile's youtube_video_id, which a phone broadcast never sets, and the
  /// player then substituted a sample video (owner retest 2026-09-25, viewer
  /// screenshot of "YouTube Developers Live: Embedded Web Player
  /// Customization", video M7lc1UVf-VE).
  String _getStreamUrl(StreamerModel streamer) {
    if (streamer.isLiveForRoom) return streamer.liveWatchId ?? '';
    final featured = streamer.youtubeVideoId.trim();
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(featured) ? featured : '';
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final networkStatus =
        context.select<AppProvider, NetworkStatus>((p) => p.networkStatus);
    final choices=appProvider.roomChoices(widget.streamId);
    if(choices.length>1) { return Scaffold(appBar:AppBar(title:Text('organization_v1.choose_show'.tr())),
      body:ListView(children:choices.map((s)=>ListTile(title:Text(s.title(context.locale.languageCode)),
        trailing:const Icon(Icons.play_arrow),onTap:()=>context.pushReplacement('/live/${s.id}'))).toList())); }
    final session=appProvider.roomSession(widget.streamId);
    if(session!=null && !session.live && session.replayStatus!='available') {
      final key=['scheduled','preparing'].contains(session.state)?'scheduled_room':
        session.replayStatus=='processing' || session.state=='processing_replay'?'replay_processing':'replay_missing';
      return Scaffold(appBar:AppBar(title:Text(session.title(context.locale.languageCode))),body:Center(child:Padding(
        padding:const EdgeInsets.all(AppTheme.spaceLg),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('organization_v1.$key'.tr()),TextButton(onPressed:_refreshRoom,child:Text('organization_v1.refresh'.tr()))]))));
    }
    if (_roomEnded && session?.replayStatus!='available') {
      return const _RoomStatusScaffold(
        key: Key('live-room-ended'),
        icon: Icons.stop_circle_outlined,
        titleKey: 'live.room_ended_title',
        bodyKey: 'live.room_ended_body',
      );
    }
    // Once a catalog has loaded, a room that names no known channel says so
    // instead of waiting or borrowing another streamer.
    if (_findStreamer(appProvider) == null &&
        appProvider.roomRevision(widget.streamId) > 0) {
      return const _RoomStatusScaffold(
        key: Key('live-room-unavailable'),
        icon: Icons.videocam_off_outlined,
        titleKey: 'live.room_unavailable_title',
        bodyKey: 'live.room_unavailable_body',
        showRetry: true,
      );
    }
    if (_recoveryExhausted) {
      return _RoomStatusScaffold(
        key: const Key('live-room-recovery-exhausted'),
        icon: Icons.wifi_off_rounded,
        titleKey: 'live.connection_error',
        bodyKey: 'live.recovery_exhausted',
        showRetry: true,
        onRetry: _retryStream,
      );
    }
    if (!_roomActive) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
            child: LiveRoomConnectionView(
          status: networkStatus,
          awaitingFreshCatalog: networkStatus == NetworkStatus.online,
          liveNotConfirmed: _requiredCatalogRevision != null &&
              appProvider.roomRevision(widget.streamId) > _requiredCatalogRevision!,
        )),
      );
    }
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = isLaptopLiveLayout(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSideBySide = isDesktop || isLandscape;
    final langCode = context.locale.languageCode;

    final resolved = _findStreamer(appProvider);
    if (resolved == null) {
      return const _RoomStatusScaffold(
        key: Key('live-room-unavailable'),
        icon: Icons.videocam_off_outlined,
        titleKey: 'live.room_unavailable_title',
        bodyKey: 'live.room_unavailable_body',
        showRetry: true,
      );
    }
    final streamer = resolved;
    // Platform presence, counted server-side (P3). Null until the first
    // successful read, and rendered as "—". YouTube's own concurrent-viewer
    // number is a different figure and stays in the broadcaster studio,
    // labelled as YouTube's -- the two are never merged.
    final viewerCount = _presenceService.count;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: true,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: AppTheme.bg,
              title: Text(
                streamer.getLocalizedTitle(langCode),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                // Leave with a "Return to broadcast" shortcut (playback stops)
                IconButton(
                  icon: const Icon(Icons.minimize_rounded, size: 20),
                  tooltip: 'live.minimize_tooltip'.tr(),
                  onPressed: () =>
                      _minimizeToMiniPlayer(appProvider, streamer, langCode),
                ),
                // Broadcaster Studio Access -- single unified entry point
                // (v0.9) for going live with an encoder or the phone camera.
                if (appProvider.isLoggedInStreamer &&
                    appProvider.isStreamerModeEnabled)
                  IconButton(
                    icon: const Icon(Icons.cell_tower_rounded, size: 20),
                    tooltip: 'live.rtmp_ip_tooltip'.tr(),
                    onPressed: () => LiveBroadcasterStudioSheet.show(context,
                        openedFromVideo: true),
                  ),
                const LanguageSwitcher(),
                const SizedBox(width: AppTheme.spaceSm),
              ],
            ),
      body: SafeArea(
        child: isSideBySide
            ? Row(
                children: [
                  // Left Side: Video Viewport & Broadcaster Metadata
                  Expanded(
                    flex: isDesktop ? 65 : 58,
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildVideoViewport(
                              appProvider, streamer, viewerCount, langCode,
                              isSideBySide: true),
                        ),
                        if (!_isFullscreen)
                          _buildBroadcasterHeader(
                              appProvider, streamer, langCode),
                      ],
                    ),
                  ),
                  if (!_isFullscreen)
                    const VerticalDivider(width: 1, color: AppTheme.border),

                  // Right Side: Cinema Multi-Tab Container
                  if (!_isFullscreen)
                    Expanded(
                      flex: isDesktop ? 35 : 42,
                      child:
                          _buildCinemaTabPanel(appProvider, streamer, langCode),
                    ),
                ],
              )
            : Column(
                children: [
                  // Mobile Portrait: Top 16:9 Video Player + Broadcaster Header
                  AnimatedSize(
                    duration: const Duration(milliseconds: 240),
                    alignment: Alignment.topCenter,
                    child: _buildVideoViewport(
                        appProvider, streamer, viewerCount, langCode,
                        isSideBySide: false),
                  ),
                  if (!_isFullscreen)
                    _buildBroadcasterHeader(appProvider, streamer, langCode),

                  // Mobile Portrait: Multi-Tab Panel
                  if (!_isFullscreen)
                    Expanded(
                      child:
                          _buildCinemaTabPanel(appProvider, streamer, langCode),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoViewport(AppProvider appProvider, StreamerModel streamer,
      int? viewerCount, String langCode,
      {required bool isSideBySide}) {
    final isAudioLive = streamer.isLiveForRoom &&
        streamer.broadcastType == BroadcastType.liveAudio;
    final roomGeneration = _roomGeneration;
    final streamUrl = _getStreamUrl(streamer);
    final playerKey = _playerKeyFor(
        '${_sourceType.name}_${streamUrl}_${appProvider.streamReloadCount}_$_playerReloads');
    // Nothing valid to play: no player at all, and an honest offline card
    // rather than a substitute video.
    final viewportState =
        streamUrl.isEmpty ? StreamState.offline : _streamState;

    final videoWidget = Listener(
        onPointerDown: (event) => _mediaPointerDown = event.localPosition,
        onPointerUp: (event) {
          final down = _mediaPointerDown;
          _mediaPointerDown = null;
          // Observe taps without claiming the gesture arena or intercepting the
          // native iframe. Its bottom transport strip is excluded.
          final box =
              _overlayKey.currentContext?.findRenderObject() as RenderBox?;
          if (down != null &&
              (event.localPosition - down).distance < 8 &&
              box != null &&
              event.localPosition.dy > 64 &&
              event.localPosition.dy < box.size.height - 80) {
            _overlayKey.currentState?.toggleControlsVisibility();
          }
        },
        child: ColoredBox(
          color: AppTheme.media,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. The Video/Audio Player Engine (Always mounted so Android WebView never suspends audio)
              if (streamUrl.isNotEmpty)
                AbstractVideoPlayer.fromSource(
                  key: playerKey,
                  sourceType: _sourceType,
                  streamUrl: streamUrl,
                  // A live room never fails over to another video.
                  fallbackUrls: streamer.isLiveForRoom
                      ? const []
                      : streamer.fallbackYoutubeVideoIds,
                  autoPlay: _playIntent,
                  // A new player (Retry, reload) keeps the viewer's mute choice.
                  initialMuted: _isMuted,
                  // The new player starts from initialMuted; the room only needs
                  // to learn whether it takes commands.
                  onPlayerReady: () => WidgetsBinding.instance
                      .addPostFrameCallback(
                          (_) => _refreshTransportAvailability()),
                  preferredQuality: _selectedQuality.value,
                  onStateChanged: (state) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          _roomActive &&
                          roomGeneration == _roomGeneration &&
                          playerKey == _playerKey &&
                          _streamState != state) {
                        _refreshTransportAvailability();
                        setState(() {
                          _streamState = state;
                          if (state == StreamState.unconfirmed) {
                            // No state bridge: hand control to the visible
                            // player without claiming recovery or repeatedly
                            // reloading media the user may already be playing.
                            _cancelViewerRecovery();
                          }
                          // Follow the player: a pause from its own controls or
                          // the system shows as paused here too.
                          if (state == StreamState.paused) _isPlaying = false;
                          if (state == StreamState.live) _isPlaying = true;
                          if (state == StreamState.paused ||
                              state == StreamState.live) {
                            _playIntent = _isPlaying;
                            if (_recovering) {
                              _recoveryTimer?.cancel();
                              _recoveryTimer = null;
                              _recoveryStable ??=
                                  Timer(const Duration(seconds: 10), () {
                                _cancelViewerRecovery();
                                if (mounted) setState(() {});
                              });
                            }
                          }
                          if (state == StreamState.fallbackError ||
                              state == StreamState.offline) {
                            _beginViewerRecovery();
                          }
                        });
                      }
                    });
                  },
                  onError: (_) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted &&
                          _roomActive &&
                          roomGeneration == _roomGeneration &&
                          playerKey == _playerKey &&
                          _streamState != StreamState.fallbackError) {
                        setState(
                            () => _streamState = StreamState.fallbackError);
                        _recoveryTimer?.cancel();
                        _recoveryTimer = null;
                        _beginViewerRecovery();
                      }
                    });
                  },
                ),

              // Keep the YouTube player mounted for audio, and restore the
              // centered audio stage over its otherwise black video surface.
              if (isAudioLive)
                LiveAudioStageMultiSpeaker(
                  streamer: streamer,
                  langCode: langCode,
                  viewerCount: viewerCount,
                  isPlaying: _isPlaying,
                  streamState: viewportState,
                  onStageTap: () =>
                      _overlayKey.currentState?.toggleControlsVisibility(),
                ),

              // 2b. Multi-Speaker Floating Video Overlay
              if (!isAudioLive &&
                  (streamer.isOrganization ||
                      streamer.affiliatedSpeakers.isNotEmpty))
                PositionedDirectional(
                  top: 44,
                  start: 12,
                  child: LiveMultiSpeakerOverlay(
                    speakers: streamer.affiliatedSpeakers,
                    orgName: streamer.getLocalizedName(langCode),
                    allVods:
                        appProvider.getVodsForStreamer(streamer.channelProfileId),
                  ),
                ),

              // 3. Floating Reactions
              FloatingReactionsOverlay(controller: _reactionsController),

              if (streamer.isIngestInterrupted)
                PositionedDirectional(
                  bottom: 52,
                  start: 12,
                  end: 12,
                  child: Semantics(
                    liveRegion: true,
                    child: Container(
                      key: const Key('live-room-reconnecting'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSm, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.media.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      ),
                      child: Row(children: [
                        const Icon(Icons.wifi_tethering_error_rounded,
                            size: 16, color: AppTheme.warning),
                        const SizedBox(width: AppTheme.spaceXs),
                        Expanded(
                          child: Text(
                            'live.broadcaster_reconnecting'.tr(),
                            style: const TextStyle(
                                color: AppTheme.onMedia, fontSize: 12),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

              // 4. Raise Hand Video Overlay Badge (Bottom-Right)
              if (_isHandRaised)
                PositionedDirectional(
                  bottom: 12,
                  end: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      border: Border.all(color: AppTheme.warning, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                            color: AppTheme.shadow,
                            blurRadius: 10,
                            offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pan_tool_outlined, size: 13),
                        const SizedBox(width: 5),
                        Text(
                          'live.hand_raised_badge'.tr(),
                          style: const TextStyle(
                            color: AppTheme.onMedia,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 5. Controls Overlay
              LivePlayerOverlayControls(
                key: _overlayKey,
                streamState: viewportState,
                // The sending phone lost its connection: say so instead of a
                // LIVE badge over a stalled player.
                showLiveBadge:
                    streamer.isLiveForRoom && !streamer.isIngestInterrupted,
                viewerCount: viewerCount,
                isPlaying: _isPlaying,
                isMuted: _isMuted,
                isFullscreen: _isFullscreen,
                isAudioOnly: isAudioLive,
                isStreamerMicMuted: appProvider.isStreamerMicMuted,
                selectedQuality: _selectedQuality,
                showTransportControls: _transportAvailable,
                // YouTube removed setPlaybackQuality; its own settings own ABR.
                showQualitySelector: false,
                onTogglePlayPause: _togglePlayPause,
                onToggleMute: _toggleMute,
                onToggleFullscreen: _handleToggleFullscreen,
                onSelectQuality: (quality) =>
                    setState(() => _selectedQuality = quality),
                onRetryConnection: _retryStream,
              ),

              // 6. Default / Custom Stream State Placeholder (Task 4a).
              // Deliberately stacked *above* the controls overlay: that overlay
              // is an opaque, full-bleed GestureDetector, so a placeholder
              // underneath it would render its Retry / Open in YouTube buttons
              // untappable. The controls hide themselves for exactly these
              // states, so nothing is lost by covering them. Renders nothing at
              // all while the feed is playing.
              StreamStatePlaceholderOverlay(
                streamState: viewportState,
                customImageUrl: _customPlaceholderUrl(appProvider, streamer),
                onRetry: _retryStream,
                onOpenInYouTube: _sourceType == StreamSourceType.youtubeEmbed &&
                        _hasYouTubeId(streamer)
                    ? () => _openStreamInYouTube(streamer)
                    : null,
              ),

              if (_streamState == StreamState.unconfirmed)
                PositionedDirectional(
                  top: 0,
                  start: 72,
                  end: 8,
                  child: Row(children: [
                    Expanded(
                        child: Text('live.player_state_unconfirmed'.tr(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.onMedia))),
                    TextButton(
                        onPressed: _retryStream,
                        child: Text('live.retry_feed'.tr())),
                  ]),
                ),
              if (_recovering || _recoveryExhausted)
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  end: 8,
                  child: IgnorePointer(
                      child: Semantics(
                    liveRegion: true,
                    child: Text(
                        _recoveryExhausted
                            ? 'live.recovery_exhausted'.tr()
                            : 'live.stream_interrupted_reconnecting_attempt'.tr(
                                namedArgs: {
                                    'current': '$_recoveryAttempts',
                                    'total': '10'
                                  }),
                        style: const TextStyle(color: AppTheme.onMedia)),
                  )),
                ),

              // 7. Private Streaming: viewer's own access state (VIP badge /
              // waiting room / unauthorized notice). No-op for public streams.
              PrivateStreamViewerGate(
                accessState: appProvider.localViewerAccessState,
                onRequestToJoin: appProvider.requestToJoinActiveStream,
              ),
            ],
          ),
        ));

    if (isSideBySide) return videoWidget;

    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return SizedBox(width: double.infinity, height: 100, child: videoWidget);
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: videoWidget,
    );
  }

  Widget _buildBroadcasterHeader(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    final isFollowing = appProvider.isFollowing(streamer.channelProfileId);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${streamer.channelProfileId}'),
            child: StreamerAvatar(
              radius: 18,
              avatarUrl: streamer.avatarUrl,
            ),
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
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded,
                        color: AppTheme.primary, size: 14),
                  ],
                ),
                Text(
                  streamer.getLocalizedOrganization(langCode),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isFollowing ? AppTheme.surfaceAlt : AppTheme.danger,
              foregroundColor:
                  isFollowing ? AppTheme.textSecondary : AppTheme.onMedia,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                side: isFollowing
                    ? const BorderSide(color: AppTheme.border)
                    : BorderSide.none,
              ),
            ),
            onPressed: () => appProvider.toggleFollow(streamer.channelProfileId),
            child: Text(
              isFollowing
                  ? 'profile.following_btn'.tr()
                  : 'profile.follow_btn'.tr(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinemaTabPanel(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    return Container(
      color: AppTheme.bg,
      child: Column(
        children: [
          // Tab Views (Chat, Sources, Venue)
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatTabView(),
                _buildSourcesTabView(appProvider, streamer, langCode),
                _buildVenueTabView(appProvider, streamer, langCode),
              ],
            ),
          ),

          //  Sleek Bottom Tab Bar Header (Chat, Sources, Venue at the BOTTOM with reduced height: 38px)
          Container(
            height: 45,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border:
                  Border(top: BorderSide(color: AppTheme.border, width: 0.8)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.danger,
              labelColor: AppTheme.danger,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorWeight: 2.0,
              tabs: [
                _buildCinemaTab(
                    Icons.chat_bubble_outline_rounded, 'live.tab_chat'.tr()),
                _buildCinemaTab(
                    Icons.folder_open_rounded, 'live.tab_sources'.tr()),
                _buildCinemaTab(
                    Icons.location_on_outlined, 'live.tab_venue'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// One tab of the chat/sources/venue bar.
  ///
  /// A third of a 320 px phone leaves about 88 px for icon plus label, which
  /// the English "Sources" already overran before the label could ellipsize --
  /// and every text scale above 1.0 made it worse. [Flexible] lets the label
  /// give way instead of overflowing, so the tab degrades to an ellipsis and
  /// keeps its icon.
  Widget _buildCinemaTab(IconData icon, String label) {
    return Tab(
      height: 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  //  Tab 1: Live Chat with Zero Top Gap, Reactions Menu & Raise Hand Toggle
  Widget _buildChatTabView() {
    return ListenableBuilder(
      listenable: _chatController,
      builder: (context, _) => _buildChatTabViewContent(),
    );
  }

  /// Slim, always-visible row so a dropped Realtime connection is visible
  /// rather than the chat silently going stale (doc/Roadmap/v0.6...md
  /// Checkpoint 1 Phase 3).
  Widget _buildChatConnectionIndicator() {
    final state = _chatController.connectionState;
    final (color, label) = switch (state) {
      ChatConnectionState.live => (
          AppTheme.success,
          'live.chat_status_live'.tr()
        ),
      ChatConnectionState.connecting => (
          AppTheme.warning,
          'live.chat_status_connecting'.tr()
        ),
      ChatConnectionState.reconnecting => (
          AppTheme.danger,
          'live.chat_status_reconnecting'.tr()
        ),
    };

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 4),
      color: AppTheme.surface,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// True once LiveChatController can't reach Realtime (dropped connection,
  /// offline testing, ...) -- reusing its existing "reconnecting"state
  /// rather than inventing a new one, since that already means exactly this.
  bool get _isChatOffline =>
      _chatController.connectionState == ChatConnectionState.reconnecting;

  Widget _buildChatTabViewContent() {
    final isOffline = _isChatOffline;
    // Both lists are oldest-first; the reversed ListView wants newest-first
    // at index 0.
    final messages = _chatController.messages.reversed.toList();

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              // Connection state, chat-unavailable, moderation alerts and slow
              // mode stack up above the list. Together they are taller than a
              // landscape phone's chat panel at text scale 2.0, so they are
              // capped at 40% of it and scroll inside that cap; the list and the
              // composer keep the rest. Below the cap the block takes only the
              // height it needs, so nothing changes at ordinary sizes.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: constraints.maxHeight * 0.35),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildChatConnectionIndicator(),
                      if (isOffline) _buildChatUnavailableBanner(),
                      if (_chatController.canModerate &&
                          _chatController.moderationAlerts.isNotEmpty)
                        ..._chatController.moderationAlerts
                            .map((alert) => _buildModerationAlertBanner(alert)),

                      // Slow mode is a property of the room, not of this viewer,
                      // so it is stated above the list for everyone -- including
                      // moderators, who are exempt from it but still need to
                      // know it is on.
                      if (_chatController.slowModeSeconds > 0 &&
                          _chatController.chatEnabled)
                        _buildChatSlowModeBanner(),
                    ],
                  ),
                ),
              ),

              // Chat Stream List (Starts from bottom with newest messages, scroll up for older)
              Expanded(
                child: messages.isEmpty
                    ? _buildChatEmptyState()
                    : Stack(
                        children: [
                          ListView.builder(
                            controller: _chatScrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            reverse: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceMd, vertical: 4),
                            itemCount: messages.length,
                            itemBuilder: (context, index) =>
                                _buildChatMessageTile(messages[index]),
                          ),
                          if (_chatUnreadWhileScrolled > 0)
                            PositionedDirectional(
                              start: 0,
                              end: 0,
                              bottom: AppTheme.spaceSm,
                              child: Center(child: _buildNewMessagesPill()),
                            ),
                        ],
                      ),
              ),

              //  Composer -- renders from LiveChatController.composerState, so
              // a viewer is never invited to type into a box whose insert the
              // server is going to refuse (P6.2).
              //
              // Capped like the chrome above it: the guest and blocked states
              // are a wrapped sentence, which in Arabic at text scale 2.0 grew
              // taller than the whole panel. Between the two caps the message
              // list always keeps at least a fifth of the panel.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: constraints.maxHeight * 0.45),
                child: SingleChildScrollView(child: _buildChatComposer()),
              ),
            ],
          ),
        ),

        //  Expandable Reactions FAB Menu (5 Icon Options)
        if (_isReactionMenuOpen)
          PositionedDirectional(
            bottom: 50,
            end: 14,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                      color: AppTheme.danger.withValues(alpha: 0.8),
                      width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                        color: AppTheme.shadowStrong,
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReactionFabIcon(liveReactionGlyphs['clap']!, 'clap'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon(
                        liveReactionGlyphs['heart']!, 'heart'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon(liveReactionGlyphs['idea']!, 'idea'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon(liveReactionGlyphs['fire']!, 'fire'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon(
                        liveReactionGlyphs['scholar']!, 'scholar'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Shown while Realtime is unreachable. The room used to fill the chat with
  /// simulated comments behind a "Demo Mode"banner (05 D-03); it now says
  /// plainly that chat is unavailable and shows no invented traffic.
  Widget _buildChatUnavailableBanner() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 6),
      color: AppTheme.warning.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 14, color: AppTheme.warning),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'live.chat_unavailable_banner'.tr(),
              style: const TextStyle(
                color: AppTheme.warning,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// In-stream moderator alert banner (Tasks 13 & 15): a chatter crossed
  /// the 3+ report threshold. Strictly for moderators/admins in the room --
  /// this only ever renders when _chatController.canModerate.
  Widget _buildModerationAlertBanner(
      ({String senderId, String senderName, int count}) alert) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 8),
      color: AppTheme.danger.withValues(alpha: 0.18),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: AppTheme.danger),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'live.moderation_alert_message'.tr(namedArgs: {
                'name': alert.senderName,
                'count': '${alert.count}',
              }),
              style: const TextStyle(
                color: AppTheme.danger,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _chatController.quickMuteFromAlert(alert.senderId),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.onMedia,
              backgroundColor: AppTheme.danger,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('live.moderation_alert_quick_mute'.tr(),
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 16, color: AppTheme.danger),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () =>
                _chatController.dismissModerationAlert(alert.senderId),
          ),
        ],
      ),
    );
  }

  // --- P6.2 composer, empty state and new-message pill --------------------

  /// Unread messages that arrived while the viewer was scrolled away from the
  /// newest end of the list. Drives the "New messages"pill, so a busy chat
  /// never yanks the list out from under someone reading back.
  int _chatUnreadWhileScrolled = 0;
  int _lastSeenChatCount = 0;

  /// The list is `reverse: true`, so offset 0 IS the newest message.
  bool get _isChatScrolledToNewest {
    if (!_chatScrollController.hasClients) return true;
    return _chatScrollController.offset <= 24;
  }

  void _handleChatScroll() {
    if (_isChatScrolledToNewest && _chatUnreadWhileScrolled != 0) {
      setState(() => _chatUnreadWhileScrolled = 0);
    }
  }

  /// Counts arrivals the viewer has not scrolled down to yet. Called from the
  /// controller listener, before the rebuild.
  void _trackChatArrivals() {
    final count = _chatController.messages.length;
    if (count > _lastSeenChatCount && !_isChatScrolledToNewest) {
      _chatUnreadWhileScrolled += count - _lastSeenChatCount;
    } else if (_isChatScrolledToNewest) {
      _chatUnreadWhileScrolled = 0;
    }
    _lastSeenChatCount = count;
  }

  void _scrollChatToNewest() {
    setState(() => _chatUnreadWhileScrolled = 0);
    if (!_chatScrollController.hasClients) return;
    _chatScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildNewMessagesPill() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        onTap: _scrollChatToNewest,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: const [
              BoxShadow(
                  color: AppTheme.shadow, blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.arrow_downward_rounded,
                  size: 13, color: AppTheme.bg),
              const SizedBox(width: 5),
              Text(
                '${'live.chat_new_messages_pill'.tr()} ($_chatUnreadWhileScrolled)',
                style: const TextStyle(
                  color: AppTheme.bg,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// An empty room stays empty (05 D-03) -- this explains the emptiness
  /// instead of filling it with invented conversation.
  Widget _buildChatEmptyState() {
    final isGuest = _chatController.isGuest;
    return CenteredScrollable(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.forum_outlined, size: 34, color: AppTheme.textMuted),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'live.chat_empty_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isGuest
                ? 'live.chat_empty_subtitle_guest'.tr()
                : 'live.chat_empty_subtitle'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  /// Slow mode is a property of the room, not of this viewer, so it is stated
  /// for everyone -- including moderators, who are exempt but still need to
  /// know the room is slowed down.
  Widget _buildChatSlowModeBanner() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 4),
      color: AppTheme.warning.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.hourglass_bottom_rounded,
              size: 12, color: AppTheme.warning),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              'live.chat_slow_mode_active'
                  .tr(args: ['${_chatController.slowModeSeconds}']),
              style: const TextStyle(
                  color: AppTheme.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// One row that states why the composer is unusable, with the only action
  /// that helps. Guests get a sign-in button; the rest are statements of fact,
  /// because there is nothing the viewer can do about them here.
  Widget _buildChatComposerNotice({
    required IconData icon,
    required Color color,
    required String message,
    Widget? action,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11.5),
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppTheme.spaceSm),
            action,
          ],
        ],
      ),
    );
  }

  Widget _buildChatComposer() {
    if (isCompactLandscapeChat(context)) {
      return _buildChatComposerNotice(
        icon: Icons.screen_rotation_rounded,
        color: AppTheme.textSecondary,
        message: 'live.landscape_chat_read_only'.tr(),
      );
    }
    if(_roomProvider?.roomSession(widget.streamId)?.live==false) {
      return _buildChatComposerNotice(icon:Icons.history,color:AppTheme.textMuted,
        message:'organization_v1.replay_chat_read_only'.tr());
    }
    switch (_chatController.composerState) {
      case ChatComposerState.guest:
        return _buildChatComposerNotice(
          icon: Icons.login_rounded,
          color: AppTheme.primary,
          message: 'live.chat_composer_guest'.tr(),
          action: TextButton(
            onPressed: () => context.go('/welcome'),
            child: Text(
              'live.chat_composer_guest_action'.tr(),
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold),
            ),
          ),
        );
      case ChatComposerState.banned:
        return _buildChatComposerNotice(
          icon: Icons.block_rounded,
          color: AppTheme.danger,
          message: 'live.chat_composer_banned'.tr(),
        );
      case ChatComposerState.platformPaused:
        return _buildChatComposerNotice(
          icon: Icons.pause_circle_outline_rounded,
          color: AppTheme.warning,
          message: 'live.chat_composer_platform_paused'.tr(),
        );
      case ChatComposerState.muted:
        return _buildChatComposerNotice(
          icon: Icons.volume_off_rounded,
          color: AppTheme.danger,
          message: 'live.chat_composer_muted'.tr(),
        );
      case ChatComposerState.chatDisabled:
        return _buildChatComposerNotice(
          icon: Icons.speaker_notes_off_rounded,
          color: AppTheme.textMuted,
          message: 'live.chat_composer_chat_off'.tr(),
        );
      case ChatComposerState.offline:
      case ChatComposerState.slowMode:
      case ChatComposerState.ready:
        return _buildChatInputBar();
    }
  }

  /// The live composer. Reached only for [ChatComposerState.ready],
  /// [ChatComposerState.slowMode] and [ChatComposerState.offline]: in the last
  /// two the field stays visible and readable but sending is held, with the
  /// countdown or the connection stated in the hint, so the viewer can see
  /// their draft and why it has not gone yet.
  Widget _buildChatInputBar() {
    final state = _chatController.composerState;
    final secondsLeft = _chatController.slowModeSecondsRemaining;
    final canSend = state == ChatComposerState.ready;

    final hint = switch (state) {
      ChatComposerState.slowMode =>
        'live.chat_composer_slow_mode'.tr(args: ['$secondsLeft']),
      ChatComposerState.offline => 'live.chat_composer_offline'.tr(),
      _ => 'live.chat_placeholder'.tr(),
    };

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spaceSm, vertical: 4),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Raise Hand Toggle Button
          IconButton(
            icon: Icon(
              Icons.back_hand_rounded,
              color: _isHandRaised ? AppTheme.warning : AppTheme.textMuted,
              size: 19,
            ),
            tooltip: 'live.raise_hand_toggle'.tr(),
            style: IconButton.styleFrom(
              backgroundColor: _isHandRaised
                  ? AppTheme.warning.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
            onPressed: canSend ? _toggleRaiseHand : null,
          ),

          // Text Input Field
          Expanded(
            child: TextField(
              controller: _chatTextController,
              focusNode: _chatFocus,
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                  color: canSend
                      ? AppTheme.textMuted
                      : AppTheme.warning.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
              onSubmitted: canSend ? (_) => _handleSendLocalMessage() : null,
            ),
          ),
          const SizedBox(width: 2),

          // Reactions Menu FAB Button -- reactions are broadcast-only, never
          // an insert, so they stay available while sending is held.
          IconButton(
            icon: Icon(
              _isReactionMenuOpen
                  ? Icons.close_rounded
                  : Icons.emoji_emotions_outlined,
              color: _isReactionMenuOpen ? AppTheme.danger : AppTheme.primary,
              size: 20,
            ),
            tooltip: 'live.reaction_menu_tooltip'.tr(),
            onPressed: () {
              setState(() => _isReactionMenuOpen = !_isReactionMenuOpen);
            },
          ),

          // Send Button
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: canSend
                  ? AppTheme.danger
                  : AppTheme.textMuted.withValues(alpha: 0.5),
              size: 19,
            ),
            onPressed: canSend ? _handleSendLocalMessage : null,
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageTile(ChatMessageModel message) {
    final tile = GestureDetector(
      // Cluster 4 Task 13: long-press now opens the actions sheet for every
      // message, own or not -- showChatMessageActionsSheet itself branches
      // on message.isCurrentUser to offer Edit/Delete vs. Report/Hide/Block.
      onLongPress: () => showChatMessageActionsSheet(
        context,
        message: message,
        controller: _chatController,
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.surface,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: message.badges.isEmpty
                          ? '${message.senderName}${message.body == '✋' ? ' ✋' : ''}: '
                          : '${message.senderName} ${message.badges.map((b) => context.locale.languageCode == 'ar' ? b.labelAr : b.labelEn).join(', ')}${message.body == '✋' ? ' ✋' : ''}: ',
                      style: TextStyle(
                        color: message.isCurrentUser
                            ? AppTheme.danger
                            : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    TextSpan(
                      text: message.body == '✋'
                          ? 'live.hand_raised_message'.tr()
                          : message.body == '✋↓'
                              ? 'live.hand_lowered_message'.tr()
                              : message.body,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                    ),
                    if (message.isEdited)
                      TextSpan(
                        text: ' ${'live.message_edited_badge'.tr()}',
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
            if (message.isPending)
              const SizedBox(
                width: 9,
                height: 9,
                child: HadayahLoadingIndicator(
                    strokeWidth: 1.5, color: AppTheme.textMuted),
              )
            else
              Text(
                TimeOfDay.fromDateTime(message.createdAt.toLocal())
                    .format(context),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
          ],
        ),
      ),
    );

    if (!message.isFailed) return tile;

    // A refused send keeps the text on screen with the server's own reason
    // and, where a second attempt could actually succeed, a Retry. A banned
    // keyword or a chat that has been turned off will be refused identically
    // forever, so those offer Discard only rather than a button that lies.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Opacity(opacity: 0.6, child: tile),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 32, bottom: 6),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 12, color: AppTheme.danger),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  message.failureReason ?? '',
                  style:
                      const TextStyle(color: AppTheme.danger, fontSize: 10.5),
                ),
              ),
              if (_chatController.isRetryable(message.id))
                TextButton(
                  onPressed: () => _retryFailedChatMessage(message.id),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                  ),
                  child: Text(
                    'live.chat_send_failed_retry'.tr(),
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              TextButton(
                onPressed: () =>
                    _chatController.discardFailedMessage(message.id),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
                child: Text(
                  'live.chat_send_failed_discard'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _retryFailedChatMessage(String messageId) {
    _chatController.retryFailedMessage(messageId).catchError((Object e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.danger),
      );
    });
  }

  Widget _buildReactionFabIcon(String emoji, String type) {
    return InkWell(
      onTap: () => _handleQuickReaction(type, emoji),
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  //  Tab 2: Sources & References (Renamed from Slides)
  Widget _buildSourcesTabView(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    final slidesUrl = appProvider.customSlidesUrl;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      children: [
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
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      color: AppTheme.danger, size: 24),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'live.slides_pdf_title'.tr(),
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5),
                        ),
                        Text(
                          slidesUrl,
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.2),
                      foregroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('live.downloading_slides_toast'.tr())),
                      );
                    },
                    child: Text('live.download_btn'.tr(),
                        style: const TextStyle(fontSize: 10.5)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        Text(
          'live.lecture_agenda_title'.tr(),
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _buildChapterItem(
            '00:00',
            langCode == 'ar'
                ? 'مقدمة في الأنظمة الذكية المستقلة'
                : 'Introduction to Autonomous Agent Systems'),
        _buildChapterItem(
            '14:30',
            langCode == 'ar'
                ? 'أنماط المعمارية وضغط سياق النماذج اللغوية'
                : 'Architecture Patterns & LLM Context Compression'),
        _buildChapterItem(
            '38:15',
            langCode == 'ar'
                ? 'عرض تطبيقي مباشر: خريطة نظم المعلومات الجغرافية'
                : 'Live Demonstration: Real-Time Vector GIS Map'),
        _buildChapterItem(
            '52:00',
            langCode == 'ar'
                ? 'المصادر المفتوحة وأوراق البحث المرجعية'
                : 'Open-Source Code & Research Papers'),
      ],
    );
  }

  Widget _buildChapterItem(String timestamp, String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              timestamp,
              style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              title,
              style:
                  const TextStyle(color: AppTheme.textPrimary, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  //  Tab 3: Venue & RSVP
  Widget _buildVenueTabView(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    final isAttending = appProvider.isAttendingInPerson(widget.streamId);
    final availableSeats = appProvider.getAvailableSeats(widget.streamId);
    // Venue seating and RSVP have no backend: no table records an attendance,
    // and the seat numbers were invented on the device. The venue address
    // below is real (it comes from the channel's own fields), so the tab
    // stays and only the unbacked parts are hidden (05 D-03, D-11 pattern).
    const showRsvp = kVenueRsvpEnabled;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      children: [
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
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppTheme.danger, size: 22),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          streamer.getLocalizedVenue(langCode),
                          style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        Text(
                          '${streamer.getLocalizedCity(langCode)}, Eastern Province, KSA',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showRsvp) const SizedBox(height: AppTheme.spaceSm),
              if (showRsvp)
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        availableSeats > 0
                            ? '$availableSeats ${'live.seats_available'.tr()}'
                            : 'live.hall_fully_booked'.tr(),
                        style: TextStyle(
                          color: availableSeats > 0
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                      Icon(
                        availableSeats > 0
                            ? Icons.event_seat_rounded
                            : Icons.block_rounded,
                        color: availableSeats > 0
                            ? AppTheme.primary
                            : AppTheme.textMuted,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              if (showRsvp) const SizedBox(height: AppTheme.spaceSm),
              if (showRsvp)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isAttending ? AppTheme.surface : AppTheme.danger,
                      foregroundColor:
                          isAttending ? AppTheme.primary : AppTheme.onMedia,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    icon: Icon(
                        isAttending
                            ? Icons.check_circle_rounded
                            : Icons.confirmation_number_outlined,
                        size: 16),
                    label: Text(
                      isAttending
                          ? 'live.seat_reserved'.tr()
                          : 'live.rsvp_attend'.tr(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    onPressed: () {
                      appProvider.toggleInPersonAttendance(widget.streamId);
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        if (isUsableVenuePoint(streamer.latitude, streamer.longitude))
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textPrimary,
                side: const BorderSide(color: AppTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              icon: const Icon(Icons.directions_car_rounded,
                  color: AppTheme.primary, size: 16),
              label: Text('live.get_directions'.tr(),
                  style: const TextStyle(fontSize: 12)),
              onPressed: () {
                VenueNavigationSheet.show(
                  context,
                  streamer: streamer,
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Full-screen status for a room that cannot or no longer plays anything:
/// the broadcast ended, or the link names no known channel.
class _RoomStatusScaffold extends StatelessWidget {
  const _RoomStatusScaffold({
    super.key,
    required this.icon,
    required this.titleKey,
    required this.bodyKey,
    this.showRetry = false,
    this.onRetry,
  });

  final bool showRetry;
  final VoidCallback? onRetry;
  final IconData icon;
  final String titleKey;
  final String bodyKey;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(backgroundColor: AppTheme.bg),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: AppTheme.textMuted, size: 42),
                const SizedBox(height: AppTheme.spaceMd),
                Text(titleKey.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: AppTheme.spaceSm),
                Text(bodyKey.tr(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: AppTheme.spaceLg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppTheme.spaceSm,
                  runSpacing: AppTheme.spaceSm,
                  children: [
                    FilledButton(
                      onPressed: () =>
                          context.canPop() ? context.pop() : context.go('/'),
                      child: Text('live.room_back_to_feed'.tr()),
                    ),
                    if (showRetry)
                      OutlinedButton(
                        key: const Key('live-room-check-again'),
                        onPressed: onRetry ??
                            () => provider.loadVerifiedStreamersFromBackend(),
                        child: Text('live.room_check_again'.tr()),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
