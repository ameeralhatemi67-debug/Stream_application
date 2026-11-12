import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/follow_action.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../profile/models/streamer_models.dart';
import '../../../profile/models/upcoming_schedule.dart';

/// Counts with Latin digits and separators in both languages, as the rest of
/// the app writes them.
String lanternCount(int? value) =>
    value == null ? '—' : NumberFormat.decimalPattern('en').format(value);

/// "in 35 min", "in 2 h 10 min", or the weekday and time for a later day.
String lanternUntil(DateTime start, DateTime now, String lang) {
  final left = start.difference(now);
  if (left.inMinutes < 1) return 'lantern.time.now'.tr();
  if (left.inMinutes < 60) {
    return 'lantern.time.in_minutes'.tr(args: ['${left.inMinutes}']);
  }
  if (left.inHours < 12) {
    return 'lantern.time.in_hours'
        .tr(args: ['${left.inHours}', '${left.inMinutes.remainder(60)}']);
  }
  final local = start.toLocal();
  return '${DateFormat.EEEE(lang).format(local)} ${DateFormat.jm('en').format(local)}';
}

ImageProvider? _avatarOf(StreamerModel s) =>
    resolveImageProviderOrNull(s.avatarUrl);

LRing lanternRingOf(StreamerModel s) => s.isAudioLive
    ? LRing.audio
    : s.isCurrentlyLive
        ? LRing.live
        : LRing.none;

/// A channel's avatar with the ring of its state.
class LanternChannelAvatar extends StatelessWidget
    implements LanternSkinWidget {
  const LanternChannelAvatar(this.streamer,
      {super.key, this.size = 46, this.ring = true});

  final StreamerModel streamer;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) => LAvatar(
      name: streamer.getLocalizedName(context.locale.languageCode),
      image: _avatarOf(streamer),
      size: size,
      org: streamer.isOrganization,
      verified: streamer.isVerified,
      ring: ring ? lanternRingOf(streamer) : LRing.none);
}

enum LanternStageTone { live, audio, quiet }

/// The 16:9 picture of a broadcast: the channel's banner under a veil when it
/// has one, otherwise a night ground with the arch. Badges and a centre piece
/// sit over it.
class LanternStage extends StatelessWidget implements LanternSkinWidget {
  const LanternStage(
      {super.key,
      required this.tone,
      this.image,
      this.topStart,
      this.topEnd,
      this.bottomStart,
      this.bottomEnd,
      this.center,
      this.aspectRatio = 16 / 9,
      this.radius = 0});

  final LanternStageTone tone;
  final ImageProvider? image;
  final Widget? topStart, topEnd, bottomStart, bottomEnd, center;
  final double aspectRatio, radius;

  static const _grounds = {
    LanternStageTone.live: [Color(0xFF5E4A22), Color(0xFF151D24)],
    LanternStageTone.audio: [Color(0xFF1B4B5B), Color(0xFF0B1117)],
    LanternStageTone.quiet: [Color(0xFF2B3742), Color(0xFF0E151B)],
  };

  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: _grounds[tone]!))),
            if (image != null)
              Image(
                  image: image!,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            if (image != null)
              const DecoratedBox(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x660B1117), Color(0xCC0B1117)])))
            else
              // The arch, as a soft shape rising from the bottom edge.
              Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                      widthFactor: .56,
                      heightFactor: .72,
                      child: DecoratedBox(
                          decoration: ShapeDecoration(
                              color: const Color(0x14FFFFFF),
                              shape: LArchBorder(
                                  side: BorderSide(
                                      color: LanternTokens.white
                                          .withValues(alpha: .1))))))),
            if (center != null) Center(child: center),
            if (topStart != null)
              PositionedDirectional(top: 12, start: 12, child: topStart!),
            if (topEnd != null)
              PositionedDirectional(top: 12, end: 12, child: topEnd!),
            if (bottomStart != null)
              PositionedDirectional(bottom: 12, start: 12, child: bottomStart!),
            if (bottomEnd != null)
              PositionedDirectional(bottom: 12, end: 12, child: bottomEnd!),
          ])));
}

/// A still waveform for an audio room's picture.
class LanternWaveform extends StatelessWidget implements LanternSkinWidget {
  const LanternWaveform({super.key, this.color = LanternTokens.white});

  final Color color;

