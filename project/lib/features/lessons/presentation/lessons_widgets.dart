import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../domain/prayer_times.dart';
import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import '../domain/lessons_rules.dart';
import '../domain/lessons_vocab.dart';
import '../state/lessons_controller.dart';
import 'lessons_kit.dart';
import 'lessons_modals.dart';

// ------------------------------------------------------------- text helpers
String slotLabel(String slot) => 'lessons.slot.$slot'.tr();
String prayerLabel(String slot) => 'lessons.prayer.$slot'.tr();
String typeLabel(String t) => 'lessons.type.$t'.tr();
String topicLabel(String t) => 'lessons.topic.$t'.tr();
String audienceLabel(String a) => 'lessons.audience.$a'.tr();
String languageLabel(String l) => 'lessons.language.$l'.tr();
String cityLabel(String c) => 'lessons.city.$c'.tr();
String facilityLabel(String f) => 'lessons.facility.$f'.tr();
String statusLabel(String s) => 'lessons.status.$s'.tr();

/// "Al-Huda Grand Mosque · Al-Aqrabiyah".
String placeOf(LessonsController c, Lesson l, String lang) {
  final m = c.mosque(l.mosqueId);
  if (m == null) return '';
  final d = c.district(m.districtId);
  return d == null ? m.name(lang) : '${m.name(lang)} · ${d.name(lang)}';
}

/// "After Isha · ≈ 7:40 PM" or "at 8:00 PM", optionally with the date.
String whenOf(LessonsController c, Lesson l, String lang, {bool withDate = true}) {
  final t = clockLabel(c.startHours(l), lang);
  final s = l.exactTime != null ? 'lessons.time.at'.tr(args: [t]) : '${slotLabel(l.slot)} · ${'lessons.time.approx'.tr(args: [t])}';
  if (!withDate) return s;
  return '${weekdayName(l.date, lang, short: true)} ${gregorianLabel(l.date, lang, short: true)} · $s';
}

String agoText(DateTime at, {DateTime? now}) {
  final m = ((now ?? DateTime.now()).difference(at).inMinutes).clamp(1, 1 << 30);
  if (m < 60) return 'lessons.ago.min'.tr(args: ['$m']);
  final h = (m / 60).round();
  if (h < 24) return 'lessons.ago.hour'.tr(args: ['$h']);
  return 'lessons.ago.day'.plural((h / 24).round());
}

TTone typeTone(String t) => t == 'lecture' ? TTone.gold : t == 'talk' ? TTone.info : TTone.slate;
TTone statusTone(String s) => switch (s) {
      'pending' => TTone.warning,
      'approved' => TTone.success,
      'withdrawn' => TTone.slate,
      _ => TTone.danger,
    };
TGlyph statusGlyph(String s) => switch (s) {
      'pending' => TGlyph.clock,
      'approved' => TGlyph.check,
      'withdrawn' => TGlyph.history,
      _ => TGlyph.x,
    };

class TypeTag extends StatelessWidget {
  const TypeTag(this.type, {super.key});
  final String type;
  @override
  Widget build(BuildContext context) => TTag(typeLabel(type), tone: typeTone(type), icon: typeGlyph(type));
}

class StatusTag extends StatelessWidget {
  const StatusTag(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) => TTag(statusLabel(status), tone: statusTone(status), icon: statusGlyph(status));
}

class LessonBadges extends StatelessWidget {
  const LessonBadges(this.lesson, {super.key, this.max = 4});
  final Lesson lesson;
  final int max;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final l = lesson;
    final out = <Widget>[];
    if (c.isLiveNow(l)) {
      out.add(const TLiveTag());
    } else if (l.streamed) {
      out.add(TTag('lessons.lesson.streamed'.tr(), tone: TTone.liveSoft, icon: TGlyph.radio));
    }
    final s = c.seriesOf(l.seriesId);
    if (s != null && l.seq != null) out.add(TTag('lessons.lesson.of'.tr(args: ['${l.seq}', '${s.total}']), tone: TTone.slate, icon: TGlyph.repeat));
    if (l.language != 'ar') out.add(TTag(languageLabel(l.language), tone: TTone.info, icon: TGlyph.globe));
    if (l.interpretation != null) {
      out.add(TTag('lessons.lesson.interp_tag'.tr(args: [languageLabel(l.interpretation!)]), tone: TTone.info, icon: TGlyph.languages));
    }
    if (l.audience != 'all') out.add(TTag(audienceLabel(l.audience), tone: TTone.slate, icon: TGlyph.users));
    if (l.womenSection && l.audience != 'women') out.add(TTag('lessons.lesson.women_tag'.tr(), tone: TTone.slate, icon: TGlyph.users));
    if (out.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: out.take(max).toList());
  }
}

