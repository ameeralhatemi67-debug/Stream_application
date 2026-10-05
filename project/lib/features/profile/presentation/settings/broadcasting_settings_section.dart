import '../../../../core/widgets/ds/ca_fields.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/widgets/ds/ca_cards.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/models/streamer_models.dart';

/// Go Live studio fields and the streaming quality default, shown together in
/// the broadcaster preferences sheet.
///
/// Extracted from `settings_screen.dart` with the rest of the Settings split.
/// The four text controllers moved with it: they were owned by the screen but
/// only ever read and written here, so the section that uses them now creates
/// and disposes them.
class BroadcastingSettingsSection extends StatefulWidget {
  const BroadcastingSettingsSection({super.key});

  @override
  State<BroadcastingSettingsSection> createState() =>
      _BroadcastingSettingsSectionState();
}

class _BroadcastingSettingsSectionState
    extends State<BroadcastingSettingsSection> {
  final TextEditingController _youtubeUrlController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _venueController = TextEditingController();
  final TextEditingController _slidesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _youtubeUrlController.text = provider.customYouTubeLiveUrl;
    _titleController.text = provider.customLiveTitle;
    _venueController.text = provider.customLiveVenue;
    _slidesController.text = provider.customSlidesUrl;
  }

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
    _youtubeUrlController.dispose();
    _titleController.dispose();
    _venueController.dispose();
    _slidesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.select<AppProvider, Object?>((p) => (
          p.isBroadcastingLive,
          p.customBroadcastType,
          p.selectedBroadcastOrgId,
          p.selectedVenueBranchId,
          p.selectedCoSpeakerIds,
          p.selectedStreamingQuality
        ));
    final provider = context.read<AppProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStreamerStudioCard(context, provider),
        const SizedBox(height: AppTheme.spaceMd),
        _buildStreamingQualityCard(context, provider),
      ],
    );
  }

  Widget _buildStreamerStudioCard(BuildContext context, AppProvider provider) {
    final isBroadcasting = provider.isBroadcastingLive;
    final isAudioLive = provider.customBroadcastType == BroadcastType.liveAudio;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isBroadcasting
              ? (isAudioLive ? Canopy.haze : Canopy.liveCrimson)
              : Canopy.hairline,
          width: isBroadcasting ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isBroadcasting
                          ? (isAudioLive ? Canopy.haze : Canopy.liveCrimson)
                          : Canopy.haze,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBroadcasting
                        ? (isAudioLive
                            ? 'settings.broadcast_status_audio_live'.tr()
                            : 'settings.broadcast_status_live'.tr())
                        : 'settings.broadcast_status_offline'.tr(),
                    style: TextStyle(
                      color: isBroadcasting
                          ? (isAudioLive ? AppTheme.onMedia : Canopy.liveCrimson)
                          : Canopy.haze,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (isBroadcasting)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAudioLive
                        ? AppTheme.media
                        : Canopy.liveCrimson.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: isAudioLive
                        ? Border.all(color: Canopy.haze, width: 0.8)
                        : null,
                  ),
                  child: Text(
                    isAudioLive
                        ? '342 ${'live.listening_count'.tr()}'
                        : '342 ${'settings.viewers_count'.tr()}',
                    style: TextStyle(
                      color: isAudioLive ? AppTheme.onMedia : Canopy.liveCrimson,
                      fontSize: AppTheme.captionFont,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          //  Broadcast Identity Selector (Scholar vs Organization)
          Text(
            'admin.broadcast_identity'.tr(),
            style: const TextStyle(
              color: Canopy.slate,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_rounded, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'admin.broadcast_as_individual'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  selected: provider.selectedBroadcastOrgId == null,
                  selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                  backgroundColor: Canopy.mint,
                  labelStyle: TextStyle(
                    color: provider.selectedBroadcastOrgId == null
                        ? AppTheme.primary
                        : Canopy.slate,
                    fontSize: AppTheme.captionFont,
                    fontWeight: provider.selectedBroadcastOrgId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: provider.selectedBroadcastOrgId == null
                        ? AppTheme.primary
                        : Canopy.hairline,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      provider.setSelectedBroadcastOrgId(null);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: ChoiceChip(
                  label: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment_rounded, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'live.org_broadcast_deferred'.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  selected: provider.selectedBroadcastOrgId == 'org_dalilk_04',
                  selectedColor: AppTheme.warning.withValues(alpha: 0.2),
                  backgroundColor: Canopy.mint,
                  labelStyle: TextStyle(
                    color: provider.selectedBroadcastOrgId == 'org_dalilk_04'
                        ? AppTheme.warning
                        : Canopy.slate,
                    fontSize: AppTheme.captionFont,
                    fontWeight:
                        provider.selectedBroadcastOrgId == 'org_dalilk_04'
                            ? FontWeight.bold
                            : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: provider.selectedBroadcastOrgId == 'org_dalilk_04'
                        ? AppTheme.warning
                        : Canopy.hairline,
                  ),
                  onSelected: null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          //  /  Broadcast Format Segmented Selector
          Text(
            'settings.broadcast_format'.tr(),
            style: const TextStyle(
              color: Canopy.slate,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      provider.setBroadcastType(BroadcastType.liveVideo),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                    decoration: BoxDecoration(
                      color: provider.customBroadcastType ==
                              BroadcastType.liveVideo
                          ? Canopy.liveCrimson.withValues(alpha: 0.2)
                          : Canopy.mint,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: provider.customBroadcastType ==
                                BroadcastType.liveVideo
                            ? Canopy.liveCrimson
                            : Canopy.hairline,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_rounded,
                          size: 16,
                          color: provider.customBroadcastType ==
                                  BroadcastType.liveVideo
                              ? Canopy.liveCrimson
                              : Canopy.haze,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'settings.format_video'.tr(),
                            style: TextStyle(
                              color: provider.customBroadcastType ==
                                      BroadcastType.liveVideo
                                  ? AppTheme.onMedia
                                  : Canopy.slate,
                              fontSize: 12,
                              fontWeight: provider.customBroadcastType ==
                                      BroadcastType.liveVideo
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      provider.setBroadcastType(BroadcastType.liveAudio),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                    decoration: BoxDecoration(
                      color: provider.customBroadcastType ==
                              BroadcastType.liveAudio
                          ? AppTheme.media
                          : Canopy.mint,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      border: Border.all(
                        color: provider.customBroadcastType ==
                                BroadcastType.liveAudio
                            ? Canopy.haze
                            : Canopy.hairline,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_rounded,
                          size: 16,
                          color: provider.customBroadcastType ==
                                  BroadcastType.liveAudio
                              ? AppTheme.onMedia
                              : Canopy.haze,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'settings.format_audio'.tr(),
                            style: TextStyle(
                              color: provider.customBroadcastType ==
                                      BroadcastType.liveAudio
                                  ? AppTheme.onMedia
                                  : Canopy.slate,
                              fontSize: 12,
                              fontWeight: provider.customBroadcastType ==
                                      BroadcastType.liveAudio
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),

          if (context.isPhoneLandscape) ...[
            Text('live.landscape_settings_portrait'.tr()),
            const SizedBox(height: AppTheme.spaceMd),
          ],
          CaInput(
              label: 'settings.youtube_url_label'.tr(),
              controller: _youtubeUrlController,
              enabled: !isBroadcasting,
              readOnly: context.isPhoneLandscape,
              helper: isBroadcasting
                  ? 'settings.youtube_url_locked_while_live'.tr()
                  : null,
              onChanged: (val) => provider.setCustomStreamerYouTubeUrl(val)),
          const SizedBox(height: AppTheme.spaceMd),
          CaInput(
              label: 'settings.lecture_title_label'.tr(),
              controller: _titleController,
              readOnly: context.isPhoneLandscape),
          const SizedBox(height: AppTheme.spaceMd),

          // Conditional Venue Section (Organization Campus Dropdown vs Custom Text Field)
          if (provider.selectedBroadcastOrgId != null) ...[
            Text(
              'admin.select_campus_branch'.tr(),
              style: const TextStyle(
                color: Canopy.slate,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final branches = provider
                    .getOrganizationVenues(provider.selectedBroadcastOrgId!);
                final langCode = context.locale.languageCode;
                return InputDecorator(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.apartment_rounded,
                        color: AppTheme.warning, size: 20),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: provider.selectedVenueBranchId,
                      isExpanded: true,
                      dropdownColor: Canopy.mint,
                      style: const TextStyle(
                          color: Canopy.ink, fontSize: 13),
                      items: branches.map((b) {
                        return DropdownMenuItem<String>(
                          value: b.venueId,
                          child: Text(
                            '${b.getLocalizedName(langCode)} (${b.seatingCapacity} seats)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          provider.setSelectedVenueBranchId(val),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppTheme.spaceMd),

            // Presenters / Co-Hosts Multi-Select Chips
            Text(
              'admin.select_co_speakers'.tr(),
              style: const TextStyle(
                color: Canopy.slate,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final speakers = provider
                    .getOrganizationSpeakers(provider.selectedBroadcastOrgId!);
                final langCode = context.locale.languageCode;
                return Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: speakers.map((spk) {
                    final isChecked =
                        provider.selectedCoSpeakerIds.contains(spk.speakerId);
                    return FilterChip(
                      avatar: CircleAvatar(
                        radius: 12,
                        backgroundImage: AssetImage(spk.avatarUrl),
                      ),
                      label: Text(spk.getLocalizedName(langCode)),
                      selected: isChecked,
                      selectedColor: AppTheme.warning.withValues(alpha: 0.25),
                      backgroundColor: Canopy.mint,
                      labelStyle: TextStyle(
                        color: isChecked
                            ? AppTheme.warning
                            : Canopy.slate,
                        fontSize: AppTheme.captionFont,
                        fontWeight:
                            isChecked ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isChecked ? AppTheme.warning : Canopy.hairline,
                      ),
                      onSelected: (_) =>
                          provider.toggleCoSpeaker(spk.speakerId),
                    );
                  }).toList(),
                );
              },
            ),
          ] else ...[
            CaInput(
                label: 'settings.venue_location_label'.tr(),
                controller: _venueController,
                readOnly: context.isPhoneLandscape),
          ],
          const SizedBox(height: AppTheme.spaceLg),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isBroadcasting ? AppTheme.surface : AppTheme.primary,
                foregroundColor:
                    isBroadcasting ? Canopy.ink : AppTheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              icon: Icon(isBroadcasting
                  ? Icons.stop_circle_outlined
                  : Icons.rocket_launch_rounded),
              label: Text(
                isBroadcasting
                    ? 'settings.end_live_btn'.tr()
                    : 'settings.go_live_btn'.tr(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () {
                provider.setCustomBroadcastDetails(
                  title: _titleController.text.trim(),
                  category: 'computer_science',
                  venue: _venueController.text.trim(),
                  slidesUrl: _slidesController.text.trim(),
                );
                provider.toggleBroadcasterGoLive(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamingQualityCard(
      BuildContext context, AppProvider provider) {
    final quality = provider.selectedStreamingQuality;

    return CaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.quality'.tr(),
            style: const TextStyle(
                color: Canopy.slate,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spaceSm),
          DropdownButtonFormField<String>(
            initialValue: quality,
            dropdownColor: Canopy.mint,
            style: const TextStyle(color: Canopy.ink, fontSize: 13),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              prefixIcon:
                  Icon(Icons.hd_outlined, color: AppTheme.primary, size: 20),
            ),
            items: [
              DropdownMenuItem(
                  value: 'Auto (1080p)',
                  child: Text('settings.quality_auto'.tr())),
              DropdownMenuItem(
                  value: 'High (720p HD)',
                  child: Text('settings.quality_high'.tr())),
              DropdownMenuItem(
                  value: 'Medium (480p SD)',
                  child: Text('settings.quality_medium'.tr())),
              DropdownMenuItem(
                  value: 'Low (360p)',
                  child: Text('settings.quality_low'.tr())),
              DropdownMenuItem(
                  value: 'Audio Only',
                  child: Text('settings.quality_audio'.tr())),
            ],
            onChanged: (val) {
              if (val != null) provider.setSelectedStreamingQuality(val);
            },
          ),
        ],
      ),
    );
  }
}
