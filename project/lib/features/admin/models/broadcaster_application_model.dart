import 'package:flutter/foundation.dart';

enum ApplicationAccountType {
  individualScholar,
  organizationVenue,
}

enum ApplicationStatus {
  pending,
  approved,
  rejected,
  suspended,
}

/// Comprehensive Model for Broadcaster & Organization Verification Applications
@immutable
class BroadcasterApplicationModel {
  final String id;
  final ApplicationAccountType accountType;
  final String applicantNameEn;
  final String applicantNameAr;
  final String email;
  final String phone;

  // Scholar-specific fields
  final String? academicTitleEn;
  final String? academicTitleAr;
  final String? institutionEn;
  final String? institutionAr;
  final String categoryId;
  final List<String> tags;

  // Organization-specific fields
  final String? organizationType;
  final String venueNameEn;
  final String venueNameAr;
  final double latitude;
  final double longitude;
  final int seatingCapacity;
  final String? officialWebsiteUrl;

  // Streaming & Profile metadata
  final String youtubeChannelUrl;
  final String youtubeHandle;
  final String bioEn;
  final String bioAr;
  final String avatarUrl;
  final String bannerUrl;

  // Lifecycle & Moderation state
  final ApplicationStatus status;
  final String? adminReviewNotes;
  final String? reviewedBy;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  const BroadcasterApplicationModel({
    required this.id,
    required this.accountType,
    required this.applicantNameEn,
    required this.applicantNameAr,
    required this.email,
    required this.phone,
    this.academicTitleEn,
    this.academicTitleAr,
    this.institutionEn,
    this.institutionAr,
    required this.categoryId,
    this.tags = const [],
    this.organizationType,
    required this.venueNameEn,
    required this.venueNameAr,
    required this.latitude,
    required this.longitude,
    this.seatingCapacity = 0,
    this.officialWebsiteUrl,
    required this.youtubeChannelUrl,
    required this.youtubeHandle,
    required this.bioEn,
    required this.bioAr,
    required this.avatarUrl,
    required this.bannerUrl,
    this.status = ApplicationStatus.pending,
    this.adminReviewNotes,
    this.reviewedBy,
    required this.submittedAt,
    this.reviewedAt,
  });

  bool get isOrganization => accountType == ApplicationAccountType.organizationVenue;
  bool get isPending => status == ApplicationStatus.pending;
  bool get isApproved => status == ApplicationStatus.approved;
  bool get isRejected => status == ApplicationStatus.rejected;
  bool get isSuspended => status == ApplicationStatus.suspended;
  String? get reviewNotes => adminReviewNotes;

  String getLocalizedApplicantName(String languageCode) =>
      languageCode == 'ar' ? applicantNameAr : applicantNameEn;

  String getLocalizedTitle(String languageCode) {
    if (isOrganization) {
      return organizationType ?? (languageCode == 'ar' ? 'منظمة تعليمية' : 'Educational Organization');
    }
    return languageCode == 'ar'
        ? (academicTitleAr ?? 'محاضر أكاديمي')
        : (academicTitleEn ?? 'Academic Lecturer');
  }

  String getLocalizedInstitution(String languageCode) =>
      languageCode == 'ar'
          ? (institutionAr ?? applicantNameAr)
          : (institutionEn ?? applicantNameEn);

  String getLocalizedVenue(String languageCode) =>
      languageCode == 'ar' ? venueNameAr : venueNameEn;

  String getLocalizedBio(String languageCode) =>
      languageCode == 'ar' ? bioAr : bioEn;

