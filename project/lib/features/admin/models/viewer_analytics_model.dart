import 'package:flutter/foundation.dart';

/// Aggregated Engagement and Viewers Analytics Model for Admin Hub
@immutable
class ViewerAnalyticsModel {
  final int totalGuestSessions;
  final int totalRegisteredGoogleUsers;
  final int totalLectureBookmarks;
  final int totalAuditoriumRsvps;
  final double totalBroadcastHours;
  final int activeViewersLive;
  final DateTime lastRefreshed;

  const ViewerAnalyticsModel({
    required this.totalGuestSessions,
    required this.totalRegisteredGoogleUsers,
    required this.totalLectureBookmarks,
    required this.totalAuditoriumRsvps,
    required this.totalBroadcastHours,
    required this.activeViewersLive,
    required this.lastRefreshed,
  });

  Map<String, dynamic> toJson() => {
        'totalGuestSessions': totalGuestSessions,
        'totalRegisteredGoogleUsers': totalRegisteredGoogleUsers,
        'totalLectureBookmarks': totalLectureBookmarks,
        'totalAuditoriumRsvps': totalAuditoriumRsvps,
        'totalBroadcastHours': totalBroadcastHours,
        'activeViewersLive': activeViewersLive,
        'lastRefreshed': lastRefreshed.toIso8601String(),
      };

  factory ViewerAnalyticsModel.fromJson(Map<String, dynamic> json) =>
      ViewerAnalyticsModel(
        totalGuestSessions: (json['totalGuestSessions'] as num?)?.toInt() ?? 0,
        totalRegisteredGoogleUsers:
            (json['totalRegisteredGoogleUsers'] as num?)?.toInt() ?? 0,
        totalLectureBookmarks:
            (json['totalLectureBookmarks'] as num?)?.toInt() ?? 0,
        totalAuditoriumRsvps:
            (json['totalAuditoriumRsvps'] as num?)?.toInt() ?? 0,
        totalBroadcastHours:
            (json['totalBroadcastHours'] as num?)?.toDouble() ?? 0,
        activeViewersLive:
            (json['activeViewersLive'] as num?)?.toInt() ?? 0,
        lastRefreshed: DateTime.parse(
            json['lastRefreshed'] as String? ?? DateTime.now().toIso8601String()),
      );

  static ViewerAnalyticsModel createDefault() {
    return ViewerAnalyticsModel(
      totalGuestSessions: 0,
      totalRegisteredGoogleUsers: 0,
      totalLectureBookmarks: 0,
      totalAuditoriumRsvps: 0,
      totalBroadcastHours: 0,
      activeViewersLive: 0,
      lastRefreshed: DateTime.now(),
    );
  }
}
