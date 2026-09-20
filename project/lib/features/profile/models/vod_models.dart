/// Model class representing archived VOD (Video-on-Demand) lectures.
class VodModel {
  final String vodId;
  final String streamerId;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final String youtubeVideoId;
  final int durationSeconds;
  final String recordedDate;
  final String thumbnailUrl;
  final int viewCount;
  final List<String> speakerIds;
  final String? venueId;

  const VodModel({
    required this.vodId,
    required this.streamerId,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.youtubeVideoId,
    required this.durationSeconds,
    required this.recordedDate,
    required this.thumbnailUrl,
    required this.viewCount,
    this.speakerIds = const [],
    this.venueId,
  });

  /// Returns localized title according to active [languageCode] ('ar' or 'en').
  String getLocalizedTitle(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;

  /// Returns localized description according to active [languageCode].
  String getLocalizedDescription(String languageCode) =>
      languageCode == 'ar' ? descriptionAr : descriptionEn;

  /// Human-readable duration string (e.g. "54:00" or "1h 15m").
  String get formattedDuration {
    final duration = Duration(seconds: durationSeconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      final formattedMin = minutes.toString().padLeft(2, '0');
      final formattedSec = seconds.toString().padLeft(2, '0');
      return '$formattedMin:$formattedSec';
    }
  }

  String get durationString => formattedDuration;
  String get categoryTag => 'Academic Lecture';

  factory VodModel.fromJson(Map<String, dynamic> json) {
    return VodModel(
      vodId: json['vod_id'] as String,
      streamerId: json['streamer_id'] as String,
      titleEn: json['title_en'] as String,
      titleAr: json['title_ar'] as String,
      descriptionEn: json['description_en'] as String,
      descriptionAr: json['description_ar'] as String,
      youtubeVideoId: json['youtube_video_id'] as String,
      durationSeconds: json['duration_seconds'] as int,
      recordedDate: json['recorded_date'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
      viewCount: json['view_count'] as int,
      speakerIds: (json['speaker_ids'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      venueId: json['venue_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vod_id': vodId,
      'streamer_id': streamerId,
      'title_en': titleEn,
      'title_ar': titleAr,
      'description_en': descriptionEn,
      'description_ar': descriptionAr,
      'youtube_video_id': youtubeVideoId,
      'duration_seconds': durationSeconds,
      'recorded_date': recordedDate,
      'thumbnail_url': thumbnailUrl,
      'view_count': viewCount,
      'speaker_ids': speakerIds,
      'venue_id': venueId,
    };
  }

  VodModel copyWith({
    String? vodId,
    String? streamerId,
    String? titleEn,
    String? titleAr,
    String? descriptionEn,
    String? descriptionAr,
    String? youtubeVideoId,
    int? durationSeconds,
    String? recordedDate,
    String? thumbnailUrl,
    int? viewCount,
    List<String>? speakerIds,
    String? venueId,
  }) {
    return VodModel(
      vodId: vodId ?? this.vodId,
      streamerId: streamerId ?? this.streamerId,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionAr: descriptionAr ?? this.descriptionAr,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      recordedDate: recordedDate ?? this.recordedDate,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      viewCount: viewCount ?? this.viewCount,
      speakerIds: speakerIds ?? this.speakerIds,
      venueId: venueId ?? this.venueId,
    );
  }
}

/// Model class representing a YouTube Playlist collection
class PlaylistModel {
  final String playlistId;
  final String streamerId;
  final String titleEn;
  final String titleAr;
  final String descriptionEn;
  final String descriptionAr;
  final String youtubePlaylistUrl;
  final String thumbnailUrl;
  final int videoCount;
  final List<VodModel> videos;
  final List<String> speakerIds;
  final String? channelHandle;

  const PlaylistModel({
    required this.playlistId,
    required this.streamerId,
    required this.titleEn,
    required this.titleAr,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.youtubePlaylistUrl,
    required this.thumbnailUrl,
    required this.videoCount,
    required this.videos,
    this.speakerIds = const [],
    this.channelHandle,
  });

  String getLocalizedTitle(String lang) => lang == 'ar' ? titleAr : titleEn;
  String getLocalizedDescription(String lang) => lang == 'ar' ? descriptionAr : descriptionEn;
}
