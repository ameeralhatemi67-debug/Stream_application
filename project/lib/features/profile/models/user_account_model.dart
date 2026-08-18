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
    this.totalLectureHours = 142,
    this.totalSubscribers = 14200,
    this.isVerifiedScholar = true,
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

  static const defaultProfile = UserProfileModel(
    id: 'prof_alghamdi_01',
    nameEn: 'Amir Al-Hatemi',
    nameAr: 'أمير الحاتمي',
    titleEn: 'Computer Science & AI Specialist',
    titleAr: 'أخصائي علوم الحاسب والذكاء الاصطناعي',
    organizationEn: 'Multimedia University Graduate',
    organizationAr: 'خريج جامعة مالتيميديا',
    bioEn: 'I like to build applications and software with AI, or using AI to boost productivity.',
    bioAr: 'أحب بناء التطبيقات والبرامج باستخدام الذكاء الاصطناعي، أو استخدام الذكاء الاصطناعي لزيادة الإنتاجية.',
    avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
    youtubeChannelUrl: 'https://youtube.com/@amiralhatime4831',
    locationCity: 'Al Khobar / Dhahran',
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
