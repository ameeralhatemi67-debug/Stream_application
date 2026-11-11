import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../discovery/presentation/lantern/lantern_stream_cards.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/chat_message_model.dart';
import '../../models/stream_privacy_models.dart';
import '../../services/live_chat_controller.dart';
import '../abstract_video_player.dart';
import '../widgets/floating_reactions_overlay.dart';
import 'lantern_room_chat.dart';
import 'lantern_room_stage.dart';

/// Everything a Lantern room draws and every action it can take. The screen
/// that owns the player, the chat and the recovery logic
/// (`LiveBroadcastScreen`) fills it in; the room widgets hold only what is
/// theirs to hold (which tab, an open menu).
@immutable
class LanternRoom {
  const LanternRoom({
    required this.streamId,
    required this.streamer,
    required this.audio,
    required this.viewers,
    required this.player,
    required this.state,
    required this.interrupted,
    required this.recovering,
    required this.recoveryAttempts,
    required this.playing,
    required this.muted,
    required this.fullscreen,
    required this.transport,
    required this.handRaised,
    required this.access,
    required this.following,
    required this.own,
    required this.replay,
    required this.chat,
    required this.chatTick,
    required this.chatText,
    required this.chatFocus,
    required this.chatScroll,
    required this.unread,
    required this.arrived,
    required this.reactions,
    required this.slidesUrl,
    required this.customArtwork,
    required this.onClose,
    required this.onMinimize,
    required this.onFollow,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onRetry,
    required this.onSend,
    required this.onToggleHand,
    required this.onReaction,
    required this.onScrollToNewest,
    required this.onSignIn,
    required this.onRetryMessage,
    required this.onMessageMenu,
    required this.onSender,
    required this.onOpenChannel,
    required this.onOpenSource,
    this.onStudio,
    this.onOpenInYouTube,
    this.onRequestJoin,
    this.onShare,
    this.onDirections,
    this.onReport,
  });

  final String streamId;
  final StreamerModel streamer;

  /// An audio room: the stage is the dial, not a picture.
  final bool audio;

  /// People in the room, counted by the platform; null until known.
  final int? viewers;

  /// The player itself, kept alive by the screen. Null when there is nothing
  /// valid to play.
  final Widget? player;
  final StreamState state;

  /// The broadcaster's feed stopped reaching the server ("we'll be right
  /// back"), and the viewer's own player trying again.
  final bool interrupted, recovering;
  final int recoveryAttempts;
  final bool playing, muted, fullscreen;

  /// Whether the player takes play, pause and mute from the app.
  final bool transport;
  final bool handRaised;
  final ViewerAccessState access;
  final bool following, own;

  /// A recording: the chat is there to read, not to write in.
  final bool replay;
  final LiveChatController chat;

  /// Fires when the chat changes, so only the chat rebuilds.
  final Listenable chatTick;
  final TextEditingController chatText;
  final FocusNode chatFocus;
  final ScrollController chatScroll;
  final int unread;

  /// Whether a message has just arrived and should rise in.
  final bool Function(String messageId) arrived;
  final FloatingReactionsOverlayController reactions;
  final String slidesUrl;
  final String? customArtwork;

  final VoidCallback onClose,
      onMinimize,
      onFollow,
      onTogglePlay,
      onToggleMute,
      onToggleFullscreen,
      onRetry,
      onSend,
      onToggleHand,
      onScrollToNewest,
      onSignIn,
      onOpenChannel,
      onOpenSource;
  final void Function(String type) onReaction;
  final void Function(String messageId) onRetryMessage;
  final void Function(ChatMessageModel message) onMessageMenu, onSender;
  final VoidCallback? onStudio,
      onOpenInYouTube,
      onRequestJoin,
      onShare,
      onDirections;

  /// Report this broadcast to the platform's admins. Null on one's own.
  final VoidCallback? onReport;

  bool get live => streamer.isLiveForRoom && !interrupted;
}

