import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../discovery/models/academic_category_model.dart';

/// Maps `AcademicCategoryModel.iconName` (a Material icon identifier stored
/// as plain text in `academic_categories.icon_name`) to the actual
/// [IconData] Flutter needs to render it. Falls back to a generic school cap
/// for any name an admin enters that isn't in this known set -- new icon
/// names are still safe to store, they just render generically until this
/// map is extended.
IconData iconForCategoryIconName(String iconName) {
  switch (iconName) {
    case 'mosque':
      return Icons.mosque_rounded;
    case 'computer':
      return Icons.memory_rounded;
    case 'engineering':
      return Icons.engineering_rounded;
    case 'medical_services':
      return Icons.medical_services_rounded;
    case 'business_center':
      return Icons.business_center_rounded;
    case 'translate':
      return Icons.translate_rounded;
    case 'functions':
      return Icons.functions_rounded;
    case 'architecture':
      return Icons.architecture_rounded;
    case 'category':
      return Icons.category_rounded;
    default:
      return Icons.school_rounded;
  }
}

/// The Spatial Map's topic dropdown (Cluster 3 Task 10) -- consumes the live
/// `AppProvider.academicCategories` list instead of a hardcoded constant, so
/// an admin's category edit (Task 11) shows up here immediately. Prepends a
/// synthetic "All Topics"entry (id 'all'), matching the discovery feed's
/// "All"chip.
class TopicSelectorDropdown extends StatelessWidget {
  final String selectedCategoryId;
  final ValueChanged<String> onCategorySelected;
  final List<AcademicCategoryModel> categories;

  const TopicSelectorDropdown({
    super.key,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final allTopicsLabel = 'map.all_topics'.tr();

    final currentLabel = selectedCategoryId == 'all'
        ? allTopicsLabel
        : categories
            .firstWhere(
              (c) => c.id == selectedCategoryId,
              orElse: () => AcademicCategoryModel(
                  id: 'all', nameEn: allTopicsLabel, nameAr: allTopicsLabel),
            )
            .getLocalizedName(langCode);
    final currentIcon = selectedCategoryId == 'all'
        ? Icons.category_rounded
        : iconForCategoryIconName(
            categories
                .firstWhere(
                  (c) => c.id == selectedCategoryId,
                  orElse: () => const AcademicCategoryModel(
                      id: 'all', nameEn: '', nameAr: ''),
                )
                .iconName,
          );

    return PopupMenuButton<String>(
      onSelected: onCategorySelected,
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.border, width: 1.0),
      ),
      offset: const Offset(0, 44),
      itemBuilder: (context) {
        return [
          _buildItem(
            id: 'all',
            label: allTopicsLabel,
            icon: Icons.category_rounded,
          ),
          ...categories.where((c) => c.isActive).map((c) => _buildItem(
                id: c.id,
                label: c.getLocalizedName(langCode),
                icon: iconForCategoryIconName(c.iconName),
              )),
        ];
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: AppTheme.border,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppTheme.shadowSoft,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    currentIcon,
                    size: 16,
                    color: AppTheme.accent,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      currentLabel,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildItem({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final isCurrent = id == selectedCategoryId;
    return PopupMenuItem<String>(
      value: id,
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isCurrent ? AppTheme.accent : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                color:
                    isCurrent ? AppTheme.accent : AppTheme.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isCurrent)
            const Icon(
              Icons.check_rounded,
              size: 16,
              color: AppTheme.accent,
            ),
        ],
      ),
    );
  }
}
