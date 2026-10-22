import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../profile/models/streamer_models.dart';
import '../../domain/prayer_times.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_in_app.dart';
import '../lessons_shell.dart';
import '../lessons_widgets.dart';

class LessonsDiscoverScreen extends StatelessWidget {
  const LessonsDiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang, wide = context.wide;
    final upcoming = c.upcoming;
    final week = upcoming.where((l) => !l.date.isAfter(addDays(c.today, 6))).toList();
    final nowH = lessonsNowHours();
    final tonight = upcoming.where((l) => sameDay(l.date, c.today) && c.startHours(l) > nowH - 1).take(4).toList();
    final hero = tonight.isNotEmpty ? tonight : upcoming.where((l) => sameDay(l.date, addDays(c.today, 1))).take(4).toList();
    final kpt = PrayerTimes.on(c.today, 26.28, 50.21);
    final mosquesWeek = week.map((l) => l.mosqueId).toSet().length;
    final series = c.approvedSeries;
    final preachers = c.listedPreachers.take(wide ? 8 : 6).toList();
    final langCounts = [
      for (final x in LessonsVocab.languages.where((x) => x != 'ar'))
        (x, upcoming.where((l) => l.language == x || l.interpretation == x).length)
    ].where((e) => e.$2 > 0).toList();
    final live = context.select<AppProvider, List<StreamerModel>>((a) => a.streamers.where((s) => s.isCurrentlyLive).take(3).toList());

    final heroItems = [
      for (final l in hero)
        InkWell(
          onTap: () => openLesson(context, l.id),
          borderRadius: BorderRadius.circular(TC.r),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            child: Row(children: [
              SizedBox(
                width: wide ? 112 : 96,
                child: Row(children: [
                  TIcon(slotGlyph(l.slot), size: 16, color: TC.onNightGold),
                  const SizedBox(width: 5),
                  Flexible(child: Text(slotLabel(l.slot), style: tBody(12.5, color: TC.onNightGold, weight: FontWeight.w700, height: 1.3))),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.title(lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: tStrong(14.5, color: TC.onNight)),
                  Text('${c.preacher(l.preacherId)?.name(lang) ?? ''} · ${c.mosque(l.mosqueId)?.name(lang) ?? ''}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(12, color: TC.onNight2, height: 1.4)),
                ]),
              ),
              if (c.isLiveNow(l)) const TLiveTag() else const TIcon(TGlyph.chevron, size: 16, color: TC.onNight2),
            ]),
          ),
        ),
    ];
    final tonightBox = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0x0AFFFFFF), borderRadius: BorderRadius.circular(TC.rXl), border: Border.all(color: TC.nightLine)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, spacing: 8, children: [
          Text(tonight.isNotEmpty ? 'lessons.discover.tonight_in'.tr() : 'lessons.discover.tomorrow_in'.tr(), style: tDisplay(19, color: TC.onNight)),
          Text('${prayerLabel('maghrib')} ${clockLabel(kpt.maghrib, lang)} · ${prayerLabel('isha')} ${clockLabel(kpt.isha, lang)}',
              style: tBody(12.5, color: TC.onNightGold)),
        ]),
        const Divider(color: TC.nightLine, height: 18),
        if (heroItems.isEmpty) Text('lessons.discover.no_lessons'.tr(), style: tBody(13, color: TC.onNight2)) else ...heroItems,
        const SizedBox(height: 6),
        TButton('lessons.discover.all_week'.tr(), kind: TBtn.night, iconEnd: TGlyph.arrowEnd, onPressed: () => context.go('/lessons/calendar')),
      ]),
    );

    final heroBand = TNight(
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16, vertical: wide ? 48 : 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(flex: 23, child: _HeroCopy(week: week.length, mosques: mosquesWeek, preachers: c.listedPreachers.length, series: series.length)),
                  const SizedBox(width: 40),
                  Expanded(flex: 17, child: tonightBox),
                ])
              : tonightBox,
        ),
      ),
    );

    final roleBand = c.canManage
        ? _RoleBand(
            glyph: TGlyph.inbox,
            title: 'lessons.admin.title'.tr(),
            body: '${tPlural('requests', c.pendingRequests.length + c.pendingEdits.length)} ${'lessons.discover.waiting'.tr()}',
            actions: [
              TButton('lessons.discover.open_review'.tr(), kind: TBtn.minted, small: true, iconEnd: TGlyph.arrowEnd,
                  onPressed: () => context.push('/admin/lessons/approvals')),
              TButton('lessons.admin.add_lesson'.tr(), small: true, icon: TGlyph.plus, onPressed: () => context.push('/admin/lessons/add')),
            ])
        : null;

    final topics = Wrap(spacing: 8, runSpacing: 8, children: [
      TChip('lessons.discover.all_subjects'.tr(), selected: true, small: true, onTap: () => context.go('/lessons/calendar')),
      for (final t in LessonsVocab.topics) TChip(topicLabel(t), small: true, onTap: () => context.go('/lessons/calendar?topic=$t')),
    ]);

    return LessonsTabBody(
      header: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (!wide)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TSearchBox(hint: 'lessons.discover.search_hint'.tr(), readOnly: true, onTap: () => context.go('/lessons/calendar')),
          ),
        heroBand,
        if (wide)
          Container(
            color: TC.card,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(children: [
                  Expanded(child: topics),
                  const SizedBox(width: 16),
                  SizedBox(width: 320, child: TSearchBox(hint: 'lessons.discover.search_hint'.tr(), readOnly: true, onTap: () => context.go('/lessons/calendar'))),
                ]),
              ),
            ),
          ),
      ]),
      children: [
        if (!wide) topics,
        if (roleBand != null) roleBand,
        const PrayerStrip(),
        if (live.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TSectionHead('lessons.discover.live_now'.tr(), count: live.length),
            TGrid(minWidth: 280, children: [for (final s in live) _LiveChannelCard(s)]),
          ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TSectionHead('lessons.discover.upcoming'.tr(),
              count: upcoming.length,
              action: TButton('lessons.see_all'.tr(), kind: TBtn.ghost, iconEnd: TGlyph.arrowEnd, onPressed: () => context.go('/lessons/calendar'))),
          if (upcoming.isEmpty)
            TEmpty(icon: TGlyph.book, title: 'lessons.discover.empty'.tr(), body: 'lessons.discover.empty_body'.tr())
          else if (wide)
            TGrid(minWidth: 340, children: [for (final l in upcoming.take(6)) LessonCard(l)])
          else
            Column(children: [for (final l in upcoming.take(5)) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, showDate: true))]),
        ]),
        if (wide) const _HowItWorks(),
        if (series.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TSectionHead('lessons.discover.series_title'.tr(), count: series.length),
            TGrid(minWidth: 260, children: [for (final s in series) SeriesCard(s)]),
          ]),
        if (langCounts.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TSectionHead('lessons.discover.langs_title'.tr(), sub: 'lessons.discover.langs_sub'.tr()),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (x, n) in langCounts)
                TCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  onTap: () => context.go('/lessons/calendar?lang=$x'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(LessonsVocab.languageNative[x]!, style: tDisplay(18)),
                    Text('${languageLabel(x)} · ${tPlural('lessons', n)}', style: tBody(12.5, color: TC.muted, height: 1.4)),
                  ]),
                ),
            ]),
          ]),
        if (preachers.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TSectionHead('lessons.discover.preachers_title'.tr(), count: c.listedPreachers.length),
            TGrid(minWidth: 220, children: [for (final p in preachers) PreacherCard(p)]),
          ]),
        MapPreviewCard(title: 'lessons.discover.map_title'.tr(), body: 'lessons.discover.map_body'.tr()),
      ],
    );
  }
}

