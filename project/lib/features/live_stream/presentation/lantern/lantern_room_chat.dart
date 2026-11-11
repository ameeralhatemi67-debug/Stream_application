import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../models/chat_message_model.dart';
import '../../services/live_chat_controller.dart';
import '../widgets/floating_reactions_overlay.dart';
import '../widgets/live_chat_layout.dart';
import 'lantern_room_stage.dart';
import 'lantern_room_view.dart';

/// The room's chat column: a heading with the connection, three tabs (chat,
/// sources, venue), and under Chat the notices, the messages (the only thing
/// in the room that scrolls) and the composer pinned at the bottom.
class LanternRoomChat extends StatefulWidget implements LanternSkinWidget {
  const LanternRoomChat({super.key, required this.room});

  final LanternRoom room;

  @override
  State<LanternRoomChat> createState() => _LanternRoomChatState();
}

class _LanternRoomChatState extends State<LanternRoomChat> {
  int _tab = 0;
  bool _reactionsOpen = false;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final room = widget.room;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return ColoredBox(
        color: t.bg,
        child: Column(children: [
          if (!keyboard)
            Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 8),
                child: Row(children: [
                  Expanded(
                      child: Semantics(
                          header: true,
                          child: Text('lantern.room.chat_title'.tr(),
                              style: Lantern.displayStyle(16,
                                  color: t.fg, height: 1.4)))),
                  ListenableBuilder(
                      listenable: room.chatTick,
                      builder: (context, _) =>
                          _Connection(room.chat.connectionState)),
                ])),
          if (!keyboard)
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: LSegmented<int>(
                    expand: true,
                    dense: true,
                    value: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                    segments: [
                      (value: 0, label: 'live.tab_chat'.tr(), icon: null),
                      (value: 1, label: 'live.tab_sources'.tr(), icon: null),
                      (value: 2, label: 'live.tab_venue'.tr(), icon: null),
                    ])),
          Expanded(
              child: switch (_tab) {
            1 => _Sources(room: room),
            2 => _Venue(room: room),
            _ => ListenableBuilder(
                listenable: room.chatTick,
                builder: (context, _) => _ChatTab(
                    room: room,
                    reactionsOpen: _reactionsOpen,
                    onToggleReactions: () =>
                        setState(() => _reactionsOpen = !_reactionsOpen),
                    onReaction: (type) {
                      setState(() => _reactionsOpen = false);
                      room.onReaction(type);
                    })),
          }),
        ]));
  }
}

class _Connection extends StatelessWidget {
  const _Connection(this.state);

  final ChatConnectionState state;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final (color, label) = switch (state) {
      ChatConnectionState.live => (t.ok, 'live.chat_status_live'.tr()),
      ChatConnectionState.connecting => (
          t.warn,
          'live.chat_status_connecting'.tr()
        ),
      ChatConnectionState.reconnecting => (
          t.live,
          'live.chat_status_reconnecting'.tr()
        ),
    };
    return Semantics(
        liveRegion: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: Lantern.textStyle(12,
                  color: t.muted, weight: FontWeight.w600, height: 1.3)),
        ]));
  }
}

class _ChatTab extends StatelessWidget {
  const _ChatTab(
      {required this.room,
      required this.reactionsOpen,
      required this.onToggleReactions,
      required this.onReaction});

  final LanternRoom room;
  final bool reactionsOpen;
  final VoidCallback onToggleReactions;
  final void Function(String type) onReaction;

