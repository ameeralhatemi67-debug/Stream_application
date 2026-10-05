import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_fields.dart';

class TagsFilterBottomSheet extends StatelessWidget {
  const TagsFilterBottomSheet({super.key});

  static void show(BuildContext context) {
    showCaSheet(context,
        title: '',
        framed: false,
        fullWidthOnPhone: true,
        flushOnPhone: true,
        body: Builder(
            builder: (context) => const SafeArea(
                top: false, child: TagsFilterBottomSheet())));
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final selectedTag = appProvider.selectedTagFilter;
    final selectedCat = appProvider.currentCategoryFilter;
    final langCode = context.locale.languageCode;
    // Cluster 3 Task 12: only approved tags are ever offered here.
    final allTags = ['all', ...appProvider.approvedTags];

    return CaSheet(
      bareChrome: true,
      title: 'ds.filter_title'.tr(),
      onClose: () => Navigator.pop(context),
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('feed.academic_fields'.tr(),
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTheme.spaceSm),
        Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              _buildCatChip(context, appProvider, 'all', 'feed.cat_all'.tr(),
                  selectedCat),
              for (final category
                  in appProvider.academicCategories.where((c) => c.isActive))
                _buildCatChip(context, appProvider, category.id,
                    category.getLocalizedName(langCode), selectedCat),
            ]),
        const SizedBox(height: AppTheme.spaceXl),
        Text('feed.tags'.tr(), style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTheme.spaceSm),
        Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: allTags.map((tag) {
              final isSelected =
                  (tag == 'all' && selectedTag == 'all') || selectedTag == tag;
              final label = tag == 'all' ? 'feed.all_tags'.tr() : tag;
              return CaChip(
                  label: label,
                  selected: isSelected,
                  onSelected: (selected) {
                    appProvider.setSelectedTagFilter(selected ? tag : 'all');
                  });
            }).toList()),
      ]),
      actions: [
        CaButton(
            label: 'common.confirm'.tr(),
            onPressed: () => Navigator.pop(context))
      ],
    );
  }

  Widget _buildCatChip(BuildContext context, AppProvider provider, String catId,
      String label, String selectedCat) {
    final isSelected =
        (catId == 'all' && selectedCat == 'all') || (selectedCat == catId);
    return CaChip(
        label: label,
        selected: isSelected,
        onSelected: (selected) {
          provider.setCategoryFilter(selected ? catId : 'all');
        });
  }
}
