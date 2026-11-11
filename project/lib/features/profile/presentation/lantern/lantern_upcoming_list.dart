import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../discovery/models/bookmark_entry.dart';
import '../../models/upcoming_schedule.dart';
import '../../models/vod_models.dart';

/// Save or unsave a recording or a planned stream: the same provider calls
/// as the older designs' save button.
class LanternSaveButton extends StatelessWidget implements LanternSkinWidget {
  const LanternSaveButton({super.key, this.vod, this.schedule, this.glass = false})
      : assert((vod == null) != (schedule == null));

  final VodModel? vod;
  final UpcomingSchedule? schedule;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final id = vod == null
        ? BookmarkEntry.upcomingKey(schedule!.id)
        : BookmarkEntry.recording(vod!).id;
    final (saved, pending) = context.select<AppProvider, (bool, bool)>(
        (p) => (p.isBookmarked(id), p.isBookmarkPending(id)));
    return LIconButton(
        key: ValueKey('lantern-save-$id'),
        icon: saved ? LGlyph.bookmarkfill : LGlyph.bookmark,
        label: (saved ? 'lantern.channel.unsave' : 'lantern.channel.save').tr(),
        on: saved && !glass,
        glass: glass,
        onPressed: pending
            ? null
            : () async {
                final provider = context.read<AppProvider>();
                try {
                  if (vod != null) {
                    await provider.toggleVodBookmark(vod!);
                  } else {
                    await provider.toggleUpcomingBookmark(schedule!);
                  }
                } catch (_) {
                  if (context.mounted) {
                    lanternToast(context, 'bookmarks.save_failed'.tr(),
                        warn: true);
                  }
                }
              });
  }
}

/// The Upcoming tab of a channel in Lantern and Arch: the planned streams in
/// order of their next start. Loading, the error with Try again, and the
/// empty state are the ones of the older tab; the State of
/// UpcomingScheduleTab keeps the load, the timer and every action.
class LanternUpcomingList extends StatelessWidget implements LanternSkinWidget {
  const LanternUpcomingList(
      {super.key,
      required this.schedules,
      required this.loading,
      required this.failed,
      required this.owner,
      required this.reminderOn,
      required this.onRetry,
      required this.onAdd,
      required this.onEdit,
      required this.onDelete,
      required this.onShare,
      this.onRemind});

  /// The upcoming entries, sorted; empty while [loading] or after [failed].
  final List<UpcomingSchedule> schedules;
  final bool loading, failed, owner;
  final bool Function(String id) reminderOn;
  final VoidCallback onRetry, onAdd;
  final ValueChanged<UpcomingSchedule> onEdit, onDelete, onShare;

  /// Null when the build has no push delivery: no reminder buttons then.
  final ValueChanged<UpcomingSchedule>? onRemind;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final Widget body;
    if (failed) {
      body = LCard(
          child: LEmptyState(
              key: const ValueKey('lantern-upcoming-error'),
              icon: LGlyph.wifioff,
              tone: LTone.live,
              title: 'upcoming.load_failed'.tr(),
              action: LButton(
                  label: 'upcoming.retry'.tr(),
                  icon: LGlyph.refresh,
                  kind: LButtonKind.secondary,
                  onPressed: onRetry)));
    } else if (loading) {
      body = Column(
          key: const ValueKey('lantern-upcoming-loading'),
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LSkeleton(height: 94, radius: 20)),
          ]);
    } else if (schedules.isEmpty) {
      body = LCard(
          child: LEmptyState(
              key: const ValueKey('lantern-upcoming-empty'),
              icon: LGlyph.calendar,
              title: 'profile.no_upcoming_schedule'.tr()));
    } else {
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        for (final s in schedules)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanRow(
                  schedule: s,
                  owner: owner,
                  reminderOn: reminderOn(s.id),
                  onRemind: onRemind == null ? null : () => onRemind!(s),
                  onShare: () => onShare(s),
                  onEdit: () => onEdit(s),
                  onDelete: () => onDelete(s))),
      ]);
    }
    return Column(
        key: const ValueKey('lantern-upcoming'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (owner) ...[
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: LButton(
                    key: const ValueKey('lantern-upcoming-add'),
                    label: 'upcoming.add'.tr(),
                    icon: LGlyph.plus,
                    kind: LButtonKind.tonal,
                    size: LButtonSize.small,
                    onPressed: onAdd)),
            const SizedBox(height: 14),
          ],
          body,
          if (!failed && !loading && schedules.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('upcoming.saudi_time_note'.tr(),
                    style: Lantern.textStyle(12.5, color: t.muted))),
        ]);
  }
}

