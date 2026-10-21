import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/safe_image_provider.dart';
import '../../../core/widgets/ds/ca_button.dart';
import '../../../core/widgets/ds/canopy_content_motion.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_surfaces.dart';
import '../../profile/presentation/widgets/vod_player_modal_sheet.dart';
import '../models/bookmark_entry.dart';

class BookmarksSheet extends StatefulWidget {
  const BookmarksSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final provider = context.read<AppProvider>();
    final selected = await showCaSheet<BookmarkEntry>(context,
        title: '',
        framed: false,
        fullWidthOnPhone: true,
        flushOnPhone: true,
        body: ChangeNotifierProvider<AppProvider>.value(
            value: provider, child: const BookmarksSheet()));
    if (selected == null || !context.mounted) return;
    if (selected.kind == BookmarkKind.recording && selected.vod != null) {
      await VodPlayerModalSheet.show(context,
          vod: selected.vod!,
          streamer: provider.getStreamerById(selected.streamerId));
    } else if (selected.kind == BookmarkKind.upcoming) {
      context.push('/profile/${selected.streamerId}');
    }
  }

  @override
  State<BookmarksSheet> createState() => _BookmarksSheetState();
}

class _BookmarksSheetState extends State<BookmarksSheet> {
  BookmarkKind? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppProvider>().loadBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries =
        context.select<AppProvider, List<BookmarkEntry>>((p) => p.bookmarks);
    final loading =
        context.select<AppProvider, bool>((p) => p.isLoadingBookmarks);
    final failed =
        context.select<AppProvider, bool>((p) => p.bookmarkLoadFailed);
    final visible =
        entries.where((e) => _filter == null || e.kind == _filter).toList();
    return SafeArea(
        top: false,
        child: CaSheet(
            title: 'feed.bookmarks_sheet_title'.tr(),
            bareChrome: true,
            onClose: () => Navigator.pop(context),
            body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entries.isNotEmpty) ...[
                    Wrap(
                        spacing: AppTheme.spaceSm,
                        runSpacing: AppTheme.spaceSm,
                        children: [
                          for (final kind in [null, ...BookmarkKind.values])
                            ChoiceChip(
                              label: Text((kind == null
                                      ? 'bookmarks.all'
                                      : kind == BookmarkKind.recording
                                          ? 'bookmarks.recordings'
                                          : 'profile.upcoming_tab')
                                  .tr()),
                              selected: _filter == kind,
                              onSelected: (_) => setState(() => _filter = kind),
                            ),
                        ]),
                    const SizedBox(height: AppTheme.spaceLg),
                  ],
                  if (failed) ...[
                    Text('bookmarks.load_failed'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Canopy.liveCrimson)),
                    Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: CaButton(
                            label: 'upcoming.retry'.tr(),
                            icon: CaGlyph.refresh,
                            variant: CaButtonVariant.text,
                            loading: loading,
                            onPressed: () =>
                                context.read<AppProvider>().loadBookmarks())),
                    const SizedBox(height: AppTheme.spaceMd),
                  ],
                  if (loading && entries.isEmpty)
                    const CaPageSkeleton()
                  else if (visible.isEmpty && !failed)
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: AppTheme.spaceXl),
                        child: Column(children: [
                          const CaIcon(CaGlyph.bookmark,
                              size: CanopySize.emptyArtHeight / 2),
                          const SizedBox(height: AppTheme.spaceMd),
                          Text('feed.no_bookmarks'.tr(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: AppTheme.spaceSm),
                          Text('bookmarks.empty_hint'.tr(),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ]))
                  else
                    for (var i = 0; i < visible.length; i++) ...[
                      if (i > 0) const Divider(height: AppTheme.spaceXl),
                      _BookmarkRow(entry: visible[i]),
                    ],
                ])));
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({required this.entry});
  final BookmarkEntry entry;

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final theme = Theme.of(context).textTheme;
    final broadcaster = context.select<AppProvider, String?>(
        (p) => p.getStreamerById(entry.streamerId)?.getLocalizedName(language));
    final pending =
        context.select<AppProvider, bool>((p) => p.isBookmarkPending(entry.id));
    final recording = entry.kind == BookmarkKind.recording;
    final title = recording
        ? entry.vod?.getLocalizedTitle(language)
        : entry.schedule?.title(language);
    final next = entry.scheduleUnavailable
        ? null
        : entry.schedule?.nextStartUtc(DateTime.now());
    final date = next?.add(const Duration(hours: 3));
    final localizations = MaterialLocalizations.of(context);
    final detail = recording
        ? entry.vod?.recordedDate
        : date == null
            ? 'bookmarks.schedule_unavailable'.tr()
            : '${localizations.formatMediumDate(date)} · '
                '${localizations.formatTimeOfDay(TimeOfDay(hour: date.hour, minute: date.minute))}';
    final openable = recording ? entry.vod != null : broadcaster != null;
    final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title ?? 'bookmarks.unavailable_recording'.tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.titleSmall),
          if (broadcaster != null) ...[
            const SizedBox(height: AppTheme.spaceXs),
            Text(broadcaster,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall?.copyWith(color: Canopy.brandGreen)),
          ],
          if (detail != null && detail.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceXs),
            Text(detail, style: theme.bodySmall),
          ],
          if (!recording && date != null)
            Text('upcoming.saudi_time'.tr(), style: theme.labelSmall),
        ]);
    final preview = ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: AspectRatio(
          aspectRatio:
              recording || MediaQuery.textScalerOf(context).scale(1) < 1.8
                  ? 16 / 9
                  : 1,
          child: recording
              ? Stack(fit: StackFit.expand, children: [
                  ColoredBox(
                      color: Canopy.mint,
                      child: entry.vod == null
                          ? const Center(child: CaIcon(CaGlyph.videooff))
                          : Image(
                              image: buildSafeImageProvider(
                                  path: entry.vod!.thumbnailUrl.isNotEmpty
                                      ? entry.vod!.thumbnailUrl
                                      : 'https://img.youtube.com/vi/${entry.vod!.youtubeVideoId}/hqdefault.jpg'),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const ColoredBox(color: Canopy.forestDeep),
                              frameBuilder: (_, child, frame, synchronous) =>
                                  synchronous || frame != null
                                      ? child
                                      : const ColoredBox(color: Canopy.mint))),
                  if (openable) ...[
                    const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppGradients.mediaScrim)),
                    const Center(
                        child: CaIcon(CaGlyph.play, color: Canopy.paper)),
                  ],
                ])
              : ColoredBox(
                  color: Canopy.mint,
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CaIcon(CaGlyph.cal),
                        if (date != null)
                          Text(localizations.formatDecimal(date.day),
                              style: theme.titleLarge),
                      ])),
        ));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
          child: Semantics(
              button: true,
              enabled: openable,
              label: recording
                  ? 'bookmarks.play'.tr()
                  : 'bookmarks.view_channel'.tr(),
              child: Material(
                  color: Canopy.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                      onTap:
                          openable ? () => Navigator.pop(context, entry) : null,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppTheme.spaceXs),
                          child: LayoutBuilder(builder: (context, bounds) {
                            final stacked = bounds.maxWidth < 230 ||
                                MediaQuery.textScalerOf(context).scale(1) >=
                                    1.8;
                            return stacked
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        SizedBox(width: 128, child: preview),
                                        const SizedBox(
                                            height: AppTheme.spaceSm),
                                        text,
                                      ])
                                : Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        SizedBox(
                                            width: bounds.maxWidth < 400
                                                ? 104
                                                : 144,
                                            child: preview),
                                        const SizedBox(width: AppTheme.spaceMd),
                                        Expanded(child: text),
                                      ]);
                          })))))),
      const SizedBox(width: AppTheme.spaceXs),
      CaIconButton(
          bare: true,
          icon: CaGlyph.trash,
          selected: true,
          label: 'bookmarks.remove'.tr(),
          onPressed: pending
              ? null
              : () async {
                  try {
                    await context
                        .read<AppProvider>()
                        .removeSavedBookmark(entry);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('bookmarks.save_failed'.tr())));
                    }
                  }
                }),
    ]);
  }
}
