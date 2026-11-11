import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_names.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart' show tPlural;
import '../lessons_widgets.dart'
    show
        audienceLabel,
        cityLabel,
        languageNativeLabel,
        openLesson,
        prayerLabel,
        topicLabel,
        typeLabel;
import 'lantern_lessons_actions.dart';
import 'lantern_lessons_parts.dart';

/// The lessons calendar in the Lantern design (/lessons/calendar): a
/// 14-day strip with Hijri dates, Upcoming and Past, the list by day or the
/// week grid by prayer, and the filters (a 300 px panel on the website
/// layout, a sheet on phones). The filter, the tab, the chosen day and the
/// lists all come from LessonsScreen's state.
class LanternLessonsCalendar extends StatefulWidget
    implements LanternSkinWidget {
  const LanternLessonsCalendar(
      {super.key,
      required this.filter,
      required this.past,
      required this.weekGrid,
      required this.day,
      required this.search,
      required this.matched,
      required this.shown,
      required this.days,
      required this.onFilter,
      required this.onPast,
      required this.onWeekGrid,
      required this.onDay,
      required this.onClear});

  final LessonFilter filter;
  final bool past, weekGrid;
  final DateTime? day;
  final TextEditingController search;

  /// Lessons that pass the filter, and those of the chosen day.
  final List<Lesson> matched, shown;
  final List<DateTime> days;
  final ValueChanged<LessonFilter> onFilter;
  final ValueChanged<bool> onPast, onWeekGrid;
  final ValueChanged<DateTime?> onDay;

  /// Clears the filters, the search and the day.
  final VoidCallback onClear;

  @override
  State<LanternLessonsCalendar> createState() => _LanternLessonsCalendarState();
}

class _LanternLessonsCalendarState extends State<LanternLessonsCalendar> {
  /// The strip's "2 weeks" end: the next fourteen days only.
  bool twoWeeks = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final wide = context.lanternWide;
    final w = widget;
    final end = addDays(c.today, 14);
    final shown = twoWeeks && w.day == null && !w.past
        ? w.shown.where((l) => l.date.isBefore(end)).toList()
        : w.shown;

