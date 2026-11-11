import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../data/lessons_repository.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../domain/prayer_times.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart' show tPlural;
import '../lessons_shell.dart' show preacherChannel;
import '../lessons_widgets.dart'
    show
        audienceLabel,
        cityLabel,
        languageLabel,
        languageNativeLabel,
        openLesson,
        prayerLabel,
        slotLabel,
        typeLabel,
        whenOf;
import 'lantern_lessons_actions.dart';

String lessonsLang(BuildContext context) => context.locale.languageCode;

/// White light at [alpha]: the glass of panels and rows on a night band.
Color lGlass(double alpha) => LanternTokens.white.withValues(alpha: alpha);

/// The night ground at [alpha], to fade a picture into the dark.
Color lNightFade(double alpha) =>
    LanternTokens.nightGround.withValues(alpha: alpha);

/// The soft gold disc behind an icon on a night band.
final lGoldGlow = LanternTokens.goldHi.withValues(alpha: .16);

/// Heading height for Readex Pro: Arabic needs more room.
double lHeadHeight(BuildContext context) => context.lanternArabic ? 1.45 : 1.25;

/// The page column: 1200 wide with 32 px gutters on the website layout,
/// 16 px gutters on phones.
class LLessonsColumn extends StatelessWidget implements LanternSkinWidget {
  const LLessonsColumn(
      {super.key, required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top, bottom;

  @override
  Widget build(BuildContext context) {
    final g = context.lanternWide ? Lantern.webGutter : Lantern.gutter;
    return Center(
        child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: Lantern.webContent + 2 * 32),
            child: Padding(
                padding: EdgeInsets.fromLTRB(g, top, g, bottom),
                child: child)));
  }
}

/// A section of a page: its heading and what is under it.
class LLessonsSection extends StatelessWidget implements LanternSkinWidget {
  const LLessonsSection(
      {super.key,
      required this.title,
      required this.child,
      this.count,
      this.subtitle,
      this.action,
      this.onAction});

  final String title;
  final String? count, subtitle, action;
  final VoidCallback? onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(top: context.lanternWide ? 44 : 30),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            LSectionHead(title,
                arch: false,
                count: count,
                subtitle: subtitle,
                action: action,
                onAction: onAction),
            const SizedBox(height: 18),
            child,
          ]));
}

/// The star and a short line in gold ink above a heading.
class LEyebrow extends StatelessWidget implements LanternSkinWidget {
  const LEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.lt.goldInk;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      LStar(size: 11, color: c),
      const SizedBox(width: 8),
      Flexible(
          child: Text(text,
              style: Lantern.textStyle(context.lanternArabic ? 13.5 : 12.5,
                  color: c, weight: FontWeight.w600, height: 1.4))),
    ]);
  }
}

/// Where the page sits: Lessons › Calendar › this lesson.
class LCrumb extends StatelessWidget implements LanternSkinWidget {
  const LCrumb(this.items, {super.key, this.color});

  final List<(String, VoidCallback?)> items;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final c = color ?? t.muted;
    return Semantics(
        container: true,
        label: 'lantern.lessons.crumb'.tr(),
        child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final (i, (label, onTap)) in items.indexed) ...[
                if (i > 0) LIcon(LGlyph.chevronend, size: 14, color: t.faint),
                onTap == null
                    ? Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lantern.textStyle(13,
                            color: c, weight: FontWeight.w600, height: 1.3))
                    : LPressable(
                        onTap: onTap,
                        label: label,
                        radius: 8,
                        pressScale: 1,
                        excludeChildSemantics: true,
                        builder: (context, s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(label,
                                style: Lantern.textStyle(13,
                                    color: s.hovered ? t.goldInk : c,
                                    height: 1.3)))),
              ],
            ]));
  }
}

/// Tabs with the gold underline (Upcoming, Series, Past, About).
class LUnderlineTabs<T> extends StatelessWidget implements LanternSkinWidget {
  const LUnderlineTabs(
      {super.key,
      required this.tabs,
      required this.value,
      required this.onChanged,
      this.line = true});

