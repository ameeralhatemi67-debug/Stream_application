class UserProfileModel {
  final String id;
  final String nameEn;
  final String nameAr;
  final String titleEn;
  final String titleAr;
  final String organizationEn;
  final String organizationAr;
  final String bioEn;
  final String bioAr;
  final String avatarUrl;
  final String bannerUrl;
  final String youtubeChannelUrl;
  final String locationCity;
  final int totalLectureHours;
  final int totalSubscribers;
  final bool isVerifiedScholar;

  const UserProfileModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.titleEn,
    required this.titleAr,
    required this.organizationEn,
    required this.organizationAr,
    required this.bioEn,
    required this.bioAr,
    required this.avatarUrl,
    required this.bannerUrl,
    required this.youtubeChannelUrl,
    required this.locationCity,
    this.totalLectureHours = 0,
    this.totalSubscribers = 0,
    // Verification is granted by the backend (user_roles / profiles), never
    // assumed client-side (P1.6).
    this.isVerifiedScholar = false,
  });

  UserProfileModel copyWith({
    String? nameEn,
    String? nameAr,
    String? titleEn,
    String? titleAr,
    String? organizationEn,
    String? organizationAr,
    String? bioEn,
    String? bioAr,
    String? avatarUrl,
    String? bannerUrl,
    String? youtubeChannelUrl,
    String? locationCity,
    int? totalLectureHours,
    int? totalSubscribers,
    bool? isVerifiedScholar,
  }) {
    return UserProfileModel(
      id: id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      titleEn: titleEn ?? this.titleEn,
      titleAr: titleAr ?? this.titleAr,
      organizationEn: organizationEn ?? this.organizationEn,
      organizationAr: organizationAr ?? this.organizationAr,
      bioEn: bioEn ?? this.bioEn,
      bioAr: bioAr ?? this.bioAr,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      youtubeChannelUrl: youtubeChannelUrl ?? this.youtubeChannelUrl,
      locationCity: locationCity ?? this.locationCity,
      totalLectureHours: totalLectureHours ?? this.totalLectureHours,
      totalSubscribers: totalSubscribers ?? this.totalSubscribers,
      isVerifiedScholar: isVerifiedScholar ?? this.isVerifiedScholar,
    );
  }

  /// The profile of an account that has not loaded (or does not have) a real
  /// profile yet: empty, not a developer's identity. Before P1.6 this carried
  /// a real person's name, photo, bio and YouTube channel, so every signed-out
  /// or unconfigured account rendered — and pre-filled forms with — that
  /// identity (issue_log.md: three accounts all showing "Amir Al-Hatemi").
  static const defaultProfile = UserProfileModel(
    id: '',
    nameEn: '',
    nameAr: '',
    titleEn: '',
    titleAr: '',
    organizationEn: '',
    organizationAr: '',
    bioEn: '',
    bioAr: '',
    avatarUrl: '',
    bannerUrl: '',
    youtubeChannelUrl: '',
    locationCity: '',
  );
}

class AppNotificationItem {
  final String id;
  final String streamerId;
  final String titleEn;
  final String titleAr;
  final String bodyEn;
  final String bodyAr;
  final DateTime timestamp;
  final String? streamId;
  final bool isLiveAlert;
  bool isRead;

  AppNotificationItem({
    required this.id,
    this.streamerId = '',
    required this.titleEn,
    required this.titleAr,
    required this.bodyEn,
    required this.bodyAr,
    required this.timestamp,
    this.streamId,
    this.isLiveAlert = false,
    this.isRead = false,
  });
}
