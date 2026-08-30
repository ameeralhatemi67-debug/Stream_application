/// Which stream-state card a streamer's uploaded artwork replaces.
///
/// Deliberately narrower than [StreamState]: a streamer can only brand the
/// three states that are *their own doing* (about to start, taking a break,
/// finished). Failure states -- offline, playback error, audio token expired
/// -- always use the system placeholder, because a custom card there would
/// hide a real fault from the viewer.
enum StreamPlaceholderType { startingSoon, intermission, ending }

extension StreamPlaceholderTypeInfo on StreamPlaceholderType {
  /// The `placeholder_type` value stored in
  /// `public.streamer_custom_placeholders`.
  String get dbValue {
    switch (this) {
      case StreamPlaceholderType.startingSoon:
        return 'starting_soon';
      case StreamPlaceholderType.intermission:
        return 'intermission';
      case StreamPlaceholderType.ending:
        return 'ending';
    }
  }

  String get labelKey {
    switch (this) {
      case StreamPlaceholderType.startingSoon:
        return 'admin.custom_card_type_starting_soon';
      case StreamPlaceholderType.intermission:
        return 'admin.custom_card_type_intermission';
      case StreamPlaceholderType.ending:
        return 'admin.custom_card_type_ending';
    }
  }

  String get editorLabelKey {
    switch (this) {
      case StreamPlaceholderType.startingSoon:
        return 'settings.custom_card_starting_soon';
      case StreamPlaceholderType.intermission:
        return 'settings.custom_card_intermission';
      case StreamPlaceholderType.ending:
        return 'settings.custom_card_ending';
    }
  }

  static StreamPlaceholderType fromDbValue(String value) {
    return StreamPlaceholderType.values.firstWhere(
      (t) => t.dbValue == value,
      orElse: () => StreamPlaceholderType.startingSoon,
    );
  }
}

/// Moderation state of one uploaded card. Only [approved] is ever shown to
/// viewers -- see `AppProvider.approvedPlaceholderImageUrl`.
enum StreamPlaceholderStatus { pending, approved, rejected }

extension StreamPlaceholderStatusInfo on StreamPlaceholderStatus {
  String get dbValue => name;

  String get labelKey {
    switch (this) {
      case StreamPlaceholderStatus.pending:
        return 'settings.custom_card_status_pending';
      case StreamPlaceholderStatus.approved:
        return 'settings.custom_card_status_approved';
      case StreamPlaceholderStatus.rejected:
        return 'settings.custom_card_status_rejected';
    }
  }

  static StreamPlaceholderStatus fromDbValue(String value) {
    return StreamPlaceholderStatus.values.firstWhere(
      (s) => s.dbValue == value,
      orElse: () => StreamPlaceholderStatus.pending,
    );
  }
}

/// One row of `public.streamer_custom_placeholders` (Cluster 1 Task 4b): a
/// streamer-uploaded stream-state card and where it currently sits in the
/// admin review pipeline.
class StreamerCustomPlaceholderModel {
  final String id;
  final String streamerId;
  final StreamPlaceholderType placeholderType;
  final String imageUrl;
  final StreamPlaceholderStatus status;

  /// Mandatory when [status] is [StreamPlaceholderStatus.rejected] -- it is
  /// the body of the notification the streamer receives, so "rejected with
  /// no reason" is not a state this pipeline can produce.
  final String? rejectionReason;

  final DateTime createdAt;

  /// Display name resolved for the admin queue; not a column.
  final String? streamerDisplayName;

  const StreamerCustomPlaceholderModel({
    required this.id,
    required this.streamerId,
    required this.placeholderType,
    required this.imageUrl,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.streamerDisplayName,
  });

  bool get isPending => status == StreamPlaceholderStatus.pending;
  bool get isApproved => status == StreamPlaceholderStatus.approved;

  StreamerCustomPlaceholderModel copyWith({
    StreamPlaceholderStatus? status,
    String? rejectionReason,
    String? streamerDisplayName,
  }) {
    return StreamerCustomPlaceholderModel(
      id: id,
      streamerId: streamerId,
      placeholderType: placeholderType,
      imageUrl: imageUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      streamerDisplayName: streamerDisplayName ?? this.streamerDisplayName,
    );
  }

  Map<String, dynamic> toRow() => {
        'id': id,
        'streamer_id': streamerId,
        'placeholder_type': placeholderType.dbValue,
        'image_url': imageUrl,
        'status': status.dbValue,
        'rejection_reason': rejectionReason,
        'created_at': createdAt.toIso8601String(),
      };

  factory StreamerCustomPlaceholderModel.fromRow(
    Map<String, dynamic> row, {
    String? streamerDisplayName,
  }) {
    return StreamerCustomPlaceholderModel(
      id: row['id'] as String,
      streamerId: row['streamer_id'] as String,
      placeholderType:
          StreamPlaceholderTypeInfo.fromDbValue(row['placeholder_type'] as String),
      imageUrl: row['image_url'] as String,
      status: StreamPlaceholderStatusInfo.fromDbValue(row['status'] as String),
      rejectionReason: row['rejection_reason'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      streamerDisplayName: streamerDisplayName,
    );
  }

  factory StreamerCustomPlaceholderModel.fromJson(Map<String, dynamic> json) =>
      StreamerCustomPlaceholderModel.fromRow(json);

  Map<String, dynamic> toJson() => toRow();
}
