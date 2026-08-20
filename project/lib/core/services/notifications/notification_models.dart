import 'package:flutter/foundation.dart';

/// 14 Distinct Humanized Notification Event Types
enum NotificationType {
  streamerLiveVideo,
  streamerLiveAudio,
  watchMilestoneOneHour,
  streamerApplicationApproved,
  streamerApplicationRejected,
  orgLiveGuestInvite,
  orgAffiliationInvite,
  streamerRemovedFromOrg,
  adminNoteToStreamer,
  adminCardEditRequestStreamer,
  adminNoteToOrg,
  adminCardEditRequestOrg,
  orgStreamerLiveStatus,
  newVodUpload,
  systemAlert,
}

/// Notification High-Level UI Filter Categories
enum NotificationCategory {
  all,
  live,
  invitesAndAdmin,
  vods,
}

/// Comprehensive Notification Model for Streamer App
@immutable
class AppNotificationModel {
  final String id;
  final NotificationType type;
  final String streamerId;
  final String streamerName;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final DateTime timestamp;
  final bool isRead;
  final String? streamId;
  final String? actionUrl;
  final Map<String, dynamic> metadata;

  const AppNotificationModel({
    required this.id,
    required this.type,
    this.streamerId = '',
    this.streamerName = '',
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.timestamp,
    this.isRead = false,
    this.streamId,
    this.actionUrl,
    this.metadata = const {},
  });

  bool get isLiveAlert =>
      type == NotificationType.streamerLiveVideo ||
      type == NotificationType.streamerLiveAudio ||
      type == NotificationType.orgStreamerLiveStatus;

  NotificationCategory get category {
    switch (type) {
      case NotificationType.streamerLiveVideo:
      case NotificationType.streamerLiveAudio:
      case NotificationType.watchMilestoneOneHour:
      case NotificationType.orgStreamerLiveStatus:
        return NotificationCategory.live;
      case NotificationType.streamerApplicationApproved:
      case NotificationType.streamerApplicationRejected:
      case NotificationType.orgLiveGuestInvite:
      case NotificationType.orgAffiliationInvite:
      case NotificationType.streamerRemovedFromOrg:
      case NotificationType.adminNoteToStreamer:
      case NotificationType.adminCardEditRequestStreamer:
      case NotificationType.adminNoteToOrg:
      case NotificationType.adminCardEditRequestOrg:
        return NotificationCategory.invitesAndAdmin;
      case NotificationType.newVodUpload:
        return NotificationCategory.vods;
      case NotificationType.systemAlert:
        return NotificationCategory.all;
    }
  }

