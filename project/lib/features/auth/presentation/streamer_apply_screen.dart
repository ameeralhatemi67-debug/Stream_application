import '../../../core/layout/window_class.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_rows.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_button.dart';
import '../../../core/widgets/ds/ca_navigation.dart';
import 'dart:async';
import '../../../core/services/youtube_channel_reference.dart';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/translation/auto_translation_service.dart';
import '../../../core/utils/id_generator.dart';
import '../../admin/models/broadcaster_application_model.dart';
import '../../map/models/map_tricity_domain.dart';
import 'steps/apply_step_1_identity.dart';
import 'steps/apply_step_2_media.dart';
import 'steps/apply_step_3_professional.dart';
import 'steps/apply_step_3_5_org_speakers.dart';
import 'steps/apply_step_4_location.dart';
import 'steps/apply_step_5_review.dart';
import '../../../core/providers/app_flags.dart';
import '../../../core/widgets/ds/ca_surfaces.dart';

/// Dynamic Streamer / Organization Verification Application Wizard
class StreamerApplyScreen extends StatefulWidget {
  const StreamerApplyScreen({super.key});

  @override
  State<StreamerApplyScreen> createState() => _StreamerApplyScreenState();
}

class _StreamerApplyScreenState extends State<StreamerApplyScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isSubmitting = false;

  // Step 1 Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _handleController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Step 2 Media
  String? _avatarPath = 'assets/images/Amir_Alhatemi/amir_person_pic.jpg';
  String? _bannerPath = 'assets/images/Amir_Alhatemi/amir_card_pic.jpg';
  Uint8List? _avatarBytes;
  Uint8List? _bannerBytes;

  // Step 3 Controllers
  final TextEditingController _affiliationController = TextEditingController();
  final TextEditingController _youtubeController = TextEditingController();
  final TextEditingController _orgNameController = TextEditingController();
  List<String> _selectedCategories = ['cs_tech'];
  bool _isOrganization = false;
  bool _organizationOnly = false;
  final List<String> _selectedTags = ['#AI', '#Software'];

  // Step 3.5 Organization Speakers
  final List<OrgApplicationSpeaker> _orgSpeakers = [];

  // Step 4 Controllers
  String _selectedCity = '';
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _preferredContact = 'whatsapp';

  /// Exact venue point the applicant pinned; null until they pin one. An
  /// unpinned application is submitted as 0,0, the existing "no location"
  /// value, never as an invented Al Khobar point.
  LatLng? _selectedCoordinates;
  final List<OrgBranchVenue> _orgBranches = [];

  // Step 5 Terms
  bool _agreedToTerms = false;

  int get _totalSteps => _isOrganization ? 6 : 5;

  @override
  void initState() {
    super.initState();
    // Organization applications follow a server switch; re-read it here.
    AppFlags.instance.addListener(_flagsChanged);
    unawaited(AppFlags.instance.refresh());
    final provider = context.read<AppProvider>();
    final existing = provider.myApplication;

    // Editing an existing application (any status) must load its data into
    // the wizard rather than starting blank -- otherwise a genuine edit
    // silently wipes real data with defaults, and submit() below would have
    // nothing to key an upsert against, producing a second channel instead
    // of updating the first (issue_log.md: "I should not have the ability
    // to own two channels").
    if (existing != null) {
      _selectedCity = existing.cityId;
      _nameController.text = existing.isOrganization
          ? existing.applicantNameEn
          : existing.applicantNameEn;
      _handleController.text = existing.youtubeHandle;
      _bioController.text = existing.bioEn;
      _avatarPath = existing.avatarUrl;
      _bannerPath = existing.bannerUrl;
      _affiliationController.text = existing.institutionEn ?? '';
      _youtubeController.text = existing.youtubeChannelUrl;
      _orgNameController.text =
          existing.isOrganization ? existing.applicantNameEn : '';
      _selectedCategories = [existing.categoryId];
      _isOrganization = existing.isOrganization;
      _organizationOnly = existing.organizationOnly;
      _selectedTags.clear();
      _selectedTags.addAll(existing.tags);
      _venueController.text = existing.venueNameEn;
      _phoneController.text = existing.phone;
      if (existing.latitude != 0.0 || existing.longitude != 0.0) {
        _selectedCoordinates = LatLng(existing.latitude, existing.longitude);
      }
      return;
    }

    final defaultName = provider.googleUserName ?? provider.userProfile.nameEn;
    if (defaultName.isNotEmpty) {
      _nameController.text = defaultName;
      final cleanHandle =
          defaultName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      _handleController.text = '@$cleanHandle';
    }
    if (provider.googleUserAvatar != null &&
        provider.googleUserAvatar!.isNotEmpty) {
      _avatarPath = provider.googleUserAvatar;
    }
  }

  void _flagsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppFlags.instance.removeListener(_flagsChanged);
    _pageController.dispose();
    _nameController.dispose();
    _handleController.dispose();
    _bioController.dispose();
    _affiliationController.dispose();
    _youtubeController.dispose();
    _orgNameController.dispose();
    _venueController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showValidationToast('wizard_steps.step1_name_label'.tr());
        return false;
      }
      if (_handleController.text.trim().isEmpty) {
        _showValidationToast('wizard_steps.step1_handle_label'.tr());
        return false;
      }
      if (_bioController.text.trim().isEmpty) {
        _showValidationToast('wizard_steps.step1_bio_label'.tr());
        return false;
      }
    } else if (_currentStep == 1) {
      if (_avatarPath == null && _avatarBytes == null) {
        _showValidationToast('wizard_steps.step2_avatar_label'.tr());
        return false;
      }
      if (_bannerPath == null && _bannerBytes == null) {
        _showValidationToast('wizard_steps.step2_banner_label'.tr());
        return false;
      }
    } else if (_currentStep == 2) {
      if (_isOrganization && _orgNameController.text.trim().isEmpty) {
        _showValidationToast('wizard_steps.step3_org_name_label'.tr());
        return false;
      }
      if (!_organizationOnly && _youtubeController.text.trim().isEmpty) {
        _showValidationToast('wizard_steps.step3_youtube_label'.tr());
        return false;
      }
      final yt = _youtubeController.text.trim();
      final validYt = yt.startsWith('https://www.youtube.com/@') ||
          yt.startsWith('http://www.youtube.com/@') ||
          yt.startsWith('https://youtube.com/@') ||
          yt.startsWith('youtube.com/@') ||
          yt.startsWith('www.youtube.com/@') ||
          (yt.startsWith('@') && yt.length > 2);
      if (!_organizationOnly && !validYt) {
        _showValidationToast('wizard_steps.step3_yt_invalid'.tr());
        return false;
      }
      if (_selectedCategories.isEmpty) {
        _showValidationToast(
            'wizard_steps.step3_categories_title'.tr(args: ['0']));
        return false;
      }
    } else if (_isOrganization && _currentStep == 3) {
      // Step 3.5 Org Speakers (Optional to have multiple, but must not be broken)
    } else if ((!_isOrganization && _currentStep == 3) ||
        (_isOrganization && _currentStep == 4)) {
      // Location & Phone Validation
      if (_selectedCoordinates != null && _selectedCity.isEmpty) {
        _showValidationToast('settings.city_label'.tr());
        return false;
      }
      final phone = _phoneController.text.replaceAll(RegExp(r'\s+'), '');
      if (phone.isNotEmpty) {
        final isValidSaudi = RegExp(r'^05[0-9]{8}$').hasMatch(phone) ||
            RegExp(r'^9665[0-9]{8}$').hasMatch(phone) ||
            RegExp(r'^\+9665[0-9]{8}$').hasMatch(phone);
        if (!isValidSaudi) {
          _showValidationToast('wizard_steps.step4_phone_label'.tr());
          return false;
        }
      }
      if (_isOrganization && _venueController.text.trim().isEmpty) {
        _showValidationToast('wizard_steps.step4_venue_org_label'.tr());
        return false;
      }
    }
    return true;
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;

    if (_currentStep < _totalSteps - 1) {
      _moveToPage(_currentStep + 1);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _moveToPage(_currentStep - 1);
    } else {
      _leaveWizard();
    }
  }

  void _moveToPage(int page) {
    if (CanopyMotion.reduced(context)) {
      _pageController.jumpToPage(page);
    } else {
      _pageController.animateToPage(page,
          duration: CanopyMotion.sheetIn, curve: CanopyMotion.easeInOut);
    }
  }

  void _leaveWizard() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/settings');
    }
  }

  /// Leaves the wizard from any step. Back only steps backwards, so from
  /// step 5 an exit used to take five taps (P6-R09 "no way out" report).
  Future<void> _confirmExit() async {
    if (_currentStep == 0) {
      _leaveWizard();
      return;
    }
    final leave = await showCaDialog<bool>(
      context: context,
      builder: (dialogContext) => CaAlertDialog(
        title: Text('wizard_steps.exit_title'.tr()),
        content: Text('wizard_steps.exit_body'.tr()),
        actions: [
          CaButton(
              label: 'wizard_steps.exit_stay'.tr(),
              variant: CaButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext, false)),
          CaButton(
              label: 'wizard_steps.exit_leave'.tr(),
              variant: CaButtonVariant.text,
              onPressed: () => Navigator.pop(dialogContext, true)),
        ],
      ),
    );
    if (leave == true && mounted) _leaveWizard();
  }

  void _showValidationToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Canopy.liveCrimson,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (_isOrganization && !AppFlags.instance.organizationApplicationsOpen) {
      _showValidationToast('application.organization_coming_soon'.tr());
      return;
    }
    final point = _selectedCoordinates;
    if (point == null ||
        !isInTricityMapDomain(point.latitude, point.longitude)) {
      _showValidationToast('map.location_outside_supported'.tr());
      return;
    }
    final channel = YouTubeChannelReference.parse(_youtubeController.text);
    if (!_organizationOnly &&
        (channel == null || channel.parameter == 'custom')) {
      _showValidationToast('live.channel_invalid'.tr());
      return;
    }
    if (!context.read<AppProvider>().isOnline) {
      _showValidationToast('offline_experience.form_preserved'.tr());
      return;
    }
    if (!_agreedToTerms) {
      _showValidationToast(
          'You must agree to the Terms & Conditions before submitting.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<AppProvider>();
      final email = provider.currentUserEmail ?? 'applicant@streamer.app';

      // 1. Upload custom avatar / banner to Supabase Storage if available
      String finalAvatarUrl =
          _avatarPath ?? 'assets/images/Amir_Alhatemi/amir_person_pic.jpg';
      if (_avatarBytes != null) {
        final uploaded = await provider.uploadStreamerMediaAsset(
          fileName:
              'avatar_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.jpg',
          fileBytes: _avatarBytes!,
        );
        if (uploaded != null) {
          finalAvatarUrl = uploaded;
        }
      }

      String finalBannerUrl =
          _bannerPath ?? 'assets/images/Amir_Alhatemi/amir_card_pic.jpg';
      if (_bannerBytes != null) {
        final uploaded = await provider.uploadStreamerMediaAsset(
          fileName:
              'banner_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.jpg',
          fileBytes: _bannerBytes!,
        );
        if (uploaded != null) {
          finalBannerUrl = uploaded;
        }
      }

      // 2. Execute Automated Bidirectional Translation & Transliteration
      final effectiveName =
          _isOrganization && _orgNameController.text.trim().isNotEmpty
              ? _orgNameController.text.trim()
              : _nameController.text.trim();

      final effectiveAffiliation = _affiliationController.text.trim().isNotEmpty
          ? _affiliationController.text.trim()
          : (_isOrganization ? _orgNameController.text.trim() : '');

      final bilingual = await AutoTranslationService.translateAndTransliterate(
        ApplicantProfileInput(
          name: effectiveName,
          bio: _bioController.text.trim(),
          institution: effectiveAffiliation,
          venueName: _venueController.text.trim(),
          isOrganization: _isOrganization,
        ),
      );

      final app = BroadcasterApplicationModel(
        // Reuse the existing application's id when editing so the upsert in
        // AdminDatabaseService.submitApplication() (keyed on `id`) updates
        // the same row instead of inserting a second channel.
        id: provider.myApplication?.id ?? newId(),
        applicantProfileId: provider.currentUserSessionId,
        accountType: _isOrganization
            ? ApplicationAccountType.organizationVenue
            : ApplicationAccountType.individualScholar,
        organizationOnly: _organizationOnly,
        applicantNameEn: bilingual.nameEn,
        applicantNameAr: bilingual.nameAr,
        email: email,
        phone: _phoneController.text.replaceAll(RegExp(r'\s+'), ''),
        academicTitleEn: bilingual.academicTitleEn,
        academicTitleAr: bilingual.academicTitleAr,
        institutionEn: bilingual.institutionEn,
        institutionAr: bilingual.institutionAr,
        categoryId: _selectedCategories.first,
        tags: _selectedTags,
        organizationType: _isOrganization ? 'Educational Academy' : null,
        venueNameEn: bilingual.venueNameEn,
        venueNameAr: bilingual.venueNameAr,
        cityId: _selectedCity,
        latitude: _selectedCoordinates?.latitude ?? 0.0,
        longitude: _selectedCoordinates?.longitude ?? 0.0,
        seatingCapacity: _isOrganization ? 300 : 120,
        youtubeChannelUrl: _organizationOnly ? '' : channel!.url,
        youtubeHandle: _organizationOnly ? '' : channel!.stored,
        bioEn: bilingual.bioEn,
        bioAr: bilingual.bioAr,
        avatarUrl: finalAvatarUrl,
        bannerUrl: finalBannerUrl,
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      await provider.submitBroadcasterApplication(app);

      if (!mounted) return;
      context.go('/application-pending');
    } catch (e) {
      if (!mounted) return;
      _showValidationToast('offline_experience.form_preserved'.tr());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<Widget> _buildStepPages() {
    final pages = <Widget>[
      // Step 1: Identity & Bio
      ApplyStep1Identity(
        nameController: _nameController,
        handleController: _handleController,
        bioController: _bioController,
      ),

      // Step 2: Media
      ApplyStep2Media(
        avatarPath: _avatarPath,
        bannerPath: _bannerPath,
        avatarBytes: _avatarBytes,
        bannerBytes: _bannerBytes,
        onAvatarSelected: (path, bytes) {
          setState(() {
            _avatarPath = path;
            _avatarBytes = bytes;
          });
        },
        onBannerSelected: (path, bytes) {
          setState(() {
            _bannerPath = path;
            _bannerBytes = bytes;
          });
        },
      ),

      // Step 3: Professional & Channel Info
      ApplyStep3Professional(
        affiliationController: _affiliationController,
        youtubeController: _youtubeController,
        orgNameController: _orgNameController,
        selectedCategories: _selectedCategories,
        isOrganization: _isOrganization,
        organizationApplicationsOpen:
            AppFlags.instance.organizationApplicationsOpen,
        organizationOnly: _organizationOnly,
        onOrganizationOnlyChanged: (value) =>
            setState(() => _organizationOnly = value),
        selectedTags: _selectedTags,
        onCategoriesChanged: (cats) =>
            setState(() => _selectedCategories = cats),
        onTypeChanged: (isOrg) {
          setState(() {
            _isOrganization = isOrg;
          });
        },
        onTagToggled: (tag) {
          setState(() {
            if (_selectedTags.contains(tag)) {
              _selectedTags.remove(tag);
            } else {
              _selectedTags.add(tag);
            }
          });
        },
      ),
    ];

    // Optional Step 3.5: Organization Speakers
    if (_isOrganization) {
      pages.add(
        ApplyStep35OrgSpeakers(
          speakers: _orgSpeakers,
          onAddSpeaker: (spk) => setState(() => _orgSpeakers.add(spk)),
          onRemoveSpeaker: (idx) => setState(() => _orgSpeakers.removeAt(idx)),
        ),
      );
    }

    // Step 4: Locations & Contact Details
    pages.add(
      ApplyStep4Location(
        selectedCity: _selectedCity,
        venueController: _venueController,
        phoneController: _phoneController,
        preferredContact: _preferredContact,
        isOrganization: _isOrganization,
        selectedCoordinates: _selectedCoordinates,
        orgBranches: _orgBranches,
        onCityChanged: (city) => setState(() => _selectedCity = city),
        onContactPrefChanged: (pref) =>
            setState(() => _preferredContact = pref),
        onCoordinatesSelected: (coord) =>
            setState(() => _selectedCoordinates = coord),
        onAddBranch: (br) => setState(() => _orgBranches.add(br)),
        onRemoveBranch: (idx) => setState(() => _orgBranches.removeAt(idx)),
      ),
    );

    // Step 5: Review & Submit
    pages.add(
      ApplyStep5Review(
        name: _nameController.text,
        handle: _handleController.text,
        bio: _bioController.text,
        avatarPath: _avatarPath,
        bannerPath: _bannerPath,
        avatarBytes: _avatarBytes,
        bannerBytes: _bannerBytes,
        institution: _affiliationController.text,
        orgName: _orgNameController.text,
        categories: _selectedCategories,
        youtube: _youtubeController.text,
        city: _selectedCity,
        venue: _venueController.text,
        phone: _phoneController.text,
        contactPref: _preferredContact,
        isOrganization: _isOrganization,
        tags: _selectedTags,
        speakers: _orgSpeakers,
        branches: _orgBranches,
        agreedToTerms: _agreedToTerms,
        onTermsToggled: (agreed) => setState(() => _agreedToTerms = agreed),
      ),
    );

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final visualStep = _isOrganization && _currentStep > 2
        ? (_currentStep == 3 ? 2 : _currentStep - 1)
        : _currentStep;
    final names = [
      for (final name in [
        'identity',
        'media',
        'professional',
        'venue',
        'review'
      ])
        'ds.apply_$name'.tr()
    ];
    final stepper = CaStepper(steps: names, index: visualStep);
    final pages = Expanded(
        child: PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: (idx) => setState(() => _currentStep = idx),
      children: [for (final page in _buildStepPages()) CaCard(child: page)],
    ));
    final footer = Padding(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Row(children: [
        if (_currentStep > 0) ...[
          Flexible(
              child: CaButton(
                  label: 'wizard_steps.btn_back'.tr(),
                  variant: CaButtonVariant.secondary,
                  onPressed: _previousStep)),
          const SizedBox(width: AppTheme.spaceMd),
        ],
        Expanded(
            child: CaButton(
          label: (_currentStep == _totalSteps - 1
                  ? 'wizard_steps.btn_submit'
                  : 'wizard_steps.btn_next')
              .tr(),
          loading: _isSubmitting,
          onPressed: _isSubmitting
              ? null
              : (_currentStep == _totalSteps - 1
                  ? _submitApplication
                  : _nextStep),
        )),
      ]),
    );
    return Scaffold(
      backgroundColor: Canopy.dawn,
      appBar: CaAppBar(
        languageBare: true,
        leading: CaIconButton(
            bare: true,
            icon: CaGlyph.back,
            label: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _previousStep),
        title: Text('ds.apply_title'.tr()),
        actions: [
          CaIconButton(
              bare: true,
              key: const Key('wizard-exit'),
              icon: CaGlyph.close,
              label: 'wizard_steps.exit_tooltip'.tr(),
              onPressed: _confirmExit)
        ],
      ),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CanopySize.wizardMax),
        child: Padding(
          padding:
              EdgeInsetsDirectional.symmetric(horizontal: context.windowInset),
          child: context.windowClass.index >= WindowClass.expanded.index
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                      width: CanopySize.wizardRail,
                      child: SingleChildScrollView(
                          child: CaCard(
                              child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          stepper,
                          const SizedBox(height: AppTheme.spaceXl),
                          for (var i = 0; i < names.length; i++)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  bottom: AppTheme.spaceLg),
                              child: Text(names[i],
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                          color: i == visualStep
                                              ? Canopy.brandGreen
                                              : Canopy.slate)),
                            ),
                        ],
                      )))),
                  const SizedBox(width: AppTheme.spaceXl),
                  Expanded(child: Column(children: [pages, footer])),
                ])
              : Column(children: [
                  Padding(
                      padding: const EdgeInsetsDirectional.only(
                          bottom: AppTheme.spaceLg),
                      child: stepper),
                  pages,
                  footer,
                ]),
        ),
      ))),
    );
  }
}
