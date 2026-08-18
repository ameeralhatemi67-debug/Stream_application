import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';

enum YoutubeVerificationState {
  unverified,
  checking,
  verifiedOnline,
  formatAccepted,
  invalidFormat,
}

/// Step 3: Professional Credentials, YouTube Channel (Live API Checked) & Account Type
class ApplyStep3Professional extends StatefulWidget {
  final TextEditingController affiliationController;
  final TextEditingController youtubeController;
  final TextEditingController orgNameController;
  final List<String> selectedCategories;
  final bool isOrganization;
  final List<String> selectedTags;
  final Function(List<String> categories) onCategoriesChanged;
  final Function(bool isOrg) onTypeChanged;
  final Function(String tag) onTagToggled;

  const ApplyStep3Professional({
    super.key,
    required this.affiliationController,
    required this.youtubeController,
    required this.orgNameController,
    required this.selectedCategories,
    required this.isOrganization,
    required this.selectedTags,
    required this.onCategoriesChanged,
    required this.onTypeChanged,
    required this.onTagToggled,
  });

  @override
  State<ApplyStep3Professional> createState() => _ApplyStep3ProfessionalState();
}

class _ApplyStep3ProfessionalState extends State<ApplyStep3Professional> {
  static const Map<String, String> defaultCategoryOptions = {
    'cs_tech': 'Computer Science & AI',
    'islamic_studies': 'Islamic Studies & Sharia',
    'languages_ielts': 'Languages & IELTS Academy',
    'engineering_tech': 'Engineering & Innovation',
    'medical_health': 'Medicine & Clinical Health',
    'general_edu': 'Culture & General Education',
  };

  static const List<String> availableTags = [
    '#AI',
    '#IELTS',
    '#English',
    '#Quran',
    '#Podcast',
    '#Software',
    '#Medicine',
    '#Engineering',
    '#Academy',
    '#Youth',
  ];