  @override
  Widget build(BuildContext context) {
    final chat = room.chat;
    final messages = chat.messagesNewestFirst;
    final offline = chat.connectionState == ChatConnectionState.reconnecting;
    return LayoutBuilder(
        builder: (context, box) => Stack(children: [
              Column(children: [
                // Notices never take more than a third of the column.
                ConstrainedBox(
                    constraints:
                        BoxConstraints(maxHeight: box.maxHeight * .35),
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          if (offline)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: LBanner(
                                    'live.chat_unavailable_banner'.tr(),
                                    tone: LTone.warn,
                                    icon: LGlyph.wifioff)),
                          if (chat.canModerate)
                            for (final alert in chat.moderationAlerts)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: LBanner(
                                      'live.moderation_alert_message'
                                          .tr(namedArgs: {
                                        'name': alert.senderName,
                                        'count': '${alert.count}'
                                      }),
                                      tone: LTone.warn,
                                      action: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LButton(
                                                label:
                                                    'live.moderation_alert_quick_mute'
                                                        .tr(),
                                                kind: LButtonKind.danger,
                                                size: LButtonSize.small,
                                                onPressed: () =>
                                                    chat.quickMuteFromAlert(
                                                        alert.senderId)),
                                            LIconButton(
                                                icon: LGlyph.close,
                                                label: MaterialLocalizations.of(
                                                        context)
                                                    .closeButtonLabel,
                                                size: 36,
                                                iconSize: 16,
                                                onPressed: () =>
                                                    chat.dismissModerationAlert(
                                                        alert.senderId)),
                                          ]))),
                          if (chat.slowModeSeconds > 0 && chat.chatEnabled)
                            Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: LBanner(
                                    'live.chat_slow_mode_active'
                                        .plural(chat.slowModeSeconds),
                                    icon: LGlyph.clock)),
                        ]))),
                Expanded(
                    child: messages.isEmpty
                        ? _Empty(guest: chat.isGuest)
                        : Stack(children: [
                            ListView.builder(
                                key: const ValueKey('lantern-room-messages'),
                                controller: room.chatScroll,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                                itemCount: messages.length,
                                itemBuilder: (context, i) => _Message(
                                    key: ValueKey(messages[i].id),
                                    room: room,
                                    message: messages[i],
                                    showIdentity: i + 1 >= messages.length ||
                                        messages[i + 1].senderId !=
                                            messages[i].senderId)),
                            if (room.unread > 0)
                              PositionedDirectional(
                                  start: 0,
                                  end: 0,
                                  bottom: 8,
                                  child: Center(
                                      child: LButton(
                                          label:
                                              '${'live.chat_new_messages_pill'.tr()} (${room.unread})',
                                          size: LButtonSize.small,
                                          onPressed: room.onScrollToNewest))),
                          ])),
                ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: box.maxHeight *
                            (MediaQuery.viewInsetsOf(context).bottom > 0
                                ? .7
                                : .45)),
                    child: SingleChildScrollView(
                        child: _Composer(
                            room: room,
                            reactionsOpen: reactionsOpen,
                            onToggleReactions: onToggleReactions))),
              ]),
              if (reactionsOpen)
                PositionedDirectional(
                    bottom: 66,
                    end: 12,
                    child: _ReactionMenu(onReaction: onReaction)),
            ]));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.guest});

  final bool guest;

  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          child: LEmptyState(
              title: 'live.chat_empty_title'.tr(),
              body: (guest
                      ? 'live.chat_empty_subtitle_guest'
                      : 'live.chat_empty_subtitle')
                  .tr(),
              icon: LGlyph.chat,
              compact: true)));
}

/// The words a role carries in chat: a chip, not only a ring colour.
class LanternRoleChip extends StatelessWidget implements LanternSkinWidget {
  const LanternRoleChip(this.badge, {super.key});

  final ChatSenderBadge badge;

  @override
  Widget build(BuildContext context) {
    final label = context.lanternArabic ? badge.labelAr : badge.labelEn;
    return switch (badge) {
      ChatSenderBadge.speaker =>
        LTag(label, tone: LTone.live, icon: LGlyph.mic),
      ChatSenderBadge.organization =>
        LTag(label, icon: LGlyph.org, outlined: true),
      ChatSenderBadge.admin =>
        LTag(label, tone: LTone.gold, icon: LGlyph.shield, outlined: true),
      ChatSenderBadge.moderator =>
        LTag(label, tone: LTone.mod, icon: LGlyph.shield),
      ChatSenderBadge.verified =>
        LTag(label, tone: LTone.gold, icon: LGlyph.verified),
    };
  }
}

/// One chat message: the sender's avatar, name and role chips, then the text
/// in a soft bubble. A new message rises in. Press and hold (or the menu
/// button with a pointer) for its actions; the avatar opens the sender.
class _Message extends StatelessWidget {
  const _Message(
      {super.key,
      required this.room,
      required this.message,
      required this.showIdentity});

