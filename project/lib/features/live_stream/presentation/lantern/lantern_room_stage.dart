import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../discovery/presentation/lantern/lantern_stream_cards.dart';
import '../../models/stream_privacy_models.dart';
import '../abstract_video_player.dart';
import '../widgets/floating_reactions_overlay.dart';
import 'lantern_room_view.dart';

/// LIVE, AUDIO, reconnecting, or a recording: the room's state in words.
class LanternRoomStateBadge extends StatelessWidget
    implements LanternSkinWidget {
  const LanternRoomStateBadge(
      {super.key, required this.room, this.small = false});

  final LanternRoom room;
  final bool small;

  @override
  Widget build(BuildContext context) {
    if (room.interrupted) {
      return LBadge('live.chat_status_reconnecting'.tr(),
          kind: LBadgeKind.soon, icon: LGlyph.wifioff, small: small);
    }
    if (room.replay) {
      return LBadge('lantern.room.recording'.tr(),
          kind: LBadgeKind.off, icon: LGlyph.history, small: small);
    }
    if (!room.streamer.isLiveForRoom) {
      return LBadge('feed.offline_badge'.tr(),
          kind: LBadgeKind.off, small: small);
    }
    return room.audio
        ? LBadge('web.badge_audio'.tr(),
            kind: LBadgeKind.audio, small: small, paused: !room.playing)
        : LBadge('web.badge_live'.tr(), kind: LBadgeKind.live, small: small);
  }
}

/// The stage: always 16:9 and as large as its space allows. The player sits
/// at the bottom of the stack; over it come the audio dial (audio rooms),
/// rising reactions, a veil when there is nothing to watch, the state and
/// viewer count, and the controls.
class LanternRoomStage extends StatefulWidget implements LanternSkinWidget {
  const LanternRoomStage({super.key, required this.room});

  final LanternRoom room;

  @override
  State<LanternRoomStage> createState() => _LanternRoomStageState();
}