    final head = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LCrumb([
            ('lessons.nav.lessons'.tr(), () => context.go('/lessons')),
            ('lessons.calendar.title'.tr(), null),
          ]),
          const SizedBox(height: 18),
          Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 20,
              runSpacing: 14,
              children: [
                ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          LEyebrow('lessons.calendar.eyebrow'.tr()),
                          const SizedBox(height: 8),
                          Semantics(
                              header: true,
                              child: Text('lessons.calendar.title'.tr(),
                                  style: Lantern.displayStyle(wide ? 32 : 27,
                                      color: t.fg,
                                      height: lHeadHeight(context)))),
                          const SizedBox(height: 4),
                          Text('lessons.calendar.subtitle'.tr(),
                              style: Lantern.textStyle(14.5, color: t.muted)),
                        ])),
                LUnderlineTabs<bool>(
                    line: false,
                    value: w.past,
                    onChanged: (v) {
                      setState(() => twoWeeks = false);
                      w.onPast(v);
                    },
                    tabs: [
                      (
                        value: false,
                        label: 'lessons.calendar.upcoming'.tr(),
                        count: c.loaded ? c.upcoming.length : null
                      ),
                      (value: true, label: 'lessons.calendar.past'.tr(), count: null),
                    ]),
              ]),
          if (!w.past && c.loaded) ...[
            const SizedBox(height: 16),
            _DayStrip(
                days: w.days,
                matched: w.matched,
                day: w.day,
                twoWeeks: twoWeeks,
                onAll: () {
                  setState(() => twoWeeks = false);
                  w.onDay(null);
                },
                onTwoWeeks: () {
                  setState(() => twoWeeks = true);
                  w.onDay(null);
                },
                onDay: (d) {
                  setState(() => twoWeeks = false);
                  w.onDay(w.day != null && sameDay(w.day!, d) ? null : d);
                }),
          ],
        ]);

    final Widget main;
    if (!c.loaded) {
      main = c.failure != null && !c.loading
          ? const LLessonsError()
          : const LLessonsSkeleton(rows: 6);
    } else {
      final bar = Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Text(tPlural('results', shown.length),
                key: const ValueKey('lantern-calendar-count'),
                style: Lantern.textStyle(14, color: t.muted)
                    .copyWith(fontFeatures: Lantern.tabular)),
            if (!w.past)
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LSegmented<bool>(
                        dense: true,
                        value: w.weekGrid,
                        onChanged: w.onWeekGrid,
                        segments: [
                          (
                            value: false,
                            label: 'lessons.calendar.list'.tr(),
                            icon: LGlyph.list
                          ),
                          (
                            value: true,
                            label: 'lessons.calendar.week'.tr(),
                            icon: LGlyph.grid
                          ),
                        ]),
                    LButton(
                        label: 'lessons.calendar.on_map'.tr(),
                        kind: LButtonKind.ghost,
                        size: LButtonSize.small,
                        icon: LGlyph.map,
                        onPressed: () => context.go('/map')),
                  ]),
          ]);
      final Widget body;
      if (shown.isEmpty) {
        body = Container(
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: t.line)),
            child: LEmptyState(
                key: const ValueKey('lantern-calendar-empty'),
                icon: LGlyph.search,
                title: 'lessons.calendar.empty_title'.tr(),
                body: 'lessons.calendar.empty_body'.tr(),
                action: LButton(
                    label: 'lessons.calendar.clear'.tr(),
                    kind: LButtonKind.secondary,
                    icon: LGlyph.close,
                    onPressed: () {
                      setState(() => twoWeeks = false);
                      w.onClear();
                    })));
      } else if (w.weekGrid && !w.past) {
        body = _WeekGrid(
            lessons: twoWeeks ? shown : w.matched, from: w.day ?? c.today);
      } else {
        body = _DayList(lessons: shown, past: w.past);
      }
      main = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!wide) ...[
              Row(children: [
                Expanded(
                    child: LField(
                        controller: w.search,
                        pill: true,
                        icon: LGlyph.search,
                        hint: 'lessons.calendar.search_hint'.tr(),
                        onChanged: (v) =>
                            w.onFilter(w.filter.copyWith(query: v)))),
                const SizedBox(width: 8),
                _FilterButton(
                    count: w.filter.activeCount,
                    onTap: () => _openFilters(context)),
              ]),
              const SizedBox(height: 14),
            ],
            bar,
            const SizedBox(height: 14),
            body,
          ]);
    }

    return LLessonsTabScroll(children: [
      const SizedBox(height: 20),
      head,
      const SizedBox(height: 22),
      if (wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: main),
          const SizedBox(width: 28),
          SizedBox(
              width: Lantern.sideFilters,
              child: LCard(
                  padding: const EdgeInsets.all(20),
                  child: _FilterPanel(
                      filter: w.filter,
                      search: w.search,
                      onChanged: w.onFilter))),
        ])
      else
        main,
    ]);
  }

  /// Phones: the filters in a sheet; Show results applies them, as on the
  /// older page.
  Future<void> _openFilters(BuildContext context) async {
    var draft = widget.filter;
    await showLanternSheet<void>(overTabs(context),
        title: 'lessons.calendar.filter_title'.tr(),
        body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FilterPanel(
                          filter: draft,
                          heading: false,
                          onChanged: (v) => set(() => draft = v)),
                      const SizedBox(height: 16),
                      LButton(
                          key: const ValueKey('lantern-calendar-show'),
                          label: 'lessons.calendar.show_results'.tr(),
                          expand: true,
                          onPressed: () {
                            widget.onFilter(draft);
                            Navigator.of(ctx).pop();
                          }),
                    ])));
  }
}

