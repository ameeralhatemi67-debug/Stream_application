import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/notifications/notification_models.dart';

/// In-App Notification Center Bottom Sheet Modal.
/// Features category filtering, read state tracking, swipe-to-delete,
/// per-streamer quick-mute controls, and direct deep-link navigation.
class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => const NotificationCenterSheet(),
    );
  }

  @override
  State<NotificationCenterSheet> createState() => _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  NotificationCategory _selectedCategory = NotificationCategory.all;

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isAr = context.locale.languageCode == 'ar';
    final allNotifications = appProvider.enhancedNotifications;

    final filteredNotifications = _selectedCategory == NotificationCategory.all
        ? allNotifications
        : allNotifications.where((n) => n.category == _selectedCategory).toList();

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceMd),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.darkBorderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row: Title, Unread Count & Action Controls
            Row(
              children: [
                const Icon(Icons.notifications_rounded, color: AppTheme.accentBlue, size: 22),
                const SizedBox(width: 8),
                Text(
                  isAr ? 'مركز التنبيهات' : 'Notifications',
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (appProvider.unreadNotificationsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${appProvider.unreadNotificationsCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const Spacer(),
                if (allNotifications.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => appProvider.markAllNotificationsAsRead(),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: Text(
                      isAr ? 'تحديد الكل كمقروء' : 'Mark all read',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMutedDark),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMd),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip(
                    label: isAr ? 'الكل' : 'All',
                    category: NotificationCategory.all,
                    count: allNotifications.length,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    label: isAr ? '🔴 البثوث المباشرة' : '🔴 Live',
                    category: NotificationCategory.live,
                    count: allNotifications.where((n) => n.category == NotificationCategory.live).length,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    label: isAr ? '🏛️ الدعوات والإدارة' : '🏛️ Invites & Admin',
                    category: NotificationCategory.invitesAndAdmin,
                    count: allNotifications.where((n) => n.category == NotificationCategory.invitesAndAdmin).length,
                  ),
                  const SizedBox(width: 8),
                  _buildCategoryChip(
                    label: isAr ? '🎬 المحاضرات' : '🎬 VODs',
                    category: NotificationCategory.vods,
                    count: allNotifications.where((n) => n.category == NotificationCategory.vods).length,
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spaceSm),
            const Divider(color: AppTheme.darkBorderSubtle, height: 1),
            const SizedBox(height: AppTheme.spaceSm),

            // Notifications List or Empty State
            if (filteredNotifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none_rounded, color: AppTheme.textMutedDark, size: 44),
                      const SizedBox(height: 12),
                      Text(
                        isAr
                            ? 'لا توجد تنبيهات جديدة في هذا القسم'
                            : 'No notifications in this category',
                        style: const TextStyle(
                          color: AppTheme.textPrimaryDark,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr
                            ? 'ستصلك إشعارات البثوث المباشرة والمحاضرات والدعوات فور توفرها.'
                            : 'You will receive alerts for live streams, lectures, and invites when they occur.',
                        style: const TextStyle(color: AppTheme.textMutedDark, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredNotifications.length,
                  separatorBuilder: (_, __) => const Divider(color: AppTheme.darkBorderSubtle, height: 1),
                  itemBuilder: (context, idx) {
                    final notif = filteredNotifications[idx];
                    return _buildNotificationTile(context, notif, appProvider, isAr);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required NotificationCategory category,
    required int count,
  }) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedCategory = category),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textSecondaryDark,
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppTheme.darkSurface2,
      selectedColor: AppTheme.accentBlue,
      side: BorderSide(
        color: isSelected ? AppTheme.accentBlue : AppTheme.darkBorderSubtle,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotificationModel notif,
    AppProvider appProvider,
    bool isAr,
  ) {
    final iconData = _getNotificationIcon(notif.type);
    final accentColor = _getNotificationColor(notif.type);
    final isMuted = notif.streamerId.isNotEmpty && appProvider.isEntityMuted(notif.streamerId);

    return Dismissible(
      key: Key('notif_${notif.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade900,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 20),
            SizedBox(width: 6),
            Text('Dismiss', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentRed,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          notif.getLocalizedTitle(isAr ? 'ar' : 'en'),
          style: TextStyle(
            color: notif.isRead ? AppTheme.textSecondaryDark : AppTheme.textPrimaryDark,
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
              style: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5, height: 1.3),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  _formatTimeAgo(notif.timestamp, isAr),
                  style: const TextStyle(color: AppTheme.textMutedDark, fontSize: 10),
                ),
                if (notif.streamerId.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      appProvider.toggleMuteEntity(notif.streamerId);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isMuted ? Icons.notifications_off_rounded : Icons.notifications_none_rounded,
                            size: 12,
                            color: isMuted ? AppTheme.accentRed : AppTheme.accentBlue,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isMuted
                                ? (isAr ? 'إلغاء الكتم' : 'Unmute')
                                : (isAr ? 'كتم الإشعارات' : 'Mute'),
                            style: TextStyle(
                              color: isMuted ? AppTheme.accentRed : AppTheme.accentBlue,
                              fontSize: 10,
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
        return AppTheme.accentRed;
      case NotificationType.streamerLiveAudio:
        return const Color(0xFFA1A1AA);
      case NotificationType.watchMilestoneOneHour:
        return Colors.amber;
      case NotificationType.streamerApplicationApproved:
        return AppTheme.accentGreen;
      case NotificationType.streamerApplicationRejected:
        return Colors.orange;
      case NotificationType.orgLiveGuestInvite:
      case NotificationType.orgAffiliationInvite:
        return AppTheme.accentPurple;
      case NotificationType.streamerRemovedFromOrg:
        return Colors.blueGrey;
      case NotificationType.adminNoteToStreamer:
      case NotificationType.adminNoteToOrg:
        return AppTheme.accentBlue;
      case NotificationType.adminCardEditRequestStreamer:
      case NotificationType.adminCardEditRequestOrg:
        return Colors.deepOrangeAccent;
      case NotificationType.newVodUpload:
        return AppTheme.accentBlue;
      case NotificationType.systemAlert:
        return AppTheme.textSecondaryDark;
    }
  }

  String _formatTimeAgo(DateTime timestamp, bool isAr) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return isAr ? 'الآن' : 'Just now';
    if (diff.inMinutes < 60) return isAr ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return isAr ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
    return isAr ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
  }
}
