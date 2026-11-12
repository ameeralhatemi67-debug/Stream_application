import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/notifications/notification_models.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../notification_center_sheet.dart';

/// Opens the notifications in Lantern and Arch (ADR-026): a panel from the
/// end side on the website layout, a Lantern sheet on a phone. The list is
/// [NotificationCenterSheet], which keeps its filter, its loads and its
/// actions and draws [LanternNotificationsBody] under Lantern.
///
/// A signed-in account gets a settings button beside the close button: it
/// closes the panel and opens Settings at the notifications section.
Future<void> showLanternNotifications(BuildContext context) {
  final signedIn = context.read<AppProvider>().isLoggedInStreamer;
  final router = GoRouter.maybeOf(context);
  return showLanternDrawer<void>(context,
      title: 'design_copy.notifications'.tr(),
      headerActions: !signedIn || router == null
          ? null
          : (sheetContext) => [
                LIconButton(
                    key: const ValueKey('lantern-notifications-preferences'),
                    icon: LGlyph.settings,
                    label: 'design_copy.notification_preferences'.tr(),
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      router.push(LanternNotificationsBody.preferencesPath);
                    }),
              ],
      body: (_) => const NotificationCenterSheet());
}

/// The notifications: the unread count, the category filters, mark all
/// read, and one row per notice with open, mute and dismiss.
class LanternNotificationsBody extends StatelessWidget
    implements LanternSkinWidget {
  const LanternNotificationsBody(
      {super.key,
      required this.all,
      required this.visible,
      required this.category,
      required this.onCategory,
      required this.unread,
      required this.onOpen,
      required this.onDelete,
      required this.isMuted,
      required this.onToggleMute,
      required this.timeAgo,
      this.onMarkAllRead});

  /// Settings, opened at its notifications section (the header's settings
  /// button).
  static const preferencesPath = '/settings?section=notifications';

  final List<AppNotificationModel> all, visible;
  final NotificationCategory category;
  final ValueChanged<NotificationCategory> onCategory;
  final int unread;
  final ValueChanged<AppNotificationModel> onOpen, onDelete;
  final bool Function(String streamerId) isMuted;
  final ValueChanged<String> onToggleMute;
  final String Function(DateTime) timeAgo;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode;
    int count(NotificationCategory c) =>
        all.where((n) => n.category == c).length;
    final filters = <(NotificationCategory, String, int)>[
      (NotificationCategory.all, 'design_copy.all'.tr(), all.length),
      (
        NotificationCategory.live,
        'design_copy.live'.tr(),
        count(NotificationCategory.live)
      ),
      (
        NotificationCategory.invitesAndAdmin,
        'design_copy.invites_admin'.tr(),
        count(NotificationCategory.invitesAndAdmin)
      ),
      (
        NotificationCategory.vods,
        'design_copy.vods'.tr(),
        count(NotificationCategory.vods)
      ),
    ];
    return Column(
        key: const ValueKey('lantern-notifications'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (unread > 0)
                  LTag(
                      'design_ui.unread_count'
                          .tr(namedArgs: {'count': '$unread'}),
                      key: const ValueKey('lantern-notifications-unread'),
                      tone: LTone.gold,
                      icon: LGlyph.bell),
                if (onMarkAllRead != null)
                  LButton(
                      key: const ValueKey('lantern-notifications-read-all'),
                      label: 'design_copy.mark_all_read'.tr(),
                      icon: LGlyph.check,
                      kind: LButtonKind.ghost,
                      size: LButtonSize.small,
                      onPressed: onMarkAllRead),
              ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (c, label, n) in filters)
              LChip(
                  key: ValueKey('lantern-notifications-filter-${c.name}'),
                  label: label,
                  count: n,
                  dense: true,
                  selected: c == category,
                  onTap: () => onCategory(c)),
          ]),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            LEmptyState(
                key: const ValueKey('lantern-notifications-empty'),
                icon: LGlyph.bell,
                title: 'design_copy.no_notifications_in_this_category'.tr(),
                body:
                    'design_copy.you_will_receive_alerts_for_live_streams_lectures_and_invites_whe'
                        .tr())
          else
            for (final n in visible)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Notice(
                      key: ValueKey('lantern-notice-${n.id}'),
                      notice: n,
                      title: n.getLocalizedTitle(language),
                      body: n.getLocalizedBody(language),
                      time: timeAgo(n.timestamp),
                      muted: n.streamerId.isNotEmpty && isMuted(n.streamerId),
                      onOpen: () => onOpen(n),
                      onDelete: () => onDelete(n),
                      onToggleMute: n.streamerId.isEmpty
                          ? null
                          : () => onToggleMute(n.streamerId))),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ]);
  }
}