class _LanternRoomStageState extends State<LanternRoomStage> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final wide = context.lanternWide;
    // Phones always show the controls; with a pointer they come on hover, and
    // stay while the room is paused.
    final showControls = !wide || _hovered || !room.playing;
    final veil = _veilOf(context, room);
    // As tall as 16:9 asks at this width; when the height is short (the
    // keyboard is open), the picture narrows and the sides stay black.
    return ColoredBox(
        color: const Color(0xFF000000),
        child: Center(
            heightFactor: 1,
            child: AspectRatio(
                aspectRatio: 16 / 9,
                child: MouseRegion(
                    onEnter: (_) => setState(() => _hovered = true),
                    onExit: (_) => setState(() => _hovered = false),
                    child: Stack(fit: StackFit.expand, children: [
                      if (room.player != null) room.player!,
                      if (room.audio) _AudioDial(room: room),
                      Positioned.fill(
                          child: LanternReactions(controller: room.reactions)),
                      if (veil != null) Positioned.fill(child: veil),
                      PositionedDirectional(
                          top: 12,
                          start: 12,
                          end: 12,
                          child: Row(children: [
                            LanternRoomStateBadge(room: room),
                            const SizedBox(width: 8),
                            if (room.live)
                              Semantics(
                                  label: room.viewers == null
                                      ? 'lantern.discover.viewers_unknown'.tr()
                                      : '${room.viewers} ${(room.audio ? 'web.listening' : 'web.watching').tr()}',
                                  excludeSemantics: true,
                                  child: LBadge(lanternCount(room.viewers),
                                      kind: LBadgeKind.glass,
                                      icon: room.audio
                                          ? LGlyph.audio
                                          : LGlyph.eye)),
                            const Spacer(),
                            if (room.access == ViewerAccessState.vipPreApproved)
                              LBadge('design_ui.vip_invited'.tr(),
                                  kind: LBadgeKind.glass, icon: LGlyph.crown),
                          ])),
                      if (room.handRaised)
                        PositionedDirectional(
                            bottom: 64,
                            end: 12,
                            child: LBadge('live.hand_raised_badge'.tr().trim(),
                                kind: LBadgeKind.soon, icon: LGlyph.hand)),
                      PositionedDirectional(
                          bottom: 0,
                          start: 0,
                          end: 0,
                          child: AnimatedOpacity(
                              opacity: showControls ? 1 : 0,
                              duration: Lantern.calm(context)
                                  ? Lantern.none
                                  : Lantern.state,
                              child: IgnorePointer(
                                  ignoring: !showControls,
                                  child: _Controls(room: room)))),
                    ])))));
  }

  /// What covers the stage when there is nothing to watch, or null.
  Widget? _veilOf(BuildContext context, LanternRoom room) {
    if (room.access == ViewerAccessState.knocking) {
      return _Veil(
          key: const ValueKey('lantern-room-knocking'),
          icon: LGlyph.lock,
          title: 'design_ui.this_is_a_private_broadcast'.tr(),
          body: 'design_ui.waiting_for_host_to_admit_you'.tr(),
          busy: true);
    }
    if (room.access == ViewerAccessState.denied) {
      return _Veil(
          key: const ValueKey('lantern-room-private'),
          icon: LGlyph.lock,
          title: 'design_ui.this_broadcast_is_private'.tr(),
          body: 'design_ui.contact_the_host_for_access'.tr(),
          action: room.onRequestJoin == null
              ? null
              : LButton(
                  label: 'design_ui.request_to_join'.tr(),
                  size: LButtonSize.small,
                  onPressed: room.onRequestJoin));
    }
    if (room.interrupted) {
      return _Veil(
          key: const ValueKey('lantern-room-interrupted'),
          icon: LGlyph.wifioff,
          title: 'live.be_right_back_title'.tr(),
          body: 'live.be_right_back_body'.tr(),
          busy: true);
    }
    if (room.recovering) {
      return _Veil(
          key: const ValueKey('lantern-room-recovering'),
          icon: LGlyph.refresh,
          title: 'live.stream_interrupted_reconnecting_attempt'.tr(namedArgs: {
            'current': '${room.recoveryAttempts}',
            'total': '10'
          }),
          busy: true,
          action: LButton(
              label: 'live.retry_feed'.tr(),
              kind: LButtonKind.secondary,
              size: LButtonSize.small,
              onPressed: room.onRetry));
    }
    final artwork = resolveImageProviderOrNull(room.customArtwork);
    switch (room.state) {
      case StreamState.live:
      case StreamState.paused:
      case StreamState.buffering:
        return null;
      case StreamState.unconfirmed:
        return Align(
            alignment: Alignment.topCenter,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 48, 12, 0),
                child: LBanner('live.player_state_unconfirmed'.tr(),
                    tone: LTone.warn,
                    action: LButton(
                        label: 'live.retry_feed'.tr(),
                        kind: LButtonKind.tonal,
                        size: LButtonSize.small,
                        onPressed: room.onRetry))));
      case StreamState.initializing:
        return _Veil(
            key: const ValueKey('lantern-room-loading'),
            title: 'live.chat_status_connecting'.tr(),
            busy: true,
            image: artwork);
      case StreamState.startingSoon:
        return _Veil(
            key: const ValueKey('lantern-room-soon'),
            icon: LGlyph.clock,
            title: 'lantern.room.starting_soon'.tr(),
            body: 'lantern.room.starting_soon_body'.tr(),
            image: artwork);
      case StreamState.reconnecting:
        return _Veil(
            key: const ValueKey('lantern-room-reconnecting'),
            icon: LGlyph.refresh,
            title: 'live.chat_status_reconnecting'.tr(),
            busy: true,
            image: artwork);
      case StreamState.ended:
        return _Veil(
            key: const ValueKey('lantern-room-ended'),
            icon: LGlyph.stop,
            title: 'live.room_ended_title'.tr(),
            body: 'live.room_ended_body'.tr(),
            image: artwork);
      case StreamState.offline:
      case StreamState.noAudioToken:
      case StreamState.fallbackError:
        return _Veil(
            key: const ValueKey('lantern-room-offline'),
            icon: LGlyph.videooff,
            title: 'live.state_offline_title'.tr(),
            image: artwork,
            action: Wrap(spacing: 8, runSpacing: 8, children: [
              LButton(
                  label: 'live.retry_feed'.tr(),
                  icon: LGlyph.refresh,
                  size: LButtonSize.small,
                  onPressed: room.onRetry),
              if (room.onOpenInYouTube != null)
                LButton(
                    label: 'live.open_in_youtube'.tr(),
                    icon: LGlyph.external,
                    kind: LButtonKind.secondary,
                    size: LButtonSize.small,
                    onPressed: room.onOpenInYouTube),
            ]));
    }
  }
}