/// A live or audio room in Lantern and Arch (owner decisions, 2026-11-10):
/// full screen, always night, exactly one screen tall. Nothing scrolls but
/// the chat. No app header, footer or navigation: leave with the close button
/// in the top corner or keep the room in the corner player.
///
/// Phone and laptop share the layout. From 1024 px the stage sits beside a
/// 400 px chat column and the top bar shows its actions as buttons; below
/// that the stage is on top (at most 45% of the screen), a one-line title
/// follows, and the chat takes the rest.
class LanternRoomView extends StatelessWidget implements LanternSkinWidget {
  const LanternRoomView({super.key, required this.room});

  final LanternRoom room;

  @override
  Widget build(BuildContext context) => LanternSurface(
      night: true,
      child: Builder(builder: (context) {
        final t = context.lt;
        final wide = context.lanternWide;
        final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
        final stage = LanternRoomStage(room: room);
        if (room.fullscreen) {
          return Scaffold(
              backgroundColor: LanternTokens.nightGround,
              body: SafeArea(child: Center(child: stage)));
        }
        final chat = LanternRoomChat(room: room);
        return Scaffold(
            key: const ValueKey('lantern-room'),
            backgroundColor: t.bg,
            // The chat's composer rides above the keyboard.
            resizeToAvoidBottomInset: true,
            body: SafeArea(
                child: wide
                    ? Row(children: [
                        Expanded(
                            child: Column(children: [
                          _TopBar(room: room, wide: true),
                          Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  // The largest 16:9 box that fits.
                                  child: LayoutBuilder(builder: (context, box) {
                                    final width = box.maxWidth <
                                            box.maxHeight * 16 / 9
                                        ? box.maxWidth
                                        : box.maxHeight * 16 / 9;
                                    return Center(
                                        child: SizedBox(
                                            width: width,
                                            height: width * 9 / 16,
                                            child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        Lantern.radiusCard),
                                                child: stage)));
                                  }))),
                          _TitleRow(room: room, wide: true),
                        ])),
                        Container(width: 1, color: t.line),
                        SizedBox(width: Lantern.sideChat, child: chat),
                      ])
                    : LayoutBuilder(
                        builder: (context, box) => Column(children: [
                              _TopBar(room: room, wide: false),
                              ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxHeight: box.maxHeight *
                                          (keyboard ? .25 : .45)),
                                  child: stage),
                              if (!keyboard) _TitleRow(room: room, wide: false),
                              Expanded(child: chat),
                            ]))));
      }));
}

/// Close, who is broadcasting, the state and the count, Follow, then the
/// room's actions. On a phone the actions fold into More.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.room, required this.wide});

  final LanternRoom room;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = room.streamer;
    final name = s.getLocalizedName(lang);
    final followLabel =
        (room.following ? 'profile.following_btn' : 'web.follow').tr();
    void about() => _showAbout(context, room);
    return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.line))),
        child: Row(children: [
          LIconButton(
              key: const ValueKey('lantern-room-close'),
              icon: LGlyph.close,
              label: 'lantern.room.leave'.tr(),
              iconSize: 22,
              onPressed: room.onClose),
          const SizedBox(width: 4),
          Expanded(
              child: LPressable(
                  onTap: room.onOpenChannel,
                  label: 'lantern.discover.open_channel'.tr(args: [name]),
                  radius: 14,
                  pressScale: 1,
                  excludeChildSemantics: true,
                  builder: (context, _) => Row(children: [
                        LanternChannelAvatar(s, size: 38),
                        const SizedBox(width: 10),
                        Flexible(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Lantern.textStyle(14.5,
                                      color: t.fg,
                                      weight: FontWeight.w700,
                                      height: 1.35)),
                              const SizedBox(height: 2),
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                LanternRoomStateBadge(room: room, small: true),
                                if (wide && room.live) ...[
                                  const SizedBox(width: 8),
                                  Flexible(
                                      child: Text(
                                          '${lanternCount(room.viewers)} ${(room.audio ? 'web.listening' : 'web.watching').tr()}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Lantern.textStyle(12,
                                                  color: t.muted, height: 1.3)
                                              .copyWith(
                                                  fontFeatures:
                                                      Lantern.tabular))),
                                ],
                              ]),
                            ])),
                      ]))),
          if (wide) ...[
            if (!room.own)
              LButton(
                  label: followLabel,
                  icon: room.following ? LGlyph.check : LGlyph.plus,
                  kind: LButtonKind.tonal,
                  size: LButtonSize.small,
                  onPressed: room.onFollow),
            const SizedBox(width: 8),
            LIconButton(
                icon: LGlyph.info, label: 'web.about'.tr(), onPressed: about),
            if (room.onShare != null)
              LIconButton(
                  icon: LGlyph.share,
                  label: 'lantern.room.share'.tr(),
                  onPressed: room.onShare),
            if (room.onReport != null)
              LIconButton(
                  key: const ValueKey('lantern-room-report'),
                  icon: LGlyph.flag,
                  label: 'lantern.report.action_stream'.tr(),
                  onPressed: room.onReport),
            if (room.onStudio != null) ...[
              const SizedBox(width: 4),
              LButton(
                  label: 'lantern.room.studio'.tr(),
                  icon: LGlyph.settings,
                  kind: LButtonKind.tonal,
                  size: LButtonSize.small,
                  onPressed: room.onStudio),
            ],
          ] else
            _More(room: room, followLabel: followLabel, onAbout: about),
          LIconButton(
              key: const ValueKey('lantern-room-corner'),
              icon: LGlyph.pip,
              label: 'web.minimize'.tr(),
              onPressed: room.onMinimize),
        ]));
  }
}

