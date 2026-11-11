import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../profile/models/streamer_models.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_names.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/prayer_times.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart' show tPlural;
import '../lessons_widgets.dart' show topicLabel;
import 'lantern_lessons_parts.dart';

/// The Lessons tab in the Lantern design (/lessons): a night hero with the
/// search and tonight's lessons by prayer, the admins' band, then Live now,
/// Upcoming, Weekly series, community languages, preachers and the map.
/// Every value comes from LessonsDiscoverScreen.
class LanternLessonsHome extends StatelessWidget implements LanternSkinWidget {
  const LanternLessonsHome(
      {super.key,
      required this.upcoming,
      required this.week,
      required this.tonight,
      required this.hero,
      required this.prayer,
      required this.mosquesWeek,
      required this.series,
      required this.preachers,
      required this.langCounts,
      required this.live});

  final List<Lesson> upcoming, week, tonight, hero;
  final PrayerTimes prayer;
  final int mosquesWeek;
  final List<LessonSeries> series;
  final List<Preacher> preachers;
  final List<(String, int)> langCounts;
  final List<StreamerModel> live;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final wide = context.lanternWide;
    final loading = !c.loaded && c.failure == null;
    if (!c.loaded && c.failure != null && !c.loading) {
      return const LLessonsTabScroll(children: [
        SizedBox(height: 28),
        LLessonsError(),
      ]);
    }
    final now = DateTime.now();
    final atMosques = loading
        ? const <Lesson>[]
        : upcoming
            .where((l) =>
                sameDay(l.date, c.today) &&
                lessonTiming(l, c.catalog, now).phase == LessonPhase.running)
            .toList();
    final hero = _Hero(
        loading: loading,
        tonight: tonight.isNotEmpty,
        lessons: this.hero,
        prayer: prayer,
        stats: [
          (week.length, 'lessons.discover.stat_week'.tr()),
          (mosquesWeek, 'lessons.discover.stat_mosques'.tr()),
          (c.listedPreachers.length, 'lessons.discover.stat_preachers'.tr()),
          (series.length, 'lessons.discover.stat_series'.tr()),
        ]);
    final subjects = Padding(
        padding: const EdgeInsets.only(top: 22),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          LChip(
              label: 'lessons.discover.all_subjects'.tr(),
              selected: true,
              dense: true,
              onTap: () => context.go('/lessons/calendar')),
          for (final t in LessonsNames.topics)
            LChip(
                label: topicLabel(t),
                dense: true,
                onTap: () => context.go('/lessons/calendar?topic=$t')),
        ]));
    final children = <Widget>[
      if (c.canManage) const _AdminBand(),
      if (loading) ...[
        LLessonsSection(
            title: 'lessons.discover.upcoming'.tr(),
            child: wide
                ? LGrid(columns: 3, children: [
                    for (var i = 0; i < 3; i++)
                      const LSkeleton(height: 200, radius: Lantern.radiusCard)
                  ])
                : const LLessonsSkeleton(rows: 3, height: 120)),
      ] else if (upcoming.isEmpty) ...[
        const SizedBox(height: 32),
        Container(
            decoration: BoxDecoration(
                color: context.lt.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: context.lt.line)),
            child: LEmptyState(
                key: const ValueKey('lantern-lessons-empty'),
                icon: LGlyph.book,
                title: 'lessons.discover.empty'.tr(),
                body: 'lessons.discover.empty_body'.tr())),
      ] else ...[
        subjects,
        if (live.isNotEmpty || atMosques.isNotEmpty)
          LLessonsSection(
              title: 'lessons.discover.live_now'.tr(),
              child: _LiveNow(live: live, atMosques: atMosques)),
        LLessonsSection(
            title: 'lessons.discover.upcoming'.tr(),
            count: tPlural('lessons', upcoming.length),
            action: 'lessons.see_all'.tr(),
            onAction: () => context.go('/lessons/calendar'),
            child: wide
                ? LGrid(columns: 3, children: [
                    for (final l in upcoming.take(6)) LLessonCard(l)
                  ])
                : Column(children: [
                    for (final l in upcoming.take(4))
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: LLessonCard(l)),
                  ])),
        if (series.isNotEmpty)
          LLessonsSection(
              title: 'lessons.discover.series_title'.tr(),
              child: _Rail(children: [for (final s in series) LSeriesCard(s)])),
        if (langCounts.isNotEmpty)
          LLessonsSection(
              title: 'lessons.discover.langs_title'.tr(),
              subtitle: 'lessons.discover.langs_sub'.tr(),
              child: LGrid(
                  columns: wide ? 4 : 1,
                  gap: wide ? 20 : 12,
                  children: [
                    for (final (x, n) in langCounts)
                      LLanguageCard(code: x, count: n)
                  ])),
        if (preachers.isNotEmpty)
          LLessonsSection(
              title: 'lessons.discover.preachers_title'.tr(),
              count: tPlural('preachers', c.listedPreachers.length),
              child: LGrid(
                  columns: wide ? 3 : 1,
                  gap: wide ? 20 : 12,
                  children: [
                    for (final p in preachers.take(6)) LPreacherCard(p)
                  ])),
      ],
      Padding(
          padding: EdgeInsets.only(top: wide ? 44 : 30),
          child: const LMapTeaser()),
    ];
    return LLessonsTabScroll(header: hero, children: children);
  }
}