/// A veil over the stage: an icon or the turning star, a title, a sentence,
/// and at most one row of actions. It fades in.
class _Veil extends StatelessWidget {
  const _Veil(
      {super.key,
      required this.title,
      this.body,
      this.icon,
      this.busy = false,
      this.action,
      this.image});

  final String title;
  final String? body;
  final LGlyph? icon;
  final bool busy;
  final Widget? action;

  /// The broadcaster's own approved artwork for this state.
  final ImageProvider? image;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return TweenAnimationBuilder<double>(
        tween: Tween(begin: Lantern.calm(context) ? 1 : 0, end: 1),
        duration: Lantern.calm(context) ? Lantern.none : Lantern.enter,
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: Semantics(
            liveRegion: true,
            container: true,
            child: Stack(fit: StackFit.expand, children: [
              const ColoredBox(color: Color(0xE60B1117)),
              if (image != null)
                Opacity(
                    opacity: .35,
                    child: Image(
                        image: image!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink())),
              const LLattice(opacity: .06),
              Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (busy)
                          const LStarLoader(size: 30)
                        else if (icon != null)
                          LIcon(icon!, size: 32, color: LanternTokens.goldHi),
                        const SizedBox(height: 10),
                        Text(title,
                            textAlign: TextAlign.center,
                            style: Lantern.displayStyle(17,
                                color: t.fg,
                                height: context.lanternArabic ? 1.5 : 1.3)),
                        if (body != null) ...[
                          const SizedBox(height: 4),
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 380),
                              child: Text(body!,
                                  textAlign: TextAlign.center,
                                  style: Lantern.textStyle(13,
                                      color: t.muted, height: 1.45))),
                        ],
                        if (action != null) ...[
                          const SizedBox(height: 12),
                          action!
                        ],
                      ]))),
            ])));
  }
}

/// Play or pause, sound, then the corner player and full screen. Glass
/// buttons over a soft scrim. Play, pause and sound show only when the
/// player takes them from the app.
class _Controls extends StatelessWidget {
  const _Controls({required this.room});

  final LanternRoom room;

  @override
  Widget build(BuildContext context) => Stack(children: [
        // The scrim is paint only: a tap between the buttons must still
        // reach a veil's action underneath.
        const Positioned.fill(
            child: IgnorePointer(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x000B1117), Color(0xB30B1117)]))))),
        Padding(
            padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
            child: Row(children: [
              if (room.transport) ...[
                LIconButton(
                    key: const ValueKey('lantern-room-play'),
                    icon: room.playing ? LGlyph.pause : LGlyph.play,
                    label: (room.playing
                            ? 'lantern.room.pause'
                            : 'lantern.room.play')
                        .tr(),
                    glass: true,
                    onPressed: room.onTogglePlay),
                const SizedBox(width: 6),
                LIconButton(
                    key: const ValueKey('lantern-room-mute'),
                    icon: room.muted ? LGlyph.volumeoff : LGlyph.volume,
                    label: (room.muted
                            ? 'lantern.room.unmute'
                            : 'lantern.room.mute')
                        .tr(),
                    glass: true,
                    onPressed: room.onToggleMute),
              ],
              const Spacer(),
              LIconButton(
                  icon: LGlyph.pip,
                  label: 'web.minimize'.tr(),
                  glass: true,
                  onPressed: room.onMinimize),
              const SizedBox(width: 6),
              LIconButton(
                  key: const ValueKey('lantern-room-fullscreen'),
                  icon: LGlyph.fullscreen,
                  label: (room.fullscreen
                          ? 'lantern.room.exit_fullscreen'
                          : 'lantern.room.fullscreen')
                      .tr(),
                  glass: true,
                  onPressed: room.onToggleFullscreen),
            ])),
      ]);
}

