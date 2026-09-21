import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import 'rtmp_ip_dialog.dart'show StudioMode;

enum _ActionKind { openStudio, pasteClipboard }

class _QuestAction {
  final _ActionKind kind;
  final String label;

  const _QuestAction(this.kind, this.label);
}

class _Quest {
  final String questName;
  final IconData icon;
  final String heading;
  final String body;
  final List<_QuestAction> actions;

  const _Quest({
    required this.questName,
    required this.icon,
    required this.heading,
    required this.body,
    this.actions = const [],
  });
}

/// Gamified multi-step "Streamer Academy"setup guide -- the Info (!) button
/// destination for all 3 Broadcaster Studio modes (V2 redesign). Replaces
/// the old plain numbered-steps dialog with a swipeable story-card carousel
/// (playful, non-technical "quest"copy), a two-tap "paste from clipboard"
/// shortcut that writes straight back into the studio sheet's stream key
/// field via [onStreamKeyPasted], and a direct external link into YouTube
/// Studio. Never asks for a Google account or channel URL -- it only opens
/// YouTube Studio's public dashboard and lets the streamer sign in there
/// themselves.
class StreamerSetupGuideModal extends StatefulWidget {
  final StudioMode mode;
  final ValueChanged<String>? onStreamKeyPasted;

  const StreamerSetupGuideModal({
    super.key,
    required this.mode,
    this.onStreamKeyPasted,
  });

  static Future<void> show(
    BuildContext context, {
    required StudioMode mode,
    ValueChanged<String>? onStreamKeyPasted,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppTheme.media.withValues(alpha: 0.6),
      builder: (_) => StreamerSetupGuideModal(
        mode: mode,
        onStreamKeyPasted: onStreamKeyPasted,
      ),
    );
  }

  @override
  State<StreamerSetupGuideModal> createState() =>
      _StreamerSetupGuideModalState();
}

