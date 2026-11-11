import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../profile/models/streamer_models.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/prayer_times.dart';
import '../../state/lessons_controller.dart';
import '../lessons_map.dart' show LessonsMap;
import '../lessons_modals.dart'
    show
        calendarLink,
        openExternal,
        showCancelSheet,
        showDeleteLessonSheet,
        showEditLessonSheet,
        showRestoreSheet;
import '../lessons_widgets.dart'
    show
        audienceLabel,
        cityLabel,
        languageLabel,
        prayerLabel,
        slotLabel,
        statusLabel,
        topicLabel,
        typeLabel;
import 'lantern_lessons_actions.dart';
import 'lantern_lessons_parts.dart';

/// A lesson that is not in the programme (removed, or a wrong link).
class LanternLessonMissing extends StatelessWidget implements LanternSkinWidget {
  const LanternLessonMissing({super.key});

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _page(BuildContext context) => LLessonsPage(
          title: 'lessons.nav.lesson'.tr(),
          children: [
            const SizedBox(height: 24),
            Container(
                decoration: BoxDecoration(
                    color: context.lt.surface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: context.lt.line)),
                child: LEmptyState(
                    key: const ValueKey('lantern-lesson-missing'),
                    icon: LGlyph.book,
                    title: 'lessons.lesson.not_found'.tr(),
                    body: 'lantern.lessons.lesson.not_found_body'.tr(),
                    action: LButton(
                        label: 'lessons.see_all'.tr(),
                        icon: LGlyph.calendar,
                        onPressed: () => context.go('/lessons/calendar')))),
          ]);
}

/// The lesson page in the Lantern design (/lessons/lesson/:id): where it
/// stands now, date, time and place, the actions, then about, the series,
/// the preacher, the mosque and that day's prayers. Everything comes from
/// LessonScreen.
class LanternLessonView extends StatelessWidget implements LanternSkinWidget {
  const LanternLessonView(
      {super.key,
      required this.lesson,
      required this.preacher,
      required this.mosque,
      required this.district,
      required this.prayer,
      required this.series,
      required this.sessions,
      required this.past,
      required this.admin,
      required this.report,
      required this.channel,
      required this.liveNow});

  final Lesson lesson;
  final Preacher? preacher;
  final Mosque? mosque;
  final District? district;
  final PrayerTimes prayer;
  final LessonSeries? series;
  final List<Lesson> sessions;
  final bool past, admin, liveNow;
  final LessonsReport? report;
  final StreamerModel? channel;

  // The page reads its colours under its own surface (day or night).
  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final wide = context.lanternWide;
    final lang = lessonsLang(context);
    final l = lesson, p = preacher, m = mosque, d = district;
    final cancelled = l.isCancelled;

    final chips = Wrap(spacing: 6, runSpacing: 6, children: [
      LTag(typeLabel(l.type), tone: LTone.gold, outlined: true),
      if (l.language != 'ar')
        LTag(languageLabel(l.language),
            tone: LTone.gold, icon: LGlyph.globe, outlined: true),
      if (l.audience != 'all') LTag(audienceLabel(l.audience)),
      if (series != null && l.seq != null)
        LTag('lessons.lesson.of'.tr(args: ['${l.seq}', '${series!.total}']),
            icon: LGlyph.history),
      if (!l.isPublic && !cancelled)
        LTag(statusLabel(l.status), tone: LTone.warn),
    ]);
    final title = Semantics(
        header: true,
        child: Text(l.title(lang),
            key: const ValueKey('lantern-lesson-title'),
            style: Lantern.displayStyle(wide ? 34 : 26,
                    color: cancelled ? t.muted : t.fg,
                    height: lHeadHeight(context))
                .copyWith(
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                    decorationColor: t.muted,
                    decorationThickness: 2)));