void openLesson(BuildContext context, String id) => context.push('/lessons/lesson/$id');

class LessonCard extends StatelessWidget {
  const LessonCard(this.lesson, {super.key, this.preview = false});
  final Lesson lesson;
  final bool preview;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final l = lesson, lang = context.lang;
    final p = c.preacher(l.preacherId);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TC.rLg),
      child: TCard(
        padding: EdgeInsets.zero,
        onTap: preview ? null : () => openLesson(context, l.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TCover(
              seed: l.id + l.mosqueId,
              glyph: typeGlyph(l.type),
              word: topicLabel(l.topic),
              tags: [if (c.isLiveNow(l)) const TLiveTag() else TypeTag(l.type)]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.title(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: tStrong(16)),
              const SizedBox(height: 8),
              if (p != null)
                Row(children: [
                  TAvatar(name: p.name(lang), size: 22, ring: false),
                  const SizedBox(width: 8),
                  Expanded(child: Text(p.name(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(13.5, color: TC.ink2, weight: FontWeight.w600))),
                ]),
              const SizedBox(height: 6),
              _Meta(TGlyph.pin, placeOf(c, l, lang)),
              _Meta(slotGlyph(l.slot), whenOf(c, l, lang)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: LessonBadges(l, max: 2)),
                if (!preview) RemindButton(l, compact: true),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.glyph, this.text);
  final TGlyph glyph;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          TIcon(glyph, size: 14, color: TC.goldIcon),
          const SizedBox(width: 6),
          Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(13, color: TC.muted, height: 1.4))),
        ]),
      );
}

class LessonRow extends StatelessWidget {
  const LessonRow(this.lesson, {super.key, this.showDate = false, this.extra});
  final Lesson lesson;
  final bool showDate;
  final Widget? extra;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final l = lesson, lang = context.lang;
    final p = c.preacher(l.preacherId);
    final t = clockLabel(c.startHours(l), lang);
    final cancelled = l.isCancelled;
    return Opacity(
      opacity: cancelled ? .72 : 1,
      child: TCard(
        padding: const EdgeInsets.all(12),
        onTap: () => openLesson(context, l.id),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 84,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            decoration: BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(TC.r)),
            child: Column(children: [
              TIcon(slotGlyph(l.slot), size: 18, color: TC.goldIcon),
              const SizedBox(height: 4),
              Text(l.exactTime != null ? t : slotLabel(l.slot), textAlign: TextAlign.center, style: tBody(12, color: TC.ink, weight: FontWeight.w700, height: 1.3)),
              Text(showDate ? gregorianLabel(l.date, lang, short: true) : (l.exactTime != null ? '' : '≈ $t'),
                  textAlign: TextAlign.center, style: tBody(11.5, color: TC.muted, height: 1.3)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                TypeTag(l.type),
                if (cancelled) TTag('lessons.status.cancelled'.tr(), tone: TTone.danger, icon: TGlyph.x),
              ]),
              const SizedBox(height: 6),
              Text(l.title(lang), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: tStrong(15).copyWith(decoration: cancelled ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Text([if (p != null) p.name(lang), placeOf(c, l, lang)].join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: tBody(13, color: TC.muted, height: 1.4)),
              const SizedBox(height: 6),
              LessonBadges(l),
              if (extra != null) Padding(padding: const EdgeInsets.only(top: 8), child: extra!),
            ]),
          ),
          Column(children: [
            RemindButton(l, compact: true),
            const TIcon(TGlyph.chevron, size: 18, color: TC.faint),
          ]),
        ]),
      ),
    );
  }
}

