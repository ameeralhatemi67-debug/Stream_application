import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_fixed_lines.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/streamer_models.dart';
import '../../models/vod_models.dart';
import 'vod_player_modal_sheet.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';

/// Modal bottom sheet for viewing and playing lectures inside a playlist.
/// Dynamically fetches playlist videos on demand with robust fallback resolution,
/// "Play All"trigger, and individual lecture inline playback.
class PlaylistViewerModalSheet extends StatefulWidget {
  final PlaylistModel playlist;
  final StreamerModel streamer;
  final String langCode;

  const PlaylistViewerModalSheet({
    super.key,
    required this.playlist,
    required this.streamer,
    required this.langCode,
  });

  static Future<void> show(
    BuildContext context, {
    required PlaylistModel playlist,
    required StreamerModel streamer,
    required String langCode,
  }) {
    return showCaSheet<void>(context,
        title: playlist.getLocalizedTitle(langCode),
        body: PlaylistViewerModalSheet(
            playlist: playlist, streamer: streamer, langCode: langCode),
        framed: false);
  }

  @override
  State<PlaylistViewerModalSheet> createState() =>
      _PlaylistViewerModalSheetState();
}

class _PlaylistViewerModalSheetState extends State<PlaylistViewerModalSheet> {
  late List<VodModel> _videos;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _videos = List.from(widget.playlist.videos);

    if (_videos.isEmpty) {
      _fetchPlaylistVideos();
    }
  }

  Future<void> _fetchPlaylistVideos() async {
    setState(() => _isLoading = true);

    final provider = context.read<AppProvider>();
    try {
      final fetched = await provider.fetchPlaylistVideos(
        streamerId: widget.streamer.streamerId,
        playlistId: widget.playlist.playlistId,
      );

      if (mounted) {
        if (fetched.isNotEmpty) {
          setState(() {
            _videos = fetched;
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _videos = [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _videos = [];
          _isLoading = false;
        });
      }
    }
  }

  void _playAll() {
    if (_videos.isNotEmpty) {
      Navigator.pop(context);
      VodPlayerModalSheet.show(
        context,
        vod: _videos.first,
        streamer: widget.streamer,
      );
    }
  }

  /// A lecture thumbnail, or a neutral tile when the playlist entry has no
  /// image yet -- an empty URL used to reach `NetworkImage('')`.
  Widget _thumbnail(String url,
      {required double width, required double height, required double radius}) {
    Widget fallback() => Container(
          width: width,
          height: height,
          color: Canopy.mint,
          alignment: Alignment.center,
          child: const Icon(Icons.video_library_rounded,
              size: 18, color: Canopy.haze),
        );
    final provider = resolveImageProviderOrNull(url);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: provider == null
          ? fallback()
          : Image(
              image: provider,
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final playlistTitle = widget.playlist.getLocalizedTitle(widget.langCode);
    final broadcasterName = widget.streamer.getLocalizedName(widget.langCode);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Canopy.dawn,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(color: Canopy.hairline, width: 1.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Sheet Top Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Canopy.slate.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Section: Thumbnail, Title, Streamer & "Play All"Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _thumbnail(widget.playlist.thumbnailUrl,
                      width: 90, height: 62, radius: AppTheme.radiusSm),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlistTitle,
                          style: const TextStyle(
                            color: Canopy.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$broadcasterName • ${_videos.isNotEmpty ? _videos.length : widget.playlist.videoCount} ${'profile.lectures_count'.tr()}',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: MaterialLocalizations.of(context).closeButtonTooltip,
                    child: IconButton(
                      icon:
                          const Icon(Icons.close_rounded, color: Canopy.slate),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Play All Action Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _videos.isNotEmpty ? _playAll : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onMedia,
                    disabledBackgroundColor:
                        AppTheme.primary.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    'design_copy.play_all_lectures'.tr(),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: Canopy.hairline, height: 1),

            // Video List or Loading State
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: HadayahLoadingIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'design_copy.loading_playlist_lectures'.tr(),
                            style: const TextStyle(
                              color: Canopy.haze,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _videos.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.playlist_play_rounded,
                                    color: Canopy.haze, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  'design_copy.no_lectures_available_in_this_playlist_currently'
                                      .tr(),
                                  style: const TextStyle(
                                    color: Canopy.slate,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Builder(builder: (context) {
                          final titleStyle = Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: Canopy.ink);
                          final viewsStyle = Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Canopy.haze);
                          // Every lecture row has the same height: a thumbnail
                          // or a 2-line title and the views line, whichever is
                          // taller.
                          final rowHeight = [
                            CanopySize.lectureImageHeight,
                            CaFixedLines.heightOf(context, titleStyle, 2) +
                                AppTheme.spaceXs +
                                CaFixedLines.heightOf(context, viewsStyle, 1),
                          ].reduce((a, b) => a > b ? a : b);
                          return ListView.separated(
                            padding: const EdgeInsets.all(AppTheme.spaceLg),
                            itemCount: _videos.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppTheme.spaceMd),
                            itemBuilder: (context, index) {
                              final video = _videos[index];
                              return CaCard(
                                padding: const EdgeInsets.all(AppTheme.spaceMd),
                                onTap: () {
                                  Navigator.pop(context);
                                  VodPlayerModalSheet.show(
                                    context,
                                    vod: video,
                                    streamer: widget.streamer,
                                  );
                                },
                                child: SizedBox(
                                  height: rowHeight,
                                  child: Row(children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          CanopyRadius.input),
                                      child: SizedBox(
                                        width: CanopySize.lectureImageWidth,
                                        height: CanopySize.lectureImageHeight,
                                        child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              _thumbnail(video.thumbnailUrl,
                                                  width: CanopySize
                                                      .lectureImageWidth,
                                                  height: CanopySize
                                                      .lectureImageHeight,
                                                  radius: 0),
                                              if (video.durationSeconds > 0)
                                                PositionedDirectional(
                                                  bottom: AppTheme.spaceXs,
                                                  end: AppTheme.spaceXs,
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      color: Canopy.forestDeep,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              CanopyRadius
                                                                  .pill),
                                                    ),
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                      child: Text(
                                                        video.formattedDuration,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                                color: Canopy
                                                                    .paper),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ]),
                                      ),
                                    ),
                                    const SizedBox(width: AppTheme.spaceMd),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          CaFixedLines(
                                              video.getLocalizedTitle(
                                                  widget.langCode),
                                              lines: 2,
                                              style: titleStyle),
                                          const SizedBox(
                                              height: AppTheme.spaceXs),
                                          CaFixedLines(
                                              '${video.viewCount} ${'profile.views'.tr()}',
                                              lines: 1,
                                              style: viewsStyle),
                                        ],
                                      ),
                                    ),
                                    const CaIcon(CaGlyph.play),
                                  ]),
                                ),
                              );
                            },
                          );
                        }),
            ),
          ],
        ),
      ),
    );
  }
}