  final LanternRoom room;
  final ChatMessageModel message;
  final bool showIdentity;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final m = message;
    final raised = m.body == raisedHandGlyph;
    final lowered = m.body == loweredHandGlyph;
    final text = raised
        ? 'live.hand_raised_message'.tr()
        : lowered
            ? 'live.hand_lowered_message'.tr()
            : m.body;
    final ring = m.badges.contains(ChatSenderBadge.speaker)
        ? LRing.live
        : m.badges.contains(ChatSenderBadge.admin)
            ? LRing.admin
            : m.badges.contains(ChatSenderBadge.moderator)
                ? LRing.mod
                : LRing.none;
    Widget tile = Padding(
        padding: EdgeInsets.only(bottom: 8, top: showIdentity ? 6 : 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 42,
              child: showIdentity
                  ? LPressable(
                      onTap: () => room.onSender(m),
                      label: m.senderName,
                      radius: 22,
                      pressScale: .95,
                      excludeChildSemantics: true,
                      builder: (context, _) => LAvatar(
                          name: m.senderName,
                          image: resolveImageProviderOrNull(m.senderAvatarUrl),
                          size: ring == LRing.none ? 34 : 30,
                          ring: ring))
                  : null),
          const SizedBox(width: 6),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                if (showIdentity)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(m.senderName,
                                style: Lantern.textStyle(12.5,
                                    color: m.isCurrentUser ? t.goldInk : t.muted,
                                    weight: FontWeight.w700,
                                    height: 1.3)),
                            for (final badge in m.badges)
                              LanternRoleChip(badge),
                          ])),
                Semantics(
                    onLongPress: () => room.onMessageMenu(m),
                    child: GestureDetector(
                        onLongPress: () => room.onMessageMenu(m),
                        onSecondaryTap: () => room.onMessageMenu(m),
                        child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            decoration: BoxDecoration(
                                color: raised ? t.warnSoft : t.surface,
                                borderRadius:
                                    BorderRadius.circular(Lantern.radiusField),
                                border: Border.all(
                                    color: m.isCurrentUser
                                        ? LanternTokens.gold
                                            .withValues(alpha: .55)
                                        : t.line)),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (raised || lowered) ...[
                                    LIcon(LGlyph.hand,
                                        size: 16,
                                        color: raised ? t.warn : t.muted),
                                    const SizedBox(width: 6),
                                  ],
                                  Flexible(
                                      child: Text.rich(
                                          TextSpan(text: text, children: [
                                            if (m.isEdited)
                                              TextSpan(
                                                  text:
                                                      ' ${'live.message_edited_badge'.tr()}',
                                                  style: Lantern.textStyle(12,
                                                      color: t.muted)),
                                            if (m.isPending)
                                              TextSpan(
                                                  text:
                                                      '  ${'live.chat_status_connecting'.tr()}',
                                                  style: Lantern.textStyle(12,
                                                      color: t.muted)),
                                          ]),
                                          style: Lantern.textStyle(14.5,
                                              color: raised ? t.warn : t.fg,
                                              height: 1.5))),
                                ])))),
              ])),
          if (context.lanternWide)
            LIconButton(
                icon: LGlyph.more,
                label: 'lantern.room.message_actions'.tr(),
                size: 34,
                iconSize: 16,
                color: t.muted,
                onPressed: () => room.onMessageMenu(m)),
        ]));
    if (room.arrived(m.id) && !Lantern.calm(context)) {
      tile = TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Lantern.enter,
          curve: Lantern.ease,
          builder: (context, v, child) => Opacity(
              opacity: v,
              child: Transform.translate(
                  offset: Offset(0, 14 * (1 - v)), child: child)),
          child: tile);
    }
    if (!m.isFailed) return tile;
    // A refused send stays on screen with the server's reason, and Retry
    // only where a second try could work.
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Opacity(opacity: .6, child: tile),
      Padding(
          padding: const EdgeInsetsDirectional.only(start: 48, bottom: 6),
          child: Row(children: [
            LIcon(LGlyph.warn, size: 14, color: t.liveText),
            const SizedBox(width: 6),
            Expanded(
                child: Text(m.failureReason ?? '',
                    style: Lantern.textStyle(12.5,
                        color: t.liveText, height: 1.35))),
            if (room.chat.isRetryable(m.id))
              LButton(
                  label: 'live.chat_send_failed_retry'.tr(),
                  kind: LButtonKind.ghost,
                  size: LButtonSize.small,
                  onPressed: () => room.onRetryMessage(m.id)),
            LButton(
                label: 'live.chat_send_failed_discard'.tr(),
                kind: LButtonKind.ghost,
                size: LButtonSize.small,
                onPressed: () => room.chat.discardFailedMessage(m.id)),
          ])),
    ]);
  }
}

