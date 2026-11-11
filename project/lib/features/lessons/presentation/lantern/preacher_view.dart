import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../profile/models/streamer_models.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_widgets.dart' show cityLabel, languageLabel;
import 'lantern_lessons_actions.dart';
import 'lantern_lessons_parts.dart';

/// A preacher who is not in the list.
class LanternPreacherMissing extends StatelessWidget
    implements LanternSkinWidget {
  const LanternPreacherMissing({super.key});

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Builder(
          builder: (context) => LLessonsPage(
                  title: 'lessons.nav.preacher'.tr(),
                  children: [
                    const SizedBox(height: 24),
                    Container(
                        decoration: BoxDecoration(
                            color: context.lt.surface,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: context.lt.line)),
                        child: LEmptyState(
                            key: const ValueKey('lantern-preacher-missing'),
                            icon: LGlyph.person,
                            title: 'lessons.preacher.not_found'.tr(),
                            action: LButton(
                                label: 'lessons.nav.lessons'.tr(),
                                onPressed: () => context.go('/lessons')))),
                  ])));
}

/// The preacher page in the Lantern design (/lessons/preachers/:id): a
/// night header with his photo, marks, Follow, his channel and the link,
/// four counts, then Upcoming, Series, Past and About. Values and the tab
/// come from PreacherScreen.
class LanternPreacherView extends StatelessWidget implements LanternSkinWidget {
  const LanternPreacherView(
      {super.key,
      required this.preacher,
      required this.upcoming,
      required this.past,
      required this.series,
      required this.places,
      required this.channel,
      required this.bio,
      required this.tab,
      required this.onTab});

  final Preacher preacher;
  final List<Lesson> upcoming, past;
  final List<LessonSeries> series;
  final List<Mosque> places;
  final StreamerModel? channel;
  final String bio, tab;
  final ValueChanged<String> onTab;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final wide = context.lanternWide;
    final lang = lessonsLang(context);
    final p = preacher;

