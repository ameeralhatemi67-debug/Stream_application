import '../../profile/models/upcoming_schedule.dart';
import '../../profile/models/vod_models.dart';

enum BookmarkKind { recording, upcoming }

/// A private saved reference, with enough public metadata to reopen it later.
class BookmarkEntry {
  const BookmarkEntry(
      {required this.id,
      required this.streamerId,
      required this.createdAt,
      this.kind = BookmarkKind.recording,
      this.vod,
      this.schedule,
      this.scheduleUnavailable = false});

  final String id, streamerId;
  final DateTime createdAt;
  final BookmarkKind kind;
  final VodModel? vod;
  final UpcomingSchedule? schedule;
  final bool scheduleUnavailable;

  static String recordingKey(String id) =>
      id.replaceFirst(RegExp(r'^vod_(yt|pl)_'), '');
  static String upcomingKey(String id) => 'upcoming:$id';

  factory BookmarkEntry.recording(VodModel vod) => BookmarkEntry(
      id: recordingKey(
          vod.youtubeVideoId.isEmpty ? vod.vodId : vod.youtubeVideoId),
      streamerId: vod.streamerId,
      createdAt: DateTime.now().toUtc(),
      vod: vod);

  factory BookmarkEntry.upcoming(UpcomingSchedule schedule) => BookmarkEntry(
      id: upcomingKey(schedule.id),
      kind: BookmarkKind.upcoming,
      streamerId: schedule.streamerId,
      createdAt: DateTime.now().toUtc(),
      schedule: schedule);

  factory BookmarkEntry.fromRow(Map<String, dynamic> row) {
    final kind = row['item_kind'] == 'upcoming'
        ? BookmarkKind.upcoming
        : BookmarkKind.recording;
    final metadata = Map<String, dynamic>.from(row['metadata'] as Map? ?? {});
    VodModel? vod;
    UpcomingSchedule? schedule;
    // Old saves have only an ID. A bad snapshot must not discard the library.
    try {
      if (kind == BookmarkKind.recording && metadata.isNotEmpty) {
        vod = VodModel.fromJson(metadata);
      } else if (kind == BookmarkKind.upcoming && metadata.isNotEmpty) {
        schedule = UpcomingSchedule.fromRow(metadata);
      }
    } catch (_) {/* Resolved from the public catalog on load. */}
    return BookmarkEntry(
        id: kind == BookmarkKind.recording
            ? recordingKey(row['vod_id'] as String)
            : row['vod_id'] as String,
        kind: kind,
        streamerId: row['streamer_id'] as String? ?? '',
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        vod: vod,
        schedule: schedule);
  }

  Map<String, dynamic> toRow() => {
        'vod_id': id,
        'streamer_id': streamerId,
        'item_kind': kind.name,
        'metadata': vod?.toJson() ??
            (schedule == null
                ? <String, dynamic>{}
                : {'id': schedule!.id, ...schedule!.toRow()}),
      };

  BookmarkEntry resolved(
          {VodModel? vod,
          UpcomingSchedule? schedule,
          bool scheduleUnavailable = false}) =>
      BookmarkEntry(
          id: id,
          streamerId: streamerId,
          createdAt: createdAt,
          kind: kind,
          vod: vod ?? this.vod,
          schedule: schedule ?? this.schedule,
          scheduleUnavailable: scheduleUnavailable);
}