/// The audio room's stage, framed like a radio dial: the host, the title, a
/// waveform, and the promise that it keeps playing in the background.
///
/// There is no speaking signal yet, so the large avatar is the host, not the
/// person talking (an open question for the owner).
class _AudioDial extends StatelessWidget {
  const _AudioDial({required this.room});

  final LanternRoom room;

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode;
    final s = room.streamer;
    final speakers = s.affiliatedSpeakers.take(2).toList();
    return LayoutBuilder(builder: (context, box) {
      final compact = box.maxHeight < 230;
      final big = compact ? 54.0 : 76.0;
      return DecoratedBox(
          decoration: const BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF16404D), Color(0xFF0B1117)])),
          child: Stack(fit: StackFit.expand, children: [
            const LLattice(color: Color(0xFF5BB7D0), opacity: .1, step: 36),
            Center(
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 30, 16, 44),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            if (speakers.isNotEmpty) ...[
                              Opacity(
                                  opacity: .75,
                                  child: LAvatar(
                                      name: lang == 'ar'
                                          ? speakers.first.nameAr
                                          : speakers.first.nameEn,
                                      size: big * .72)),
                              const SizedBox(width: 12),
                            ],
                            LanternChannelAvatar(s, size: big),
                            if (speakers.length > 1) ...[
                              const SizedBox(width: 12),
                              Opacity(
                                  opacity: .75,
                                  child: LAvatar(
                                      name: lang == 'ar'
                                          ? speakers[1].nameAr
                                          : speakers[1].nameEn,
                                      size: big * .72)),
                            ],
                          ]),
                          SizedBox(height: compact ? 8 : 14),
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Text(s.getLocalizedTitle(lang),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Lantern.displayStyle(compact ? 15 : 18,
                                      color: LanternTokens.onNight,
                                      height: 1.4))),
                          SizedBox(height: compact ? 6 : 12),
                          LanternLiveWave(playing: room.playing),
                          SizedBox(height: compact ? 6 : 12),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0x800B1117),
                                  borderRadius: BorderRadius.circular(
                                      Lantern.radiusPill)),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const LIcon(LGlyph.moon,
                                        size: 14, color: LanternTokens.onNight),
                                    const SizedBox(width: 6),
                                    Text('lantern.room.background'.tr(),
                                        style: Lantern.textStyle(12.5,
                                            color: LanternTokens.onNight,
                                            weight: FontWeight.w500,
                                            height: 1.3)),
                                  ])),
                        ])))),
          ]));
    });
  }
}

/// A waveform that moves while the room plays and stills when it pauses or
/// ends. Drawn from a fixed pattern: the app has no audio level to show.
class LanternLiveWave extends StatefulWidget implements LanternSkinWidget {
  const LanternLiveWave({super.key, required this.playing});

  final bool playing;

  @override
  State<LanternLiveWave> createState() => _LanternLiveWaveState();
}