/// The phone's More menu: what the laptop shows as buttons.
class _More extends StatelessWidget {
  const _More(
      {required this.room, required this.followLabel, required this.onAbout});

  final LanternRoom room;
  final String followLabel;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    PopupMenuItem<VoidCallback> item(
            LGlyph glyph, String label, VoidCallback action) =>
        PopupMenuItem(
            value: action,
            child: Row(children: [
              LIcon(glyph, size: 18, color: t.fg),
              const SizedBox(width: 12),
              Flexible(child: Text(label)),
            ]));
    return PopupMenuButton<VoidCallback>(
        tooltip: 'lantern.room.more'.tr(),
        onSelected: (action) => action(),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
              if (!room.own)
                item(room.following ? LGlyph.check : LGlyph.plus, followLabel,
                    room.onFollow),
              item(LGlyph.info, 'web.about'.tr(), onAbout),
              if (room.onShare != null)
                item(LGlyph.share, 'lantern.room.share'.tr(), room.onShare!),
              if (room.onStudio != null)
                item(LGlyph.settings, 'lantern.room.studio'.tr(),
                    room.onStudio!),
              if (room.onReport != null)
                item(LGlyph.flag, 'lantern.report.action_stream'.tr(),
                    room.onReport!),
            ],
        child: SizedBox.square(
            dimension: Lantern.target,
            child: Center(
                child: LIcon(LGlyph.more,
                    size: 22,
                    color: t.fg,
                    label: 'lantern.room.more'.tr()))));
  }
}

/// One line under the stage: the title and where it is held. The full
/// description is under About.
class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.room, required this.wide});

  final LanternRoom room;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final venue = room.streamer.getLocalizedVenue(lang);
    return Padding(
        padding:
            EdgeInsets.symmetric(horizontal: 16, vertical: wide ? 14 : 10),
        child: Row(children: [
          Flexible(
              child: Semantics(
                  header: true,
                  child: Text(room.streamer.getLocalizedTitle(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Lantern.displayStyle(wide ? 18 : 15.5,
                          color: t.fg, height: 1.4)))),
          if (venue.isNotEmpty && wide) ...[
            const SizedBox(width: 14),
            LIcon(LGlyph.pin, size: 15, color: t.muted),
            const SizedBox(width: 5),
            Flexible(
                child: Text(venue,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        Lantern.textStyle(13, color: t.muted, height: 1.4))),
          ],
        ]));
  }
}