  final List<({T value, String label, int? count})> tabs;
  final T value;
  final ValueChanged<T> onChanged;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final calm = Lantern.calm(context);
    return DecoratedBox(
        decoration: BoxDecoration(
            border: line ? Border(bottom: BorderSide(color: t.line)) : null),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final tab in tabs)
                LPressable(
                    onTap: () => onChanged(tab.value),
                    label: tab.count == null
                        ? tab.label
                        : '${tab.label}, ${tab.count}',
                    selected: tab.value == value,
                    radius: 10,
                    pressScale: 1,
                    excludeChildSemantics: true,
                    builder: (context, s) {
                      final on = tab.value == value;
                      return SizedBox(
                          height: 48,
                          child: Stack(alignment: Alignment.center, children: [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(tab.label,
                                          style: Lantern.textStyle(14.5,
                                              color: on || s.hovered
                                                  ? t.fg
                                                  : t.muted,
                                              weight: FontWeight.w600,
                                              height: 1.2)),
                                      if (tab.count != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: t.sunk,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        Lantern.radiusPill)),
                                            child: Text('${tab.count}',
                                                style: Lantern.textStyle(11.5,
                                                        color: t.goldInk,
                                                        weight: FontWeight.w600,
                                                        height: 1.3)
                                                    .copyWith(
                                                        fontFeatures:
                                                            Lantern.tabular))),
                                      ],
                                    ])),
                            PositionedDirectional(
                                start: 12,
                                end: 12,
                                bottom: 0,
                                child: AnimatedScale(
                                    scale: on ? 1 : 0,
                                    alignment: Alignment.center,
                                    duration: calm
                                        ? Lantern.none
                                        : const Duration(milliseconds: 300),
                                    curve: Lantern.ease,
                                    child: Container(
                                        height: 3,
                                        decoration: const BoxDecoration(
                                            color: LanternTokens.gold,
                                            borderRadius: BorderRadius.vertical(
                                                top: Radius.circular(3)))))),
                          ]));
                    }),
            ])));
  }
}

/// The five prayers of a day with their adhan times; [active] is drawn in
/// gold (the next prayer, or the prayer a lesson follows). [glass] sits on
/// a night band.
class LPrayerStrip extends StatelessWidget implements LanternSkinWidget {
  const LPrayerStrip(
      {super.key, required this.times, this.active, this.glass = false});

  final PrayerTimes times;
  final String? active;
  final bool glass;

  /// The next prayer after now, or null when Isha has passed.
  static String? nextPrayer(PrayerTimes pt) {
    final now = lessonsNowHours();
    final i = LessonsVocab.slots.indexWhere((s) => pt.of(s) > now);
    return i < 0 ? null : LessonsVocab.slots[i];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = lessonsLang(context);
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: glass ? lGlass(.06) : t.sunk,
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          for (final (i, slot) in LessonsVocab.slots.indexed) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(child: _cell(t, lang, slot)),
          ],
        ]));
  }

  Widget _cell(LanternTokens t, String lang, String slot) {
    final on = slot == active;
    final full = clockLabel(times.of(slot), lang);
    final number = full.split(' ').first;
    return Semantics(
        label: '${prayerLabel(slot)} $full',
        selected: on,
        child: ExcludeSemantics(
            child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                decoration: BoxDecoration(
                    gradient: on ? Lantern.goldFill : null,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(prayerLabel(slot),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lantern.textStyle(12,
                          color: on ? LanternTokens.onGold : t.muted,
                          weight: on ? FontWeight.w600 : FontWeight.w400,
                          height: 1.3)),
                  const SizedBox(height: 3),
                  Text(number,
                      maxLines: 1,
                      style: Lantern.displayStyle(14,
                              color: on ? LanternTokens.onGold : t.fg,
                              height: 1.1)
                          .copyWith(fontFeatures: Lantern.tabular)),
                ]))));
  }
}

/// The bell of a lesson row or card: Remind me, or the reminder that is on.
class LRemindIcon extends StatelessWidget implements LanternSkinWidget {
  const LRemindIcon(this.lesson, {super.key, this.color});

  final Lesson lesson;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    if (!canRemind(c, lesson)) return const SizedBox.shrink();
    final on = c.hasReminder(lesson.id);
    return LIconButton(
        key: ValueKey('lantern-remind-${lesson.id}'),
        icon: LGlyph.bell,
        size: 40,
        iconSize: 18,
        on: on,
        color: color,
        label: on
            ? 'lessons.lesson.reminder_on'.tr()
            : 'lessons.lesson.remind'.tr(),
        onPressed: () => remindTap(context, lesson));
  }
}

/// Follow or Following, for a preacher, a series or a mosque.
class LFollowButton extends StatelessWidget implements LanternSkinWidget {
  const LFollowButton(
      {super.key,
      required this.kind,
      required this.id,
      this.size = LButtonSize.medium,
      this.style = LButtonKind.tonal,
      this.expand = false});

  final String kind, id;
  final LButtonSize size;
  final LButtonKind style;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final on = context.watch<LessonsController>().isFollowing(kind, id);
    return LButton(
        key: ValueKey('lantern-follow-$kind-$id'),
        label: on ? 'lessons.follow.following'.tr() : 'lessons.follow.follow'.tr(),
        kind: on ? LButtonKind.dark : style,
        size: size,
        expand: expand,
        icon: on ? LGlyph.check : LGlyph.plus,
        onPressed: () => toggleLessonsFollow(context, kind, id));
  }
}

/// A small arch with the mosque inside: the mark of a lesson.
class LArchBadge extends StatelessWidget implements LanternSkinWidget {
  const LArchBadge(
      {super.key,
      this.width = 34,
      this.height = 40,
      this.icon = LGlyph.mosque,
      this.filled = false});

