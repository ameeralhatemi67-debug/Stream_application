import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/follow_action.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../discovery/presentation/lantern/lantern_stream_cards.dart';
import '../../../lessons/domain/lessons_dates.dart';
import '../../../lessons/domain/lessons_models.dart';
import '../../../lessons/domain/lessons_rules.dart';
import '../../../lessons/presentation/lessons_widgets.dart'
    show cityLabel, openLesson, whenOf;
import '../../../lessons/state/lessons_controller.dart';
import '../../../profile/models/streamer_models.dart';
import '../venue_directions_launcher.dart';

/// Rebuilds its child when the minute changes, so "starts in" and "left"
/// stay true while a card is open.
class _EveryMinute extends StatefulWidget {
  const _EveryMinute({required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<_EveryMinute> createState() => _EveryMinuteState();
}

class _EveryMinuteState extends State<_EveryMinute> {
  Timer? _timer;

  void _arm() {
    _timer = Timer(Duration(seconds: 61 - DateTime.now().second), () {
      if (!mounted) return;
      setState(() {});
      _arm();
    });
  }

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, DateTime.now());
}

/// A mosque chosen on the map: its arch badge, name and district; a band
/// that says what is happening (on now with how much is left, live in the
/// app, or when the next lesson starts); this week's lessons; the preachers
/// who teach there; its page and directions.
///
/// Without a connection nothing can be trusted as happening now, so the band
/// is left out and only the lessons the app holds are listed.
class LanternMosquePlaceCard extends StatelessWidget
    implements LanternSkinWidget {
  const LanternMosquePlaceCard(
      {super.key,
      required this.mosqueId,
      required this.onClose,
      this.online = true});

  final String mosqueId;
  final VoidCallback onClose;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final m = c.mosque(mosqueId);
    if (m == null) return const SizedBox.shrink();
    final t = context.lt;
    final lang = context.locale.languageCode;
    final end = addDays(c.today, 6);
    final lessons =
        c.upcomingWhere((l) => l.mosqueId == m.id && !l.date.isAfter(end));
    final preachers =
        c.listedPreachers.where((p) => p.homeMosqueId == m.id).take(3).toList();
    final district = c.district(m.districtId)?.name(lang) ?? '';
    final place = [district, cityLabel(c.cityOfMosque(m.id))]
        .where((v) => v.isNotEmpty)
        .join(' · ');
    return LCard(
        key: const ValueKey('lantern-map-mosque-card'),
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 40,
                    height: 46,
                    alignment: const Alignment(0, .35),
                    decoration: const ShapeDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [LanternTokens.goldHi, Color(0xFFC1923B)]),
                        shape: LArchBorder(
                            bottom: 7,
                            side: BorderSide(
                                color: Color(0xFF805B1B), width: 2))),
                    child: const LIcon(LGlyph.mosque,
                        size: 18, color: Color(0xFF4B320E))),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Semantics(
                          header: true,
                          child: Text(m.name(lang),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Lantern.displayStyle(16.5,
                                  color: t.fg,
                                  height:
                                      context.lanternArabic ? 1.45 : 1.25))),
                      if (place.isNotEmpty)
                        Text(place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Lantern.textStyle(13,
                                color: t.muted, height: 1.4)),
                    ])),
                LIconButton(
                    icon: LGlyph.close,
                    label: 'lantern.map.close_card'.tr(),
                    size: 40,
                    onPressed: onClose),
              ]),
              if (online)
                _EveryMinute(builder: (context, now) {
                  final next = mosqueNow(lessons, c.catalog, now).lesson;
                  return next == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _StatusBand(
                              lesson: next,
                              timing: lessonTiming(next, c.catalog, now),
                              live: c.isLiveNow(next, now: now),
                              when: whenOf(c, next, lang, withDate: false)));
                }),
              const SizedBox(height: 12),
              Text('lantern.map.this_week'.tr(),
                  style: Lantern.textStyle(12.5,
                      color: t.goldInk, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              if (lessons.isEmpty)
                Text('lessons.map.none_period'.tr(),
                    style: Lantern.textStyle(13.5, color: t.muted))
              else
                for (final l in lessons.take(3))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _LessonLine(lesson: l, controller: c)),
              if (lessons.length > 3)
                Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: LLink(
                        'lantern.map.more_lessons'
                            .tr(args: ['${lessons.length - 3}']),
                        onTap: () =>
                            context.push('/lessons/mosques/${m.id}'))),
              if (preachers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('lessons.map.preachers_here'.tr(),
                    style: Lantern.textStyle(12.5,
                        color: t.goldInk, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in preachers)
                    LPressable(
                        onTap: () =>
                            context.push('/lessons/preachers/${p.id}'),
                        label: p.name(lang),
                        excludeChildSemantics: true,
                        builder: (context, s) => Container(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                4, 4, 12, 4),
                            decoration: BoxDecoration(
                                color: s.hovered ? t.line : t.sunk,
                                borderRadius: BorderRadius.circular(
                                    Lantern.radiusPill)),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LAvatar(name: p.name(lang), size: 26),
                                  const SizedBox(width: 8),
                                  Flexible(
                                      child: Text(p.name(lang),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Lantern.textStyle(13,
                                              color: t.fg,
                                              weight: FontWeight.w600,
                                              height: 1.3))),
                                ]))),
                ]),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                LButton(
                    label: 'lessons.map.mosque_page'.tr(),
                    trailing: LGlyph.arrow,
                    size: LButtonSize.small,
                    onPressed: () => context.push('/lessons/mosques/${m.id}')),
                if (m.directions != null)
                  LButton(
                      label: 'lessons.lesson.directions'.tr(),
                      icon: LGlyph.directions,
                      kind: LButtonKind.tonal,
                      size: LButtonSize.small,
                      onPressed: () => launchUrl(m.directions!,
                          mode: LaunchMode.externalApplication)),
              ]),
            ]));
  }
}

