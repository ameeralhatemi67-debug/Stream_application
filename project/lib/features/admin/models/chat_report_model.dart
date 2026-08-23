/// A chat_reports row, joined with the reported message's body and both
/// parties' display info -- what the Chat Moderation Dashboard (v0.8
/// Checkpoint 4 Phase 1) needs to render one queue entry.
class ChatReportModel {
  final String id;
  final String messageId;
  final String streamId;
  final String reportedSenderId;
  final String reporterId;
  final String reason;
  final DateTime createdAt;
  final String messageBody;
  final String reporterDisplayName;
  final String? reporterEmail;
  final String reportedDisplayName;
  final String? reportedEmail;

  const ChatReportModel({
    required this.id,
    required this.messageId,
    required this.streamId,
    required this.reportedSenderId,
    required this.reporterId,
    required this.reason,
    required this.createdAt,
    required this.messageBody,
    required this.reporterDisplayName,
    this.reporterEmail,
    required this.reportedDisplayName,
    this.reportedEmail,
  });
}
