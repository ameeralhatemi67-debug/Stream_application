import 'dart:math';

/// Model representing live chat messages injected by the "Ghost Audience" simulation engine or user.
class GhostComment {
  final String messageId;
  final String streamId;
  final String senderNameEn;
  final String senderNameAr;
  final String senderAvatar;
  final String messageTextEn;
  final String messageTextAr;
  final String timestamp;
  final bool isCurrentUser;
  final bool isGhostSimulation;
  final String reactionType; // 'none', 'clap', 'heart', 'raise_hand'

  const GhostComment({
    required this.messageId,
    required this.streamId,
    required this.senderNameEn,
    required this.senderNameAr,
    required this.senderAvatar,
    required this.messageTextEn,
    required this.messageTextAr,
    required this.timestamp,
    this.isCurrentUser = false,
    this.isGhostSimulation = true,
    this.reactionType = 'none',
  });

  /// Returns sender name according to current [languageCode] ('ar' or 'en').
  String getLocalizedSender(String languageCode) =>
      languageCode == 'ar' ? senderNameAr : senderNameEn;

  /// Returns message text according to current [languageCode].
  String getLocalizedMessage(String languageCode) =>
      languageCode == 'ar' ? messageTextAr : messageTextEn;

  factory GhostComment.fromJson(Map<String, dynamic> json) {
    return GhostComment(
      messageId: json['message_id'] as String,
      streamId: json['stream_id'] as String,
      senderNameEn: json['sender_name_en'] ?? json['sender_name'] ?? 'Viewer',
      senderNameAr: json['sender_name_ar'] ?? json['sender_name'] ?? 'متابع',
      senderAvatar: json['sender_avatar'] as String,
      messageTextEn: json['message_text_en'] as String,
      messageTextAr: json['message_text_ar'] as String,
      timestamp: json['timestamp'] as String,
      isCurrentUser: json['is_current_user'] as bool? ?? false,
      isGhostSimulation: json['is_ghost_simulation'] as bool? ?? true,
      reactionType: json['reaction_type'] as String? ?? 'none',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'stream_id': streamId,
      'sender_name_en': senderNameEn,
      'sender_name_ar': senderNameAr,
      'sender_avatar': senderAvatar,
      'message_text_en': messageTextEn,
      'message_text_ar': messageTextAr,
      'timestamp': timestamp,
      'is_current_user': isCurrentUser,
      'is_ghost_simulation': isGhostSimulation,
      'reaction_type': reactionType,
    };
  }
}

/// Localized pool of realistic comments for the "Ghost Audience" simulation engine.
/// Injecting localized EN & AR comments every 4-7 seconds during live pitch demonstrations.
class GhostCommentPool {
  static final _random = Random();

