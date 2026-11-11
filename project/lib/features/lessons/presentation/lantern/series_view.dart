import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../domain/lessons_models.dart';
import 'lantern_lessons_parts.dart';

/// A series that is not in the programme.
class LanternSeriesMissing extends StatelessWidget implements LanternSkinWidget {
  const LanternSeriesMissing({super.key});

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Builder(
          builder: (context) => LLessonsPage(
                  title: 'lessons.nav.series'.tr(),
                  children: [
                    const SizedBox(height: 24),
                    Container(
                        decoration: BoxDecoration(
                            color: context.lt.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: context.lt.line)),
                        child: LEmptyState(
                            key: const ValueKey('lantern-series-missing'),
                            icon: LGlyph.history,
                            title: 'lessons.lesson.not_found'.tr(),
                            body: 'lantern.lessons.lesson.not_found_body'.tr(),
                            action: LButton(
                                label: 'lessons.see_all'.tr(),
                                icon: LGlyph.calendar,
                                onPressed: () =>
                                    context.go('/lessons/calendar')))),
                  ])));
}

/// The series page in the Lantern design (/lessons/series/:id): its title,
/// who gives it, where and when, Follow and the next session, how far it
/// has come, then every session. Values come from LessonSeriesScreen.
class LanternSeriesView extends StatelessWidget implements LanternSkinWidget {
  const LanternSeriesView(
      {super.key,
      required this.series,
      required this.subtitle,
      required this.sessions,
      required this.done,
      required this.next});

  final LessonSeries series;

  /// Preacher · mosque · every weekday and prayer, as the older screen
  /// writes it.
  final String subtitle;
  final List<Lesson> sessions;

  /// Sessions already held, and the next one to come.
  final int done;
  final Lesson? next;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    final lang = lessonsLang(context);
    final s = series;
    final total = s.total <= 0 ? 1 : s.total;

    final head = LCard(
        key: const ValueKey('lantern-series-head'),
        padding: EdgeInsets.all(wide ? 28 : 20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              LCrumb([
                ('lessons.nav.lessons'.tr(), () => context.go('/lessons')),
                ('lessons.calendar.title'.tr(),
                    () => context.go('/lessons/calendar')),
                (s.title(lang), null),
              ]),
              const SizedBox(height: 16),
              LEyebrow('lessons.lesson.series'.tr()),
              const SizedBox(height: 8),
              Semantics(
                  header: true,
                  child: Text(s.title(lang),
                      style: Lantern.displayStyle(wide ? 30 : 24,
                          color: t.fg, height: lHeadHeight(context)))),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: Lantern.textStyle(14, color: t.muted, height: 1.5)),
              const SizedBox(height: 16),
              Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LFollowButton(
                        kind: 'series', id: s.id, style: LButtonKind.primary),
                    if (next != null)
                      LButton(
                          key: const ValueKey('lantern-series-next'),
                          label: 'lessons.lesson.upcoming'.tr(),
                          kind: LButtonKind.secondary,
                          icon: LGlyph.calendar,
                          onPressed: () =>
                              context.push('/lessons/lesson/${next!.id}')),
                  ]),
              const SizedBox(height: 18),
              LFillBar(done / total,
                  label: 'lessons.discover.done_of'
                      .tr(args: ['$done', '${s.total}'])),
              const SizedBox(height: 6),
              Text('lessons.discover.done_of'.tr(args: ['$done', '${s.total}']),
                  style: Lantern.textStyle(13, color: t.muted, height: 1.4)
                      .copyWith(fontFeatures: Lantern.tabular)),
            ]));

    return LLessonsPage(title: 'lessons.nav.series'.tr(), children: [
      head,
      LLessonsSection(
          key: const ValueKey('lantern-series-sessions'),
          title: 'lessons.nav.lessons'.tr(),
          count: '${sessions.length}',
          child: Column(children: [
            for (final l in sessions)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: LLessonRow(l, showDate: true)),
          ])),
    ]);
  }
}
