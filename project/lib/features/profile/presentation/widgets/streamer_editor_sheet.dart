import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:top_snackbar_flutter/top_snack_bar.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/app_provider.dart';
import '../../models/streamer_models.dart';

class StreamerEditorSheet extends StatefulWidget {
  final StreamerModel? existingStreamer;

  const StreamerEditorSheet({
    super.key,
    this.existingStreamer,
  });

  static void show(BuildContext context, {StreamerModel? streamer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (context) => StreamerEditorSheet(existingStreamer: streamer),
    );
  }

  @override
  State<StreamerEditorSheet> createState() => _StreamerEditorSheetState();
}

class _StreamerEditorSheetState extends State<StreamerEditorSheet> {
  final _scrollController = ScrollController();

  // Field GlobalKeys for Auto-Scrolling to Unfilled Required Fields
  final _nameKey = GlobalKey();
  final _titleKey = GlobalKey();
  final _cityKey = GlobalKey();
  final _venueKey = GlobalKey();
  final _tagsKey = GlobalKey();
  final _youtubeKey = GlobalKey();

  late final TextEditingController _nameEnController;
  late final TextEditingController _nameArController;
  late final TextEditingController _titleEnController;
  late final TextEditingController _titleArController;
  late final TextEditingController _orgController;
  late final TextEditingController _bioController;
  late final TextEditingController _avatarUrlController;
  late final TextEditingController _bannerUrlController;
  late final TextEditingController _venueController;
  late final TextEditingController _tagsController;
  late final TextEditingController _youtubeController;
  late final TextEditingController _streamKeyController;

  String _selectedCity = 'Al Khobar';
  String _selectedCategory = 'computer_science';

  static const List<String> supportedCities = ['Al Khobar', 'Dhahran', 'Dammam'];