    Widget empty(String key, String title, {String? body, Widget? action}) =>
        Container(
            decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: t.line)),
            child: LEmptyState(
                key: ValueKey(key),
                icon: LGlyph.book,
                title: title,
                body: body,
                action: action));
    Widget cards(List<Widget> xs) => wide
        ? LGrid(columns: 3, children: xs)
        : Column(children: [
            for (final x in xs)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: x),
          ]);

    final body = switch (tab) {
      'upcoming' => upcoming.isEmpty
          ? empty('lantern-preacher-no-upcoming',
              'lessons.preacher.no_upcoming'.tr(),
              body: 'lessons.preacher.follow_hint'.tr(),
              action: LFollowButton(kind: 'preacher', id: p.id))
          : cards([for (final l in upcoming) LLessonCard(l)]),
      'series' => series.isEmpty
          ? empty('lantern-preacher-no-series',
              'lantern.lessons.preacher.no_series'.tr())
          : cards([for (final s in series) LSeriesCard(s)]),
      'past' => past.isEmpty
          ? empty('lantern-preacher-no-past',
              'lantern.lessons.preacher.no_past'.tr())
          : Column(children: [
              for (final l in past.take(12))
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LLessonRow(l, showDate: true)),
            ]),
      _ => LPanel(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
              Text(bio, style: Lantern.textStyle(15, color: t.fg, height: 1.8)),
              const SizedBox(height: 14),
              LKv([
                (
                  'lessons.preacher.languages'.tr(),
                  p.languages.map(languageLabel).join('، ')
                ),
                (
                  'lessons.preacher.affiliation'.tr(),
                  'lessons.affiliation.${p.affiliation}'.tr()
                ),
              ]),
            ])),
    };

    // The band is always night: its text reads the night colours.
    final header = LNightBand(
        padding: EdgeInsets.only(top: 22, bottom: wide ? 30 : 24),
        child: Builder(builder: (context) {
          final t = context.lt;
          return LLessonsColumn(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
              LCrumb([
                ('lessons.nav.lessons'.tr(), () => context.go('/lessons')),
                ('lantern.lessons.preachers'.tr(), () => context.go('/lessons')),
                (p.name(lang), null),
              ]),
              const SizedBox(height: 22),
              Wrap(
                  spacing: 22,
                  runSpacing: 18,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      DecoratedBox(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: LanternTokens.goldHi
                                        .withValues(alpha: .35),
                                    spreadRadius: 4)
                              ]),
                          child: LAvatar(
                              key: const ValueKey('lantern-preacher-avatar'),
                              name: p.name(lang),
                              size: wide ? 96 : 76,
                              image: resolveImageProviderOrNull(p.photoUrl),
                              ring: channel?.isCurrentlyLive == true
                                  ? LRing.live
                                  : LRing.none,
                              verified: true)),
                      const SizedBox(width: 18),
                      ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: wide
                                  ? 560
                                  : MediaQuery.sizeOf(context).width - 140),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                    header: true,
                                    child: Text(p.name(lang),
                                        style: Lantern.displayStyle(
                                            wide ? 32 : 24,
                                            color: LanternTokens.onNight,
                                            height: lHeadHeight(context)))),
                                const SizedBox(height: 4),
                                Text(
                                    [
                                      if (p.title(lang).isNotEmpty)
                                        p.title(lang),
                                      cityLabel(p.city)
                                    ].join(' · '),
                                    style: Lantern.textStyle(14,
                                        color: t.muted, height: 1.45)),
                                const SizedBox(height: 10),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  LTag('lessons.preacher.verified'.tr(),
                                      tone: LTone.gold, icon: LGlyph.verified),
                                  if (p.affiliation == 'ministry')
                                    LTag('lessons.affiliation.ministry'.tr(),
                                        tone: LTone.mod, icon: LGlyph.org),
                                  if (channel != null)
                                    LTag('lessons.preacher.has_channel'.tr(),
                                        tone: LTone.live, icon: LGlyph.live),
                                  LTag(
                                      p.languages
                                          .map((x) =>
                                              LessonsVocab.languageNative[x] ??
                                              x)
                                          .join(' · '),
                                      icon: LGlyph.globe),
                                ]),
                              ])),
                    ]),
                    Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          LFollowButton(
                              kind: 'preacher',
                              id: p.id,
                              style: LButtonKind.primary),
                          if (channel != null)
                            LButton(
                                label: 'lessons.preacher.channel'.tr(),
                                kind: LButtonKind.secondary,
                                icon: LGlyph.live,
                                onPressed: () => context
                                    .push('/profile/${channel!.streamerId}')),
                          LIconButton(
                              key: const ValueKey('lantern-preacher-copy'),
                              icon: LGlyph.link,
                              label: 'lessons.preacher.copy_link'.tr(),
                              onPressed: () =>
                                  lanternCopy(context, preacherLink(p.id))),
                          if (c.canManage)
                            LButton(
                                label: 'lessons.admin.manage_preacher'.tr(),
                                kind: LButtonKind.ghost,
                                size: LButtonSize.small,
                                icon: LGlyph.shield,
                                onPressed: () => context
                                    .push('/admin/lessons/preachers/${p.id}')),
                        ]),
                  ]),
              const SizedBox(height: 24),
              Container(height: 1, color: t.line),
              const SizedBox(height: 18),
              Wrap(spacing: wide ? 36 : 26, runSpacing: 14, children: [
                for (final (n, label) in [
                  (upcoming.length, 'lessons.preacher.s_upcoming'.tr()),
                  (series.length, 'lessons.preacher.s_series'.tr()),
                  (places.length, 'lessons.preacher.s_mosques'.tr()),
                  (past.length, 'lessons.preacher.s_held'.tr()),
                ])
                  Semantics(
                      label: '$n $label',
                      child: ExcludeSemantics(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Text('$n',
                                style: Lantern.displayStyle(wide ? 30 : 24,
                                        color: LanternTokens.goldHi, height: 1.1)
                                    .copyWith(fontFeatures: Lantern.tabular)),
                            const SizedBox(height: 4),
                            Text(label,
                                style: Lantern.textStyle(13.5,
                                    color: t.muted, height: 1.3)),
                          ]))),
              ]),
            ]));
        }));

    return LLessonsPage(
        title: 'lessons.nav.preacher'.tr(),
        header: header,
        children: [
          LUnderlineTabs<String>(value: tab, onChanged: onTab, tabs: [
            (
              value: 'upcoming',
              label: 'lessons.preacher.upcoming'.tr(),
              count: upcoming.length
            ),
            (
              value: 'series',
              label: 'lessons.preacher.series'.tr(),
              count: series.length
            ),
            (value: 'past', label: 'lessons.preacher.past'.tr(), count: null),
            (value: 'about', label: 'lessons.preacher.about'.tr(), count: null),
          ]),
          const SizedBox(height: 22),
          KeyedSubtree(key: ValueKey('lantern-preacher-tab-$tab'), child: body),
          if (places.isNotEmpty)
            LLessonsSection(
                key: const ValueKey('lantern-preacher-mosques'),
                title: 'lessons.preacher.teaches_at'.tr(),
                count: '${places.length}',
                child: wide
                    ? LGrid(
                        columns: 3,
                        gap: 12,
                        children: [for (final m in places) _place(context, m)])
                    : Column(children: [
                        for (final m in places)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _place(context, m)),
                      ])),
        ]);
  }

  /// A mosque he teaches at, which opens its page.
  Widget _place(BuildContext context, Mosque m) {
    final c = context.read<LessonsController>();
    final lang = lessonsLang(context);
    final d = c.district(m.districtId);
    return LRow(
        key: ValueKey('lantern-preacher-mosque-${m.id}'),
        title: m.name(lang),
        subtitle: d == null ? null : '${d.name(lang)} · ${cityLabel(d.city)}',
        leading: const LArchBadge(),
        onTap: () => context.push('/lessons/mosques/${m.id}'));
  }
}
