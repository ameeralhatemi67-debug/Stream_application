import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/notifications/notification_models.dart';
import '../../../core/widgets/ds/ca_surfaces.dart';
import '../../../core/widgets/ds/ca_button.dart';
import '../../../core/widgets/ds/ca_fields.dart';

/// In-App Notification Center Bottom Sheet Modal.
/// Features category filtering, read state tracking, swipe-to-delete,
/// per-streamer quick-mute controls, and direct deep-link navigation.
class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showCaSheet<void>(context,
        title: '',
        framed: false,
        fullWidthOnPhone: true,
        flushOnPhone: true,
        body: Builder(
            builder: (ctx) => const SafeArea(
                top: false, child: NotificationCenterSheet())));
  }

  @override
  State<NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  NotificationCategory _selectedCategory = NotificationCategory.all;

  @override
  void initState() {
    super.initState();
    // Server-written organization events (assignments, invitations, starts).
    final provider = context.read<AppProvider>();
    if (provider.isLoggedInStreamer) {
      provider.refreshOrganizationEvents().catchError(
          (Object e) => debugPrint('Organization events unavailable: $e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // context.read for method calls -- doesn't need to rebuild this widget on
    // its own. context.select scopes the rebuild to just the 3 fields this
    // sheet actually renders (notificationPreferences is included because
    // _buildNotificationTile's isEntityMuted check depends on it -- without
    // it, toggling mute wouldn't visibly update the mute icon).
    final appProvider = context.read<AppProvider>();
    final (allNotifications, unreadNotificationsCount, _) = context.select<
        AppProvider,
        (List<AppNotificationModel>, int, NotificationPreferencesModel)>(
      (p) => (
        p.enhancedNotifications,
        p.unreadNotificationsCount,
        p.notificationPreferences,
      ),
    );
    final isAr = context.locale.languageCode == 'ar';

    final filteredNotifications = _selectedCategory == NotificationCategory.all
        ? allNotifications
        : allNotifications
            .where((n) => n.category == _selectedCategory)
            .toList();

    return CaSheet(
      bareChrome: true,
      title: 'design_copy.notifications'.tr(),
      headerStatus: unreadNotificationsCount > 0
          ? Semantics(
              label: 'design_ui.unread_count'
                  .tr(namedArgs: {'count': '$unreadNotificationsCount'}),
              child: ExcludeSemantics(
                  child: Container(
                      padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: AppTheme.spaceSm,
                          vertical: AppTheme.spaceXs),
                      decoration: BoxDecoration(
                          color: Canopy.mint,
                          borderRadius:
                              BorderRadius.circular(CanopyRadius.pill)),
                      child: Text(
                          'design_ui.unread_count'.tr(namedArgs: {
                            'count': '$unreadNotificationsCount'
                          }),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: Canopy.brandGreen)))))
          : null,
      onClose: () => Navigator.pop(context),
      scrollBody: false,
      actions: [
        if (allNotifications.isNotEmpty)
          CaButton(
              label: 'design_copy.mark_all_read'.tr(),
              variant: CaButtonVariant.text,
              onPressed: () => appProvider.markAllNotificationsAsRead())
      ],
      body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip(
                    label: 'design_copy.all'.tr(),
                    category: NotificationCategory.all,
                    count: allNotifications.length,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    label: 'design_copy.live'.tr(),
                    category: NotificationCategory.live,
                    count: allNotifications
                        .where((n) => n.category == NotificationCategory.live)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    label: 'design_copy.invites_admin'.tr(),
                    category: NotificationCategory.invitesAndAdmin,
                    count: allNotifications
                        .where((n) =>
                            n.category == NotificationCategory.invitesAndAdmin)
                        .length,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    label: 'design_copy.vods'.tr(),
                    category: NotificationCategory.vods,
                    count: allNotifications
                        .where((n) => n.category == NotificationCategory.vods)
                        .length,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceSm),
            const Divider(color: Canopy.hairline, height: 1),
            const SizedBox(height: AppTheme.spaceSm),

            // Notifications List or Empty State
            if (filteredNotifications.isEmpty)
              Flexible(
                  child: SingleChildScrollView(
                      child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none_rounded,
                          color: Canopy.haze, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        'design_copy.no_notifications_in_this_category'.tr(),
                        style: const TextStyle(
                          color: Canopy.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'design_copy.you_will_receive_alerts_for_live_streams_lectures_and_invites_whe'
                            .tr(),
                        style: const TextStyle(
                            color: Canopy.haze, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )))
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredNotifications.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Canopy.hairline, height: 1),
                  itemBuilder: (context, idx) {
                    final notif = filteredNotifications[idx];
                    return _buildNotificationTile(
                        context, notif, appProvider, isAr);
                  },
                ),
              ),
          ]),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required NotificationCategory category,
    required int count,
  }) {
    final isSelected = _selectedCategory == category;
    return CaChip(
        label: '$label ($count)',
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category));
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotificationModel notif,
    AppProvider appProvider,
    bool isAr,
  ) {
    final iconData = _getNotificationIcon(notif.type);
    final accentColor = _getNotificationColor(notif.type);
    final isMuted = notif.streamerId.isNotEmpty &&
        appProvider.isEntityMuted(notif.streamerId);

    return Dismissible(
      key: Key('notif_${notif.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Canopy.liveCrimson,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const Icon(Icons.delete_sweep_rounded,
                color: AppTheme.onMedia, size: 20),
            const SizedBox(width: 6),
            Text('design_ui.dismiss'.tr(),
                style: const TextStyle(
                    color: AppTheme.onMedia,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      onDismissed: (_) {
        appProvider.deleteNotification(notif.id);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        leading: Stack(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Icon(iconData, color: accentColor, size: 20),
            ),
            if (!notif.isRead)
              PositionedDirectional(
                top: 0,
                end: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notif.getLocalizedTitle(isAr ? 'ar' : 'en'),
          style: TextStyle(
            color: notif.isRead ? Canopy.slate : Canopy.ink,
            fontSize: 13,
            fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              notif.getLocalizedBody(isAr ? 'ar' : 'en'),
              style: const TextStyle(
                  color: Canopy.haze, fontSize: 12, height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatTimeAgo(notif.timestamp, isAr),
                  style:
                      const TextStyle(color: Canopy.haze, fontSize: 12),
                ),
                if (notif.streamerId.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      appProvider.toggleMuteEntity(notif.streamerId);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMuted
                                ? Icons.notifications_off_rounded
                                : Icons.notifications_none_rounded,
                            size: 12,
                            color:
                                isMuted ? Canopy.haze : AppTheme.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isMuted
                                ? ('design_copy.unmute'.tr())
                                : ('design_copy.mute'.tr()),
                            style: TextStyle(
                              color: isMuted
                                  ? Canopy.haze
                                  : AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        onTap: () {
          appProvider.markNotificationAsRead(notif.id);
          Navigator.pop(context);

          if (notif.streamId != null && notif.streamId!.isNotEmpty) {
            context.push('/live/${notif.streamId}');
          } else if (notif.actionUrl != null && notif.actionUrl!.isNotEmpty) {
            context.push(notif.actionUrl!);
          } else if (notif.streamerId.isNotEmpty) {
            context.push('/profile/${notif.streamerId}');
          }
        },
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.streamerLiveVideo:
      case NotificationType.orgStreamerLiveStatus:
        return Icons.videocam_rounded;
      case NotificationType.streamerLiveAudio:
        return Icons.mic_rounded;
      case NotificationType.watchMilestoneOneHour:
        return Icons.workspace_premium_rounded;
      case NotificationType.streamerApplicationApproved:
        return Icons.verified_rounded;
      case NotificationType.streamerApplicationRejected:
        return Icons.assignment_late_rounded;
      case NotificationType.orgLiveGuestInvite:
        return Icons.record_voice_over_rounded;
      case NotificationType.orgAffiliationInvite:
        return Icons.domain_add_rounded;
      case NotificationType.streamerRemovedFromOrg:
        return Icons.domain_disabled_rounded;
      case NotificationType.adminNoteToStreamer:
      case NotificationType.adminNoteToOrg:
        return Icons.mark_email_read_rounded;
      case NotificationType.adminCardEditRequestStreamer:
      case NotificationType.adminCardEditRequestOrg:
        return Icons.edit_note_rounded;
      case NotificationType.newVodUpload:
        return Icons.video_library_rounded;
      case NotificationType.systemAlert:
        return Icons.info_outline_rounded;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.streamerLiveVideo:
      case NotificationType.orgStreamerLiveStatus:
        return Canopy.liveCrimson;
      case NotificationType.streamerLiveAudio:
        return Canopy.haze;
      case NotificationType.watchMilestoneOneHour:
        return AppTheme.warning;
      case NotificationType.streamerApplicationApproved:
        return Canopy.leaf;
      case NotificationType.streamerApplicationRejected:
        return AppTheme.warning;
      case NotificationType.orgLiveGuestInvite:
      case NotificationType.orgAffiliationInvite:
        return AppTheme.accent;
      case NotificationType.streamerRemovedFromOrg:
        return Canopy.haze;
      case NotificationType.adminNoteToStreamer:
      case NotificationType.adminNoteToOrg:
        return AppTheme.primary;
      case NotificationType.adminCardEditRequestStreamer:
      case NotificationType.adminCardEditRequestOrg:
        return AppTheme.warning;
      case NotificationType.newVodUpload:
        return AppTheme.primary;
      case NotificationType.systemAlert:
        return Canopy.slate;
    }
  }

  String _formatTimeAgo(DateTime timestamp, bool isAr) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'design_copy.just_now'.tr();
    if (diff.inMinutes < 60) {
      return isAr ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return isAr ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    }
    return isAr ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
  }
}