/// The filter button of the phone layout, with how many filters are on.
class _FilterButton extends StatelessWidget implements LanternSkinWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final label = count == 0
        ? 'lessons.calendar.filter'.tr()
        : '${'lessons.calendar.filter'.tr()}, $count';
    return Stack(clipBehavior: Clip.none, children: [
      Container(
          decoration: BoxDecoration(
              color: t.surface,
              shape: BoxShape.circle,
              border: Border.all(color: t.line, width: 1.5)),
          child: LIconButton(
              key: const ValueKey('lantern-calendar-filters'),
              icon: LGlyph.filter,
              label: label,
              size: 48,
              onPressed: onTap)),
      if (count > 0)
        PositionedDirectional(
            top: -2,
            end: -2,
            child: IgnorePointer(
                child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        gradient: Lantern.goldFill, shape: BoxShape.circle),
                    child: Text('$count',
                        style: Lantern.textStyle(11,
                            color: LanternTokens.onGold,
                            weight: FontWeight.w700,
                            height: 1))))),
    ]);
  }
}

/// All, the fourteen days with their Hijri dates and a dot per lesson, and
/// 2 weeks.
class _DayStrip extends StatelessWidget implements LanternSkinWidget {
  const _DayStrip(
      {required this.days,
      required this.matched,
      required this.day,
      required this.twoWeeks,
      required this.onAll,
      required this.onTwoWeeks,
      required this.onDay});

  final List<DateTime> days;
  final List<Lesson> matched;
  final DateTime? day;
  final bool twoWeeks;
  final VoidCallback onAll, onTwoWeeks;
  final ValueChanged<DateTime> onDay;

  @override
  Widget build(BuildContext context) {
    final c = context.read<LessonsController>();
    final lang = lessonsLang(context);
    return SingleChildScrollView(
        key: const ValueKey('lantern-calendar-strip'),
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _DayChip(
                  key: const ValueKey('lantern-day-all'),
                  big: 'lessons.all'.tr(),
                  bottom: tPlural('lessons', matched.length),
                  selected: day == null && !twoWeeks,
                  wideChip: true,
                  label: 'lessons.all'.tr(),
                  onTap: onAll),
              for (final d in days)
                _DayChip(
                    key: ValueKey('lantern-day-${isoDate(d)}'),
                    top: sameDay(d, c.today)
                        ? 'lessons.time.today'.tr()
                        : weekdayName(d, lang, short: true),
                    big: '${d.day}',
                    bottom: hijriLabel(d, lang, year: false),
                    count: matched.where((l) => sameDay(l.date, d)).length,
                    today: sameDay(d, c.today),
                    selected: day != null && sameDay(day!, d),
                    label:
                        '${weekdayName(d, lang)} ${gregorianLabel(d, lang)}, ${hijriLabel(d, lang)}, ${tPlural('lessons', matched.where((l) => sameDay(l.date, d)).length)}',
                    onTap: () => onDay(d)),
              _DayChip(
                  key: const ValueKey('lantern-day-two-weeks'),
                  big: 'lessons.calendar.two_weeks'.tr(),
                  bottom: tPlural('days', 14),
                  selected: day == null && twoWeeks,
                  wideChip: true,
                  label: 'lessons.calendar.two_weeks'.tr(),
                  onTap: onTwoWeeks),
            ]))));
  }
}

class _DayChip extends StatelessWidget implements LanternSkinWidget {
  const _DayChip(
      {super.key,
      this.top,
      required this.big,
      required this.bottom,
      required this.selected,
      required this.label,
      required this.onTap,
      this.count,
      this.today = false,
      this.wideChip = false});

