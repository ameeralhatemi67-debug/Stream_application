import '../../../../core/widgets/ds/canopy_content_motion.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/reminder_push_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../models/streamer_models.dart';
import '../../models/upcoming_schedule.dart';
import 'upcoming_schedule_editor_sheet.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import '../../../../core/widgets/ds/ca_feedback.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../discovery/presentation/widgets/bookmark_button.dart';

class UpcomingScheduleTab extends StatefulWidget {
  const UpcomingScheduleTab({super.key, required this.streamer});
  final StreamerModel streamer;

  @override
  State<UpcomingScheduleTab> createState() => _UpcomingScheduleTabState();
}

class _UpcomingScheduleTabState extends State<UpcomingScheduleTab> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<AppProvider>();
      if (provider.upcomingSchedulesFor(widget.streamer.streamerId) == null) {
        provider.loadUpcomingSchedules(widget.streamer.streamerId);
      }
      provider.ensureTagsLoaded();
    });
    // Schedules change over hours or days, not seconds; polling every 30 s per
    // open profile was pure waste (audit NET-11). Opening the tab loads fresh.
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted &&
          TickerMode.valuesOf(context).enabled &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        context
            .read<AppProvider>()
            .loadUpcomingSchedules(widget.streamer.streamerId);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UpcomingScheduleTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamer.streamerId != widget.streamer.streamerId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context
              .read<AppProvider>()
              .loadUpcomingSchedules(widget.streamer.streamerId);
        }
      });
    }
  }

  Future<void> _edit([UpcomingSchedule? schedule]) async {
    await showCaSheet<void>(context,
        title: 'upcoming.edit'.tr(),
        framed: false,
        bareChrome: true,
        body: UpcomingScheduleEditorSheet(
            streamerId: widget.streamer.streamerId, existing: schedule));
  }

  Future<void> _delete(UpcomingSchedule schedule) async {
    final confirmed = await showCaDialog<bool>(
      context: context,
      builder: (dialogContext) => CaAlertDialog(
        title: Text('upcoming.delete_title'.tr()),
        content: Text('upcoming.delete_message'.tr()),
        actions: [
          CaButton(
              label: 'upcoming.cancel'.tr(),
              variant: CaButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext, false)),
          CaButton(
              label: 'upcoming.delete'.tr(),
              variant: CaButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext, true)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<AppProvider>().deleteUpcomingSchedule(schedule);
    } catch (_) {
      if (mounted) _message('upcoming.save_failed'.tr());
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _remind(UpcomingSchedule schedule) async {
    final provider = context.read<AppProvider>();
    if (!provider.isLoggedInStreamer) {
      final signIn = await showCaDialog<bool>(
        context: context,
        builder: (dialogContext) => CaAlertDialog(
          title: Text('upcoming.sign_in_title'.tr()),
          content: Text('upcoming.sign_in_body'.tr()),
          actions: [
            CaButton(
                label: 'upcoming.cancel'.tr(),
                variant: CaButtonVariant.text,
                onPressed: () => Navigator.pop(dialogContext, false)),
            CaButton(
                label: 'upcoming.sign_in'.tr(),
                variant: CaButtonVariant.text,
                onPressed: () => Navigator.pop(dialogContext, true)),
          ],
        ),
      );
      if (signIn == true && mounted) context.push('/welcome');
      return;
    }
    try {
      await provider.toggleCardReminder(schedule.id,
          language: context.locale.languageCode);
      if (mounted) {
        _message((provider.hasCardReminder(schedule.id)
                ? 'upcoming.reminder_saved'
                : 'upcoming.reminder_removed')
            .tr());
        if (provider.hasCardReminder(schedule.id) &&
            provider.reminderPushStatus != ReminderPushStatus.granted) {
          _message((provider.reminderPushStatus == ReminderPushStatus.notGranted
                  ? 'upcoming.permission_denied'
                  : 'upcoming.permission_unavailable')
              .tr());
        }
      }
    } catch (_) {
      if (mounted) _message('upcoming.save_failed'.tr());
    }
  }

  void _share(UpcomingSchedule schedule) {
    final language = context.locale.languageCode;
    final next = schedule.nextStartUtc(DateTime.now());
    if (next == null) return;
    final saudi = next.add(const Duration(hours: 3));
    final localizations = MaterialLocalizations.of(context);
    final when = '${localizations.formatMediumDate(saudi)} '
        '${localizations.formatTimeOfDay(TimeOfDay(hour: saudi.hour, minute: saudi.minute))} '
        '${'upcoming.saudi_time'.tr()}';
    final days = schedule.isSpecial
        ? ''
        : '\n${_weekdayLabels(schedule.weekdays).join(', ')}';
    final handle = widget.streamer.youtubeHandle.trim().replaceFirst('@', '');
    final channel = handle.isEmpty ? '' : '\nhttps://www.youtube.com/@$handle';
    Share.share('${schedule.title(language)}\n$when$days$channel',
        subject: schedule.title(language));
  }

  List<String> _weekdayLabels(List<int> weekdays) => [
        for (final day in (List<int>.from(weekdays)..sort()))
          'upcoming.day_$day'.tr(),
      ];

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    context.select<
            AppProvider, (bool, bool, List<UpcomingSchedule>?, String?, int)>(
        (p) => (
              p.isApprovedStreamer,
              p.isOwnStreamerProfile(widget.streamer.streamerId),
              p.upcomingSchedulesFor(widget.streamer.streamerId),
              p.upcomingScheduleErrorFor(widget.streamer.streamerId),
              Object.hashAll(
                  (p.upcomingSchedulesFor(widget.streamer.streamerId) ?? [])
                      .map((s) => p.hasCardReminder(s.id)))
            ));
    final id = widget.streamer.streamerId;
    final own = provider.isApprovedStreamer &&
        provider.isOwnStreamerProfile(id) &&
        !widget.streamer.isOrganization;
    final rows = provider.upcomingSchedulesFor(id);
    final error = provider.upcomingScheduleErrorFor(id);
    final now = DateTime.now();
    final upcoming = rows == null
        ? <UpcomingSchedule>[]
        : rows.where((s) => s.nextStartUtc(now) != null).toList()
      ..sort((a, b) => a.nextStartUtc(now)!.compareTo(b.nextStartUtc(now)!));

    return LayoutBuilder(builder: (context, constraints) {
      final available =
          (constraints.maxWidth - 2 * AppTheme.spaceLg).clamp(0.0, 1200.0);
      final columns =
          ((available + AppTheme.spaceMd) / 292).floor().clamp(1, 4);
      final cardWidth =
          (available - (columns - 1) * AppTheme.spaceMd) / columns;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Center(
            child: SizedBox(
          width: available,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // The tab sits on the green panel, so the heading is white and the
            // schedule entries are white cards like the archive tiles.
            Row(children: [
              Expanded(
                  child: Text('upcoming.title'.tr(),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Canopy.paper))),
              if (own)
                CaButton(
                    label: 'upcoming.add'.tr(),
                    icon: CaGlyph.plus,
                    variant: CaButtonVariant.secondary,
                    onPressed: () => _edit()),
            ]),
            const SizedBox(height: AppTheme.spaceMd),
            if (error != null)
              CaCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('upcoming.load_failed'.tr(),
                        style: const TextStyle(color: Canopy.liveCrimson)),
                    const SizedBox(height: AppTheme.spaceSm),
                    CaButton(
                        label: 'upcoming.retry'.tr(),
                        icon: CaGlyph.refresh,
                        variant: CaButtonVariant.text,
                        onPressed: () => provider.loadUpcomingSchedules(id)),
                  ]))
            else if (rows == null)
              const CaCard(child: CaPageSkeleton())
            else if (upcoming.isEmpty)
              CaCard(
                  child: CaEmptyState(
                      icon: CaGlyph.cal,
                      title: 'profile.no_upcoming_schedule'.tr(),
                      body: ''))
            else
              Wrap(
                spacing: AppTheme.spaceMd,
                runSpacing: AppTheme.spaceMd,
                children: [
                  for (final schedule in upcoming)
                    SizedBox(
                        width: cardWidth,
                        child: _ScheduleCard(
                          schedule: schedule,
                          days: _weekdayLabels(schedule.weekdays),
                          isOwner: own,
                          reminderOn: provider.hasCardReminder(schedule.id),
                          onShare: () => _share(schedule),
                          onReminder: () => _remind(schedule),
                          onEdit: () => _edit(schedule),
                          onDelete: () => _delete(schedule),
                        )),
                ],
              ),
          ]),
        )),
      );
    });
  }
}

