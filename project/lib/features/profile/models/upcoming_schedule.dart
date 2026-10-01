import 'package:flutter/material.dart';

/// A planned announcement, independent of YouTube and live-session state.
@immutable
class UpcomingSchedule {
  const UpcomingSchedule({
    required this.id,
    required this.streamerId,
    required this.kind,
    required this.localTime,
    required this.weekdays,
    required this.oneTimeStartUtc,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.tags,
    required this.colorKey,
    this.organizationId,
    this.venueId,
    this.broadcastType = 'liveVideo',
    this.durationMinutes = 60,
  });

  final String id;
  final String streamerId;
  final String kind; // weekly or once
  final String localTime; // HH:mm in Asia/Riyadh
  final List<int> weekdays; // ISO 1=Monday ... 7=Sunday
  final DateTime? oneTimeStartUtc;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final List<String> tags;
  final String colorKey;
  final String? organizationId, venueId;
  final String broadcastType;
  final int durationMinutes;

  bool get isSpecial => kind == 'once';

  String title(String language) => language == 'ar'
      ? (titleAr.isNotEmpty ? titleAr : titleEn)
      : (titleEn.isNotEmpty ? titleEn : titleAr);

  String description(String language) => language == 'ar'
      ? (descriptionAr.isNotEmpty ? descriptionAr : descriptionEn)
      : (descriptionEn.isNotEmpty ? descriptionEn : descriptionAr);

  /// All recurrence arithmetic uses Saudi civil time, regardless of device TZ.
  DateTime? nextStartUtc(DateTime after) {
    final now = after.toUtc();
    if (isSpecial) {
      final start = oneTimeStartUtc?.toUtc();
      return start != null && start.isAfter(now) ? start : null;
    }
    if (weekdays.isEmpty) return null;
    final parts = localTime.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    final saudiNow = now.add(const Duration(hours: 3));
    for (var days = 0; days <= 7; days++) {
      final localDay = DateTime.utc(
          saudiNow.year, saudiNow.month, saudiNow.day + days, hour, minute);
      if (!weekdays.contains(localDay.weekday)) continue;
      final start = localDay.subtract(const Duration(hours: 3));
      if (start.isAfter(now)) return start;
    }
    return null;
  }

  factory UpcomingSchedule.fromRow(Map<String, dynamic> row) =>
      UpcomingSchedule(
        id: row['id'] as String,
        streamerId: row['streamer_profile_id'] as String,
        kind: row['kind'] as String,
        localTime: (row['local_time'] as String? ?? '00:00').substring(0, 5),
        weekdays: (row['weekdays'] as List? ?? const []).cast<int>(),
        oneTimeStartUtc:
            DateTime.tryParse(row['one_time_start_at'] as String? ?? ''),
        titleEn: row['title_en'] as String? ?? '',
        titleAr: row['title_ar'] as String? ?? '',
        descriptionEn: row['description_en'] as String? ?? '',
        descriptionAr: row['description_ar'] as String? ?? '',
        tags: (row['tags'] as List? ?? const []).cast<String>(),
        colorKey: row['color_key'] as String? ?? 'green',
        organizationId: row['organization_id'] as String?,
        venueId: row['venue_id'] as String?,
        broadcastType: row['broadcast_type'] as String? ?? 'liveVideo',
        durationMinutes: (row['duration_minutes'] as num?)?.toInt() ?? 60,
      );

  Map<String, dynamic> toRow() => {
        'streamer_profile_id': streamerId,
        'kind': kind,
        'local_time': localTime,
        'weekdays': weekdays,
        'one_time_start_at': oneTimeStartUtc?.toUtc().toIso8601String(),
        'title_en': titleEn.trim(),
        'title_ar': titleAr.trim(),
        'description_en': descriptionEn.trim(),
        'description_ar': descriptionAr.trim(),
        'tags': tags,
        'color_key': colorKey,
        if (organizationId != null) 'organization_id': organizationId,
        if (venueId != null) 'venue_id': venueId,
        'broadcast_type': broadcastType,
        'duration_minutes': durationMinutes,
      };
}