void _showAbout(BuildContext context, LanternRoom room) {
  final lang = context.locale.languageCode;
  final s = room.streamer;
  showLanternSheet<void>(context,
      title: 'web.about'.tr(),
      night: true,
      body: (context) {
        final t = context.lt;
        final bio = s.getLocalizedBio(lang);
        final venue = [s.getLocalizedVenue(lang), s.getLocalizedCity(lang)]
            .where((v) => v.isNotEmpty)
            .join(' · ');
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                LanternChannelAvatar(s, size: 52),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(s.getLocalizedName(lang),
                          style: Lantern.textStyle(16,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.4)),
                      Text(s.getLocalizedOrganization(lang),
                          style: Lantern.textStyle(13, color: t.muted)),
                    ])),
              ]),
              const SizedBox(height: 14),
              Text(s.getLocalizedTitle(lang),
                  style: Lantern.displayStyle(17,
                      color: t.fg,
                      height: context.lanternArabic ? 1.5 : 1.3)),
              if (bio.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(bio, style: Lantern.textStyle(14.5, color: t.muted)),
              ],
              if (venue.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  LIcon(LGlyph.pin, size: 16, color: t.goldInk),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(venue,
                          style: Lantern.textStyle(13.5, color: t.fg))),
                ]),
              ],
              const SizedBox(height: 18),
              LButton(
                  label: 'lantern.room.open_channel'.tr(),
                  icon: LGlyph.person,
                  kind: LButtonKind.tonal,
                  expand: true,
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    room.onOpenChannel();
                  }),
            ]);
      });
}

/// A room that cannot or no longer plays anything: ended, not found, the
/// connection gave up, not started yet. Night, with the arch and one way on.
class LanternRoomStatus extends StatelessWidget implements LanternSkinWidget {
  const LanternRoomStatus(
      {super.key,
      required this.title,
      required this.body,
      this.icon = LGlyph.videooff,
      this.onRetry,
      this.retryLabel,
      this.busy = false});

  final String title, body;
  final LGlyph icon;
  final VoidCallback? onRetry;
  final String? retryLabel;

  /// Still trying: the star turns in place of the icon.
  final bool busy;

  @override
  Widget build(BuildContext context) => LanternSurface(
      night: true,
      child: Builder(builder: (context) {
        final t = context.lt;
        return Scaffold(
            backgroundColor: t.bg,
            body: SafeArea(
                child: Stack(children: [
              const LLattice(opacity: .07),
              PositionedDirectional(
                  top: 10,
                  start: 8,
                  child: LIconButton(
                      icon: LGlyph.close,
                      label: 'lantern.room.leave'.tr(),
                      iconSize: 22,
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/feed'))),
              Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Semantics(
                          liveRegion: true,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (busy)
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 8),
                                      child: LStarLoader(size: 34))
                                else
                                  LEmptyState(
                                      title: title,
                                      body: body,
                                      icon: icon,
                                      compact: true),
                                if (busy) ...[
                                  Text(title,
                                      textAlign: TextAlign.center,
                                      style: Lantern.textStyle(15.5,
                                          color: t.fg,
                                          weight: FontWeight.w600)),
                                  const SizedBox(height: 6),
                                  ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 420),
                                      child: Text(body,
                                          textAlign: TextAlign.center,
                                          style: Lantern.textStyle(13.5,
                                              color: t.muted))),
                                ],
                                const SizedBox(height: 14),
                                Wrap(spacing: 10, runSpacing: 10, children: [
                                  if (onRetry != null)
                                    LButton(
                                        label: retryLabel ??
                                            'live.retry_feed'.tr(),
                                        icon: LGlyph.refresh,
                                        onPressed: onRetry),
                                  LButton(
                                      label: 'web.nav_discover'.tr(),
                                      kind: LButtonKind.secondary,
                                      onPressed: () => context.go('/feed')),
                                ]),
                              ])))),
            ])));
      }));
}

/// A link that matches more than one show: choose which to open.
class LanternRoomChoices extends StatelessWidget implements LanternSkinWidget {
  const LanternRoomChoices(
      {super.key,
      required this.title,
      required this.choices,
      required this.onChoose});

  final String title;

  /// Each show's id and title.
  final List<(String, String)> choices;
  final void Function(String id) onChoose;

  @override
  Widget build(BuildContext context) => LanternSurface(
      night: true,
      child: Builder(builder: (context) {
        final t = context.lt;
        return Scaffold(
            backgroundColor: t.bg,
            appBar: LanternPageBar(title: title),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              for (final (id, name) in choices)
                Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LRow(
                        title: name,
                        icon: LGlyph.play,
                        onTap: () => onChoose(id))),
            ]));
      }));
}