/// The composer, drawn from the chat's own state, so nobody is invited to
/// type into a box the server will refuse.
class _Composer extends StatelessWidget {
  const _Composer(
      {required this.room,
      required this.reactionsOpen,
      required this.onToggleReactions});

  final LanternRoom room;
  final bool reactionsOpen;
  final VoidCallback onToggleReactions;

  @override
  Widget build(BuildContext context) {
    final chat = room.chat;
    Widget notice(LGlyph icon, String text, {LTone tone = LTone.neutral,
            Widget? action}) =>
        Padding(
            key: const ValueKey('lantern-room-composer-notice'),
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: LBanner(text, tone: tone, icon: icon, action: action));
    if (isCompactLandscapeChat(context)) {
      return notice(LGlyph.phone, 'live.landscape_chat_read_only'.tr());
    }
    if (room.replay) {
      return notice(
          LGlyph.history, 'organization_v1.replay_chat_read_only'.tr());
    }
    switch (chat.composerState) {
      case ChatComposerState.guest:
        return notice(LGlyph.person, 'live.chat_composer_guest'.tr(),
            action: LButton(
                label: 'live.chat_composer_guest_action'.tr(),
                size: LButtonSize.small,
                onPressed: room.onSignIn));
      case ChatComposerState.banned:
        return notice(LGlyph.ban, 'live.chat_composer_banned'.tr(),
            tone: LTone.live);
      case ChatComposerState.platformPaused:
        return notice(
            LGlyph.pause, 'live.chat_composer_platform_paused'.tr(),
            tone: LTone.warn);
      case ChatComposerState.muted:
        return notice(LGlyph.volumeoff, 'live.chat_composer_muted'.tr(),
            tone: LTone.live);
      case ChatComposerState.chatDisabled:
        return notice(LGlyph.chat, 'live.chat_composer_chat_off'.tr());
      case ChatComposerState.offline:
      case ChatComposerState.slowMode:
      case ChatComposerState.ready:
        break;
    }
    final t = context.lt;
    final state = chat.composerState;
    final canSend = state == ChatComposerState.ready;
    final hint = switch (state) {
      ChatComposerState.slowMode => 'live.chat_composer_slow_mode'
          .plural(chat.slowModeSecondsRemaining),
      ChatComposerState.offline => 'live.chat_composer_offline'.tr(),
      _ => 'live.chat_placeholder'.tr(),
    };
    return Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
        child: TextFieldTapRegion(
            child: Row(children: [
          LIconButton(
              key: const ValueKey('lantern-room-hand'),
              icon: LGlyph.hand,
              label: 'live.raise_hand_toggle'.tr(),
              on: room.handRaised,
              onPressed: canSend ? room.onToggleHand : null),
          Expanded(
              child: TextField(
                  key: const ValueKey('lantern-room-input'),
                  controller: room.chatText,
                  focusNode: room.chatFocus,
                  onTapOutside:
                      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                          ? (_) => room.chatFocus.unfocus()
                          : null,
                  cursorColor: t.goldInk,
                  style: Lantern.textStyle(14.5, color: t.fg, height: 1.35),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                      hintText: hint,
                      hintStyle:
                          Lantern.textStyle(14, color: t.muted, height: 1.35),
                      isDense: true,
                      filled: true,
                      fillColor: t.surface,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: _pill(t.line),
                      enabledBorder: _pill(t.line),
                      focusedBorder: _pill(LanternTokens.gold)),
                  onSubmitted: canSend ? (_) => room.onSend() : null)),
          LIconButton(
              key: const ValueKey('lantern-room-react'),
              icon: reactionsOpen ? LGlyph.close : LGlyph.smile,
              label: 'live.reaction_menu_tooltip'.tr(),
              onPressed: onToggleReactions),
          const SizedBox(width: 2),
          _SendButton(onPressed: canSend ? room.onSend : null),
        ])));
  }

  static OutlineInputBorder _pill(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Lantern.radiusPill),
      borderSide: BorderSide(color: color, width: 1.2));
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final on = onPressed != null;
    return LPressable(
        key: const ValueKey('lantern-room-send'),
        onTap: onPressed,
        label: 'live.send'.tr(),
        pressScale: .92,
        excludeChildSemantics: true,
        builder: (context, s) => Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? null : t.sunk,
                gradient: on ? Lantern.goldFill : null),
            child: LIcon(LGlyph.send,
                size: 20, color: on ? LanternTokens.onGold : t.faint)));
  }
}

