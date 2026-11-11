import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart' show tPlural;
import '../lessons_map.dart' show LessonsMap;
import '../lessons_modals.dart' show openExternal;
import '../lessons_widgets.dart'
    show cityLabel, facilityLabel, openLesson, slotLabel;
import 'lantern_lessons_parts.dart';

/// A mosque that is not in the programme.
class LanternMosqueMissing extends StatelessWidget implements LanternSkinWidget {
  const LanternMosqueMissing({super.key});

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Builder(
          builder: (context) => LLessonsPage(
                  title: 'lessons.nav.mosque'.tr(),
                  children: [
                    const SizedBox(height: 24),
                    Container(
                        decoration: BoxDecoration(
                            color: context.lt.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: context.lt.line)),
                        child: LEmptyState(
                            key: const ValueKey('lantern-mosque-missing'),
                            icon: LGlyph.mosque,
                            title: 'lessons.lesson.not_found'.tr(),
                            action: LButton(
                                label: 'lessons.nav.lessons'.tr(),
                                onPressed: () => context.go('/lessons')))),
                  ])));
}

/// The mosque page in the Lantern design (/lessons/mosques/:id): a map
/// strip with the arch badge, its name, area and marks, Directions and On
/// the map, this week's programme as a timetable, the lessons coming up,
/// today's prayers and who teaches here. Values come from MosqueScreen.
class LanternMosqueView extends StatelessWidget implements LanternSkinWidget {
  const LanternMosqueView(
      {super.key,
      required this.mosque,
      required this.district,
      required this.lessons,
      required this.week});

  final Mosque mosque;
  final District? district;

  /// Upcoming lessons here, and the seven days from today.
  final List<Lesson> lessons;
  final List<DateTime> week;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final wide = context.lanternWide;
    final lang = lessonsLang(context);
    final m = mosque, d = district;
    final thisWeek =
        lessons.where((l) => !l.date.isAfter(week.last)).toList();
    final onMap =
        m.verified && m.hasPin && LessonsMap.covers(m.latitude!, m.longitude!);
    final preacherIds = <String>{for (final l in lessons) l.preacherId};
    final preachers =
        preacherIds.map(c.preacher).whereType<Preacher>().toList();
    final today = prayerTimesFor(c.today, m, c.catalog.districts);

    final identity = Padding(
        padding: const EdgeInsets.only(top: 150),
        child: LLessonsColumn(
            child: Wrap(
                spacing: 20,
                runSpacing: 14,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
              Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                        decoration: ShapeDecoration(
                            color: t.bg,
                            shape: const LArchBorder(bottom: 20)),
                        child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: LArchBadge(
                                width: wide ? 96 : 76,
                                height: wide ? 112 : 90,
                                filled: true))),
                    const SizedBox(width: 18),
                    ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: wide
                                ? 560
                                : MediaQuery.sizeOf(context).width - 140),
                        child: Padding(
                            padding: EdgeInsets.only(top: wide ? 76 : 62),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Semantics(
                                      header: true,
                                      child: Text(m.name(lang),
                                          style: Lantern.displayStyle(
                                              wide ? 30 : 24,
                                              color: t.fg,
                                              height: lHeadHeight(context)))),
                                  if (d != null)
                                    Text('${d.name(lang)} · ${cityLabel(d.city)}',
                                        style: Lantern.textStyle(14,
                                            color: t.muted, height: 1.45)),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, runSpacing: 6, children: [
                                    LTag(
                                        'lantern.lessons.mosque.this_week'.tr(
                                            args: [
                                              tPlural('lessons', thisWeek.length)
                                            ]),
                                        tone: LTone.gold,
                                        outlined: true),
                                    for (final f in m.facilities)
                                      LTag(facilityLabel(f),
                                          icon: f == 'women'
                                              ? LGlyph.users
                                              : LGlyph.check),
                                    if (!m.verified)
                                      LTag(
                                          'lantern.lessons.mosque.unverified'
                                              .tr(),
                                          tone: LTone.warn,
                                          icon: LGlyph.warn),
                                  ]),
                                ]))),
                  ]),
              Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (m.directions != null)
                      LButton(
                          label: 'lessons.lesson.directions'.tr(),
                          icon: LGlyph.directions,
                          onPressed: () => openExternal(m.directions!)),
                    if (onMap)
                      LButton(
                          key: const ValueKey('lantern-mosque-on-map'),
                          label: 'lessons.calendar.on_map'.tr(),
                          kind: LButtonKind.secondary,
                          icon: LGlyph.map,
                          onPressed: () => context.go('/map?mosque=${m.id}')),
                    LFollowButton(kind: 'mosque', id: m.id),
                  ]),
            ])));

    final header = Stack(children: [
      const LMapArt(height: 220, radius: 0),
      identity,
    ]);

    final main = <Widget>[
      if (!m.verified)
        LBanner('lessons.mosque.unverified'.tr(),
            key: const ValueKey('lantern-mosque-unverified'), tone: LTone.warn),
      LLessonsSection(
          title: 'lessons.mosque.week'.tr(),
          child: _Timetable(lessons: thisWeek)),
      if (lessons.isNotEmpty)
        LLessonsSection(
            title: 'lessons.mosque.upcoming'.tr(),
            count: tPlural('lessons', lessons.length),
            child: wide
                ? LGrid(columns: 2, children: [
                    for (final l in lessons.take(8)) LLessonCard(l)
                  ])
                : Column(children: [
                    for (final l in lessons.take(4))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LLessonCard(l)),
                  ])),
    ];
    final side = <Widget>[
      LPanel(
          title: 'lantern.lessons.mosque.prayer_today'.tr(),
          child: LPrayerStrip(
              times: today, active: LPrayerStrip.nextPrayer(today))),
      if (preachers.isNotEmpty)
        LPanel(
            title: 'lessons.map.preachers_here'.tr(),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final p in preachers)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LRow(
                        title: p.name(lang),
                        subtitle: p.title(lang).isEmpty ? null : p.title(lang),
                        dense: true,
                        leading: LAvatar(
                            name: p.name(lang),
                            size: 40,
                            image: resolveImageProviderOrNull(p.photoUrl)),
                        onTap: () =>
                            context.push('/lessons/preachers/${p.id}'))),
            ])),
    ];

    Widget column(List<Widget> xs, double gap) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < xs.length; i++) ...[
                if (i > 0) SizedBox(height: gap),
                xs[i]
              ]
            ]);

    return LLessonsPage(
        title: 'lessons.nav.mosque'.tr(),
        header: header,
        children: [
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: column(main, 0)),
              const SizedBox(width: 28),
              SizedBox(
                  width: Lantern.sideChat,
                  child: Padding(
                      padding: const EdgeInsets.only(top: 44),
                      child: column(side, 14))),
            ])
          else
            column([
              ...main,
              const SizedBox(height: 14),
              ...side,
            ], 16),
        ]);
  }
}

