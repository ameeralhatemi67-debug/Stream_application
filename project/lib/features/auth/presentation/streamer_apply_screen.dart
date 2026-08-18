import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/app_provider.dart';
import '../../admin/models/broadcaster_application_model.dart';
import 'steps/apply_step_1_identity.dart';
import 'steps/apply_step_2_media.dart';
import 'steps/apply_step_3_professional.dart';
import 'steps/apply_step_3_5_org_speakers.dart';
import 'steps/apply_step_4_location.dart';
import 'steps/apply_step_5_review.dart';

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
  final List<String> _selectedTags = ['#AI', '#Software'];

  // Step 3.5 Organization Speakers
  final List<OrgApplicationSpeaker> _orgSpeakers = [];

  // Step 4 Controllers
  String _selectedCity = 'khobar';
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _preferredContact = 'whatsapp';
  LatLng _selectedCoordinates = const LatLng(26.2172, 50.1971);
  final List<OrgBranchVenue> _orgBranches = [];

  // Step 5 Terms
  bool _agreedToTerms = false;

  int get _totalSteps => _isOrganization ? 6 : 5;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    if (provider.googleUserName != null && provider.googleUserName!.isNotEmpty) {
      _nameController.text = provider.googleUserName!;
    }
    if (provider.googleUserAvatar != null && provider.googleUserAvatar!.isNotEmpty) {
      _avatarPath = provider.googleUserAvatar;
    }
  }

  @override
  void dispose() {
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
      if (_youtubeController.text.trim().isEmpty) {
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
      if (!validYt) {
        _showValidationToast('wizard_steps.step3_yt_invalid'.tr());
        return false;
      }
      if (_selectedCategories.isEmpty) {
        _showValidationToast('wizard_steps.step3_categories_title'.tr(args: ['0']));
        return false;
      }
    } else if (_isOrganization && _currentStep == 3) {
      // Step 3.5 Org Speakers (Optional to have multiple, but must not be broken)
    } else if ((!_isOrganization && _currentStep == 3) || (_isOrganization && _currentStep == 4)) {
      // Location & Phone Validation
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
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/role-select');
    }
  }

  void _showValidationToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accentRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitApplication() async {
    if (!_agreedToTerms) {
      _showValidationToast('You must agree to the Terms & Conditions before submitting.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final provider = context.read<AppProvider>();
      final email = provider.currentUserEmail ?? 'applicant@streamer.app';

      final app = BroadcasterApplicationModel(
        id: 'app_${DateTime.now().millisecondsSinceEpoch}',
        accountType: _isOrganization
            ? ApplicationAccountType.organizationVenue
            : ApplicationAccountType.individualScholar,
        applicantNameEn: _nameController.text.trim(),
        applicantNameAr: _nameController.text.trim(),
        email: email,
        phone: _phoneController.text.replaceAll(RegExp(r'\s+'), ''),
        academicTitleEn: _isOrganization ? 'Organization Representative' : 'Academic Broadcaster',
        academicTitleAr: _isOrganization ? 'ممثل الجهة الأكاديمية' : 'مقدم برامج تعليمية',
        institutionEn: _affiliationController.text.trim().isNotEmpty
            ? _affiliationController.text.trim()
            : (_isOrganization ? _orgNameController.text.trim() : 'Independent Scholar'),
        institutionAr: _affiliationController.text.trim().isNotEmpty
            ? _affiliationController.text.trim()
            : (_isOrganization ? _orgNameController.text.trim() : 'باحث مستقل'),
        categoryId: _selectedCategories.first,
        tags: _selectedTags,
        organizationType: _isOrganization ? 'Educational Academy' : null,
        venueNameEn: _venueController.text.trim().isNotEmpty
            ? _venueController.text.trim()
            : (_isOrganization ? '${_orgNameController.text} HQ' : 'Al Khobar Educational Center'),
        venueNameAr: _venueController.text.trim().isNotEmpty
            ? _venueController.text.trim()
            : (_isOrganization ? '${_orgNameController.text} المركز الرئيسي' : 'مركز الخبر التعليمي'),
        latitude: _selectedCoordinates.latitude,
        longitude: _selectedCoordinates.longitude,
        seatingCapacity: _isOrganization ? 300 : 120,
        youtubeChannelUrl: _youtubeController.text.trim().startsWith('http')
            ? _youtubeController.text.trim()
            : 'https://www.youtube.com/${_youtubeController.text.trim()}',
        youtubeHandle: _youtubeController.text.trim().startsWith('@')
            ? _youtubeController.text.trim()
            : '@${_youtubeController.text.trim().split('/').last}',
        bioEn: _bioController.text.trim(),
        bioAr: _bioController.text.trim(),
        avatarUrl: _avatarPath ?? 'assets/images/Amir_Alhatemi/amir_person_pic.jpg',
        bannerUrl: _bannerPath ?? 'assets/images/Amir_Alhatemi/amir_card_pic.jpg',
        status: ApplicationStatus.pending,
        submittedAt: DateTime.now(),
      );

      await provider.submitBroadcasterApplication(app);

      if (!mounted) return;
      context.go('/application-pending');
    } catch (e) {
      if (!mounted) return;
      _showValidationToast('Submission error: $e');
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
        selectedTags: _selectedTags,
        onCategoriesChanged: (cats) => setState(() => _selectedCategories = cats),
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
        onContactPrefChanged: (pref) => setState(() => _preferredContact = pref),
        onCoordinatesSelected: (coord) => setState(() => _selectedCoordinates = coord),
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final stepProgress = (_currentStep + 1) / _totalSteps;

    return Scaffold(
      backgroundColor: AppTheme.darkBgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Transform.scale(
            scaleX: context.locale.languageCode == 'ar' ? -1.0 : 1.0,
            child: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimaryDark),
          ),
          onPressed: _previousStep,
        ),
        title: Text(
          _isOrganization
              ? 'wizard_steps.org_title'.tr(args: ['${_currentStep + 1}', '$_totalSteps'])
              : 'wizard_steps.streamer_title'.tr(args: ['${_currentStep + 1}', '$_totalSteps']),
          style: const TextStyle(
            color: AppTheme.textPrimaryDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 780 : 540),
            child: Column(
              children: [
                // Top Progress Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: stepProgress,
                          backgroundColor: AppTheme.darkSurface1,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentRed),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'wizard_steps.step_progress'.tr(args: ['${_currentStep + 1}', '$_totalSteps']),
                            style: const TextStyle(
                              color: AppTheme.textMutedDark,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'wizard_steps.step_completed'.tr(args: ['${(stepProgress * 100).toInt()}']),
                            style: const TextStyle(
                              color: AppTheme.accentRed,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceMd),

                // Wizard PageView
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg),
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (idx) => setState(() => _currentStep = idx),
                      children: _buildStepPages(),
                    ),
                  ),
                ),

                // Bottom Navigation Action Bar
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceLg),
                  decoration: const BoxDecoration(
                    color: AppTheme.darkSurface1,
                    border: Border(top: BorderSide(color: AppTheme.darkBorderSubtle)),
                  ),
                  child: Row(
                    children: [
                      if (_currentStep > 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimaryDark,
                            side: const BorderSide(color: AppTheme.darkBorderSubtle),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          onPressed: _previousStep,
                          child: Text('wizard_steps.btn_back'.tr()),
                        ),
                        const SizedBox(width: AppTheme.spaceMd),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentRed,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            ),
                            elevation: 2,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : (_currentStep == _totalSteps - 1 ? _submitApplication : _nextStep),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _currentStep == _totalSteps - 1
                                          ? 'wizard_steps.btn_submit'.tr()
                                          : 'wizard_steps.btn_next'.tr(),
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    _currentStep == _totalSteps - 1
                                        ? const Icon(Icons.send_rounded, size: 16)
                                        : Transform.scale(
                                            scaleX: context.locale.languageCode == 'ar' ? -1.0 : 1.0,
                                            child: const Icon(Icons.arrow_forward_rounded, size: 16),
                                          ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
