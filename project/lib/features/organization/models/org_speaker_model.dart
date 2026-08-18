import 'org_broadcaster_permissions.dart';

/// Model representing an instructor, lecturer, or guest speaker within an Organization.
class OrgSpeakerModel {
  final String speakerId;
  final String nameEn;
  final String nameAr;
  final String roleOrTitleEn;
  final String roleOrTitleAr;
  final String avatarUrl;
  final String bioEn;
  final String bioAr;
  final bool isPermanentStaff;
  final String? linkedEmail;
  final String? youtubeHandle;
  final OrgBroadcasterPermissions permissions;

  const OrgSpeakerModel({
    required this.speakerId,
    required this.nameEn,
    required this.nameAr,
    required this.roleOrTitleEn,
    required this.roleOrTitleAr,
    required this.avatarUrl,
    required this.bioEn,
    required this.bioAr,
    this.isPermanentStaff = true,
    this.linkedEmail,
    this.youtubeHandle,
    this.permissions = const OrgBroadcasterPermissions(),
  });

  String getLocalizedName(String languageCode) =>
      languageCode == 'ar' ? nameAr : nameEn;

  String getLocalizedRole(String languageCode) =>
      languageCode == 'ar' ? roleOrTitleAr : roleOrTitleEn;

  String getLocalizedBio(String languageCode) =>
      languageCode == 'ar' ? bioAr : bioEn;

  factory OrgSpeakerModel.fromJson(Map<String, dynamic> json) {
    return OrgSpeakerModel(
      speakerId: json['speaker_id'] as String,
      nameEn: json['name_en'] as String,
      nameAr: json['name_ar'] as String,
      roleOrTitleEn: json['role_or_title_en'] as String,
      roleOrTitleAr: json['role_or_title_ar'] as String,
      avatarUrl: json['avatar_url'] as String,
      bioEn: json['bio_en'] as String? ?? '',
      bioAr: json['bio_ar'] as String? ?? '',
      isPermanentStaff: json['is_permanent_staff'] as bool? ?? true,
      linkedEmail: json['linked_email'] as String?,
      youtubeHandle: json['youtube_handle'] as String?,
      permissions: json['permissions'] != null
          ? OrgBroadcasterPermissions.fromJson(
              json['permissions'] as Map<String, dynamic>)
          : const OrgBroadcasterPermissions(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'speaker_id': speakerId,
      'name_en': nameEn,
      'name_ar': nameAr,
      'role_or_title_en': roleOrTitleEn,
      'role_or_title_ar': roleOrTitleAr,
      'avatar_url': avatarUrl,
      'bio_en': bioEn,
      'bio_ar': bioAr,
      'is_permanent_staff': isPermanentStaff,
      'linked_email': linkedEmail,
      'youtube_handle': youtubeHandle,
      'permissions': permissions.toJson(),
    };
  }

  OrgSpeakerModel copyWith({
    String? speakerId,
    String? nameEn,
    String? nameAr,
    String? roleOrTitleEn,
    String? roleOrTitleAr,
    String? avatarUrl,
    String? bioEn,
    String? bioAr,
    bool? isPermanentStaff,
    String? linkedEmail,
    String? youtubeHandle,
    OrgBroadcasterPermissions? permissions,
  }) {
    return OrgSpeakerModel(
      speakerId: speakerId ?? this.speakerId,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      roleOrTitleEn: roleOrTitleEn ?? this.roleOrTitleEn,
      roleOrTitleAr: roleOrTitleAr ?? this.roleOrTitleAr,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bioEn: bioEn ?? this.bioEn,
      bioAr: bioAr ?? this.bioAr,
      isPermanentStaff: isPermanentStaff ?? this.isPermanentStaff,
      linkedEmail: linkedEmail ?? this.linkedEmail,
      youtubeHandle: youtubeHandle ?? this.youtubeHandle,
      permissions: permissions ?? this.permissions,
    );
  }
}