  static const _heights = [
    .3, .55, .8, .45, .95, .6, .35, .75, 1.0, .5, .85, .4, .65, .3, .7, .45
  ];

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox(
          height: 34,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final h in _heights) ...[
              Container(
                  width: 3,
                  height: 34 * h,
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .85),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
            ],
          ])));
}

/// The state badge of a channel: LIVE, AUDIO, or nothing when it is offline.
class LanternStateBadge extends StatelessWidget implements LanternSkinWidget {
  const LanternStateBadge(this.streamer, {super.key, this.small = false});

  final StreamerModel streamer;
  final bool small;

  @override
  Widget build(BuildContext context) => streamer.isAudioLive
      ? LBadge('web.badge_audio'.tr(), kind: LBadgeKind.audio, small: small)
      : streamer.isCurrentlyLive
          ? LBadge('web.badge_live'.tr(), kind: LBadgeKind.live, small: small)
          : LBadge('feed.offline_badge'.tr(),
              kind: LBadgeKind.off, small: small);
}

/// The viewer count of a live room over its picture; "—" until it is known.
class LanternViewers extends StatelessWidget implements LanternSkinWidget {
  const LanternViewers(this.streamer, {super.key});

  final StreamerModel streamer;

  @override
  Widget build(BuildContext context) {
    final count = context.select<AppProvider, int?>(
        (p) => p.platformViewerCount(streamer.activeStreamId ?? ''));
    return Semantics(
        label: count == null
            ? 'lantern.discover.viewers_unknown'.tr()
            : '$count ${(streamer.isAudioLive ? 'web.listening' : 'web.watching').tr()}',
        excludeSemantics: true,
        child: LBadge(lanternCount(count),
            kind: LBadgeKind.glass,
            icon: streamer.isAudioLive ? LGlyph.audio : LGlyph.eye));
  }
}

void lanternOpenRoom(BuildContext context, StreamerModel s) {
  final id = s.activeStreamId;
  if (id != null && id.isNotEmpty) context.push('/live/$id');
}

void lanternOpenChannel(BuildContext context, StreamerModel s) =>
    context.push('/profile/${s.channelProfileId}');

/// A live room as a card: its picture with the state and the viewers, then
/// who is speaking and one button to enter.
class LanternLiveCard extends StatelessWidget implements LanternSkinWidget {
  const LanternLiveCard(this.streamer, {super.key});

  final StreamerModel streamer;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = streamer;
    final title = s.getLocalizedTitle(lang);
    return LCard(
        padding: EdgeInsets.zero,
        label: 'lantern.discover.open_room'.tr(args: [title]),
        onTap: () => lanternOpenRoom(context, s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LanternStage(
              tone: s.isAudioLive
                  ? LanternStageTone.audio
                  : LanternStageTone.live,
              image: resolveImageProviderOrNull(s.bannerUrl),
              topStart: LanternStateBadge(s),
              topEnd: LanternViewers(s),
              center: s.isAudioLive ? const LanternWaveform() : null),
          Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                LanternChannelAvatar(s),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(15,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.4)),
                      Text(
                          [
                            s.getLocalizedName(lang),
                            s.getLocalizedCity(lang)
                          ].where((v) => v.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(13,
                              color: t.muted, height: 1.4)),
                    ])),
                const SizedBox(width: 10),
                // The card is the button; this repeats it for the eye.
                ExcludeSemantics(
                    child: IgnorePointer(
                        child: LButton(
                            label: (s.isAudioLive ? 'web.listen' : 'web.watch')
                                .tr(),
                            icon: s.isAudioLive ? LGlyph.audio : LGlyph.live,
                            kind: s.isAudioLive
                                ? LButtonKind.dark
                                : LButtonKind.primary,
                            size: LButtonSize.small,
                            onPressed: () {}))),
              ])),
        ]));
  }
}

/// A countdown that keeps time while it is on screen: seconds inside the
/// last hour (minutes under calm motion), minutes before that.
class LanternCountdown extends StatefulWidget implements LanternSkinWidget {
  const LanternCountdown(
      {super.key, required this.start, required this.style, this.onDue});

  final DateTime start;
  final TextStyle style;
  final VoidCallback? onDue;

  @override
  State<LanternCountdown> createState() => _LanternCountdownState();
}

class _LanternCountdownState extends State<LanternCountdown> {
  Timer? _tick;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(LanternCountdown old) {
    super.didUpdateWidget(old);
    if (old.start != widget.start) _schedule();
  }

