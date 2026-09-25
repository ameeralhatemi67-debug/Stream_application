import 'dart:ui';
import '../../../../core/config/feature_flags.dart';

import 'package:flutter/foundation.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_toast_overlay.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/stream_privacy_models.dart';
import '../../services/rtmp_publish_engine.dart'
    show BroadcastQualityPreset, BroadcastQualityPresetConfig;
import '../screens/phone_broadcast_screen.dart';
import 'streamer_setup_guide_modal.dart';

enum StudioMode { obs, phone, local }

/// 70% glassmorphic Broadcaster Studio bottom sheet -- the single unified
/// go-live entry point (v0.9 redesign). Replaces the old RtmpIpSettingsDialog
/// (three-tab AlertDialog behind a gray cell tower icon) and QuickGoLiveSheet
/// (a second, separate sheet behind a green cell tower icon): both are now
/// one sheet with three modes (Encoder / Phone / Local, which is
/// unavailable) behind one icon.
///
/// Root-cause fix for the phone-stream bug (see
/// doc/Roadmap/Go_Live_Studio_BottomSheet_Redesign_Plan.md): QuickGoLiveSheet
/// used to drive the phone camera off a *simulated* YouTubeLiveService
/// stream key ("sim-key-xxxx"), which YouTube's real RTMP ingest rejects
/// instantly and tears the camera/mic pipeline down. Phone mode below always
/// uses the same real, user-supplied stream key
/// (AppProvider.phoneBroadcastStreamKey/phoneBroadcastRtmpUrl) that OBS mode
/// displays -- there is exactly one source of truth for "the"stream key
/// now, and it is never auto-generated.
class LiveBroadcasterStudioSheet extends StatefulWidget {
  /// Test-only: lets a widget test (e.g. rendered_contrast_test.dart) render
  /// the sheet already on the Phone or Local tab instead of only ever being
  /// able to exercise the OBS default. Production always uses the default
  /// (OBS), matching the real entry point's behaviour before this existed.
  @visibleForTesting
  final StudioMode initialMode;

  /// Set when the studio is opened from the phone broadcast screen: End
  /// goes through that screen, which stops its encoder and leaves.
  final Future<void> Function()? onEndBroadcast;

  const LiveBroadcasterStudioSheet({
    super.key,
    @visibleForTesting this.initialMode = StudioMode.obs,
    this.onEndBroadcast,
  });

