import 'package:flutter/foundation.dart';
import 'org_broadcaster_permissions.dart';

enum AffiliationDirection {
  streamerToOrg, // Streamer applied to join the Org
  orgToStreamer, // Org invited the Streamer
}

enum AffiliationStatus {
  pending,
  accepted,
  declined,
  revoked,
}

/// Model representing an affiliation request between a Streamer and an Organization
@immutable
class OrgAffiliationRequestModel {
  final String id;
  final String orgId;
  final String orgNameEn;
  final String orgNameAr;
  final String orgAvatarUrl;
  final String streamerId;
  final String streamerNameEn;
  final String streamerNameAr;
  final String streamerAvatarUrl;
  final String streamerEmail;
  final String? proposedRoleEn;
  final String? proposedRoleAr;
  final String note;
  final AffiliationDirection direction;
  final AffiliationStatus status;
  final OrgBroadcasterPermissions permissions;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const OrgAffiliationRequestModel({
    required this.id,
    required this.orgId,
    required this.orgNameEn,
    required this.orgNameAr,
    required this.orgAvatarUrl,
    required this.streamerId,
    required this.streamerNameEn,
    required this.streamerNameAr,
    required this.streamerAvatarUrl,
    required this.streamerEmail,
    this.proposedRoleEn,
    this.proposedRoleAr,
    required this.note,
    required this.direction,
    this.status = AffiliationStatus.pending,
    this.permissions = const OrgBroadcasterPermissions(),
    required this.createdAt,
    this.resolvedAt,
  });

  bool get isPending => status == AffiliationStatus.pending;
  bool get isAccepted => status == AffiliationStatus.accepted;
  bool get isDeclined => status == AffiliationStatus.declined;

  String getLocalizedOrgName(String languageCode) =>
      languageCode == 'ar' ? orgNameAr : orgNameEn;

  String getLocalizedStreamerName(String languageCode) =>
      languageCode == 'ar' ? streamerNameAr : streamerNameEn;

  String getLocalizedProposedRole(String languageCode) =>
      languageCode == 'ar'
          ? (proposedRoleAr ?? 'محاضر / مدرب')
          : (proposedRoleEn ?? 'Instructor / Speaker');

  OrgAffiliationRequestModel copyWith({
    String? id,
    String? orgId,
    String? orgNameEn,
    String? orgNameAr,
    String? orgAvatarUrl,
    String? streamerId,
    String? streamerNameEn,
    String? streamerNameAr,
    String? streamerAvatarUrl,
    String? streamerEmail,
    String? proposedRoleEn,
    String? proposedRoleAr,
    String? note,
    AffiliationDirection? direction,
    AffiliationStatus? status,
    OrgBroadcasterPermissions? permissions,
    DateTime? createdAt,
    DateTime? resolvedAt,
  }) {
    return OrgAffiliationRequestModel(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      orgNameEn: orgNameEn ?? this.orgNameEn,
      orgNameAr: orgNameAr ?? this.orgNameAr,
      orgAvatarUrl: orgAvatarUrl ?? this.orgAvatarUrl,
      streamerId: streamerId ?? this.streamerId,
      streamerNameEn: streamerNameEn ?? this.streamerNameEn,
      streamerNameAr: streamerNameAr ?? this.streamerNameAr,
      streamerAvatarUrl: streamerAvatarUrl ?? this.streamerAvatarUrl,
      streamerEmail: streamerEmail ?? this.streamerEmail,
      proposedRoleEn: proposedRoleEn ?? this.proposedRoleEn,
      proposedRoleAr: proposedRoleAr ?? this.proposedRoleAr,
      note: note ?? this.note,
      direction: direction ?? this.direction,
      status: status ?? this.status,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'orgNameEn': orgNameEn,
        'orgNameAr': orgNameAr,
        'orgAvatarUrl': orgAvatarUrl,
        'streamerId': streamerId,
        'streamerNameEn': streamerNameEn,
        'streamerNameAr': streamerNameAr,
        'streamerAvatarUrl': streamerAvatarUrl,
        'streamerEmail': streamerEmail,
        'proposedRoleEn': proposedRoleEn,
        'proposedRoleAr': proposedRoleAr,
        'note': note,
        'direction': direction.name,
        'status': status.name,
        'permissions': permissions.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
      };

  factory OrgAffiliationRequestModel.fromJson(Map<String, dynamic> json) =>
      OrgAffiliationRequestModel(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        orgNameEn: json['orgNameEn'] as String? ?? '',
        orgNameAr: json['orgNameAr'] as String? ?? '',
        orgAvatarUrl: json['orgAvatarUrl'] as String? ?? '',
        streamerId: json['streamerId'] as String,
        streamerNameEn: json['streamerNameEn'] as String? ?? '',
        streamerNameAr: json['streamerNameAr'] as String? ?? '',
        streamerAvatarUrl: json['streamerAvatarUrl'] as String? ?? '',
        streamerEmail: json['streamerEmail'] as String? ?? '',
        proposedRoleEn: json['proposedRoleEn'] as String?,
        proposedRoleAr: json['proposedRoleAr'] as String?,
        note: json['note'] as String? ?? '',
        direction: AffiliationDirection.values
            .byName(json['direction'] as String? ?? 'streamerToOrg'),
        status: AffiliationStatus.values
            .byName(json['status'] as String? ?? 'pending'),
        permissions: json['permissions'] != null
            ? OrgBroadcasterPermissions.fromJson(
                json['permissions'] as Map<String, dynamic>)
            : const OrgBroadcasterPermissions(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String)
            : null,
      );
}
