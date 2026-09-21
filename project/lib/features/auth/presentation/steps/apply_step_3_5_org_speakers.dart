import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';

class OrgApplicationSpeaker {
  String name;
  String handle;
  String bio;
  String youtube;
  String avatarUrl;
  Uint8List? avatarBytes;
  String role;

  OrgApplicationSpeaker({
    required this.name,
    required this.handle,
    required this.bio,
    required this.youtube,
    required this.avatarUrl,
    this.avatarBytes,
    this.role = 'Instructor',
  });
}

/// Step 3.5: Organization Broadcaster & Speaker Management (With Custom Avatar Upload)
class ApplyStep35OrgSpeakers extends StatelessWidget {
  final List<OrgApplicationSpeaker> speakers;
  final Function(OrgApplicationSpeaker speaker) onAddSpeaker;
  final Function(int index) onRemoveSpeaker;

  const ApplyStep35OrgSpeakers({
    super.key,
    required this.speakers,
    required this.onAddSpeaker,
    required this.onRemoveSpeaker,
  });

  static const List<String> _speakerAvatarPresets = [
    'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
    'assets/images/Dalilak/profile1.jpg',
    'assets/images/Dalilak/profile2.jpg',
    'assets/images/Dalilak/profile3.jpg',
    'assets/images/quran/Quran_profile.jpg',
  ];