class _HeroCopy extends StatelessWidget {
  const _HeroCopy({required this.week, required this.mosques, required this.preachers, required this.series});
  final int week, mosques, preachers, series;
  @override
  Widget build(BuildContext context) {
    Widget stat(int n, String label) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$n', style: tDisplay(30, color: TC.onNightGold)),
            Text(label, style: tBody(13, color: TC.onNight2, height: 1.4)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TEyebrow('lessons.discover.hero_eyebrow'.tr(), onNight: true),
      const SizedBox(height: 14),
      Text('lessons.discover.hero_title'.tr(), style: tDisplay(42, color: TC.onNight).copyWith(height: 1.25)),
      const SizedBox(height: 14),
      ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text('lessons.discover.hero_body'.tr(), style: tBody(16, color: TC.onNight2, height: 1.9))),
      const SizedBox(height: 22),
      Wrap(spacing: 10, runSpacing: 10, children: [
        TButton('lessons.discover.this_week'.tr(), kind: TBtn.minted, large: true, icon: TGlyph.calendar, onPressed: () => context.go('/lessons/calendar')),
        TButton('lessons.discover.open_map'.tr(), kind: TBtn.night, large: true, icon: TGlyph.map, onPressed: () => context.go('/map')),
      ]),
      const SizedBox(height: 28),
      const Divider(color: TC.nightLine, height: 1),
      const SizedBox(height: 16),
      Row(children: [
        stat(week, 'lessons.discover.stat_week'.tr()),
        stat(mosques, 'lessons.discover.stat_mosques'.tr()),
        stat(preachers, 'lessons.discover.stat_preachers'.tr()),
        stat(series, 'lessons.discover.stat_series'.tr()),
      ]),
    ]);
  }
}

class _RoleBand extends StatelessWidget {
  const _RoleBand({required this.glyph, required this.title, required this.body, required this.actions});
  final TGlyph glyph;
  final String title, body;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(TC.rLg), border: Border.all(color: TC.hair2)),
        child: Wrap(spacing: 14, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TIcon(glyph, size: 20, color: TC.goldIcon),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 520),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: tStrong(15)),
              Text(body, style: tBody(14, color: TC.muted, height: 1.5)),
            ]),
          ),
          ...actions,
        ]),
      );
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TSectionHead('lessons.discover.how_title'.tr(), eyebrow: 'lessons.discover.how_eyebrow'.tr()),
        TGrid(minWidth: 300, children: [
          for (var i = 1; i <= 3; i++)
            TCard(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: HidayahGradients.minted),
                  child: Text('$i', style: tStrong(14)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('lessons.discover.how_${i}_t'.tr(), style: tStrong(15)),
                    const SizedBox(height: 4),
                    Text('lessons.discover.how_${i}_b'.tr(), style: tBody(14, color: TC.muted)),
                  ]),
                ),
              ]),
            ),
        ]),
      ]);
}

class _LiveChannelCard extends StatelessWidget {
  const _LiveChannelCard(this.s);
  final StreamerModel s;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return ClipRRect(
      borderRadius: BorderRadius.circular(TC.rLg),
      child: TCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push(s.activeStreamId == null ? '/profile/${s.streamerId}' : '/live/${s.activeStreamId}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TCover(seed: s.streamerId, glyph: TGlyph.radio, word: s.getLocalizedName(lang), tags: const [TLiveTag()]),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(s.getLocalizedTitle(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: tStrong(15)),
          ),
        ]),
      ),
    );
  }
}