  void _schedule() {
    _tick?.cancel();
    final left = widget.start.difference(DateTime.now());
    if (left.isNegative) return;
    final seconds = left.inMinutes < 60 && !Lantern.calm(context);
    _tick = Timer(
        seconds
            ? const Duration(seconds: 1)
            : Duration(seconds: 60 - DateTime.now().second), () {
      if (!mounted) return;
      setState(() {});
      if (!widget.start.isAfter(DateTime.now())) widget.onDue?.call();
      _schedule();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final left = widget.start.difference(now);
    final lang = context.locale.languageCode;
    final text = left.isNegative
        ? 'lantern.time.now'.tr()
        : left.inMinutes < 60 && !Lantern.calm(context)
            ? '${left.inMinutes.toString().padLeft(2, '0')}:${left.inSeconds.remainder(60).toString().padLeft(2, '0')}'
            : lanternUntil(widget.start, now, lang);
    return Text(text,
        textDirection: TextDirection.ltr,
        style: widget.style.copyWith(fontFeatures: Lantern.tabular));
  }
}

/// A planned broadcast that has not started: its picture with a countdown,
/// who gives it, and Remind me. New in Lantern and Arch.
class LanternSoonCard extends StatelessWidget implements LanternSkinWidget {
  const LanternSoonCard(
      {super.key,
      required this.streamer,
      required this.schedule,
      required this.start,
      required this.onRemind});

  final StreamerModel streamer;
  final UpcomingSchedule schedule;
  final DateTime start;

  /// Null hides the reminder button (reminders need push, which this build
  /// may not have).
  final VoidCallback? onRemind;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = streamer;
    final reminded = context.select<AppProvider, bool>(
        (p) => p.hasReminder(s.channelProfileId));
    final title = schedule.title(lang).isEmpty
        ? s.getLocalizedTitle(lang)
        : schedule.title(lang);
    return LCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LPressable(
              onTap: () => lanternOpenChannel(context, s),
              label: 'lantern.discover.open_channel'
                  .tr(args: [s.getLocalizedName(lang)]),
              radius: 0,
              pressScale: 1,
              focusRing: false,
              excludeChildSemantics: true,
              builder: (context, _) => LanternStage(
                  tone: LanternStageTone.quiet,
                  topStart: LBadge('lantern.discover.scheduled'.tr(),
                      kind: LBadgeKind.soon, icon: LGlyph.clock),
                  bottomEnd: LBadge(
                      lanternUntil(start, DateTime.now(), lang),
                      kind: LBadgeKind.glass),
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('lantern.discover.starts_in'.tr(),
                        style: Lantern.textStyle(12.5,
                            color: const Color(0xFFC9D1D8),
                            weight: FontWeight.w500,
                            height: 1.3)),
                    LanternCountdown(
                        start: start,
                        style: Lantern.displayStyle(28,
                            color: LanternTokens.goldHi, height: 1.2)),
                  ]))),
          Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                LanternChannelAvatar(s, ring: false),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(15,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.4)),
                      Text(
                          [
                            s.getLocalizedName(lang),
                            s.getLocalizedCity(lang)
                          ].where((v) => v.isNotEmpty).join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Lantern.textStyle(13,
                              color: t.muted, height: 1.4)),
                    ])),
                if (onRemind != null) ...[
                  const SizedBox(width: 10),
                  LButton(
                      label: (reminded
                              ? 'lantern.discover.reminder_on'
                              : 'lantern.discover.remind')
                          .tr(),
                      icon: reminded ? LGlyph.check : LGlyph.bell,
                      kind: LButtonKind.tonal,
                      size: LButtonSize.small,
                      onPressed: onRemind),
                ],
              ])),
        ]));
  }
}

/// A scholar or channel as a card: a band with the lattice in the channel's
/// own tone, the avatar over its edge with the ring of its state, the name,
/// what they teach, the city, then the tags with Watch or Listen and Follow
/// on one line. Every card has the same height.
class LanternChannelCard extends StatelessWidget implements LanternSkinWidget {
  const LanternChannelCard(this.streamer, {super.key, this.nextLive});

  final StreamerModel streamer;

