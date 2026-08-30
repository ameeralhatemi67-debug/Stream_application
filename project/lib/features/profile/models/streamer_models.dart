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

/// Exactly 5 Streamers representing AlSharqia Broadcasters (All initially offline)
final List<StreamerModel> mockStreamers = [
  const StreamerModel(
    streamerId: 'prof_alghamdi_01',
    fullNameEn: 'Amir Al-Hatemi',
    fullNameAr: 'أمير الحاتمي',
    titleEn: 'Computer Science & AI Specialist',
    titleAr: 'أخصائي علوم الحاسب والذكاء الاصطناعي',
    organizationEn: 'Multimedia University Graduate',
    organizationAr: 'خريج جامعة مالتيميديا',
    avatarUrl: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    bannerUrl: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
    bioEn: 'I like to build applications and software with AI, or using AI to boost productivity.',
    bioAr: 'أحب بناء التطبيقات والبرامج باستخدام الذكاء الاصطناعي، أو استخدام الذكاء الاصطناعي لزيادة الإنتاجية.',
    isVerified: true,
    followerCount: 14200,
    categoryId: 'cs_tech',
    tags: ['#AI', '#Cloud', '#Dev', '#Software'],
    cityEn: 'Dhahran',
    cityAr: 'الظهران',
    venueNameEn: 'KFUPM Innovation Hall',
    venueNameAr: 'قاعة الابتكار بجامعة الملك فهد للبترول والمعادن',
    latitude: 26.3042,
    longitude: 50.1462,
    isCurrentlyLive: false,
    activeStreamId: 'stream_live_992',
    activeViewerCount: 0,
    upcomingScheduleEn: [
      'Mon 10:00 AM - AI & Software Engineering',
      'Wed 02:00 PM - Productivity Tools with AI'
    ],
    upcomingScheduleAr: [
      'الاثنين 10:00 صباحاً - الذكاء الاصطناعي وهندسة البرمجيات',
      'الأربعاء 02:00 مساءً - أدوات الإنتاجية بالذكاء الاصطناعي'
    ],
    youtubeHandle: 'amiralhatime4831',
  ),
  const StreamerModel(
    streamerId: 'prof_otaibi_02',
    fullNameEn: 'Sheikh Ahmed Amer',
    fullNameAr: 'الداعية أحمد عامر',
    titleEn: 'Islamic Educator & Content Creator (@ahmedamercaller)',
    titleAr: 'داعية إسلامي وصانع محتوى (@ahmedamercaller)',
    organizationEn: 'Ahmed Amer YouTube Channel (@ahmedamercaller)',
    organizationAr: 'قناة الداعية أحمد عامر الرسمية',
    avatarUrl: 'assets/images/Ahmed_Amer_YouTube_files/Ahmed_Amer_profile.jpg',
    bannerUrl: 'assets/images/Ahmed_Amer_YouTube_files/Ahmed_Amer_banner.jpg',
    bioEn: 'Islamic scholar and educator focused on Quranic reflections, Seerah series, and the popular Istiraha podcast on YouTube (@ahmedamercaller).',
    bioAr: 'داعية إسلامي وصانع محتوى يركز على تدبر القرآن الكريم والسيرة النبوية وبودكاست استراحة على يوتيوب (@ahmedamercaller).',
    isVerified: true,
    followerCount: 45200,
    categoryId: 'islamic_studies',
    tags: ['#Sharia', '#Podcast', '#Quran', '#Seerah'],
    cityEn: 'Al Khobar',
    cityAr: 'الخبر',
    venueNameEn: 'Custodian of the Two Holy Mosques Grand Mosque',
    venueNameAr: 'جامع خادم الحرمين الشريفين الكبير بالخبر',
    latitude: 26.2871,
    longitude: 50.2125,
    isCurrentlyLive: false,
    activeViewerCount: 0,
    upcomingScheduleEn: [
      'Fri 05:00 PM - Istiraha Podcast Live Stream',
      'Sun 08:00 PM - Quranic Reflections & Seerah'
    ],
    upcomingScheduleAr: [
      'الجمعة 05:00 مساءً - بث مباشر بودكاست استراحة',
      'الأحد 08:00 مساءً - تدبر القرآن الكريم والسيرة'
    ],
    youtubeHandle: 'ahmedamercaller',
  ),
  const StreamerModel(
    streamerId: 'prof_dossary_03',
    fullNameEn: 'Bidon Waraq (Faisal Al-Aql)',
    fullNameAr: 'بودكاست بدون ورق (فيصل العقل)',
    titleEn: 'Arabic Podcast & Cultural Dialogue (@BidonWaraq)',
    titleAr: 'بودكاست حواري وثقافي (@BidonWaraq)',
    organizationEn: 'Bidon Waraq Channel (@BidonWaraq)',
    organizationAr: 'قناة بدون ورق الرسمية (@BidonWaraq)',
    avatarUrl: 'assets/images/BidonWaraq/BidonWaraq_profile.jpg',
    bannerUrl: 'assets/images/BidonWaraq/BidonWaraq_banner.jpg',
    bioEn: 'Bidon Waraq is a leading Arabic podcast hosted by Faisal Abdulrahman Al-Aql, featuring objective discussions and long-form interviews on psychology, history, personal development, and social topics.',
    bioAr: 'بودكاست بدون ورق يقدمه فيصل عبد الرحمن العقل، حوارات موضوعية ومقابلات مطولة حول النفس، التاريخ، التطوير الشخصي، والقضايا الاجتماعية.',
    isVerified: true,
    followerCount: 98500,
    categoryId: 'islamic_studies',
    tags: ['#Podcast', '#Culture', '#Dialogue', '#History'],
    cityEn: 'Al Khobar',
    cityAr: 'الخبر',
    venueNameEn: 'Al-Rahmah Grand Hall',
    venueNameAr: 'القاعة الكبرى بجامع الرحمة',
    latitude: 26.2750,
    longitude: 50.2010,
    isCurrentlyLive: false,
    activeViewerCount: 0,
    upcomingScheduleEn: [
      'Thu 09:00 PM - New Episode Live Broadcast'
    ],
    upcomingScheduleAr: [
      'الخميس 09:00 مساءً - بث مباشر لحلقة جديدة'
    ],
    youtubeHandle: 'BidonWaraq',
  ),
  const StreamerModel(
    streamerId: 'org_dalilk_04',
    fullNameEn: 'Dalilk 4 IELTS (Abdulrahman Hejazi)',
    fullNameAr: 'دليل الآيلتس (عبدالرحمن حجازي)',
    titleEn: 'Premier IELTS Preparation & English Academy (@dalilk4ielts)',
    titleAr: 'أكاديمية ودليل اختبار الآيلتس واللغة الإنجليزية (@dalilk4ielts)',
    organizationEn: 'Dalilk Educational Academy',
    organizationAr: 'أكاديمية دليل التعليمية',
    avatarUrl: 'assets/images/Dalilak/OrgMainProfile.jpg',
    bannerUrl: 'assets/images/Dalilak/OrgBanner.jpg',
    bioEn: 'Comprehensive IELTS test preparation, speaking simulations, vocabulary masterclasses, and linguistic development led by Abdulrahman Hejazi and certified academic trainers.',
    bioAr: 'المنصة التعليمية الرائدة للتحضير لاختبار الآيلتس وتطوير مهارات اللغة الإنجليزية يقدمها عبدالرحمن حجازي ونخبة من المدربين المعتمدين.',
    isVerified: true,
    isOrganization: true,
    followerCount: 385000,
    categoryId: 'languages_ielts',
    tags: ['#IELTS', '#English', '#Speaking', '#Vocabulary', '#Academy'],
    cityEn: 'Al Khobar / Rakah',
    cityAr: 'الخبر / الراكة',
    venueNameEn: 'Dalilk Academic Campus - Rakah HQ',
    venueNameAr: 'مقر أكاديمية دليل - الراكة الشمالية',
    latitude: 26.3580,
    longitude: 50.1860,
    isCurrentlyLive: false,
    activeViewerCount: 0,
    upcomingScheduleEn: [
      'Tue 08:00 PM - Live IELTS Speaking Simulation',
      'Sat 05:00 PM - Vocabulary Band 8 Masterclass'
    ],
    upcomingScheduleAr: [
      'الثلاثاء 08:00 مساءً - محاكاة اختبار محادثة الآيلتس لايف',
      'السبت 05:00 مساءً - ورشة مفردات الآيلتس للدرجة 8'
    ],
    youtubeHandle: 'dalilk4ielts',
    featuredChannelHandles: [
      'dalilk4english',
      'dalilk4english_podcast',
    ],
    venues: [
      OrgVenueBranchModel(
        venueId: 'dalilk_hq_khobar',
        nameEn: 'Khobar Academic Campus (Main HQ)',
        nameAr: 'المقر الأكاديمي بالخبر (الرئيسي)',
        cityEn: 'Al Khobar / Rakah',
        cityAr: 'الخبر / الراكة',
        latitude: 26.3580,
        longitude: 50.1860,
        seatingCapacity: 350,
        isMainHeadquarters: true,
        addressEn: 'Khalid Ibn Al-Walid St, Rakah, Al Khobar',
        addressAr: 'شارع خالد بن الوليد، الراكة، الخبر',
        availableFacilities: ['Fiber Broadcast AV', 'Interactive Stage', 'Soundproofing', 'Wi-Fi 6'],
      ),
      OrgVenueBranchModel(
        venueId: 'dalilk_branch_dhahran',
        nameEn: 'Dhahran Tech Innovation Hall',
        nameAr: 'قاعة الابتكار التقني بالظهران',
        cityEn: 'Dhahran',
        cityAr: 'الظهران',
        latitude: 26.3050,
        longitude: 50.1450,
        seatingCapacity: 150,
        addressEn: 'Dhahran Academic District',
        addressAr: 'حي الظهران الأكاديمي',
        availableFacilities: ['Studio Audio', 'Podcasting Booths'],
      ),
      OrgVenueBranchModel(
        venueId: 'dalilk_branch_dammam',
        nameEn: 'Dammam Executive Training Suite',
        nameAr: 'جناح التدريب التنفيذي بالدمام',
        cityEn: 'Dammam',
        cityAr: 'الدمام',
        latitude: 26.4207,
        longitude: 50.0888,
        seatingCapacity: 100,
        addressEn: 'Al Shati District, Dammam',
        addressAr: 'حي الشاطئ، الدمام',
        availableFacilities: ['4K Camera Array', 'Lecture Recording'],
      ),
    ],
    affiliatedSpeakers: [
      OrgSpeakerModel(
        speakerId: 'spk_abdulrahman',
        nameEn: 'Abdulrahman Hejazi',
        nameAr: 'عبدالرحمن حجازي',
        roleOrTitleEn: 'Founder & Lead IELTS Strategist',
        roleOrTitleAr: 'المؤسس وخبير استراتيجيات الآيلتس',
        avatarUrl: 'assets/images/Dalilak/profile1.jpg',
        bioEn: 'Founder of Dalilk 4 IELTS with over 10 years of experience helping thousands achieve Band 8+.',
        bioAr: 'مؤسس دليل الآيلتس بخبرة تزيد عن 10 سنوات في تمكين آلاف الطلاب من تحقيق درجات 8+.',
        isPermanentStaff: true,
        linkedEmail: 'abdulrahman@dalilk.com',
        youtubeHandle: 'dalilk4ielts',
      ),
      OrgSpeakerModel(
        speakerId: 'spk_sarah',
        nameEn: 'Dr. Sarah Al-Dosari',
        nameAr: 'د. سارة الدوسري',
        roleOrTitleEn: 'Senior IELTS Speaking & Writing Specialist',
        roleOrTitleAr: 'أخصائية أولى في محادثة وكتابة الآيلتس',
        avatarUrl: 'assets/images/Dalilak/profile2.jpg',
        bioEn: 'Expert in IELTS examiner criteria, fluency development, and writing task evaluation.',
        bioAr: 'خبيرة في معايير مصححي الآيلتس وتطوير الطلاقة وتقييم مهام الكتابة.',
        isPermanentStaff: true,
        linkedEmail: 'sarah@dalilk.com',
        youtubeHandle: 'dalilk4english',
      ),
      OrgSpeakerModel(
        speakerId: 'spk_alex',
        nameEn: 'Alex Thompson',
        nameAr: 'أليكس تومسون',
        roleOrTitleEn: 'Native English & Phonetics Coach',
        roleOrTitleAr: 'مدرب النطق ومحادثة اللغة الإنجليزية',
        avatarUrl: 'assets/images/Dalilak/profile3.jpg',
        bioEn: 'Certified linguist specializing in accent reduction, everyday idioms, and conversational mastery.',
        bioAr: 'لغوي معتمد متخصص في تصحيح النطق والتعابير اليومية وإتقان المحادثة.',
        isPermanentStaff: false,
        linkedEmail: 'alex@dalilk.com',
        youtubeHandle: 'dalilk4english_podcast',
      ),
    ],
  ),
  const StreamerModel(
    streamerId: 'quran_4k_05',
    fullNameEn: 'Al Quran 4K (Holy Quran Live)',
    fullNameAr: 'إذاعة القرآن الكريم (بث مباشر 4K)',
    titleEn: '24/7 Holy Quran Recitations & Live Audio (@AlQuran4KOfficial)',
    titleAr: 'تلاوات خاشعة وبث مباشر للقرآن الكريم 24/7 (@AlQuran4KOfficial)',
    organizationEn: 'Al Quran 4K Channel (@AlQuran4KOfficial)',
    organizationAr: 'قناة إذاعة القرآن الكريم الرسمية',
    avatarUrl: 'assets/images/quran/Quran_profile.jpg',
    bannerUrl: 'assets/images/quran/Quran_banner.jpg',
    bioEn: '24/7 Continuous spiritual broadcast featuring serene and heart-touching Holy Quran recitations from Mecca, Medina, and world-renowned reciters in ultra-high quality audio.',
    bioAr: 'بث مباشر متواصل على مدار الساعة لتلاوات خاشعة من القرآن الكريم بأصوات نخبة من كبار القراء والحرمين الشريفين بجودة صوتية نقية وعالية.',
    isVerified: true,
    followerCount: 2850000,
    categoryId: 'islamic_studies',
    tags: ['#Quran', '#LiveAudio', '#Tilawah', '#Makkah', '#Madinah', '#Islamic'],
    cityEn: 'Al Khobar / Al-Hizam',
    cityAr: 'الخبر / الحزام الذهبي',
    venueNameEn: 'Al-Gosaibi Holy Quran Center',
    venueNameAr: 'مركز القصيبي لعلوم القرآن الكريم بالخبر',
    latitude: 26.2650,
    longitude: 50.2030,
    isCurrentlyLive: true,
    broadcastType: BroadcastType.liveAudio,
    activeStreamId: 'stream_quran_live_audio',
    activeViewerCount: 18450,
    upcomingScheduleEn: [
      '24/7 Live Continuous Holy Quran Audio Stream',
      'Daily Tahajjud & Taraweeh Recitations'
    ],
    upcomingScheduleAr: [
      'بث صوتي مباشر متواصل للقرآن الكريم 24/7',
      'تلاوات التهجد والتراويح اليومية'
    ],
    youtubeHandle: 'AlQuran4KOfficial',
    youtubeVideoId: 'jjBoecWjAnw',
    fallbackYoutubeVideoIds: ['PLkCnLrKN8Q', 'hPeOq1Dz5xI'],
  ),
];
