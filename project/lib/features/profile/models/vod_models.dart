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

/// Collection of mock archived VOD lectures for testing profile VOD grids and modal video players.
class MockVodArchivePool {
  static const List<VodModel> sampleVods = [
    VodModel(
      vodId: 'vod_lecture_804',
      streamerId: 'prof_alghamdi_01',
      titleEn: 'Introduction to Distributed Microservices Architecture',
      titleAr: 'مقدمة في معمارية الخدمات المصغرة الموزعة',
      descriptionEn: 'Recorded past lecture at KFUPM covering REST APIs, gRPC, and container orchestration.',
      descriptionAr: 'تسجيل محاضرة سابقة بجامعة الملك فهد تغطي واجهات REST، وgRPC، وحاويات التطبيقات.',
      youtubeVideoId: '9bZkp7q19f0',
      durationSeconds: 3240,
      recordedDate: '2026-07-20',
      thumbnailUrl: 'assets/images/vods/microservices_thumb.jpg',
      viewCount: 2840,
    ),
    VodModel(
      vodId: 'vod_lecture_805',
      streamerId: 'prof_alghamdi_01',
      titleEn: 'Cloud Edge Nodes & Low Latency Networking in KSA',
      titleAr: 'عقد الحافة السحابية والشبكات منخفضة الاستجابة في المملكة',
      descriptionEn: 'Detailed presentation on establishing Saudi cloud zones and edge compute points.',
      descriptionAr: 'عرض تفصيلي عن إنشاء مناطق السحاب السعودية ونقاط الحوسبة الطرفية.',
      youtubeVideoId: 'dQw4w9WgXcQ',
      durationSeconds: 2700,
      recordedDate: '2026-07-15',
      thumbnailUrl: 'assets/images/vods/edge_nodes_thumb.jpg',
      viewCount: 4120,
    ),
    VodModel(
      vodId: 'vod_lecture_806',
      streamerId: 'dr_nora_02',
      titleEn: 'AI Models in Healthcare & Medical Imaging Diagnostics',
      titleAr: 'نماذج الذكاء الاصطناعي في الرعاية الصحية وتشخيص الصور الطبية',
      descriptionEn: 'Imam Abdulrahman Bin Faisal University seminar on AI applications in Saudi hospitals.',
      descriptionAr: 'ندوة جامعة الإمام عبد الرحمن بن فيصل حول تطبيقات الذكاء الاصطناعي في المستشفيات السعودية.',
      youtubeVideoId: 'L_LUpnjgPso',
      durationSeconds: 4050,
      recordedDate: '2026-07-10',
      thumbnailUrl: 'assets/images/vods/ai_health_thumb.jpg',
      viewCount: 1950,
    ),
    VodModel(
      vodId: 'vod_amer_101',
      streamerId: 'prof_otaibi_02',
      titleEn: 'Istiraha Podcast - Ep. 1: Spiritual Rest & Quranic Lessons (@ahmedamercaller)',
      titleAr: 'بودكاست استراحة - الحلقة 1: الاستراحة الإيمانية وتدبر القرآن (@ahmedamercaller)',
      descriptionEn: 'Episode 1 from official playlist PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9 on @ahmedamercaller channel.',
      descriptionAr: 'الحلقة الأولى من قائمة التشغيل الرسمية PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9 على قناة الداعية أحمد عامر.',
      youtubeVideoId: 'M7lc1UVf-VE',
      durationSeconds: 3240,
      recordedDate: '2026-08-01',
      thumbnailUrl: 'assets/images/Ahmed_Amer_YouTube_files/Ahmed_Amer_profile.jpg',
      viewCount: 15400,
    ),
    VodModel(
      vodId: 'vod_amer_102',
      streamerId: 'prof_otaibi_02',
      titleEn: 'Prophetic Seerah & Companions Reflections - Sheikh Ahmed Amer',
      titleAr: 'قصص السيرة النبوية والمواقف الإيمانية - الداعية أحمد عامر',
      descriptionEn: 'Special lecture on the life of the Prophet Muhammad (PBUH) and the noble Sahaba from @ahmedamercaller.',
      descriptionAr: 'محاضرة خاصة في سيرة النبي صلى الله عليه وسلم والصحابة الكرام من سلسلة الداعية أحمد عامر.',
      youtubeVideoId: 'fJ9rUzIMcZQ',
      durationSeconds: 2850,
      recordedDate: '2026-07-28',
      thumbnailUrl: 'assets/images/Ahmed_Amer_YouTube_files/Ahmed_Amer_banner.jpg',
      viewCount: 22800,
    ),
    VodModel(
      vodId: 'vod_amer_103',
      streamerId: 'prof_otaibi_02',
      titleEn: 'Quranic Stories & Modern Dawah Reflections - Ahmed Amer',
      titleAr: 'تأملات في قصص القرآن والدعوة المعاصرة - أحمد عامر',
      descriptionEn: 'Deep-dive session examining Quranic parables and spiritual lessons for youth.',
      descriptionAr: 'جلسة تدبرية عميقة تناقش أمثال القرآن الكريم والدروس الإيمانية للشباب.',
      youtubeVideoId: 'bHQqvYy5KYo',
      durationSeconds: 3600,
      recordedDate: '2026-07-22',
      thumbnailUrl: 'assets/images/Ahmed_Amer_YouTube_files/Ahmed_Amer_profile.jpg',
      viewCount: 18900,
    ),
    // Dalilk 4 IELTS Sample VODs (Organization Tier)
    VodModel(
      vodId: 'vod_dalilk_201',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_abdulrahman'],
      venueId: 'dalilk_hq_khobar',
      titleEn: 'IELTS Band 8+ Master Strategy & Roadmap (@dalilk4ielts)',
      titleAr: 'خطة وخريطة طريق تحقيق درجة +8 في الآيلتس (@dalilk4ielts)',
      descriptionEn: 'Comprehensive masterclass on IELTS test structure, time management, and achieving top scores.',
      descriptionAr: 'محاضرة شاملة حول معايير اختبار الآيلتس، وإدارة الوقت، وكيفية تحقيق أعلى الدرجات.',
      youtubeVideoId: 'dQw4w9WgXcQ',
      durationSeconds: 3420,
      recordedDate: '2026-08-10',
      thumbnailUrl: 'assets/images/Dalilak/profile1.jpg',
      viewCount: 42300,
    ),
    VodModel(
      vodId: 'vod_dalilk_202',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_sarah'],
      venueId: 'dalilk_branch_dhahran',
      titleEn: 'IELTS Speaking Part 2 & 3 Simulation with Live Feedback',
      titleAr: 'محاكاة اختبار محادثة الآيلتس الجزء 2 و 3 مع التقييم المباشر',
      descriptionEn: 'Live speaking exam practice session analyzing common mistakes and fluency techniques.',
      descriptionAr: 'تدريب مباشر على اختبار المحادثة وتحليل الأخطاء الشائعة واستراتيجيات الطلاقة.',
      youtubeVideoId: 'fJ9rUzIMcZQ',
      durationSeconds: 2980,
      recordedDate: '2026-08-08',
      thumbnailUrl: 'assets/images/Dalilak/profile2.jpg',
      viewCount: 31800,
    ),
    VodModel(
      vodId: 'vod_dalilk_203',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_alex'],
      venueId: 'dalilk_branch_dammam',
      titleEn: 'Everyday Native Idioms & Pronunciation Mastery',
      titleAr: 'التعابير الاصطلاحية اليومية وإتقان النطق مع أليكس',
      descriptionEn: 'Essential everyday idioms, connected speech, and accent refinement for natural English.',
      descriptionAr: 'أهم التعابير الاصطلاحية والنطق المتصل وتطوير الأكسنت للتحدث بلغة إنجليزية طبيعية.',
      youtubeVideoId: 'bHQqvYy5KYo',
      durationSeconds: 2550,
      recordedDate: '2026-08-05',
      thumbnailUrl: 'assets/images/Dalilak/profile3.jpg',
      viewCount: 26400,
    ),
    VodModel(
      vodId: 'vod_dalilk_204',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_abdulrahman', 'spk_sarah'],
      venueId: 'dalilk_hq_khobar',
      titleEn: 'Joint Workshop: IELTS Writing Task 2 Structure & Examiner Criteria',
      titleAr: 'ورشة مشتركة: هيكل مقال الآيلتس ومعايير تصحيح الكتابة',
      descriptionEn: 'Co-hosted workshop breaking down essay templates, idea generation, and grammatical range.',
      descriptionAr: 'ورشة مشتركة لشرح قوالب المقال، وتوليد الأفكار، والتنوع القواعدي المتقدم.',
      youtubeVideoId: 'M7lc1UVf-VE',
      durationSeconds: 4100,
      recordedDate: '2026-08-02',
      thumbnailUrl: 'assets/images/Dalilak/OrgBanner.jpg',
      viewCount: 48900,
    ),
    VodModel(
      vodId: 'vod_dalilk_205',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_abdulrahman'],
      venueId: 'dalilk_hq_khobar',
      titleEn: 'IELTS Academic Reading: Speed Skimming & True/False Mastery (@dalilk4ielts)',
      titleAr: 'قراءة الآيلتس الأكاديمية: مهارات القراءة السريعة وأسئلة الصح والخطأ',
      descriptionEn: 'Tactical methods to solve reading passages under 55 minutes without getting trapped in vocabulary.',
      descriptionAr: 'طرق تكتيكية لحل قطع القراءة في أقل من 55 دقيقة وتجاوز مصائد المفردات المعقدة.',
      youtubeVideoId: '9bZkp7q19f0',
      durationSeconds: 3120,
      recordedDate: '2026-07-28',
      thumbnailUrl: 'assets/images/Dalilak/profile1.jpg',
      viewCount: 37600,
    ),
    VodModel(
      vodId: 'vod_dalilk_206',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_abdulrahman'],
      venueId: 'dalilk_branch_dhahran',
      titleEn: 'IELTS Listening Band 9 Secrets: Map Labeling & Note Completion',
      titleAr: 'أسرار استماع الآيلتس للدرجة 9: أسئلة الخرائط وإكمال الملاحظات',
      descriptionEn: 'How to predict answers and navigate British/Australian accents in listening sections.',
      descriptionAr: 'كيف تتوقع الإجابات وتتعامل مع اللهجات البريطانية والأسترالية في اختبار الاستماع.',
      youtubeVideoId: 'L_LUpnjgPso',
      durationSeconds: 2840,
      recordedDate: '2026-07-25',
      thumbnailUrl: 'assets/images/Dalilak/profile1.jpg',
      viewCount: 29500,
    ),
    VodModel(
      vodId: 'vod_dalilk_207',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_sarah'],
      venueId: 'dalilk_branch_dhahran',
      titleEn: 'English Fluency Foundations: Thinking Directly in English (@dalilk4english)',
      titleAr: 'أسس طلاقة اللغة الإنجليزية: التفكير المباشر باللغة دون ترجمة',
      descriptionEn: 'Techniques to stop mental translation, build sentence rhythm, and eliminate conversational hesitation.',
      descriptionAr: 'تقنيات التوقف عن الترجمة الذهنية وبناء إيقاع الجمل والتخلص من التردد أثناء المحادثة.',
      youtubeVideoId: 'dQw4w9WgXcQ',
      durationSeconds: 2750,
      recordedDate: '2026-07-22',
      thumbnailUrl: 'assets/images/Dalilak/profile2.jpg',
      viewCount: 34100,
    ),
    VodModel(
      vodId: 'vod_dalilk_208',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_sarah'],
      venueId: 'dalilk_branch_dhahran',
      titleEn: 'Top 100 Advanced Academic Collocations for IELTS Speaking',
      titleAr: 'أهم 100 تركيب لغوي أكاديمي متقدم لاختبار محادثة الآيلتس',
      descriptionEn: 'Boost lexical resource score with natural native collocations and descriptive phrases.',
      descriptionAr: 'ارفع درجة الحصيلة اللغوية عبر استخدام متلازمات طبيعية وتعبيرات وصفية متقدمة.',
      youtubeVideoId: 'fJ9rUzIMcZQ',
      durationSeconds: 2600,
      recordedDate: '2026-07-18',
      thumbnailUrl: 'assets/images/Dalilak/profile2.jpg',
      viewCount: 28700,
    ),
    VodModel(
      vodId: 'vod_dalilk_209',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_alex'],
      venueId: 'dalilk_branch_dammam',
      titleEn: 'Dalilk Podcast Ep. 12: British vs American Pronunciation & Connected Speech (@dalilk4english_podcast)',
      titleAr: 'بودكاست دليل - حلقة 12: الفروقات الصوتية بين النطق البريطاني والأمريكي',
      descriptionEn: 'Deep dive into vowel shifts, glottal stops, and connected speech assimilation with Alex.',
      descriptionAr: 'تحليل صوتي شامل لتغير نطق الحروف المتحركة والوقفات الصوتية وربط الكلمات.',
      youtubeVideoId: 'bHQqvYy5KYo',
      durationSeconds: 3300,
      recordedDate: '2026-07-14',
      thumbnailUrl: 'assets/images/Dalilak/profile3.jpg',
      viewCount: 31200,
    ),
    VodModel(
      vodId: 'vod_dalilk_210',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_alex'],
      venueId: 'dalilk_branch_dammam',
      titleEn: 'Dalilk Podcast Ep. 13: Natural Phrasal Verbs & Slang in Real Life',
      titleAr: 'بودكاست دليل - حلقة 13: الأفعال المركبة والمصطلحات الدارجة في الحياة اليومية',
      descriptionEn: 'How to understand and use phrasal verbs effortlessly in professional and social settings.',
      descriptionAr: 'كيف تستخدم الأفعال المركبة بطلاقة ودون تكلف في بيئات العمل والمواقف الاجتماعية.',
      youtubeVideoId: 'M7lc1UVf-VE',
      durationSeconds: 3150,
      recordedDate: '2026-07-10',
      thumbnailUrl: 'assets/images/Dalilak/profile3.jpg',
      viewCount: 27900,
    ),
    VodModel(
      vodId: 'vod_dalilk_211',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_abdulrahman'],
      venueId: 'dalilk_hq_khobar',
      titleEn: 'IELTS Writing Task 1: Academic Graphs & Trends Mastery (@dalilk4ielts)',
      titleAr: 'كتابة الآيلتس المهمة الأولى: تحليل الرسوم البيانية والجداول',
      descriptionEn: 'Step-by-step breakdown of report writing, trends description, and vocabulary for Task 1.',
      descriptionAr: 'شرح خطوة بخطوة لكتابة تقرير المهمة الأولى ووصف الاتجاهات والبيانات الإحصائية.',
      youtubeVideoId: 'dQw4w9WgXcQ',
      durationSeconds: 2900,
      recordedDate: '2026-07-06',
      thumbnailUrl: 'assets/images/Dalilak/profile1.jpg',
      viewCount: 35400,
    ),
    VodModel(
      vodId: 'vod_dalilk_212',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_abdulrahman'],
      venueId: 'dalilk_hq_khobar',
      titleEn: 'IELTS 15-Day Final Sprint Plan & Common Traps',
      titleAr: 'خطة الأسبوعين الأخيرة لاجتياز الآيلتس وتجنب أهم المصائد',
      descriptionEn: 'Tactical daily schedule and priority checklist for the final weeks before exam day.',
      descriptionAr: 'جدول مذاكرة يومي مركز وقائمة أولويات للأيام الأخيرة قبل دخول قاعة الاختبار.',
      youtubeVideoId: '9bZkp7q19f0',
      durationSeconds: 3350,
      recordedDate: '2026-07-01',
      thumbnailUrl: 'assets/images/Dalilak/profile1.jpg',
      viewCount: 41200,
    ),
    VodModel(
      vodId: 'vod_dalilk_213',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_sarah'],
      venueId: 'dalilk_branch_dhahran',
      titleEn: 'English Grammar from Scratch to Advanced Academic Level (@dalilk4english)',
      titleAr: 'قواعد اللغة الإنجليزية من الصفر حتى المستوى الأكاديمي المتقدم',
      descriptionEn: 'Clear explanation of tenses, conditionals, and complex sentence building.',
      descriptionAr: 'شرح مبسط للأزمنة والجمل الشرطية وبناء التراكيب المعقدة دون أخطاء.',
      youtubeVideoId: 'L_LUpnjgPso',
      durationSeconds: 3600,
      recordedDate: '2026-06-27',
      thumbnailUrl: 'assets/images/Dalilak/profile2.jpg',
      viewCount: 38900,
    ),
    VodModel(
      vodId: 'vod_dalilk_214',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_sarah'],
      venueId: 'dalilk_branch_dhahran',
      titleEn: 'IELTS Speaking Fluency: Idiomatic Structures & Coherence',
      titleAr: 'طلاقة محادثة الآيلتس: التراكيب الاصطلاحية والترابط المنطقي',
      descriptionEn: 'How to transition smoothly between ideas and speak for 2 minutes without awkward pauses.',
      descriptionAr: 'كيف تنتقل بسلاسة بين الأفكار وتتحدث لمدة دقيقتين متواصلتين بثقة تامة.',
      youtubeVideoId: 'fJ9rUzIMcZQ',
      durationSeconds: 2800,
      recordedDate: '2026-06-22',
      thumbnailUrl: 'assets/images/Dalilak/profile2.jpg',
      viewCount: 30500,
    ),
    VodModel(
      vodId: 'vod_dalilk_215',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_alex'],
      venueId: 'dalilk_branch_dammam',
      titleEn: 'Dalilk Podcast Ep. 14: Overcoming English Speaking Anxiety & Hesitation (@dalilk4english_podcast)',
      titleAr: 'بودكاست دليل - حلقة 14: التغلب على التردد والخوف من التحدث بالإنجليزية',
      descriptionEn: 'Psychological and linguistic exercises to build effortless conversational confidence.',
      descriptionAr: 'تمارين نفسية ولغوية لبناء الثقة والتخلص من التردد أثناء التحدث مع المتحدثين الأصليين.',
      youtubeVideoId: 'bHQqvYy5KYo',
      durationSeconds: 3400,
      recordedDate: '2026-06-18',
      thumbnailUrl: 'assets/images/Dalilak/profile3.jpg',
      viewCount: 33100,
    ),
    VodModel(
      vodId: 'vod_dalilk_216',
      streamerId: 'org_dalilk_04',
      speakerIds: ['spk_alex'],
      venueId: 'dalilk_branch_dammam',
      titleEn: 'American Accent Training: Master The Flap T & Intonation Rules',
      titleAr: 'تدريب الأكسنت الأمريكي: إتقان نطق حرف T وقواعد نبرات الصوت',
      descriptionEn: 'Practical tongue and mouth positioning drills to sound naturally American.',
      descriptionAr: 'تدريبات عملية لمخارج الحروف ونبرة الصوت لاكتساب الأكسنت الأمريكي بشكل طبيعي.',
      youtubeVideoId: 'M7lc1UVf-VE',
      durationSeconds: 3100,
      recordedDate: '2026-06-12',
      thumbnailUrl: 'assets/images/Dalilak/profile3.jpg',
      viewCount: 29800,
    ),
    // Al Quran 4K Official (Holy Quran 24/7 Live Channel)
    VodModel(
      vodId: 'vod_quran_301',
      streamerId: 'quran_4k_05',
      titleEn: 'Surah Al-Baqarah Complete Recitation in 4K Ultra High Audio',
      titleAr: 'سورة البقرة كاملة بجودة صوتية عالية وتلاوة خاشعة 4K',
      descriptionEn: 'Heart-touching continuous recitation of Surah Al-Baqarah from Al Quran 4K Official channel.',
      descriptionAr: 'تلاوة مباركة خاشعة لسورة البقرة كاملة من قناة إذاعة القرآن الكريم الرسمية.',
      youtubeVideoId: '_y45JcS3MlQ',
      durationSeconds: 7200,
      recordedDate: '2026-08-15',
      thumbnailUrl: 'assets/images/quran/Quran_banner.jpg',
      viewCount: 945000,
    ),
    VodModel(
      vodId: 'vod_quran_302',
      streamerId: 'quran_4k_05',
      titleEn: 'Surah Al-Kahf - Peaceful Friday Tilawah Recitation (@AlQuran4KOfficial)',
      titleAr: 'سورة الكهف - تلاوة يوم الجمعة المباركة والسكينة الإيمانية',
      descriptionEn: 'Serene Friday recitation of Surah Al-Kahf with crystal clear audio.',
      descriptionAr: 'تلاوة هادئة ومريحة لسورة الكهف ليوم الجمعة بأعلى جودة صوتية.',
      youtubeVideoId: 'dQw4w9WgXcQ',
      durationSeconds: 2400,
      recordedDate: '2026-08-11',
      thumbnailUrl: 'assets/images/quran/Quran_profile.jpg',
      viewCount: 682000,
    ),
    VodModel(
      vodId: 'vod_quran_303',
      streamerId: 'quran_4k_05',
      titleEn: 'Surah Maryam & Taha - Emotional Makkah Live Recitation',
      titleAr: 'سورة مريم وطه - تلاوة خاشعة ومؤثرة من مكة المكرمة',
      descriptionEn: 'Spiritual and uplifting recitation of Surahs Maryam & Taha.',
      descriptionAr: 'تلاوة إيمانية تبعث على الطمأنينة والخشوع من رحاب البيت العتيق.',
      youtubeVideoId: 'fJ9rUzIMcZQ',
      durationSeconds: 3100,
      recordedDate: '2026-08-04',
      thumbnailUrl: 'assets/images/quran/Quran_banner.jpg',
      viewCount: 520000,
    ),
    VodModel(
      vodId: 'vod_quran_304',
      streamerId: 'quran_4k_05',
      titleEn: 'Juz Amma Complete Audio Master - Makkah & Madinah Reciters',
      titleAr: 'جزء عم كاملاً - بأصوات نخبة من أئمة وقراء الحرمين الشريفين',
      descriptionEn: 'Complete 30th Juz recitation for listening, reflection, and memorization.',
      descriptionAr: 'تلاوة تعليمية وتدبرية مباركة لكامل جزء عم بأجمل الأصوات.',
      youtubeVideoId: 'bHQqvYy5KYo',
      durationSeconds: 4200,
      recordedDate: '2026-07-29',
      thumbnailUrl: 'assets/images/quran/Quran_profile.jpg',
      viewCount: 810000,
    ),
  ];