  final double width, height;
  final LGlyph icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return ExcludeSemantics(
        child: Container(
            width: width,
            height: height,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
                color: filled ? null : t.sunk,
                gradient: filled
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [LanternTokens.goldHi, LanternTokens.gold])
                    : null,
                shape: LArchBorder(
                    bottom: height * .16,
                    side: BorderSide(
                        color: filled
                            ? LanternTokens.goldLo
                            : LanternTokens.gold,
                        width: filled ? 2.5 : 1.5))),
            child: Padding(
                padding: EdgeInsets.only(top: height * .12),
                child: LIcon(icon,
                    size: width * .52,
                    color: filled ? LanternTokens.onGold : t.goldInk))));
  }
}

/// A progress bar that fills from empty when it first shows (still under
/// calm motion).
class LFillBar extends StatelessWidget implements LanternSkinWidget {
  const LFillBar(this.value, {super.key, this.label});

  final double value;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (Lantern.calm(context)) return LProgress(value, label: label, height: 7);
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Lantern.ease,
        builder: (context, v, _) => LProgress(v, label: label, height: 7));
  }
}

/// Equal columns; each row as tall as its tallest card.
class LGrid extends StatelessWidget implements LanternSkinWidget {
  const LGrid(
      {super.key,
      required this.columns,
      required this.children,
      this.gap = 20});

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final row = children.sublist(i, math.min(i + columns, children.length));
      rows.add(IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var j = 0; j < columns; j++) ...[
          if (j > 0) SizedBox(width: gap),
          Expanded(child: j < row.length ? row[j] : const SizedBox.shrink()),
        ],
      ])));
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            rows[i],
          ],
        ]);
  }
}

/// A panel of the side column: a card with a small heading.
class LPanel extends StatelessWidget implements LanternSkinWidget {
  const LPanel({super.key, this.title, required this.child, this.onTap, this.label});

  final String? title, label;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => LCard(
      padding: const EdgeInsets.all(20),
      onTap: onTap,
      label: label,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Semantics(
                  header: true,
                  child: Text(title!,
                      style: Lantern.displayStyle(16,
                          color: context.lt.fg, height: lHeadHeight(context)))),
              const SizedBox(height: 12),
            ],
            child,
          ]));
}

/// Key and value lines with a hairline between them.
class LKv extends StatelessWidget implements LanternSkinWidget {
  const LKv(this.rows, {super.key});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (final (i, (k, v)) in rows.indexed)
        Container(
            padding: EdgeInsets.only(
                top: i == 0 ? 0 : 9, bottom: i == rows.length - 1 ? 0 : 9),
            decoration: BoxDecoration(
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.line2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: Lantern.textStyle(14, color: t.muted, height: 1.4)),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(v,
                      textAlign: TextAlign.end,
                      style: Lantern.textStyle(14,
                          color: t.fg, weight: FontWeight.w600, height: 1.4))),
            ])),
    ]);
  }
}

/// The sample-data note of builds without a backend.
class LLessonsDemoNote extends StatelessWidget implements LanternSkinWidget {
  const LLessonsDemoNote({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Container(
        width: double.infinity,
        color: t.warnSoft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text('lessons.sample_banner'.tr(),
            textAlign: TextAlign.center,
            style: Lantern.textStyle(12.5,
                color: t.warn, weight: FontWeight.w600, height: 1.4)));
  }
}

/// Lessons could not load: the message and Try again.
class LLessonsError extends StatelessWidget implements LanternSkinWidget {
  const LLessonsError({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    return Container(
        key: const ValueKey('lantern-lessons-error'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: t.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration:
                  BoxDecoration(color: t.liveSoft, shape: BoxShape.circle),
              child: LIcon(
                  c.failure == LessonsFailure.unavailable
                      ? LGlyph.wifioff
                      : LGlyph.warn,
                  size: 30,
                  color: t.liveText)),
          const SizedBox(height: 14),
          Text('lessons.unavailable_title'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.displayStyle(20,
                  color: t.fg, height: lHeadHeight(context))),
          const SizedBox(height: 8),
          ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Text('lessons.unavailable_body'.tr(),
                  textAlign: TextAlign.center,
                  style: Lantern.textStyle(14.5, color: t.muted))),
          const SizedBox(height: 18),
          LButton(
              label: 'lessons.retry'.tr(),
              icon: LGlyph.refresh,
              loading: c.loading,
              onPressed: c.refresh),
        ]));
  }
}

/// Grey blocks in the shape of rows while lessons load.
class LLessonsSkeleton extends StatelessWidget implements LanternSkinWidget {
  const LLessonsSkeleton({super.key, this.rows = 4, this.height = 64});

  final int rows;
  final double height;

  @override
  Widget build(BuildContext context) => Column(
      key: const ValueKey('lantern-lessons-loading'),
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: LSkeleton(height: height, radius: Lantern.radiusRow)),
      ]);
}

