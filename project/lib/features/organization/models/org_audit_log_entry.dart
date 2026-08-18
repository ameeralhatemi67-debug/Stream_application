/// Enumeration of all trackable administrative and streaming actions for Organizations.
enum OrgAuditAction {
  createOrganization,
  updateOrganizationProfile,
  addVenueBranch,
  updateVenueBranch,
  removeVenueBranch,
  addSpeakerToRoster,
  updateSpeakerDetails,
  removeSpeakerFromRoster,
  grantBroadcastPermission,
  revokeBroadcastPermission,
  updatePermissions,
  assignOwnerRole,
  revokeOwnerRole,
  startLiveBroadcast,
  endLiveBroadcast,
  applyBroadcaster,
  submitAffiliationRequest,
  acceptAffiliationRequest,
  declineAffiliationRequest,
}

/// Immutable audit log entry tracking administrative, member, and broadcast actions.
class OrgAuditLogEntry {
  final String logId;
  final String organizationId;
  final DateTime timestamp;
  final String actorEmail;
  final String actorName;
  final OrgAuditAction action;
  final String descriptionEn;
  final String descriptionAr;
  final Map<String, dynamic> metadata;

  const OrgAuditLogEntry({
    required this.logId,
    required this.organizationId,
    required this.timestamp,
    required this.actorEmail,
    required this.actorName,
    required this.action,
    required this.descriptionEn,
    required this.descriptionAr,
    this.metadata = const {},
  });

  String getLocalizedDescription(String languageCode) =>
      languageCode == 'ar' ? descriptionAr : descriptionEn;

  factory OrgAuditLogEntry.fromJson(Map<String, dynamic> json) {
    return OrgAuditLogEntry(
      logId: json['log_id'] as String,
      organizationId: json['organization_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      actorEmail: json['actor_email'] as String,
      actorName: json['actor_name'] as String,
      action: OrgAuditAction.values.firstWhere(
        (e) => e.name == (json['action'] as String),
        orElse: () => OrgAuditAction.updateOrganizationProfile,
      ),
      descriptionEn: json['description_en'] as String,
      descriptionAr: json['description_ar'] as String,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'organization_id': organizationId,
      'timestamp': timestamp.toIso8601String(),
      'actor_email': actorEmail,
      'actor_name': actorName,
      'action': action.name,
      'description_en': descriptionEn,
      'description_ar': descriptionAr,
      'metadata': metadata,
    };
  }
}
