import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';

/// Lightweight Viewer / Student Quick Profile Setup
class ViewerSetupScreen extends StatefulWidget {
  const ViewerSetupScreen({super.key});

  @override
  State<ViewerSetupScreen> createState() => _ViewerSetupScreenState();
}

class _ViewerSetupScreenState extends State<ViewerSetupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _selectedAvatarUrl;
  bool _isLoading = false;

  final List<String> _avatarPresets = [
    'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    'assets/images/Dalilak/profile1.jpg',
    'assets/images/Dalilak/profile2.jpg',
    'assets/images/Dalilak/profile3.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatarUrl = _avatarPresets.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      if (image != null) {
        setState(() {
          _selectedAvatarUrl = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _handleEnter() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('viewer_setup.error_name_empty'.tr()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<AppProvider>();

    try {
      await provider.setupGuestViewer(
        name: name,
        avatarUrl: _selectedAvatarUrl,
      );
      if (!mounted) return;
      context.go('/feed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Setup error: $e'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimaryDark),
          onPressed: () => context.go('/welcome'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceLg,
              vertical: AppTheme.spaceMd,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isDesktop ? 600 : 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Title & Subtitle
                  const Icon(
                    Icons.account_circle_outlined,
                    size: 56,
                    color: AppTheme.accentBlue,
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Text(
                    'viewer_setup.title'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'viewer_setup.subtitle'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textSecondaryDark,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spaceLg),

                  // Avatar Selection Row
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spaceMd),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface1,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(color: AppTheme.darkBorderSubtle),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'viewer_setup.avatar_section_title'.tr(),
                          style: const TextStyle(
                            color: AppTheme.textPrimaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceMd),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ..._avatarPresets.map((preset) {
                              final isSelected = _selectedAvatarUrl == preset;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedAvatarUrl = preset),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
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
                                    radius: 22,
                                    backgroundImage: AssetImage(preset),
                                  ),
                                ),
                              );
                            }),
                            // Pick from device button
                            GestureDetector(
                              onTap: _pickCustomAvatar,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.darkSurface2,
                                  border: Border.all(
                                    color: AppTheme.darkBorderSubtle,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_photo_alternate_rounded,
                                  size: 20,
                                  color: AppTheme.accentBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),

                  // Display Name Text Field
                  TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark),
                    decoration: InputDecoration(
                      labelText: 'viewer_setup.name_label'.tr(),
                      labelStyle: const TextStyle(color: AppTheme.textSecondaryDark),
                      hintText: 'viewer_setup.name_hint'.tr(),
                      hintStyle: const TextStyle(color: AppTheme.textMutedDark),
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          color: AppTheme.accentBlue),
                      filled: true,
                      fillColor: AppTheme.darkSurface1,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: const BorderSide(color: AppTheme.accentBlue, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXl),

                  // Enter Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        elevation: 2,
                      ),
                      onPressed: _isLoading ? null : _handleEnter,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'viewer_setup.btn_enter'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Transform.scale(
                                  scaleX: context.locale.languageCode == 'ar' ? -1.0 : 1.0,
                                  child: const Icon(Icons.arrow_forward_rounded, size: 18),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