/// A lesson as a row: the time box, the title and where, its marks and
/// the bell. [glass] is the night band's version.
class LLessonRow extends StatelessWidget implements LanternSkinWidget {
  const LLessonRow(this.lesson,
      {super.key, this.glass = false, this.showDate = false, this.trailing});

  final Lesson lesson;
  final bool glass, showDate;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final l = lesson, lang = lessonsLang(context);
    final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId);
    final d = c.district(m?.districtId);
    final cancelled = l.isCancelled;
    final running = l.isPublic &&
        lessonTiming(l, c.catalog, DateTime.now()).phase == LessonPhase.running;
    final live = c.isLiveNow(l);
    final where = [
      if (p != null) p.name(lang),
      if (m != null) m.name(lang),
      if (d != null) cityLabel(d.city),
    ].join(' · ');
    final time = clockLabel(c.startHours(l), lang);
    final marks = <Widget>[
      if (cancelled)
        LTag('lessons.status.cancelled'.tr(), tone: LTone.live)
      else if (live)
        LBadge('lessons.lesson.live'.tr(), kind: LBadgeKind.live, small: true)
      else if (running)
        LBadge('lantern.lessons.now'.tr(), kind: LBadgeKind.now, small: true),
      if (l.streamed && !live && !cancelled)
        Semantics(
            label: 'lessons.lesson.streamed'.tr(),
            child: ExcludeSemantics(
                child: Container(
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                        color: t.liveSoft,
                        borderRadius:
                            BorderRadius.circular(Lantern.radiusPill)),
                    child: LIcon(LGlyph.live, size: 14, color: t.liveText)))),
      if (l.language != 'ar')
        LTag(languageLabel(l.language), tone: LTone.gold, outlined: true),
    ];
    final fg = glass ? LanternTokens.onNight : t.fg;
    final muted = glass ? LanternTokens.dark.muted : t.muted;
    return LPressable(
        onTap: () => openLesson(context, l.id),
        label: '${l.title(lang)}, $time, $where',
        radius: Lantern.radiusRow,
        pressScale: .985,
        builder: (context, s) => AnimatedContainer(
            duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
            padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 6, 10),
            decoration: BoxDecoration(
                color: glass
                    ? lGlass(s.hovered ? .1 : .06)
                    : s.hovered
                        ? t.sunk
                        : t.surface,
                borderRadius: BorderRadius.circular(Lantern.radiusRow),
                border: Border.all(
                    color: glass
                        ? lGlass(.08)
                        : s.hovered
                            ? t.line
                            : t.line2)),
            child: Opacity(
                opacity: cancelled ? .7 : 1,
                child: Row(children: [
                  Container(
                      constraints: const BoxConstraints(minWidth: 70),
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      decoration: BoxDecoration(
                          color: glass ? lGlass(.08) : t.sunk,
                          borderRadius:
                              BorderRadius.circular(Lantern.radiusTile)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(time,
                            maxLines: 1,
                            style: Lantern.displayStyle(14.5,
                                    color: fg, height: 1.15)
                                .copyWith(fontFeatures: Lantern.tabular)),
                        const SizedBox(height: 2),
                        Text(
                            showDate
                                ? gregorianLabel(l.date, lang, short: true)
                                : slotLabel(l.slot),
                            maxLines: 1,
                            style: Lantern.textStyle(10.5,
                                color: muted, height: 1.2)),
                      ])),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Text(l.title(lang),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Lantern.textStyle(14.5,
                                    color: fg,
                                    weight: FontWeight.w600,
                                    height: 1.35)
                                .copyWith(
                                    decoration: cancelled
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: muted)),
                        const SizedBox(height: 2),
                        Text(where,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Lantern.textStyle(12.5,
                                color: muted, height: 1.4)),
                        if (marks.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: marks),
                        ],
                        if (trailing != null) ...[
                          const SizedBox(height: 8),
                          trailing!,
                        ],
                      ])),
                  const SizedBox(width: 4),
                  LRemindIcon(l, color: glass ? LanternTokens.onNight : null),
                ]))));
  }
}

