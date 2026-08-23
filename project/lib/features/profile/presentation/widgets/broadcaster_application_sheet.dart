import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../admin/models/broadcaster_application_model.dart';

/// Interactive In-App Application Sheet for Viewers applying to become
/// Verified Scholars or Registering Organization Auditoriums.
class BroadcasterApplicationSheet extends StatefulWidget {
  final BroadcasterApplicationModel? existingApplication;

  const BroadcasterApplicationSheet({
    super.key,
    this.existingApplication,
  });

  static void show(BuildContext context,
      {BroadcasterApplicationModel? application}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) =>
          BroadcasterApplicationSheet(existingApplication: application),
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

  @override
  void initState() {
    super.initState();
    final app = widget.existingApplication;
    _selectedRole = app?.accountType ?? ApplicationAccountType.individualScholar;

    final provider = context.read<AppProvider>();
    final defaultEmail = provider.currentUserEmail ?? provider.googleUserEmail ?? '';
    final defaultName = provider.googleUserName ?? provider.userProfile.nameEn;

    _nameEnController = TextEditingController(text: app?.applicantNameEn ?? (defaultName.isNotEmpty ? defaultName : ''));
    _nameArController = TextEditingController(
        text: app?.applicantNameAr ??
            (provider.userProfile.nameAr.isNotEmpty ? provider.userProfile.nameAr : (defaultName.isNotEmpty ? defaultName : '')));
    _emailController = TextEditingController(text: app?.email ?? defaultEmail);
    _phoneController = TextEditingController(text: app?.phone ?? '+966 ');

    _academicTitleEnController =
        TextEditingController(text: app?.academicTitleEn ?? 'Assistant Professor');
    _academicTitleArController =
        TextEditingController(text: app?.academicTitleAr ?? 'أستاذ مساعد');
    _institutionEnController =
        TextEditingController(text: app?.institutionEn ?? 'King Fahd University');
    _institutionArController =
        TextEditingController(text: app?.institutionAr ?? 'جامعة الملك فهد للبترول والمعادن');
    _tagsController = TextEditingController(
        text: app?.tags.isNotEmpty == true
            ? app!.tags.join(', ')
            : '#AI, #Technology');

    _orgTypeController = TextEditingController(
        text: app?.organizationType ?? 'University & Research Center');
    _venueNameEnController =
        TextEditingController(text: app?.venueNameEn ?? 'Grand Auditorium');
    _venueNameArController =
        TextEditingController(text: app?.venueNameAr ?? 'المدرج الأكاديمي الرئيسي');
    _seatingCapacityController = TextEditingController(
        text: app?.seatingCapacity != null && app!.seatingCapacity > 0
            ? app.seatingCapacity.toString()
            : '350');
    _websiteController =
        TextEditingController(text: app?.officialWebsiteUrl ?? 'https://');
    _latController = TextEditingController(
        text: app?.latitude.toString() ?? '26.3050');
    _lngController = TextEditingController(
        text: app?.longitude.toString() ?? '50.1450');

    _youtubeChannelController = TextEditingController(
        text: app?.youtubeChannelUrl ?? 'https://youtube.com/@channel');
    _youtubeHandleController =
        TextEditingController(text: app?.youtubeHandle ?? 'academic_channel');
    _bioEnController = TextEditingController(
        text: app?.bioEn ??
            'Dedicated academic researcher delivering open lectures in the Eastern Province.');
    _bioArController = TextEditingController(
        text: app?.bioAr ??
            'باحث ومحاضر أكاديمي مكرس لتقديم المحاضرات العلمية المفتوحة بالمنطقة الشرقية.');

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
            color: AppTheme.accentRed,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
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

  void _fillCityCoordinates(String cityName) {
    setState(() {
      if (cityName == 'Al Khobar') {
        _latController.text = '26.2871';
        _lngController.text = '50.2125';
      } else if (cityName == 'Dhahran') {
        _latController.text = '26.3050';
        _lngController.text = '50.1450';
      } else if (cityName == 'Dammam') {
        _latController.text = '26.4207';
        _lngController.text = '50.0888';
      }
    });
  }

  Future<void> _handleSubmit() async {
    final nameEn = _nameEnController.text.trim();
    final nameAr = _nameArController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (nameEn.isEmpty || nameAr.isEmpty) {
      _scrollToKey(_nameKey);
      _showErrorBanner('${'settings.required_field_missing'.tr()} Name (En/Ar)');
      return;
    }

    if (email.isEmpty || !email.contains('@')) {
      _scrollToKey(_emailKey);
      _showErrorBanner('${'settings.required_field_missing'.tr()} Valid Email');
      return;
    }

    if (_selectedRole == ApplicationAccountType.individualScholar) {
      if (_academicTitleEnController.text.trim().isEmpty ||
          _institutionEnController.text.trim().isEmpty) {
        _scrollToKey(_academicKey);
        _showErrorBanner(
            '${'settings.required_field_missing'.tr()} Academic Title / University');
        return;
      }
    } else {
      if (_venueNameEnController.text.trim().isEmpty ||
          _venueNameArController.text.trim().isEmpty) {
        _scrollToKey(_venueKey);
        _showErrorBanner(
            '${'settings.required_field_missing'.tr()} Physical Venue / Auditorium Name');
        return;
      }
    }

    if (_youtubeHandleController.text.trim().isEmpty) {
      _scrollToKey(_youtubeKey);
      _showErrorBanner(
          '${'settings.required_field_missing'.tr()} YouTube Handle');
      return;
    }

    setState(() => _isSubmitting = true);

    final tags = _tagsController.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final lat = double.tryParse(_latController.text.trim()) ?? 26.2871;
    final lng = double.tryParse(_lngController.text.trim()) ?? 50.2125;
    final capacity = int.tryParse(_seatingCapacityController.text.trim()) ?? 250;

    final application = BroadcasterApplicationModel(
      id: widget.existingApplication?.id ??
          'app_${DateTime.now().millisecondsSinceEpoch}',
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
      tags: tags.isNotEmpty ? tags : ['#Education', '#SaudiLectures'],
      organizationType: _selectedRole == ApplicationAccountType.organizationVenue
          ? _orgTypeController.text.trim()
          : null,
      venueNameEn: _venueNameEnController.text.trim(),
      venueNameAr: _venueNameArController.text.trim(),
      latitude: lat,
      longitude: lng,
      seatingCapacity: capacity,
      officialWebsiteUrl: _websiteController.text.trim(),
      youtubeChannelUrl: _youtubeChannelController.text.trim(),
      youtubeHandle: _youtubeHandleController.text.trim().replaceAll('@', ''),
      bioEn: _bioEnController.text.trim(),
      bioAr: _bioArController.text.trim(),
      avatarUrl: widget.existingApplication?.avatarUrl ??
          'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
      bannerUrl: widget.existingApplication?.bannerUrl ??
          'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
      status: ApplicationStatus.pending,
      submittedAt: DateTime.now(),
    );

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await appProvider.submitBroadcasterApplication(application);

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
              color: AppTheme.accentGreen,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'application.submitted_toast'.tr(),
                    style: const TextStyle(
                      color: Colors.white,
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
                color: AppTheme.darkBorderSubtle,
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
                  color: AppTheme.accentBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: AppTheme.accentBlue, size: 22),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'application.title'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textPrimaryDark,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'application.subtitle'.tr(),
                      style: const TextStyle(
                        color: AppTheme.textSecondaryDark,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.textSecondaryDark),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(color: AppTheme.darkBorderSubtle, height: 24),

          // Form Scroll View
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Role Segmented Switcher
                  _buildRoleSwitcher(),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _emailController,
                            label: 'application.email'.tr(),
                            hint: 'academic@university.edu.sa',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
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
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
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
                                Text(
                                  'application.submit_btn'.tr(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
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
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.darkSurface3 : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: isSelected
              ? Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.8))
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.accentBlue : AppTheme.textSecondaryDark,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textSecondaryDark,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          _buildSectionHeader('application.section_academic'.tr(),
              Icons.school_outlined),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _academicTitleEnController,
                  label: 'application.academic_title_en'.tr(),
                  hint: 'e.g. Associate Professor',
                  icon: Icons.workspace_premium_outlined,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
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
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _institutionEnController,
                  label: 'application.institution_en'.tr(),
                  hint: 'e.g. King Fahd University',
                  icon: Icons.account_balance_outlined,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
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
        _buildSectionHeader('application.section_academic'.tr(),
            Icons.domain_outlined),
        const SizedBox(height: AppTheme.spaceSm),
        _buildTextField(
          controller: _orgTypeController,
          label: 'application.org_type'.tr(),
          hint: 'University, Research Center, Cultural Hall',
          icon: Icons.category_outlined,
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _seatingCapacityController,
                label: 'application.seating_capacity'.tr(),
                hint: 'e.g. 500 Seats',
                icon: Icons.event_seat_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
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
          _buildSectionHeader('application.section_venue'.tr(),
              Icons.location_on_outlined),
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

          // Quick GPS Coordinate Presets
          Row(
            children: [
              const Text(
                'AlSharqia Presets:',
                style: TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _buildPresetChip('Al Khobar'),
              const SizedBox(width: 4),
              _buildPresetChip('Dhahran'),
              const SizedBox(width: 4),
              _buildPresetChip('Dammam'),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _latController,
                  label: 'application.latitude'.tr(),
                  hint: '26.3050',
                  icon: Icons.my_location_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: _buildTextField(
                  controller: _lngController,
                  label: 'application.longitude'.tr(),
                  hint: '50.1450',
                  icon: Icons.explore_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String cityName) {
    return InkWell(
      onTap: () => _fillCityCoordinates(cityName),
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.darkBorderSubtle),
        ),
        child: Text(
          cityName,
          style: const TextStyle(color: AppTheme.accentBlue, fontSize: 10),
        ),
      ),
    );
  }

  Widget _buildStreamingSection() {
    return KeyedSubtree(
      key: _youtubeKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('application.section_stream'.tr(),
              Icons.videocam_outlined),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _youtubeChannelController,
                  label: 'application.youtube_channel'.tr(),
                  hint: 'https://youtube.com/@channel',
                  icon: Icons.link_rounded,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: AppTheme.darkSurface2,
          style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
          icon: const Icon(Icons.arrow_drop_down_rounded,
              color: AppTheme.textSecondaryDark),
          items: const [
            DropdownMenuItem(
                value: 'computer_science',
                child: Text('💻 Computer Science & AI')),
            DropdownMenuItem(
                value: 'medical_health',
                child: Text('🩺 Medicine & Health Sciences')),
            DropdownMenuItem(
                value: 'engineering',
                child: Text('⚙️ Engineering & Architecture')),
            DropdownMenuItem(
                value: 'islamic_studies',
                child: Text('📜 Islamic & Arabic Studies')),
            DropdownMenuItem(
                value: 'business_finance',
                child: Text('📊 Business & Fintech')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCategory = val);
            }
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.accentBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimaryDark,
            fontSize: 13,
            fontWeight: FontWeight.bold,
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
            color: AppTheme.textSecondaryDark,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppTheme.textSecondaryDark, fontSize: 12),
            prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondaryDark),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: AppTheme.darkSurface2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.accentBlue),
            ),
          ),
        ),
      ],
    );
  }
}