    final facts = [
      LFactTile(
          icon: LGlyph.calendar,
          label: 'lessons.lesson.date'.tr(),
          value:
              '${relativeDayLabel(l.date, lang) == weekdayName(l.date, lang) ? '' : '${relativeDayLabel(l.date, lang)} · '}${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)}',
          sub: hijriLabel(l.date, lang)),
      LFactTile(
          icon: LGlyph.clock,
          label: 'lessons.lesson.time'.tr(),
          value: l.exactTime != null
              ? clockLabel(hhmmToHours(l.exactTime!), lang)
              : slotLabel(l.slot),
          sub: 'lessons.time.adhan_line'.tr(args: [
            prayerLabel(l.slot),
            clockLabel(prayer.of(l.slot), lang),
            clockLabel(c.startHours(l), lang)
          ])),
      LFactTile(
          icon: LGlyph.pin,
          label: 'lessons.lesson.place'.tr(),
          value: m?.name(lang) ?? '',
          sub: d == null ? '' : '${d.name(lang)} · ${cityLabel(d.city)}',
          onTap: m == null
              ? null
              : () => context.push('/lessons/mosques/${m.id}')),
    ];
    final factsBlock = wide
        ? LGrid(columns: 3, gap: 10, children: facts)
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final f in facts)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: f),
          ]);

    final reminded = c.hasReminder(l.id);
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      if (past)
        if (c.signedIn)
          LChip(
              key: ValueKey('lantern-attend-${l.id}'),
              label: c.attended(l.id)
                  ? 'lessons.calendar.attended'.tr()
                  : 'lessons.calendar.did_attend'.tr(),
              selected: c.attended(l.id),
              icon: LGlyph.check,
              onTap: () => toggleLessonAttended(context, l))
        else
          const SizedBox.shrink()
      else
        LButton(
            key: const ValueKey('lantern-lesson-remind'),
            label: reminded
                ? 'lessons.lesson.reminder_on'.tr()
                : 'lessons.lesson.remind'.tr(),
            kind: reminded ? LButtonKind.dark : LButtonKind.primary,
            icon: LGlyph.bell,
            onPressed: canRemind(c, l) ? () => remindTap(context, l) : null),
      if (!past && l.isPublic)
        LButton(
            label: 'lessons.lesson.calendar'.tr(),
            kind: LButtonKind.secondary,
            icon: LGlyph.calendar,
            onPressed: () => openExternal(calendarLink(c, l, lang))),
      if (m?.directions != null)
        LButton(
            label: 'lessons.lesson.directions'.tr(),
            kind: LButtonKind.secondary,
            icon: LGlyph.directions,
            onPressed: () => openExternal(m!.directions!)),
      if (l.isPublic || cancelled)
        LButton(
            key: const ValueKey('lantern-lesson-share'),
            label: 'lessons.lesson.share'.tr(),
            kind: LButtonKind.ghost,
            icon: LGlyph.share,
            onPressed: () => showLanternShareSheet(context, l)),
    ]);

    final stream = l.streamed || channel != null
        ? Container(
            key: const ValueKey('lantern-lesson-stream'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: liveNow ? t.live : t.line, width: liveNow ? 1.5 : 1),
                boxShadow: liveNow
                    ? [BoxShadow(color: t.liveSoft, spreadRadius: 3)]
                    : null),
            child: Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: t.liveSoft,
                            borderRadius: BorderRadius.circular(14)),
                        child: liveNow
                            ? LBadge('lessons.lesson.live'.tr(),
                                kind: LBadgeKind.live, small: true)
                            : LIcon(LGlyph.live, size: 22, color: t.liveText)),
                    const SizedBox(width: 14),
                    ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: wide ? 420 : 230),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                  (liveNow
                                          ? 'lessons.lesson.live_now'
                                          : 'lessons.lesson.will_stream')
                                      .tr(),
                                  style: Lantern.textStyle(14.5,
                                      color: t.fg,
                                      weight: FontWeight.w600,
                                      height: 1.35)),
                              Text(
                                  p?.name(lang) ??
                                      'lessons.lesson.stream_note'.tr(),
                                  style: Lantern.textStyle(13,
                                      color: t.muted, height: 1.4)),
                            ])),
                  ]),
                  if (channel != null)
                    LButton(
                        label: 'lessons.lesson.watch'.tr(),
                        size: LButtonSize.small,
                        kind: liveNow ? LButtonKind.primary : LButtonKind.tonal,
                        icon: LGlyph.play,
                        onPressed: () => context.push(
                            channel!.isCurrentlyLive &&
                                    channel!.activeStreamId != null
                                ? '/live/${channel!.activeStreamId}'
                                : '/profile/${channel!.streamerId}')),
                ]))
        : null;

    final about = LPanel(
        title: 'lessons.lesson.about'.tr(),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (l.description(lang).isNotEmpty) ...[
                Text(l.description(lang),
                    style: Lantern.textStyle(15, color: t.fg, height: 1.8)),
                const SizedBox(height: 12),
              ],
              LKv([
                ('lessons.lesson.subject'.tr(), topicLabel(l.topic)),
                (
                  'lessons.lesson.language'.tr(),
                  '${languageLabel(l.language)}${l.interpretation == null ? '' : ' · ${'lessons.lesson.interp_into'.tr(args: [languageLabel(l.interpretation!)])}'}'
                ),
                ('lessons.lesson.audience'.tr(), audienceLabel(l.audience)),
                (
                  'lessons.facility.women'.tr(),
                  (l.womenSection
                          ? 'lantern.lessons.lesson.available'
                          : 'lantern.lessons.lesson.not_available')
                      .tr()
                ),
              ]),
            ]));

    final seriesPanel = series == null
        ? null
        : _SeriesPanel(series: series!, sessions: sessions, current: l);

    final adminBar = admin
        ? Container(
            key: const ValueKey('lantern-lesson-admin'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: t.sunk,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.line)),
            child: Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    LIcon(LGlyph.shield, size: 18, color: t.goldInk),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text(
                            l.status == 'pending'
                                ? 'lessons.lesson.pending_note'.tr()
                                : 'lessons.lesson.admin_note'.tr(),
                            style: Lantern.textStyle(14,
                                color: t.fg, weight: FontWeight.w600))),
                  ]),
                  if (l.isPublic)
                    LButton(
                        label: 'lessons.lesson.edit'.tr(),
                        size: LButtonSize.small,
                        kind: LButtonKind.secondary,
                        icon: LGlyph.edit,
                        onPressed: () => showEditLessonSheet(context, l)),
                  if (l.isPublic && !past)
                    LButton(
                        label: 'lessons.lesson.cancel'.tr(),
                        size: LButtonSize.small,
                        kind: LButtonKind.ghost,
                        icon: LGlyph.close,
                        onPressed: () => showCancelSheet(context, l)),
                  if (cancelled)
                    LButton(
                        label: 'lessons.restore.title'.tr(),
                        size: LButtonSize.small,
                        icon: LGlyph.check,
                        onPressed: () => showRestoreSheet(context, l)),
                  if (l.isPublic || cancelled)
                    LButton(
                        label: 'lessons.del.title'.tr(),
                        size: LButtonSize.small,
                        kind: LButtonKind.ghost,
                        icon: LGlyph.trash,
                        onPressed: () => showDeleteLessonSheet(context, l)),
                  if (past && l.isPublic && report == null)
                    LButton(
                        label: 'lessons.lesson.add_report'.tr(),
                        size: LButtonSize.small,
                        icon: LGlyph.edit,
                        onPressed: () =>
                            context.push('/admin/lessons/report/${l.id}')),
                  LButton(
                      label: 'lessons.admin.manage_preacher'.tr(),
                      size: LButtonSize.small,
                      kind: LButtonKind.ghost,
                      icon: LGlyph.person,
                      onPressed: () => context
                          .push('/admin/lessons/preachers/${l.preacherId}')),
                  if (report != null)
                    LTag(
                        'lessons.lesson.report_done'
                            .tr(args: ['${report!.attendance}']),
                        tone: LTone.ok,
                        icon: LGlyph.check),
                ]))
        : null;

    final main = <Widget>[
      chips,
      title,
      LLessonStatus(l),
      factsBlock,
      actions,
      if (stream != null) stream,
      about,
      if (seriesPanel != null) seriesPanel,
    ];

    final side = <Widget>[
      if (p != null)
        LPanel(
            onTap: () => context.push('/lessons/preachers/${p.id}'),
            label: p.name(lang),
            child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    LAvatar(
                        name: p.name(lang),
                        size: 56,
                        image: resolveImageProviderOrNull(p.photoUrl),
                        verified: true),
                    const SizedBox(width: 12),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.name(lang),
                                  style: Lantern.textStyle(15,
                                      color: t.fg,
                                      weight: FontWeight.w600,
                                      height: 1.3)),
                              if (p.title(lang).isNotEmpty)
                                Text(p.title(lang),
                                    style: Lantern.textStyle(12.5,
                                        color: t.muted, height: 1.4)),
                            ])),
                  ]),
                  LFollowButton(
                      kind: 'preacher', id: p.id, size: LButtonSize.small),
                ])),
      if (m != null)
        LPanel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              const LMapArt(height: 190),
              const SizedBox(height: 12),
              Text(m.name(lang),
                  style: Lantern.textStyle(15,
                      color: t.fg, weight: FontWeight.w600, height: 1.3)),
              if (d != null)
                Text('${d.name(lang)} · ${cityLabel(d.city)}',
                    style: Lantern.textStyle(13, color: t.muted, height: 1.4)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                LButton(
                    label: 'lessons.map.mosque_page'.tr(),
                    size: LButtonSize.small,
                    onPressed: () => context.push('/lessons/mosques/${m.id}')),
                if (m.verified &&
                    m.hasPin &&
                    LessonsMap.covers(m.latitude!, m.longitude!))
                  LButton(
                      label: 'lessons.calendar.on_map'.tr(),
                      size: LButtonSize.small,
                      kind: LButtonKind.secondary,
                      icon: LGlyph.map,
                      onPressed: () => context.go('/map?mosque=${m.id}')),
              ]),
            ])),
      LPanel(
          title:
              '${'lessons.lesson.prayer_times'.tr()} · ${cityLabel(d?.city ?? 'khobar')}',
          child: LPrayerStrip(times: prayer, active: l.slot)),
      if (c.signedIn && (l.isPublic || cancelled))
        Center(
            child: LButton(
                key: const ValueKey('lantern-lesson-flag'),
                label: 'lessons.lesson.flag_link'.tr(),
                kind: LButtonKind.ghost,
                icon: LGlyph.warn,
                onPressed: () => showLanternFlagSheet(context, l))),
    ];

    Widget column(List<Widget> xs, double gap) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < xs.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                xs[i]
              ]
            ]);

    return LLessonsPage(title: 'lessons.nav.lesson'.tr(), children: [
      LCrumb([
        ('lessons.nav.lessons'.tr(), () => context.go('/lessons')),
        ('lessons.calendar.title'.tr(), () => context.go('/lessons/calendar')),
        (l.title(lang), null),
      ]),
      const SizedBox(height: 18),
      if (adminBar != null) ...[adminBar, const SizedBox(height: 18)],
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: column(main, 16)),
          const SizedBox(width: 28),
          SizedBox(width: Lantern.sideChat, child: column(side, 14)),
        ])
      else
        column([...main, ...side], 16),
    ]);
  }
}

