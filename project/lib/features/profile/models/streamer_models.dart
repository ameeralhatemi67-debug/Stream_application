import '../../organization/models/org_speaker_model.dart';
import '../../organization/models/org_venue_branch_model.dart';

enum BroadcasterStatus { live, offline }

enum BroadcastType {
  offline,
  liveVideo,
  liveAudio,
}

class StreamerModel {
  final String streamerId;
  final String fullNameEn;
  final String fullNameAr;
  final String titleEn;
  final String titleAr;
  final String organizationEn;
  final String organizationAr;
  final String avatarUrl;
  final String bannerUrl;
  final String bioEn;
  final String bioAr;
  final bool isVerified;
  final int followerCount;
  final String categoryId;
  final List<String> tags;
  final String cityEn;
  final String cityAr;
  final String venueNameEn;
  final String venueNameAr;
  final double latitude;
  final double longitude;
  final bool isCurrentlyLive;
  final BroadcastType broadcastType;
  final bool isOrganization;
  final String? activeStreamId;
  final int activeViewerCount;
  final List<String> upcomingScheduleEn;
  final List<String> upcomingScheduleAr;
  final String youtubeHandle;
  final String youtubeVideoId;
  final List<String> fallbackYoutubeVideoIds;
  final List<OrgVenueBranchModel> venues;
  final List<OrgSpeakerModel> affiliatedSpeakers;
  final List<String> featuredChannelHandles;
  final String? activeLiveVenueId;
  final List<String> activeLiveSpeakerIds;

  /// Cluster 4 Task 18: an admin can temporarily pull this streamer's marker
  /// off the Spatial Map (moderation action short of a full ban) without
  /// touching their profile -- it stays reachable by direct link. Mirrors
  /// profiles.is_temporarily_hidden_from_map / organizations.is_temporarily_hidden_from_map.
  final bool isTemporarilyHiddenFromMap;

  const StreamerModel({
    required this.streamerId,
    required this.fullNameEn,
    required this.fullNameAr,
    required this.titleEn,
    required this.titleAr,
    required this.organizationEn,
    required this.organizationAr,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.bioEn,
    required this.bioAr,
    required this.isVerified,
    required this.followerCount,
    required this.categoryId,
    this.tags = const [],
    required this.cityEn,
    required this.cityAr,
    required this.venueNameEn,
    required this.venueNameAr,
    required this.latitude,
    required this.longitude,
    required this.isCurrentlyLive,
    this.broadcastType = BroadcastType.offline,
    this.isOrganization = false,
    this.activeStreamId,
    this.activeViewerCount = 0,
    this.upcomingScheduleEn = const [],
    this.upcomingScheduleAr = const [],
    this.youtubeHandle = 'ahmedamercaller',
    this.youtubeVideoId = 'dQw4w9WgXcQ',
    this.fallbackYoutubeVideoIds = const [],
    this.venues = const [],
    this.affiliatedSpeakers = const [],
    this.featuredChannelHandles = const [],
    this.activeLiveVenueId,
    this.activeLiveSpeakerIds = const [],
    this.isTemporarilyHiddenFromMap = false,
  });

  BroadcastType get activeBroadcastType {
    if (!isCurrentlyLive) return BroadcastType.offline;
    return broadcastType == BroadcastType.offline ? BroadcastType.liveVideo : broadcastType;
  }

  bool get isVideoLive => isCurrentlyLive && (activeBroadcastType == BroadcastType.liveVideo);
  bool get isAudioLive => isCurrentlyLive && (activeBroadcastType == BroadcastType.liveAudio);

  BroadcasterStatus get status =>
      isCurrentlyLive ? BroadcasterStatus.live : BroadcasterStatus.offline;

  String getLocalizedName(String languageCode) =>
      languageCode == 'ar' ? fullNameAr : fullNameEn;

  String getLocalizedTitle(String languageCode) =>
      languageCode == 'ar' ? titleAr : titleEn;

  String getLocalizedOrganization(String languageCode) =>
      languageCode == 'ar' ? organizationAr : organizationEn;

  String getLocalizedBio(String languageCode) =>
      languageCode == 'ar' ? bioAr : bioEn;

  String getLocalizedCity(String languageCode) =>
      languageCode == 'ar' ? cityAr : cityEn;

  String getLocalizedVenue(String languageCode) =>
      languageCode == 'ar' ? venueNameAr : venueNameEn;