class _Hero extends StatelessWidget implements LanternSkinWidget {
  const _Hero(
      {required this.loading,
      required this.tonight,
      required this.lessons,
      required this.prayer,
      required this.stats});

  final bool loading, tonight;
  final List<Lesson> lessons;
  final PrayerTimes prayer;
  final List<(int, String)> stats;

  @override
  Widget build(BuildContext context) {
    final wide = context.lanternWide;
    return LNightBand(
        glow: const AlignmentDirectional(-.7, -.7).resolve(Directionality.of(context)),
        padding: EdgeInsets.symmetric(vertical: wide ? 48 : 28),
        child: LLessonsColumn(
            child: Builder(builder: (context) {
          final copy = _HeroCopy(loading: loading, stats: stats);
          final panel = _TonightPanel(
              loading: loading,
              tonight: tonight,
              lessons: lessons,
              prayer: prayer);
          if (!wide) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [copy, const SizedBox(height: 26), panel]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: copy),
            const SizedBox(width: 44),
            SizedBox(width: 480, child: panel),
          ]);
        })));
  }
}

class _HeroCopy extends StatelessWidget implements LanternSkinWidget {
  const _HeroCopy({required this.loading, required this.stats});

  final bool loading;
  final List<(int, String)> stats;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LEyebrow('lessons.discover.hero_eyebrow'.tr(),
              color: LanternTokens.goldHi),
          const SizedBox(height: 14),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Semantics(
                  header: true,
                  child: Text('lessons.discover.hero_title'.tr(),
                      style: Lantern.displayStyle(wide ? 42 : 30,
                          color: LanternTokens.onNight,
                          height: context.lanternArabic ? 1.4 : 1.15)))),
          const SizedBox(height: 14),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Text('lessons.discover.hero_body'.tr(),
                  style: Lantern.textStyle(wide ? 16.5 : 15.5,
                      color: t.muted, height: 1.7))),
          const SizedBox(height: 22),
          const _SearchPill(),
          const SizedBox(height: 18),
          Wrap(spacing: 12, runSpacing: 12, children: [
            LButton(
                label: 'lessons.discover.this_week'.tr(),
                icon: LGlyph.calendar,
                onPressed: () => context.go('/lessons/calendar')),
            LButton(
                label: 'lessons.discover.open_map'.tr(),
                kind: LButtonKind.secondary,
                icon: LGlyph.map,
                onPressed: () => context.go('/map')),
          ]),
          const SizedBox(height: 30),
          Container(height: 1, color: t.line),
          const SizedBox(height: 22),
          Wrap(spacing: wide ? 36 : 22, runSpacing: 16, children: [
            for (final (n, label) in stats)
              Semantics(
                  label: '${loading ? '' : n} $label',
                  child: ExcludeSemantics(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text(loading ? '—' : '$n',
                            style: Lantern.displayStyle(wide ? 30 : 24,
                                    color: LanternTokens.goldHi, height: 1.1)
                                .copyWith(fontFeatures: Lantern.tabular)),
                        const SizedBox(height: 4),
                        Text(label,
                            style: Lantern.textStyle(13.5,
                                color: t.muted, height: 1.3)),
                      ]))),
          ]),
        ]);
  }
}

/// The search in the hero: opens the calendar, where the search is.
class _SearchPill extends StatelessWidget implements LanternSkinWidget {
  const _SearchPill();

