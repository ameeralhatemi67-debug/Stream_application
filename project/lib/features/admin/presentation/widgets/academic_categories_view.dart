import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../discovery/models/academic_category_model.dart';
import '../../../map/presentation/widgets/topic_selector_dropdown.dart'
    show iconForCategoryIconName;

/// Admin Academic Categories manager (Cluster 3 Task 11): create, edit,
/// reorder, and deactivate/delete the taxonomy every Discovery/Map/tag
/// filter chip reads from `AppProvider.academicCategories`.
class AcademicCategoriesView extends StatefulWidget {
  const AcademicCategoriesView({super.key});

  @override
  State<AcademicCategoriesView> createState() =>
      _AcademicCategoriesViewState();
}

class _AcademicCategoriesViewState extends State<AcademicCategoriesView> {
  final Set<String> _actingOnIds = {};

  @override
  void initState() {
    super.initState();
    context.read<AppProvider>().ensureAcademicCategoriesLoaded();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.accentRed : AppTheme.accentGreen,
      ),
    );
  }

  Future<void> _run(String id, Future<void> Function() action,
      String successMessage) async {
    setState(() => _actingOnIds.add(id));
    try {
      await action();
      _showToast(successMessage);
    } catch (e) {
      _showToast('$e', isError: true);
    } finally {
      if (mounted) setState(() => _actingOnIds.remove(id));
    }
  }

  Future<void> _reorder(
      AppProvider provider, List<AcademicCategoryModel> sorted, int index, int delta) async {
    final targetIndex = index + delta;
    if (targetIndex < 0 || targetIndex >= sorted.length) return;
    final a = sorted[index];
    final b = sorted[targetIndex];
    await provider.saveAcademicCategory(a.copyWith(sortOrder: b.sortOrder));
    await provider.saveAcademicCategory(b.copyWith(sortOrder: a.sortOrder));
  }

  void _showEditDialog(AppProvider provider, {AcademicCategoryModel? existing}) {
    final idController = TextEditingController(text: existing?.id ?? '');
    final nameEnController = TextEditingController(text: existing?.nameEn ?? '');
    final nameArController = TextEditingController(text: existing?.nameAr ?? '');
    final iconController =
        TextEditingController(text: existing?.iconName ?? 'school');
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.darkSurface1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: const BorderSide(color: AppTheme.darkBorderSubtle),
          ),
          title: Text(
            existing == null
                ? 'admin.category_add'.tr()
                : 'admin.category_edit'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (existing == null)
                  _dialogField(idController, 'admin.category_id_label'.tr(),
                      hint: 'admin.category_id_hint'.tr()),
                _dialogField(nameEnController, 'admin.category_name_en'.tr()),
                _dialogField(nameArController, 'admin.category_name_ar'.tr()),
                _dialogField(iconController, 'admin.category_icon'.tr()),
                const SizedBox(height: AppTheme.spaceSm),
                Row(
                  children: [
                    Checkbox(
                      value: isActive,
                      activeColor: AppTheme.accentGreen,
                      onChanged: (v) =>
                          setDialogState(() => isActive = v ?? true),
                    ),
                    Text('admin.category_active'.tr(),
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr(),
                  style: const TextStyle(color: AppTheme.textMutedDark)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: Colors.white),
              onPressed: () {
                final id = (existing?.id ?? idController.text.trim())
                    .toLowerCase()
                    .replaceAll(RegExp(r'\s+'), '_');
                if (id.isEmpty || nameEnController.text.trim().isEmpty) return;
                Navigator.pop(dialogContext);
                _run(
                  id,
                  () => provider.saveAcademicCategory(AcademicCategoryModel(
                    id: id,
                    nameEn: nameEnController.text.trim(),
                    nameAr: nameArController.text.trim(),
                    iconName: iconController.text.trim().isEmpty
                        ? 'school'
                        : iconController.text.trim(),
                    sortOrder: existing?.sortOrder ??
                        provider.academicCategories.length,
                    isActive: isActive,
                  )),
                  'admin.category_saved_toast'.tr(),
                );
              },
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController controller, String label,
      {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: AppTheme.textSecondaryDark),
          hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11),
          filled: true,
          fillColor: AppTheme.darkSurface2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(AppProvider provider, AcademicCategoryModel category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
        title: Text('admin.category_delete_confirm_title'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimaryDark, fontWeight: FontWeight.bold)),
        content: Text('admin.category_delete_confirm_body'.tr(),
            style:
                const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMutedDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext);
              _run(
                category.id,
                () => provider.deleteAcademicCategory(category.id),
                'admin.category_deleted_toast'.tr(),
              );
            },
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final categories = context.select<AppProvider, List<AcademicCategoryModel>>(
        (p) => p.academicCategories);
    final sorted = [...categories]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final langCode = context.locale.languageCode;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_rounded,
                  color: AppTheme.accentBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.tab_categories'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentBlue,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('admin.category_add'.tr()),
                onPressed: () => _showEditDialog(provider),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: Text('admin.no_categories'.tr(),
                        style: const TextStyle(
                            color: AppTheme.textSecondaryDark)))
                : ListView.separated(
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spaceMd),
                    itemBuilder: (context, index) {
                      final category = sorted[index];
                      final isActing = _actingOnIds.contains(category.id);
                      return Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: AppTheme.darkSurface1,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.darkBorderSubtle),
                        ),
                        child: Row(
                          children: [
                            Icon(iconForCategoryIconName(category.iconName),
                                color: category.isActive
                                    ? AppTheme.accentBlue
                                    : AppTheme.textMutedDark,
                                size: 20),
                            const SizedBox(width: AppTheme.spaceMd),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    category.getLocalizedName(langCode),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: category.isActive
                                          ? AppTheme.textPrimaryDark
                                          : AppTheme.textMutedDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    category.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textMutedDark,
                                        fontSize: 10.5),
                                  ),
                                ],
                              ),
                            ),
                            if (isActing)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.accentBlue),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.arrow_upward_rounded,
                                    size: 16, color: AppTheme.textSecondaryDark),
                                onPressed: index == 0
                                    ? null
                                    : () => _reorder(provider, sorted, index, -1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward_rounded,
                                    size: 16, color: AppTheme.textSecondaryDark),
                                onPressed: index == sorted.length - 1
                                    ? null
                                    : () => _reorder(provider, sorted, index, 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    size: 16, color: AppTheme.accentBlue),
                                onPressed: () =>
                                    _showEditDialog(provider, existing: category),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: AppTheme.accentRed),
                                onPressed: () =>
                                    _confirmDelete(provider, category),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
