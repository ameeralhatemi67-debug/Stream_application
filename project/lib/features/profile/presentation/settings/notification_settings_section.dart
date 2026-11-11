import '../../../../core/widgets/ds/ca_fields.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/reminder_push_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../lantern/lantern_settings_sections.dart';

/// The notification preferences card, shown in its own modal sheet from
/// Settings.
///
/// Extracted from `settings_screen.dart` as part of finishing the Settings
/// split the spec asks for: the screen was carrying every section's markup
/// inline, which is what made its sections hard to review one at a time.
class NotificationSettingsSection extends StatelessWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    context.select<AppProvider, Object?>((p) => (
          p.notificationPreferences,
          p.isLoggedInStreamer,
          p.reminderLeadMinutes,
          p.reminderPushStatus,
          p.streamers
        ));
    if (context.isLanternSkin) {
      return _buildLantern(context, context.read<AppProvider>());
    }
    return _buildNotificationPreferencesCard(
        context, context.read<AppProvider>());
  }

  /// Lantern and Arch (ADR-026): the same preferences and provider calls.
  Widget _buildLantern(BuildContext context, AppProvider provider) {
    final isAr = context.locale.languageCode == 'ar';
    final prefs = provider.notificationPreferences;
    final status = provider.reminderPushStatus;
    final askPush = provider.isLoggedInStreamer &&
        status != ReminderPushStatus.granted;
    return LanternNotificationPrefs(
        limit: prefs.maxPer10Min,
        onLimit: provider.setNotificationRateLimit,
        reminders: provider.remindersAvailable ? true : null,
        leadMinutes: provider.reminderLeadMinutes,
        onLead: provider.isLoggedInStreamer
            ? (value) async {
                try {
                  await provider.setReminderLeadMinutes(value);
                } catch (_) {
                  if (context.mounted) {
                    lanternToast(context, 'upcoming.save_failed'.tr(),
                        warn: true);
                  }
                }
              }
            : null,
        pushNote: !askPush
            ? null
            : (status == ReminderPushStatus.notGranted
                    ? 'upcoming.permission_denied'
                    : 'upcoming.permission_unavailable')
                .tr(),
        pushHelp: askPush && status == ReminderPushStatus.notGranted
            ? 'upcoming.permission_help'.tr()
            : null,
        onEnablePush: askPush && status == ReminderPushStatus.notGranted
            ? () => provider.syncReminderPush(
                requestPermission: true,
                language: context.locale.languageCode)
            : null,
        categories: [
          (
            'design_copy.live_video_broadcasts'.tr(),
            LGlyph.live,
            prefs.liveVideoEnabled,
            (v) => provider.updateNotificationPreferences(
                prefs.copyWith(liveVideoEnabled: v)),
          ),
          (
            'design_copy.live_audio_stages'.tr(),
            LGlyph.audio,
            prefs.liveAudioEnabled,
            (v) => provider.updateNotificationPreferences(
                prefs.copyWith(liveAudioEnabled: v)),
          ),
          (
            'design_copy.1_hour_watch_milestone_rewards'.tr(),
            LGlyph.star,
            prefs.watchMilestonesEnabled,
            (v) => provider.updateNotificationPreferences(
                prefs.copyWith(watchMilestonesEnabled: v)),
          ),
          (
            'design_copy.org_invites_guest_roles'.tr(),
            LGlyph.org,
            prefs.orgInvitesEnabled,
            (v) => provider.updateNotificationPreferences(
                prefs.copyWith(orgInvitesEnabled: v)),
          ),
          (
            'design_copy.administrative_governance_notes'.tr(),
            LGlyph.shield,
            prefs.adminNotesEnabled,
            (v) => provider.updateNotificationPreferences(
                prefs.copyWith(adminNotesEnabled: v)),
          ),
          (
            'design_copy.new_vods_lectures'.tr(),
            LGlyph.play,
            prefs.vodsEnabled,
            (v) => provider.updateNotificationPreferences(
                prefs.copyWith(vodsEnabled: v)),
          ),
          (
            'design_copy.lesson_alerts'.tr(),
            LGlyph.mosque,
            prefs.lessonsEnabled,
            (v) => provider.updateNotificationPreferences(
                prefs.copyWith(lessonsEnabled: v)),
          ),
        ],
        muted: [
          for (final id in prefs.mutedEntityIds)
            (
              provider
                      .getStreamerById(id)
                      ?.getLocalizedName(isAr ? 'ar' : 'en') ??
                  id,
              () => provider.toggleMuteEntity(id),
            ),
        ]);
  }

  Widget _buildNotificationPreferencesCard(
      BuildContext context, AppProvider provider) {
    final isAr = context.locale.languageCode == 'ar';
    final prefs = provider.notificationPreferences;
    final mutedIds = prefs.mutedEntityIds;

    return CaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //  10-Minute Rolling Rate Limiter Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'design_copy.10_minute_alert_limit'.tr(),
                style: const TextStyle(
                  color: Canopy.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppTheme.radiusXs),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.5)),
                ),
                child: Text(
                  isAr
                      ? '${prefs.maxPer10Min} إشعارات'
                      : '${prefs.maxPer10Min} alerts',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: AppTheme.captionFont,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'design_copy.prevents_notification_fatigue_by_bundling_excess_alerts_into_a_sm'
                .tr(),
            style: const TextStyle(
                color: Canopy.haze, fontSize: AppTheme.captionFont),
          ),
          const SizedBox(height: 8),
          Slider(
            value: prefs.maxPer10Min.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            activeColor: AppTheme.primary,
            inactiveColor: Canopy.hairline,
            label: '${prefs.maxPer10Min}',
            onChanged: (val) {
              provider.setNotificationRateLimit(val.round());
            },
          ),
          const Divider(color: Canopy.hairline, height: 24),

          if (provider.remindersAvailable) ...[
            Text('upcoming.reminder_settings'.tr(),
                style: const TextStyle(
                    color: Canopy.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: AppTheme.spaceSm),
            Row(children: [
              Expanded(
                  child: Text('upcoming.lead_time'.tr(),
                      style: const TextStyle(color: Canopy.slate))),
              DropdownButton<int>(
                value: provider.reminderLeadMinutes,
                items: [
                  for (var minutes = 5; minutes <= 30; minutes += 5)
                    DropdownMenuItem(
                        value: minutes,
                        child: Text('$minutes ${isAr ? 'دقيقة' : 'min'}'))
                ],
                onChanged: provider.isLoggedInStreamer
                    ? (value) async {
                        if (value == null) return;
                        try {
                          await provider.setReminderLeadMinutes(value);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('upcoming.save_failed'.tr())));
                          }
                        }
                      }
                    : null,
              ),
            ]),
            if (provider.isLoggedInStreamer &&
                provider.reminderPushStatus != ReminderPushStatus.granted) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                  (provider.reminderPushStatus == ReminderPushStatus.notGranted
                          ? 'upcoming.permission_denied'
                          : 'upcoming.permission_unavailable')
                      .tr(),
                  style: const TextStyle(color: Canopy.slate)),
              if (provider.reminderPushStatus ==
                  ReminderPushStatus.notGranted) ...[
                const SizedBox(height: 4),
                Text('upcoming.permission_help'.tr(),
                    style: const TextStyle(
                        color: Canopy.haze, fontSize: AppTheme.captionFont)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    key: const ValueKey('turn-on-notifications'),
                    onPressed: () => provider.syncReminderPush(
                        requestPermission: true,
                        language: context.locale.languageCode),
                    child: Text('upcoming.permission_enable'.tr()),
                  ),
                ),
              ],
            ],
            const Divider(color: Canopy.hairline, height: 24),
          ],

          //  Granular Notification Category Toggles
          Text(
            'design_copy.active_notification_categories'.tr(),
            style: const TextStyle(
              color: Canopy.ink,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),

          _buildNotifCaSwitch(
            title: 'design_copy.live_video_broadcasts'.tr(),
            value: prefs.liveVideoEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(liveVideoEnabled: val),
              );
            },
          ),
          _buildNotifCaSwitch(
            title: 'design_copy.live_audio_stages'.tr(),
            value: prefs.liveAudioEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(liveAudioEnabled: val),
              );
            },
          ),
          _buildNotifCaSwitch(
            title: 'design_copy.1_hour_watch_milestone_rewards'.tr(),
            value: prefs.watchMilestonesEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(watchMilestonesEnabled: val),
              );
            },
          ),
          _buildNotifCaSwitch(
            title: 'design_copy.org_invites_guest_roles'.tr(),
            value: prefs.orgInvitesEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(orgInvitesEnabled: val),
              );
            },
          ),
          _buildNotifCaSwitch(
            title: 'design_copy.administrative_governance_notes'.tr(),
            value: prefs.adminNotesEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(adminNotesEnabled: val),
              );
            },
          ),
          _buildNotifCaSwitch(
            title: 'design_copy.new_vods_lectures'.tr(),
            value: prefs.vodsEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(vodsEnabled: val),
              );
            },
          ),
          _buildNotifCaSwitch(
            title: 'design_copy.lesson_alerts'.tr(),
            value: prefs.lessonsEnabled,
            onChanged: (val) {
              provider.updateNotificationPreferences(
                prefs.copyWith(lessonsEnabled: val),
              );
            },
          ),

          //  Muted Streamers / Organizations List
          if (mutedIds.isNotEmpty) ...[
            const Divider(color: Canopy.hairline, height: 24),
            Text(
              isAr
                  ? 'القنوات المكتومة (${mutedIds.length})'
                  : 'Muted Channels (${mutedIds.length})',
              style: const TextStyle(
                color: Canopy.ink,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: mutedIds.map((id) {
                final streamer = provider.getStreamerById(id);
                final name = streamer != null
                    ? streamer.getLocalizedName(isAr ? 'ar' : 'en')
                    : id;
                return Chip(
                  backgroundColor: Canopy.mint,
                  label: Text(
                    name,
                    style: const TextStyle(
                        color: Canopy.slate, fontSize: AppTheme.captionFont),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded,
                      size: 14, color: Canopy.liveCrimson),
                  onDeleted: () {
                    provider.toggleMuteEntity(id);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotifCaSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Canopy.slate, fontSize: 12),
            ),
          ),
          CaSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