/// The weekly series: how far it has come and each session's state.
class _SeriesPanel extends StatelessWidget implements LanternSkinWidget {
  const _SeriesPanel(
      {required this.series, required this.sessions, required this.current});

  final LessonSeries series;
  final List<Lesson> sessions;
  final Lesson current;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final lang = lessonsLang(context);
    final done = sessions.where((x) => x.date.isBefore(c.today)).length;
    return LPanel(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
          Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Semantics(
                    header: true,
                    child: Text(
                        '${'lessons.lesson.series'.tr()}: ${series.title(lang)}',
                        style: Lantern.displayStyle(16,
                            color: t.fg, height: lHeadHeight(context)))),
                LFollowButton(
                    kind: 'series', id: series.id, size: LButtonSize.small),
              ]),
          const SizedBox(height: 12),
          LFillBar(done / (series.total <= 0 ? 1 : series.total),
              label: 'lessons.discover.done_of'
                  .tr(args: ['$done', '${series.total}'])),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final x in sessions) _session(context, c, t, lang, x),
          ]),
        ]));
  }

  Widget _session(BuildContext context, LessonsController c, LanternTokens t,
      String lang, Lesson x) {
    final here = x.id == current.id;
    final held = x.date.isBefore(c.today);
    final attended = held && c.attended(x.id);
    final (label, bg, fg) = x.isCancelled
        ? ('lessons.status.cancelled'.tr(), t.liveSoft, t.liveText)
        : attended
            ? ('lessons.lesson.attended'.tr(), t.okSoft, t.ok)
            : held
                ? ('lessons.lesson.held'.tr(), t.sunk, t.muted)
                : sameDay(x.date, c.today)
                    ? ('lessons.time.today'.tr(), t.sunk, t.goldInk)
                    : ('lessons.lesson.upcoming'.tr(), t.surface, t.muted);
    return LPressable(
        onTap: here ? null : () => context.push('/lessons/lesson/${x.id}'),
        label: '${x.seq ?? ''} $label ${gregorianLabel(x.date, lang)}',
        radius: 14,
        selected: here,
        excludeChildSemantics: true,
        builder: (context, s) => Container(
            width: 66,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
                gradient: here ? Lantern.goldFill : null,
                color: here ? null : bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: here || (!held && !x.isCancelled)
                        ? LanternTokens.gold
                        : Colors.transparent,
                    width: 1.5)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${x.seq ?? ''}',
                  style: Lantern.displayStyle(16,
                          color: here ? LanternTokens.onGold : t.fg,
                          height: 1.1)
                      .copyWith(fontFeatures: Lantern.tabular)),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(11,
                      color: here ? LanternTokens.onGold : fg, height: 1.2)),
              Text(gregorianLabel(x.date, lang, short: true),
                  maxLines: 1,
                  style: Lantern.textStyle(10.5,
                      color: here ? LanternTokens.onGold : t.muted,
                      height: 1.2)),
            ])));
  }
}