/// A lesson as a card: the arch, when, the title, the preacher, the time
/// and the place, and its tags.
class LLessonCard extends StatelessWidget implements LanternSkinWidget {
  const LLessonCard(this.lesson, {super.key});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final l = lesson, lang = lessonsLang(context);
    final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId);
    final d = c.district(m?.districtId);
    final running = l.isPublic &&
        lessonTiming(l, c.catalog, DateTime.now()).phase == LessonPhase.running;
    final live = c.isLiveNow(l);
    final s = c.seriesOf(l.seriesId);
    Widget meta(LGlyph g, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          LIcon(g, size: 15, color: t.muted),
          const SizedBox(width: 6),
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(13, color: t.muted, height: 1.4))),
        ]));
    return LCard(
        onTap: () => openLesson(context, l.id),
        label: l.title(lang),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const LArchBadge(),
                const SizedBox(width: 8),
                Expanded(
                    child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          if (live)
                            LBadge('lessons.lesson.live'.tr(),
                                kind: LBadgeKind.live, small: true)
                          else if (running)
                            LBadge('lantern.lessons.on_now'.tr(),
                                kind: LBadgeKind.now, small: true)
                          else if (sameDay(l.date, c.today))
                            LBadge('lessons.time.today'.tr(),
                                kind: LBadgeKind.soon, small: true)
                          else
                            LTag(relativeDayLabel(l.date, lang)),
                          if (l.streamed && !live)
                            LTag('lessons.lesson.streamed'.tr(),
                                tone: LTone.live, icon: LGlyph.live),
                        ]))),
                LRemindIcon(l),
              ]),
              const SizedBox(height: 10),
              Text(l.title(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(16,
                      color: t.fg, weight: FontWeight.w600, height: 1.35)),
              if (p != null)
                Text(p.name(lang),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Lantern.textStyle(13, color: t.muted, height: 1.5)),
              const SizedBox(height: 4),
              meta(LGlyph.clock, whenOf(c, l, lang, withDate: false)),
              meta(LGlyph.pin, [
                if (m != null) m.name(lang),
                if (d != null) cityLabel(d.city)
              ].join(' · ')),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                LTag(typeLabel(l.type)),
                if (s != null && l.seq != null)
                  LTag('lessons.lesson.of'.tr(args: ['${l.seq}', '${s.total}'])),
                if (l.language != 'ar')
                  LTag(languageLabel(l.language),
                      tone: LTone.gold, icon: LGlyph.globe, outlined: true),
                if (l.audience != 'all') LTag(audienceLabel(l.audience)),
              ]),
            ]));
  }
}

/// A weekly series: the arch counter (done of total), its preacher, a bar
/// that fills, and when and where.
class LSeriesCard extends StatelessWidget implements LanternSkinWidget {
  const LSeriesCard(this.series, {super.key});

  final LessonSeries series;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final s = series, lang = lessonsLang(context);
    final sessions = c.sessionsOf(s.id);
    final done = sessions.where((l) => l.date.isBefore(c.today)).length;
    final weekday = sessions.isEmpty ? '' : weekdayName(sessions.first.date, lang);
    final total = s.total <= 0 ? 1 : s.total;
    final streamed = sessions.any((l) => l.streamed);
    return LCard(
        onTap: () => context.push('/lessons/series/${s.id}'),
        label: s.title(lang),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                    width: 56,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                        color: t.sunk,
                        shape: const LArchBorder(
                            bottom: 10,
                            side: BorderSide(
                                color: LanternTokens.gold, width: 1.5))),
                    child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('$done',
                              style: Lantern.displayStyle(20,
                                      color: t.goldInk, height: 1)
                                  .copyWith(fontFeatures: Lantern.tabular)),
                          Text('/${s.total}',
                              style: Lantern.textStyle(11,
                                  color: t.muted, height: 1.2)),
                        ]))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(s.title(lang),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(15.5,
                              color: t.fg, weight: FontWeight.w600, height: 1.3)),
                      Text(c.preacher(s.preacherId)?.name(lang) ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(13,
                              color: t.muted, height: 1.4)),
                    ])),
              ]),
              const SizedBox(height: 12),
              LFillBar(done / total),
              const SizedBox(height: 6),
              Text('lessons.discover.done_of'.tr(args: ['$done', '${s.total}']),
                  style: Lantern.textStyle(12.5, color: t.muted, height: 1.4)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (weekday.isNotEmpty)
                  LTag(
                      '${'lessons.time.every'.tr(args: [weekday])} · ${slotLabel(s.slot)}',
                      icon: LGlyph.calendar),
                if (c.mosque(s.mosqueId) != null)
                  LTag(c.mosque(s.mosqueId)!.name(lang), icon: LGlyph.mosque),
                if (streamed)
                  LTag('lessons.lesson.streamed'.tr(),
                      tone: LTone.live, icon: LGlyph.live),
                if (s.language.isNotEmpty && s.language != 'ar')
                  LTag(languageLabel(s.language),
                      tone: LTone.gold, icon: LGlyph.globe, outlined: true),
              ]),
            ]));
  }
}

/// A preacher: photo or initial, name, title and his marks.
class LPreacherCard extends StatelessWidget implements LanternSkinWidget {
  const LPreacherCard(this.preacher, {super.key});

  final Preacher preacher;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final p = preacher, lang = lessonsLang(context);
    final channel = preacherChannel(context, p);
    final ahead = c.upcoming.where((l) => l.preacherId == p.id).length;
    return LCard(
        onTap: () => context.push('/lessons/preachers/${p.id}'),
        label: p.name(lang),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LAvatar(
              name: p.name(lang),
              size: 64,
              image: resolveImageProviderOrNull(p.photoUrl),
              ring: channel?.isCurrentlyLive == true ? LRing.live : LRing.none,
              verified: true),
          const SizedBox(height: 10),
          Text(p.name(lang),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Lantern.textStyle(15.5,
                  color: t.fg, weight: FontWeight.w600, height: 1.3)),
          if (p.title(lang).isNotEmpty)
            Text(p.title(lang),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Lantern.textStyle(13, color: t.muted, height: 1.45)),
          const SizedBox(height: 8),
          Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                LTag('lessons.preacher.verified'.tr(),
                    tone: LTone.gold, icon: LGlyph.verified),
                if (channel != null)
                  LTag('lessons.preacher.has_channel'.tr(),
                      tone: LTone.live, icon: LGlyph.live),
                LTag(tPlural('ahead', ahead)),
              ]),
        ]));
  }
}