  static Future<void> show(BuildContext context,
      {Future<void> Function()? onEndBroadcast}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppTheme.media.withValues(alpha: 0.6),
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
            Align(
              alignment: Alignment.bottomCenter,
              child: LiveBroadcasterStudioSheet(onEndBroadcast: onEndBroadcast),
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
    'cs_tech': 'Computer Science & AI',
    'islamic_studies': 'Islamic Studies & Sharia',
    'languages_ielts': 'Languages & IELTS Academy',
    'engineering_tech': 'Engineering & Innovation',
    'medical_health': 'Medicine & Clinical Health',
    'general_edu': 'Culture & General Education',
  };
  static const Map<String, String> _categoryLabelsAr = {
    'cs_tech': 'علوم الحاسب والذكاء الاصطناعي',
    'islamic_studies': 'الدراسات الإسلامية والشرعية',
    'languages_ielts': 'اللغات وأكاديمية الآيلتس',
    'engineering_tech': 'الهندسة والابتكار',
    'medical_health': 'الطب والصحة السريرية',
    'general_edu': 'الثقافة والتعليم العام',
  };

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _streamKeyController;
  late final TextEditingController _ingestUrlController;
  late final TextEditingController _youtubeUrlController;

  StudioMode _mode = StudioMode.obs;
  String _selectedCategory = 'cs_tech';
  bool _isAudioOnly = false;
  BroadcastQualityPreset _quality = BroadcastQualityPreset.medium;
  bool _streamKeyVisible = false;

  /// Which external sender the Encoder tab lists for: OBS Studio on a
  /// computer, or another phone app (for example Larix Broadcaster). They are
  /// separate modes and are recorded separately on the server session.
  String _externalSender = 'obs_laptop';
  bool _isSubmitting = false;
  // Re-entrancy guard: a double tap must not start two go-live requests or
  // pop the sheet and then the page under it.
  bool _ctaBusy = false;
  // Visible inside the sheet. Earlier failures went to the page's
  // ScaffoldMessenger, which renders underneath this modal sheet, so the
  // buttons looked inert (P6-R06/R08/S01).
  String? _ctaErrorTitleKey;
  String? _ctaErrorKey;
  bool _ctaErrorOffersDeviceClaim = false;

  bool _isPrivate = false;
  final List<String> _whitelistHandles = [];
  bool _requireKnockApproval = true;
  late final TextEditingController _whitelistInputController;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
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
    _selectedCategory =
        _categoryLabelsEn.containsKey(provider.customLiveCategory)
            ? provider.customLiveCategory
            : 'cs_tech';
    _isAudioOnly = provider.customBroadcastType == BroadcastType.liveAudio;
    _isPrivate = provider.streamVisibility == StreamVisibility.private;
    _whitelistHandles.addAll(provider.streamWhitelistHandles);
    _requireKnockApproval = provider.requireKnockApproval;
    _whitelistInputController = TextEditingController();
    for (final c in [
      _titleController,
      _streamKeyController,
      _ingestUrlController,
      _youtubeUrlController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() => setState(_clearCtaError);

  void _clearCtaError() {
    _ctaErrorTitleKey = null;
    _ctaErrorKey = null;
    _ctaErrorOffersDeviceClaim = false;
  }

  void _showCtaError(String key, {String? titleKey}) {
    if (!mounted) return;
    setState(() {
      _ctaErrorTitleKey = titleKey;
      _ctaErrorKey = key;
      _ctaErrorOffersDeviceClaim = key == 'broadcast_primary_required';
    });
  }

  @override
  void dispose() {
    for (final c in [
      _titleController,
      _streamKeyController,
      _ingestUrlController,
      _youtubeUrlController,
    ]) {
      c.removeListener(_onFieldChanged);
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _streamKeyController.dispose();
    _ingestUrlController.dispose();
    _youtubeUrlController.dispose();
    _whitelistInputController.dispose();
    super.dispose();
  }

  // V2: unified system coral pink accent (matching the Discovery tab icon AppTheme.danger)
  Color get _modeColor => AppTheme.danger;

  void _selectMode(StudioMode mode) {
    if (mode == _mode) return;
    HapticFeedback.selectionClick();
    setState(() {
      _mode = mode;
      _clearCtaError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    // UI-09: on a short screen with a gesture nav bar, the safe-area inset
    // (not just the keyboard inset) has to be honoured or the bottom action
    // row renders flush against/under the system bar.
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.80),
          padding: EdgeInsets.only(
            left: AppTheme.spaceLg,
            right: AppTheme.spaceLg,
            top: AppTheme.spaceMd,
            bottom: bottomInset > 0
                ? bottomInset + AppTheme.spaceMd
                : bottomSafeArea + AppTheme.spaceLg,
          ),
          // V2: no outer border stroke -- the sheet sits cleanly against the
          // blurred backdrop with just its borderless rounded-top edge.
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          // UI-02/UI-09: mainAxisSize.min + Flexible (not Expanded) lets the
          // sheet shrink to fit short content (Local mode) instead of always
          // stretching to 80% of the screen and leaving a dead gap below the
          // last field, while still capping tall content (OBS mode) at the
          // maxHeight above and letting it scroll internally.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              const SizedBox(height: AppTheme.spaceMd),
              _buildHeader(isAr),
              const SizedBox(height: AppTheme.spaceLg),
              _buildModePill(isAr),
              const SizedBox(height: AppTheme.spaceMd),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: AppTheme.spaceXs),
                  child: _buildMiddleCard(isAr),
                ),
              ),
              if (_ctaErrorKey != null) ...[
                const SizedBox(height: AppTheme.spaceSm),
                _buildCtaError(),
              ],
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
          color: AppTheme.borderStrong,
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
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'live_studio.director_subtitle'.tr(),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
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
    // UI-04 root cause: AnimatedPositionedDirectional's `start` is already
    // resolved against the ambient TextDirection (right edge in RTL), which
    // is the exact same start-relative convention the Row below uses to lay
    // out its own (also Directionality-aware) children. Manually mirroring
    // the index here on top of that double-flips it in Arabic, so the pink
    // selection indicator lands under a different tab than the one whose
    // fields are actually showing -- e.g. selecting OBS visually highlighted
    // the محلي (Local) tab instead. The index must be passed through as-is.
    final index = StudioMode.values.indexOf(_mode);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 3;
          return Stack(
            children: [
              // Directional: the selected-tab indicator has to slide from the
              // start edge, which is the right one in Arabic.
              AnimatedPositionedDirectional(
                duration: const Duration(milliseconds: 360),
                curve: Curves.easeOutBack,
                start: index * tabWidth,
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
                    child: _pillTab(
                        StudioMode.obs,
                        Icons.settings_input_antenna_rounded,
                        'live_studio.mode_encoder'.tr()),
                  ),
                  Expanded(
                    child: _pillTab(
                      StudioMode.phone,
                      Icons.smartphone_rounded,
                      'design_copy.phone'.tr(),
                    ),
                  ),
                  Expanded(
                    // Announced as unavailable before it is selected.
                    child: Semantics(
                      hint: 'live_studio.btn_local_unavailable'.tr(),
                      child: _pillTab(
                        StudioMode.local,
                        Icons.bolt_rounded,
                        'design_copy.local'.tr(),
                      ),
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
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
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
                color: selected ? _modeColor : AppTheme.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    // UI-02: the selected pill is a light tint of _modeColor, so
                    // white (onMedia) text on it was near-invisible. _modeColor
                    // itself (already used for the icon) reads clearly on that
                    // tint, matching the pattern the category chips already use.
                    color: selected ? _modeColor : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _titleField() {
    return TextField(
      controller: _titleController,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5),
      decoration: InputDecoration(
        hintText: 'live_studio.title_hint'.tr(),
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        prefixIcon: Icon(Icons.title_rounded, color: _modeColor, size: 20),
        filled: true,
        fillColor: AppTheme.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _descriptionField(bool isAr) {
    return TextField(
      controller: _descriptionController,
      minLines: 2,
      maxLines: 4,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'design_copy.a_short_summary_viewers_will_see'.tr(),
        hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        filled: true,
        fillColor: AppTheme.surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          borderSide: const BorderSide(color: AppTheme.border),
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
          backgroundColor: AppTheme.surfaceAlt,
          labelStyle: TextStyle(
            color: isSelected ? _modeColor : AppTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? _modeColor : AppTheme.border,
          ),
          onSelected: (_) => setState(() => _selectedCategory = entry.key),
        );
      }).toList(),
    );
  }

  /// Opens the gamified "Streamer Academy"multi-step guide for whichever
  /// mode is currently selected. "Paste Key from Clipboard"inside the
  /// guide writes straight back into this sheet's own stream key field
  /// (the single source of truth Phone mode submits -- see the class doc's
  /// root-cause note), not into AppProvider directly, so the field the
  /// streamer sees here updates immediately once the guide closes.
  Widget _infoButton() {
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded,
          color: AppTheme.live, size: 20),
      tooltip: 'live_studio.setup_guide_tooltip'.tr(),
      onPressed: () => StreamerSetupGuideModal.show(
        context,
        mode: _mode,
        externalSender: _externalSender,
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
        _sectionLabel('design_copy.broadcast_title'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _titleField(),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('design_copy.broadcast_description'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _descriptionField(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('design_copy.category'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _categoryChips(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('live_studio.sender_label'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _buildSenderChoice(),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(
                child: _sectionLabel('design_copy.youtube_live_link'.tr())),
            _infoButton(),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        _watchUrlField(),
        const SizedBox(height: AppTheme.spaceSm),
        _buildAutoDetectButton(),
        const SizedBox(height: AppTheme.spaceMd),
        _encoderKeyNote(),
        const SizedBox(height: AppTheme.spaceMd),
        _buildAudioPosterSection(isAr),
        _buildStreamAccessSection(isAr),
      ],
    );
  }

  Widget _watchUrlField() => TextField(
        key: const Key('studio-watch-link-field'),
        controller: _youtubeUrlController,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'live_studio.watch_link_hint'.tr(),
          helperText: 'live_studio.watch_link_helper'.tr(),
          helperMaxLines: 3,
          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          prefixIcon: Icon(Icons.link_rounded, color: _modeColor, size: 18),
          filled: true,
          fillColor: AppTheme.surfaceAlt,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            borderSide: const BorderSide(color: AppTheme.border),
          ),
        ),
      );

  Widget _buildAutoDetectButton() {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        return SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: provider.isFindingMyLiveBroadcast
                ? null
                : () async {
                    final found = await provider.findMyLiveBroadcast();
                    if (!context.mounted) return;
                    if (found) {
                      _youtubeUrlController.text =
                          provider.customYouTubeLiveUrl;
                      InteractiveToastOverlay.show(
                        context,
                        title:
                            'live_studio.toast_broadcast_detected_title'.tr(),
                        message: 'live_studio.toast_broadcast_detected_message'
                            .tr(args: [provider.customYouTubeVideoId]),
                        icon: Icons.sensors_rounded,
                        accentColor: AppTheme.success,
                      );
                    } else {
                      InteractiveToastOverlay.show(
                        context,
                        title: 'live_studio.toast_detection_failed_title'.tr(),
                        message: (provider.findMyLiveBroadcastErrorKey ??
                                'live_studio.toast_detection_failed_message')
                            .tr(),
                        icon: Icons.error_outline_rounded,
                        accentColor: AppTheme.danger,
                      );
                    }
                  },
            icon: provider.isFindingMyLiveBroadcast
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _modeColor),
                  )
                : Icon(Icons.sensors_rounded, size: 16, color: _modeColor),
            label: Text(
              (provider.isFindingMyLiveBroadcast
                      ? 'live_studio.find_live_busy'
                      : 'live_studio.find_live_button')
                  .tr(),
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

  Widget _buildSenderChoice() {
    Widget chip(String mode, IconData icon, String labelKey) {
      final selected = _externalSender == mode;
      return ChoiceChip(
        key: Key('studio-sender-$mode'),
        avatar: Icon(icon,
            size: 16, color: selected ? _modeColor : AppTheme.textSecondary),
        label: Text(labelKey.tr()),
        selected: selected,
        selectedColor: _modeColor.withValues(alpha: 0.2),
        backgroundColor: AppTheme.surfaceAlt,
        labelStyle: TextStyle(
          color: selected ? _modeColor : AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
        side: BorderSide(color: selected ? _modeColor : AppTheme.border),
        onSelected: (_) => setState(() => _externalSender = mode),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('obs_laptop', Icons.laptop_mac_rounded,
                'live_studio.sender_obs_laptop'),
            chip('external_phone', Icons.smartphone_rounded,
                'live_studio.sender_external_phone'),
          ],
        ),
        const SizedBox(height: AppTheme.spaceXs),
        Semantics(
          liveRegion: true,
          child: Text(
            (_externalSender == 'obs_laptop'
                    ? 'live_studio.sender_obs_laptop_help'
                    : 'live_studio.sender_external_phone_help')
                .tr(),
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
          ),
        ),
      ],
    );
  }

  /// OBS or the phone app holds the stream key; this app never needs it for
  /// an external sender, so it is neither shown nor copied here.
  Widget _encoderKeyNote() {
    return Container(
      key: const Key('studio-encoder-key-note'),
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.key_rounded, color: _modeColor, size: 16),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              'live_studio.encoder_key_note'.tr(),
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
            ),
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
        _sectionLabel('design_copy.youtube_live_link'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _watchUrlField(),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('design_copy.broadcast_title'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _titleField(),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('design_copy.broadcast_description'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _descriptionField(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('design_copy.category'.tr()),
        const SizedBox(height: AppTheme.spaceSm),
        _categoryChips(isAr),
        const SizedBox(height: AppTheme.spaceMd),
        Row(
          children: [
            Expanded(
                child: _sectionLabel('design_copy.youtube_stream_key'.tr())),
            _infoButton(),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSm),
        TextField(
          controller: _streamKeyController,
          obscureText: !_streamKeyVisible,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontFamily: 'monospace'),
          key: const Key('studio-stream-key-field'),
          decoration: InputDecoration(
            hintText: 'xxxx-xxxx-xxxx-xxxx-xxxx',
            helperText: 'live_studio.stream_key_helper'.tr(),
            helperMaxLines: 3,
            hintStyle:
                const TextStyle(color: AppTheme.textMuted, fontSize: 11.5),
            prefixIcon: Icon(Icons.key_rounded, color: _modeColor, size: 18),
            suffixIcon: IconButton(
              icon: Icon(
                _streamKeyVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                color: AppTheme.textMuted,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _streamKeyVisible = !_streamKeyVisible),
            ),
            filled: true,
            fillColor: AppTheme.surfaceAlt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              borderSide: const BorderSide(color: AppTheme.border),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMd),
        _sectionLabel('design_copy.quality_preset'.tr()),
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
        final shortLabel = '${preset.height}p';
        final bandwidth = 'live_studio.preset_bitrate'
            .tr(args: [(preset.videoBitrateBps / 1e6).toStringAsFixed(1)]);
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(
              end: preset == BroadcastQualityPreset.high ? 0 : 8,
            ),
            child: InkWell(
              onTap: () => setState(() => _quality = preset),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _modeColor.withValues(alpha: 0.15)
                      : AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isSelected ? _modeColor : AppTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      shortLabel,
                      style: TextStyle(
                        color: isSelected ? _modeColor : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bandwidth,
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 9.5),
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
  // Local mode (unavailable: no local transport, owner decision D3)
  // ---------------------------------------------------------------------

  /// Same-Wi-Fi streaming has no media transport in this build: the old form
  /// only saved an rtmp:// address and started nothing. Say so plainly until
  /// P6S implements and verifies a real local transport.
  Widget _buildLocalFields(bool isAr) {
    return Container(
      key: const ValueKey('local-unavailable'),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.wifi_off_rounded,
              color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'live_studio.local_unavailable_title'.tr(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXs),
                Text(
                  'live_studio.local_unavailable_body'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaError() {
    final titleKey = _ctaErrorTitleKey;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: const ValueKey('studio-cta-error'),
        padding: const EdgeInsets.all(AppTheme.spaceSm),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppTheme.danger, size: 18),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (titleKey != null)
                        Text(
                          titleKey.tr(),
                          style: const TextStyle(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      Text(
                        _ctaErrorKey!.tr(),
                        style: const TextStyle(
                            color: AppTheme.textPrimary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_ctaErrorOffersDeviceClaim)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  icon: const Icon(Icons.phonelink_setup_rounded, size: 16),
                  label: Text('live_studio.action_use_this_device'.tr()),
                  onPressed: () {
                    // The server either grants the role or reports the
                    // device holding it; the conflict dialog handles that.
                    context.read<AppProvider>().setRoleMode(true);
                    setState(_clearCtaError);
                  },
                ),
              ),
          ],
        ),
      ),
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
              key: const Key('studio-audio-only-section'),
              margin: const EdgeInsets.only(top: AppTheme.spaceSm),
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                border: Border.all(color: _modeColor.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'live_studio.audio_only_title'.tr(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXs),
                  Text(
                    // The phone's own encoder hides its video; an external
                    // sender decides for itself what YouTube shows.
                    (_mode == StudioMode.phone
                            ? 'live_studio.audio_only_note'
                            : 'live_studio.audio_only_note_encoder')
                        .tr(),
                    key: const Key('studio-audio-only-note'),
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.4),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  // ---------------------------------------------------------------------
  // Private & Restricted Streaming: Public/Private access selector
  // ---------------------------------------------------------------------

  Widget _buildStreamAccessSection(bool isAr) {
    if (!kPrivateStreamingEnabled) return const SizedBox.shrink();
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppTheme.spaceMd),
          _sectionLabel('design_copy.stream_access'.tr()),
          const SizedBox(height: AppTheme.spaceSm),
          Row(
            children: [
              Expanded(
                child: _accessPill(
                  label: 'design_copy.public'.tr(),
                  selected: !_isPrivate,
                  onTap: () => setState(() => _isPrivate = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _accessPill(
                  label: 'design_copy.private'.tr(),
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
          color: selected
              ? _modeColor.withValues(alpha: 0.15)
              : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? _modeColor : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? _modeColor : AppTheme.textSecondary,
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
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: _modeColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'design_copy.pre_approved_roster_whitelist'.tr(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
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
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: '@sarah, @khalid',
                    hintStyle: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 11.5),
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(color: AppTheme.border),
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
                  backgroundColor: AppTheme.surface,
                  label: Text(
                    handle,
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 11),
                  ),
                  deleteIcon: const Icon(Icons.close_rounded,
                      size: 14, color: AppTheme.danger),
                  onDeleted: () =>
                      setState(() => _whitelistHandles.remove(handle)),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: AppTheme.spaceMd),
          Row(
            children: [
              Expanded(
                child: Text(
                  'design_copy.require_host_knock_approval_for_new_guests'.tr(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 12),
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
              label: Text('design_copy.share_private_invite_link'.tr()),
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
            label: 'design_copy.video'.tr(),
            selected: !_isAudioOnly,
            onTap: () => setState(() => _isAudioOnly = false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _formatOption(
            icon: Icons.mic_rounded,
            label: 'design_copy.audio'.tr(),
            selected: _isAudioOnly,
            onTap: () => setState(() => _isAudioOnly = true),
            // V2: gentle breathing glow while Audio-Only is the active
            // format, so the CTA morph below isn't the only signal that
            // this choice changes what "going live"does.
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
          color: selected
              ? _modeColor.withValues(alpha: 0.18)
              : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: selected ? _modeColor : AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16, color: selected ? _modeColor : AppTheme.textMuted),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: selected ? _modeColor : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
    return _PulseGlow(pulsing: pulsing, color: _modeColor, child: content);
  }

  Widget _buildCtaButton() {
    final provider = context.watch<AppProvider>();
    final isLive = provider.isBroadcastingLive;

    if (isLive) {
      return SizedBox(
        width: double.infinity,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSubmitting
                ? null
                : () async {
                    final endHere = widget.onEndBroadcast;
                    if (endHere != null) {
                      setState(() => _isSubmitting = true);
                      Navigator.of(context).pop();
                      await endHere();
                      return;
                    }
                    setState(() => _isSubmitting = true);
                    await provider.toggleBroadcasterGoLive(context);
                    if (!mounted) return;
                    setState(() => _isSubmitting = false);
                    Navigator.of(context).pop();
                    InteractiveToastOverlay.show(
                      context,
                      title: 'live_studio.toast_broadcast_ended_title'.tr(),
                      message: 'live_studio.toast_broadcast_ended_message'.tr(),
                      icon: Icons.stop_circle_rounded,
                      accentColor: AppTheme.danger,
                    );
                  },
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              // UI-02: this was AppTheme.surfaceAlt (a pale mint fill) with
              // white text/icon on top -- effectively invisible, which read
              // as a disabled button even though it was fully tappable. A
              // solid fill in the mode's own semantic accent gives the
              // primary action the contrast and hierarchy it needs.
              decoration: BoxDecoration(
                color: _modeColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.danger.withValues(alpha: 0.38),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.onMedia),
                    )
                  else
                    const Icon(Icons.stop_circle_rounded,
                        size: 18, color: AppTheme.onMedia),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'design_ui.end_stream'.tr(),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppTheme.onMedia,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final (label, icon) = switch (_mode) {
      StudioMode.obs => ('live_studio.btn_go_live'.tr(), Icons.sensors_rounded),
      StudioMode.phone => (
          'live_studio.btn_open_camera'.tr(),
          Icons.photo_camera_rounded
        ),
      StudioMode.local => (
          'live_studio.btn_local_unavailable'.tr(),
          Icons.block_rounded
        ),
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
              // UI-02: solid fill (was the near-invisible pale surfaceAlt).
              decoration: BoxDecoration(
                color: _modeColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.danger.withValues(alpha: 0.38),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.onMedia),
                    )
                  else
                    Icon(icon, size: 18, color: AppTheme.onMedia),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppTheme.onMedia,
                      ),
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
    if (_ctaBusy) return;
    _ctaBusy = true;
    try {
      switch (_mode) {
        case StudioMode.obs:
          await _handleObsGoLive();
        case StudioMode.phone:
          await _handlePhoneOpenCamera();
        case StudioMode.local:
          _showCtaError('live_studio.local_unavailable_body',
              titleKey: 'live_studio.local_unavailable_title');
      }
    } finally {
      _ctaBusy = false;
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
    // No backdrop image reaches the encoder yet (the phone hides its video
    // track); nothing is stored that would suggest otherwise.
    provider.setCustomAudioOnlyPosterPath(null);
    provider.configureStreamPrivacy(
      visibility:
          _isPrivate ? StreamVisibility.private : StreamVisibility.public,
      whitelistHandles: _whitelistHandles,
      requireKnockApproval: _requireKnockApproval,
    );
  }

  /// OBS: the app cannot see OBS or YouTube ingest. It only asks the server
  /// to list this account as live for the given watch video ID, and reports
  /// exactly that -- never "live on YouTube".
  Future<void> _handleObsGoLive() async {
    final provider = context.read<AppProvider>();
    _persistSharedMeta(provider);
    final preflight = provider.broadcastPreflightErrorKey;
    if (preflight != null) {
      _showCtaError(preflight);
      return;
    }
    final rawYoutube = _youtubeUrlController.text.trim();
    if (looksLikeStreamKey(rawYoutube)) {
      _showCtaError('live_studio.error_key_in_watch_field');
      return;
    }
    final videoId = AppProvider.extractYouTubeId(rawYoutube);
    if (videoId.isEmpty) {
      _showCtaError(_externalSender == 'obs_laptop'
          ? 'live_studio.error_watch_id_required'
          : 'live_studio.error_watch_id_required_phone_app');
      return;
    }

    setState(() => _isSubmitting = true);
    final check = await provider.verifyWatchLink(videoId);
    if (!mounted) return;
    if (!check.allowsStart) {
      setState(() => _isSubmitting = false);
      _showCtaError(check.errorKey!);
      return;
    }
    provider.setCustomStreamerYouTubeUrl(rawYoutube);
    if (!provider.isBroadcastingLive) {
      provider.setBroadcastSenderMode(_externalSender);
      await provider.setBroadcasterLive(true);
    }
    // Closed while the request was in flight: the provider already holds the
    // server's answer; there is nothing left to show here.
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!provider.isBroadcastingLive) {
      _showCtaError(provider.broadcastSessionError ?? 'broadcast_state_failed');
      return;
    }
    Navigator.of(context).pop();
    InteractiveToastOverlay.show(
      context,
      title: 'live_studio.obs_listed_live_title'.tr(),
      message: [
        (_externalSender == 'obs_laptop'
                ? 'live_studio.obs_listed_live_body'
                : 'live_studio.phone_app_listed_live_body')
            .tr(args: [videoId]),
        if (check.noteKey != null) check.noteKey!.tr(),
      ].join(' '),
      // A note the broadcaster must read stays up longer and is not cut off.
      duration: Duration(seconds: check.noteKey == null ? 4 : 12),
      messageMaxLines: check.noteKey == null ? 2 : 8,
      icon: check.noteKey == null
          ? Icons.sensors_rounded
          : Icons.warning_amber_rounded,
      accentColor: check.noteKey == null ? _modeColor : AppTheme.warning,
    );
  }

  /// Phone: validate everything the phone screen needs before leaving the
  /// sheet, so a refusal is explained here instead of after navigation.
  Future<void> _handlePhoneOpenCamera() async {
    final provider = context.read<AppProvider>();
    // Opened from the phone broadcast screen: that screen already owns the
    // camera; a second one would stack another encoder on top.
    if (widget.onEndBroadcast != null) {
      _showCtaError('live_studio.error_phone_screen_open');
      return;
    }
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _showCtaError('live_studio.error_phone_unsupported');
      return;
    }
    final preflight = provider.broadcastPreflightErrorKey;
    if (preflight != null) {
      _showCtaError(preflight);
      return;
    }
    final streamKey = _streamKeyController.text.trim();
    if (streamKey.isEmpty) {
      _showCtaError('live_studio.toast_stream_key_required_message',
          titleKey: 'live_studio.toast_stream_key_required_title');
      return;
    }
    if (looksLikeIngestUrl(streamKey)) {
      _showCtaError('live_studio.error_ingest_in_key_field');
      return;
    }
    if (looksLikeWatchLink(streamKey)) {
      _showCtaError('live_studio.error_watch_in_key_field');
      return;
    }
    final watchUrl = _youtubeUrlController.text.trim();
    if (looksLikeStreamKey(watchUrl)) {
      _showCtaError('live_studio.error_key_in_watch_field');
      return;
    }
    final videoId = AppProvider.extractYouTubeId(watchUrl);
    if (videoId.isEmpty) {
      _showCtaError('live.watch_url_required');
      return;
    }
    setState(() => _isSubmitting = true);
    final check = await provider.verifyWatchLink(videoId);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!check.allowsStart) {
      _showCtaError(check.errorKey!);
      return;
    }
    provider.setCustomStreamerYouTubeUrl(watchUrl);
    _persistSharedMeta(provider);
    provider.updatePhoneBroadcastTarget(
      rtmpUrl: _ingestUrlController.text.trim().isEmpty
          ? provider.phoneBroadcastRtmpUrl
          : _ingestUrlController.text.trim(),
      streamKey: streamKey,
    );

    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute(
        builder: (_) => PhoneBroadcastScreen(
            quickLaunchPreset: _quality, watchLinkNoteKey: check.noteKey),
      ),
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

/// A YouTube stream key pasted into the public watch-link field (keys are
/// dash-separated groups of letters and digits). Never shown back.
@visibleForTesting
bool looksLikeStreamKey(String text) =>
    RegExp(r'^[A-Za-z0-9]{4}(-[A-Za-z0-9]{4}){3,5}$').hasMatch(text.trim());

/// A watch link (or a bare 11-character video ID) pasted into the secret
/// stream-key field.
@visibleForTesting
bool looksLikeWatchLink(String text) {
  final t = text.trim();
  final lower = t.toLowerCase();
  return lower.contains('youtube.com/') ||
      lower.contains('youtu.be/') ||
      RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(t);
}

/// The RTMP(S) server address pasted into the stream-key field.
@visibleForTesting
bool looksLikeIngestUrl(String text) =>
    RegExp(r'^rtmps?://', caseSensitive: false).hasMatch(text.trim());