  final String? top;
  final String big, bottom, label;
  final bool selected, today, wideChip;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final fg = selected ? LanternTokens.onGold : t.fg;
    final sub = selected ? LanternTokens.onGold : t.muted;
    final n = count ?? 0;
    return Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: LPressable(
            onTap: onTap,
            label: label,
            selected: selected,
            radius: 18,
            pressScale: .96,
            excludeChildSemantics: true,
            builder: (context, s) => AnimatedContainer(
                duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
                curve: Lantern.ease,
                transform: Matrix4.translationValues(
                    0, s.hovered && !s.pressed ? -2 : 0, 0),
                constraints: BoxConstraints(minWidth: wideChip ? 76 : 68),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                decoration: BoxDecoration(
                    color: selected ? null : t.surface,
                    gradient: selected ? Lantern.goldFill : null,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: selected
                            ? LanternTokens.gold
                            : today || s.hovered
                                ? LanternTokens.gold
                                : t.line,
                        width: today && !selected ? 1.5 : 1)),
                child: Opacity(
                    opacity: count == 0 && !selected ? .55 : 1,
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (top != null)
                            Text(top!,
                                maxLines: 1,
                                style: Lantern.textStyle(11.5,
                                    color: sub,
                                    weight: FontWeight.w600,
                                    height: 1.2)),
                          const SizedBox(height: 3),
                          Text(big,
                              maxLines: 1,
                              style: Lantern.displayStyle(wideChip ? 14 : 20,
                                      color: fg, height: 1.1)
                                  .copyWith(fontFeatures: Lantern.tabular)),
                          const SizedBox(height: 3),
                          Text(bottom,
                              maxLines: 1,
                              style: Lantern.textStyle(10.5,
                                  color: selected
                                      ? LanternTokens.onGold
                                      : t.goldInk,
                                  height: 1.2)),
                          if (count != null) ...[
                            const SizedBox(height: 5),
                            SizedBox(
                                height: 4,
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < math.min(n, 4); i++)
                                        Container(
                                            width: 4,
                                            height: 4,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 1.5),
                                            decoration: BoxDecoration(
                                                color: selected
                                                    ? LanternTokens.onGold
                                                    : LanternTokens.gold,
                                                shape: BoxShape.circle)),
                                    ])),
                          ],
                        ])))));
  }
}

/// The filters: city, district, mosque, preacher, language, audience, type
/// and subject, three switches, and a live Clear filters (n).
class _FilterPanel extends StatelessWidget implements LanternSkinWidget {
  const _FilterPanel(
      {required this.filter,
      required this.onChanged,
      this.search,
      this.heading = true});