/// A community language and how many lessons are in it.
class LLanguageCard extends StatelessWidget implements LanternSkinWidget {
  const LLanguageCard({super.key, required this.code, required this.count});

  final String code;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final native = languageNativeLabel(code);
    final mark = native.characters.take(2).toString();
    return LCard(
        onTap: () => context.go('/lessons/calendar?lang=$code'),
        label: '${languageLabel(code)}, ${tPlural('lessons', count)}',
        padding: const EdgeInsets.all(18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: t.audioSoft,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(mark,
                      style: Lantern.displayStyle(18,
                          color: t.audio, height: 1.1))),
              const SizedBox(height: 10),
              Text(languageLabel(code),
                  style: Lantern.displayStyle(16,
                      color: t.fg, height: lHeadHeight(context))),
              // The language named in itself is isolated, so its script does
              // not reorder the line around it.
              Text('$_fsi$native$_pdi · ${tPlural('lessons', count)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(13, color: t.muted, height: 1.45)),
            ]));
  }
}

final _fsi = String.fromCharCode(0x2068), _pdi = String.fromCharCode(0x2069);

/// The drawn map of the teaser: streets, the coast, mosque arches and live
/// dots. A picture, not the map; tapping opens the map.
class LMapArt extends StatelessWidget implements LanternSkinWidget {
  const LMapArt({super.key, this.height = 260, this.radius = Lantern.radiusCard});

  final double height, radius;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return ExcludeSemantics(
        child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SizedBox(
                height: height,
                child: CustomPaint(
                    painter: _MapArtPainter(
                        ground: t.sunk,
                        sea: t.audioSoft,
                        street: t.surface,
                        live: t.live,
                        user: t.audio,
                        rtl: Directionality.of(context) == TextDirection.rtl),
                    child: const SizedBox.expand()))));
  }
}

class _MapArtPainter extends CustomPainter {
  _MapArtPainter(
      {required this.ground,
      required this.sea,
      required this.street,
      required this.live,
      required this.user,
      required this.rtl});