class _LanternLiveWaveState extends State<LanternLiveWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));

  void _sync() {
    if (widget.playing && !Lantern.calm(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(LanternLiveWave old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: SizedBox(
          width: 170,
          height: 30,
          child: CustomPaint(painter: _WavePainter(_c))));
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t) : super(repaint: t);

  final Animation<double> t;

  @override
  void paint(Canvas canvas, Size size) {
    const bars = 28;
    final step = size.width / bars;
    final paint = Paint()
      ..color = const Color(0xFF8FD3E6)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < bars; i++) {
      final still = .25 + .5 * (.5 + .5 * math.sin(i * 1.7));
      final h = t.isAnimating
          ? .2 +
              .8 *
                  (.5 +
                      .5 *
                          math.sin(2 * math.pi * t.value + i * .9) *
                          math.cos(i * .35))
          : still * .6;
      final x = step * (i + .5);
      final half = size.height * h.clamp(.12, 1.0) / 2;
      canvas.drawLine(Offset(x, size.height / 2 - half),
          Offset(x, size.height / 2 + half), paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => false;
}

/// Reactions that rise over the stage: five drawn icons in colour orbs
/// (heart, sparkles, bulb, flame, book) and the raised hand. They float for
/// 2.4 s. Under calm motion they show in place and fade.
class LanternReactions extends StatefulWidget implements LanternSkinWidget {
  const LanternReactions({super.key, required this.controller});

  final FloatingReactionsOverlayController controller;

  /// The drawing and the orb colour of each reaction the chat can send.
  static const kinds = <String, (LGlyph, Color)>{
    'heart': (LGlyph.heartfill, Color(0xFFC2343F)),
    'clap': (LGlyph.sparkles, Color(0xFFBD933F)),
    'idea': (LGlyph.bulb, Color(0xFF9A5B0E)),
    'fire': (LGlyph.flame, Color(0xFFB8501C)),
    'scholar': (LGlyph.book, Color(0xFF2D6F86)),
    'raise_hand': (LGlyph.hand, Color(0xFF4B3F96)),
  };

  static const maxOnScreen = 14;

  @override
  State<LanternReactions> createState() => _LanternReactionsState();
}

class _LanternReactionsState extends State<LanternReactions> {
  final _orbs = <({int id, String type, double x})>[];
  final _random = math.Random();
  int _next = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.listen(_spawn);
  }

  @override
  void didUpdateWidget(LanternReactions old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.listen(null);
      widget.controller.listen(_spawn);
    }
  }

  @override
  void dispose() {
    widget.controller.listen(null);
    super.dispose();
  }

  void _spawn(String type) {
    if (!mounted || _orbs.length >= LanternReactions.maxOnScreen) return;
    final id = _next++;
    setState(() => _orbs.add((
          id: id,
          type: LanternReactions.kinds.containsKey(type) ? type : 'heart',
          x: .1 + .8 * _random.nextDouble()
        )));
  }

  void _done(int id) {
    if (mounted) setState(() => _orbs.removeWhere((o) => o.id == id));
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
      child: ExcludeSemantics(
          child: LayoutBuilder(
              builder: (context, box) => Stack(children: [
                    for (final orb in _orbs)
                      _Orb(
                          key: ValueKey(orb.id),
                          kind: LanternReactions.kinds[orb.type]!,
                          left: (box.maxWidth - 40) * orb.x,
                          travel: math.min(210.0, box.maxHeight * .7),
                          onDone: () => _done(orb.id)),
                  ]))));
}

class _Orb extends StatefulWidget {
  const _Orb(
      {super.key,
      required this.kind,
      required this.left,
      required this.travel,
      required this.onDone});

  final (LGlyph, Color) kind;
  final double left, travel;
  final VoidCallback onDone;

  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final calm = Lantern.calm(context);
    return AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final v = _c.value;
          final opacity = v < .12 ? v / .12 : 1 - Curves.easeIn.transform(v);
          return Positioned(
              left: widget.left,
              bottom:
                  56 + (calm ? 0 : widget.travel * Curves.easeOut.transform(v)),
              child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.scale(
                      scale: calm ? 1 : .6 + .45 * v, child: child)));
        },
        child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: widget.kind.$2,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x66FFFFFF)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 10,
                      offset: Offset(0, 4))
                ]),
            child:
                LIcon(widget.kind.$1, size: 20, color: LanternTokens.white)));
  }
}
