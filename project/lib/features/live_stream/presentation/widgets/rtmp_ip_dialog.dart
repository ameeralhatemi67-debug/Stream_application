import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_toast_overlay.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/stream_privacy_models.dart';
import '../../services/rtmp_publish_engine.dart' show BroadcastQualityPreset;
import '../screens/phone_broadcast_screen.dart';
import 'streamer_setup_guide_modal.dart';

enum StudioMode { obs, phone, local }

enum _PosterChoice { defaultVisualizer, custom }

/// 70% glassmorphic Broadcaster Studio bottom sheet -- the single unified
/// go-live entry point (v0.9 redesign). Replaces the old RtmpIpSettingsDialog
/// (three-tab AlertDialog behind a gray cell tower icon) and QuickGoLiveSheet
/// (a second, separate sheet behind a green cell tower icon): both are now
/// one sheet with three modes (OBS / Phone / Local RTMP) behind one icon.
///
/// Root-cause fix for the phone-stream bug (see
/// doc/Roadmap/Go_Live_Studio_BottomSheet_Redesign_Plan.md): QuickGoLiveSheet
/// used to drive the phone camera off a *simulated* YouTubeLiveService
/// stream key ("sim-key-xxxx"), which YouTube's real RTMP ingest rejects
/// instantly and tears the camera/mic pipeline down. Phone mode below always
/// uses the same real, user-supplied stream key
/// (AppProvider.phoneBroadcastStreamKey/phoneBroadcastRtmpUrl) that OBS mode
/// displays -- there is exactly one source of truth for "the" stream key
/// now, and it is never auto-generated.
class LiveBroadcasterStudioSheet extends StatefulWidget {
  const LiveBroadcasterStudioSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (sheetContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(sheetContext).pop(),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: const ColoredBox(color: Colors.transparent),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.bottomCenter,
              child: LiveBroadcasterStudioSheet(),
            ),
          ],
        );
      },
    );
  }

  @override
  State<LiveBroadcasterStudioSheet> createState() =>
      _LiveBroadcasterStudioSheetState();
}