/// What is happening at the mosque: on now (green, with a progress bar),
/// also live in the app (red), or when the next lesson starts. It always
/// says the status comes from the schedule.
class _StatusBand extends StatelessWidget {
  const _StatusBand(
      {required this.lesson,
      required this.timing,
      required this.live,
      required this.when});

  final Lesson lesson;
  final LessonTiming timing;
  final bool live;
  final String when;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final running = timing.phase == LessonPhase.running;
    final (bg, fg) = live
        ? (t.liveSoft, t.liveText)
        : running
            ? (t.okSoft, t.ok)
            : (t.sunk, t.fg);
    final head = live
        ? 'lessons.map.both'.tr()
        : running
            ? 'lessons.map.on_site'.tr()
            : '${'lessons.map.starts_in'.tr()} ${durationLabel(timing.minutes, lang)}';
    return LPressable(
        onTap: () => openLesson(context, lesson.id),
        label: '$head. ${lesson.title(lang)}',
        radius: Lantern.radiusField,
        pressScale: .99,
        excludeChildSemantics: true,
        builder: (context, _) => Container(
            key: const ValueKey('lantern-map-status-band'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(Lantern.radiusField)),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    LIcon(
                        live
                            ? LGlyph.live
                            : running
                                ? LGlyph.mosque
                                : LGlyph.clock,
                        size: 16,
                        color: fg),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(head,
                            style: Lantern.textStyle(13,
                                color: fg,
                                weight: FontWeight.w700,
                                height: 1.35))),
                    if (running)
                      Text(
                          'lessons.map.left_about'.tr(
                              args: [durationLabel(timing.minutes, lang)]),
                          style: Lantern.textStyle(12,
                                  color: fg, height: 1.35)
                              .copyWith(fontFeatures: Lantern.tabular)),
                  ]),
                  const SizedBox(height: 4),
                  Text(lesson.title(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lantern.textStyle(14.5,
                          color: t.fg, weight: FontWeight.w700, height: 1.4)),
                  Text(when,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lantern.textStyle(12.5,
                          color: t.muted, height: 1.4)),
                  if (running) ...[
                    const SizedBox(height: 8),
                    LProgress(timing.progress.clamp(0, 1).toDouble(),
                        height: 6, color: live ? t.live : t.ok),
                  ],
                  const SizedBox(height: 6),
                  Text('lessons.map.from_schedule'.tr(),
                      style: Lantern.textStyle(11.5,
                          color: t.muted, height: 1.3)),
                ])));
  }
}

class _LessonLine extends StatelessWidget {
  const _LessonLine({required this.lesson, required this.controller});

