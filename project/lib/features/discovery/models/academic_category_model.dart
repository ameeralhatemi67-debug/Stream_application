import 'package:flutter/foundation.dart';

/// A row from `academic_categories` (see
/// supabase/migrations/20260830130000_academic_categories.sql). Drives the
/// Discovery feed's category chips, the Spatial Map's topic dropdown, and the
/// tags filter sheet's category section -- all three read the same
/// `AppProvider.academicCategories` list instead of a hardcoded constant, so
/// an admin edit (Task 11) is instantly visible everywhere.
@immutable
class AcademicCategoryModel {
  final String id;
  final String nameEn;
  final String nameAr;
  final String iconName;
  final int sortOrder;
  final bool isActive;

  const AcademicCategoryModel({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    this.iconName = 'school',
    this.sortOrder = 0,
    this.isActive = true,
  });

  String getLocalizedName(String langCode) =>
      langCode == 'ar' ? nameAr : nameEn;

  factory AcademicCategoryModel.fromJson(Map<String, dynamic> json) {
    return AcademicCategoryModel(
      id: json['id'] as String,
      nameEn: json['name_en'] as String? ?? '',
      nameAr: json['name_ar'] as String? ?? '',
      iconName: json['icon_name'] as String? ?? 'school',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_en': nameEn,
        'name_ar': nameAr,
        'icon_name': iconName,
        'sort_order': sortOrder,
        'is_active': isActive,
      };

  AcademicCategoryModel copyWith({
    String? nameEn,
    String? nameAr,
    String? iconName,
    int? sortOrder,
    bool? isActive,
  }) {
    return AcademicCategoryModel(
      id: id,
      nameEn: nameEn ?? this.nameEn,
      nameAr: nameAr ?? this.nameAr,
      iconName: iconName ?? this.iconName,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  /// Default pool shown before the backend list has loaded (or if Supabase
  /// is unreachable) -- identical to the seed rows in the migration, so
  /// behavior is unchanged for a cold client.
  static const List<AcademicCategoryModel> defaultPool = [
    AcademicCategoryModel(
        id: 'islamic_studies',
        nameEn: 'Islamic Studies',
        nameAr: 'الدراسات الإسلامية',
        iconName: 'mosque',
        sortOrder: 0),
    AcademicCategoryModel(
        id: 'computer_science',
        nameEn: 'Computer Science',
        nameAr: 'علوم الحاسب',
        iconName: 'computer',
        sortOrder: 1),
    AcademicCategoryModel(
        id: 'engineering',
        nameEn: 'Engineering',
        nameAr: 'الهندسة',
        iconName: 'engineering',
        sortOrder: 2),
    AcademicCategoryModel(
        id: 'medicine',
        nameEn: 'Medicine',
        nameAr: 'الطب',
        iconName: 'medical_services',
        sortOrder: 3),
    AcademicCategoryModel(
        id: 'business',
        nameEn: 'Business',
        nameAr: 'إدارة الأعمال',
        iconName: 'business_center',
        sortOrder: 4),
    AcademicCategoryModel(
        id: 'linguistics',
        nameEn: 'Linguistics',
        nameAr: 'اللغويات',
        iconName: 'translate',
        sortOrder: 5),
    AcademicCategoryModel(
        id: 'mathematics',
        nameEn: 'Mathematics',
        nameAr: 'الرياضيات',
        iconName: 'functions',
        sortOrder: 6),
    AcademicCategoryModel(
        id: 'architecture',
        nameEn: 'Architecture',
        nameAr: 'العمارة',
        iconName: 'architecture',
        sortOrder: 7),
  ];
}