  /// The next planned broadcast, when one is known and the channel is not
  /// live.
  final DateTime? nextLive;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = streamer;
    final name = s.getLocalizedName(lang);
    final tone = LAvatar.tones[LAvatar.toneOf(name)];
    final following = context
        .select<AppProvider, bool>((p) => p.isFollowing(s.channelProfileId));
    final own = context
        .select<AppProvider, bool>((p) => p.isOwnStreamerProfile(s.streamerId));
    final city = s.getLocalizedCity(lang);
    final next = nextLive;
    return LCard(
        padding: EdgeInsets.zero,
        clip: false,
        onTap: () => lanternOpenChannel(context, s),
        label: 'lantern.discover.open_channel'.tr(args: [name]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              height: 84,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(
                    child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(Lantern.radiusCard - 1)),
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: tone)),
                            child: const Stack(children: [
                              LLattice(
                                  color: LanternTokens.white,
                                  opacity: .14,
                                  step: 26),
                            ])))),
                PositionedDirectional(
                    top: 10, end: 10, child: _channelBadge(s, next, lang)),
                PositionedDirectional(
                    start: 16,
                    bottom: -26,
                    child: Container(
                        decoration: BoxDecoration(
                            color: t.surface,
                            borderRadius: BorderRadius.circular(
                                s.isOrganization ? 24 : 40)),
                        padding: const EdgeInsets.all(3),
                        child: LanternChannelAvatar(s, size: 62))),
              ])),
          Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 30, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                          child: Text(name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Lantern.textStyle(16,
                                  color: t.fg,
                                  weight: FontWeight.w700,
                                  height: 1.4))),
                      if (s.isOrganization) ...[
                        const SizedBox(width: 8),
                        LTag('web.nav_orgs'.tr(), icon: LGlyph.org),
                      ] else if (own) ...[
                        const SizedBox(width: 8),
                        LTag('feed.your_channel_badge'.tr(), tone: LTone.gold),
                      ],
                    ]),
                    Text(s.getLocalizedTitle(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Lantern.textStyle(13, color: t.muted, height: 1.5)),
                    // The place line is kept even when empty, and the tags
                    // share one line with the buttons, so every card in a
                    // row is the same height (owner notes 2026-11-12).
                    Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: SizedBox(
                            height: 19,
                            child: city.isEmpty
                                ? null
                                : Row(children: [
                                    LIcon(LGlyph.pin, size: 14, color: t.muted),
                                    const SizedBox(width: 5),
                                    Flexible(
                                        child: Text(city,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Lantern.textStyle(13,
                                                color: t.muted, height: 1.4))),
                                  ]))),
                    const SizedBox(height: 12),
                    SizedBox(
                        key: const ValueKey('lantern-channel-card-actions'),
                        height: 36,
                        child: Row(children: [
                          // The tags that fit on one line; the rest are cut.
                          Expanded(
                              child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: SizedBox(
                                      height: 22,
                                      child: Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          clipBehavior: Clip.hardEdge,
                                          children: [
                                            for (final tag in s.tags.take(3))
                                              LTag(tag),
                                          ])))),
                          if (s.isCurrentlyLive) ...[
                            const SizedBox(width: 8),
                            LButton(
                                label: (s.isAudioLive
                                        ? 'web.listen'
                                        : 'web.watch')
                                    .tr(),
                                icon: s.isAudioLive
                                    ? LGlyph.audio
                                    : LGlyph.live,
                                kind: s.isAudioLive
                                    ? LButtonKind.dark
                                    : LButtonKind.primary,
                                size: LButtonSize.small,
                                onPressed: () => lanternOpenRoom(context, s)),
                          ],
                          // Follow at the end of the tags' line: the left in
                          // Arabic.
                          if (!own) ...[
                            const SizedBox(width: 8),
                            LButton(
                                key: const ValueKey('lantern-channel-card-follow'),
                                label: (following
                                        ? 'profile.following_btn'
                                        : 'web.follow')
                                    .tr(),
                                icon: following ? LGlyph.check : LGlyph.plus,
                                kind: LButtonKind.tonal,
                                size: LButtonSize.small,
                                onPressed: () => toggleFollowWithFeedback(
                                    context, s.channelProfileId)),
                          ],
                        ])),
                  ])),
        ]));
  }

  Widget _channelBadge(StreamerModel s, DateTime? next, String lang) {
    if (s.isCurrentlyLive) return LanternStateBadge(s, small: true);
    if (next != null) {
      return LBadge(lanternUntil(next, DateTime.now(), lang),
          kind: LBadgeKind.soon, icon: LGlyph.clock, small: true);
    }
    return const SizedBox.shrink();
  }
}