  final Lesson lesson;
  final LessonsController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final l = lesson;
    final preacher = controller.preacher(l.preacherId);
    return LPressable(
        onTap: () => openLesson(context, l.id),
        label: l.title(lang),
        radius: Lantern.radiusTile,
        pressScale: .99,
        excludeChildSemantics: true,
        builder: (context, s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: s.hovered ? t.sunk : t.surface,
                borderRadius: BorderRadius.circular(Lantern.radiusTile),
                border: Border.all(color: t.line2)),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(l.title(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lantern.textStyle(14,
                            color: t.fg,
                            weight: FontWeight.w600,
                            height: 1.4)),
                    Text(
                        [
                          whenOf(controller, l, lang),
                          if (preacher != null) preacher.name(lang)
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Lantern.textStyle(12.5,
                            color: t.muted, height: 1.4)),
                  ])),
              if (controller.hasReminder(l.id))
                Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: LIcon(LGlyph.bell, size: 16, color: t.goldInk)),
              const SizedBox(width: 6),
              LIcon(LGlyph.chevronend, size: 16, color: t.faint),
            ])));
  }
}

/// A broadcaster chosen on the map: a small stage that says its state (live
/// with the viewers, an audio waveform, a countdown, or when the next
/// broadcast is), the avatar over the stage's edge, where it broadcasts
/// from, and the way in.
class LanternStreamerPlaceCard extends StatelessWidget
    implements LanternSkinWidget {
  const LanternStreamerPlaceCard(
      {super.key,
      required this.streamer,
      required this.onClose,
      this.nextStart,
      this.nextTitle});

  final StreamerModel streamer;
  final VoidCallback onClose;

  /// The next planned broadcast, when the channel is not live.
  final DateTime? nextStart;
  final String? nextTitle;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = streamer;
    final live = s.isCurrentlyLive;
    final following = context
        .select<AppProvider, bool>((p) => p.isFollowing(s.channelProfileId));
    final own = context
        .select<AppProvider, bool>((p) => p.isOwnStreamerProfile(s.streamerId));
    final venue = s.getLocalizedVenue(lang), city = s.getLocalizedCity(lang);
    final next = nextStart;
    final soon = !live &&
        next != null &&
        next.difference(DateTime.now()) < const Duration(hours: 12);
    void open() => context.push(live
        ? '/live/${s.liveSessionId ?? s.streamerId}'
        : '/profile/${s.channelProfileId}');
    return LCard(
        key: const ValueKey('lantern-map-streamer-card'),
        padding: EdgeInsets.zero,
        clip: false,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(clipBehavior: Clip.none, children: [
                ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(Lantern.radiusCard - 1)),
                    child: LanternStage(
                        aspectRatio: 16 / 6,
                        tone: s.isAudioLive
                            ? LanternStageTone.audio
                            : live
                                ? LanternStageTone.live
                                : LanternStageTone.quiet,
                        image: live
                            ? resolveImageProviderOrNull(s.bannerUrl)
                            : null,
                        topStart: live
                            ? LanternStateBadge(s)
                            : next != null
                                ? LBadge('lantern.discover.scheduled'.tr(),
                                    kind: LBadgeKind.soon, icon: LGlyph.clock)
                                : LBadge('feed.offline_badge'.tr(),
                                    kind: LBadgeKind.off),
                        bottomEnd: live ? LanternViewers(s) : null,
                        center: s.isAudioLive
                            ? const LanternWaveform()
                            : live
                                ? null
                                : _NextBroadcast(
                                    start: next,
                                    title: nextTitle,
                                    countdown: soon))),
                PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: LIconButton(
                        icon: LGlyph.close,
                        label: 'lantern.map.close_card'.tr(),
                        glass: true,
                        size: 36,
                        iconSize: 18,
                        onPressed: onClose)),
                PositionedDirectional(
                    start: 14,
                    bottom: -24,
                    child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(
                                s.isOrganization ? 22 : 40)),
                        child: LanternChannelAvatar(s, size: 54))),
              ]),
              Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 30, 14, 14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                            header: true,
                            child: Text(s.getLocalizedName(lang),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Lantern.textStyle(16,
                                    color: t.fg,
                                    weight: FontWeight.w700,
                                    height: 1.4))),
                        Text(s.getLocalizedTitle(lang),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Lantern.textStyle(13,
                                color: t.muted, height: 1.45)),
                        if (venue.isNotEmpty || city.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          LPressable(
                              key: const ValueKey('lantern-map-card-venue'),
                              onTap: () => openVenueDirections(
                                  context, s.latitude, s.longitude,
                                  googleOnly: true),
                              label: 'venue.open_maps'.tr(),
                              radius: Lantern.radiusTile,
                              pressScale: .99,
                              excludeChildSemantics: true,
                              builder: (context, state) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                      color: state.hovered ? t.line : t.sunk,
                                      borderRadius: BorderRadius.circular(
                                          Lantern.radiusTile)),
                                  child: Row(children: [
                                    LIcon(LGlyph.pin,
                                        size: 18, color: t.goldInk),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text(venue.isEmpty ? city : venue,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: Lantern.textStyle(13.5,
                                                  color: t.fg,
                                                  weight: FontWeight.w600,
                                                  height: 1.4)),
                                          if (venue.isNotEmpty &&
                                              city.isNotEmpty)
                                            Text(city,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: Lantern.textStyle(12.5,
                                                    color: t.muted,
                                                    height: 1.4)),
                                        ])),
                                    const SizedBox(width: 8),
                                    LIcon(LGlyph.directions,
                                        size: 18, color: t.goldInk),
                                  ]))),
                        ],
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          LButton(
                              key: const ValueKey('lantern-map-card-open'),
                              label: live
                                  ? (s.isAudioLive ? 'web.listen' : 'web.watch')
                                      .tr()
                                  : 'lantern.map.open_channel'.tr(),
                              icon: !live
                                  ? LGlyph.person
                                  : s.isAudioLive
                                      ? LGlyph.audio
                                      : LGlyph.live,
                              kind: s.isAudioLive
                                  ? LButtonKind.dark
                                  : LButtonKind.primary,
                              size: LButtonSize.small,
                              onPressed: open),
                          if (!own)
                            LButton(
                                label: (following
                                        ? 'profile.following_btn'
                                        : 'web.follow')
                                    .tr(),
                                icon: following ? LGlyph.check : LGlyph.plus,
                                kind: LButtonKind.tonal,
                                size: LButtonSize.small,
                                onPressed: () => toggleFollowWithFeedback(
                                    context, s.channelProfileId)),
                        ]),
                      ])),
            ]));
  }
}