class _Notice extends StatelessWidget {
  const _Notice(
      {super.key,
      required this.notice,
      required this.title,
      required this.body,
      required this.time,
      required this.muted,
      required this.onOpen,
      required this.onDelete,
      required this.onToggleMute});

  final AppNotificationModel notice;
  final String title, body, time;
  final bool muted;
  final VoidCallback onOpen, onDelete;
  final VoidCallback? onToggleMute;

  static LGlyph glyphOf(NotificationType type) => switch (type) {
        NotificationType.streamerLiveVideo ||
        NotificationType.orgStreamerLiveStatus =>
          LGlyph.live,
        NotificationType.streamerLiveAudio => LGlyph.audio,
        NotificationType.watchMilestoneOneHour => LGlyph.star,
        NotificationType.streamerApplicationApproved => LGlyph.verified,
        NotificationType.streamerApplicationRejected => LGlyph.warn,
        NotificationType.orgLiveGuestInvite => LGlyph.mic,
        NotificationType.orgAffiliationInvite ||
        NotificationType.streamerRemovedFromOrg =>
          LGlyph.org,
        NotificationType.adminNoteToStreamer ||
        NotificationType.adminNoteToOrg =>
          LGlyph.mail,
        NotificationType.adminCardEditRequestStreamer ||
        NotificationType.adminCardEditRequestOrg =>
          LGlyph.edit,
        NotificationType.newVodUpload => LGlyph.play,
        NotificationType.scheduleReminder => LGlyph.clock,
        NotificationType.systemAlert => LGlyph.info,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final unread = !notice.isRead;
    final (disc, ink) = switch (notice.type) {
      NotificationType.streamerLiveVideo ||
      NotificationType.orgStreamerLiveStatus =>
        (t.liveSoft, t.liveText),
      NotificationType.streamerLiveAudio => (t.audioSoft, t.audio),
      NotificationType.streamerApplicationApproved => (t.okSoft, t.ok),
      NotificationType.streamerApplicationRejected ||
      NotificationType.adminCardEditRequestStreamer ||
      NotificationType.adminCardEditRequestOrg =>
        (t.warnSoft, t.warn),
      _ => (t.sunk, t.goldInk),
    };
    final ground = unread
        ? Color.alphaBlend(
            LanternTokens.gold.withValues(alpha: t.night ? .1 : .08),
            t.surface)
        : t.surface;
    return LPressable(
        onTap: onOpen,
        label: unread
            ? '$title, ${'lantern.account.unread'.tr()}'
            : title,
        radius: Lantern.radiusRow,
        pressScale: .99,
        builder: (context, s) => AnimatedContainer(
            duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 4, 10),
            decoration: BoxDecoration(
                color: s.hovered ? t.sunk : ground,
                borderRadius: BorderRadius.circular(Lantern.radiusRow),
                border: Border.all(
                    color: unread ? LanternTokens.goldHi : t.line2)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: disc,
                      borderRadius: BorderRadius.circular(Lantern.radiusTile)),
                  child: LIcon(glyphOf(notice.type), size: 19, color: ink)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                          child: Text(title,
                              style: Lantern.textStyle(14,
                                  color: t.fg,
                                  weight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  height: 1.35))),
                      if (unread)
                        const Padding(
                            padding:
                                EdgeInsetsDirectional.only(start: 6, top: 4),
                            child: LStar(size: 10)),
                    ]),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(body,
                          style: Lantern.textStyle(13,
                              color: t.muted, height: 1.4)),
                    ],
                    const SizedBox(height: 4),
                    Wrap(
                        spacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(time,
                              style: Lantern.textStyle(12, color: t.muted)),
                          if (onToggleMute != null)
                            LPressable(
                                onTap: onToggleMute,
                                label: (muted
                                        ? 'design_copy.unmute'
                                        : 'design_copy.mute')
                                    .tr(),
                                radius: 8,
                                excludeChildSemantics: true,
                                builder: (context, s) => ConstrainedBox(
                                    constraints: const BoxConstraints(
                                        minHeight: Lantern.target),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          LIcon(
                                              muted
                                                  ? LGlyph.volumeoff
                                                  : LGlyph.bell,
                                              size: 14,
                                              color: muted
                                                  ? t.muted
                                                  : t.goldInk),
                                          const SizedBox(width: 4),
                                          Text(
                                              (muted
                                                      ? 'design_copy.unmute'
                                                      : 'design_copy.mute')
                                                  .tr(),
                                              style: Lantern.textStyle(12.5,
                                                  color: muted
                                                      ? t.muted
                                                      : t.goldInk,
                                                  weight: FontWeight.w600)),
                                        ]))),
                        ]),
                  ])),
              LIconButton(
                  icon: LGlyph.close,
                  label: 'design_ui.dismiss'.tr(),
                  iconSize: 16,
                  onPressed: onDelete),
            ])));
  }
}