  final LessonFilter filter;
  final ValueChanged<LessonFilter> onChanged;
  final TextEditingController? search;
  final bool heading;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final lang = lessonsLang(context);
    final f = filter;
    final districts = c.catalog.districts.values
        .where((d) => f.city == null || d.city == f.city)
        .toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    final mosques = c.verifiedMosques
        .where((m) =>
            (f.city == null || c.district(m.districtId)?.city == f.city) &&
            (f.districtId == null || m.districtId == f.districtId))
        .toList();
    Widget toggle(String key, String label, LGlyph icon, bool value,
            ValueChanged<bool> on) =>
        Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(children: [
              LIcon(icon, size: 18, color: t.goldInk),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: Lantern.textStyle(14, color: t.fg, height: 1.35))),
              const SizedBox(width: 8),
              LSwitch(
                  key: ValueKey('lantern-filter-$key'),
                  value: value,
                  label: label,
                  onChanged: on),
            ]));
    return Column(
        key: const ValueKey('lantern-calendar-filter-panel'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (heading)
            Row(children: [
              LIcon(LGlyph.filter, size: 18, color: t.goldInk),
              const SizedBox(width: 8),
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text('lessons.calendar.filter_title'.tr(),
                          style: Lantern.displayStyle(16,
                              color: t.fg, height: lHeadHeight(context))))),
            ]),
          if (search != null) ...[
            const SizedBox(height: 14),
            LField(
                controller: search,
                pill: true,
                icon: LGlyph.search,
                hint: 'lessons.calendar.search_hint'.tr(),
                onChanged: (v) => onChanged(f.copyWith(query: v))),
          ],
          LSelect(
              key: const ValueKey('lantern-filter-city'),
              label: 'lessons.calendar.city'.tr(),
              value: f.city,
              items: [
                for (final x in LessonsNames.cityIds.where((x) => x != 'other'))
                  (x, cityLabel(x))
              ],
              onChanged: (v) => onChanged(
                  f.copyWith(city: v, districtId: null, mosqueId: null))),
          LSelect(
              label: 'lessons.calendar.district'.tr(),
              value: f.districtId,
              items: [for (final d in districts) (d.id, d.name(lang))],
              onChanged: (v) =>
                  onChanged(f.copyWith(districtId: v, mosqueId: null))),
          LSelect(
              label: 'lessons.calendar.mosque'.tr(),
              value: f.mosqueId,
              items: [
                for (final m in mosques) (m.id, m.name(lang)),
                if (f.mosqueId != null && !mosques.any((m) => m.id == f.mosqueId))
                  (f.mosqueId!, c.mosque(f.mosqueId)?.name(lang) ?? f.mosqueId!),
              ],
              onChanged: (v) => onChanged(f.copyWith(mosqueId: v))),
          LSelect(
              label: 'lessons.calendar.preacher'.tr(),
              value: f.preacherId,
              items: [
                for (final p in c.listedPreachers) (p.id, p.name(lang)),
                if (f.preacherId != null &&
                    !c.listedPreachers.any((p) => p.id == f.preacherId))
                  (
                    f.preacherId!,
                    c.preacher(f.preacherId)?.name(lang) ?? f.preacherId!
                  ),
              ],
              onChanged: (v) => onChanged(f.copyWith(preacherId: v))),
          LSelect(
              key: const ValueKey('lantern-filter-language'),
              label: 'lessons.calendar.language'.tr(),
              value: f.language,
              items: [
                for (final x in {...LessonsNames.languages, if (f.language != null) f.language!})
                  (x, languageNativeLabel(x))
              ],
              onChanged: (v) => onChanged(f.copyWith(language: v))),
          LSelect(
              label: 'lessons.calendar.audience'.tr(),
              value: f.audience,
              items: [
                for (final a in LessonsNames.audiences) (a, audienceLabel(a))
              ],
              onChanged: (v) => onChanged(f.copyWith(audience: v))),
          LSelect(
              label: 'lessons.calendar.type'.tr(),
              value: f.type,
              items: [for (final x in LessonsVocab.types) (x, typeLabel(x))],
              onChanged: (v) => onChanged(f.copyWith(type: v))),
          LSelect(
              label: 'lessons.calendar.subject'.tr(),
              value: f.topic,
              items: [
                for (final x in {...LessonsNames.topics, if (f.topic != null) f.topic!})
                  (x, topicLabel(x))
              ],
              onChanged: (v) => onChanged(f.copyWith(topic: v))),
          const SizedBox(height: 10),
          toggle('women', 'lessons.calendar.women'.tr(), LGlyph.users,
              f.womenOnly, (v) => onChanged(f.copyWith(womenOnly: v))),
          toggle('live', 'lessons.calendar.live'.tr(), LGlyph.live,
              f.streamedOnly, (v) => onChanged(f.copyWith(streamedOnly: v))),
          toggle('series', 'lessons.calendar.series_only'.tr(), LGlyph.history,
              f.seriesOnly, (v) => onChanged(f.copyWith(seriesOnly: v))),
          const SizedBox(height: 10),
          LButton(
              key: const ValueKey('lantern-filter-clear'),
              label: 'lessons.calendar.clear_n'.tr(args: ['${f.activeCount}']),
              kind: LButtonKind.ghost,
              size: LButtonSize.small,
              onPressed: f.activeCount == 0 ? null : () => onChanged(f.cleared())),
        ]);
  }
}

