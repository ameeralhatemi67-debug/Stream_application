import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../discovery/models/academic_category_model.dart';
import '../../../map/presentation/widgets/topic_selector_dropdown.dart'
    show iconForCategoryIconName;

const List<Map<String, dynamic>> kAvailableCategoryIcons = [
  {'name': 'school', 'icon': Icons.school_rounded, 'label': 'Education / School'},
  {'name': 'mosque', 'icon': Icons.mosque_rounded, 'label': 'Islamic / Religious'},
  {'name': 'computer', 'icon': Icons.computer_rounded, 'label': 'Computer Science / Tech'},
  {'name': 'engineering', 'icon': Icons.engineering_rounded, 'label': 'Engineering'},
  {'name': 'medical_services', 'icon': Icons.medical_services_rounded, 'label': 'Medicine / Healthcare'},
  {'name': 'business_center', 'icon': Icons.business_center_rounded, 'label': 'Business / Economics'},
  {'name': 'menu_book', 'icon': Icons.menu_book_rounded, 'label': 'Literature / Humanities'},
  {'name': 'science', 'icon': Icons.science_rounded, 'label': 'Science / Physics'},
  {'name': 'psychology', 'icon': Icons.psychology_rounded, 'label': 'Psychology / Social'},
  {'name': 'architecture', 'icon': Icons.architecture_rounded, 'label': 'Architecture / Design'},
  {'name': 'palette', 'icon': Icons.palette_rounded, 'label': 'Arts / Media'},
  {'name': 'gavel', 'icon': Icons.gavel_rounded, 'label': 'Law / Jurisprudence'},
  {'name': 'public', 'icon': Icons.public_rounded, 'label': 'Global / International'},
  {'name': 'calculate', 'icon': Icons.calculate_rounded, 'label': 'Mathematics'},
  {'name': 'biotech', 'icon': Icons.biotech_rounded, 'label': 'Biology / Chemistry'},
  {'name': 'history_edu', 'icon': Icons.history_edu_rounded, 'label': 'History / Heritage'},
];

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
        backgroundColor: isError ? AppTheme.danger : AppTheme.success,
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

  void _showIconPickerModal(
      BuildContext context, void Function(String) onSelect) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('design_ui.select_category_icon'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.1,
                ),
                itemCount: kAvailableCategoryIcons.length,
                itemBuilder: (ctx, i) {
                  final item = kAvailableCategoryIcons[i];
                  return InkWell(
                    onTap: () {
                      onSelect(item['name'] as String);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item['icon'] as IconData,
                              color: AppTheme.primary, size: 24),
                          const SizedBox(height: 4),
                          Text(
                            item['name'] as String,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(AppProvider provider, {AcademicCategoryModel? existing}) {
    final idController = TextEditingController(text: existing?.id ?? '');
    final nameEnController = TextEditingController(text: existing?.nameEn ?? '');
    final nameArController = TextEditingController(text: existing?.nameAr ?? '');
    final iconController =
        TextEditingController(text: existing?.iconName ?? 'school');
    bool isActive = existing?.isActive ?? true;

    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    final latinRegex = RegExp(r'[a-zA-Z]');

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final enHasArabic = arabicRegex.hasMatch(nameEnController.text);
          final arHasEnglish = latinRegex.hasMatch(nameArController.text);

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: const BorderSide(color: AppTheme.border),
            ),
            title: Text(
              existing == null
                  ? 'admin.category_add'.tr()
                  : 'admin.category_edit'.tr(),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (existing == null)
                      _dialogField(
                        idController,
                        'admin.category_id_label'.tr(),
                        hint: 'admin.category_id_hint'.tr(),
                        onChanged: () => setDialogState(() {}),
                      ),
                    _dialogField(
                      nameEnController,
                      'admin.category_name_en'.tr(),
                      onChanged: () => setDialogState(() {}),
                      errorText: enHasArabic
                          ? 'Warning: English name should be in Latin letters'
                          : null,
                    ),
                    _dialogField(
                      nameArController,
                      'admin.category_name_ar'.tr(),
                      onChanged: () => setDialogState(() {}),
                      errorText: arHasEnglish
                          ? 'تنبيه: الاسم بالعربية يجب أن يكون بالحروف العربية'
                          : null,
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Expanded(
                          child: _dialogField(
                            iconController,
                            'admin.category_icon'.tr(),
                            onChanged: () => setDialogState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.surfaceAlt,
                              foregroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                side: const BorderSide(color: AppTheme.border),
                              ),
                            ),
                            icon: Icon(iconForCategoryIconName(iconController.text), size: 18),
                            label: Text('design_ui.pick_icon'.tr(), style: const TextStyle(fontSize: 12)),
                            onPressed: () => _showIconPickerModal(context, (name) {
                              setDialogState(() {
                                iconController.text = name;
                              });
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceSm),
                    Row(
                      children: [
                        Checkbox(
                          value: isActive,
                          activeColor: AppTheme.success,
                          onChanged: (v) =>
                              setDialogState(() => isActive = v ?? true),
                        ),
                        Text('admin.category_active'.tr(),
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('common.cancel'.tr(),
                    style: const TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onMedia),
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
          );
        },
      ),
    );
  }

  Widget _dialogField(
    TextEditingController controller,
    String label, {
    String? hint,
    String? errorText,
    VoidCallback? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: (_) => onChanged?.call(),
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              filled: true,
              fillColor: AppTheme.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
          if (errorText != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4, start: 4),
              child: Text(
                errorText,
                style: const TextStyle(
                  color: AppTheme.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(AppProvider provider, AcademicCategoryModel category) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: const BorderSide(color: AppTheme.border),
        ),
        title: Text('admin.category_delete_confirm_title'.tr(),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('admin.category_delete_confirm_body'.tr(),
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('common.cancel'.tr(),
                style: const TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger, foregroundColor: AppTheme.onMedia),
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
                  color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'admin.tab_categories'.tr(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: AppTheme.onMedia),
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
                            color: AppTheme.textSecondary)))
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
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(iconForCategoryIconName(category.iconName),
                                color: category.isActive
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
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
                                          ? AppTheme.textPrimary
                                          : AppTheme.textMuted,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    category.id,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppTheme.textMuted,
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
                                    strokeWidth: 2, color: AppTheme.primary),
                              )
                            else ...[
                              IconButton(
                                icon: const Icon(Icons.arrow_upward_rounded,
                                    size: 16, color: AppTheme.textSecondary),
                                onPressed: index == 0
                                    ? null
                                    : () => _reorder(provider, sorted, index, -1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_downward_rounded,
                                    size: 16, color: AppTheme.textSecondary),
                                onPressed: index == sorted.length - 1
                                    ? null
                                    : () => _reorder(provider, sorted, index, 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    size: 16, color: AppTheme.primary),
                                onPressed: () =>
                                    _showEditDialog(provider, existing: category),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16, color: AppTheme.danger),
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
