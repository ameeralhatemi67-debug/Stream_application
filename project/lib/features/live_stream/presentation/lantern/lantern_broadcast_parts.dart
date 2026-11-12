import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// The phone broadcaster's picture while the camera is off (audio only), in
/// Lantern and Arch: the night ground with the lattice of the opening screen,
/// faded out behind the middle, and there the microphone's live level with
/// its state in words under it.
class LanternBroadcastAudioStage extends StatelessWidget
    implements LanternSkinWidget {
  const LanternBroadcastAudioStage(
      {super.key, required this.level, required this.muted});

  /// 0 to 1 while the encoder reports it; null before (not live yet).
  final ValueListenable<double?> level;
  final bool muted;

  @override
  Widget build(BuildContext context) => LanternSurface(
      night: true,
      child: ColoredBox(
          key: const ValueKey('lantern-broadcast-audio-stage'),
          color: LanternTokens.nightGround,
          child: Stack(fit: StackFit.expand, children: [
            const DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(radius: .85, colors: [
              Color(0x33BD933F),
              Color(0x00BD933F),
            ]))),
            // The pattern stays at the edges and fades out behind the meter,
            // so the middle reads clearly.
            ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) =>
                    const RadialGradient(radius: .8, colors: [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xFF000000),
                    ], stops: [
                      0,
                      .32,
                      1
                    ]).createShader(bounds),
                child: const Stack(fit: StackFit.expand, children: [
                  LLattice(opacity: .2, step: 44),
                ])),
            Center(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 96),
                    child: _MicLevel(level: level, muted: muted))),
          ])));
}

/// The live level: a medallion that swells with the voice, the last few
/// seconds as bars beneath it, and the microphone's state in words.
class _MicLevel extends StatefulWidget {
  const _MicLevel({required this.level, required this.muted});

  final ValueListenable<double?> level;
  final bool muted;

  @override
  State<_MicLevel> createState() => _MicLevelState();
}

class _MicLevelState extends State<_MicLevel> {
  static const _bars = 28;
  final List<double> _history = List.filled(_bars, 0, growable: true);

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_sample);
  }

  @override
  void didUpdateWidget(_MicLevel old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level) {
      old.level.removeListener(_sample);
      widget.level.addListener(_sample);
    }
  }

  @override
  void dispose() {
    widget.level.removeListener(_sample);
    super.dispose();
  }

  void _sample() {
    if (!mounted) return;
    setState(() {
      _history
        ..removeAt(0)
        ..add(widget.muted ? 0 : (widget.level.value ?? 0));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final muted = widget.muted;
    final value = muted ? 0.0 : (widget.level.value ?? 0);
    final waiting = !muted && widget.level.value == null;
    final calm = Lantern.calm(context);
    final status = muted
        ? 'lantern.broadcaster.mic_off'.tr()
        : waiting
            ? 'lantern.broadcaster.level_waiting'.tr()
            : 'lantern.broadcaster.mic_on'.tr();
    return Semantics(
        container: true,
        liveRegion: true,
        label: '${'live_studio.audio_only_title'.tr()}, $status',
        child: ExcludeSemantics(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              width: 200,
              height: 200,
              child: Stack(alignment: Alignment.center, children: [
                // The halo follows the voice.
                AnimatedContainer(
                    duration:
                        calm ? Lantern.none : const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    width: 120 + 80 * value,
                    height: 120 + 80 * value,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (muted ? t.live : LanternTokens.gold)
                            .withValues(alpha: .10 + .14 * value),
                        border: Border.all(
                            color: (muted ? t.live : LanternTokens.gold)
                                .withValues(alpha: .25 + .45 * value),
                            width: 1.5))),
                Container(
                    key: const ValueKey('lantern-broadcast-mic'),
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: muted ? null : Lantern.goldFill,
                        color: muted ? LanternTokens.liveFill : null,
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 24,
                              spreadRadius: -6,
                              offset: Offset(0, 10)),
                        ]),
                    alignment: Alignment.center,
                    child: LIcon(muted ? LGlyph.micoff : LGlyph.mic,
                        size: 44,
                        color: muted
                            ? LanternTokens.white
                            : LanternTokens.onGold)),
              ])),
          const SizedBox(height: 12),
          Text('live_studio.audio_only_title'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.displayStyle(22,
                  color: LanternTokens.onNight,
                  height: context.lanternArabic ? 1.45 : 1.25)),
          const SizedBox(height: 16),
          SizedBox(
              key: const ValueKey('lantern-broadcast-level'),
              width: 240,
              height: 44,
              child: CustomPaint(
                  painter: _Bars(
                      levels: List.of(_history),
                      color: muted ? t.line : LanternTokens.goldHi,
                      rest: LanternTokens.onNight.withValues(alpha: .18)))),
          const SizedBox(height: 14),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (muted) ...[
              const LIcon(LGlyph.micoff, size: 18, color: Color(0xFFFF8A8F)),
              const SizedBox(width: 6),
            ],
            Flexible(
                child: Text(status,
                    key: const ValueKey('lantern-broadcast-mic-status'),
                    textAlign: TextAlign.center,
                    style: Lantern.textStyle(muted ? 15 : 14,
                        // A light red that passes on the night ground.
                        color: muted
                            ? const Color(0xFFFF8A8F)
                            : LanternTokens.onNight.withValues(alpha: .78),
                        weight: muted ? FontWeight.w700 : FontWeight.w500,
                        height: 1.4))),
          ]),
        ])));
  }
}

