import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => UpcomingScheduleEditorSheet(
          streamerId: widget.streamer.streamerId, existing: schedule),
    );
  }

  Future<void> _delete(UpcomingSchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('upcoming.delete_title'.tr()),
        content: Text('upcoming.delete_message'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('upcoming.cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('upcoming.delete'.tr())),
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
      final signIn = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('upcoming.sign_in_title'.tr()),
          content: Text('upcoming.sign_in_body'.tr()),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text('upcoming.cancel'.tr())),
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text('upcoming.sign_in'.tr())),
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
    final provider = context.watch<AppProvider>();
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
            Row(children: [
              Expanded(
                  child: Text('upcoming.title'.tr(),
                      style: Theme.of(context).textTheme.titleLarge)),
              if (own)
                IconButton.filled(
                  tooltip: 'upcoming.add'.tr(),
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add_rounded),
                ),
            ]),
            const SizedBox(height: AppTheme.spaceMd),
            if (error != null) ...[
              Text('upcoming.load_failed'.tr(),
                  style: const TextStyle(color: AppTheme.danger)),
              TextButton.icon(
                  onPressed: () => provider.loadUpcomingSchedules(id),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text('upcoming.retry'.tr())),
            ] else if (rows == null)
              const Center(child: CircularProgressIndicator())
            else if (upcoming.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXl),
                child: Column(children: [
                  const Icon(Icons.event_busy_rounded,
                      color: AppTheme.textSecondary, size: 48),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text('profile.no_upcoming_schedule'.tr(),
                      textAlign: TextAlign.center),
                ]),
              )
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

  Color get _color => switch (widget.schedule.colorKey) {
        'gold' => AppTheme.warning,
        'berry' => AppTheme.danger,
        'slate' => AppTheme.media,
        _ => AppTheme.primary,
      };

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    final next = widget.schedule.nextStartUtc(DateTime.now());
    if (next == null) return const SizedBox.shrink();
    final saudi = next.add(const Duration(hours: 3));
    final localizations = MaterialLocalizations.of(context);
    final description = widget.schedule.description(language);
    return Semantics(
      label: '${widget.schedule.title(language)}, ${'upcoming.planned'.tr()}',
      child: GestureDetector(
        onLongPress: () => _menuKey.currentState?.showButtonMenu(),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          decoration: BoxDecoration(
            color: widget.schedule.isSpecial
                ? _color.withValues(alpha: 0.07)
                : AppTheme.surface,
            border: Border.all(color: _color.withValues(alpha: 0.55)),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: widget.schedule.isSpecial
                ? [
                    BoxShadow(
                      color: _color.withValues(alpha: 0.14),
                      blurRadius: 15,
                    )
                  ]
                : null,
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.calendar_today_rounded, color: _color, size: 20),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                  child: Text('upcoming.planned'.tr(),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700))),
              if (widget.schedule.isSpecial)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99)),
                  child: Text('upcoming.special'.tr(),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w700)),
                ),
              PopupMenuButton<String>(
                key: _menuKey,
                tooltip: 'upcoming.actions'.tr(),
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
            const SizedBox(height: AppTheme.spaceSm),
            Text(widget.schedule.title(language),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppTheme.spaceSm),
            Text(
                '${localizations.formatMediumDate(saudi)} · '
                '${localizations.formatTimeOfDay(TimeOfDay(hour: saudi.hour, minute: saudi.minute))}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('upcoming.saudi_time'.tr(),
                style: const TextStyle(color: AppTheme.textSecondary)),
            if (!widget.schedule.isSpecial)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                child: Text(widget.days.join(' · ')),
              ),
            if (widget.schedule.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.spaceSm),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in widget.schedule.tags)
                      Chip(
                          label: Text(tag),
                          visualDensity: VisualDensity.compact)
                  ],
                ),
              ),
            if (description.isNotEmpty) ...[
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: IconButton(
                  tooltip:
                      (_expanded ? 'upcoming.show_less' : 'upcoming.show_more')
                          .tr(),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded),
                ),
              ),
              if (_expanded) Text(description),
            ],
          ]),
        ),
      ),
    );
  }
}