class _StreamerSetupGuideModalState extends State<StreamerSetupGuideModal> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<_Quest> _quests(bool isAr) {
    return switch (widget.mode) {
      StudioMode.obs => _obsQuests(isAr),
      StudioMode.phone => _phoneQuests(isAr),
      StudioMode.local => _localQuests(isAr),
    };
  }

  List<_Quest> _obsQuests(bool isAr) => [
        _Quest(
          questName: 'design_copy.mission_control'.tr(),
          icon: Icons.public_rounded,
          heading: 'design_copy.open_mission_control'.tr(),
          body: 'design_copy.everything_starts_at_youtube_studio_your_mission_control_for_goin'.tr(),
          actions: [
            _QuestAction(_ActionKind.openStudio,
                'design_copy.open_youtube_studio'.tr()),
          ],
        ),
        _Quest(
          questName: 'design_copy.the_secret_vip_pass'.tr(),
          icon: Icons.vpn_key_rounded,
          heading: 'design_copy.grab_your_secret_stream_key'.tr(),
          body: 'design_copy.think_of_your_stream_key_like_a_secret_vip_backstage_pass_it_tell'.tr(),
          actions: [
            _QuestAction(_ActionKind.openStudio,
                'design_copy.open_youtube_studio'.tr()),
            _QuestAction(_ActionKind.pasteClipboard,
                'design_copy.paste_key_from_clipboard'.tr()),
          ],
        ),
        _Quest(
          questName: 'design_copy.connecting_the_wires'.tr(),
          icon: Icons.cable_rounded,
          heading: 'design_copy.wire_up_obs_studio'.tr(),
          body: 'design_copy.open_obs_studio_on_your_computer_go_to_settings_stream_and_paste_'.tr(),
        ),
        _Quest(
          questName: 'design_copy.ready_for_takeoff'.tr(),
          icon: Icons.rocket_launch_rounded,
          heading: 'design_copy.launch_your_broadcast'.tr(),
          body: 'design_copy.press_start_streaming_in_obs_first_then_tap_go_live_below_to_laun'.tr(),
        ),
      ];

  List<_Quest> _phoneQuests(bool isAr) => [
        _Quest(
          questName: 'design_copy.account_activation'.tr(),
          icon: Icons.hourglass_top_rounded,
          heading: 'design_copy.activate_your_channel_first'.tr(),
          body: 'design_copy.first_time_going_live_on_youtube_your_channel_needs_a_one_time_24'.tr(),
        ),
        _Quest(
          questName: 'design_copy.set_it_forget_it'.tr(),
          icon: Icons.save_rounded,
          heading: 'design_copy.paste_your_stream_key_once'.tr(),
          body: 'design_copy.grab_your_stream_key_from_youtube_studio_s_stream_tab_and_paste_i'.tr(),
          actions: [
            _QuestAction(_ActionKind.openStudio,
                'design_copy.open_youtube_studio'.tr()),
            _QuestAction(_ActionKind.pasteClipboard,
                'design_copy.paste_key_from_clipboard'.tr()),
          ],
        ),
        _Quest(
          questName: 'design_copy.live_from_your_phone'.tr(),
          icon: Icons.smartphone_rounded,
          heading: 'design_copy.open_camera_go'.tr(),
          body: 'design_copy.tap_open_camera_and_your_phone_s_own_camera_and_microphone_become'.tr(),
        ),
      ];

  List<_Quest> _localQuests(bool isAr) => [
        _Quest(
          questName: 'design_copy.same_room_network'.tr(),
          icon: Icons.wifi_rounded,
          heading: 'design_copy.join_the_same_wi_fi'.tr(),
          body: 'design_copy.this_mode_streams_straight_over_your_local_wi_fi_no_internet_need'.tr(),
        ),
        _Quest(
          questName: 'design_copy.plug_play'.tr(),
          icon: Icons.bolt_rounded,
          heading: 'design_copy.enter_the_laptop_ip'.tr(),
          body: 'design_copy.find_your_laptop_s_local_ip_address_usually_starts_with_192_168_t'.tr(),
        ),
      ];

  Future<void> _openYoutubeStudio() async {
    final uri = Uri.parse('https://studio.youtube.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pasteFromClipboard(bool isAr) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (!mounted) return;

    if (text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('design_copy.clipboard_is_empty_or_too_short_to_be_a_stream_key'.tr()),
        ),
      );
      return;
    }

    widget.onStreamKeyPasted?.call(text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('design_copy.stream_key_pasted'.tr()),
        backgroundColor: AppTheme.live,
      ),
    );
  }

  void _goToPage(int page) {
    HapticFeedback.selectionClick();
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.locale.languageCode == 'ar';
    final quests = _quests(isAr);
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: screenHeight * 0.72,
          padding: EdgeInsets.only(
            left: AppTheme.spaceLg,
            right: AppTheme.spaceLg,
            top: AppTheme.spaceMd,
            bottom: bottomInset > 0 ? bottomInset + AppTheme.spaceMd : AppTheme.spaceLg,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(isAr, quests),
              const SizedBox(height: AppTheme.spaceMd),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: quests.length,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentPage = i);
                  },
                  itemBuilder: (context, i) => _buildQuestCard(quests[i], isAr),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              _buildDots(quests.length),
              const SizedBox(height: AppTheme.spaceMd),
              _buildNavRow(quests.length, isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isAr, List<_Quest> quests) {
    final quest = quests[_currentPage];
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'design_copy.streamer_academy'.tr(),
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isAr
                    ? 'المستوى ${_currentPage + 1} من ${quests.length}: ${quest.questName}'
                    : 'Level ${_currentPage + 1} of ${quests.length}: ${quest.questName}',
                style: const TextStyle(
                  color: AppTheme.onMedia,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
          tooltip: 'design_copy.close'.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildQuestCard(_Quest quest, bool isAr) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXs),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.surfaceAlt,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.danger.withValues(alpha: 0.42),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(quest.icon, color: AppTheme.onMedia, size: 30),
                ),
              ),
              const SizedBox(height: AppTheme.spaceLg),
              Text(
                quest.heading,
                textAlign: TextAlign.start,
                style: const TextStyle(
                  color: AppTheme.onMedia,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                quest.body,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (quest.actions.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spaceLg),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: quest.actions.map((action) {
                    return OutlinedButton(
                      onPressed: switch (action.kind) {
                        _ActionKind.openStudio => _openYoutubeStudio,
                        _ActionKind.pasteClipboard => () => _pasteFromClipboard(isAr),
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: AppTheme.danger),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        ),
                      ),
                      child: Text(
                        action.label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _currentPage;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppTheme.danger.withValues(alpha: 0.45),
                      blurRadius: 8,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            width: active ? 26 : 7,
            height: 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              color: active ? null : AppTheme.disabled,
              gradient: active
                  ? AppGradients.brand
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNavRow(int count, bool isAr) {
    final isFirst = _currentPage == 0;
    final isLast = _currentPage == count - 1;

    return Row(
      children: [
        Expanded(
          child: isFirst
              ? const SizedBox.shrink()
              : OutlinedButton(
                  onPressed: () => _goToPage(_currentPage - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: Text(
                    'design_copy.previous_step'.tr(),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                ),
        ),
        if (!isFirst) const SizedBox(width: AppTheme.spaceSm),
        Expanded(
          child: ElevatedButton(
            onPressed: isLast
                ? () => Navigator.of(context).pop()
                : () => _goToPage(_currentPage + 1),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: AppTheme.onMedia,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: Text(
              isLast
                  ? ('design_copy.got_it_let_s_stream'.tr())
                  : ('design_copy.next_quest'.tr()),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
