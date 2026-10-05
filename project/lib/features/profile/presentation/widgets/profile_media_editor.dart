import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../auth/presentation/widgets/image_arrange_modal.dart';

/// A freshly picked image: the cropped bytes (uploaded on save) and the
/// picker's path (only a local preview fallback).
typedef PickedProfileImage = ({Uint8List bytes, String path});

/// Banner with the profile photo overlapping its lower edge, each with its
/// own change action. Shared by the viewer and broadcaster profile editors.
/// Picking crops the image (round photo, 16:9 banner) but uploads nothing;
/// the editor uploads the bytes when the user saves.
class ProfileMediaEditor extends StatelessWidget {
  const ProfileMediaEditor({
    super.key,
    required this.name,
    this.avatarUrl,
    this.bannerUrl,
    this.avatarBytes,
    this.bannerBytes,
    required this.onAvatarPicked,
    required this.onBannerPicked,
    this.enabled = true,
  });

  final String name;
  final String? avatarUrl, bannerUrl;
  final Uint8List? avatarBytes, bannerBytes;
  final ValueChanged<PickedProfileImage> onAvatarPicked, onBannerPicked;
  final bool enabled;

  static const double _avatarSize = 84;

  static ImageProvider? _image(Uint8List? bytes, String? url, int width) {
    if (bytes != null) return MemoryImage(bytes);
    final path = url?.trim() ?? '';
    if (path.isEmpty) return null;
    return downscaledImage(buildSafeImageProvider(path: path), width: width);
  }

  Future<void> _pick(BuildContext context, {required bool avatar}) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: avatar ? 1024 : 1920,
        maxHeight: avatar ? 1024 : 1920,
      );
      if (image == null || !context.mounted) return;
      final raw = await image.readAsBytes();
      if (!context.mounted) return;
      final cropped = await ImageArrangeModal.show(
        context: context,
        imagePath: image.path,
        imageBytes: raw,
        arrangeType: avatar
            ? ImageArrangeType.avatarCircle
            : ImageArrangeType.banner16x9,
      );
      final picked = (bytes: cropped ?? raw, path: image.path);
      avatar ? onAvatarPicked(picked) : onBannerPicked(picked);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('settings.image_pick_failed'.tr()),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _image(avatarBytes, avatarUrl, 256);
    final banner = _image(bannerBytes, bannerUrl, 1200);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return LayoutBuilder(builder: (context, constraints) {
      final bannerHeight = constraints.maxWidth / 3;
      return SizedBox(
        height: bannerHeight + _avatarSize / 2 + AppTheme.spaceXs,
        child: Stack(clipBehavior: Clip.none, children: [
          // Banner
          PositionedDirectional(
            top: 0,
            start: 0,
            end: 0,
            height: bannerHeight,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
              child: Stack(fit: StackFit.expand, children: [
                if (banner != null)
                  Image(
                      image: banner,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const DecoratedBox(
                          decoration:
                              BoxDecoration(gradient: CanopyGradients.panel)))
                else
                  const DecoratedBox(
                      decoration:
                          BoxDecoration(gradient: CanopyGradients.panel)),
                PositionedDirectional(
                  end: AppTheme.spaceSm,
                  top: AppTheme.spaceSm,
                  child: Material(
                    color: Canopy.forestDeep.withValues(alpha: .62),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: InkWell(
                      key: const Key('profile-change-banner'),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      onTap: enabled ? () => _pick(context, avatar: false) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMd,
                            vertical: AppTheme.spaceSm),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.photo_camera_outlined,
                              size: 18, color: Canopy.paper),
                          const SizedBox(width: AppTheme.spaceXs),
                          Text('settings.change_banner'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: Canopy.paper)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          // Photo, overlapping the banner's lower edge
          PositionedDirectional(
            start: AppTheme.spaceLg,
            bottom: 0,
            child: Container(
              width: _avatarSize,
              height: _avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Canopy.mint,
                border: Border.all(color: Canopy.paper, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x33123E26), blurRadius: 8)
                ],
                image: avatar == null
                    ? null
                    : DecorationImage(
                        image: avatar,
                        fit: BoxFit.cover,
                        onError: (_, __) {}),
              ),
              alignment: Alignment.center,
              child: avatar == null
                  ? Text(initial,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.primary, fontWeight: FontWeight.w700))
                  : null,
            ),
          ),
          PositionedDirectional(
            start: AppTheme.spaceLg + _avatarSize + AppTheme.spaceSm,
            bottom: 0,
            child: TextButton.icon(
              key: const Key('profile-change-photo'),
              onPressed: enabled ? () => _pick(context, avatar: true) : null,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text('settings.change_photo'.tr()),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            ),
          ),
        ]),
      );
    });
  }
}
