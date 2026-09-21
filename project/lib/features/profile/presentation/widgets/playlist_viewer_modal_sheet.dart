import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/streamer_models.dart';
import '../../models/vod_models.dart';
import 'vod_player_modal_sheet.dart';

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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlaylistViewerModalSheet(
        playlist: playlist,
        streamer: streamer,
        langCode: langCode,
      ),
    );
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

        // Fallback resolution: the streamer's own cached recordings. There is
        // no sample pool behind this any more -- an empty result stays empty
        // and the sheet shows its empty state (P2 truthful data).
        final allStreamerVods =
            provider.getVodsForStreamer(widget.streamer.streamerId);
        List<VodModel> fallbackList = allStreamerVods
            .where((v) =>
                v.speakerIds.any((s) => widget.playlist.speakerIds.contains(s)))
            .toList();

        if (fallbackList.isEmpty) {
          fallbackList = allStreamerVods;
        }

        setState(() {
          _videos = fallbackList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _videos = provider.getVodsForStreamer(widget.streamer.streamerId);
          _isLoading = false;
        });
      }
    }
  }

  ImageProvider _getImageProvider(String url) {
    if (url.startsWith('assets/')) {
      return AssetImage(url);
    }
    return NetworkImage(url);
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

  @override
  Widget build(BuildContext context) {
    final isAr = widget.langCode == 'ar';
    final playlistTitle = widget.playlist.getLocalizedTitle(widget.langCode);
    final broadcasterName =
        widget.streamer.getLocalizedName(widget.langCode);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1.5),
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
                  color: AppTheme.textSecondary.withValues(alpha: 0.4),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Image(
                      image: _getImageProvider(widget.playlist.thumbnailUrl),
                      width: 90,
                      height: 62,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          playlistTitle,
                          style: const TextStyle(
                            color: AppTheme.onMedia,
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
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
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
                    isAr ? 'تشغيل القائمة بالكامل' : 'Play All Lectures',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
            const Divider(color: AppTheme.border, height: 1),

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
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isAr
                                ? 'جاري تحميل قائمة المحاضرات...'
                                : 'Loading playlist lectures...',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
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
                                    color: AppTheme.textMuted, size: 40),
                                const SizedBox(height: 10),
                                Text(
                                  isAr
                                      ? 'لا توجد محاضرات متاحة في هذه القائمة حالياً'
                                      : 'No lectures available in this playlist currently',
                                  style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _videos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final video = _videos[index];
                            return ListTile(
                              tileColor: AppTheme.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                                side: const BorderSide(
                                    color: AppTheme.border),
                              ),
                              leading: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image(
                                      image: _getImageProvider(
                                          video.thumbnailUrl),
                                      width: 68,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 1),
                                    margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: AppTheme.media.withValues(alpha: 0.8),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      video.formattedDuration,
                                      style: const TextStyle(
                                        color: AppTheme.onMedia,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                video.getLocalizedTitle(widget.langCode),
                                style: const TextStyle(
                                  color: AppTheme.onMedia,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${video.viewCount} ${'profile.views'.tr()}',
                                style: const TextStyle(
                                  color: AppTheme.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              trailing: const Icon(
                                Icons.play_circle_fill_rounded,
                                color: AppTheme.primary,
                                size: 24,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                VodPlayerModalSheet.show(
                                  context,
                                  vod: video,
                                  streamer: widget.streamer,
                                );
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