class _ScheduleCard extends StatefulWidget {
  const _ScheduleCard(
      {required this.schedule,
      required this.days,
      required this.isOwner,
      required this.reminderOn,
      required this.onShare,
      required this.onReminder,
      required this.onEdit,
      required this.onDelete});
  final UpcomingSchedule schedule;
  final List<String> days;
  final bool isOwner;
  final bool reminderOn;
  final VoidCallback onShare, onReminder, onEdit, onDelete;

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  final GlobalKey<PopupMenuButtonState<String>> _menuKey = GlobalKey();
  bool _expanded = false;

  /// The colour the presenter picked for this entry.
  Color get _color => switch (widget.schedule.colorKey) {
        'gold' => AppTheme.warning,
        'berry' => Canopy.liveCrimson,
        'slate' => AppTheme.media,
        _ => Canopy.brandGreen,
      };

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final next = widget.schedule.nextStartUtc(DateTime.now());
    if (next == null) return const SizedBox.shrink();
    final saudi = next.add(const Duration(hours: 3));
    final localizations = MaterialLocalizations.of(context);
    final description = widget.schedule.description(language);
    final textTheme = Theme.of(context).textTheme;
    final time = localizations
        .formatTimeOfDay(TimeOfDay(hour: saudi.hour, minute: saudi.minute));
    return Semantics(
      label: '${widget.schedule.title(language)}, ${'upcoming.planned'.tr()}',
      child: GestureDetector(
        onLongPress: () => _menuKey.currentState?.showButtonMenu(),
        child: CaCard(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _DateBadge(
                  color: _color,
                  month: DateFormat.MMM(language).format(saudi),
                  day: localizations.formatDecimal(saudi.day)),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        (widget.schedule.isSpecial
                                ? 'upcoming.special'
                                : 'upcoming.planned')
                            .tr(),
                        style: textTheme.labelSmall?.copyWith(
                            color: _color, fontWeight: FontWeight.w700)),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(widget.schedule.title(language),
                        style: textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppTheme.spaceXs),
                    Row(children: [
                      const CaIcon(CaGlyph.clock, size: CanopySize.inlineIcon),
                      const SizedBox(width: AppTheme.spaceXs),
                      Flexible(
                          child: Text(
                              '${localizations.formatMediumDate(saudi)} · $time',
                              style: textTheme.bodySmall?.copyWith(
                                  color: Canopy.ink,
                                  fontWeight: FontWeight.w600))),
                    ]),
                    Text('upcoming.saudi_time'.tr(),
                        style: textTheme.bodySmall),
                  ])),
              PopupMenuButton<String>(
                key: _menuKey,
                tooltip: 'upcoming.actions'.tr(),
                icon: const CaIcon(CaGlyph.dots),
                onSelected: (value) => switch (value) {
                  'share' => widget.onShare(),
                  'remind' => widget.onReminder(),
                  'edit' => widget.onEdit(),
                  _ => widget.onDelete(),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'share', child: Text('upcoming.share'.tr())),
                  PopupMenuItem(
                      value: 'remind',
                      child: Text((widget.reminderOn
                              ? 'upcoming.remove_reminder'
                              : 'upcoming.reminder')
                          .tr())),
                  if (widget.isOwner) ...[
                    PopupMenuItem(
                        value: 'edit', child: Text('upcoming.edit'.tr())),
                    PopupMenuItem(
                        value: 'delete', child: Text('upcoming.delete'.tr())),
                  ],
                ],
              ),
            ]),
            if (!widget.schedule.isSpecial && widget.days.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceMd),
              Wrap(
                  spacing: AppTheme.spaceXs,
                  runSpacing: AppTheme.spaceXs,
                  children: [
                    for (final day in widget.days)
                      _Pill(label: day, color: _color),
                  ]),
            ],
            if (widget.schedule.tags.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Wrap(
                  spacing: AppTheme.spaceXs,
                  runSpacing: AppTheme.spaceXs,
                  children: [
                    for (final tag in widget.schedule.tags)
                      Directionality(
                          textDirection: TextDirection.ltr,
                          child: _Pill(label: tag, color: Canopy.brandGreen)),
                  ]),
            ],
            if (description.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Text(description,
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: textTheme.bodyMedium),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip:
                      (_expanded ? 'upcoming.show_less' : 'upcoming.show_more')
                          .tr(),
                  color: Canopy.brandGreen,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ],
            const SizedBox(height: AppTheme.spaceMd),
            BookmarkButton(schedule: widget.schedule),
            const SizedBox(height: AppTheme.spaceSm),
            CaButton(
                label: (widget.reminderOn
                        ? 'upcoming.remove_reminder'
                        : 'upcoming.reminder')
                    .tr(),
                icon: widget.reminderOn ? CaGlyph.check : CaGlyph.bell,
                confirm: widget.reminderOn,
                variant: widget.reminderOn
                    ? CaButtonVariant.secondary
                    : CaButtonVariant.primary,
                onPressed: widget.onReminder),
          ]),
        ),
      ),
    );
  }
}

/// The date of the next start, in the colour the presenter chose.
class _DateBadge extends StatelessWidget {
  const _DateBadge(
      {required this.color, required this.month, required this.day});
  final Color color;
  final String month, day;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ExcludeSemantics(
        child: Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
            decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(CanopyRadius.input)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(month,
                  style: textTheme.labelSmall?.copyWith(
                      color: Canopy.paper, fontWeight: FontWeight.w600)),
              Text(day,
                  style: textTheme.titleLarge?.copyWith(
                      color: Canopy.paper, fontWeight: FontWeight.w700)),
            ])));
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: Canopy.mint,
          borderRadius: BorderRadius.circular(CanopyRadius.pill)),
      child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppTheme.spaceSm, vertical: AppTheme.spaceXs),
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Canopy.ink))));
}
