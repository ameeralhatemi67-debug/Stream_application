import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../profile/presentation/widgets/vod_player_modal_sheet.dart';
import '../../models/bookmark_entry.dart';
import '../bookmarks_sheet.dart';

/// Opens the saved list in Lantern and Arch (ADR-026): a Lantern sheet on a
/// phone and, on the website layout, a large Lantern dialog (a page of its
/// own would need a new route in the shared router). [BookmarksSheet] keeps
/// its filter and loads. What happens after a choice is the older sheet's:
/// a recording plays, an upcoming stream opens its channel.
Future<void> showLanternBookmarks(BuildContext context) async {
  final provider = context.read<AppProvider>();
  Widget body(BuildContext _) => ChangeNotifierProvider<AppProvider>.value(
      value: provider, child: const BookmarksSheet());
  final title = 'feed.bookmarks_sheet_title'.tr();
  final opened = context.lanternWide
      ? showLanternDialog<BookmarkEntry>(context,
          title: title, maxWidth: 860, body: body)
      : showLanternSheet<BookmarkEntry>(context, title: title, body: body);
  final selected = await opened;
  if (selected == null || !context.mounted) return;
  if (selected.kind == BookmarkKind.recording && selected.vod != null) {
    await VodPlayerModalSheet.show(context,
        vod: selected.vod!,
        streamer: provider.getStreamerById(selected.streamerId));
  } else if (selected.kind == BookmarkKind.upcoming) {
    context.push('/profile/${selected.streamerId}');
  }
}

/// The saved list: All saved / Recordings / Upcoming, a row per item with
/// its picture, one main action and Remove, the empty state, and the
/// partly failed state with Try again.
class LanternBookmarksBody extends StatelessWidget implements LanternSkinWidget {
  const LanternBookmarksBody(
      {super.key,
      required this.entries,
      required this.visible,
      required this.filter,
      required this.onFilter,
      required this.loading,
      required this.failed,
      required this.onRetry,
      required this.onOpen});

  final List<BookmarkEntry> entries, visible;
  final BookmarkKind? filter;
  final ValueChanged<BookmarkKind?> onFilter;
  final bool loading, failed;
  final VoidCallback onRetry;
  final ValueChanged<BookmarkEntry> onOpen;

  @override
  Widget build(BuildContext context) => Column(
          key: const ValueKey('lantern-bookmarks'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entries.isNotEmpty) ...[
              LSegmented<BookmarkKind?>(
                  key: const ValueKey('lantern-bookmarks-tabs'),
                  expand: true,
                  segments: [
                    (value: null, label: 'bookmarks.all'.tr(), icon: null),
                    (
                      value: BookmarkKind.recording,
                      label: 'bookmarks.recordings'.tr(),
                      icon: null
                    ),
                    (
                      value: BookmarkKind.upcoming,
                      label: 'profile.upcoming_tab'.tr(),
                      icon: null
                    ),
                  ],
                  value: filter,
                  onChanged: onFilter),
              const SizedBox(height: 16),
            ],
            if (failed) ...[
              LBanner('bookmarks.load_failed'.tr(),
                  key: const ValueKey('lantern-bookmarks-failed'),
                  tone: LTone.warn,
                  action: LButton(
                      label: 'upcoming.retry'.tr(),
                      icon: LGlyph.refresh,
                      size: LButtonSize.small,
                      kind: LButtonKind.tonal,
                      loading: loading,
                      onPressed: onRetry)),
              const SizedBox(height: 14),
            ],
            if (loading && entries.isEmpty)
              for (var i = 0; i < 3; i++)
                const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LSkeleton(height: 86, radius: 20))
            else if (visible.isEmpty && !failed)
              LEmptyState(
                  key: const ValueKey('lantern-bookmarks-empty'),
                  icon: LGlyph.bookmark,
                  title: 'feed.no_bookmarks'.tr(),
                  body: 'bookmarks.empty_hint'.tr())
            else
              for (final e in visible)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _Saved(
                        key: ValueKey('lantern-bookmark-${e.id}'),
                        entry: e,
                        onOpen: () => onOpen(e))),
          ]);
}

class _Saved extends StatelessWidget {
  const _Saved({super.key, required this.entry, required this.onOpen});

  final BookmarkEntry entry;
  final VoidCallback onOpen;