class _NextBroadcast extends StatelessWidget {
  const _NextBroadcast(
      {required this.start, required this.title, required this.countdown});

  final DateTime? start;
  final String? title;
  final bool countdown;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final start = this.start;
    if (start == null) {
      return Text('lantern.map.not_scheduled'.tr(),
          style: Lantern.textStyle(13,
              color: const Color(0xFFC9D1D8), weight: FontWeight.w500));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
          (countdown
                  ? 'lantern.discover.starts_in'
                  : 'lantern.map.next_broadcast')
              .tr(),
          style: Lantern.textStyle(12,
              color: const Color(0xFFC9D1D8),
              weight: FontWeight.w500,
              height: 1.3)),
      if (countdown)
        LanternCountdown(
            start: start,
            style: Lantern.displayStyle(22,
                color: LanternTokens.goldHi, height: 1.2))
      else
        Text(lanternUntil(start, DateTime.now(), lang),
            style: Lantern.displayStyle(17,
                color: LanternTokens.goldHi, height: 1.3)),
      if ((title ?? '').isNotEmpty)
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Lantern.textStyle(12.5,
                    color: LanternTokens.onNight, height: 1.3))),
    ]);
  }
}

/// Places that share one spot and never come apart on the map (a broadcaster
/// streaming from a mosque): a short list to choose from.
Future<void> showLanternPlaceList(BuildContext context,
        {required String title,
        required List<({String label, bool mosque, VoidCallback open})>
            places}) =>
    showLanternSheet<void>(context,
        title: title,
        body: (context) => Column(
                key: const ValueKey('lantern-map-place-list'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final place in places)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LRow(
                            title: place.label,
                            icon: place.mosque ? LGlyph.mosque : LGlyph.person,
                            onTap: () {
                              Navigator.of(context).maybePop();
                              place.open();
                            })),
                ]));
