import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_shell.dart';
import '../lessons_widgets.dart';

/// The public calendar (Lessons's activities page, upgraded).
class LessonsScreen extends StatefulWidget {
  const LessonsScreen({super.key, this.initial = LessonFilter.none});
  final LessonFilter initial;
  @override
  State<LessonsScreen> createState() => _LessonsScreenState();
}

class _LessonsScreenState extends State<LessonsScreen> {
  late LessonFilter f = widget.initial;
  bool past = false, weekGrid = false;
  DateTime? day;
  final search = TextEditingController();

  @override
  void didUpdateWidget(LessonsScreen old) {
    super.didUpdateWidget(old);
    if (old.initial != widget.initial) setState(() => f = widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang, wide = context.wide;
    final base = past ? c.pastWhere((_) => true) : (c.publicLessons.where((l) => !l.date.isBefore(c.today)).toList()..sort(compareLessons));
    final matched = base.where((l) => f.matches(l, c.catalog)).toList();
    final shown = day == null ? matched : matched.where((l) => sameDay(l.date, day!)).toList();
    final days = [for (var i = 0; i < 14; i++) addDays(c.today, i)];

    final dayStrip = past
        ? null
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _DayChip(top: 'lessons.all'.tr(), big: '∞', bottom: 'lessons.calendar.two_weeks'.tr(), selected: day == null, onTap: () => setState(() => day = null)),
              for (final d in days)
                _DayChip(
                  top: sameDay(d, c.today) ? 'lessons.time.today'.tr() : weekdayName(d, lang, short: true),
                  big: '${d.day}',
                  bottom: '${hijriOf(d).day} ${'lessons.time.hijri_short'.tr()}',
                  count: matched.where((l) => sameDay(l.date, d)).length,
                  selected: day != null && sameDay(day!, d),
                  onTap: () => setState(() => day = day != null && sameDay(day!, d) ? null : d),
                ),
            ]),
          );

    final list = shown.isEmpty
        ? TEmpty(
            icon: TGlyph.search,
            title: 'lessons.calendar.empty_title'.tr(),
            body: 'lessons.calendar.empty_body'.tr(),
            action: TButton('lessons.calendar.clear'.tr(), onPressed: () => setState(() {
              f = LessonFilter.none;
              search.clear();
              day = null;
            })))
        : LessonDayList(shown, extra: past ? (l) => AttendToggle(l) : null);

    final tabs = TTabs<bool>(
      value: past,
      onChanged: (v) => setState(() {
        past = v;
        day = null;
      }),
      options: [
        TSegOption(false, 'lessons.calendar.upcoming'.tr(), count: c.upcoming.length),
        TSegOption(true, 'lessons.calendar.past'.tr()),
      ],
    );

    if (!wide) {
      return LessonsTabBody(children: [
        Row(children: [
          Expanded(
            child: TSearchBox(
              hint: 'lessons.calendar.search_hint'.tr(),
              controller: search,
              onChanged: (v) => setState(() => f = f.copyWith(query: v)),
              trailing: _FilterButton(count: f.activeCount, onTap: () => _openFilters(context)),
            ),
          ),
        ]),
        tabs,
        if (dayStrip != null) dayStrip,
        Text(tPlural('results', shown.length), style: tBody(13, color: TC.muted)),
        list,
      ]);
    }

    return LessonsTabBody(children: [
      TPageHead(
        eyebrow: 'lessons.calendar.eyebrow'.tr(),
        title: 'lessons.calendar.title'.tr(),
        subtitle: 'lessons.calendar.subtitle'.tr(),
        actions: [
          TSeg<bool>(
            value: weekGrid,
            onChanged: (v) => setState(() => weekGrid = v),
            options: [
              TSegOption(false, 'lessons.calendar.list'.tr(), icon: TGlyph.list),
              TSegOption(true, 'lessons.calendar.week'.tr(), icon: TGlyph.grid),
            ],
          ),
          TButton('lessons.calendar.on_map'.tr(), icon: TGlyph.map, onPressed: () => context.go('/map')),
        ],
      ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 300,
          child: TCard(
            child: _FilterPanel(
              f: f,
              search: search,
              onChanged: (v) => setState(() => f = v),
            ),
          ),
        ),
        const SizedBox(width: 28),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [Expanded(child: tabs), Text(tPlural('results', shown.length), style: tBody(13, color: TC.muted))]),
            const SizedBox(height: 12),
            if (dayStrip != null) ...[dayStrip, const SizedBox(height: 12)],
            if (weekGrid && !past) _WeekGrid(lessons: matched, from: day ?? c.today) else list,
          ]),
        ),
      ]),
    ]);
  }

  Future<void> _openFilters(BuildContext context) async {
    var draft = f;
    await showTModal<void>(context,
        title: 'lessons.calendar.filter_title'.tr(),
        body: (ctx) => StatefulBuilder(builder: (ctx, set) => _FilterPanel(f: draft, onChanged: (v) => set(() => draft = v), showSearch: false)),
        footer: (ctx) => [
              TButton('lessons.calendar.show_results'.tr(), kind: TBtn.minted, expand: true, onPressed: () {
                setState(() => f = draft);
                Navigator.of(ctx).pop();
              }),
            ]);
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        TIconButton(TGlyph.filter, tooltip: 'lessons.calendar.filter'.tr(), onPressed: onTap),
        if (count > 0)
          PositionedDirectional(
            top: 4,
            end: 4,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: TC.gold, shape: BoxShape.circle),
              child: Text('$count', style: tBody(11, color: TC.ink, weight: FontWeight.w700, height: 1)),
            ),
          ),
      ]);
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.top, required this.big, required this.bottom, required this.selected, required this.onTap, this.count});
  final String top, big, bottom;
  final bool selected;
  final VoidCallback onTap;
  final int? count;
  @override
  Widget build(BuildContext context) {
    final fg = selected ? HidayahGold.g200 : TC.ink;
    final zero = count == 0;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Opacity(
        opacity: zero && !selected ? .5 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            width: 68,
            decoration: BoxDecoration(
              color: selected ? null : TC.card,
              gradient: selected ? HidayahGradients.selected : null,
              borderRadius: BorderRadius.circular(TC.r),
              border: Border.all(color: selected ? Colors.transparent : TC.hair),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(TC.r),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(children: [
                  Text(top, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(11.5, color: selected ? fg : TC.muted, weight: FontWeight.w600, height: 1.2)),
                  Text(big, style: tDisplay(20, color: fg)),
                  Text(bottom, maxLines: 1, style: tBody(11, color: selected ? fg : TC.bronze, height: 1.2)),
                  if ((count ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('$count', style: tBody(11, color: selected ? fg : TC.tagFg, weight: FontWeight.w700, height: 1.1)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({required this.f, required this.onChanged, this.search, this.showSearch = true});
  final LessonFilter f;
  final ValueChanged<LessonFilter> onChanged;
  final TextEditingController? search;
  final bool showSearch;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final districts = c.catalog.districts.values.where((d) => f.city == null || d.city == f.city).toList()..sort((a, b) => a.sort.compareTo(b.sort));
    final mosques = c.verifiedMosques
        .where((m) => (f.city == null || c.district(m.districtId)?.city == f.city) && (f.districtId == null || m.districtId == f.districtId))
        .toList();
    Widget group(String label, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            TChips(chips),
          ]),
        );
    Widget drop(String label, String? value, List<DropdownMenuItem<String?>> items, ValueChanged<String?> on) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: TField(
            label: label,
            child: DropdownButtonFormField<String?>(
              initialValue: value,
              isExpanded: true,
              decoration: tInput(),
              items: [DropdownMenuItem<String?>(value: null, child: Text('lessons.all'.tr())), ...items],
              onChanged: on,
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showSearch && search != null) ...[
        TSearchBox(hint: 'lessons.calendar.search_hint'.tr(), controller: search, onChanged: (v) => onChanged(f.copyWith(query: v))),
        const SizedBox(height: 14),
      ],
      group('lessons.calendar.city'.tr(), [
        for (final x in LessonsVocab.cities.where((x) => x != 'other'))
          TChip(cityLabel(x), small: true, selected: f.city == x,
              onTap: () => onChanged(f.copyWith(city: f.city == x ? null : x, districtId: null, mosqueId: null))),
      ]),
      drop('lessons.calendar.district'.tr(), f.districtId, [for (final d in districts) DropdownMenuItem(value: d.id, child: Text(d.name(lang)))],
          (v) => onChanged(f.copyWith(districtId: v, mosqueId: null))),
      drop('lessons.calendar.mosque'.tr(), f.mosqueId, [for (final m in mosques) DropdownMenuItem(value: m.id, child: Text(m.name(lang), overflow: TextOverflow.ellipsis))],
          (v) => onChanged(f.copyWith(mosqueId: v))),
      drop('lessons.calendar.preacher'.tr(), f.preacherId,
          [for (final p in c.listedPreachers) DropdownMenuItem(value: p.id, child: Text(p.name(lang), overflow: TextOverflow.ellipsis))],
          (v) => onChanged(f.copyWith(preacherId: v))),
      group('lessons.calendar.type'.tr(), [
        for (final t in LessonsVocab.types)
          TChip(typeLabel(t), small: true, icon: typeGlyph(t), selected: f.type == t, onTap: () => onChanged(f.copyWith(type: f.type == t ? null : t))),
      ]),
      group('lessons.calendar.language'.tr(), [
        for (final x in LessonsVocab.languages)
          TChip(LessonsVocab.languageNative[x]!, small: true, selected: f.language == x, onTap: () => onChanged(f.copyWith(language: f.language == x ? null : x))),
      ]),
      group('lessons.calendar.audience'.tr(), [
        for (final a in LessonsVocab.audiences)
          TChip(audienceLabel(a), small: true, selected: f.audience == a, onTap: () => onChanged(f.copyWith(audience: f.audience == a ? null : a))),
      ]),
      group('lessons.calendar.subject'.tr(), [
        for (final t in LessonsVocab.topics)
          TChip(topicLabel(t), small: true, selected: f.topic == t, onTap: () => onChanged(f.copyWith(topic: f.topic == t ? null : t))),
      ]),
      TToggleRow(label: 'lessons.calendar.women'.tr(), icon: TGlyph.users, value: f.womenOnly, onChanged: (v) => onChanged(f.copyWith(womenOnly: v))),
      TToggleRow(label: 'lessons.calendar.live'.tr(), icon: TGlyph.radio, value: f.streamedOnly, onChanged: (v) => onChanged(f.copyWith(streamedOnly: v))),
      TToggleRow(label: 'lessons.calendar.series_only'.tr(), icon: TGlyph.repeat, value: f.seriesOnly, onChanged: (v) => onChanged(f.copyWith(seriesOnly: v))),
      if (f.activeCount > 0)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TButton('lessons.calendar.clear_n'.tr(args: ['${f.activeCount}']), kind: TBtn.ghost, icon: TGlyph.x, onPressed: () => onChanged(f.cleared())),
        ),
    ]);
  }
}

/// Seven days by five prayers.
class _WeekGrid extends StatelessWidget {
  const _WeekGrid({required this.lessons, required this.from});
  final List<Lesson> lessons;
  final DateTime from;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final c = context.watch<LessonsController>();
    final days = [for (var i = 0; i < 7; i++) addDays(from, i)];
    Color typeColor(String t) => t == 'lecture' ? TC.gold : t == 'talk' ? TC.infoFg : TC.slateFg;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(128),
        columnWidths: const {0: FixedColumnWidth(110)},
        border: TableBorder.all(color: TC.hair),
        children: [
          TableRow(decoration: const BoxDecoration(color: TC.tint), children: [
            const SizedBox(),
            for (final d in days)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Text(sameDay(d, c.today) ? 'lessons.time.today'.tr() : weekdayName(d, lang, short: true), style: tStrong(13)),
                  Text(gregorianLabel(d, lang, short: true), style: tBody(12, color: TC.ink2, height: 1.3)),
                  Text(hijriLabel(d, lang, year: false), style: tBody(11, color: TC.bronze, height: 1.3)),
                ]),
              ),
          ]),
          for (final s in LessonsVocab.slots)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  TIcon(slotGlyph(s), size: 16, color: TC.goldIcon),
                  const SizedBox(width: 6),
                  Expanded(child: Text(slotLabel(s), style: tBody(12.5, color: TC.ink2, weight: FontWeight.w600, height: 1.3))),
                ]),
              ),
              for (final d in days)
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(children: [
                    for (final l in lessons.where((l) => sameDay(l.date, d) && l.slot == s))
                      InkWell(
                        onTap: () => context.push('/lessons/lesson/${l.id}'),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: TC.card,
                            borderRadius: BorderRadius.circular(8),
                            border: BorderDirectional(start: BorderSide(color: typeColor(l.type), width: 3)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.title(lang), maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: tStrong(12).copyWith(decoration: l.isCancelled ? TextDecoration.lineThrough : null)),
                            Text(c.mosque(l.mosqueId)?.name(lang) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(11, color: TC.muted, height: 1.3)),
                          ]),
                        ),
                      ),
                  ]),
                ),
            ]),
        ],
      ),
    );
  }
}
