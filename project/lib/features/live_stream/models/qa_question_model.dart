class LectureQuestionModel {
  final String id;
  final String authorName;
  final String authorAvatar;
  final String questionText;
  final DateTime timestamp;
  int upvotes;
  bool hasUpvoted;
  bool isAnsweredLive;

  LectureQuestionModel({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.questionText,
    required this.timestamp,
    this.upvotes = 0,
    this.hasUpvoted = false,
    this.isAnsweredLive = false,
  });

  static List<LectureQuestionModel> sampleQuestions = [
    LectureQuestionModel(
      id: 'q1',
      authorName: 'Fahad Al-Otaibi',
      authorAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100',
      questionText: 'How does backpropagation handle vanishing gradients in deep recurrent layers?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 12)),
      upvotes: 24,
      hasUpvoted: true,
      isAnsweredLive: true,
    ),
    LectureQuestionModel(
      id: 'q2',
      authorName: 'Noura Al-Dosari',
      authorAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100',
      questionText: 'Will the slides on multi-head attention mechanisms be shared after the live stream?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
      upvotes: 18,
      hasUpvoted: false,
      isAnsweredLive: false,
    ),
    LectureQuestionModel(
      id: 'q3',
      authorName: 'Tariq Al-Ghamdi',
      authorAvatar: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=100',
      questionText: 'Are the physical lab sessions at KFUPM Auditorium 21 open for guests today?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      upvotes: 9,
      hasUpvoted: false,
      isAnsweredLive: false,
    ),
  ];
}
