import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/rtmp_publish_engine.dart' show BroadcastQualityPreset;
import '../screens/phone_broadcast_screen.dart';

/// Quick Go-Live Setup Sheet -- opened by the green cell tower icon
/// (broadcaster_profile_screen.dart / live_broadcast_screen.dart), the
/// automated counterpart to the manual "From Phone" tab in
/// RtmpIpSettingsDialog (gray cell tower icon, untouched). Never asks for a
/// Google account or YouTube channel -- the signed-in streamer's identity
/// already lives in AppProvider/UserProfileModel; this sheet only collects
/// what's specific to *this* broadcast (title, category, venue, format,
/// quality) before AppProvider.startQuickPhoneBroadcast automates the rest
/// via YouTubeLiveService.
class QuickGoLiveSheet extends StatefulWidget {
  const QuickGoLiveSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface1,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (_) => const QuickGoLiveSheet(),
    );
  }

  @override
  State<QuickGoLiveSheet> createState() => _QuickGoLiveSheetState();
}

class _QuickGoLiveSheetState extends State<QuickGoLiveSheet> {
  // Same category taxonomy already used by the broadcaster application form
  // (apply_step_3_professional.dart's defaultCategoryOptions) -- kept as its
  // own bilingual copy here since that map lives on a private State class
  // and isn't exported.
  static const Map<String, String> _categoryLabelsEn = {
    'cs_tech': '💻 Computer Science & AI',
    'islamic_studies': '📜 Islamic Studies & Sharia',
    'languages_ielts': '🗣️ Languages & IELTS Academy',
    'engineering_tech': '⚙️ Engineering & Innovation',
    'medical_health': '🩺 Medicine & Clinical Health',
    'general_edu': '🎓 Culture & General Education',
  };
  static const Map<String, String> _categoryLabelsAr = {
    'cs_tech': '💻 علوم الحاسب والذكاء الاصطناعي',
    'islamic_studies': '📜 الدراسات الإسلامية والشرعية',
    'languages_ielts': '🗣️ اللغات وأكاديمية الآيلتس',
    'engineering_tech': '⚙️ الهندسة والابتكار',
    'medical_health': '🩺 الطب والصحة السريرية',
    'general_edu': '🎓 الثقافة والتعليم العام',
  };

  late final TextEditingController _titleController;
  late final TextEditingController _venueController;
  late String _selectedCategory;
  bool _isAudioOnly = false;
  BroadcastQualityPreset _quality = BroadcastQualityPreset.medium;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _titleController = TextEditingController(
      text: provider.customLiveTitle.isNotEmpty
          ? provider.customLiveTitle
          : 'Live Academic Lecture',
    );
    _venueController = TextEditingController(text: provider.customLiveVenue);
    _selectedCategory =
        _categoryLabelsEn.containsKey(provider.customLiveCategory)
            ? provider.customLiveCategory
            : 'cs_tech';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  Future<void> _handleStartBroadcast() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a broadcast title.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = context.read<AppProvider>();
    final quality = _quality;
    final success = await provider.startQuickPhoneBroadcast(
      title: title,
      category: _selectedCategory,
      venue: _venueController.text.trim(),
      isAudioOnly: _isAudioOnly,
      quality: quality,
    );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Couldn't start the YouTube broadcast. Please try again."),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => PhoneBroadcastScreen(quickLaunchPreset: quality),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isAr = context.locale.languageCode == 'ar';
    final categoryLabels = isAr ? _categoryLabelsAr : _categoryLabelsEn;
    final userName = context.select<AppProvider, String>(
        (p) => isAr ? p.userProfile.nameAr : p.userProfile.nameEn);