  void _showAddSpeakerDialog(BuildContext context) {
    final provider = context.read<AppProvider>();
    final nameCtrl = TextEditingController();
    final handleCtrl = TextEditingController();
    final bioCtrl = TextEditingController();
    final youtubeCtrl = TextEditingController();
    final roleCtrl = TextEditingController(text: 'Lecturer / Instructor');
    final ImagePicker picker = ImagePicker();

    String selectedAvatar = 'assets/images/Dalilak/profile1.jpg';
    Uint8List? uploadedAvatarBytes;
    bool wasAutofilled = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> pickCustomSpeakerAvatar() async {
            try {
              final XFile? image = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              if (image != null) {
                final bytes = await image.readAsBytes();
                setDialogState(() {
                  uploadedAvatarBytes = bytes;
                  selectedAvatar = image.path;
                });
              }
            } catch (e) {
              debugPrint('Error picking speaker avatar: $e');
            }
          }

          void checkAndAutofill(String handle) {
            final query = handle.trim().toLowerCase();
            final normalized = query.startsWith('@') ? query.substring(1) : query;
            if (normalized.isEmpty) return;

            final existing = provider.streamers.cast<dynamic>().firstWhere(
              (s) {
                final sHandle = (s.youtubeHandle as String).replaceAll('@', '').toLowerCase();
                final sId = (s.id as String).toLowerCase();
                return sHandle == normalized || sId == normalized;
              },
              orElse: () => null,
            );

            if (existing != null) {
              setDialogState(() {
                nameCtrl.text = existing.nameEn ?? existing.nameAr ?? '';
                bioCtrl.text = existing.bioEn ?? existing.bioAr ?? '';
                youtubeCtrl.text = 'https://www.youtube.com/${existing.youtubeHandle}';
                selectedAvatar = existing.avatarUrl ?? selectedAvatar;
                uploadedAvatarBytes = null;
                wasAutofilled = true;
              });
            }
          }

          return AlertDialog(
            backgroundColor: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              side: const BorderSide(color: AppTheme.border),
            ),
            title: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.danger, size: 24),
                const SizedBox(width: 10),
                Text(
                  'wizard_steps.step3_5_dialog_title'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Speaker Avatar Picker Header
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: pickCustomSpeakerAvatar,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: AppTheme.surfaceAlt,
                                  backgroundImage: uploadedAvatarBytes != null
                                      ? MemoryImage(uploadedAvatarBytes!)
                                      : (selectedAvatar.startsWith('assets/')
                                          ? AssetImage(selectedAvatar)
                                          : NetworkImage(selectedAvatar) as ImageProvider),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.danger,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: AppTheme.onMedia),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.upload_file_rounded, size: 14),
                            label: Text('wizard_steps.step2_upload_btn'.tr(), style: const TextStyle(fontSize: 11)),
                            onPressed: pickCustomSpeakerAvatar,
                          ),
                          const SizedBox(height: 4),
                          // Avatar Preset Row
                          Wrap(
                            spacing: 6,
                            children: _speakerAvatarPresets.map((preset) {
                              final isSelected = selectedAvatar == preset && uploadedAvatarBytes == null;
                              return GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedAvatar = preset;
                                    uploadedAvatarBytes = null;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(1.5),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppTheme.danger : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundImage: AssetImage(preset),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),

                    // Handle Field
                    TextField(
                      controller: handleCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'wizard_steps.step1_handle_label'.tr(),
                        hintText: '@amir_alhatemi or @handle',
                        prefixIcon: const Icon(Icons.alternate_email_rounded, color: AppTheme.danger, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search_rounded, color: AppTheme.primary),
                          tooltip: 'Auto-fill from system',
                          onPressed: () => checkAndAutofill(handleCtrl.text),
                        ),
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                      onChanged: (val) => checkAndAutofill(val),
                    ),
                    if (wasAutofilled) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text('design_ui.auto_filled_from_registered_streamer_profile'.tr(),
                              style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppTheme.spaceSm),

                    // Full Name
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'wizard_steps.step1_name_label'.tr(),
                        prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.danger, size: 18),
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),

                    // Role Title
                    TextField(
                      controller: roleCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'affiliation_modal.proposed_role'.tr(),
                        hintText: 'e.g. Lead IELTS Instructor',
                        prefixIcon: const Icon(Icons.badge_outlined, color: AppTheme.danger, size: 18),
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),

                    // YouTube
                    TextField(
                      controller: youtubeCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'wizard_steps.step3_youtube_label'.tr(),
                        hintText: 'https://www.youtube.com/@handle',
                        prefixIcon: const Icon(Icons.video_collection_outlined, color: AppTheme.danger, size: 18),
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceSm),

                    // Bio
                    TextField(
                      controller: bioCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'wizard_steps.step1_bio_label'.tr(),
                        hintText: 'Short academic summary...',
                        prefixIcon: const Icon(Icons.description_outlined, color: AppTheme.danger, size: 18),
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('common.cancel'.tr(), style: const TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: AppTheme.onMedia,
                ),
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty || handleCtrl.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('design_ui.please_enter_at_least_a_name_and_handle'.tr())),
                    );
                    return;
                  }

                  onAddSpeaker(
                    OrgApplicationSpeaker(
                      name: nameCtrl.text.trim(),
                      handle: handleCtrl.text.trim(),
                      bio: bioCtrl.text.trim(),
                      youtube: youtubeCtrl.text.trim(),
                      role: roleCtrl.text.trim().isEmpty ? 'Instructor' : roleCtrl.text.trim(),
                      avatarUrl: selectedAvatar,
                      avatarBytes: uploadedAvatarBytes,
                    ),
                  );
                  Navigator.of(ctx).pop();
                },
                child: Text('wizard_steps.step3_5_dialog_add'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'wizard_steps.step3_5_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step3_5_desc'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // Header with + Add Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'wizard_steps.step3_5_roster_count'.tr(args: ['${speakers.length}']),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
                  foregroundColor: AppTheme.onMedia,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('wizard_steps.step3_5_add_btn'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showAddSpeakerDialog(context),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          if (speakers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: AppTheme.spaceLg),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
              ),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.groups_outlined, color: AppTheme.textMuted, size: 48),
                  const SizedBox(height: 10),
                  Text('design_ui.no_speakers_added_yet'.tr(),
                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap "+ Add Streamer"to invite or associate speakers with this organization.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                    ),
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('design_ui.add_first_streamer'.tr()),
                    onPressed: () => _showAddSpeakerDialog(context),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: speakers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final spk = speakers[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.surfaceAlt,
                        backgroundImage: spk.avatarBytes != null
                            ? MemoryImage(spk.avatarBytes!)
                            : (spk.avatarUrl.startsWith('assets/')
                                ? AssetImage(spk.avatarUrl)
                                : NetworkImage(spk.avatarUrl) as ImageProvider),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              spk.name,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${spk.role} • ${spk.handle}',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                        tooltip: 'Remove speaker',
                        onPressed: () => onRemoveSpeaker(idx),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
