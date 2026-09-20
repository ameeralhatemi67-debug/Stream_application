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
}