  static List<PlaylistModel> get samplePlaylists {
    final amerVods = sampleVods.where((v) => v.streamerId == 'prof_otaibi_02').toList();
    final hejaziVods = sampleVods.where((v) => v.streamerId == 'org_dalilk_04' && v.speakerIds.contains('spk_abdulrahman')).toList();
    final sarahVods = sampleVods.where((v) => v.streamerId == 'org_dalilk_04' && v.speakerIds.contains('spk_sarah')).toList();
    final alexVods = sampleVods.where((v) => v.streamerId == 'org_dalilk_04' && v.speakerIds.contains('spk_alex')).toList();
    final quranVods = sampleVods.where((v) => v.streamerId == 'quran_4k_05').toList();

    return [
      PlaylistModel(
        playlistId: 'PL_quran_full_tilawah',
        streamerId: 'quran_4k_05',
        channelHandle: 'AlQuran4KOfficial',
        titleEn: 'Complete Holy Quran Recitations Collection (@AlQuran4KOfficial)',
        titleAr: 'المصحف المرتل الكامل وتلاوات القرآن الكريم (@AlQuran4KOfficial)',
        descriptionEn: 'Full collection of high quality Quran recitations and long-form chapters.',
        descriptionAr: 'المجموعة الكاملة للمصحف المرتل بأصوات كبار القراء بجودة صوتية نقية.',
        youtubePlaylistUrl: 'https://www.youtube.com/@AlQuran4KOfficial',
        thumbnailUrl: 'assets/images/quran/Quran_banner.jpg',
        videoCount: quranVods.length,
        videos: quranVods,
      ),
      PlaylistModel(
        playlistId: 'PL_dalilk_ielts_full',
        streamerId: 'org_dalilk_04',
        speakerIds: const ['spk_abdulrahman'],
        channelHandle: 'dalilk4ielts',
        titleEn: 'Dalilk 4 IELTS Masterclass Series (@dalilk4ielts)',
        titleAr: 'سلسلة دورات دليل الآيلتس الشاملة (@dalilk4ielts)',
        descriptionEn: 'Complete collection of IELTS preparation lectures, reading techniques, and Band 8+ frameworks.',
        descriptionAr: 'المجموعة الكاملة لدروس التحضير للآيلتس واستراتيجيات القراءة والكتابة الأكاديمية.',
        youtubePlaylistUrl: 'https://www.youtube.com/@dalilk4ielts',
        thumbnailUrl: 'assets/images/Dalilak/profile1.jpg',
        videoCount: hejaziVods.length,
        videos: hejaziVods,
      ),
      PlaylistModel(
        playlistId: 'PL_dalilk_writing_intensive',
        streamerId: 'org_dalilk_04',
        speakerIds: const ['spk_abdulrahman'],
        channelHandle: 'dalilk4ielts',
        titleEn: 'IELTS Writing Task 1 & 2 Blueprint (@dalilk4ielts)',
        titleAr: 'مخطط كتابة مهام الآيلتس الأولى والثانية الشامل (@dalilk4ielts)',
        descriptionEn: 'Essay structures, cohesive devices, graph analysis, and argument building.',
        descriptionAr: 'هياكل المقالات، الروابط المنطقية، تحليل الرسوم البيانية، وبناء الحجج الأكاديمية.',
        youtubePlaylistUrl: 'https://www.youtube.com/@dalilk4ielts',
        thumbnailUrl: 'assets/images/Dalilak/OrgBanner.jpg',
        videoCount: 2,
        videos: hejaziVods.take(2).toList(),
      ),
      PlaylistModel(
        playlistId: 'PL_dalilk_speaking_sim',
        streamerId: 'org_dalilk_04',
        speakerIds: const ['spk_sarah'],
        channelHandle: 'dalilk4english',
        titleEn: 'Dalilk 4 English Fluency & Speaking Mastery (@dalilk4english)',
        titleAr: 'طلاقة اللغة الإنجليزية ومحادثة الآيلتس (@dalilk4english)',
        descriptionEn: 'Live speaking exam practice, fluency development, and examiner scoring criteria.',
        descriptionAr: 'تدريب مباشر على اختبار المحادثة، تطوير الطلاقة، ومعايير تقييم مصححي الآيلتس.',
        youtubePlaylistUrl: 'https://www.youtube.com/@dalilk4english',
        thumbnailUrl: 'assets/images/Dalilak/profile2.jpg',
        videoCount: sarahVods.length,
        videos: sarahVods,
      ),
      PlaylistModel(
        playlistId: 'PL_dalilk_grammar_pro',
        streamerId: 'org_dalilk_04',
        speakerIds: const ['spk_sarah'],
        channelHandle: 'dalilk4english',
        titleEn: 'Advanced English Grammar & Academic Collocations (@dalilk4english)',
        titleAr: 'قواعد اللغة الإنجليزية المتقدمة والمتلازمات الأكاديمية (@dalilk4english)',
        descriptionEn: 'Essential grammatical structures and high-band collocations for natural English.',
        descriptionAr: 'القواعد الأساسية والتراكيب اللغوية المتقدمة للتحدث بلغة إنجليزية رصينة وطبيعية.',
        youtubePlaylistUrl: 'https://www.youtube.com/@dalilk4english',
        thumbnailUrl: 'assets/images/Dalilak/profile2.jpg',
        videoCount: 2,
        videos: sarahVods.take(2).toList(),
      ),
      PlaylistModel(
        playlistId: 'PL_dalilk_podcast_series',
        streamerId: 'org_dalilk_04',
        speakerIds: const ['spk_alex'],
        channelHandle: 'dalilk4english_podcast',
        titleEn: 'Dalilk English Podcast Full Series (@dalilk4english_podcast)',
        titleAr: 'سلسلة بودكاست دليل الإنجليزية الكاملة (@dalilk4english_podcast)',
        descriptionEn: 'Native pronunciation drills, everyday idioms, and conversational English podcast with Alex.',
        descriptionAr: 'حلقات بودكاست تدريب النطق، التعابير الدارجة، واللغة الإنجليزية اليومية مع أليكس.',
        youtubePlaylistUrl: 'https://www.youtube.com/@dalilk4english_podcast',
        thumbnailUrl: 'assets/images/Dalilak/profile3.jpg',
        videoCount: alexVods.length,
        videos: alexVods,
      ),
      PlaylistModel(
        playlistId: 'PL_dalilk_accent_drills',
        streamerId: 'org_dalilk_04',
        speakerIds: const ['spk_alex'],
        channelHandle: 'dalilk4english_podcast',
        titleEn: 'Native Accent & Connected Speech Masterclass (@dalilk4english_podcast)',
        titleAr: 'إتقان الأكسنت والنطق المتصل باللغة الإنجليزية (@dalilk4english_podcast)',
        descriptionEn: 'Practical phonetic exercises for connected speech, vowel reduction, and natural rhythm.',
        descriptionAr: 'تمارين صوتية عملية للنطق المتصل، تخفيف الحركات، والتحكم في إيقاع الكلام.',
        youtubePlaylistUrl: 'https://www.youtube.com/@dalilk4english_podcast',
        thumbnailUrl: 'assets/images/Dalilak/profile3.jpg',
        videoCount: 2,
        videos: alexVods.take(2).toList(),
      ),
      PlaylistModel(
        playlistId: 'PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9',
        streamerId: 'prof_otaibi_02',
        titleEn: 'Ahmed Amer Playlist (PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9)',
        titleAr: 'قائمة تشغيل الداعية أحمد عامر (PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9)',
        descriptionEn: 'Official playlist PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9 featuring Sheikh Ahmed Amer (@ahmedamercaller).',
        descriptionAr: 'قائمة التشغيل الرسمية PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9 للداعية أحمد عامر.',
        youtubePlaylistUrl: 'https://www.youtube.com/playlist?list=PLATApN30c4aLXpHzO1GkEb9H0CeXaJFy9',
        thumbnailUrl: 'assets/images/Ahmed_Amer_YouTube_files/Ahmed_Amer_profile.jpg',
        videoCount: amerVods.length,
        videos: amerVods,
      ),
      PlaylistModel(
        playlistId: 'PLSSxr3Rf2_X12mvTpHUlgrqjK38r6h5n-',
        streamerId: 'prof_otaibi_02',
        titleEn: 'Istiraha Podcast - Full Series',
        titleAr: 'سلسلة بودكاست استراحة الكاملة',
        descriptionEn: 'Full audio & video episodes of Istiraha podcast by Sheikh Ahmed Amer.',
        descriptionAr: 'الحلقات الكاملة لبودكاست استراحة للداعية أحمد عامر.',
        youtubePlaylistUrl: 'https://www.youtube.com/playlist?list=PLSSxr3Rf2_X12mvTpHUlgrqjK38r6h5n-',
        thumbnailUrl: 'assets/images/Ahmed_Amer_YouTube_files/Ahmed_Amer_banner.jpg',
        videoCount: amerVods.length,
        videos: amerVods,
      ),
    ];
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