class _PlanRow extends StatelessWidget implements LanternSkinWidget {
  const _PlanRow(
      {required this.schedule,
      required this.owner,
      required this.reminderOn,
      required this.onShare,
      required this.onEdit,
      required this.onDelete,
      this.onRemind});

  final UpcomingSchedule schedule;
  final bool owner, reminderOn;
  final VoidCallback onShare, onEdit, onDelete;
  final VoidCallback? onRemind;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final next = schedule.nextStartUtc(DateTime.now());
    if (next == null) return const SizedBox.shrink();
    // Planned streams are set in Saudi time (UTC+3), as in the older tab.
    final saudi = next.add(const Duration(hours: 3));
    final m = MaterialLocalizations.of(context);
    final time =
        m.formatTimeOfDay(TimeOfDay(hour: saudi.hour, minute: saudi.minute));
    final days = [
      for (final d in (List<int>.from(schedule.weekdays)..sort()))
        'upcoming.day_$d'.tr(),
    ];
    final description = schedule.description(lang);
    final narrow = !context.lanternWide &&
        MediaQuery.sizeOf(context).width < 600;

    final date = Semantics(
        label: m.formatFullDate(saudi),
        child: ExcludeSemantics(
            child: Container(
                width: 62,
                height: 72,
                decoration: ShapeDecoration(
                    color: t.sunk,
                    shape: const LArchBorder(
                        side: BorderSide(color: LanternTokens.gold, width: 1.5),
                        bottom: 10)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),
                      Text(DateFormat.E(lang).format(saudi),
                          maxLines: 1,
                          style: Lantern.textStyle(10.5,
                              color: t.muted, height: 1.2)),
                      Text(m.formatDecimal(saudi.day),
                          style: Lantern.displayStyle(22,
                                  color: t.fg, height: 1.1)
                              .copyWith(fontFeatures: Lantern.tabular)),
                      Text(DateFormat.MMM(lang).format(saudi),
                          maxLines: 1,
                          style: Lantern.textStyle(10.5,
                              color: t.muted, height: 1.2)),
                    ]))));

    final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(spacing: 6, runSpacing: 4, children: [
            LTag(
                (schedule.isSpecial ? 'upcoming.special' : 'upcoming.planned')
                    .tr(),
                tone: schedule.isSpecial ? LTone.gold : LTone.neutral),
            for (final tag in schedule.tags)
              Directionality(
                  textDirection: TextDirection.ltr, child: LTag(tag)),
          ]),
          const SizedBox(height: 6),
          Text(schedule.title(lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Lantern.textStyle(15,
                  color: t.fg, weight: FontWeight.w600, height: 1.35)),
          const SizedBox(height: 3),
          Text(
              '${m.formatMediumDate(saudi)} · $time · ${'upcoming.saudi_time'.tr()}',
              style: Lantern.textStyle(13, color: t.muted, height: 1.4)),
          if (!schedule.isSpecial && days.isNotEmpty)
            Text('lantern.channel.planned_every'.tr(args: [days.join('، ')]),
                style: Lantern.textStyle(13, color: t.muted, height: 1.4)),
          if (description.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Lantern.textStyle(13.5, color: t.fg, height: 1.5))),
        ]);

    final actions = Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (onRemind != null)
            LButton(
                key: ValueKey('lantern-upcoming-remind-${schedule.id}'),
                label: (reminderOn
                        ? 'upcoming.remove_reminder'
                        : 'upcoming.reminder')
                    .tr(),
                icon: reminderOn ? LGlyph.check : LGlyph.bell,
                kind: reminderOn ? LButtonKind.secondary : LButtonKind.tonal,
                size: LButtonSize.small,
                onPressed: onRemind),
          LanternSaveButton(schedule: schedule),
          LIconButton(
              icon: LGlyph.share,
              label: 'upcoming.share'.tr(),
              onPressed: onShare),
          if (owner) ...[
            LIconButton(
                key: ValueKey('lantern-upcoming-edit-${schedule.id}'),
                icon: LGlyph.edit,
                label: 'upcoming.edit'.tr(),
                onPressed: onEdit),
            LIconButton(
                key: ValueKey('lantern-upcoming-delete-${schedule.id}'),
                icon: LGlyph.trash,
                label: 'upcoming.delete'.tr(),
                onPressed: onDelete),
          ],
        ]);

    return Container(
        key: ValueKey('lantern-upcoming-${schedule.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: t.line)),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      date,
                      const SizedBox(width: 14),
                      Expanded(child: text),
                    ]),
                    const SizedBox(height: 8),
                    actions,
                  ])
            : Row(children: [
                date,
                const SizedBox(width: 14),
                Expanded(child: text),
                const SizedBox(width: 12),
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: actions),
              ]));
  }
}