  @override
  void initState() {
    super.initState();
    final s = widget.existingStreamer;
    _nameEnController = TextEditingController(text: s?.fullNameEn ?? '');
    _nameArController = TextEditingController(text: s?.fullNameAr ?? '');
    _titleEnController = TextEditingController(text: s?.titleEn ?? '');
    _titleArController = TextEditingController(text: s?.titleAr ?? '');
    _orgController = TextEditingController(text: s?.organizationEn ?? '');
    _bioController = TextEditingController(text: s?.bioEn ?? '');
    _avatarUrlController = TextEditingController(text: s?.avatarUrl ?? '');
    _bannerUrlController = TextEditingController(text: s?.bannerUrl ?? '');
    _venueController = TextEditingController(text: s?.venueNameEn ?? '');
    _tagsController = TextEditingController(text: s?.tags.join(', ') ?? '#AI, #Tech');
    _youtubeController = TextEditingController(text: s?.youtubeHandle ?? '');
    _streamKeyController = TextEditingController();

    if (s != null && supportedCities.contains(s.cityEn)) {
      _selectedCity = s.cityEn;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameEnController.dispose();
    _nameArController.dispose();
    _titleEnController.dispose();
    _titleArController.dispose();
    _orgController.dispose();
    _bioController.dispose();
    _avatarUrlController.dispose();
    _bannerUrlController.dispose();
    _venueController.dispose();
    _tagsController.dispose();
    _youtubeController.dispose();
    _streamKeyController.dispose();
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
            color: AppTheme.darkSurface2,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.accentRed, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.accentRed, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textPrimaryDark,
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
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

  void _submitForm() {
    final name = _nameEnController.text.trim();
    final title = _titleEnController.text.trim();
    final venue = _venueController.text.trim();
    final tagsRaw = _tagsController.text.trim();
    final youtube = _youtubeController.text.trim();

    // Required Field 1: Name
    if (name.isEmpty) {
      _showErrorBanner('${'settings.required_field_missing'.tr()}${'settings.full_name'.tr()} *');
      _scrollToKey(_nameKey);
      return;
    }

    // Required Field 2: Title
    if (title.isEmpty) {
      _showErrorBanner('${'settings.required_field_missing'.tr()}${'settings.academic_title'.tr()} *');
      _scrollToKey(_titleKey);
      return;
    }

    // Required Field 3: Location (City)
    if (!supportedCities.contains(_selectedCity)) {
      _showErrorBanner('settings.location_unsupported'.tr());
      _scrollToKey(_cityKey);
      return;
    }

    // Required Field 4: Venue Name
    if (venue.isEmpty) {
      _showErrorBanner('${'settings.required_field_missing'.tr()}${'settings.venue_label'.tr()} *');
      _scrollToKey(_venueKey);
      return;
    }

    // Required Field 5: Tags (At least 1 tag)
    final parsedTags = tagsRaw
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .map((t) => t.startsWith('#') ? t : '#$t')
        .toList();

    if (parsedTags.isEmpty) {
      _showErrorBanner('settings.tags_required'.tr());
      _scrollToKey(_tagsKey);
      return;
    }

    // Required Field 6: YouTube Account / Handle
    if (youtube.isEmpty) {
      _showErrorBanner('${'settings.required_field_missing'.tr()}${'settings.linked_youtube'.tr()} *');
      _scrollToKey(_youtubeKey);
      return;
    }

    // Default Fallback Placeholders
    // Placeholder Gray Icon Surface for Avatar if empty
    final avatar = _avatarUrlController.text.trim().isNotEmpty
        ? _avatarUrlController.text.trim()
        : 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=200&q=80';

    // Placeholder Geometric/Abstract Background for Banner if empty
    final banner = _bannerUrlController.text.trim().isNotEmpty
        ? _bannerUrlController.text.trim()
        : 'https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=1200&q=80';

    final nameAr = _nameArController.text.trim().isNotEmpty ? _nameArController.text.trim() : name;
    final titleAr = _titleArController.text.trim().isNotEmpty ? _titleArController.text.trim() : title;
    final org = _orgController.text.trim().isNotEmpty ? _orgController.text.trim() : 'Independent Broadcaster';
    final bio = _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : 'Educational Broadcaster in AlSharqia.';

    // Approximate Coordinates for supported Eastern Province cities
    double lat = 26.2871;
    double lng = 50.2125;
    if (_selectedCity == 'Dhahran') {
      lat = 26.3042;
      lng = 50.1462;
    } else if (_selectedCity == 'Dammam') {
      lat = 26.4207;
      lng = 50.0888;
    }

    final provider = context.read<AppProvider>();
    final isEditing = widget.existingStreamer != null;
    final streamerId = widget.existingStreamer?.streamerId ?? 'custom_streamer_${DateTime.now().millisecondsSinceEpoch}';

    final newStreamer = StreamerModel(
      streamerId: streamerId,
      fullNameEn: name,
      fullNameAr: nameAr,
      titleEn: title,
      titleAr: titleAr,
      organizationEn: org,
      organizationAr: org,
      avatarUrl: avatar,
      bannerUrl: banner,
      bioEn: bio,
      bioAr: bio,
      isVerified: true,
      followerCount: widget.existingStreamer?.followerCount ?? 1200,
      categoryId: _selectedCategory,
      tags: parsedTags,
      cityEn: _selectedCity,
      cityAr: _selectedCity == 'Al Khobar' ? 'الخبر' : (_selectedCity == 'Dhahran' ? 'الظهران' : 'الدمام'),
      venueNameEn: venue,
      venueNameAr: venue,
      latitude: lat,
      longitude: lng,
      isCurrentlyLive: false,
      activeViewerCount: 0,
      youtubeHandle: youtube.replaceAll('@', ''),
    );

    if (isEditing) {
      provider.updateStreamer(newStreamer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.streamer_updated'.tr()),
          backgroundColor: AppTheme.accentBlue,
        ),
      );
    } else {
      provider.addStreamer(newStreamer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('settings.streamer_added'.tr()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingStreamer != null;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.90,
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spaceLg,
        right: AppTheme.spaceLg,
        top: AppTheme.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (Fixed)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
                    color: AppTheme.accentRed,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'settings.edit_streamer'.tr() : 'settings.add_streamer'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimaryDark,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textMutedDark),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: AppTheme.darkBorderSubtle),

          // Scrollable Form Body
          Flexible(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'settings.add_streamer_desc'.tr(),
                    style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12),
                  ),
                  const SizedBox(height: 16),

                  // 1. Full Name (Required)
                  _buildSectionHeader('1. ${'settings.full_name'.tr()} *', key: _nameKey),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nameEnController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Dr. Salman Al-Fahad',
                      labelText: 'Full Name (English) *',
                      prefixIcon: Icon(Icons.person_rounded, size: 18, color: AppTheme.accentRed),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameArController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'مثال: د. سلمان الفهد',
                      labelText: 'الاسم الكامل (بالعربي)',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.accentBlue),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Academic Title / Role (Required)
                  _buildSectionHeader('2. ${'settings.academic_title'.tr()} *', key: _titleKey),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleEnController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'e.g. Associate Professor of AI',
                      labelText: 'Academic Title / Role (English) *',
                      prefixIcon: Icon(Icons.school_rounded, size: 18, color: AppTheme.accentRed),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleArController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'مثال: أستاذ مشارك في الذكاء الاصطناعي',
                      labelText: 'المسمى الأكاديمي (بالعربي)',
                      prefixIcon: Icon(Icons.school_outlined, size: 18, color: AppTheme.accentBlue),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Organization (Optional)
                  _buildSectionHeader('3. ${'settings.university_org'.tr()} (Optional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _orgController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. KFUPM / Dhahran Techno Valley',
                      labelText: 'settings.university_org'.tr(),
                      prefixIcon: const Icon(Icons.business_rounded, size: 18, color: AppTheme.textMutedDark),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Description / Bio (Optional)
                  _buildSectionHeader('4. ${'settings.bio_research'.tr()} (Optional)'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bioController,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Brief summary of lectures, topics, or research...',
                      labelText: 'settings.bio_research'.tr(),
                      prefixIcon: const Icon(Icons.description_outlined, size: 18, color: AppTheme.textMutedDark),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Profile Picture (Optional - Default Placeholder if empty)
                  _buildSectionHeader('5. ${'settings.profile_pic_url'.tr()}'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _avatarUrlController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'https://... or assets/images/...',
                      labelText: 'settings.profile_pic_url'.tr(),
                      prefixIcon: const Icon(Icons.account_circle_outlined, size: 18, color: AppTheme.accentBlue),
                      helperText: 'Leave empty for default clean gray avatar placeholder',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 6. Banner Picture (Optional - Default Placeholder if empty)
                  _buildSectionHeader('6. ${'settings.banner_pic_url'.tr()}'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bannerUrlController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'https://... or assets/images/...',
                      labelText: 'settings.banner_pic_url'.tr(),
                      prefixIcon: const Icon(Icons.image_outlined, size: 18, color: AppTheme.accentBlue),
                      helperText: 'Leave empty for default dark abstract background',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 7. Location: City & Venue (Required - Must be Khobar, Dhahran, Dammam)
                  _buildSectionHeader('7. ${'settings.city_label'.tr()} *', key: _cityKey),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    dropdownColor: AppTheme.darkSurface2,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'settings.city_label'.tr(),
                      prefixIcon: const Icon(Icons.location_city_rounded, size: 18, color: AppTheme.accentRed),
                    ),
                    items: supportedCities.map((city) {
                      return DropdownMenuItem<String>(
                        value: city,
                        child: Text(city),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCity = val);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Container(
                    key: _venueKey,
                    child: TextField(
                      controller: _venueController,
                      style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Grand Auditorium Hall / Campus Center',
                        labelText: '${'settings.venue_label'.tr()} *',
                        prefixIcon: const Icon(Icons.pin_drop_rounded, size: 18, color: AppTheme.accentRed),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 8. Tags (Required - At least 1 tag)
                  _buildSectionHeader('8. ${'settings.tags_label'.tr()} *', key: _tagsKey),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _tagsController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '#AI, #MachineLearning, #Cloud',
                      labelText: '${'settings.tags_label'.tr()} *',
                      prefixIcon: const Icon(Icons.tag_rounded, size: 18, color: AppTheme.accentRed),
                      helperText: 'Add at least one tag (comma separated)',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 9. Academic Category
                  _buildSectionHeader('9. Academic Category'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    dropdownColor: AppTheme.darkSurface2,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Academic Category',
                      prefixIcon: Icon(Icons.category_rounded, size: 18, color: AppTheme.accentBlue),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'computer_science', child: Text('Computer Science & AI')),
                      DropdownMenuItem(value: 'islamic_studies', child: Text('Islamic Studies & Sharia')),
                      DropdownMenuItem(value: 'engineering', child: Text('Engineering & Innovation')),
                      DropdownMenuItem(value: 'medicine', child: Text('Medicine & Health')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedCategory = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // 10. YouTube Account / Handle (Required)
                  _buildSectionHeader('10. ${'settings.linked_youtube'.tr()} *', key: _youtubeKey),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _youtubeController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'e.g. ahmedamercaller or full URL',
                      labelText: '${'settings.linked_youtube'.tr()} *',
                      prefixIcon: const Icon(Icons.smart_display_rounded, size: 18, color: AppTheme.accentRed),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 11. Stream Key / RTMP URL (Optional)
                  _buildSectionHeader('11. ${'settings.stream_key'.tr()}'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _streamKeyController,
                    style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'rtmp://... (Optional for testing)',
                      labelText: 'settings.stream_key'.tr(),
                      prefixIcon: const Icon(Icons.key_rounded, size: 18, color: AppTheme.textMutedDark),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Submit Action Button (Fixed at Bottom)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _submitForm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              icon: Icon(isEditing ? Icons.check_circle_rounded : Icons.add_circle_rounded, size: 18),
              label: Text(
                isEditing ? 'settings.save_profile'.tr() : 'settings.add_streamer'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {Key? key}) {
    return Container(
      key: key,
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimaryDark,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