  final Color ground, sea, street, live, user;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Offset p(double x, double y) => Offset((rtl ? 1 - x : x) * w, y * h);
    canvas.drawRect(Offset.zero & size, Paint()..color = ground);
    final coast = Path()
      ..moveTo(p(.75, 0).dx, 0)
      ..cubicTo(p(.85, .25).dx, .2 * h, p(.8, .55).dx, .55 * h, p(.88, .8).dx,
          .8 * h)
      ..lineTo(p(.9, 1).dx, h)
      ..lineTo(p(1, 1).dx, h)
      ..lineTo(p(1, 0).dx, 0)
      ..close();
    canvas.drawPath(coast, Paint()..color = sea);
    final road = Paint()
      ..color = street
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    for (final (a, b) in [
      (p(.2, 0), p(.25, 1)),
      (p(.4, 0), p(.43, 1)),
      (p(.55, 0), p(.6, 1)),
      (p(0, .37), p(.53, .33)),
      (p(0, .58), p(.48, .55)),
    ]) {
      canvas.drawLine(a, b, road);
    }
    final gold = Path()
      ..moveTo(p(.07, .23).dx, .23 * h)
      ..quadraticBezierTo(p(.5, .4).dx, .45 * h, p(.82, .93).dx, .93 * h);
    canvas.drawPath(
        gold,
        Paint()
          ..color = LanternTokens.goldHi
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    for (final (x, y) in [
      (.22, .23),
      (.52, .25),
      (.4, .37),
      (.59, .46),
      (.73, .5),
      (.63, .61),
      (.7, .76),
    ]) {
      final c = p(x, y);
      final r = Rect.fromCenter(center: c, width: 16, height: 19);
      canvas.drawPath(lanternArchPath(r, bottom: 3),
          Paint()..color = LanternTokens.gold);
      canvas.drawPath(
          lanternArchPath(r, bottom: 3),
          Paint()
            ..color = LanternTokens.goldLo
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
    for (final (x, y, color) in [
      (.52, .54, live),
      (.65, .67, live),
      (.58, .72, user),
    ]) {
      canvas.drawCircle(p(x, y), 9, Paint()..color = street);
      canvas.drawCircle(p(x, y), 6.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_MapArtPainter old) =>
      old.ground != ground || old.rtl != rtl || old.sea != sea;
}

/// Find a lesson near you: a card that opens the map.
class LMapTeaser extends StatelessWidget implements LanternSkinWidget {
  const LMapTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    void open() => context.go('/map');
    final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LEyebrow('web.nav_map'.tr()),
          const SizedBox(height: 10),
          Text('lessons.discover.map_title'.tr(),
              style: Lantern.displayStyle(wide ? 28 : 24,
                  color: t.fg, height: lHeadHeight(context))),
          const SizedBox(height: 8),
          Text('lessons.discover.map_body'.tr(),
              style: Lantern.textStyle(14.5, color: t.muted)),
          const SizedBox(height: 18),
          LButton(
              key: const ValueKey('lantern-lessons-open-map'),
              label: 'lessons.discover.open_map'.tr(),
              icon: LGlyph.map,
              expand: !wide,
              onPressed: open),
        ]);
    final art = LPressable(
        onTap: open,
        label: 'lessons.discover.open_map'.tr(),
        radius: Lantern.radiusCard,
        excludeChildSemantics: true,
        builder: (context, s) => AnimatedScale(
            scale: s.hovered && !Lantern.calm(context) ? 1.015 : 1,
            duration: Lantern.calm(context)
                ? Lantern.none
                : const Duration(milliseconds: 400),
            curve: Lantern.ease,
            child: LMapArt(height: wide ? 330 : 190)));
    return LCard(
        radius: 32,
        padding: EdgeInsets.all(wide ? 28 : 18),
        child: wide
            ? Row(children: [
                Expanded(flex: 10, child: copy),
                const SizedBox(width: 28),
                Expanded(flex: 11, child: art),
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [copy, const SizedBox(height: 18), art]));
  }
}

/// The scroll of a Lessons tab: pull to refresh, the sample-data note, the
/// page, then the website footer or room for the floating navigation.
class LLessonsTabScroll extends StatelessWidget implements LanternSkinWidget {
  const LLessonsTabScroll(
      {super.key, required this.children, this.header, this.controller});

  final List<Widget> children;
  final Widget? header;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.read<LessonsController>();
    final t = context.lt;
    final wide = context.lanternWide;
    return ColoredBox(
        color: t.bg,
        child: RefreshIndicator(
            color: LanternTokens.gold,
            backgroundColor: t.surface,
            onRefresh: c.refresh,
            child: SingleChildScrollView(
                controller: controller,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (c.isDemo) const LLessonsDemoNote(),
                      if (header != null) header!,
                      LLessonsColumn(
                          bottom: wide ? 56 : 28,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children)),
                      if (wide)
                        const LanternWebFooter()
                      else
                        SizedBox(height: MediaQuery.paddingOf(context).bottom),
                    ]))));
  }
}

/// A pushed Lessons page (lesson, preacher, mosque, application): the page
/// bar on a phone; the website header and footer on the website layout.
/// Shows the loading and failure states until the programme has loaded.
class LLessonsPage extends StatelessWidget implements LanternSkinWidget {
  const LLessonsPage(
      {super.key,
      required this.title,
      required this.children,
      this.header,
      this.gate = true});

  final String title;
  final List<Widget> children;
  final Widget? header;

  /// Waits for the programme (off for pages that show their own waiting).
  final bool gate;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    // After a failure the page waits for Try again: loading again on every
    // rebuild would never let the failure show.
    if (c.failure == null) unawaited(c.ensureLoaded());
    return LanternSurface(child: Builder(builder: (context) {
      final t = context.lt;
      final wide = context.lanternWide;
      final waiting = gate && !c.loaded;
      final body = SingleChildScrollView(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            if (c.isDemo) const LLessonsDemoNote(),
            if (!waiting && header != null) header!,
            LLessonsColumn(
                top: 18,
                bottom: wide ? 56 : 28 + MediaQuery.paddingOf(context).bottom,
                child: waiting
                    ? (c.failure != null && !c.loading
                        ? const LLessonsError()
                        : const LLessonsSkeleton(rows: 5))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children)),
            if (wide) const LanternWebFooter(),
          ]));
      if (wide) {
        return Scaffold(
            backgroundColor: t.bg,
            body: SafeArea(
                child: Column(children: [
              const LanternWebHeader(active: LanternSection.lessons),
              Expanded(child: body),
            ])));
      }
      return Scaffold(
          backgroundColor: t.bg,
          appBar: LanternPageBar(
              title: title,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/lessons')),
          body: body);
    }));
  }
}

