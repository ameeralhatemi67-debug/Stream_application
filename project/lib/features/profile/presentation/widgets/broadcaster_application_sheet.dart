import '../../../../core/services/youtube_channel_reference.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../admin/models/broadcaster_application_model.dart';
import '../../../map/models/map_tricity_domain.dart';
import '../../../auth/presentation/widgets/location_picker_modal.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';
import '../../../../core/providers/app_flags.dart';

/// Interactive In-App Application Sheet for Viewers applying to become
/// Verified Scholars or Registering Organization Auditoriums.
class BroadcasterApplicationSheet extends StatefulWidget {
  final BroadcasterApplicationModel? existingApplication;
  final bool editingProfile;

  const BroadcasterApplicationSheet({
    super.key,
    this.existingApplication,
    this.editingProfile = false,
  });

  static void show(BuildContext context,
      {BroadcasterApplicationModel? application, bool editingProfile = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 720),
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => BroadcasterApplicationSheet(
          existingApplication: application, editingProfile: editingProfile),
    );
  }

  @override
  State<BroadcasterApplicationSheet> createState() =>
      _BroadcasterApplicationSheetState();
}

class _BroadcasterApplicationSheetState
    extends State<BroadcasterApplicationSheet> {
  final _scrollController = ScrollController();

  // Scroll Keys for Auto-Navigation on Error
  final _nameKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _academicKey = GlobalKey();
  final _venueKey = GlobalKey();
  final _youtubeKey = GlobalKey();

  late ApplicationAccountType _selectedRole;
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

  // Scholar fields
  late final TextEditingController _academicTitleEnController;
  late final TextEditingController _academicTitleArController;
  late final TextEditingController _institutionEnController;
  late final TextEditingController _institutionArController;
  late final TextEditingController _tagsController;
  String _selectedCategory = 'computer_science';

  // Organization fields
  late final TextEditingController _orgTypeController;
  late final TextEditingController _venueNameEnController;
  late final TextEditingController _venueNameArController;
  late final TextEditingController _seatingCapacityController;
  late final TextEditingController _websiteController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  // Streaming & Profile fields
  late final TextEditingController _youtubeChannelController;
  late final TextEditingController _youtubeHandleController;
  late final TextEditingController _bioEnController;
  late final TextEditingController _bioArController;

  bool _isSubmitting = false;
  String _cityId = '';

  @override
  void initState() {
    super.initState();
    final app = widget.existingApplication;
    _cityId = app?.cityId ?? '';
    _selectedRole =
        app?.accountType ?? ApplicationAccountType.individualScholar;

    final provider = context.read<AppProvider>();
    final defaultEmail =
        provider.currentUserEmail ?? provider.googleUserEmail ?? '';
    final defaultName = provider.googleUserName ?? provider.userProfile.nameEn;

    _nameEnController = TextEditingController(
        text: app?.applicantNameEn ??
            (defaultName.isNotEmpty ? defaultName : ''));
    _nameArController = TextEditingController(
        text: app?.applicantNameAr ??
            (provider.userProfile.nameAr.isNotEmpty
                ? provider.userProfile.nameAr
                : (defaultName.isNotEmpty ? defaultName : '')));
    _emailController = TextEditingController(text: app?.email ?? defaultEmail);
    _phoneController = TextEditingController(text: app?.phone ?? '+966 ');

    _academicTitleEnController =
        TextEditingController(text: app?.academicTitleEn ?? '');
    _academicTitleArController =
        TextEditingController(text: app?.academicTitleAr ?? '');
    _institutionEnController =
        TextEditingController(text: app?.institutionEn ?? '');
    _institutionArController =
        TextEditingController(text: app?.institutionAr ?? '');
    _tagsController = TextEditingController(
        text: app?.tags.isNotEmpty == true ? app!.tags.join(', ') : '');

    _orgTypeController =
        TextEditingController(text: app?.organizationType ?? '');
    _venueNameEnController =
        TextEditingController(text: app?.venueNameEn ?? '');
    _venueNameArController =
        TextEditingController(text: app?.venueNameAr ?? '');
    _seatingCapacityController = TextEditingController(
        text: app?.seatingCapacity != null && app!.seatingCapacity > 0
            ? app.seatingCapacity.toString()
            : '');
    _websiteController =
        TextEditingController(text: app?.officialWebsiteUrl ?? '');
    _latController =
        TextEditingController(text: app?.latitude.toString() ?? '');
    _lngController =
        TextEditingController(text: app?.longitude.toString() ?? '');

    _youtubeChannelController =
        TextEditingController(text: app?.youtubeChannelUrl ?? '');
    _youtubeHandleController =
        TextEditingController(text: app?.youtubeHandle ?? '');
    _bioEnController = TextEditingController(text: app?.bioEn ?? '');
    _bioArController = TextEditingController(text: app?.bioAr ?? '');

    if (app != null && app.categoryId.isNotEmpty) {
      _selectedCategory = app.categoryId;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _academicTitleEnController.dispose();
    _academicTitleArController.dispose();
    _institutionEnController.dispose();
    _institutionArController.dispose();
    _tagsController.dispose();
    _orgTypeController.dispose();
    _venueNameEnController.dispose();
    _venueNameArController.dispose();
    _seatingCapacityController.dispose();
    _websiteController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _youtubeChannelController.dispose();
    _youtubeHandleController.dispose();
    _bioEnController.dispose();
    _bioArController.dispose();
    super.dispose();
  }

  void _scrollToKey(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    }
  }

  void _showErrorBanner(String message) {
    showTopSnackBar(
      Overlay.of(context),
      Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.danger,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(
                color: AppTheme.shadow,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.onMedia),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.onMedia,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      displayDuration: const Duration(seconds: 4),
    );
  }

  Future<void> _openLocationPicker() async {
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    final initial = lat != null &&
            lng != null &&
            lat.isFinite &&
            lng.isFinite &&
            !(lat == 0 && lng == 0)
        ? LatLng(lat, lng)
        : null;
    final result = await LocationPickerModal.show(
      context: context,
      initialCity: _cityId,
      initialLocation: initial,
    );
    if (!mounted || result == null) return;
    setState(() {
      _latController.text = result.coordinates.latitude.toString();
      _lngController.text = result.coordinates.longitude.toString();
    });
  }

  Future<bool> _confirmSensitiveEdit() async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Row(
            children: [
              Expanded(child: Text('profile.review_confirm_title'.tr())),
              IconButton(
                tooltip: 'design_ui.cancel'.tr(),
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(dialogContext).pop(false),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('profile.review_confirm_message'.tr()),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('profile.review_fields_title'.tr()),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text('profile.review_fields_list'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('profile.review_confirm_yes'.tr()),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _handleSubmit() async {
    if (!widget.editingProfile &&
        _selectedRole == ApplicationAccountType.organizationVenue &&
        !AppFlags.instance.organizationApplicationsOpen) {
      _showErrorBanner('application.organization_coming_soon'.tr());
      return;
    }
    final nameEn = _nameEnController.text.trim();
    final nameAr = _nameArController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (nameEn.isEmpty || nameAr.isEmpty) {
      _scrollToKey(_nameKey);
      _showErrorBanner(
          '${'settings.required_field_missing'.tr()} Name (En/Ar)');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _scrollToKey(_emailKey);
      _showErrorBanner('${'settings.required_field_missing'.tr()} Valid Email');
      return;
    }

    if (!widget.editingProfile &&
        _selectedRole == ApplicationAccountType.individualScholar) {
      if (_academicTitleEnController.text.trim().isEmpty ||
          _institutionEnController.text.trim().isEmpty) {
        _scrollToKey(_academicKey);
        _showErrorBanner(
            '${'settings.required_field_missing'.tr()} Academic Title / University');
        return;
      }
    } else if (!widget.editingProfile) {
      if (_venueNameEnController.text.trim().isEmpty ||
          _venueNameArController.text.trim().isEmpty) {
        _scrollToKey(_venueKey);
        _showErrorBanner(
            '${'settings.required_field_missing'.tr()} Physical Venue / Auditorium Name');
        return;
      }
    }

    final channelChanged = !widget.editingProfile ||
        _youtubeChannelController.text.trim() !=
            widget.existingApplication?.youtubeChannelUrl.trim() ||
        _youtubeHandleController.text.trim() !=
            widget.existingApplication?.youtubeHandle.trim();
    final channelError = channelChanged
        ? YouTubeChannelReference.pairError(
            _youtubeChannelController.text, _youtubeHandleController.text)
        : null;
    if (channelError != null) {
      _scrollToKey(_youtubeKey);
      _showErrorBanner(channelError.tr());
      return;
    }
    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final noPoint = _latController.text.trim().isEmpty &&
        _lngController.text.trim().isEmpty;
    final lat = noPoint ? 0.0 : double.tryParse(_latController.text.trim());
    final lng = noPoint ? 0.0 : double.tryParse(_lngController.text.trim());
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      _showErrorBanner('map.pin_invalid'.tr());
      return;
    }
    final locationChanged = !widget.editingProfile ||
        lat != widget.existingApplication?.latitude ||
        lng != widget.existingApplication?.longitude ||
        _cityId != widget.existingApplication?.cityId ||
        _venueNameEnController.text.trim() !=
            widget.existingApplication?.venueNameEn ||
        _venueNameArController.text.trim() !=
            widget.existingApplication?.venueNameAr;
    if (locationChanged && !isInTricityMapDomain(lat, lng)) {
      _scrollToKey(_venueKey);
      _showErrorBanner('map.location_outside_supported'.tr());
      return;
    }
    final capacity = int.tryParse(_seatingCapacityController.text.trim()) ?? 0;

    final application = BroadcasterApplicationModel(
      id: widget.existingApplication?.id ?? newId(),
      accountType: _selectedRole,
      applicantNameEn: nameEn,
      applicantNameAr: nameAr,
      email: email,
      phone: phone,
      academicTitleEn: _selectedRole == ApplicationAccountType.individualScholar
          ? _academicTitleEnController.text.trim()
          : null,
      academicTitleAr: _selectedRole == ApplicationAccountType.individualScholar
          ? _academicTitleArController.text.trim()
          : null,
      institutionEn: _selectedRole == ApplicationAccountType.individualScholar
          ? _institutionEnController.text.trim()
          : null,
      institutionAr: _selectedRole == ApplicationAccountType.individualScholar
          ? _institutionArController.text.trim()
          : null,
      categoryId: _selectedCategory,
      tags: tags,
      organizationType:
          _selectedRole == ApplicationAccountType.organizationVenue
              ? _orgTypeController.text.trim()
              : null,
      venueNameEn: _venueNameEnController.text.trim(),
      venueNameAr: _venueNameArController.text.trim(),
      cityId: _cityId,
      latitude: lat,
      longitude: lng,
      seatingCapacity: capacity,
      officialWebsiteUrl: _websiteController.text.trim(),
      youtubeChannelUrl: _youtubeChannelController.text.trim(),
      youtubeHandle: _youtubeHandleController.text.trim(),
      bioEn: _bioEnController.text.trim(),
      bioAr: _bioArController.text.trim(),
      avatarUrl: widget.existingApplication?.avatarUrl ?? '',
      bannerUrl: widget.existingApplication?.bannerUrl ?? '',
      status: ApplicationStatus.pending,
      submittedAt: DateTime.now(),
    );

    final previous = widget.existingApplication;
    final sensitiveChanged = widget.editingProfile &&
        previous != null &&
        (email != previous.email ||
            phone != previous.phone ||
            locationChanged ||
            channelChanged);
    if (sensitiveChanged && !await _confirmSensitiveEdit()) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      if (channelChanged) {
        await context.read<AppProvider>().validateChannelConfiguration(
            _youtubeChannelController.text, _youtubeHandleController.text);
      }
    } on FormatException catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorBanner(e.message.tr());
      }
      return;
    }
    if (!mounted) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    var needsReview = true;
    try {
      if (widget.editingProfile) {
        needsReview = await appProvider.saveBroadcasterProfile(application);
      } else {
        await appProvider.submitBroadcasterApplication(application);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorBanner('offline_experience.form_preserved'.tr());
      }
      return;
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();

      showTopSnackBar(
        Overlay.of(context),
        Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.success,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: const [
                BoxShadow(
                  color: AppTheme.shadow,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: AppTheme.onMedia),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    (needsReview
                            ? 'application.submitted_toast'
                            : 'profile.edit_saved')
                        .tr(),
                    style: const TextStyle(
                      color: AppTheme.onMedia,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        displayDuration: const Duration(seconds: 4),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spaceLg,
        right: AppTheme.spaceLg,
        top: AppTheme.spaceMd,
        bottom: bottomInset + AppTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceSm),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.editingProfile
                              ? 'settings.edit_profile'
                              : 'application.title')
                          .tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      (widget.editingProfile
                              ? 'profile.edit_review_help'
                              : 'application.subtitle')
                          .tr(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(color: AppTheme.border, height: 24),

          // Form Scroll View
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Role Segmented Switcher
                  if (!widget.editingProfile) _buildRoleSwitcher(),
                  const SizedBox(height: AppTheme.spaceLg),

                  // 2. Identity & Contact Information
                  _buildSectionHeader('application.section_personal'.tr(),
                      Icons.person_outline_rounded),
                  const SizedBox(height: AppTheme.spaceSm),
                  KeyedSubtree(
                    key: _nameKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: _nameEnController,
                          label: 'application.name_en'.tr(),
                          hint: 'e.g. Dr. Zaid Al-Otaibi',
                          icon: Icons.badge_outlined,
                        ),
                        const SizedBox(height: AppTheme.spaceSm),
                        _buildTextField(
                          controller: _nameArController,
                          label: 'application.name_ar'.tr(),
                          hint: 'مثال: د. زيد العتيبي',
                          icon: Icons.translate_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  KeyedSubtree(
                    key: _emailKey,
                    child: Flex(
                      direction: MediaQuery.sizeOf(context).width < 600
                          ? Axis.vertical
                          : Axis.horizontal,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          fit: FlexFit.loose,
                          child: _buildTextField(
                            controller: _emailController,
                            label: 'application.email'.tr(),
                            hint: 'academic@university.edu.sa',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(
                            width: AppTheme.spaceSm, height: AppTheme.spaceSm),
                        Flexible(
                          fit: FlexFit.loose,
                          child: _buildTextField(
                            controller: _phoneController,
                            label: 'application.phone'.tr(),
                            hint: '+966 50 123 4567',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceLg),

                  // 3. Academic or Organization Details
                  if (_selectedRole == ApplicationAccountType.individualScholar)
                    _buildScholarSection()
                  else
                    _buildOrganizationSection(),
                  const SizedBox(height: AppTheme.spaceLg),

                  // 4. Physical Venue & GIS Coordinates
                  _buildVenueSection(),
                  const SizedBox(height: AppTheme.spaceLg),

                  // 5. Streaming & Bio
                  _buildStreamingSection(),
                  const SizedBox(height: AppTheme.spaceXl),

                  // Submit Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: AppTheme.onMedia,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: HadayahLoadingIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.onMedia,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('application.submitting'.tr()),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    (widget.editingProfile
                                            ? 'profile.save_changes'
                                            : 'application.submit_btn')
                                        .tr(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleTab(
              type: ApplicationAccountType.individualScholar,
              title: 'application.role_scholar'.tr(),
              subtitle: 'application.role_scholar_desc'.tr(),
              icon: Icons.school_rounded,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildRoleTab(
              type: ApplicationAccountType.organizationVenue,
              title: 'application.role_org'.tr(),
              subtitle: 'application.role_org_desc'.tr(),
              icon: Icons.apartment_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab({
    required ApplicationAccountType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == type;
    final unavailable = type == ApplicationAccountType.organizationVenue &&
        !widget.editingProfile &&
        !AppFlags.instance.organizationApplicationsOpen;
    return GestureDetector(
      onTap: () {
        if (unavailable) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('application.organization_coming_soon'.tr()),
          ));
          return;
        }
        setState(() => _selectedRole = type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: isSelected
              ? Border.all(color: AppTheme.primary.withValues(alpha: 0.8))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: unavailable
                  ? AppTheme.textMuted
                  : (isSelected ? AppTheme.primary : AppTheme.textSecondary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: unavailable
                          ? AppTheme.textMuted
                          : isSelected
                              ? AppTheme.textPrimary
                              : AppTheme.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScholarSection() {
    return KeyedSubtree(
      key: _academicKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'application.section_academic'.tr(), Icons.school_outlined),
          const SizedBox(height: AppTheme.spaceSm),
          Flex(
            direction: MediaQuery.sizeOf(context).width < 600
                ? Axis.vertical
                : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: _buildTextField(
                  controller: _academicTitleEnController,
                  label: 'application.academic_title_en'.tr(),
                  hint: 'e.g. Associate Professor',
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm, height: AppTheme.spaceSm),
              Flexible(
                fit: FlexFit.loose,
                child: _buildTextField(
                  controller: _academicTitleArController,
                  label: 'application.academic_title_ar'.tr(),
                  hint: 'مثال: أستاذ مشارك',
                  icon: Icons.translate_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Flex(
            direction: MediaQuery.sizeOf(context).width < 600
                ? Axis.vertical
                : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: _buildTextField(
                  controller: _institutionEnController,
                  label: 'application.institution_en'.tr(),
                  hint: 'e.g. King Fahd University',
                  icon: Icons.account_balance_outlined,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm, height: AppTheme.spaceSm),
              Flexible(
                fit: FlexFit.loose,
                child: _buildTextField(
                  controller: _institutionArController,
                  label: 'application.institution_ar'.tr(),
                  hint: 'مثال: جامعة الملك فهد',
                  icon: Icons.translate_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildCategoryDropdown(),
          const SizedBox(height: AppTheme.spaceSm),
          _buildTextField(
            controller: _tagsController,
            label: 'application.tags'.tr(),
            hint: '#AI, #Robotics, #Medicine',
            icon: Icons.tag_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildOrganizationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            'application.section_academic'.tr(), Icons.domain_outlined),
        const SizedBox(height: AppTheme.spaceSm),
        _buildTextField(
          controller: _orgTypeController,
          label: 'application.org_type'.tr(),
          hint: 'University, Research Center, Cultural Hall',
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Flex(
          direction: MediaQuery.sizeOf(context).width < 600
              ? Axis.vertical
              : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: _buildTextField(
                controller: _seatingCapacityController,
                label: 'application.seating_capacity'.tr(),
                hint: 'e.g. 500 Seats',
                icon: Icons.event_seat_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm, height: AppTheme.spaceSm),
            Flexible(
              fit: FlexFit.loose,
              child: _buildTextField(
                controller: _websiteController,
                label: 'application.website_url'.tr(),
                hint: 'https://kfupm.edu.sa',
                icon: Icons.language_rounded,
                keyboardType: TextInputType.url,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _buildCategoryDropdown(),
      ],
    );
  }

  Widget _buildVenueSection() {
    return KeyedSubtree(
      key: _venueKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'application.section_venue'.tr(), Icons.location_on_outlined),
          const SizedBox(height: AppTheme.spaceSm),
          _buildTextField(
            controller: _venueNameEnController,
            label: 'application.venue_name_en'.tr(),
            hint: 'e.g. Building 24 Grand Auditorium',
            icon: Icons.apartment_outlined,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildTextField(
            controller: _venueNameArController,
            label: 'application.venue_name_ar'.tr(),
            hint: 'مثال: قاعة ومدرج مبنى 24 الرئيسي',
            icon: Icons.translate_rounded,
          ),
          const SizedBox(height: AppTheme.spaceSm),

          // City membership is independent of the exact venue coordinates.
          DropdownButtonFormField<String>(
            initialValue:
                const {'khobar', 'dhahran', 'dammam'}.contains(_cityId)
                    ? _cityId
                    : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'profile.city'.tr(),
              helperText: _cityId.isNotEmpty &&
                      !const {'khobar', 'dhahran', 'dammam'}.contains(_cityId)
                  ? '${'profile.saved_city'.tr()}: '
                      '${context.locale.languageCode == 'ar' ? BroadcasterApplicationModel.cityNames[_cityId]?.nameAr ?? _cityId : BroadcasterApplicationModel.cityNames[_cityId]?.nameEn ?? _cityId}'
                  : null,
            ),
            items: BroadcasterApplicationModel.cityNames.entries
                .where((city) =>
                    const {'khobar', 'dhahran', 'dammam'}.contains(city.key))
                .map((city) => DropdownMenuItem(
                      value: city.key,
                      child: Text(context.locale.languageCode == 'ar'
                          ? city.value.nameAr
                          : city.value.nameEn),
                    ))
                .toList(),
            onChanged: (city) => setState(() => _cityId = city ?? ''),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text('profile.current_location'.tr(),
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppTheme.spaceXs),
          OutlinedButton.icon(
            onPressed: _openLocationPicker,
            icon: const Icon(Icons.pin_drop_outlined),
            label: Text('design_ui.pinpoint_broadcast_location'.tr()),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            _latController.text.trim().isEmpty ||
                    _lngController.text.trim().isEmpty
                ? 'map.picker_no_point'.tr()
                : 'map.picker_pinned_point'.tr(namedArgs: {
                    'coords':
                        '${_latController.text.trim()}, ${_lngController.text.trim()}',
                  }),
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingSection() {
    return KeyedSubtree(
      key: _youtubeKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
              'application.section_stream'.tr(), Icons.videocam_outlined),
          const SizedBox(height: AppTheme.spaceSm),
          Flex(
            direction: MediaQuery.sizeOf(context).width < 600
                ? Axis.vertical
                : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                fit: FlexFit.loose,
                child: _buildTextField(
                  controller: _youtubeChannelController,
                  label: 'application.youtube_channel'.tr(),
                  hint: 'https://youtube.com/@channel',
                  icon: Icons.link_rounded,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm, height: AppTheme.spaceSm),
              Flexible(
                fit: FlexFit.loose,
                child: _buildTextField(
                  controller: _youtubeHandleController,
                  label: 'application.youtube_handle'.tr(),
                  hint: '@academic_channel',
                  icon: Icons.alternate_email_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildTextField(
            controller: _bioEnController,
            label: 'application.bio_en'.tr(),
            hint: 'Describe your research topics, lectures, and goals...',
            icon: Icons.article_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          _buildTextField(
            controller: _bioArController,
            label: 'application.bio_ar'.tr(),
            hint: 'نبذة عن أبحاثك والمحاضرات العلمية المقررة...',
            icon: Icons.translate_rounded,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categories = <String, String>{
      'computer_science': 'design_ui.computer_science_ai'.tr(),
      'medical_health': 'design_ui.medicine_health_sciences'.tr(),
      'engineering': 'design_ui.engineering_architecture'.tr(),
      'islamic_studies': 'design_ui.islamic_arabic_studies'.tr(),
      'business_finance': 'design_ui.business_fintech'.tr(),
      for (final category
          in context.select((AppProvider p) => p.academicCategories))
        if (category.isActive || category.id == _selectedCategory)
          category.id: category.getLocalizedName(context.locale.languageCode),
    };
    // Preserve registration/legacy/custom IDs until the user changes them.
    categories.putIfAbsent(
      _selectedCategory,
      () => _selectedCategory == 'cs_tech'
          ? 'design_ui.computer_science_ai'.tr()
          : _selectedCategory,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: AppTheme.surfaceAlt,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppTheme.textSecondary),
          items: categories.entries
              .map((category) => DropdownMenuItem(
                    value: category.key,
                    child: Text(category.value),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCategory = val);
            }
          },
        ),
      ),
    );
  }

  /// Every section header in this sheet: an icon and a title that has to give
  /// way rather than overrun a 320 px form, in either language.
  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondary),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppTheme.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.primary),
            ),
          ),
        ),
      ],
    );
  }
}