  @override
  Widget build(BuildContext context) {
    final hint = 'lessons.discover.search_hint'.tr();
    return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: LPressable(
            key: const ValueKey('lantern-lessons-search'),
            onTap: () => context.go('/lessons/calendar'),
            label: hint,
            excludeChildSemantics: true,
            pressScale: .99,
            builder: (context, s) => AnimatedContainer(
                duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                    color: LanternTokens.white.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(Lantern.radiusPill),
                    boxShadow: s.hovered
                        ? [
                            BoxShadow(
                                color: LanternTokens.dark.glow,
                                blurRadius: 0,
                                spreadRadius: 3)
                          ]
                        : null),
                child: Row(children: [
                  const LIcon(LGlyph.search,
                      size: 18, color: LanternTokens.slate),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(14.5,
                              color: LanternTokens.slate, height: 1.3))),
                ]))));
  }
}

/// Tonight in the Eastern Province: the dates, the prayers with the next
/// one in gold, tonight's lessons (tomorrow's when none are left), and the
/// week.
class _TonightPanel extends StatelessWidget implements LanternSkinWidget {
  const _TonightPanel(
      {required this.loading,
      required this.tonight,
      required this.lessons,
      required this.prayer});

  final bool loading, tonight;
  final List<Lesson> lessons;
  final PrayerTimes prayer;

  @override
  Widget build(BuildContext context) {
    final c = context.read<LessonsController>();
    final t = context.lt;
    final lang = lessonsLang(context);
    final day = tonight ? c.today : addDays(c.today, 1);
    return Container(
        key: const ValueKey('lantern-lessons-tonight'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: lGlass(.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: lGlass(.12))),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    Semantics(
                        header: true,
                        child: Text(
                            (tonight
                                    ? 'lessons.discover.tonight_in'
                                    : 'lessons.discover.tomorrow_in')
                                .tr(),
                            style: Lantern.displayStyle(17,
                                color: LanternTokens.onNight,
                                height: lHeadHeight(context)))),
                    Text(
                        '${hijriLabel(day, lang)} · ${gregorianLabel(day, lang)}',
                        style: Lantern.textStyle(13, color: t.muted)),
                  ]),
              const SizedBox(height: 12),
              LPrayerStrip(
                  times: prayer,
                  glass: true,
                  active: tonight ? LPrayerStrip.nextPrayer(prayer) : null),
              const SizedBox(height: 12),
              if (loading)
                for (var i = 0; i < 3; i++)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: LSkeleton(height: 58, radius: 16))
              else if (lessons.isEmpty)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Text('lessons.discover.no_lessons'.tr(),
                        style: Lantern.textStyle(14, color: t.muted)))
              else
                for (final l in lessons)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: LLessonRow(l, glass: true)),
              const SizedBox(height: 4),
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: LLink('lessons.discover.all_week'.tr(),
                      onTap: () => context.go('/lessons/calendar'))),
            ]));
  }
}

/// For admins: what waits for review, Open review and Add lesson.
class _AdminBand extends StatelessWidget implements LanternSkinWidget {
  const _AdminBand();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final n = c.pendingRequests.length + c.pendingEdits.length;
    return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Container(
            key: const ValueKey('lantern-lessons-admin'),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
                color: t.sunk,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.line)),
            child: Wrap(
                spacing: 14,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    LIcon(LGlyph.shield, size: 20, color: t.goldInk),
                    const SizedBox(width: 10),
                    Flexible(
                        child: Text.rich(
                            TextSpan(
                                text: 'lessons.me.console'.tr(),
                                style: Lantern.textStyle(14.5,
                                    color: t.fg, weight: FontWeight.w600),
                                children: [
                                  TextSpan(
                                      text:
                                          ' · ${tPlural('requests', n)} ${'lessons.discover.waiting'.tr()}',
                                      style: Lantern.textStyle(14,
                                          color: t.muted)),
                                ]))),
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    LButton(
                        label: 'lessons.discover.open_review'.tr(),
                        size: LButtonSize.small,
                        onPressed: () =>
                            context.push('/admin/lessons/approvals')),
                    LButton(
                        label: 'lessons.admin.add_lesson'.tr(),
                        kind: LButtonKind.secondary,
                        size: LButtonSize.small,
                        icon: LGlyph.plus,
                        onPressed: () => context.push('/admin/lessons/add')),
                  ]),
                ])));
  }
}

/// Live now: the live channel next to the lessons on now at mosques.
class _LiveNow extends StatelessWidget implements LanternSkinWidget {
  const _LiveNow({required this.live, required this.atMosques});

