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
        totalGuestSessions: (json['totalGuestSessions'] as num?)?.toInt() ?? 1250,
        totalRegisteredGoogleUsers:
            (json['totalRegisteredGoogleUsers'] as num?)?.toInt() ?? 170,
        totalLectureBookmarks:
            (json['totalLectureBookmarks'] as num?)?.toInt() ?? 890,
        totalAuditoriumRsvps:
            (json['totalAuditoriumRsvps'] as num?)?.toInt() ?? 340,
        totalBroadcastHours:
            (json['totalBroadcastHours'] as num?)?.toDouble() ?? 142.5,
        activeViewersLive:
            (json['activeViewersLive'] as num?)?.toInt() ?? 342,
        lastRefreshed: DateTime.parse(
            json['lastRefreshed'] as String? ?? DateTime.now().toIso8601String()),
      );

  static ViewerAnalyticsModel createDefault() {
    return ViewerAnalyticsModel(
      totalGuestSessions: 1420,
      totalRegisteredGoogleUsers: 185,
      totalLectureBookmarks: 920,
      totalAuditoriumRsvps: 365,
      totalBroadcastHours: 156.4,
      activeViewersLive: 342,
      lastRefreshed: DateTime.now(),
    );
  }
}