  String get venueAddressEn => venueNameEn;
  String get venueAddressAr => venueNameAr;
  String get streamThumbnailUrl => bannerUrl;
  String get cloudStreamUrl => 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8';

  List<String> getLocalizedSchedule(String languageCode) =>
      languageCode == 'ar' ? upcomingScheduleAr : upcomingScheduleEn;

  OrgVenueBranchModel? get mainVenue {
    if (venues.isEmpty) return null;
    return venues.firstWhere((v) => v.isMainHeadquarters, orElse: () => venues.first);
  }

  OrgVenueBranchModel? get currentActiveVenue {
    if (activeLiveVenueId == null || venues.isEmpty) return mainVenue;
    return venues.firstWhere((v) => v.venueId == activeLiveVenueId, orElse: () => venues.first);
  }

  List<OrgSpeakerModel> get currentActiveSpeakers {
    if (activeLiveSpeakerIds.isEmpty || affiliatedSpeakers.isEmpty) return const [];
    return affiliatedSpeakers.where((s) => activeLiveSpeakerIds.contains(s.speakerId)).toList();
  }

  StreamerModel copyWith({
    String? streamerId,
    String? fullNameEn,
    String? fullNameAr,
    String? titleEn,
    String? titleAr,
    String? organizationEn,
    String? organizationAr,
    String? avatarUrl,
    String? bannerUrl,
    String? bioEn,
    String? bioAr,
    bool? isVerified,
    int? followerCount,
    String? categoryId,
    List<String>? tags,
    String? cityEn,
    String? cityAr,
    String? venueNameEn,
    String? venueNameAr,
    double? latitude,
    double? longitude,
    bool? isCurrentlyLive,
    BroadcastType? broadcastType,
    bool? isOrganization,
    String? activeStreamId,
    int? activeViewerCount,
    List<String>? upcomingScheduleEn,
    List<String>? upcomingScheduleAr,
    String? youtubeHandle,
    String? youtubeVideoId,
    List<String>? fallbackYoutubeVideoIds,
    List<OrgVenueBranchModel>? venues,
    List<OrgSpeakerModel>? affiliatedSpeakers,
    List<String>? featuredChannelHandles,
    String? activeLiveVenueId,
    List<String>? activeLiveSpeakerIds,
    bool? isTemporarilyHiddenFromMap,
  }) {
    return StreamerModel(
      streamerId: streamerId ?? this.streamerId,
      fullNameEn: fullNameEn ?? this.fullNameEn,
      fullNameAr: fullNameAr ?? this.fullNameAr,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      organizationEn: organizationEn ?? this.organizationEn,
      organizationAr: organizationAr ?? this.organizationAr,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bioEn: bioEn ?? this.bioEn,
      bioAr: bioAr ?? this.bioAr,
      isVerified: isVerified ?? this.isVerified,
      followerCount: followerCount ?? this.followerCount,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      cityEn: cityEn ?? this.cityEn,
      cityAr: cityAr ?? this.cityAr,
      venueNameEn: venueNameEn ?? this.venueNameEn,
      venueNameAr: venueNameAr ?? this.venueNameAr,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isCurrentlyLive: isCurrentlyLive ?? this.isCurrentlyLive,
      broadcastType: broadcastType ?? this.broadcastType,
      isOrganization: isOrganization ?? this.isOrganization,
      activeStreamId: activeStreamId ?? this.activeStreamId,
      activeViewerCount: activeViewerCount ?? this.activeViewerCount,
      upcomingScheduleEn: upcomingScheduleEn ?? this.upcomingScheduleEn,
      upcomingScheduleAr: upcomingScheduleAr ?? this.upcomingScheduleAr,
      youtubeHandle: youtubeHandle ?? this.youtubeHandle,
      youtubeVideoId: youtubeVideoId ?? this.youtubeVideoId,
      fallbackYoutubeVideoIds: fallbackYoutubeVideoIds ?? this.fallbackYoutubeVideoIds,
      venues: venues ?? this.venues,
      affiliatedSpeakers: affiliatedSpeakers ?? this.affiliatedSpeakers,
      featuredChannelHandles: featuredChannelHandles ?? this.featuredChannelHandles,
      activeLiveVenueId: activeLiveVenueId ?? this.activeLiveVenueId,
      activeLiveSpeakerIds: activeLiveSpeakerIds ?? this.activeLiveSpeakerIds,
      isTemporarilyHiddenFromMap:
          isTemporarilyHiddenFromMap ?? this.isTemporarilyHiddenFromMap,
    );
  }
}
