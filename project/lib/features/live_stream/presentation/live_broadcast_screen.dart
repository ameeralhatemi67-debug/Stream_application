import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/ghost_comments.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/widgets/language_switcher.dart';
import '../../profile/models/streamer_models.dart';
import '../../profile/models/vod_models.dart';
import '../../map/presentation/widgets/venue_navigation_sheet.dart';
import 'abstract_video_player.dart';
import 'widgets/floating_reactions_overlay.dart';
import 'widgets/live_player_overlay_controls.dart';
import 'widgets/live_multi_speaker_overlay.dart';
import 'widgets/live_audio_stage_multi_speaker.dart';
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

  late TabController _tabController;
  StreamSourceType _sourceType = StreamSourceType.youtubeEmbed;
  StreamState _streamState = StreamState.live;
  bool _isPlaying = true;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _isHandRaised = false;
  bool _isReactionMenuOpen = false;

  @override
  void initState() {
    super.initState();
    // 3 Tabs: Chat, Sources, Venue
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<AppProvider>()
          .seedGhostChatIfNeeded(streamId: widget.streamId);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatTextController.dispose();
    _chatScrollController.dispose();
    super.dispose();
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

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final localComment = GhostComment(
      messageId: 'user_${now.millisecondsSinceEpoch}',
      streamId: widget.streamId,
      senderNameEn: 'You',
      senderNameAr: 'أنت',
      senderAvatar: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
      messageTextEn: text,
      messageTextAr: text,
      timestamp: timeStr,
      isCurrentUser: true,
      isGhostSimulation: false,
    );

    context.read<AppProvider>().addChatMessage(localComment);
    _chatTextController.clear();

    if (_chatScrollController.hasClients) {
      _chatScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _handleQuickReaction(String reactionType, String emoji) {
    _reactionsController.spawnReaction(reactionType);
    setState(() => _isReactionMenuOpen = false);

    final reactionComment = GhostComment(
      messageId: 'reaction_${DateTime.now().millisecondsSinceEpoch}',
      streamId: widget.streamId,
      senderNameEn: 'You',
      senderNameAr: 'أنت',
      senderAvatar: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
      messageTextEn: '$emoji Reacted',
      messageTextAr: '$emoji تفاعل',
      timestamp:
          '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      isCurrentUser: true,
    );
    context.read<AppProvider>().addChatMessage(reactionComment);
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
                // Floating Picture-in-Picture Mini-Player Button
                IconButton(
                  icon: const Icon(Icons.picture_in_picture_alt_rounded,
                      size: 20),
                  tooltip: 'live.mini_player_tooltip'.tr(),
                  onPressed: () {
                    appProvider.launchMiniPlayer(
                      videoId: _getStreamUrl(appProvider),
                      title: streamer.getLocalizedTitle(langCode),
                      streamerName: streamer.getLocalizedName(langCode),
                      streamId: widget.streamId,
                    );
                    context.pop();
                  },
                ),
                if (appProvider.isLoggedInStreamer && appProvider.isStreamerModeEnabled)
                  IconButton(
                    icon: const Icon(Icons.cell_tower_rounded, size: 20),
                    tooltip: 'live.rtmp_ip_tooltip'.tr(),
                    onPressed: () => RtmpIpSettingsDialog.show(context),
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

  Widget _buildVideoViewport(
      AppProvider appProvider, StreamerModel streamer, int viewerCount, String langCode,
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
            autoPlay: _isPlaying,
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
          if (!isAudioLive && (streamer.isOrganization || streamer.affiliatedSpeakers.isNotEmpty))
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
            currentSource: _sourceType,
            streamState: _streamState,
            viewerCount: viewerCount,
            isPlaying: _isPlaying,
            isMuted: _isMuted,
            isFullscreen: _isFullscreen,
            onTogglePlayPause: () {
              setState(() {
                _isPlaying = !_isPlaying;
                _streamState =
                    _isPlaying ? StreamState.live : StreamState.paused;
              });
            },
            onToggleMute: () => setState(() => _isMuted = !_isMuted),
            onToggleFullscreen: () =>
                setState(() => _isFullscreen = !_isFullscreen),
            onSelectSource: (source) => setState(() {
              _sourceType = source;
              _streamState = StreamState.live;
            }),
            onRetryConnection: () =>
                setState(() => _streamState = StreamState.live),
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
                _buildChatTabView(appProvider, langCode),
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
  Widget _buildChatTabView(AppProvider appProvider, String langCode) {
    final comments = appProvider.chatMessages;

    return Stack(
      children: [
        Column(
          children: [
            // Chat Stream List (Starts from bottom with newest messages, scroll up for older)
            Expanded(
              child: ListView.builder(
                controller: _chatScrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                reverse: true,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMd, vertical: 4),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.darkSurface3,
                          child: Text(
                            comment.getLocalizedSender(langCode).isNotEmpty
                                ? comment
                                    .getLocalizedSender(langCode)[0]
                                    .toUpperCase()
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
                                  text:
                                      '${comment.getLocalizedSender(langCode)}: ',
                                  style: TextStyle(
                                    color: comment.isCurrentUser
                                        ? AppTheme.accentRed
                                        : AppTheme.accentBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                TextSpan(
                                  text: comment.getLocalizedMessage(langCode),
                                  style: const TextStyle(
                                      color: AppTheme.textPrimaryDark,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          comment.timestamp,
                          style: const TextStyle(
                              color: AppTheme.textMutedDark, fontSize: 10),
                        ),
                      ],
                    ),
                  );
                },
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