/// The last few seconds of the level, newest on the right, drawn from the
/// middle line up and down.
class _Bars extends CustomPainter {
  const _Bars({required this.levels, required this.color, required this.rest});

  final List<double> levels;
  final Color color, rest;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty) return;
    const gap = 3.0;
    final width =
        math.max(2.0, (size.width - gap * (levels.length - 1)) / levels.length);
    final mid = size.height / 2;
    for (var i = 0; i < levels.length; i++) {
      final level = levels[i].clamp(0.0, 1.0);
      final half = math.max(2.0, level * size.height / 2);
      final x = i * (width + gap);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, mid - half, width, half * 2),
              Radius.circular(width / 2)),
          Paint()..color = level < .04 ? rest : color);
    }
  }

  @override
  bool shouldRepaint(_Bars old) =>
      old.color != color || old.rest != rest || !listEquals(old.levels, levels);
}

/// One row of the broadcaster's tools: a switch.
typedef LanternBroadcastToggle = ({
  bool value,
  ValueChanged<bool>? onChanged,
});

/// The broadcaster's quick tools in Lantern and Arch, as a sheet body: the
/// state of the broadcast, then sound and picture, what shows on this
/// screen, the broadcast's own settings, and End. Every switch reads "on"
/// as the thing being on (the microphone, the camera, the chat).
class LanternBroadcastTools extends StatelessWidget
    implements LanternSkinWidget {
  const LanternBroadcastTools(
      {super.key,
      required this.status,
      required this.live,
      required this.mic,
      required this.camera,
      required this.chat,
      required this.onFrontCamera,
      required this.languageName,
      required this.onLanguage,
      required this.onEnd,
      this.hideReplay,
      this.attendees});

  /// "Live · 2555 kbit/s", or the connection's state.
  final String status;
  final bool live;
  final LanternBroadcastToggle mic, camera, chat;

  /// Null when this broadcast has no server session (nothing to hide).
  final LanternBroadcastToggle? hideReplay;

  /// A private broadcast's attendees: title, the queue line, open.
  final (String, String, VoidCallback)? attendees;
  final VoidCallback onFrontCamera, onLanguage, onEnd;
  final String languageName;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget group(String title) => Padding(
        padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8, top: 18),
        child: Text(title,
            style: Lantern.textStyle(13,
                color: t.muted, weight: FontWeight.w600, height: 1.3)));
    Widget gap() => const SizedBox(height: 8);
    LSwitch toggle(LanternBroadcastToggle row, String label) =>
        LSwitch(value: row.value, onChanged: row.onChanged, label: label);
    return Column(
        key: const ValueKey('lantern-broadcast-tools'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: live
                  ? LBadge(status,
                      key: const ValueKey('lantern-broadcast-status'),
                      kind: LBadgeKind.live)
                  : LTag(status,
                      key: const ValueKey('lantern-broadcast-status'),
                      tone: LTone.warn,
                      icon: LGlyph.signal)),
          group('lantern.broadcaster.group_sound'.tr()),
          LRow(
              key: const ValueKey('lantern-broadcast-mic-row'),
              icon: mic.value ? LGlyph.mic : LGlyph.micoff,
              danger: !mic.value,
              title: 'lantern.broadcaster.mic'.tr(),
              subtitle: (mic.value
                      ? 'lantern.broadcaster.mic_on'
                      : 'lantern.broadcaster.mic_off')
                  .tr(),
              arrow: false,
              trailing: toggle(mic, 'lantern.broadcaster.mic'.tr()),
              onTap: mic.onChanged == null
                  ? null
                  : () => mic.onChanged!(!mic.value)),
          gap(),
          LRow(
              key: const ValueKey('lantern-broadcast-camera-row'),
              icon: camera.value ? LGlyph.video : LGlyph.videooff,
              title: 'lantern.broadcaster.camera'.tr(),
              subtitle: (camera.value
                      ? 'lantern.broadcaster.camera_on'
                      : 'lantern.broadcaster.camera_off')
                  .tr(),
              arrow: false,
              trailing: toggle(camera, 'lantern.broadcaster.camera'.tr()),
              onTap: camera.onChanged == null
                  ? null
                  : () => camera.onChanged!(!camera.value)),
          gap(),
          LRow(
              key: const ValueKey('lantern-broadcast-front-camera'),
              icon: LGlyph.flip,
              title: 'live.front_camera_coming_soon'.tr(),
              subtitle: 'live.ctrl_back_active_sub'.tr(),
              arrow: false,
              trailing: LTag('lantern.apply.soon'.tr(), tone: LTone.warn),
              onTap: onFrontCamera),
          group('lantern.broadcaster.group_screen'.tr()),
          LRow(
              key: const ValueKey('lantern-broadcast-chat-row'),
              icon: LGlyph.chat,
              title: 'lantern.broadcaster.chat'.tr(),
              subtitle: (chat.value
                      ? 'lantern.broadcaster.chat_on'
                      : 'lantern.broadcaster.chat_off')
                  .tr(),
              arrow: false,
              trailing: toggle(chat, 'lantern.broadcaster.chat'.tr()),
              onTap: chat.onChanged == null
                  ? null
                  : () => chat.onChanged!(!chat.value)),
          gap(),
          LRow(
              key: const ValueKey('lantern-broadcast-language'),
              icon: LGlyph.translate,
              title: 'language.switch_lang'.tr(),
              subtitle: languageName,
              onTap: onLanguage),
          if (hideReplay != null || attendees != null)
            group('lantern.broadcaster.group_broadcast'.tr()),
          if (hideReplay != null)
            LRow(
                key: const ValueKey('phone-hide-replay'),
                icon: hideReplay!.value ? LGlyph.eyeoff : LGlyph.eye,
                title: 'live.hide_replay'.tr(),
                subtitle: 'live.hide_replay_sub'.tr(),
                arrow: false,
                trailing: toggle(hideReplay!, 'live.hide_replay'.tr()),
                onTap: hideReplay!.onChanged == null
                    ? null
                    : () => hideReplay!.onChanged!(!hideReplay!.value)),
          if (hideReplay != null && attendees != null) gap(),
          if (attendees != null)
            LRow(
                key: const ValueKey('lantern-broadcast-attendees'),
                icon: LGlyph.users,
                title: attendees!.$1,
                subtitle: attendees!.$2,
                onTap: attendees!.$3),
          const SizedBox(height: 22),
          LButton(
              key: const ValueKey('lantern-broadcast-end'),
              label: 'live.end_broadcast'.tr(),
              icon: LGlyph.stop,
              kind: LButtonKind.danger,
              expand: true,
              onPressed: onEnd),
          const SizedBox(height: 8),
          Text('live.ctrl_end_sub'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.textStyle(12.5, color: t.muted, height: 1.4)),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ]);
  }
}