    // Same shape as the other modal sheets in this codebase (e.g.
    // BroadcasterApplicationSheet): a height-capped Container + Expanded
    // SingleChildScrollView, rather than DraggableScrollableSheet, which
    // needs a sizing context showModalBottomSheet's own Stack provides and
    // otherwise mis-sizes when this widget is pumped directly (e.g. in
    // widget tests).
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        left: AppTheme.spaceLg,
        right: AppTheme.spaceLg,
        top: AppTheme.spaceMd,
        bottom: bottomInset + AppTheme.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHandle(),
          const SizedBox(height: AppTheme.spaceMd),
          _buildHeader(userName),
          const SizedBox(height: AppTheme.spaceLg),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel(
                      isAr ? 'عنوان المحاضرة' : 'Broadcast Title'),
                  const SizedBox(height: AppTheme.spaceSm),
                  _buildTitleField(),
                  const SizedBox(height: AppTheme.spaceLg),
                  _buildSectionLabel(isAr ? 'الفئة' : 'Category'),
                  const SizedBox(height: AppTheme.spaceSm),
                  _buildCategorySelector(categoryLabels),
                  const SizedBox(height: AppTheme.spaceLg),
                  _buildSectionLabel(
                      isAr ? 'القاعة / الموقع' : 'Venue / Auditorium'),
                  const SizedBox(height: AppTheme.spaceSm),
                  _buildVenueField(isAr),
                  const SizedBox(height: AppTheme.spaceLg),
                  _buildSectionLabel(isAr ? 'صيغة البث' : 'Broadcast Format'),
                  const SizedBox(height: AppTheme.spaceSm),
                  _buildFormatSwitch(isAr),
                  const SizedBox(height: AppTheme.spaceLg),
                  _buildSectionLabel(isAr ? 'جودة البث' : 'Quality Preset'),
                  const SizedBox(height: AppTheme.spaceSm),
                  _buildQualityPicker(),
                  const SizedBox(height: AppTheme.spaceXl),
                  _buildSubmitButton(isAr),
                  const SizedBox(height: AppTheme.spaceMd),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.darkBorderSubtle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(String userName) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accentGreen.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cell_tower_rounded,
              color: AppTheme.accentGreen, size: 24),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quick Go-Live Setup',
                style: TextStyle(
                  color: AppTheme.textPrimaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Streaming as $userName',
                style: const TextStyle(
                  color: AppTheme.textSecondaryDark,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'e.g. AI & Machine Learning Lecture',
        hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 12),
        prefixIcon: const Icon(Icons.title_rounded,
            color: AppTheme.accentGreen, size: 20),
        filled: true,
        fillColor: AppTheme.darkSurface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
      ),
    );
  }

  Widget _buildCategorySelector(Map<String, String> categoryLabels) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categoryLabels.entries.map((entry) {
        final isSelected = _selectedCategory == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          selectedColor: AppTheme.accentGreen.withValues(alpha: 0.2),
          backgroundColor: AppTheme.darkSurface2,
          labelStyle: TextStyle(
            color:
                isSelected ? AppTheme.accentGreen : AppTheme.textSecondaryDark,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(
            color:
                isSelected ? AppTheme.accentGreen : AppTheme.darkBorderSubtle,
          ),
          onSelected: (_) => setState(() => _selectedCategory = entry.key),
        );
      }).toList(),
    );
  }

  Widget _buildVenueField(bool isAr) {
    return TextField(
      controller: _venueController,
      style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: isAr ? 'مثال: مدرج القسم 21' : 'e.g. KFUPM Auditorium 21',
        hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 12),
        prefixIcon: const Icon(Icons.location_pin,
            color: AppTheme.accentGreen, size: 20),
        filled: true,
        fillColor: AppTheme.darkSurface2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
      ),
    );
  }

  Widget _buildFormatSwitch(bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMd, vertical: AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            _isAudioOnly ? Icons.mic_rounded : Icons.videocam_rounded,
            color: AppTheme.accentGreen,
            size: 20,
          ),
          const SizedBox(width: AppTheme.spaceMd),
          Expanded(
            child: Text(
              _isAudioOnly
                  ? (isAr
                      ? 'صوتي فقط (وضع البودكاست)'
                      : 'Audio-Only (Podcast Mode)')
                  : (isAr ? 'كاميرا + صوت' : 'Camera Video + Audio'),
              style: const TextStyle(
                color: AppTheme.textPrimaryDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(
            value: _isAudioOnly,
            activeThumbColor: AppTheme.accentGreen,
            onChanged: (val) => setState(() => _isAudioOnly = val),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityPicker() {
    return Row(
      children: BroadcastQualityPreset.values.map((preset) {
        final isSelected = _quality == preset;
        final shortLabel = switch (preset) {
          BroadcastQualityPreset.low => '480p',
          BroadcastQualityPreset.medium => '720p',
          BroadcastQualityPreset.high => '1080p',
        };
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: preset == BroadcastQualityPreset.high ? 0 : 8,
            ),
            child: InkWell(
              onTap: () => setState(() => _quality = preset),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentGreen.withValues(alpha: 0.15)
                      : AppTheme.darkSurface2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentGreen
                        : AppTheme.darkBorderSubtle,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      shortLabel,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentGreen
                            : AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset == BroadcastQualityPreset.medium
                          ? 'Recommended'
                          : preset == BroadcastQualityPreset.low
                              ? 'Weak upload'
                              : 'Strong Wi-Fi',
                      style: const TextStyle(
                        color: AppTheme.textMutedDark,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSubmitButton(bool isAr) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _handleStartBroadcast,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.sensors_rounded),
        label: Text(
          _isSubmitting
              ? (isAr ? 'جارٍ التجهيز...' : 'Setting up...')
              : (isAr
                  ? 'بدء البث وفتح الكاميرا'
                  : 'Start Broadcast & Open Camera'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accentGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        ),
      ),
    );
  }
}