  Future<void> _remove(BuildContext context) async {
    try {
      await context.read<AppProvider>().removeSavedBookmark(entry);
    } catch (_) {
      if (context.mounted) {
        lanternToast(context, 'bookmarks.save_failed'.tr(), warn: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final language = context.locale.languageCode;
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
    // Saudi time, as the older sheet shows it.
    final date = next?.add(const Duration(hours: 3));
    final localizations = MaterialLocalizations.of(context);
    final detail = recording
        ? entry.vod?.recordedDate
        : date == null
            ? 'bookmarks.schedule_unavailable'.tr()
            : '${localizations.formatMediumDate(date)} · '
                '${localizations.formatTimeOfDay(TimeOfDay(hour: date.hour, minute: date.minute))} '
                '${'upcoming.saudi_time'.tr()}';
    final openable = recording ? entry.vod != null : broadcaster != null;
    final gone = !openable || (!recording && date == null);

    final thumb = ClipRRect(
        borderRadius: BorderRadius.circular(Lantern.radiusTile),
        child: SizedBox(
            width: 112,
            height: 63,
            child: Stack(fit: StackFit.expand, children: [
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: AlignmentDirectional.topStart,
                          end: AlignmentDirectional.bottomEnd,
                          colors: [LanternTokens.goldLo, LanternTokens.ink]))),
              if (recording && entry.vod != null)
                Image(
                    image: buildSafeImageProvider(
                        path: entry.vod!.thumbnailUrl.isNotEmpty
                            ? entry.vod!.thumbnailUrl
                            : 'https://img.youtube.com/vi/${entry.vod!.youtubeVideoId}/hqdefault.jpg'),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              Center(
                  child: recording
                      ? Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: LanternTokens.nightGround
                                  .withValues(alpha: .55),
                              shape: BoxShape.circle),
                          child: LIcon(
                              entry.vod == null
                                  ? LGlyph.videooff
                                  : LGlyph.playfill,
                              size: 16,
                              color: LanternTokens.white))
                      : Column(mainAxisSize: MainAxisSize.min, children: [
                          const LIcon(LGlyph.calendar,
                              size: 18, color: LanternTokens.goldHi),
                          if (date != null)
                            Text(localizations.formatDecimal(date.day),
                                style: Lantern.displayStyle(16,
                                    color: LanternTokens.white, height: 1.1)),
                        ])),
            ])));
    final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title ?? 'bookmarks.unavailable_recording'.tr(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Lantern.textStyle(15,
                  color: t.fg, weight: FontWeight.w600, height: 1.35)),
          if (broadcaster != null)
            Text(broadcaster,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Lantern.textStyle(12.5,
                    color: t.goldInk, weight: FontWeight.w600, height: 1.4)),
          if (detail != null && detail.isNotEmpty)
            Text(detail,
                style: Lantern.textStyle(12.5, color: t.muted, height: 1.4)),
        ]);
    final main = openable
        ? LButton(
            key: ValueKey('lantern-bookmark-open-${entry.id}'),
            label: (recording ? 'bookmarks.play' : 'bookmarks.view_channel')
                .tr(),
            icon: recording ? LGlyph.play : LGlyph.eye,
            kind: LButtonKind.tonal,
            size: LButtonSize.small,
            onPressed: onOpen)
        : null;
    final remove = LIconButton(
        key: ValueKey('lantern-bookmark-remove-${entry.id}'),
        icon: LGlyph.trash,
        label: 'bookmarks.remove'.tr(),
        onPressed: pending ? null : () => _remove(context));
    return Opacity(
        opacity: gone ? .7 : 1,
        child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: gone ? t.sunk : t.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gone ? t.muted : t.line)),
            child: LayoutBuilder(
                builder: (context, box) => box.maxWidth >= 520
                    ? Row(children: [
                        thumb,
                        const SizedBox(width: 14),
                        Expanded(child: text),
                        if (main != null) ...[const SizedBox(width: 10), main],
                        const SizedBox(width: 4),
                        remove,
                      ])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              SizedBox(
                                  width: 88,
                                  child: FittedBox(
                                      fit: BoxFit.contain,
                                      alignment:
                                          AlignmentDirectional.topStart,
                                      child: thumb)),
                              const SizedBox(width: 12),
                              Expanded(child: text),
                            ]),
                            const SizedBox(height: 8),
                            Row(children: [
                              if (main != null) Flexible(child: main),
                              const Spacer(),
                              remove,
                            ]),
                          ]))));
  }
}
