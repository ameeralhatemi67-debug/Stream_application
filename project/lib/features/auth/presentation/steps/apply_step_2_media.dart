import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../widgets/image_arrange_modal.dart';

/// Step 2: Broadcaster Media Assets (Profile Photo & Banner with Auto-Fit & Repositioning)
class ApplyStep2Media extends StatefulWidget {
  final String? avatarPath;
  final String? bannerPath;
  final Uint8List? avatarBytes;
  final Uint8List? bannerBytes;
  final Function(String path, Uint8List? bytes) onAvatarSelected;
  final Function(String path, Uint8List? bytes) onBannerSelected;

  const ApplyStep2Media({
    super.key,
    required this.avatarPath,
    required this.bannerPath,
    this.avatarBytes,
    this.bannerBytes,
    required this.onAvatarSelected,
    required this.onBannerSelected,
  });

  @override
  State<ApplyStep2Media> createState() => _ApplyStep2MediaState();
}

class _ApplyStep2MediaState extends State<ApplyStep2Media> {
  final ImagePicker _picker = ImagePicker();
  String? _avatarError;
  String? _bannerError;

  // The avatar/banner preset strips offered real people's photographs
  // (a named broadcaster and two organizations) as pictures an applicant
  // could adopt as their own. Applicants upload their own image instead
  // (_pickAvatar/_pickBanner below) -- P2 truthful data.

  Future<void> _pickAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        final rawBytes = await image.readAsBytes();
        setState(() => _avatarError = null);

        if (mounted) {
          final cropped = await ImageArrangeModal.show(
            context: context,
            imagePath: image.path,
            imageBytes: rawBytes,
            arrangeType: ImageArrangeType.avatarCircle,
          );

          widget.onAvatarSelected(image.path, cropped ?? rawBytes);
        }
      }
    } catch (e) {
      setState(() => _avatarError = 'Could not read image: $e');
    }
  }

  Future<void> _pickBanner() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (image != null) {
        final rawBytes = await image.readAsBytes();
        setState(() => _bannerError = null);

        if (mounted) {
          final cropped = await ImageArrangeModal.show(
            context: context,
            imagePath: image.path,
            imageBytes: rawBytes,
            arrangeType: ImageArrangeType.banner16x9,
          );

          widget.onBannerSelected(image.path, cropped ?? rawBytes);
        }
      }
    } catch (e) {
      setState(() => _bannerError = 'Could not read banner: $e');
    }
  }

  Future<void> _openArrangeModal(bool isAvatar) async {
    final path = isAvatar ? widget.avatarPath : widget.bannerPath;
    final bytes = isAvatar ? widget.avatarBytes : widget.bannerBytes;
    if (path == null && bytes == null) return;

    final cropped = await ImageArrangeModal.show(
      context: context,
      imagePath: path ?? '',
      imageBytes: bytes,
      arrangeType: isAvatar ? ImageArrangeType.avatarCircle : ImageArrangeType.banner16x9,
    );

    if (cropped != null) {
      if (isAvatar) {
        widget.onAvatarSelected(path ?? 'cropped_avatar.png', cropped);
      } else {
        widget.onBannerSelected(path ?? 'cropped_banner.png', cropped);
      }
    }
  }

  Widget _buildBannerPreview() {
    if (_bannerError != null) {
      return Container(
        height: 150,
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.accentRed, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 28),
            const SizedBox(height: 6),
            Text(
              _bannerError!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final path = widget.bannerPath;
    final bytes = widget.bannerBytes;

    if (path == null && (bytes == null || bytes.isEmpty)) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.darkBorderSubtle, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppTheme.accentRed),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'wizard_steps.step2_banner_tap'.tr(),
                style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    final imgProvider = buildSafeImageProvider(
      path: path,
      bytes: bytes,
      defaultAsset: 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
    );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Image(
            image: imgProvider,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 150,
            errorBuilder: (_, error, __) => Container(
              height: 150,
              color: AppTheme.darkSurface2,
              alignment: Alignment.center,
              child: Text('Image Error: $error', style: const TextStyle(color: AppTheme.accentRed, fontSize: 11)),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.75),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.crop_rotate_rounded, size: 14),
                label: Text('common.arrange'.tr(), style: const TextStyle(fontSize: 11)),
                onPressed: () => _openArrangeModal(false),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                icon: const Icon(Icons.edit_rounded, size: 14),
                label: Text('common.change'.tr(), style: const TextStyle(fontSize: 11)),
                onPressed: _pickBanner,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = buildSafeImageProvider(
      path: widget.avatarPath,
      bytes: widget.avatarBytes,
      defaultAsset: 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'wizard_steps.step2_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step2_desc'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // 🖼️ Banner Section
          Text(
            'wizard_steps.step2_banner_label'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: (widget.bannerPath == null && widget.bannerBytes == null) ? _pickBanner : null,
            child: _buildBannerPreview(),
          ),
          const SizedBox(height: 10),

          const SizedBox(height: AppTheme.spaceLg),

          // 👤 Avatar Section
          Text(
            'wizard_steps.step2_avatar_label'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: AppTheme.darkSurface1,
                      backgroundImage: (widget.avatarPath != null || widget.avatarBytes != null)
                          ? avatarProvider
                          : null,
                      child: (widget.avatarPath == null && widget.avatarBytes == null)
                          ? const Icon(Icons.person_add_alt_1_rounded, size: 36, color: AppTheme.accentRed)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentRed,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.darkSurface1,
                        foregroundColor: AppTheme.textPrimaryDark,
                        side: const BorderSide(color: AppTheme.darkBorderSubtle),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      icon: const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text('wizard_steps.step2_upload_btn'.tr(), style: const TextStyle(fontSize: 12)),
                      onPressed: _pickAvatar,
                    ),
                    if (widget.avatarPath != null || widget.avatarBytes != null) ...[
                      const SizedBox(height: 6),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.accentBlue,
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.crop_rotate_rounded, size: 15),
                        label: Text('wizard_steps.step2_arrange_btn'.tr(), style: const TextStyle(fontSize: 12)),
                        onPressed: () => _openArrangeModal(true),
                      ),
                    ],
                    if (_avatarError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _avatarError!,
                        style: const TextStyle(color: AppTheme.accentRed, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

        ],
      ),
    );
  }
}
