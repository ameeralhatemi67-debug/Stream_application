import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/chat_message_model.dart';
import '../models/ghost_comments.dart';
import '../services/ghost_chat_fallback_controller.dart';
import '../services/live_chat_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../../profile/models/vod_models.dart';
import '../../map/presentation/widgets/venue_navigation_sheet.dart';
import 'abstract_video_player.dart';
import 'widgets/chat_message_actions_sheet.dart';
import 'widgets/floating_reactions_overlay.dart';
import 'widgets/live_player_overlay_controls.dart';
import 'widgets/live_multi_speaker_overlay.dart';
import 'widgets/live_audio_stage_multi_speaker.dart';
import 'widgets/private_stream_viewer_gate.dart';
import 'widgets/stream_state_placeholder_overlay.dart';
import '../../admin/models/streamer_custom_placeholder_model.dart';
import 'widgets/rtmp_ip_dialog.dart';

class LiveBroadcastScreen extends StatefulWidget {
  final String streamId;

  const LiveBroadcastScreen({super.key, required this.streamId});

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen>
    with SingleTickerProviderStateMixin {
  final FloatingReactionsOverlayController _reactionsController =
      FloatingReactionsOverlayController();
  final TextEditingController _chatTextController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  late final LiveChatController _chatController;
  late final GhostChatFallbackController _ghostChatController;

  late TabController _tabController;
  // Fixed to the YouTube embed engine (ADR-002). The overlay's selector no
  // longer switches engines -- as of Cluster 1 Task 2 it picks a *resolution*
  // (StreamQualityLevel), which is what its "1080p/720p/480p" labels always
  // claimed to do.
  final StreamSourceType _sourceType = StreamSourceType.youtubeEmbed;
  StreamState _streamState = StreamState.live;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _isHandRaised = false;
  bool _isReactionMenuOpen = false;
  StreamQualityLevel _selectedQuality = StreamQualityLevel.auto;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Chat, Sources, Venue
    _tabController = TabController(length: 3, vsync: this);
    _chatController = LiveChatController(
      streamId: widget.streamId,
      onReaction: (type) => _reactionsController.spawnReaction(type),
    )..start();
    _ghostChatController =
        GhostChatFallbackController(streamId: widget.streamId);
    _chatController.addListener(_handleChatConnectionChange);
    _setWakelock(true);
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
      final future =
          enable ? WakelockPlus.enable() : WakelockPlus.disable();
      future.catchError((Object e) {
        debugPrint('[LiveBroadcastScreen] wakelock unavailable: $e');
      });
    } catch (e) {
      debugPrint('[LiveBroadcastScreen] wakelock unavailable: $e');
    }
  }

  @override
  void dispose() {
    _setWakelock(false);
    // Always restore portrait + the normal system chrome, even if the user
    // backed out of the room while still in fullscreen landscape -- leaving
    // the app locked to landscape after this screen is gone would strand
    // every other screen sideways.
    _restorePortraitChrome();
    _tabController.dispose();
    _chatTextController.dispose();
    _chatScrollController.dispose();
    _chatController.removeListener(_handleChatConnectionChange);
    _chatController.dispose();
    _ghostChatController.dispose();
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

  /// Cluster 1 Task 6 -- hand the running stream to the floating mini-player
  /// and drop back to whichever tab (Feed or Map) the viewer came from.
  /// Popping rather than pushing is what keeps the audio going: the
  /// mini-player lives in the app shell above the navigator, so it survives
  /// the route change.
  void _minimizeToMiniPlayer(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    appProvider.openMiniPlayer(
      videoId: _getStreamUrl(appProvider),
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

  /// Switches the chat tab to the simulated ghost-chat fallback the moment
  /// Realtime drops (Checkpoint 4), and back to real messages the moment it
  /// recovers -- reusing LiveChatController's existing "reconnecting" state
  /// rather than adding a new one, since that's already exactly "Realtime is
  /// unreachable."
  void _handleChatConnectionChange() {
    final disconnected =
        _chatController.connectionState == ChatConnectionState.reconnecting;
    if (disconnected && !_ghostChatController.isActive) {
      _ghostChatController.start();
    } else if (!disconnected && _ghostChatController.isActive) {
      _ghostChatController.stop();
    }
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
  }

  void _handleSendLocalMessage() {
    final text = _chatTextController.text.trim();
    if (text.isEmpty) return;

    if (_chatController.connectionState == ChatConnectionState.reconnecting) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('live.demo_mode_cannot_send_toast'.tr())),
      );
      return;
    }
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
        SnackBar(content: Text('$e'), backgroundColor: AppTheme.accentRed),
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

  void _toggleRaiseHand() {
    // Pure video overlay toggle (no snackbar or chat message spam)
    setState(() {
      _isHandRaised = !_isHandRaised;
    });
  }

  StreamerModel _resolveStreamer(AppProvider appProvider) {
    return appProvider.getStreamerById(widget.streamId) ??
        appProvider.streamers.firstWhere(
          (s) =>
              s.streamerId == widget.streamId ||
              s.activeStreamId == widget.streamId ||
              s.youtubeVideoId == widget.streamId,
          orElse: () =>
              appProvider.activeStreamer ?? appProvider.streamers.first,
        );
  }

  /// Which of the three streamer-brandable states (Task 4b) the current
  /// [_streamState] maps to, or null for the failure states -- a custom card
  /// must never paper over "offline" or "playback failed", since hiding a
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

  void _retryStream() {
    setState(() {
      _streamState = StreamState.live;
      _isPlaying = true;
    });
  }

  bool _hasYouTubeId(AppProvider appProvider) =>
      _getStreamUrl(appProvider).trim().isNotEmpty;

  /// Task 5 -- same escape hatch the YouTube adapter offers inside its own
  /// error view, surfaced here too so it is reachable from the unified
  /// placeholder regardless of which layer noticed the failure.
  Future<void> _openStreamInYouTube(AppProvider appProvider) async {
    final videoId = _getStreamUrl(appProvider).trim();
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

  String _getStreamUrl(AppProvider appProvider) {
    final streamer = _resolveStreamer(appProvider);

    if (_sourceType == StreamSourceType.youtubeEmbed) {
      if (streamer.streamerId == 'prof_alghamdi_01' &&
          appProvider.customYouTubeVideoId.isNotEmpty) {
        return appProvider.customYouTubeVideoId;
      }
      return streamer.youtubeVideoId;
    } else if (_sourceType == StreamSourceType.localRtmp) {
      return appProvider.rtmpStreamUrl;
    } else {
      return streamer.cloudStreamUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final mediaQuery = MediaQuery.of(context);
    final isDesktop = mediaQuery.size.width >= 900;
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isSideBySide = isDesktop || isLandscape;
    final langCode = context.locale.languageCode;

    final streamer = _resolveStreamer(appProvider);
    final viewerCount =
        streamer.activeViewerCount > 0 ? streamer.activeViewerCount : 1240;

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      resizeToAvoidBottomInset: true,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: AppTheme.darkBgBase,
              title: Text(
                streamer.getLocalizedTitle(langCode),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              actions: [
                // Minimize to the floating in-app PiP mini-player (Task 6)
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt_rounded,
                      size: 20),
                  tooltip: 'live.minimize_tooltip'.tr(),
                  onPressed: () =>
                      _minimizeToMiniPlayer(appProvider, streamer, langCode),
                ),
                // Broadcaster Studio Access -- single unified entry point
                // (v0.9) for going live via OBS, phone camera, or local RTMP.
                if (appProvider.isLoggedInStreamer &&
                    appProvider.isStreamerModeEnabled)
                  IconButton(
                    icon: const Icon(Icons.cell_tower_rounded, size: 20),
                    tooltip: 'live.rtmp_ip_tooltip'.tr(),
                    onPressed: () => LiveBroadcasterStudioSheet.show(context),
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
                    const VerticalDivider(
                        width: 1, color: AppTheme.darkBorderSubtle),

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
                  _buildVideoViewport(
                      appProvider, streamer, viewerCount, langCode,
                      isSideBySide: false),
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
      int viewerCount, String langCode,
      {required bool isSideBySide}) {
    final isAudioLive = streamer.isAudioLive;

    final videoWidget = Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. The Video/Audio Player Engine (Always mounted so Android WebView never suspends audio)
          AbstractVideoPlayer.fromSource(
            key: ValueKey(
                '${_sourceType.name}_${appProvider.rtmpLaptopIp}_${appProvider.streamReloadCount}'),
            sourceType: _sourceType,
            streamUrl: _getStreamUrl(appProvider),
            fallbackUrls: streamer.fallbackYoutubeVideoIds,
            // Audio-only broadcasts always autoplay: LiveAudioStageMultiSpeaker
            // paints over the player entirely, so there is no visible
            // transport for the viewer to un-pause -- the engine underneath
            // has to start (and stay) playing on its own (Task 1).
            autoPlay: isAudioLive || _isPlaying,
            preferredQuality: _selectedQuality.value,
            onStateChanged: (state) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _streamState != state) {
                  setState(() => _streamState = state);
                }
              });
            },
            onError: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _streamState != StreamState.fallbackError) {
                  setState(() => _streamState = StreamState.fallbackError);
                }
              });
            },
          ),

          // 2. Audio-Only Presenter Stage Overlay with Kinetic Pulse Dynamics
          if (isAudioLive)
            LiveAudioStageMultiSpeaker(
              streamer: streamer,
              langCode: langCode,
              viewerCount: viewerCount,
              speakers: streamer.affiliatedSpeakers,
              allVods: MockVodArchivePool.sampleVods,
              isPlaying: _isPlaying,
              streamState: _streamState,
              onStageTap: () {
                if (!_isPlaying) {
                  setState(() {
                    _isPlaying = true;
                    _streamState = StreamState.live;
                  });
                }
              },
            ),

          // 2b. Multi-Speaker Floating Video Overlay
          if (!isAudioLive &&
              (streamer.isOrganization ||
                  streamer.affiliatedSpeakers.isNotEmpty))
            Positioned(
              top: 44,
              left: 12,
              child: LiveMultiSpeakerOverlay(
                speakers: streamer.affiliatedSpeakers,
                orgName: streamer.getLocalizedName(langCode),
                allVods: MockVodArchivePool.sampleVods,
              ),
            ),

          // 3. Floating Reactions
          FloatingReactionsOverlay(controller: _reactionsController),

          // 4. Raise Hand Video Overlay Badge (Bottom-Right)
          if (_isHandRaised)
            Positioned(
              bottom: 12,
              right: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black54,
                        blurRadius: 10,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✋', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 5),
                    Text(
                      'live.hand_raised_badge'.tr(),
                      style: const TextStyle(
                        color: Colors.white,
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
            streamState: _streamState,
            viewerCount: viewerCount,
            isPlaying: _isPlaying,
            isMuted: _isMuted,
            isFullscreen: _isFullscreen,
            isAudioOnly: isAudioLive,
            isStreamerMicMuted: appProvider.isStreamerMicMuted,
            selectedQuality: _selectedQuality,
            onTogglePlayPause: () {
              setState(() {
                _isPlaying = !_isPlaying;
                _streamState =
                    _isPlaying ? StreamState.live : StreamState.paused;
              });
            },
            onToggleMute: () => setState(() => _isMuted = !_isMuted),
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
            streamState: _streamState,
            customImageUrl: _customPlaceholderUrl(appProvider, streamer),
            onRetry: _retryStream,
            onOpenInYouTube: _sourceType == StreamSourceType.youtubeEmbed &&
                    _hasYouTubeId(appProvider)
                ? () => _openStreamInYouTube(appProvider)
                : null,
          ),

          // 7. Private Streaming: viewer's own access state (VIP badge /
          // waiting room / unauthorized notice). No-op for public streams.
          PrivateStreamViewerGate(
            accessState: appProvider.localViewerAccessState,
            onRequestToJoin: appProvider.requestToJoinActiveStream,
          ),
        ],
      ),
    );

    if (isSideBySide) return videoWidget;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: videoWidget,
    );
  }

  Widget _buildBroadcasterHeader(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    final isFollowing = appProvider.isFollowing(streamer.streamerId);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface1,
        border: Border(
            bottom: BorderSide(color: AppTheme.darkBorderSubtle, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.push('/profile/${streamer.streamerId}'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.darkSurface3,
              backgroundImage: _getImageProvider(streamer.avatarUrl),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isFollowing ? AppTheme.darkSurface2 : AppTheme.accentRed,
              foregroundColor:
                  isFollowing ? AppTheme.textSecondaryDark : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(60, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                side: isFollowing
                    ? const BorderSide(color: AppTheme.darkBorderSubtle)
                    : BorderSide.none,
              ),
            ),
            onPressed: () => appProvider.toggleFollow(streamer.streamerId),
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
      color: AppTheme.darkBgBase,
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

          // 🌟 Sleek Bottom Tab Bar Header (Chat, Sources, Venue at the BOTTOM with reduced height: 38px)
          Container(
            height: 45,
            decoration: const BoxDecoration(
              color: AppTheme.darkSurface1,
              border: Border(
                  top:
                      BorderSide(color: AppTheme.darkBorderSubtle, width: 0.8)),
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
                      const Icon(Icons.folder_open_rounded, size: 14),
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

  // 💬 Tab 1: Live Chat with Zero Top Gap, Reactions Menu & Raise Hand Toggle
  Widget _buildChatTabView() {
    return ListenableBuilder(
      listenable: Listenable.merge([_chatController, _ghostChatController]),
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
          AppTheme.accentGreen,
          'live.chat_status_live'.tr()
        ),
      ChatConnectionState.connecting => (
          AppTheme.accentAmber,
          'live.chat_status_connecting'.tr()
        ),
      ChatConnectionState.reconnecting => (
          AppTheme.accentRed,
          'live.chat_status_reconnecting'.tr()
        ),
    };

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 4),
      color: AppTheme.darkSurface1,
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
  /// offline testing, ...) -- reusing its existing "reconnecting" state
  /// rather than inventing a new one, since that already means exactly this.
  bool get _isChatOffline =>
      _chatController.connectionState == ChatConnectionState.reconnecting;

  Widget _buildChatTabViewContent() {
    final isOffline = _isChatOffline;
    // Both lists are oldest-first; the reversed ListView wants newest-first
    // at index 0.
    final messages = _chatController.messages.reversed.toList();
    final ghostMessages = _ghostChatController.messages.reversed.toList();
    final langCode = context.locale.languageCode;

    return Stack(
      children: [
        Column(
          children: [
            _buildChatConnectionIndicator(),
            if (isOffline) _buildDemoModeBanner(),

            // Chat Stream List (Starts from bottom with newest messages, scroll up for older)
            Expanded(
              child: isOffline
                  ? ListView.builder(
                      controller: _chatScrollController,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      reverse: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd, vertical: 4),
                      itemCount: ghostMessages.length,
                      itemBuilder: (context, index) =>
                          _buildGhostChatTile(ghostMessages[index], langCode),
                    )
                  : ListView.builder(
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
            ),

            // ✍️ Chat Input Bar with Raise Hand, Reactions FAB, and Send
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm, vertical: 4),
              decoration: const BoxDecoration(
                color: AppTheme.darkSurface1,
                border:
                    Border(top: BorderSide(color: AppTheme.darkBorderSubtle)),
              ),
              child: Row(
                children: [
                  // ✋ Raise Hand Toggle Button (No notification snackbar spam)
                  IconButton(
                    icon: Icon(
                      Icons.back_hand_rounded,
                      color: _isHandRaised
                          ? Colors.amberAccent
                          : AppTheme.textMutedDark,
                      size: 19,
                    ),
                    tooltip: 'live.raise_hand_toggle'.tr(),
                    style: IconButton.styleFrom(
                      backgroundColor: _isHandRaised
                          ? Colors.amber.shade900.withValues(alpha: 0.3)
                          : Colors.transparent,
                    ),
                    onPressed: _toggleRaiseHand,
                  ),

                  // 💬 Text Input Field
                  Expanded(
                    child: TextField(
                      controller: _chatTextController,
                      style: const TextStyle(
                          color: AppTheme.textPrimaryDark, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'live.chat_placeholder'.tr(),
                        hintStyle: const TextStyle(
                            color: AppTheme.textMutedDark, fontSize: 11),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          borderSide: const BorderSide(
                              color: AppTheme.darkBorderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          borderSide: const BorderSide(
                              color: AppTheme.darkBorderSubtle),
                        ),
                      ),
                      onSubmitted: (_) => _handleSendLocalMessage(),
                    ),
                  ),
                  const SizedBox(width: 2),

                  // ✨ Reactions Menu FAB Button
                  IconButton(
                    icon: Icon(
                      _isReactionMenuOpen
                          ? Icons.close_rounded
                          : Icons.emoji_emotions_outlined,
                      color: _isReactionMenuOpen
                          ? AppTheme.accentRed
                          : AppTheme.accentBlue,
                      size: 20,
                    ),
                    tooltip: 'live.reaction_menu_tooltip'.tr(),
                    onPressed: () {
                      setState(
                          () => _isReactionMenuOpen = !_isReactionMenuOpen);
                    },
                  ),

                  // ✈️ Send Button
                  IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppTheme.accentRed, size: 19),
                    onPressed: _handleSendLocalMessage,
                  ),
                ],
              ),
            ),
          ],
        ),

        // 🌟 Expandable Reactions FAB Menu (5 Icon Options)
        if (_isReactionMenuOpen)
          Positioned(
            bottom: 50,
            right: 14,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface1,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                      color: AppTheme.accentRed.withValues(alpha: 0.8),
                      width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black87,
                        blurRadius: 16,
                        offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReactionFabIcon('👏', 'clap'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon('❤️', 'heart'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon('💡', 'idea'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon('🔥', 'fire'),
                    const SizedBox(width: 6),
                    _buildReactionFabIcon('🎓', 'scholar'),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDemoModeBanner() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 6),
      color: AppTheme.accentAmber.withValues(alpha: 0.15),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 14, color: AppTheme.accentAmber),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'live.demo_mode_banner'.tr(),
              style: const TextStyle(
                color: AppTheme.accentAmber,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageTile(ChatMessageModel message) {
    return GestureDetector(
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
              backgroundColor: AppTheme.darkSurface3,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppTheme.accentBlue,
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
                          ? '${message.senderName}: '
                          : '${message.senderName} ${message.badges.map((b) => b.emoji).join()}: ',
                      style: TextStyle(
                        color: message.isCurrentUser
                            ? AppTheme.accentRed
                            : AppTheme.accentBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    TextSpan(
                      text: message.body,
                      style: const TextStyle(
                          color: AppTheme.textPrimaryDark, fontSize: 12),
                    ),
                    if (message.isEdited)
                      TextSpan(
                        text: ' ${'live.message_edited_badge'.tr()}',
                        style: const TextStyle(
                            color: AppTheme.textMutedDark, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
            Text(
              TimeOfDay.fromDateTime(message.createdAt.toLocal())
                  .format(context),
              style:
                  const TextStyle(color: AppTheme.textMutedDark, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// Simulated fallback message tile (Checkpoint 4) -- deliberately styled
  /// dimmer than _buildChatMessageTile (muted sender-name color, reduced
  /// opacity) and not long-press-actionable, so demo content stays visually
  /// distinct from real chat beyond just the banner above it.
  Widget _buildGhostChatTile(GhostComment comment, String langCode) {
    return Opacity(
      opacity: 0.8,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppTheme.darkSurface3,
              child: Text(
                comment.getLocalizedSender(langCode).isNotEmpty
                    ? comment.getLocalizedSender(langCode)[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: AppTheme.textMutedDark,
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
                      text: '${comment.getLocalizedSender(langCode)}: ',
                      style: const TextStyle(
                        color: AppTheme.textMutedDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    TextSpan(
                      text: comment.getLocalizedMessage(langCode),
                      style: const TextStyle(
                          color: AppTheme.textSecondaryDark, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              comment.timestamp,
              style:
                  const TextStyle(color: AppTheme.textMutedDark, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionFabIcon(String emoji, String type) {
    return InkWell(
      onTap: () => _handleQuickReaction(type, emoji),
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface2,
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.darkBorderSubtle),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  // 📄 Tab 2: Sources & References (Renamed from Slides)
  Widget _buildSourcesTabView(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    final slidesUrl = appProvider.customSlidesUrl;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      children: [
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
              Row(
                children: [
                  const Icon(Icons.menu_book_rounded,
                      color: AppTheme.accentRed, size: 24),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'live.slides_pdf_title'.tr(),
                          style: const TextStyle(
                              color: AppTheme.textPrimaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5),
                        ),
                        Text(
                          slidesUrl,
                          style: const TextStyle(
                              color: AppTheme.textMutedDark, fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          AppTheme.accentBlue.withValues(alpha: 0.2),
                      foregroundColor: AppTheme.accentBlue,
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
              color: AppTheme.textPrimaryDark,
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
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.darkBgBase,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              timestamp,
              style: const TextStyle(
                  color: AppTheme.accentBlue,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  color: AppTheme.textPrimaryDark, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }

  // 📍 Tab 3: Venue & RSVP
  Widget _buildVenueTabView(
      AppProvider appProvider, StreamerModel streamer, String langCode) {
    final isAttending = appProvider.isAttendingInPerson(widget.streamId);
    final availableSeats = appProvider.getAvailableSeats(widget.streamId);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      children: [
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
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppTheme.accentRed, size: 22),
                  const SizedBox(width: AppTheme.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          streamer.getLocalizedVenue(langCode),
                          style: const TextStyle(
                              color: AppTheme.textPrimaryDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        Text(
                          '${streamer.getLocalizedCity(langCode)}, Eastern Province, KSA',
                          style: const TextStyle(
                              color: AppTheme.textMutedDark, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface2,
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
                            ? AppTheme.accentBlue
                            : AppTheme.textMutedDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    Icon(
                      availableSeats > 0
                          ? Icons.event_seat_rounded
                          : Icons.block_rounded,
                      color: availableSeats > 0
                          ? AppTheme.accentBlue
                          : AppTheme.textMutedDark,
                      size: 15,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isAttending
                        ? AppTheme.darkSurface3
                        : AppTheme.accentRed,
                    foregroundColor:
                        isAttending ? AppTheme.accentBlue : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.textPrimaryDark,
              side: const BorderSide(color: AppTheme.darkBorderSubtle),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
            icon: const Icon(Icons.directions_car_rounded,
                color: AppTheme.accentBlue, size: 16),
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