class _LiveBroadcasterStudioSheetState
    extends State<LiveBroadcasterStudioSheet> {
  // Same category taxonomy the old QuickGoLiveSheet used (itself mirroring
  // apply_step_3_professional.dart's defaultCategoryOptions) -- kept as its
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

  static const List<String> _presetIps = [
    '127.0.0.1',
    '192.168.1.100',
    '192.168.0.105',
    '10.0.0.5',
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _streamKeyController;
  late final TextEditingController _ingestUrlController;
  late final TextEditingController _youtubeUrlController;
  late final TextEditingController _ipController;

  StudioMode _mode = StudioMode.obs;
  String _selectedCategory = 'cs_tech';
  bool _isAudioOnly = false;
  BroadcastQualityPreset _quality = BroadcastQualityPreset.medium;
  bool _streamKeyVisible = false;
  bool _isSubmitting = false;
  _PosterChoice _posterChoice = _PosterChoice.defaultVisualizer;
  String? _posterPath;

  bool _isPrivate = false;
  final List<String> _whitelistHandles = [];
  bool _requireKnockApproval = true;
  late final TextEditingController _whitelistInputController;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _titleController = TextEditingController(text: provider.customLiveTitle);
    _descriptionController =
        TextEditingController(text: provider.customLiveDescription);
    _streamKeyController =
        TextEditingController(text: provider.phoneBroadcastStreamKey);
    _ingestUrlController =
        TextEditingController(text: provider.phoneBroadcastRtmpUrl);
    _youtubeUrlController = TextEditingController(
      text: provider.customYouTubeLiveUrl.isNotEmpty
          ? provider.customYouTubeLiveUrl
          : provider.customYouTubeVideoId,
    );
    _ipController = TextEditingController(text: provider.rtmpLaptopIp);
    _selectedCategory =
        _categoryLabelsEn.containsKey(provider.customLiveCategory)
            ? provider.customLiveCategory
            : 'cs_tech';
    _isAudioOnly = provider.customBroadcastType == BroadcastType.liveAudio;
    final posterPath = provider.customAudioOnlyPosterPath;
    if (posterPath != null && posterPath.isNotEmpty) {
      _posterChoice = _PosterChoice.custom;
      _posterPath = posterPath;
    }
    _isPrivate = provider.streamVisibility == StreamVisibility.private;
    _whitelistHandles.addAll(provider.streamWhitelistHandles);
    _requireKnockApproval = provider.requireKnockApproval;
    _whitelistInputController = TextEditingController();
    for (final c in [
      _titleController,
      _streamKeyController,
      _ingestUrlController,
      _ipController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _streamKeyController,
      _ingestUrlController,
      _ipController,
    ]) {
      c.removeListener(_onFieldChanged);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _streamKeyController.dispose();
    _ingestUrlController.dispose();
    _youtubeUrlController.dispose();
    _ipController.dispose();
    _whitelistInputController.dispose();
    super.dispose();
  }

  // V2: unified system coral pink accent (matching the Discovery tab icon Color(0xFFFF8080))
  Color get _modeColor => AppTheme.accentRed;

  void _selectMode(StudioMode mode) {
    if (mode == _mode) return;
    HapticFeedback.selectionClick();
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: screenHeight * 0.80,
          padding: EdgeInsets.only(
            left: AppTheme.spaceLg,
            right: AppTheme.spaceLg,
            top: AppTheme.spaceMd,
            bottom: bottomInset > 0 ? bottomInset + AppTheme.spaceMd : AppTheme.spaceLg,
          ),
          // V2: no outer border stroke -- the sheet sits cleanly against the
          // blurred backdrop with just its borderless rounded-top edge.
          decoration: BoxDecoration(
            color: AppTheme.darkSurface1.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHandle(),
              const SizedBox(height: AppTheme.spaceMd),
              _buildHeader(isAr),
              const SizedBox(height: AppTheme.spaceLg),
              _buildModePill(isAr),
              const SizedBox(height: AppTheme.spaceMd),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildMiddleCard(isAr),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _buildBottomRow(isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.darkBorderHighlight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAr) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _modeColor.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.cell_tower_rounded, color: _modeColor, size: 24),
        ),
        const SizedBox(width: AppTheme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'live_studio.director_title'.tr(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'live_studio.director_subtitle'.tr(),
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

  Widget _buildModePill(bool isAr) {
    final index = StudioMode.values.indexOf(_mode);
    final effectiveIndex = isAr ? (StudioMode.values.length - 1 - index) : index;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 3;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutBack,
                left: effectiveIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _modeColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(color: _modeColor, width: 1.4),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _pillTab(StudioMode.obs, Icons.laptop_mac_rounded, 'OBS'),
                  ),
                  Expanded(
                    child: _pillTab(
                      StudioMode.phone,
                      Icons.smartphone_rounded,
                      isAr ? 'الجوال' : 'Phone',
                    ),
                  ),
                  Expanded(
                    child: _pillTab(
                      StudioMode.local,
                      Icons.bolt_rounded,
                      isAr ? 'محلي' : 'Local',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pillTab(StudioMode mode, IconData icon, String label) {
    final selected = _mode == mode;
    return InkWell(
      onTap: () => _selectMode(mode),
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? _modeColor : AppTheme.textSecondaryDark,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondaryDark,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiddleCard(bool isAr) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Container(
          key: ValueKey(_mode),
          child: switch (_mode) {
            StudioMode.obs => _buildObsFields(isAr),
            StudioMode.phone => _buildPhoneFields(isAr),
            StudioMode.local => _buildLocalFields(isAr),
          },
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _titleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'e.g. AI & Machine Learning Lecture',
        hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 12),
        prefixIcon: Icon(Icons.title_rounded, color: _modeColor, size: 20),
        filled: true,
        fillColor: AppTheme.darkSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
      ),
    );
  }

  Widget _descriptionField(bool isAr) {
    return TextField(
      controller: _descriptionController,
      minLines: 2,
      maxLines: 4,
      style: const TextStyle(color: AppTheme.textPrimaryDark, fontSize: 13),
      decoration: InputDecoration(
        hintText: isAr
            ? 'وصف موجز للمحاضرة يظهر للمشاهدين...'
            : 'A short summary viewers will see...',
        hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 12),
        filled: true,
        fillColor: AppTheme.darkSurface2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
        ),
      ),
    );
  }

  Widget _categoryChips(bool isAr) {
    final labels = isAr ? _categoryLabelsAr : _categoryLabelsEn;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.entries.map((entry) {
        final isSelected = _selectedCategory == entry.key;
        return ChoiceChip(
          label: Text(entry.value),
          selected: isSelected,
          selectedColor: _modeColor.withValues(alpha: 0.2),
          backgroundColor: AppTheme.darkSurface2,
          labelStyle: TextStyle(
            color: isSelected ? _modeColor : AppTheme.textSecondaryDark,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? _modeColor : AppTheme.darkBorderSubtle,
          ),
          onSelected: (_) => setState(() => _selectedCategory = entry.key),
        );
      }).toList(),
    );
  }

  /// Opens the gamified "Streamer Academy" multi-step guide for whichever
  /// mode is currently selected. "Paste Key from Clipboard" inside the
  /// guide writes straight back into this sheet's own stream key field
  /// (the single source of truth Phone mode submits -- see the class doc's
  /// root-cause note), not into AppProvider directly, so the field the
  /// streamer sees here updates immediately once the guide closes.
  Widget _infoButton() {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded, color: AppTheme.accentPink, size: 20),
      tooltip: 'live_studio.setup_guide_tooltip'.tr(),
      onPressed: () => StreamerSetupGuideModal.show(
        context,
        mode: _mode,
        onStreamKeyPasted: (key) {
          setState(() => _streamKeyController.text = key);
        },
      ),
      constraints: const BoxConstraints(),
      padding: EdgeInsets.zero,
    );
  }

  // ---------------------------------------------------------------------
  // OBS mode
  // ---------------------------------------------------------------------

  Widget _buildObsFields(bool isAr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(isAr ? 'عنوان البث' : 'Broadcast Title'),
        const SizedBox(height: AppTheme.spaceSm),
        _titleField(),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel(isAr ? 'وصف البث' : 'Broadcast Description'),
        const SizedBox(height: AppTheme.spaceSm),
        _descriptionField(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel(isAr ? 'الفئة' : 'Category'),
        const SizedBox(height: AppTheme.spaceSm),
        _categoryChips(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(child: _sectionLabel(isAr ? 'رابط يوتيوب لايف' : 'YouTube Live Link')),
            _infoButton(),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        TextField(
          controller: _youtubeUrlController,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'https://youtube.com/watch?v=... or Video ID',
            hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
            prefixIcon: Icon(Icons.link_rounded, color: _modeColor, size: 18),
            filled: true,
            fillColor: AppTheme.darkSurface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _buildAutoDetectButton(),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel(isAr ? 'مفتاح البث' : 'Stream Key'),
        const SizedBox(height: AppTheme.spaceSm),
        _readOnlyKeyBox(),
        const SizedBox(height: AppTheme.spaceSm),
        _sectionLabel(isAr ? 'عنوان خادم الإرسال' : 'Ingest Server URL'),
        const SizedBox(height: AppTheme.spaceSm),
        _ingestUrlPreview(),
        const SizedBox(height: AppTheme.spaceMd),
        _buildAudioPosterSection(isAr),
        _buildStreamAccessSection(isAr),
      ],
    );
  }

  Widget _buildAutoDetectButton() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: provider.isDetectingAmirLiveVideo
                ? null
                : () async {
                    final found = await provider.autoDetectAmirLiveVideo();
                    if (!context.mounted) return;
                    if (found) {
                      _youtubeUrlController.text = provider.customYouTubeLiveUrl;
                      InteractiveToastOverlay.show(
                        context,
                        title: 'Live Broadcast Detected',
                        message: 'Active Video ID: ${provider.customYouTubeVideoId}',
                        icon: Icons.sensors_rounded,
                        accentColor: AppTheme.accentGreen,
                      );
                    } else {
                      InteractiveToastOverlay.show(
                        context,
                        title: 'Broadcast Detection Failed',
                        message: provider.amirAutoDetectError ??
                            'Could not detect an active live video on YouTube.',
                        icon: Icons.error_outline_rounded,
                        accentColor: AppTheme.accentRed,
                      );
                    }
                  },
            icon: provider.isDetectingAmirLiveVideo
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _modeColor),
                  )
                : Icon(Icons.sensors_rounded, size: 16, color: _modeColor),
            label: Text(
              provider.isDetectingAmirLiveVideo ? 'Detecting...' : 'Auto-Detect Live Video',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: _modeColor,
              side: BorderSide(color: _modeColor),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        );
      },
    );
  }

  Widget _readOnlyKeyBox() {
    final key = _streamKeyController.text;
    final masked = key.isEmpty ? '' : '•' * key.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.darkBorderSubtle),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, color: _modeColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              key.isEmpty
                  ? 'Not set -- add it in Phone mode'
                  : (_streamKeyVisible ? key : masked),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              _streamKeyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 16,
              color: AppTheme.textMutedDark,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: key.isEmpty
                ? null
                : () => setState(() => _streamKeyVisible = !_streamKeyVisible),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMutedDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: key.isEmpty
                ? null
                : () {
                    Clipboard.setData(ClipboardData(text: key));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Stream key copied to clipboard')),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _ingestUrlPreview() {
    final url = _ingestUrlController.text.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.darkBgBase,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: _modeColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.link_rounded, color: _modeColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              url.isEmpty ? 'rtmp://a.rtmp.youtube.com/live2' : url,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMutedDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ingest URL copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Phone mode
  // ---------------------------------------------------------------------

  Widget _buildPhoneFields(bool isAr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(isAr ? 'عنوان البث' : 'Broadcast Title'),
        const SizedBox(height: AppTheme.spaceSm),
        _titleField(),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel(isAr ? 'وصف البث' : 'Broadcast Description'),
        const SizedBox(height: AppTheme.spaceSm),
        _descriptionField(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel(isAr ? 'الفئة' : 'Category'),
        const SizedBox(height: AppTheme.spaceSm),
        _categoryChips(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(child: _sectionLabel(isAr ? 'مفتاح بث يوتيوب' : 'YouTube Stream Key')),
            _infoButton(),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        TextField(
          controller: _streamKeyController,
          obscureText: !_streamKeyVisible,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'xxxx-xxxx-xxxx-xxxx-xxxx',
            hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
            prefixIcon: Icon(Icons.key_rounded, color: _modeColor, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _streamKeyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppTheme.textMutedDark,
                size: 18,
              ),
              onPressed: () => setState(() => _streamKeyVisible = !_streamKeyVisible),
            ),
            filled: true,
            fillColor: AppTheme.darkSurface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel(isAr ? 'جودة البث' : 'Quality Preset'),
        const SizedBox(height: AppTheme.spaceSm),
        _buildQualityPicker(),
        const SizedBox(height: AppTheme.spaceMd),
        _buildAudioPosterSection(isAr),
        _buildStreamAccessSection(isAr),
      ],
    );
  }

  Widget _buildQualityPicker() {
    return Row(
      children: BroadcastQualityPreset.values.map((preset) {
        final isSelected = _quality == preset;
        final (shortLabel, bandwidth) = switch (preset) {
          BroadcastQualityPreset.low => ('480p', '~1.2 Mbps'),
          BroadcastQualityPreset.medium => ('720p', '~2.5 Mbps'),
          BroadcastQualityPreset.high => ('1080p', '~4.5 Mbps'),
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _modeColor.withValues(alpha: 0.15) : AppTheme.darkSurface2,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isSelected ? _modeColor : AppTheme.darkBorderSubtle,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      shortLabel,
                      style: TextStyle(
                        color: isSelected ? _modeColor : AppTheme.textPrimaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bandwidth,
                      style: const TextStyle(color: AppTheme.textMutedDark, fontSize: 9.5),
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

  // ---------------------------------------------------------------------
  // Local RTMP mode
  // ---------------------------------------------------------------------

  Widget _buildLocalFields(bool isAr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionLabel(isAr ? 'عنوان جهاز الحاسوب المحلي' : 'Laptop Local IP Address')),
            _infoButton(),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        TextField(
          controller: _ipController,
          keyboardType: TextInputType.url,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'e.g. 192.168.1.100',
            hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
            prefixIcon: Icon(Icons.laptop_rounded, color: _modeColor, size: 18),
            filled: true,
            fillColor: AppTheme.darkSurface2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _presetIps.map((ip) {
            final isSelected = _ipController.text.trim() == ip;
            return ChoiceChip(
              label: Text(ip),
              selected: isSelected,
              selectedColor: _modeColor.withValues(alpha: 0.25),
              backgroundColor: AppTheme.darkSurface2,
              side: BorderSide(color: isSelected ? _modeColor : AppTheme.darkBorderSubtle),
              labelStyle: TextStyle(
                color: isSelected ? _modeColor : AppTheme.textSecondaryDark,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (selected) {
                if (selected) setState(() => _ipController.text = ip);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _sectionLabel(isAr ? 'معاينة رابط البث' : 'Stream URL Preview'),
        const SizedBox(height: AppTheme.spaceSm),
        Container(
          padding: const EdgeInsets.all(AppTheme.spaceSm),
          decoration: BoxDecoration(
            color: AppTheme.darkBgBase,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: _modeColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.link_rounded, color: _modeColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'rtmp://${_ipController.text.trim().isEmpty ? "..." : _ipController.text.trim()}/live/demo',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textMutedDark),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  Clipboard.setData(ClipboardData(
                    text: 'rtmp://${_ipController.text.trim()}/live/demo',
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('RTMP URL copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ),
        _buildStreamAccessSection(isAr),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Audio-only unfolding poster option
  // ---------------------------------------------------------------------

  Widget _buildAudioPosterSection(bool isAr) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: _isAudioOnly
          ? Container(
              margin: const EdgeInsets.only(top: AppTheme.spaceSm),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.darkSurface2,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: _modeColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr ? '🎙️ خلفية الوضع الصوتي فقط' : '🎙️ Audio-Only Backdrop',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  Row(
                    children: [
                      Expanded(
                        child: _posterOption(
                          icon: Icons.graphic_eq_rounded,
                          label: isAr ? 'الافتراضي' : 'Default',
                          selected: _posterChoice == _PosterChoice.defaultVisualizer,
                          onTap: () => setState(() {
                            _posterChoice = _PosterChoice.defaultVisualizer;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _posterOption(
                          icon: Icons.image_rounded,
                          label: isAr ? 'ملصق مخصص' : 'Custom Poster',
                          selected: _posterChoice == _PosterChoice.custom,
                          onTap: _pickPoster,
                        ),
                      ),
                    ],
                  ),
                  if (_posterChoice == _PosterChoice.custom && _posterPath != null) ...[
                    const SizedBox(height: AppTheme.spaceSm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      child: Image(
                        image: buildSafeImageProvider(path: _posterPath),
                        height: 90,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _posterOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _modeColor.withValues(alpha: 0.15) : AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: selected ? _modeColor : AppTheme.darkBorderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: selected ? _modeColor : AppTheme.textMutedDark),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppTheme.textSecondaryDark,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPoster() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image == null || !mounted) return;
      setState(() {
        _posterChoice = _PosterChoice.custom;
        _posterPath = image.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not read image: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Private & Restricted Streaming: Public/Private access selector
  // ---------------------------------------------------------------------

  Widget _buildStreamAccessSection(bool isAr) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spaceMd),
          _sectionLabel(isAr ? 'الوصول للبث' : 'Stream Access'),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: _accessPill(
                  label: isAr ? '🌐 عام' : '🌐 Public',
                  selected: !_isPrivate,
                  onTap: () => setState(() => _isPrivate = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accessPill(
                  label: isAr ? '🔒 خاص' : '🔒 Private',
                  selected: _isPrivate,
                  onTap: () => setState(() => _isPrivate = true),
                ),
              ),
            ],
          ),
          if (_isPrivate) _buildPrivateAccessOptions(isAr),
        ],
      ),
    );
  }

  Widget _accessPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _modeColor.withValues(alpha: 0.15) : AppTheme.darkSurface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? _modeColor : AppTheme.darkBorderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondaryDark,
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateAccessOptions(bool isAr) {
    return Container(
      margin: const EdgeInsets.only(top: AppTheme.spaceSm),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface2,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: _modeColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAr ? 'القائمة المعتمدة مسبقاً (Whitelist)' : 'Pre-Approved Roster (Whitelist)',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _whitelistInputController,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: '@sarah, @khalid',
                    hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.darkSurface1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
                    ),
                  ),
                  onSubmitted: (_) => _addWhitelistHandle(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.add_circle_rounded, color: _modeColor),
                onPressed: _addWhitelistHandle,
              ),
            ],
          ),
          if (_whitelistHandles.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _whitelistHandles.map((handle) {
                return Chip(
                  backgroundColor: AppTheme.darkSurface1,
                  label: Text(
                    handle,
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.accentRed),
                  onDeleted: () => setState(() => _whitelistHandles.remove(handle)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: Text(
                  isAr
                      ? 'طلب موافقة المضيف للضيوف الجدد'
                      : 'Require Host Knock Approval for new guests',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              Switch(
                value: _requireKnockApproval,
                activeThumbColor: _modeColor,
                onChanged: (val) => setState(() => _requireKnockApproval = val),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.ios_share_rounded, size: 16),
              label: Text(isAr ? 'مشاركة رابط الدعوة الخاص' : 'Share Private Invite Link'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _modeColor,
                side: BorderSide(color: _modeColor),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onPressed: _handleSharePrivateInvite,
            ),
          ),
        ],
      ),
    );
  }

  void _addWhitelistHandle() {
    final raw = _whitelistInputController.text.trim();
    if (raw.isEmpty) return;
    final handle = raw.startsWith('@') ? raw : '@$raw';
    setState(() {
      if (!_whitelistHandles.contains(handle)) {
        _whitelistHandles.add(handle);
      }
      _whitelistInputController.clear();
    });
  }

  Future<void> _handleSharePrivateInvite() async {
    final provider = context.read<AppProvider>();
    final link = provider.generatePrivateInviteLink();
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    await Share.share(link, subject: 'Private Stream Invite');
  }

  // ---------------------------------------------------------------------
  // Bottom section: format toggle + morphing CTA
  // ---------------------------------------------------------------------

  Widget _buildBottomRow(bool isAr) {
    return Row(
      children: [
        Expanded(flex: 5, child: _buildFormatToggle(isAr)),
        const SizedBox(width: AppTheme.spaceSm),
        Expanded(flex: 6, child: _buildCtaButton()),
      ],
    );
  }

  Widget _buildFormatToggle(bool isAr) {
    return Row(
      children: [
        Expanded(
          child: _formatOption(
            icon: Icons.videocam_rounded,
            label: isAr ? 'مرئي' : 'Video',
            selected: !_isAudioOnly,
            onTap: () => setState(() => _isAudioOnly = false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _formatOption(
            icon: Icons.mic_rounded,
            label: isAr ? 'صوتي' : 'Audio',
            selected: _isAudioOnly,
            onTap: () => setState(() => _isAudioOnly = true),
            // V2: gentle breathing glow while Audio-Only is the active
            // format, so the CTA morph below isn't the only signal that
            // this choice changes what "going live" does.
            pulsing: _isAudioOnly,
          ),
        ),
      ],
    );
  }

  Widget _formatOption({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool pulsing = false,
  }) {
    final content = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? _modeColor.withValues(alpha: 0.18) : AppTheme.darkSurface2,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: selected ? _modeColor : AppTheme.darkBorderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? _modeColor : AppTheme.textMutedDark),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : AppTheme.textSecondaryDark,
              ),
            ),
          ],
        ),
      ),
    );
    return _PulseGlow(pulsing: pulsing, color: _modeColor, child: content);
  }

  Widget _buildCtaButton() {
    final (label, icon) = switch (_mode) {
      StudioMode.obs => ('Go Live', Icons.sensors_rounded),
      StudioMode.phone => ('Open Camera', Icons.photo_camera_rounded),
      StudioMode.local => ('Stream', Icons.bolt_rounded),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 380),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: SizedBox(
        key: ValueKey(_mode),
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSubmitting ? null : _handleCtaPressed,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8080), Color(0xFFFF5274)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentRed.withValues(alpha: 0.38),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSubmitting)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else
                    Icon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleCtaPressed() async {
    switch (_mode) {
      case StudioMode.obs:
        await _handleObsGoLive();
        break;
      case StudioMode.phone:
        _handlePhoneOpenCamera();
        break;
      case StudioMode.local:
        _handleLocalStream();
        break;
    }
  }

  void _persistSharedMeta(AppProvider provider) {
    provider.setCustomBroadcastMeta(
      title: _titleController.text.trim().isEmpty
          ? provider.customLiveTitle
          : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
    );
    provider.setBroadcastType(
      _isAudioOnly ? BroadcastType.liveAudio : BroadcastType.liveVideo,
    );
    provider.setCustomAudioOnlyPosterPath(
      _posterChoice == _PosterChoice.custom ? _posterPath : null,
    );
    provider.configureStreamPrivacy(
      visibility: _isPrivate ? StreamVisibility.private : StreamVisibility.public,
      whitelistHandles: _whitelistHandles,
      requireKnockApproval: _requireKnockApproval,
    );
  }

  Future<void> _handleObsGoLive() async {
    final provider = context.read<AppProvider>();
    setState(() => _isSubmitting = true);

    _persistSharedMeta(provider);

    final rawYoutube = _youtubeUrlController.text.trim();
    if (rawYoutube.isNotEmpty) {
      provider.setCustomStreamerYouTubeUrl(rawYoutube);
    }
    provider.updatePhoneBroadcastTarget(
      rtmpUrl: _ingestUrlController.text.trim().isEmpty
          ? provider.phoneBroadcastRtmpUrl
          : _ingestUrlController.text.trim(),
      streamKey: _streamKeyController.text.trim(),
    );

    if (!provider.isBroadcastingLive) {
      await provider.toggleBroadcasterGoLive(context);
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.of(context).pop();

    final videoId = AppProvider.extractYouTubeId(rawYoutube.isEmpty ? provider.customYouTubeLiveUrl : rawYoutube);
    InteractiveToastOverlay.show(
      context,
      title: 'YouTube Live Target Updated',
      message: 'Active Video ID: $videoId',
      icon: Icons.sensors_rounded,
      accentColor: _modeColor,
    );
  }

  void _handlePhoneOpenCamera() {
    final provider = context.read<AppProvider>();
    final streamKey = _streamKeyController.text.trim();

    if (streamKey.isEmpty) {
      InteractiveToastOverlay.show(
        context,
        title: 'Stream Key Required',
        message: "Paste the stream key from YouTube Studio's Go Live > Stream tab.",
        icon: Icons.error_outline_rounded,
        accentColor: AppTheme.accentRed,
      );
      return;
    }

    _persistSharedMeta(provider);
    provider.updatePhoneBroadcastTarget(
      rtmpUrl: _ingestUrlController.text.trim().isEmpty
          ? provider.phoneBroadcastRtmpUrl
          : _ingestUrlController.text.trim(),
      streamKey: streamKey,
    );

    Navigator.of(context).pop();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhoneBroadcastScreen(quickLaunchPreset: _quality),
      ),
    );
  }

  void _handleLocalStream() {
    final provider = context.read<AppProvider>();
    final rawIp = _ipController.text.trim();

    if (rawIp.isEmpty) {
      InteractiveToastOverlay.show(
        context,
        title: 'Laptop IP Required',
        message: "Enter your laptop's local network IP address to continue.",
        icon: Icons.error_outline_rounded,
        accentColor: AppTheme.accentRed,
      );
      return;
    }

    provider.updateRtmpLaptopIp(rawIp);
    provider.configureStreamPrivacy(
      visibility: _isPrivate ? StreamVisibility.private : StreamVisibility.public,
      whitelistHandles: _whitelistHandles,
      requireKnockApproval: _requireKnockApproval,
    );
    Navigator.of(context).pop();

    InteractiveToastOverlay.show(
      context,
      title: 'Local RTMP Target Updated',
      message: 'rtmp://${provider.rtmpLaptopIp}/live/demo',
      icon: Icons.cell_tower_rounded,
      accentColor: _modeColor,
    );
  }
}

/// Breathing pulse/glow (scale 1.0 -> 1.05, opacity ramp) wrapped around the
/// Audio-Only format toggle while it's the active selection (V2). The
/// AnimationController only ever repeats while [pulsing] is true -- started
/// in initState/didUpdateWidget and stopped the instant it flips back to
/// false -- so a widget test that never selects Audio-Only never has an
/// infinitely-repeating animation in the tree (an earlier always-on pulse on
/// the header icon made every `pumpAndSettle()` in this sheet's tests time
/// out; see the v0.9 test suite history).
class _PulseGlow extends StatefulWidget {
  final bool pulsing;
  final Color color;
  final Widget child;

  const _PulseGlow({
    required this.pulsing,
    required this.color,
    required this.child,
  });

  @override
  State<_PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<_PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulseGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !oldWidget.pulsing) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing && oldWidget.pulsing) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulsing) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final scale = 1.0 + (t * 0.05);
        final glowOpacity = 0.25 + (t * 0.35);
        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: glowOpacity),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