/// Lessons grouped under day headings with Gregorian and Hijri dates.
class LessonDayList extends StatelessWidget {
  const LessonDayList(this.lessons, {super.key, this.extra});
  final List<Lesson> lessons;
  final Widget? Function(Lesson)? extra;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final groups = <List<Lesson>>[];
    for (final l in lessons) {
      if (groups.isNotEmpty && sameDay(groups.last.first.date, l.date)) {
        groups.last.add(l);
      } else {
        groups.add([l]);
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final g in groups) ...[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, children: [
            Text(relativeDayLabel(g.first.date, lang), style: tDisplay(18)),
            Text(gregorianLabel(g.first.date, lang), style: tBody(13.5, color: TC.ink2, weight: FontWeight.w600)),
            Text(hijriLabel(g.first.date, lang), style: tBody(13, color: TC.bronze)),
            TTag(tPlural('lessons', g.length), tone: TTone.slate),
          ]),
        ),
        for (final l in g) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, extra: extra?.call(l))),
      ],
    ]);
  }
}

class RemindButton extends StatelessWidget {
  const RemindButton(this.lesson, {super.key, this.compact = false});
  final Lesson lesson;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    if (!lesson.isPublic || lesson.date.isBefore(c.today)) return const SizedBox.shrink();
    final on = c.hasReminder(lesson.id);
    void tap() => c.signedIn ? showRemindSheet(context, lesson) : showTSignIn(context, 'lessons.sign_in_remind'.tr());
    final label = on ? 'lessons.lesson.reminder_on'.tr() : 'lessons.lesson.remind'.tr();
    if (compact) {
      return Semantics(
        button: true,
        toggled: on,
        label: label,
        child: InkResponse(
          onTap: tap,
          radius: 22,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: on ? BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(20)) : null,
            child: TIcon(TGlyph.bell, size: 18, color: on ? TC.bronze : TC.muted, stroke: on ? 2.4 : 1.8),
          ),
        ),
      );
    }
    return TButton(label, kind: on ? TBtn.ink : TBtn.minted, icon: TGlyph.bell, onPressed: tap);
  }
}

class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.kind, required this.id, this.small = false, this.expand = false});
  final String kind, id;
  final bool small, expand;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final on = c.isFollowing(kind, id);
    return TButton(on ? 'lessons.follow.following'.tr() : 'lessons.follow.follow'.tr(),
        kind: on ? TBtn.ink : TBtn.outline,
        icon: on ? TGlyph.check : TGlyph.plus,
        small: small,
        expand: expand, onPressed: () {
      if (!c.signedIn) {
        showTSignIn(context, 'lessons.sign_in_follow'.tr());
        return;
      }
      tRun(context, () => c.toggleFollow(kind, id), success: on ? 'lessons.follow.off'.tr() : 'lessons.follow.on'.tr());
    });
  }
}

class AttendToggle extends StatelessWidget {
  const AttendToggle(this.lesson, {super.key});
  final Lesson lesson;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    if (!c.signedIn) return const SizedBox.shrink();
    final on = c.attended(lesson.id);
    return TChip(on ? 'lessons.calendar.attended'.tr() : 'lessons.calendar.did_attend'.tr(),
        small: true,
        selected: on,
        icon: TGlyph.check,
        onTap: () => tRun(context, () => c.toggleAttended(lesson.id),
            success: on ? 'lessons.calendar.removed_log'.tr() : 'lessons.calendar.added_log'.tr()));
  }
}

class PreacherCard extends StatelessWidget {
  const PreacherCard(this.preacher, {super.key});
  final Preacher preacher;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final p = preacher, lang = context.lang;
    final upcoming = c.upcoming.where((l) => l.preacherId == p.id).length;
    return TCard(
      onTap: () => context.push('/lessons/preachers/${p.id}'),
      child: Column(children: [
        TAvatar(name: p.name(lang), size: 64),
        const SizedBox(height: 10),
        Text(p.name(lang), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tStrong(15)),
        if (p.title(lang).isNotEmpty)
          Text(p.title(lang), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: tBody(13, color: TC.muted, height: 1.4)),
        const SizedBox(height: 6),
        Text('${cityLabel(p.city)} · ${p.languages.map((x) => LessonsVocab.languageNative[x] ?? x).join(' · ')}',
            textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(12.5, color: TC.muted, height: 1.4)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          TTag(tPlural('ahead', upcoming), tone: TTone.slate),
          if (p.affiliation == 'ministry') TTag('lessons.affiliation.ministry'.tr(), tone: TTone.info),
        ]),
        const SizedBox(height: 12),
        FollowButton(kind: 'preacher', id: p.id, small: true, expand: true),
      ]),
    );
  }
}