/// This week's programme as a timetable: day with Hijri, prayer and start,
/// the lesson, the preacher, and a mark for one that is on or streamed.
class _Timetable extends StatelessWidget implements LanternSkinWidget {
  const _Timetable({required this.lessons});

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final wide = context.lanternWide;
    final lang = lessonsLang(context);
    final now = DateTime.now();
    final small = Lantern.textStyle(11.5, color: t.muted, height: 1.35);
    final strong =
        Lantern.textStyle(14, color: t.fg, weight: FontWeight.w600, height: 1.35);
    Widget row(Lesson l) {
      final running = l.isPublic &&
          lessonTiming(l, c.catalog, now).phase == LessonPhase.running;
      final day = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(relativeDayLabel(l.date, lang), style: strong),
            Text(hijriLabel(l.date, lang, year: false), style: small),
          ]);
      final time = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(slotLabel(l.slot),
                style: Lantern.textStyle(13.5, color: t.fg, height: 1.35)),
            Text('≈ ${clockLabel(c.startHours(l), lang)}',
                style: small.copyWith(fontFeatures: Lantern.tabular)),
          ]);
      final what = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.title(lang),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: strong.copyWith(
                    decoration:
                        l.isCancelled ? TextDecoration.lineThrough : null)),
            if (l.seriesId != null)
              Text('lessons.lesson.series'.tr(), style: small),
          ]);
      final who = Text(c.preacher(l.preacherId)?.name(lang) ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Lantern.textStyle(13.5, color: t.fg, height: 1.35));
      final mark = c.isLiveNow(l, now: now)
          ? LBadge('lessons.lesson.live'.tr(), kind: LBadgeKind.live, small: true)
          : running
          ? LBadge('lantern.lessons.now'.tr(), kind: LBadgeKind.now, small: true)
          : l.streamed
              ? Semantics(
                  label: 'lessons.lesson.streamed'.tr(),
                  child: LIcon(LGlyph.live, size: 18, color: t.liveText))
              : const SizedBox.shrink();
      return LPressable(
          key: ValueKey('lantern-mosque-row-${l.id}'),
          onTap: () => openLesson(context, l.id),
          label: '${relativeDayLabel(l.date, lang)}, ${slotLabel(l.slot)}, ${l.title(lang)}',
          radius: 0,
          pressScale: 1,
          builder: (context, s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: running
                      ? t.okSoft
                      : s.hovered
                          ? t.sunk
                          : null,
                  border: Border(top: BorderSide(color: t.line2))),
              child: wide
                  ? Row(children: [
                      Expanded(flex: 11, child: day),
                      const SizedBox(width: 12),
                      Expanded(flex: 10, child: time),
                      const SizedBox(width: 12),
                      Expanded(flex: 20, child: what),
                      const SizedBox(width: 12),
                      Expanded(flex: 15, child: who),
                      SizedBox(
                          width: 70,
                          child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: mark)),
                    ])
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                          width: 112,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [day, const SizedBox(height: 6), time])),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [what, const SizedBox(height: 4), who])),
                      mark,
                    ])));
    }

    return Container(
        key: const ValueKey('lantern-mosque-week'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.line)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wide)
                Container(
                    color: t.sunk,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: DefaultTextStyle(
                        style: Lantern.textStyle(12,
                            color: t.muted, weight: FontWeight.w600),
                        child: Row(children: [
                          for (final (flex, k) in [
                            (11, 'lantern.lessons.mosque.day'),
                            (10, 'lessons.lesson.time'),
                            (20, 'lessons.nav.lesson'),
                            (15, 'lessons.calendar.preacher'),
                          ]) ...[
                            Expanded(flex: flex, child: Text(k.tr())),
                            const SizedBox(width: 12),
                          ],
                          const SizedBox(width: 58),
                        ])))
              else
                const SizedBox.shrink(),
              if (lessons.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('lantern.lessons.mosque.none_week'.tr(),
                        style: Lantern.textStyle(14, color: t.muted)))
              else
                for (final l in lessons) row(l),
            ]));
  }
}
