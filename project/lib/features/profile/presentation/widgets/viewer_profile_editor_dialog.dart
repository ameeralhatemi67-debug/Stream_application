import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_fields.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/layout/window_class.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'profile_media_editor.dart';

/// Editor for a non-verified viewer's own display identity (names, photo,
/// banner) -- strictly separate from the Broadcaster Application flow. A
/// plain viewer never has enough submitted info to justify opening
/// BroadcasterApplicationSheet; this is the only thing "Edit Profile" opens
/// for them (issue_log.md).
class ViewerProfileEditorDialog extends StatefulWidget {
  const ViewerProfileEditorDialog({super.key});

  /// A full-width sheet on phones; a centred panel on wider screens.
  static Future<void> show(BuildContext context) {
    return showCaSheet<void>(
      context,
      title: 'settings.edit_profile'.tr(),
      framed: false,
      fullWidthOnPhone: true,
      body: const ViewerProfileEditorDialog(),
    );
  }

  @override
  State<ViewerProfileEditorDialog> createState() =>
      _ViewerProfileEditorDialogState();
}

class _ViewerProfileEditorDialogState extends State<ViewerProfileEditorDialog> {
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  String? _avatarUrl, _bannerUrl;
  Uint8List? _avatarBytes, _bannerBytes;
  String? _avatarPath, _bannerPath;
  bool _isSaving = false;
  String? _error;

  // Neutral, original geometric marks -- not photos of real people or
  // branded content, per UI-05.
  static const List<String> _avatarPresets = [
    'assets/images/avatars/neutral_1.png',
    'assets/images/avatars/neutral_2.png',
    'assets/images/avatars/neutral_3.png',
    'assets/images/avatars/neutral_4.png',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppProvider>().userProfile;
    _nameEnController = TextEditingController(text: profile.nameEn);
    _nameArController = TextEditingController(text: profile.nameAr);
    _avatarUrl = profile.avatarUrl;
    _bannerUrl = profile.bannerUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.isPhoneLandscape) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) FocusScope.of(context).unfocus();
      });
    }
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameArController.dispose();
    super.dispose();
  }

  /// Uploads a newly picked image. A signed-out guest keeps the local file
  /// (it only lives on this device anyway); a signed-in account must get a
  /// real URL or the save stops, so no local path is ever stored remotely.
  Future<String?> _upload(
      AppProvider provider, Uint8List bytes, String kind, String? localPath) async {
    final uploaded = await provider.uploadStreamerMediaAsset(
        fileName: '${kind}_${DateTime.now().millisecondsSinceEpoch}.png',
        fileBytes: bytes,
        contentType: 'image/png');
    if (uploaded != null) return uploaded;
    if (provider.currentUserId == null) return localPath;
    throw StateError('upload failed');
  }

  Future<void> _handleSave() async {
    final nameEn = _nameEnController.text.trim();
    final nameAr = _nameArController.text.trim();
    if (nameEn.isEmpty) {
      setState(() => _error = 'viewer_setup.error_name_empty');
      return;
    }
    final provider = context.read<AppProvider>();
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final avatar = _avatarBytes == null
          ? _avatarUrl
          : await _upload(provider, _avatarBytes!, 'avatar', _avatarPath);
      final banner = _bannerBytes == null
          ? _bannerUrl
          : await _upload(provider, _bannerBytes!, 'banner', _bannerPath);
      await provider.updateViewerProfile(
        nameEn: nameEn,
        nameAr: nameAr.isEmpty ? nameEn : nameAr,
        avatarUrl: avatar,
        bannerUrl: banner,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _error = 'settings.upload_failed');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final landscape = context.isPhoneLandscape;
    return Material(
      color: AppTheme.surface,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceXs, 0),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('settings.edit_profile'.tr(),
                            style: theme.titleLarge?.copyWith(
                                color: Canopy.ink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('settings.edit_profile_hint'.tr(),
                            style: theme.bodySmall?.copyWith(color: Canopy.slate)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'common.cancel'.tr(),
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Canopy.slate),
                  ),
                ]),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileMediaEditor(
                        name: _nameEnController.text,
                        avatarUrl: _avatarUrl,
                        bannerUrl: _bannerUrl,
                        avatarBytes: _avatarBytes,
                        bannerBytes: _bannerBytes,
                        enabled: !_isSaving,
                        onAvatarPicked: (img) => setState(() {
                          _avatarBytes = img.bytes;
                          _avatarPath = img.path;
                        }),
                        onBannerPicked: (img) => setState(() {
                          _bannerBytes = img.bytes;
                          _bannerPath = img.path;
                        }),
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                      Text('settings.choose_avatar'.tr(),
                          style: theme.labelLarge?.copyWith(color: Canopy.slate)),
                      const SizedBox(height: AppTheme.spaceSm),
                      Wrap(
                        spacing: AppTheme.spaceSm,
                        runSpacing: AppTheme.spaceSm,
                        children: [
                          for (final preset in _avatarPresets)
                            Semantics(
                              button: true,
                              selected: _avatarBytes == null && _avatarUrl == preset,
                              child: GestureDetector(
                                onTap: _isSaving
                                    ? null
                                    : () => setState(() {
                                          _avatarUrl = preset;
                                          _avatarBytes = null;
                                          _avatarPath = null;
                                        }),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _avatarBytes == null &&
                                              _avatarUrl == preset
                                          ? AppTheme.primary
                                          : Canopy.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 22,
                                    backgroundImage: AssetImage(preset),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppTheme.spaceLg),
                      if (landscape) ...[
                        Text('live.landscape_settings_portrait'.tr()),
                        const SizedBox(height: AppTheme.spaceMd),
                      ],
                      CaInput(
                          label: 'viewer_setup.name_label'.tr(),
                          controller: _nameEnController,
                          readOnly: landscape),
                      const SizedBox(height: AppTheme.spaceMd),
                      CaInput(
                          label: 'الاسم بالعربية',
                          controller: _nameArController,
                          textDirection: ui.TextDirection.rtl,
                          readOnly: landscape),
                      if (_error != null) ...[
                        const SizedBox(height: AppTheme.spaceMd),
                        Text(_error!.tr(),
                            style: theme.bodySmall
                                ?.copyWith(color: Canopy.liveCrimson)),
                      ],
                    ],
                  ),
                ),
              ),
              // Actions stay visible while the form scrolls.
              DecoratedBox(
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Canopy.hairline))),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppTheme.spaceLg,
                      AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd),
                  child: Row(children: [
                    Expanded(
                      child: CaButton(
                        label: 'common.cancel'.tr(),
                        variant: CaButtonVariant.secondary,
                        onPressed:
                            _isSaving ? null : () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: CaButton(
                        key: const Key('viewer-profile-save'),
                        label: 'common.save'.tr(),
                        loading: _isSaving,
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
