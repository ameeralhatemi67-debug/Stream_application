import '../../../../core/widgets/ds/ca_fields.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';

/// Modal sheet enabling individual broadcasters to search and apply to join an Organization
class JoinOrgModalSheet extends StatefulWidget {
  const JoinOrgModalSheet({super.key});

  static void show(BuildContext context) {
    showCaSheet<void>(context,
        title: 'design_ui.join_an_organization'.tr(),
        body: const JoinOrgModalSheet(),
        framed: false);
  }

  @override
  State<JoinOrgModalSheet> createState() => _JoinOrgModalSheetState();
}

class _JoinOrgModalSheetState extends State<JoinOrgModalSheet> {
  String? _selectedOrgId;
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;

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
    _roleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_selectedOrgId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('affiliation_modal.error_select_org'.tr()),
          backgroundColor: Canopy.liveCrimson,
        ),
      );
      return;
    }

    if (_noteController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('affiliation_modal.error_note_empty'.tr()),
          backgroundColor: Canopy.liveCrimson,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = context.read<AppProvider>();

    try {
      await provider.submitOrgAffiliationRequest(
        orgId: _selectedOrgId!,
        note: _noteController.text.trim(),
        proposedRoleEn: _roleController.text.trim().isNotEmpty
            ? _roleController.text.trim()
            : 'Guest Speaker',
        proposedRoleAr: _roleController.text.trim().isNotEmpty
            ? _roleController.text.trim()
            : 'محاضر زائر',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('affiliation_modal.submitted_toast'.tr()),
          backgroundColor: Canopy.leaf,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Canopy.liveCrimson,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final orgs = provider.streamers.where((s) => s.isOrganization).toList();

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Canopy.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                const Icon(Icons.business_rounded,
                    color: Canopy.liveCrimson, size: 22),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'affiliation_modal.title'.tr(),
                    style: const TextStyle(
                      color: Canopy.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'affiliation_modal.subtitle'.tr(),
              style: const TextStyle(
                color: Canopy.slate,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),

            // Organization Directory Selector
            Text(
              'affiliation_modal.select_org'.tr(),
              style: const TextStyle(
                color: Canopy.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            ...orgs.map((org) {
              final isSelected = _selectedOrgId == org.streamerId;
              return GestureDetector(
                onTap: () => setState(() => _selectedOrgId = org.streamerId),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Canopy.liveCrimson.withValues(alpha: 0.12)
                        : Canopy.mint,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: isSelected ? Canopy.liveCrimson : Canopy.hairline,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: AssetImage(org.avatarUrl),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.locale.languageCode == 'ar'
                                  ? org.fullNameAr
                                  : org.fullNameEn,
                              style: const TextStyle(
                                color: Canopy.ink,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              '${org.venues.length} Campus Locations • ${org.affiliatedSpeakers.length} Affiliated Speakers',
                              style: const TextStyle(
                                color: Canopy.haze,
                                fontSize: AppTheme.captionFont,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: Canopy.liveCrimson, size: 20),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),

            // Proposed Title / Role
            CaInput(
              readOnly: context.isPhoneLandscape,
              controller: _roleController,
              label: 'affiliation_modal.proposed_role'.tr(),
              hint: 'affiliation_modal.proposed_role_hint'.tr(),
            ),
            const SizedBox(height: 12),

            // Message / Note
            CaInput(
              readOnly: context.isPhoneLandscape,
              controller: _noteController,
              maxLines: 3,
              label: 'affiliation_modal.intro_note'.tr(),
              hint: 'affiliation_modal.intro_note_hint'.tr(),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Canopy.liveCrimson,
                  foregroundColor: AppTheme.onMedia,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submitRequest,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: HadayahLoadingIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onMedia,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'affiliation_modal.submit_btn'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