  late List<String> _customCategories;
  YoutubeVerificationState _ytState = YoutubeVerificationState.unverified;
  String _ytFeedbackMessage = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _customCategories = widget.selectedCategories
        .where((c) => !defaultCategoryOptions.containsKey(c) && !defaultCategoryOptions.containsValue(c))
        .toList();
    _scheduleYoutubeVerification(widget.youtubeController.text);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _scheduleYoutubeVerification(String val) {
    _debounceTimer?.cancel();
    final text = val.trim();

    if (text.isEmpty) {
      setState(() {
        _ytState = YoutubeVerificationState.unverified;
        _ytFeedbackMessage = 'wizard_steps.step3_yt_required'.tr();
      });
      return;
    }

    final hasValidSyntax = text.startsWith('https://www.youtube.com/@') ||
        text.startsWith('http://www.youtube.com/@') ||
        text.startsWith('https://youtube.com/@') ||
        text.startsWith('youtube.com/@') ||
        text.startsWith('www.youtube.com/@') ||
        (text.startsWith('@') && text.length > 2);

    if (!hasValidSyntax) {
      setState(() {
        _ytState = YoutubeVerificationState.invalidFormat;
        _ytFeedbackMessage = 'wizard_steps.step3_yt_invalid'.tr();
      });
      return;
    }

    setState(() {
      _ytState = YoutubeVerificationState.checking;
      _ytFeedbackMessage = 'wizard_steps.step3_yt_checking'.tr();
    });

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      final cleanHandle = text.replaceAll('https://www.youtube.com/', '')
          .replaceAll('http://www.youtube.com/', '')
          .replaceAll('https://youtube.com/', '')
          .replaceAll('youtube.com/', '')
          .replaceAll('www.youtube.com/', '')
          .replaceAll('@', '');

      final provider = context.read<AppProvider>();
      final isRegisteredStreamer = provider.streamers.any(
        (s) => s.youtubeHandle.replaceAll('@', '').toLowerCase() == cleanHandle.toLowerCase(),
      );

      if (isRegisteredStreamer) {
        if (mounted) {
          setState(() {
            _ytState = YoutubeVerificationState.verifiedOnline;
            _ytFeedbackMessage = 'wizard_steps.step3_yt_verified'.tr(args: [cleanHandle]);
          });
        }
        return;
      }

      // Check format acceptance
      if (mounted) {
        setState(() {
          _ytState = YoutubeVerificationState.formatAccepted;
          _ytFeedbackMessage = 'wizard_steps.step3_yt_format_ok'.tr();
        });
      }
    });
  }

  void _toggleCategory(String cat) {
    final current = List<String>.from(widget.selectedCategories);
    if (current.contains(cat)) {
      current.remove(cat);
    } else {
      if (current.length >= 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can select a maximum of 6 academic/content fields.'),
            backgroundColor: AppTheme.accentRed,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      current.add(cat);
    }
    widget.onCategoriesChanged(current);
  }

  void _showAddCustomFieldDialog() {
    if (widget.selectedCategories.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 6 fields limit reached. Remove a field to add another.'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    final customCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: Text('wizard_steps.step3_add_dialog_title'.tr(), style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 16)),
        content: TextField(
          controller: customCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimaryDark),
          decoration: InputDecoration(
            labelText: 'wizard_steps.step3_add_custom_field'.tr(),
            hintText: 'e.g. Data Science, Architecture',
            filled: true,
            fillColor: AppTheme.darkSurface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: AppTheme.textSecondaryDark)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed, foregroundColor: Colors.white),
            onPressed: () {
              final text = customCtrl.text.trim();
              if (text.isNotEmpty) {
                setState(() {
                  if (!_customCategories.contains(text)) {
                    _customCategories.add(text);
                  }
                });
                _toggleCategory(text);
              }
              Navigator.of(ctx).pop();
            },
            child: Text('wizard_steps.step3_add_custom_field'.tr()),
          ),
        ],
      ),
    );
  }

  Widget _buildEntityTypeSelectors(bool isPhone) {
    final individualButton = _buildTypeButton(
      title: 'wizard_steps.step3_type_individual'.tr(),
      subtitle: 'wizard_steps.step3_type_individual_sub'.tr(),
      isSelected: !widget.isOrganization,
      onTap: () => widget.onTypeChanged(false),
    );

    final orgButton = _buildTypeButton(
      title: 'wizard_steps.step3_type_org'.tr(),
      subtitle: 'wizard_steps.step3_type_org_sub'.tr(),
      isSelected: widget.isOrganization,
      onTap: () => widget.onTypeChanged(true),
    );

    if (isPhone) {
      // 📱 Stacked Two-Row Layout on Phone to eliminate horizontal overflow
      return Column(
        children: [
          individualButton,
          const SizedBox(height: 10),
          orgButton,
        ],
      );
    } else {
      // 💻 Side-by-Side 2-Column Row on Desktop / Tablet
      return Row(
        children: [
          Expanded(child: individualButton),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(child: orgButton),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'wizard_steps.step3_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step3_desc'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondaryDark,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // 🏛️ Account Type Selector Toggle (Responsive Two-Row on Phone)
          Text(
            'wizard_steps.step3_entity_type'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildEntityTypeSelectors(isPhone),
          const SizedBox(height: AppTheme.spaceMd),

          // Conditional Organization Name field if Org is selected
          if (widget.isOrganization) ...[
            TextField(
              controller: widget.orgNameController,
              style: const TextStyle(color: AppTheme.textPrimaryDark),
              decoration: InputDecoration(
                labelText: 'wizard_steps.step3_org_name_label'.tr(),
                labelStyle: const TextStyle(color: AppTheme.textSecondaryDark),
                hintText: 'wizard_steps.step3_org_name_hint'.tr(),
                hintStyle: const TextStyle(color: AppTheme.textMutedDark),
                prefixIcon: const Icon(Icons.business_rounded, color: AppTheme.accentRed),
                filled: true,
                fillColor: AppTheme.darkSurface1,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.accentRed, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],

          // Affiliation / Workplace
          TextField(
            controller: widget.affiliationController,
            style: const TextStyle(color: AppTheme.textPrimaryDark),
            decoration: InputDecoration(
              labelText: widget.isOrganization
                  ? 'wizard_steps.step3_affiliation_org'.tr()
                  : 'wizard_steps.step3_affiliation_ind'.tr(),
              labelStyle: const TextStyle(color: AppTheme.textSecondaryDark),
              hintText: widget.isOrganization ? 'wizard_steps.step3_org_name_hint'.tr() : 'wizard_steps.step3_affiliation_ind_hint'.tr(),
              hintStyle: const TextStyle(color: AppTheme.textMutedDark),
              prefixIcon: const Icon(Icons.school_outlined, color: AppTheme.accentRed),
              filled: true,
              fillColor: AppTheme.darkSurface1,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.accentRed, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // 🎬 YouTube Channel Handle / URL (With Live Automated Channel Checker)
          TextField(
            controller: widget.youtubeController,
            style: const TextStyle(color: AppTheme.textPrimaryDark),
            onChanged: _scheduleYoutubeVerification,
            decoration: InputDecoration(
              labelText: 'wizard_steps.step3_youtube_label'.tr(),
              labelStyle: const TextStyle(color: AppTheme.textSecondaryDark),
              hintText: 'https://www.youtube.com/@AlQuran4KOfficial or @amir_alhatemi',
              hintStyle: const TextStyle(color: AppTheme.textMutedDark),
              prefixIcon: const Icon(Icons.video_library_rounded, color: AppTheme.accentRed),
              suffixIcon: _buildYoutubeSuffixIcon(),
              filled: true,
              fillColor: AppTheme.darkSurface1,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: _getYoutubeBorderColor(),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: BorderSide(
                  color: _getYoutubeBorderColor(isFocused: true),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _ytFeedbackMessage,
            style: TextStyle(
              color: _getYoutubeTextColor(),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // 📚 Primary Academic Fields (Headline & Selection)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'wizard_steps.step3_categories_title'.tr(args: ['${widget.selectedCategories.length}']),
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // On desktop/tablet, show button on right; on phone, rendered at bottom of wrap
              if (!isPhone)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accentBlue,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text('wizard_steps.step3_add_custom_field'.tr(), style: const TextStyle(fontSize: 12)),
                  onPressed: _showAddCustomFieldDialog,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...defaultCategoryOptions.entries.map((entry) {
                final isSelected = widget.selectedCategories.contains(entry.key) ||
                    widget.selectedCategories.contains(entry.value);
                return FilterChip(
                  label: Text(entry.value),
                  selected: isSelected,
                  selectedColor: AppTheme.accentRed.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.accentRed,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.accentRed : AppTheme.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppTheme.darkSurface1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: BorderSide(
                      color: isSelected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
                    ),
                  ),
                  onSelected: (_) => _toggleCategory(entry.key),
                );
              }),
              ..._customCategories.map((custom) {
                final isSelected = widget.selectedCategories.contains(custom);
                return FilterChip(
                  label: Text(custom),
                  selected: isSelected,
                  selectedColor: AppTheme.accentRed.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.accentRed,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.accentRed : AppTheme.textSecondaryDark,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppTheme.darkSurface1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: BorderSide(
                      color: isSelected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
                    ),
                  ),
                  onSelected: (_) => _toggleCategory(custom),
                );
              }),
              // On phone view, render "+ Add Custom Field" as a clean ActionChip at the bottom of the wrap!
              if (isPhone)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16, color: AppTheme.accentBlue),
                  label: Text('wizard_steps.step3_add_custom_field'.tr(), style: const TextStyle(fontSize: 11, color: AppTheme.accentBlue)),
                  backgroundColor: AppTheme.darkSurface1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: const BorderSide(color: AppTheme.accentBlue, width: 1),
                  ),
                  onPressed: _showAddCustomFieldDialog,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          // 🏷️ Lecture Discovery Topic Tags
          Text(
            'wizard_steps.step3_tags_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableTags.map((tag) {
              final isSelected = widget.selectedTags.contains(tag);
              return FilterChip(
                label: Text(tag),
                selected: isSelected,
                selectedColor: AppTheme.accentBlue.withValues(alpha: 0.25),
                checkmarkColor: AppTheme.accentBlue,
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.accentBlue : AppTheme.textSecondaryDark,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: AppTheme.darkSurface1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  side: BorderSide(
                    color: isSelected ? AppTheme.accentBlue : AppTheme.darkBorderSubtle,
                  ),
                ),
                onSelected: (_) => widget.onTagToggled(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget? _buildYoutubeSuffixIcon() {
    if (widget.youtubeController.text.isEmpty) return null;
    switch (_ytState) {
      case YoutubeVerificationState.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentBlue),
          ),
        );
      case YoutubeVerificationState.verifiedOnline:
        return const Icon(Icons.verified_rounded, color: Colors.green);
      case YoutubeVerificationState.formatAccepted:
        return const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accentBlue);
      case YoutubeVerificationState.invalidFormat:
        return const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed);
      case YoutubeVerificationState.unverified:
        return null;
    }
  }

  Color _getYoutubeBorderColor({bool isFocused = false}) {
    if (widget.youtubeController.text.isEmpty) return isFocused ? AppTheme.accentRed : AppTheme.darkBorderSubtle;
    switch (_ytState) {
      case YoutubeVerificationState.verifiedOnline:
        return Colors.green;
      case YoutubeVerificationState.formatAccepted:
        return AppTheme.accentBlue;
      case YoutubeVerificationState.invalidFormat:
        return AppTheme.accentRed;
      default:
        return isFocused ? AppTheme.accentRed : AppTheme.darkBorderSubtle;
    }
  }

  Color _getYoutubeTextColor() {
    switch (_ytState) {
      case YoutubeVerificationState.verifiedOnline:
        return Colors.green;
      case YoutubeVerificationState.formatAccepted:
        return AppTheme.accentBlue;
      case YoutubeVerificationState.invalidFormat:
        return AppTheme.accentRed;
      default:
        return AppTheme.textMutedDark;
    }
  }

  Widget _buildTypeButton({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accentRed.withValues(alpha: 0.12) : AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? AppTheme.textPrimaryDark : AppTheme.textSecondaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.accentRed, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textMutedDark,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