/// A labelled choice from a list, with All first.
class LSelect extends StatelessWidget implements LanternSkinWidget {
  const LSelect(
      {super.key,
      required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  final String label;
  final String? value;
  final List<(String, String)> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final style = Lantern.textStyle(14, color: t.fg, height: 1.3);
    return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                  padding: const EdgeInsetsDirectional.only(start: 2, bottom: 6),
                  child: Text(label,
                      style: Lantern.textStyle(13,
                          color: t.muted, weight: FontWeight.w600, height: 1.3))),
              Container(
                  constraints: const BoxConstraints(minHeight: Lantern.target),
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
                  decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(Lantern.radiusTile),
                      border: Border.all(
                          color: value == null ? t.line : LanternTokens.gold,
                          width: 1.5)),
                  child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                          value: value,
                          isExpanded: true,
                          dropdownColor: t.raised,
                          borderRadius: BorderRadius.circular(Lantern.radiusTile),
                          style: style,
                          icon: LIcon(LGlyph.chevron, size: 18, color: t.muted),
                          hint: Text('lessons.all'.tr(), style: style),
                          items: [
                            DropdownMenuItem<String?>(
                                value: null,
                                child: Text('lessons.all'.tr(), style: style)),
                            for (final (id, name) in items)
                              DropdownMenuItem<String?>(
                                  value: id,
                                  child: Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: style)),
                          ],
                          onChanged: onChanged))),
            ]));
  }
}

/// Lessons under their day: today and tomorrow named, then the Gregorian
/// and Hijri dates. Past lessons carry Did you attend?
class _DayList extends StatelessWidget implements LanternSkinWidget {
  const _DayList({required this.lessons, required this.past});

  final List<Lesson> lessons;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final lang = lessonsLang(context);
    final groups = <List<Lesson>>[];
    for (final l in lessons) {
      if (groups.isNotEmpty && sameDay(groups.last.first.date, l.date)) {
        groups.last.add(l);
      } else {
        groups.add([l]);
      }
    }
    return Column(
        key: const ValueKey('lantern-calendar-list'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in groups) ...[
            Container(
                margin: const EdgeInsets.only(top: 8, bottom: 10),
                padding: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: t.line))),
                child: Semantics(
                    header: true,
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                          text: relativeDayLabel(g.first.date, lang) ==
                                  weekdayName(g.first.date, lang)
                              ? weekdayName(g.first.date, lang)
                              : '${relativeDayLabel(g.first.date, lang)} · ${weekdayName(g.first.date, lang)}',
                          style: Lantern.displayStyle(15,
                              color: t.fg, height: lHeadHeight(context))),
                      TextSpan(
                          text:
                              '   ${gregorianLabel(g.first.date, lang)} · ${hijriLabel(g.first.date, lang)}',
                          style: Lantern.textStyle(12.5, color: t.muted)),
                    ])))),
            for (final l in g)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LLessonRow(l,
                      trailing: past && c.signedIn ? _AttendChip(l) : null)),
            const SizedBox(height: 12),
          ],
        ]);
  }
}

class _AttendChip extends StatelessWidget implements LanternSkinWidget {
  const _AttendChip(this.lesson);

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final on = context.watch<LessonsController>().attended(lesson.id);
    return Align(
        alignment: AlignmentDirectional.centerStart,
        child: LChip(
            key: ValueKey('lantern-attend-${lesson.id}'),
            label: on
                ? 'lessons.calendar.attended'.tr()
                : 'lessons.calendar.did_attend'.tr(),
            selected: on,
            dense: true,
            icon: LGlyph.check,
            onTap: () => toggleLessonAttended(context, lesson)));
  }
}

/// Seven days by the five prayers. Streamed lessons have a red edge, the
/// others gold; a lesson on now is green. Scrolls sideways when narrow.
class _WeekGrid extends StatelessWidget implements LanternSkinWidget {
  const _WeekGrid({required this.lessons, required this.from});

  final List<Lesson> lessons;
  final DateTime from;

