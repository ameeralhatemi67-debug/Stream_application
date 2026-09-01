import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';

/// Lightweight editor for a non-verified viewer's own display identity
/// (name EN/AR + avatar) -- strictly separate from the Broadcaster
/// Application flow. A plain viewer never has enough submitted info to
/// justify opening BroadcasterApplicationSheet; this dialog is the only
/// thing "Edit Profile" should open for them (issue_log.md).
class ViewerProfileEditorDialog extends StatefulWidget {
  const ViewerProfileEditorDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ViewerProfileEditorDialog(),
    );
  }

  @override
  State<ViewerProfileEditorDialog> createState() =>
      _ViewerProfileEditorDialogState();
}

class _ViewerProfileEditorDialogState
    extends State<ViewerProfileEditorDialog> {
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  final ImagePicker _picker = ImagePicker();
  String? _avatarUrl;
  bool _isSaving = false;

  static const List<String> _avatarPresets = [
    'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    'assets/images/Dalilak/profile1.jpg',
    'assets/images/Dalilak/profile2.jpg',
    'assets/images/Dalilak/profile3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppProvider>().userProfile;
    _nameEnController = TextEditingController(text: profile.nameEn);
    _nameArController = TextEditingController(text: profile.nameAr);
    _avatarUrl = profile.avatarUrl;
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameArController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() => _avatarUrl = image.path);
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _handleSave() async {
    final nameEn = _nameEnController.text.trim();
    final nameAr = _nameArController.text.trim();
    if (nameEn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('viewer_setup.error_name_empty'.tr()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<AppProvider>().updateViewerProfile(
            nameEn: nameEn,
            nameAr: nameAr.isEmpty ? nameEn : nameAr,
            avatarUrl: _avatarUrl,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.darkBorderSubtle),
      ),
      title: Row(
        children: [
          const Icon(Icons.account_circle_outlined,
              color: AppTheme.accentBlue, size: 22),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              'settings.edit_profile'.tr(),
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ..._avatarPresets.map((preset) {
                      final isSelected = _avatarUrl == preset;
                      return GestureDetector(
                        onTap: () => setState(() => _avatarUrl = preset),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentBlue
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: AssetImage(preset),
                          ),
                        ),
                      );
                    }),
                    GestureDetector(
                      onTap: _pickCustomAvatar,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.darkSurface2,
                          border: Border.all(color: AppTheme.darkBorderSubtle),
                          image: (_avatarUrl != null &&
                                  !_avatarPresets.contains(_avatarUrl))
                              ? DecorationImage(
                                  image: buildSafeImageProvider(
                                      path: _avatarUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: (_avatarUrl != null &&
                                !_avatarPresets.contains(_avatarUrl))
                            ? null
                            : const Icon(Icons.add_photo_alternate_rounded,
                                size: 18, color: AppTheme.accentBlue),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              TextField(
                controller: _nameEnController,
                style: const TextStyle(color: AppTheme.textPrimaryDark),
                decoration: InputDecoration(
                  labelText: 'viewer_setup.name_label'.tr(),
                  prefixIcon: const Icon(Icons.badge_outlined,
                      color: AppTheme.accentBlue),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: _nameArController,
                textDirection: ui.TextDirection.rtl,
                style: const TextStyle(color: AppTheme.textPrimaryDark),
                decoration: const InputDecoration(
                  labelText: 'الاسم بالعربية',
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: AppTheme.accentBlue),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr(),
              style: const TextStyle(color: AppTheme.textSecondaryDark)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSaving ? null : _handleSave,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text('common.save'.tr()),
        ),
      ],
    );
  }
}