  final List<StreamerModel> live;
  final List<Lesson> atMosques;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    final mosques = atMosques.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                        color: t.okSoft,
                        borderRadius: BorderRadius.circular(Lantern.radiusField)),
                    child: Row(children: [
                      LIcon(LGlyph.mosque, size: 18, color: t.ok),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(
                              'lantern.lessons.home.at_mosques'.tr(
                                  args: [tPlural('lessons', atMosques.length)]),
                              style: Lantern.textStyle(13.5,
                                  color: t.ok, weight: FontWeight.w600))),
                    ])),
                for (final l in atMosques.take(3))
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LLessonRow(l)),
              ]);
    final streams = [for (final s in live.take(mosques == null ? 2 : 1)) _LiveStreamCard(s)];
    final parts = [...streams, if (mosques != null) mosques];
    if (wide) {
      return LGrid(columns: 2, children: parts);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (i, p) in parts.indexed) ...[
        if (i > 0) const SizedBox(height: 14),
        p,
      ],
    ]);
  }
}

class _LiveStreamCard extends StatelessWidget implements LanternSkinWidget {
  const _LiveStreamCard(this.s);

  final StreamerModel s;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = lessonsLang(context);
    final audio = s.isAudioLive;
    final banner = resolveImageProviderOrNull(s.bannerUrl);
    void open() => context.push(s.activeStreamId == null
        ? '/profile/${s.streamerId}'
        : '/live/${s.activeStreamId}');
    return LCard(
        onTap: open,
        label: '${s.getLocalizedName(lang)}, ${s.getLocalizedTitle(lang)}',
        padding: EdgeInsets.zero,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LanternSurface(
                      night: true,
                      child: Stack(fit: StackFit.expand, children: [
                        const DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                              LanternTokens.goldLo,
                              LanternTokens.ink
                            ]))),
                        if (banner != null)
                          Opacity(
                              opacity: .55,
                              child: Image(
                                  image: banner,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink())),
                        DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                              lNightFade(0),
                              lNightFade(.7)
                            ]))),
                        FractionallySizedBox(
                            widthFactor: .46,
                            heightFactor: .8,
                            alignment: Alignment.bottomCenter,
                            child: DecoratedBox(
                                decoration: ShapeDecoration(
                                    color: lGlass(.08),
                                    shape: LArchBorder(
                                        side: BorderSide(
                                            color: LanternTokens.white
                                                .withValues(alpha: .14)))))),
                        PositionedDirectional(
                            top: 14,
                            start: 14,
                            child: audio
                                ? LBadge('web.listen'.tr(),
                                    kind: LBadgeKind.audio)
                                : LBadge('lessons.lesson.live'.tr(),
                                    kind: LBadgeKind.live)),
                        if (s.activeViewerCount > 0)
                          PositionedDirectional(
                              top: 14,
                              end: 14,
                              child: LBadge('${s.activeViewerCount}',
                                  kind: LBadgeKind.glass, icon: LGlyph.eye)),
                      ]))),
              Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    LAvatar(
                        name: s.getLocalizedName(lang),
                        image: resolveImageProviderOrNull(s.avatarUrl),
                        size: 46,
                        ring: audio ? LRing.audio : LRing.live,
                        verified: s.isVerified),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          Text(s.getLocalizedTitle(lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Lantern.textStyle(15,
                                  color: t.fg,
                                  weight: FontWeight.w600,
                                  height: 1.3)),
                          Text(s.getLocalizedName(lang),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Lantern.textStyle(12.5,
                                  color: t.muted, height: 1.4)),
                        ])),
                    const SizedBox(width: 8),
                    LButton(
                        label: (audio ? 'web.listen' : 'web.watch').tr(),
                        size: LButtonSize.small,
                        icon: audio ? LGlyph.audio : LGlyph.live,
                        onPressed: open),
                  ])),
            ]));
  }
}

/// A row of cards that scrolls sideways.
class _Rail extends StatelessWidget implements LanternSkinWidget {
  const _Rail({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final wide = context.lanternWide;
    final w = wide
        ? 290.0
        : (MediaQuery.sizeOf(context).width - 2 * Lantern.gutter) * .84;
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (final (i, child) in children.indexed) ...[
                    if (i > 0) const SizedBox(width: 16),
                    SizedBox(width: w, child: child),
                  ],
                ]))));
  }
}