  static const _head = 96.0, _min = 820.0;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final lang = lessonsLang(context);
    final days = [for (var i = 0; i < 7; i++) addDays(from, i)];
    final pt = prayerTimesFor(from, null, c.catalog.districts);
    final now = DateTime.now();
    final calm = Lantern.calm(context);
    var n = 0;
    Widget cell(DateTime d, String slot) {
      final xs = lessons.where((l) => sameDay(l.date, d) && l.slot == slot);
      return Container(
          constraints: const BoxConstraints(minHeight: 62),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              border: BorderDirectional(start: BorderSide(color: t.line2))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final l in xs) _event(context, c, t, lang, l, now, calm, n++),
          ]));
    }

    return LayoutBuilder(builder: (context, box) {
      final width = math.max(box.maxWidth, _min);
      final grid = SizedBox(
          width: width,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: _head, color: t.sunk),
              for (final d in days)
                Expanded(
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 6),
                        decoration: BoxDecoration(
                            color: sameDay(d, c.today)
                                ? Color.alphaBlend(
                                    LanternTokens.gold.withValues(alpha: .18),
                                    t.sunk)
                                : t.sunk,
                            border:
                                Border(bottom: BorderSide(color: t.line))),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(
                              sameDay(d, c.today)
                                  ? 'lessons.time.today'.tr()
                                  : weekdayName(d, lang, short: true),
                              maxLines: 1,
                              style: Lantern.textStyle(13,
                                  color: t.fg,
                                  weight: FontWeight.w600,
                                  height: 1.2)),
                          Text(gregorianLabel(d, lang, short: true),
                              maxLines: 1,
                              style: Lantern.textStyle(11,
                                  color: t.muted, height: 1.3)),
                        ]))),
            ])),
            for (final (i, slot) in LessonsVocab.slots.indexed)
              Container(
                  decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(top: BorderSide(color: t.line2))),
                  child: IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Container(
                            width: _head,
                            padding: const EdgeInsets.all(10),
                            color: t.sunk,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(prayerLabel(slot),
                                      style: Lantern.textStyle(13,
                                          color: t.fg,
                                          weight: FontWeight.w600,
                                          height: 1.2)),
                                  Text(clockLabel(pt.of(slot), lang),
                                      style: Lantern.textStyle(11,
                                              color: t.muted, height: 1.4)
                                          .copyWith(
                                              fontFeatures: Lantern.tabular)),
                                ])),
                        for (final d in days) Expanded(child: cell(d, slot)),
                      ]))),
          ]));
      return Container(
          key: const ValueKey('lantern-calendar-grid'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: t.line)),
          child: width > box.maxWidth
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal, child: grid)
              : grid);
    });
  }

  Widget _event(BuildContext context, LessonsController c, LanternTokens t,
      String lang, Lesson l, DateTime now, bool calm, int index) {
    final running =
        l.isPublic && lessonTiming(l, c.catalog, now).phase == LessonPhase.running;
    final edge = l.streamed ? t.live : LanternTokens.gold;
    final chip = Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: LPressable(
            key: ValueKey('lantern-grid-${l.id}'),
            onTap: () => openLesson(context, l.id),
            label: l.title(lang),
            radius: 10,
            pressScale: .97,
            excludeChildSemantics: true,
            builder: (context, s) => Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                    color: running
                        ? t.okSoft
                        : s.hovered
                            ? t.line2
                            : t.sunk,
                    borderRadius: BorderRadius.circular(10),
                    border: BorderDirectional(
                        start: BorderSide(color: edge, width: 3))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.title(lang),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(11.5,
                                  color: t.fg,
                                  weight: FontWeight.w600,
                                  height: 1.25)
                              .copyWith(
                                  decoration: l.isCancelled
                                      ? TextDecoration.lineThrough
                                      : null)),
                      Text(c.mosque(l.mosqueId)?.name(lang) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(10.5,
                              color: t.muted, height: 1.3)),
                    ]))));
    if (calm) return chip;
    // The events rise in, one after another.
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 280 + 30 * math.min(index, 20)),
        curve: Lantern.ease,
        builder: (context, v, child) => Opacity(
            opacity: v,
            child: Transform.translate(
                offset: Offset(0, 8 * (1 - v)), child: child)),
        child: chip);
  }
}
