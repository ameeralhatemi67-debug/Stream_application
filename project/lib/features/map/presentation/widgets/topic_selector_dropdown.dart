import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_theme.dart';

class AcademicTopicItem {
  final String id;
  final String titleEn;
  final String titleAr;
  final IconData icon;

  const AcademicTopicItem({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.icon,
  });

  String getLocalizedTitle(String langCode) =>
      langCode == 'ar' ? titleAr : titleEn;
}

const List<AcademicTopicItem> kAcademicTopics = [
  AcademicTopicItem(
    id: 'all',
    titleEn: 'All Topics',
    titleAr: 'جميع المواضيع',
    icon: Icons.category_rounded,
  ),
  AcademicTopicItem(
    id: 'computer_science',
    titleEn: 'Computer Science & AI',
    titleAr: 'الحاسب والذكاء الاصطناعي',
    icon: Icons.memory_rounded,
  ),
  AcademicTopicItem(
    id: 'islamic_studies',
    titleEn: 'Islamic Studies & Sharia',
    titleAr: 'الدراسات الإسلامية والشريعة',
    icon: Icons.auto_stories_rounded,
  ),
  AcademicTopicItem(
    id: 'medicine',
    titleEn: 'Medicine & Health',
    titleAr: 'الطب والعلوم الصحية',
    icon: Icons.medical_services_rounded,
  ),
  AcademicTopicItem(
    id: 'engineering',
    titleEn: 'Engineering & Innovation',
    titleAr: 'الهندسة والابتكار',
    icon: Icons.engineering_rounded,
  ),
];

class TopicSelectorDropdown extends StatelessWidget {
  final String selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  const TopicSelectorDropdown({
    super.key,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = context.locale.languageCode;
    final currentTopic = kAcademicTopics.firstWhere(
      (t) =>
          t.id == selectedCategoryId ||
          (selectedCategoryId == 'cs_tech' && t.id == 'computer_science'),
      orElse: () => kAcademicTopics.first,
    );

    return PopupMenuButton<String>(
      onSelected: onCategorySelected,
      color: AppTheme.darkSurface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        side: const BorderSide(color: AppTheme.darkBorderSubtle, width: 1.0),
      ),
      offset: const Offset(0, 44),
      itemBuilder: (context) {
        return kAcademicTopics.map((topic) {
          final isCurrent = topic.id == selectedCategoryId ||
              (selectedCategoryId == 'cs_tech' &&
                  topic.id == 'computer_science');
          return PopupMenuItem<String>(
            value: topic.id,
            child: Row(
              children: [
                Icon(
                  topic.icon,
                  size: 18,
                  color: isCurrent ? AppTheme.accentPurple : AppTheme.textMutedDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    topic.getLocalizedTitle(langCode),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppTheme.accentPurple : AppTheme.textPrimaryDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCurrent)
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: AppTheme.accentPurple,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(14.0),
          border: Border.all(
            color: AppTheme.darkBorderSubtle,
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
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
                    currentTopic.icon,
                    size: 16,
                    color: AppTheme.accentPurple,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      currentTopic.getLocalizedTitle(langCode),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
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
              color: AppTheme.textMutedDark,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