class SeriesCard extends StatelessWidget {
  const SeriesCard(this.series, {super.key});
  final LessonSeries series;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final s = series, lang = context.lang;
    final sessions = c.sessionsOf(s.id);
    final done = sessions.where((l) => l.date.isBefore(c.today)).length;
    final weekday = sessions.isEmpty ? '' : weekdayName(sessions.first.date, lang);
    return TCard(
      onTap: () => context.push('/lessons/series/${s.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const TIcon(TGlyph.repeat, size: 16, color: TC.goldIcon),
          const SizedBox(width: 6),
          Expanded(
              child: Text('${'lessons.time.every'.tr(args: [weekday])} · ${slotLabel(s.slot)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: tBody(12.5, color: TC.bronze, weight: FontWeight.w600, height: 1.3))),
        ]),
        const SizedBox(height: 8),
        Text(s.title(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: tStrong(15.5)),
        const SizedBox(height: 4),
        Text('${c.preacher(s.preacherId)?.name(lang) ?? ''} · ${c.mosque(s.mosqueId)?.name(lang) ?? ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(13, color: TC.muted, height: 1.4)),
        const SizedBox(height: 10),
        TMeter(value: done, max: s.total),
        const SizedBox(height: 4),
        Text('lessons.discover.done_of'.tr(args: ['$done', '${s.total}']), style: tBody(12.5, color: TC.muted, height: 1.4)),
      ]),
    );
  }
}

/// Today's lessons under each prayer, for one city.
class PrayerStrip extends StatefulWidget {
  const PrayerStrip({super.key});
  @override
  State<PrayerStrip> createState() => _PrayerStripState();
}

class _PrayerStripState extends State<PrayerStrip> {
  String city = 'khobar';
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final centre = LessonsVocab.cityCentre[city]!;
    final pt = PrayerTimes.on(c.today, centre.$1, centre.$2);
    final now = lessonsNowHours();
    final nextIdx = LessonsVocab.slots.indexWhere((s) => pt.of(s) > now);
    final today = c.upcoming.where((l) => sameDay(l.date, c.today) && c.cityOfMosque(l.mosqueId) == city).toList();
    final columns = [
      for (var i = 0; i < 5; i++)
        _PrayerColumn(
          slot: LessonsVocab.slots[i],
          time: clockLabel(pt.of(LessonsVocab.slots[i]), lang),
          state: nextIdx == -1 || i < nextIdx ? 0 : i == nextIdx ? 1 : 2,
          lessons: today.where((l) => l.slot == LessonsVocab.slots[i]).toList(),
        )
    ];
    return TCard(
      padding: EdgeInsets.all(context.wide ? 22 : 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, spacing: 12, runSpacing: 10, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            TEyebrow('${'lessons.time.today'.tr()} · ${hijriLabel(c.today, lang)}'),
            const SizedBox(height: 4),
            Text('lessons.discover.strip_title'.tr(), style: tDisplay(context.wide ? 22 : 18)),
          ]),
          TSeg<String>(
            small: true,
            value: city,
            onChanged: (v) => setState(() => city = v),
            options: [for (final x in LessonsVocab.mapCities) TSegOption(x, cityLabel(x))],
          ),
        ]),
        const SizedBox(height: 14),
        if (context.wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < 5; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: columns[i])]
          ])
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (var i = 0; i < 5; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                // Columns grow with the text size so the adhan time fits.
                SizedBox(width: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.8).scale(156), child: columns[i]),
              ]
            ]),
          ),
      ]),
    );
  }
}