  static const List<GhostComment> rawComments = [
    GhostComment(
      messageId: 'ghost_001',
      streamId: 'stream_live_992',
      senderNameEn: 'Fahad Al-Otaibi',
      senderNameAr: 'فهد العتيبي',
      senderAvatar: 'assets/images/avatars/user_fahad.jpg',
      messageTextEn: 'Peace be upon you all! Greetings from Al Khobar.',
      messageTextAr: 'السلام عليكم ورحمة الله وبركاته! تحياتي لكم من الخبر.',
      timestamp: '16:40:02',
    ),
    GhostComment(
      messageId: 'ghost_002',
      streamId: 'stream_live_992',
      senderNameEn: 'Sarah Al-Ghamdi',
      senderNameAr: 'سارة الغامدي',
      senderAvatar: 'assets/images/avatars/user_sarah.jpg',
      messageTextEn: 'Excellent explanation of cloud latency in KSA regions!',
      messageTextAr: 'شرح ممتاز جداً عن زمن الاستجابة السحابية في المملكة!',
      timestamp: '16:40:15',
    ),
    GhostComment(
      messageId: 'ghost_003',
      streamId: 'stream_live_992',
      senderNameEn: 'Dr. Tariq Al-Dossary',
      senderNameAr: 'د. طارق الدوسري',
      senderAvatar: 'assets/images/avatars/user_tariq.jpg',
      messageTextEn: 'Will the lecture presentation slides be saved in VODs?',
      messageTextAr: 'هل ستكون الشرائح والتسجيلات محفوظة في الأرشيف؟',
      timestamp: '16:40:28',
    ),
    GhostComment(
      messageId: 'ghost_004',
      streamId: 'stream_live_992',
      senderNameEn: 'Mohammed Al-Zahrani',
      senderNameAr: 'محمد الزهراني',
      senderAvatar: 'assets/images/avatars/user_mohammed.jpg',
      messageTextEn:
          'Can we attend the physical seminar tomorrow at KFUPM auditorium?',
      messageTextAr:
          'هل يمكننا حضور الندوة المباشرة غداً في قاعة جامعة الملك فهد؟',
      timestamp: '16:40:41',
    ),
    GhostComment(
      messageId: 'ghost_005',
      streamId: 'stream_live_992',
      senderNameEn: 'Reem Al-Qahtani',
      senderNameAr: 'ريم القحطاني',
      senderAvatar: 'assets/images/avatars/user_reem.jpg',
      messageTextEn: 'Great point regarding edge nodes in Dhahran and Dammam!',
      messageTextAr:
          'نقطة رائعة جداً بخصوص الخوادم الطرفية في الظهران والدمام!',
      timestamp: '16:40:55',
    ),
    GhostComment(
      messageId: 'ghost_006',
      streamId: 'stream_live_992',
      senderNameEn: 'Abdullah Al-Shehri',
      senderNameAr: 'عبد الله الشهري',
      senderAvatar: 'assets/images/avatars/user_abdullah.jpg',
      messageTextEn: 'The RTMP local stream quality is crystal clear! 👏',
      messageTextAr: 'جودة البث المباشر المحلية فائقة الوضوح! 👏',
      timestamp: '16:41:10',
      reactionType: 'clap',
    ),
    GhostComment(
      messageId: 'ghost_007',
      streamId: 'stream_live_992',
      senderNameEn: 'Nouf Al-Harbi',
      senderNameAr: 'نوف الحربي',
      senderAvatar: 'assets/images/avatars/user_nouf.jpg',
      messageTextEn: 'Thank you Professor for this valuable information! ❤️',
      messageTextAr: 'شكراً جزيلاً يا دكتور على هذه المعلومات القيّمة! ❤️',
      timestamp: '16:41:22',
      reactionType: 'heart',
    ),
    GhostComment(
      messageId: 'ghost_008',
      streamId: 'stream_live_992',
      senderNameEn: 'Khaled Al-Mansoori',
      senderNameAr: 'خالد المنصوري',
      senderAvatar: 'assets/images/avatars/user_khaled.jpg',
      messageTextEn:
          'I have a quick question about container orchestration latency ✋',
      messageTextAr: 'لدي سؤال سريع حول زمن استجابة إدارة الحاوية ✋',
      timestamp: '16:41:35',
      reactionType: 'raise_hand',
    ),
  ];

  /// Generates a random comment from the pool with updated timestamp and unique ID.
  static GhostComment getRandomComment({String streamId = 'stream_live_992'}) {
    final template = rawComments[_random.nextInt(rawComments.length)];
    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    final randomId =
        'ghost_${now.millisecondsSinceEpoch}_${_random.nextInt(1000)}';

    return GhostComment(
      messageId: randomId,
      streamId: streamId,
      senderNameEn: template.senderNameEn,
      senderNameAr: template.senderNameAr,
      senderAvatar: template.senderAvatar,
      messageTextEn: template.messageTextEn,
      messageTextAr: template.messageTextAr,
      timestamp: timeStr,
      isCurrentUser: false,
      isGhostSimulation: true,
      reactionType: template.reactionType,
    );
  }
}