  BroadcasterApplicationModel copyWith({
    String? id,
    ApplicationAccountType? accountType,
    String? applicantNameEn,
    String? applicantNameAr,
    String? email,
    String? phone,
    String? academicTitleEn,
    String? academicTitleAr,
    String? institutionEn,
    String? institutionAr,
    String? categoryId,
    List<String>? tags,
    String? organizationType,
    String? venueNameEn,
    String? venueNameAr,
    double? latitude,
    double? longitude,
    int? seatingCapacity,
    String? officialWebsiteUrl,
    String? youtubeChannelUrl,
    String? youtubeHandle,
    String? bioEn,
    String? bioAr,
    String? avatarUrl,
    String? bannerUrl,
    ApplicationStatus? status,
    String? adminReviewNotes,
    String? reviewedBy,
    DateTime? submittedAt,
    DateTime? reviewedAt,
  }) {
    return BroadcasterApplicationModel(
      id: id ?? this.id,
      accountType: accountType ?? this.accountType,
      applicantNameEn: applicantNameEn ?? this.applicantNameEn,
      applicantNameAr: applicantNameAr ?? this.applicantNameAr,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      academicTitleEn: academicTitleEn ?? this.academicTitleEn,
      academicTitleAr: academicTitleAr ?? this.academicTitleAr,
      institutionEn: institutionEn ?? this.institutionEn,
      institutionAr: institutionAr ?? this.institutionAr,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      organizationType: organizationType ?? this.organizationType,
      venueNameEn: venueNameEn ?? this.venueNameEn,
      venueNameAr: venueNameAr ?? this.venueNameAr,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      officialWebsiteUrl: officialWebsiteUrl ?? this.officialWebsiteUrl,
      youtubeChannelUrl: youtubeChannelUrl ?? this.youtubeChannelUrl,
      youtubeHandle: youtubeHandle ?? this.youtubeHandle,
      bioEn: bioEn ?? this.bioEn,
      bioAr: bioAr ?? this.bioAr,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      status: status ?? this.status,
      adminReviewNotes: adminReviewNotes ?? this.adminReviewNotes,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      submittedAt: submittedAt ?? this.submittedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountType': accountType.name,
        'applicantNameEn': applicantNameEn,
        'applicantNameAr': applicantNameAr,
        'email': email,
        'phone': phone,
        'academicTitleEn': academicTitleEn,
        'academicTitleAr': academicTitleAr,
        'institutionEn': institutionEn,
        'institutionAr': institutionAr,
        'categoryId': categoryId,
        'tags': tags,
        'organizationType': organizationType,
        'venueNameEn': venueNameEn,
        'venueNameAr': venueNameAr,
        'latitude': latitude,
        'longitude': longitude,
        'seatingCapacity': seatingCapacity,
        'officialWebsiteUrl': officialWebsiteUrl,
        'youtubeChannelUrl': youtubeChannelUrl,
        'youtubeHandle': youtubeHandle,
        'bioEn': bioEn,
        'bioAr': bioAr,
        'avatarUrl': avatarUrl,
        'bannerUrl': bannerUrl,
        'status': status.name,
        'adminReviewNotes': adminReviewNotes,
        'reviewedBy': reviewedBy,
        'submittedAt': submittedAt.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
      };

  factory BroadcasterApplicationModel.fromJson(Map<String, dynamic> json) =>
      BroadcasterApplicationModel(
        id: json['id'] as String,
        accountType: ApplicationAccountType.values.byName(
            json['accountType'] as String? ?? 'individualScholar'),
        applicantNameEn: json['applicantNameEn'] as String? ?? '',
        applicantNameAr: json['applicantNameAr'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        academicTitleEn: json['academicTitleEn'] as String?,
        academicTitleAr: json['academicTitleAr'] as String?,
        institutionEn: json['institutionEn'] as String?,
        institutionAr: json['institutionAr'] as String?,
        categoryId: json['categoryId'] as String? ?? 'computer_science',
        tags: List<String>.from(json['tags'] as List? ?? ['#Education']),
        organizationType: json['organizationType'] as String?,
        venueNameEn: json['venueNameEn'] as String? ?? '',
        venueNameAr: json['venueNameAr'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 26.2871,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 50.2125,
        seatingCapacity: (json['seatingCapacity'] as num?)?.toInt() ?? 0,
        officialWebsiteUrl: json['officialWebsiteUrl'] as String?,
        youtubeChannelUrl: json['youtubeChannelUrl'] as String? ?? '',
        youtubeHandle: json['youtubeHandle'] as String? ?? '',
        bioEn: json['bioEn'] as String? ?? '',
        bioAr: json['bioAr'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ??
            'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: json['bannerUrl'] as String? ??
            'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        status: ApplicationStatus.values
            .byName(json['status'] as String? ?? 'pending'),
        adminReviewNotes: json['adminReviewNotes'] as String?,
        reviewedBy: json['reviewedBy'] as String?,
        submittedAt: DateTime.parse(json['submittedAt'] as String),
        reviewedAt: json['reviewedAt'] != null
            ? DateTime.parse(json['reviewedAt'] as String)
            : null,
      );
}