class _PrayerColumn extends StatelessWidget {
  const _PrayerColumn({required this.slot, required this.time, required this.state, required this.lessons});
  final String slot, time;
  final int state; // 0 past, 1 next, 2 later
  final List<Lesson> lessons;
  @override
  Widget build(BuildContext context) {
    final c = context.read<LessonsController>();
    final lang = context.lang;
    final next = state == 1;
    return Opacity(
      opacity: state == 0 ? .62 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: next ? null : TC.page,
          gradient: next ? TC.night : null,
          borderRadius: BorderRadius.circular(TC.r),
          border: Border.all(color: next ? Colors.transparent : TC.hair),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            TIcon(slotGlyph(slot), size: 18, color: next ? TC.onNightGold : TC.goldIcon),
            const SizedBox(width: 6),
            Expanded(child: Text(prayerLabel(slot), style: tStrong(14, color: next ? TC.onNight : TC.ink))),
            Text(time, style: tBody(12.5, color: next ? TC.onNightGold : TC.muted, height: 1.2)),
          ]),
          if (next) Padding(padding: const EdgeInsets.only(top: 4), child: Text('lessons.discover.next_prayer'.tr(), style: tBody(11.5, color: TC.onNightGold, weight: FontWeight.w700))),
          const SizedBox(height: 8),
          if (lessons.isEmpty)
            Text('lessons.discover.no_lessons'.tr(), style: tBody(12.5, color: next ? TC.onNight2 : TC.faint))
          else
            for (final l in lessons)
              InkWell(
                onTap: () => openLesson(context, l.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (c.isLiveNow(l)) const Padding(padding: EdgeInsets.only(bottom: 4), child: TLiveTag()),
                    Text(l.title(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: tStrong(13, color: next ? TC.onNight : TC.ink)),
                    Text(c.mosque(l.mosqueId)?.name(lang) ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: tBody(12, color: next ? TC.onNight2 : TC.muted, height: 1.4)),
                  ]),
                ),
              ),
        ]),
      ),
    );
  }
}

/// A mosque row with its lesson count coin.
class MosqueRow extends StatelessWidget {
  const MosqueRow({super.key, required this.mosque, required this.count, this.subtitle, this.selected = false, this.onTap, this.live = false});
  final Mosque mosque;
  final int count;
  final String? subtitle;
  final bool selected, live;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? TC.tint : TC.card,
            borderRadius: BorderRadius.circular(TC.r),
            border: Border.all(color: selected ? TC.gold : TC.hair),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(TC.r),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: HidayahGradients.minted),
                  child: Text('$count', style: tStrong(13, color: TC.ink)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(mosque.name(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: tStrong(14)),
                    if (subtitle != null)
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(12.5, color: TC.muted, height: 1.4)),
                  ]),
                ),
                if (live) const TLiveTag() else const TIcon(TGlyph.chevron, size: 16, color: TC.faint),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Facilities as small labelled icons.
class FacilityList extends StatelessWidget {
  const FacilityList(this.facilities, {super.key, this.dense = false});
  final List<String> facilities;
  final bool dense;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 12, runSpacing: 6, children: [
        for (final f in facilities)
          Row(mainAxisSize: MainAxisSize.min, children: [
            TIcon(facilityGlyph(f), size: 14, color: TC.goldIcon),
            const SizedBox(width: 5),
            Text(facilityLabel(f), style: tBody(dense ? 12 : 13, color: TC.muted, height: 1.3)),
          ]),
      ]);
}

/// The approved lessons at a mosque between [from] and [to].
List<Lesson> lessonsAt(LessonsController c, String mosqueId, {DateTime? from, DateTime? to}) =>
    c.upcoming.where((l) => l.mosqueId == mosqueId && (from == null || !l.date.isBefore(from)) && (to == null || !l.date.isAfter(to))).toList();

/// Clashes for a candidate lesson, against everything the caller can see.
List<Lesson> candidateClashes(LessonsController c,
        {required String requestId, required DateTime date, required String slot, required String mosqueId, required String preacherId}) =>
    clashesFor((id: null, requestId: requestId, date: date, slot: slot, mosqueId: mosqueId, preacherId: preacherId), c.catalog.lessons.values);
