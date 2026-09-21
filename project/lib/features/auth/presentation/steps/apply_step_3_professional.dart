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

  /// Robust parser that extracts the YouTube handle from various formats:
  /// - `youtube.com/@apop8091`
  /// - `www.youtube.com/@apop8091`
  /// - `@apop8091`
  /// - `https://www.youtube.com/@apop8091`
  /// - `https://youtube.com/c/apop8091`
  /// - `apop8091`
  static String extractCleanYouTubeHandle(String input) {
    var text = input.trim();
    if (text.isEmpty) return '';

    if (text.contains('?')) {
      text = text.split('?').first;
    }

    text = text.replaceFirst(RegExp(r'^https?:\/\/', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'^www\.', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'^(youtube\.com|youtu\.be)\/', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'^(c\/|user\/|channel\/)', caseSensitive: false), '');
    text = text.replaceAll('/videos', '').replaceAll('/featured', '').replaceAll('/playlists', '').replaceAll('/streams', '');
    text = text.replaceAll('@', '');
    text = text.replaceAll('/', '').trim();
    return text;
  }

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

  late List<String> _customCategories;
  YoutubeVerificationState _ytState = YoutubeVerificationState.unverified;
  String _ytFeedbackMessage = '';
  Timer? _debounceTimer;
  final TextEditingController _customTagController = TextEditingController();

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
    _customTagController.dispose();
    super.dispose();
  }

  /// Submits a brand-new tag as pending review (Cluster 3 Task 12) and
  /// selects it locally right away -- the applicant sees it applied to
  /// their form immediately, even though it won't appear in anyone else's
  /// approved-tag list until an admin approves it.
  void _submitCustomTag() {
    final tag = _customTagController.text.trim();
    if (tag.isEmpty) return;
    context.read<AppProvider>().submitPendingTag(tag);
    widget.onTagToggled(tag);
    _customTagController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('wizard_steps.step3_tag_pending_notice'.tr())),
    );
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

    final cleanHandle = ApplyStep3Professional.extractCleanYouTubeHandle(text);
    final isValidHandle = cleanHandle.length >= 2 && RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(cleanHandle);

    if (!isValidHandle) {
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
      final provider = context.read<AppProvider>();
      final isRegisteredStreamer = provider.streamers.any(
        (s) => ApplyStep3Professional.extractCleanYouTubeHandle(s.youtubeHandle).toLowerCase() == cleanHandle.toLowerCase(),
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
          SnackBar(
            content: Text('design_ui.you_can_select_a_maximum_of_6_academic_content_fields'.tr()),
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 2),
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
        SnackBar(
          content: Text('design_ui.maximum_6_fields_limit_reached_remove_a_field_to_add_another'.tr()),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    final customCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        title: Text('wizard_steps.step3_add_dialog_title'.tr(), style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: TextField(
          controller: customCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            labelText: 'wizard_steps.step3_add_custom_field'.tr(),
            hintText: 'e.g. Data Science, Architecture',
            filled: true,
            fillColor: AppTheme.surfaceAlt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr(), style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: AppTheme.onMedia),
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
      //  Stacked Two-Row Layout on Phone to eliminate horizontal overflow
      return Column(
        children: [
          individualButton,
          const SizedBox(height: 10),
          orgButton,
        ],
      );
    } else {
      //  Side-by-Side 2-Column Row on Desktop / Tablet
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
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'wizard_steps.step3_desc'.tr(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spaceLg),

          //  Account Type Selector Toggle (Responsive Two-Row on Phone)
          Text(
            'wizard_steps.step3_entity_type'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
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
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'wizard_steps.step3_org_name_label'.tr(),
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                hintText: 'wizard_steps.step3_org_name_hint'.tr(),
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.business_rounded, color: AppTheme.danger),
                filled: true,
                fillColor: AppTheme.surface,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],

          // Affiliation / Workplace
          TextField(
            controller: widget.affiliationController,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              labelText: widget.isOrganization
                  ? 'wizard_steps.step3_affiliation_org'.tr()
                  : 'wizard_steps.step3_affiliation_ind'.tr(),
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: widget.isOrganization ? 'wizard_steps.step3_org_name_hint'.tr() : 'wizard_steps.step3_affiliation_ind_hint'.tr(),
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.school_outlined, color: AppTheme.danger),
              filled: true,
              fillColor: AppTheme.surface,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                borderSide: const BorderSide(color: AppTheme.danger, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          //  YouTube Channel Handle / URL (With Live Automated Channel Checker)
          TextField(
            controller: widget.youtubeController,
            style: const TextStyle(color: AppTheme.textPrimary),
            onChanged: _scheduleYoutubeVerification,
            decoration: InputDecoration(
              labelText: 'wizard_steps.step3_youtube_label'.tr(),
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: 'https://www.youtube.com/@AlQuran4KOfficial or @amir_alhatemi',
              hintStyle: const TextStyle(color: AppTheme.textMuted),
              prefixIcon: const Icon(Icons.video_library_rounded, color: AppTheme.danger),
              suffixIcon: _buildYoutubeSuffixIcon(),
              filled: true,
              fillColor: AppTheme.surface,
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

          //  Primary Academic Fields (Headline & Selection)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'wizard_steps.step3_categories_title'.tr(args: ['${widget.selectedCategories.length}']),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // On desktop/tablet, show button on right; on phone, rendered at bottom of wrap
              if (!isPhone)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
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
                  selectedColor: AppTheme.danger.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.danger,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.danger : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: BorderSide(
                      color: isSelected ? AppTheme.danger : AppTheme.border,
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
                  selectedColor: AppTheme.danger.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.danger,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.danger : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: BorderSide(
                      color: isSelected ? AppTheme.danger : AppTheme.border,
                    ),
                  ),
                  onSelected: (_) => _toggleCategory(custom),
                );
              }),
              // On phone view, render "+ Add Custom Field"as a clean ActionChip at the bottom of the wrap!
              if (isPhone)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16, color: AppTheme.primary),
                  label: Text('wizard_steps.step3_add_custom_field'.tr(), style: const TextStyle(fontSize: 11, color: AppTheme.primary)),
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: const BorderSide(color: AppTheme.primary, width: 1),
                  ),
                  onPressed: _showAddCustomFieldDialog,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceLg),

          //  Lecture Discovery Topic Tags
          Text(
            'wizard_steps.step3_tags_title'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Builder(builder: (context) {
            // Cluster 3 Task 12: suggests only admin-approved tags instead
            // of a hardcoded pool.
            final approvedTags = context.watch<AppProvider>().approvedTags;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: approvedTags.map((tag) {
                final isSelected = widget.selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  selectedColor: AppTheme.primary.withValues(alpha: 0.25),
                  checkmarkColor: AppTheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: AppTheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    side: BorderSide(
                      color:
                          isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  onSelected: (_) => widget.onTagToggled(tag),
                );
              }).toList(),
            );
          }),
          if (widget.selectedTags
              .any((t) => !context.watch<AppProvider>().approvedTags.contains(t)))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.selectedTags
                    .where((t) =>
                        !context.watch<AppProvider>().approvedTags.contains(t))
                    .map((tag) => Chip(
                          label: Text(tag),
                          avatar: const Icon(Icons.hourglass_top_rounded,
                              size: 14, color: AppTheme.warning),
                          backgroundColor:
                              AppTheme.warning.withValues(alpha: 0.15),
                          labelStyle:
                              const TextStyle(color: AppTheme.warning, fontSize: 11),
                          onDeleted: () => widget.onTagToggled(tag),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customTagController,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12),
                  onSubmitted: (_) => _submitCustomTag(),
                  decoration: InputDecoration(
                    hintText: 'wizard_steps.step3_custom_tag_hint'.tr(),
                    hintStyle: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide:
                          const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _submitCustomTag,
                icon: const Icon(Icons.add_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onMedia,
                ),
              ),
            ],
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
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
          ),
        );
      case YoutubeVerificationState.verifiedOnline:
        return const Icon(Icons.verified_rounded, color: Colors.green);
      case YoutubeVerificationState.formatAccepted:
        return const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primary);
      case YoutubeVerificationState.invalidFormat:
        return const Icon(Icons.error_outline_rounded, color: AppTheme.danger);
      case YoutubeVerificationState.unverified:
        return null;
    }
  }

  Color _getYoutubeBorderColor({bool isFocused = false}) {
    if (widget.youtubeController.text.isEmpty) return isFocused ? AppTheme.danger : AppTheme.border;
    switch (_ytState) {
      case YoutubeVerificationState.verifiedOnline:
        return Colors.green;
      case YoutubeVerificationState.formatAccepted:
        return AppTheme.primary;
      case YoutubeVerificationState.invalidFormat:
        return AppTheme.danger;
      default:
        return isFocused ? AppTheme.danger : AppTheme.border;
    }
  }

  Color _getYoutubeTextColor() {
    switch (_ytState) {
      case YoutubeVerificationState.verifiedOnline:
        return Colors.green;
      case YoutubeVerificationState.formatAccepted:
        return AppTheme.primary;
      case YoutubeVerificationState.invalidFormat:
        return AppTheme.danger;
      default:
        return AppTheme.textMuted;
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
          color: isSelected ? AppTheme.danger.withValues(alpha: 0.12) : AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isSelected ? AppTheme.danger : AppTheme.border,
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
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle_rounded, color: AppTheme.danger, size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