/// A fact of a lesson: its icon, what it is, the value and a line under it.
class LFactTile extends StatelessWidget implements LanternSkinWidget {
  const LFactTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      this.sub,
      this.onTap});

  final LGlyph icon;
  final String label, value;
  final String? sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget body(LPressState s) => AnimatedContainer(
        duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: s.hovered ? t.sunk : t.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: s.hovered ? LanternTokens.goldHi : t.line)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LIcon(icon, size: 20, color: t.goldInk),
              const SizedBox(height: 6),
              Text(label,
                  style: Lantern.textStyle(12, color: t.muted, height: 1.3)),
              const SizedBox(height: 2),
              Text(value,
                  style: Lantern.textStyle(15,
                          color: t.fg, weight: FontWeight.w600, height: 1.35)
                      .copyWith(
                          decoration:
                              onTap == null ? null : TextDecoration.underline,
                          decorationColor: t.goldInk)),
              if (sub != null && sub!.isNotEmpty)
                Text(sub!,
                    style: Lantern.textStyle(12, color: t.muted, height: 1.4)),
            ]));
    if (onTap == null) {
      return Semantics(
          container: true,
          child: body((hovered: false, pressed: false, focused: false)));
    }
    return LPressable(
        onTap: onTap,
        label: '$label: $value',
        radius: 18,
        pressScale: .985,
        builder: (context, s) => body(s));
  }
}

/// Where a lesson stands now: on at the mosque (with how far through), how
/// long until it starts (counting), or cancelled. Counts every 30 seconds,
/// as the older status card does.
class LLessonStatus extends StatefulWidget implements LanternSkinWidget {
  const LLessonStatus(this.lesson, {super.key});

  final Lesson lesson;

  @override
  State<LLessonStatus> createState() => _LLessonStatusState();
}

class _LLessonStatusState extends State<LLessonStatus> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final t = context.lt;
    final l = widget.lesson, lang = lessonsLang(context);
    Widget box(
            {required Key key,
            required Color bg,
            required Color fg,
            required Widget lead,
            required String title,
            required List<Widget> lines}) =>
        Semantics(
            container: true,
            liveRegion: true,
            child: Container(
                key: key,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(22)),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      lead,
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Text(title,
                                style: Lantern.displayStyle(16,
                                    color: fg, height: lHeadHeight(context))),
                            const SizedBox(height: 4),
                            ...lines,
                          ])),
                    ])));
    if (l.isCancelled) {
      return box(
          key: const ValueKey('lantern-lesson-cancelled'),
          bg: t.liveSoft,
          fg: t.liveText,
          lead: LIcon(LGlyph.ban, size: 24, color: t.liveText),
          title: 'lessons.lesson.cancelled'.tr(),
          lines: [
            Text(
                (l.cancelReason ?? '').isEmpty
                    ? 'lantern.lessons.lesson.cancel_told'.tr()
                    : l.cancelReason!,
                style: Lantern.textStyle(13.5, color: t.liveText)),
          ]);
    }
    if (!l.isPublic) return const SizedBox.shrink();
    final timing = lessonTiming(l, c.catalog, DateTime.now());
    if (timing.phase == LessonPhase.ended) return const SizedBox.shrink();
    if (timing.phase == LessonPhase.upcoming) {
      return LanternSurface(
          night: true,
          child: Builder(
              builder: (context) => box(
                      key: const ValueKey('lantern-lesson-upcoming'),
                      bg: LanternTokens.nightGround,
                      fg: LanternTokens.onNight,
                      lead: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: lGoldGlow, shape: BoxShape.circle),
                          child: const LIcon(LGlyph.clock,
                              size: 20, color: LanternTokens.goldHi)),
                      title:
                          '${relativeDayLabel(l.date, lang)} · ${slotLabel(l.slot)}',
                      lines: [
                        Text.rich(
                            TextSpan(
                                text: '${'lessons.map.starts_in'.tr()} ',
                                children: [
                                  TextSpan(
                                      text: durationLabel(timing.minutes, lang),
                                      style: Lantern.displayStyle(15,
                                              color: LanternTokens.goldHi,
                                              height: 1.3)
                                          .copyWith(
                                              fontFeatures: Lantern.tabular)),
                                ]),
                            style: Lantern.textStyle(13.5,
                                color: LanternTokens.dark.muted)),
                      ])));
    }
    final live = c.isLiveNow(l);
    final started = lessonMinutes(l) - timing.minutes;
    return box(
        key: ValueKey(live ? 'lantern-lesson-live' : 'lantern-lesson-on-site'),
        bg: t.okSoft,
        fg: t.ok,
        lead: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: t.ok, shape: BoxShape.circle))),
        title: (live ? 'lessons.map.both' : 'lessons.map.on_site').tr(),
        lines: [
          Text(
              '${'lessons.map.started_ago'.tr(args: [durationLabel(started < 1 ? 1 : started, lang)])} · ${'lessons.map.left_about'.tr(args: [durationLabel(timing.minutes, lang)])}',
              style: Lantern.textStyle(13.5, color: t.ok)),
          const SizedBox(height: 8),
          LProgress(timing.progress, color: t.ok, height: 6),
          const SizedBox(height: 6),
          Text(
              '${(live ? 'lessons.lesson.stream_note' : 'lessons.map.not_streamed').tr()} ${'lessons.map.from_schedule'.tr()}.',
              style: Lantern.textStyle(12, color: t.ok, height: 1.4)),
        ]);
  }
}