/// The five reactions, as the drawn icons that rise over the stage.
class _ReactionMenu extends StatelessWidget {
  const _ReactionMenu({required this.onReaction});

  final void Function(String type) onReaction;

  static const _labels = {
    'heart': 'lantern.room.react_heart',
    'clap': 'lantern.room.react_praise',
    'idea': 'lantern.room.react_idea',
    'fire': 'lantern.room.react_fire',
    'scholar': 'lantern.room.react_learned',
  };

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Material(
        key: const ValueKey('lantern-room-reactions'),
        color: t.raised,
        elevation: 8,
        shadowColor: const Color(0x99000000),
        shape: StadiumBorder(side: BorderSide(color: t.line)),
        child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final entry in _labels.entries) ...[
                LPressable(
                    onTap: () => onReaction(entry.key),
                    label: entry.value.tr(),
                    pressScale: .88,
                    excludeChildSemantics: true,
                    builder: (context, s) {
                      final kind = LanternReactions.kinds[entry.key]!;
                      return AnimatedScale(
                          scale: s.hovered ? 1.12 : 1,
                          duration: Lantern.calm(context)
                              ? Lantern.none
                              : Lantern.press,
                          child: Container(
                              width: 40,
                              height: 40,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: kind.$2, shape: BoxShape.circle),
                              child: LIcon(kind.$1,
                                  size: 20, color: LanternTokens.white)));
                    }),
              ],
            ])));
  }
}

class _Sources extends StatelessWidget {
  const _Sources({required this.room});

  final LanternRoom room;

  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(room.slidesUrl.trim());
    final usable = uri != null &&
        uri.hasAuthority &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    if (!usable) {
      return Center(
          child: SingleChildScrollView(
              child: LEmptyState(
                  title: 'live.sources_empty'.tr(),
                  icon: LGlyph.book,
                  compact: true)));
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      LRow(
          title: 'live.slides_pdf_title'.tr(),
          subtitle: room.slidesUrl.trim(),
          icon: LGlyph.book,
          trailing: LIcon(LGlyph.external, size: 18, color: context.lt.muted),
          onTap: room.onOpenSource),
    ]);
  }
}

class _Venue extends StatelessWidget {
  const _Venue({required this.room});

  final LanternRoom room;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final s = room.streamer;
    final venue = s.getLocalizedVenue(lang), city = s.getLocalizedCity(lang);
    return ListView(padding: const EdgeInsets.all(12), children: [
      LCard(
          flat: true,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 40,
                height: 44,
                alignment: const Alignment(0, .3),
                decoration: ShapeDecoration(
                    color: t.sunk,
                    shape: const LArchBorder(
                        side: BorderSide(color: LanternTokens.gold),
                        bottom: 6)),
                child: LIcon(LGlyph.pin, size: 18, color: t.goldInk)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(venue.isEmpty ? city : venue,
                      style: Lantern.textStyle(15,
                          color: t.fg, weight: FontWeight.w700, height: 1.4)),
                  if (venue.isNotEmpty && city.isNotEmpty)
                    Text(city,
                        style: Lantern.textStyle(13,
                            color: t.muted, height: 1.4)),
                ])),
          ])),
      if (room.onDirections != null) ...[
        const SizedBox(height: 12),
        LButton(
            label: 'live.get_directions'.tr(),
            icon: LGlyph.directions,
            kind: LButtonKind.tonal,
            expand: true,
            onPressed: room.onDirections),
      ],
    ]);
  }
}
