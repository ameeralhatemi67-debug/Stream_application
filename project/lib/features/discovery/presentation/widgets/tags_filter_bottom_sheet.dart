import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';

class TagsFilterBottomSheet extends StatelessWidget {
  const TagsFilterBottomSheet({super.key});

  static const List<String> allTags = [
    'all',
    '#AI',
    '#Cloud',
    '#Dev',
    '#Software',
    '#Sharia',
    '#Podcast',
    '#Quran',
    '#Seerah',
    '#Culture',
    '#Dialogue',
    '#History',
    '#Solar',
    '#CleanEnergy',
    '#Innovation',
    '#Cybersecurity',
    '#ZeroTrust',
    '#Networks',
  ];

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => const TagsFilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final selectedTag = appProvider.selectedTagFilter;
    final selectedCat = appProvider.currentCategoryFilter;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spaceLg,
        right: AppTheme.spaceLg,
        top: AppTheme.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Fixed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppTheme.accentRed, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'feed.filter_tags_title'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMutedDark),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: AppTheme.darkBorderSubtle),

          // Scrollable Body
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Topics Filter
                  Text(
                    'feed.academic_fields'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCatChip(context, appProvider, 'all', 'feed.cat_all'.tr(), selectedCat),
                      _buildCatChip(context, appProvider, 'computer_science', 'feed.cat_cs'.tr(), selectedCat),
                      _buildCatChip(context, appProvider, 'islamic_studies', 'feed.cat_sharia'.tr(), selectedCat),
                      _buildCatChip(context, appProvider, 'engineering', 'feed.cat_eng'.tr(), selectedCat),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Tags Filter
                  Text(
                    'feed.tags'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = (tag == 'all' && selectedTag == 'all') || (selectedTag == tag);
                      final label = tag == 'all' ? 'feed.all_tags'.tr() : tag;

                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          appProvider.setSelectedTagFilter(selected ? tag : 'all');
                        },
                        selectedColor: AppTheme.accentRed,
                        backgroundColor: AppTheme.darkSurface2,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Confirm Button (Fixed at Bottom)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              child: Text('dialogs.confirm'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatChip(BuildContext context, AppProvider provider, String catId, String label, String selectedCat) {
    final isSelected = (catId == 'all' && selectedCat == 'all') || (selectedCat == catId);
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        provider.setCategoryFilter(selected ? catId : 'all');
      },
      selectedColor: AppTheme.accentBlue,
      backgroundColor: AppTheme.darkSurface2,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textPrimaryDark,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.accentBlue : AppTheme.darkBorderSubtle,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