  String getLocalizedTitle(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;

  String getLocalizedBody(String languageCode) =>
      languageCode == 'ar' ? bodyAr : bodyEn;

  AppNotificationModel copyWith({
    String? id,
    NotificationType? type,
    String? streamerId,
    String? streamerName,
    String? titleEn,
    String? titleAr,
    String? bodyEn,
    String? bodyAr,
    DateTime? timestamp,
    bool? isRead,
    String? streamId,
    String? actionUrl,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      streamerId: streamerId ?? this.streamerId,
      streamerName: streamerName ?? this.streamerName,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      bodyEn: bodyEn ?? this.bodyEn,
      bodyAr: bodyAr ?? this.bodyAr,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      streamId: streamId ?? this.streamId,
      actionUrl: actionUrl ?? this.actionUrl,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'streamerId': streamerId,
        'streamerName': streamerName,
        'titleEn': titleEn,
        'titleAr': titleAr,
        'bodyEn': bodyEn,
        'bodyAr': bodyAr,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
        'streamId': streamId,
        'actionUrl': actionUrl,
        'metadata': metadata,
      };

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.systemAlert,
      ),
      streamerId: json['streamerId'] as String? ?? '',
      streamerName: json['streamerName'] as String? ?? '',
      titleEn: json['titleEn'] as String? ?? '',
      titleAr: json['titleAr'] as String? ?? '',
      bodyEn: json['bodyEn'] as String? ?? '',
      bodyAr: json['bodyAr'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      streamId: json['streamId'] as String?,
      actionUrl: json['actionUrl'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }
}

/// User Notification Settings and Anti-Spam Throttling Preferences
@immutable
class NotificationPreferencesModel {
  final int maxPer10Min;
  final Set<String> mutedEntityIds;
  final bool liveVideoEnabled;
  final bool liveAudioEnabled;
  final bool vodsEnabled;
  final bool watchMilestonesEnabled;
  final bool orgInvitesEnabled;
  final bool adminNotesEnabled;
  final bool quietHoursEnabled;
  final int quietHoursStart; // Hour in 24h format (e.g. 23)
  final int quietHoursEnd; // Hour in 24h format (e.g. 7)

  const NotificationPreferencesModel({
    this.maxPer10Min = 5,
    this.mutedEntityIds = const {},
    this.liveVideoEnabled = true,
    this.liveAudioEnabled = true,
    this.vodsEnabled = true,
    this.watchMilestonesEnabled = true,
    this.orgInvitesEnabled = true,
    this.adminNotesEnabled = true,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 23,
    this.quietHoursEnd = 7,
  });

  bool isEntityMuted(String entityId) => mutedEntityIds.contains(entityId);

  bool isCategoryEnabled(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.live:
        return liveVideoEnabled || liveAudioEnabled || watchMilestonesEnabled;
      case NotificationCategory.invitesAndAdmin:
        return orgInvitesEnabled || adminNotesEnabled;
      case NotificationCategory.vods:
        return vodsEnabled;
      case NotificationCategory.all:
        return true;
    }
  }

  bool isTypeEnabled(NotificationType type) {
    switch (type) {
      case NotificationType.streamerLiveVideo:
      case NotificationType.orgStreamerLiveStatus:
        return liveVideoEnabled;
      case NotificationType.streamerLiveAudio:
        return liveAudioEnabled;
      case NotificationType.watchMilestoneOneHour:
        return watchMilestonesEnabled;
      case NotificationType.newVodUpload:
        return vodsEnabled;
      case NotificationType.orgLiveGuestInvite:
      case NotificationType.orgAffiliationInvite:
      case NotificationType.streamerRemovedFromOrg:
        return orgInvitesEnabled;
      case NotificationType.streamerApplicationApproved:
      case NotificationType.streamerApplicationRejected:
      case NotificationType.adminNoteToStreamer:
      case NotificationType.adminCardEditRequestStreamer:
      case NotificationType.adminNoteToOrg:
      case NotificationType.adminCardEditRequestOrg:
        return adminNotesEnabled;
      case NotificationType.systemAlert:
        return true;
    }
  }

  NotificationPreferencesModel copyWith({
    int? maxPer10Min,
    Set<String>? mutedEntityIds,
    bool? liveVideoEnabled,
    bool? liveAudioEnabled,
    bool? vodsEnabled,
    bool? watchMilestonesEnabled,
    bool? orgInvitesEnabled,
    bool? adminNotesEnabled,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) {
    return NotificationPreferencesModel(
      maxPer10Min: maxPer10Min ?? this.maxPer10Min,
      mutedEntityIds: mutedEntityIds ?? this.mutedEntityIds,
      liveVideoEnabled: liveVideoEnabled ?? this.liveVideoEnabled,
      liveAudioEnabled: liveAudioEnabled ?? this.liveAudioEnabled,
      vodsEnabled: vodsEnabled ?? this.vodsEnabled,
      watchMilestonesEnabled:
          watchMilestonesEnabled ?? this.watchMilestonesEnabled,
      orgInvitesEnabled: orgInvitesEnabled ?? this.orgInvitesEnabled,
      adminNotesEnabled: adminNotesEnabled ?? this.adminNotesEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }
}
