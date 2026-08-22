import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/interactive_toast_overlay.dart';
import '../../../profile/models/streamer_models.dart';
import '../screens/phone_broadcast_screen.dart';

enum BroadcastTargetType { localRtmp, youtubeLive, phoneToYoutube }

/// Pitch Director & Live Studio Settings Dialog.
/// Allows switching Amir Al-Hatemi's live stream between Local OBS RTMP and YouTube Live.
class RtmpIpSettingsDialog extends StatefulWidget {
  const RtmpIpSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const RtmpIpSettingsDialog(),
    );
  }

  @override
  State<RtmpIpSettingsDialog> createState() => _RtmpIpSettingsDialogState();
}

class _RtmpIpSettingsDialogState extends State<RtmpIpSettingsDialog> {
  BroadcastTargetType _selectedTarget = BroadcastTargetType.youtubeLive;
  late TextEditingController _ipController;
  late TextEditingController _youtubeUrlController;
  late TextEditingController _phoneRtmpUrlController;
  late TextEditingController _streamKeyController;
  bool _streamKeyVisible = false;

  final List<String> _presetIps = [
    '127.0.0.1',
    '192.168.1.100',
    '192.168.0.105',
    '10.0.0.5',
  ];

  @override
  void initState() {
    super.initState();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    _ipController = TextEditingController(text: appProvider.rtmpLaptopIp);
    _youtubeUrlController = TextEditingController(
      text: appProvider.customYouTubeLiveUrl.isNotEmpty
          ? appProvider.customYouTubeLiveUrl
          : appProvider.customYouTubeVideoId,
    );
    _phoneRtmpUrlController =
        TextEditingController(text: appProvider.phoneBroadcastRtmpUrl);
    _streamKeyController =
        TextEditingController(text: appProvider.phoneBroadcastStreamKey);
    _ipController.addListener(_onFieldChanged);
    _youtubeUrlController.addListener(_onFieldChanged);
    _phoneRtmpUrlController.addListener(_onFieldChanged);
    _streamKeyController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _ipController.removeListener(_onFieldChanged);
    _youtubeUrlController.removeListener(_onFieldChanged);
    _phoneRtmpUrlController.removeListener(_onFieldChanged);
    _streamKeyController.removeListener(_onFieldChanged);
    _ipController.dispose();
    _youtubeUrlController.dispose();
    _phoneRtmpUrlController.dispose();
    _streamKeyController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (_selectedTarget == BroadcastTargetType.phoneToYoutube) {
      final rtmpUrl = _phoneRtmpUrlController.text.trim();
      final streamKey = _streamKeyController.text.trim();
      if (streamKey.isEmpty) {
        InteractiveToastOverlay.show(
          context,
          title: 'Stream Key Required',
          message: 'Paste the stream key from YouTube Studio\'s Go Live > Stream tab.',
          icon: Icons.error_outline_rounded,
          accentColor: AppTheme.accentRed,
        );
        return;
      }
      appProvider.updatePhoneBroadcastTarget(
        rtmpUrl: rtmpUrl,
        streamKey: streamKey,
      );
      Navigator.of(context).pop();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PhoneBroadcastScreen()),
      );
      return;
    }

    if (_selectedTarget == BroadcastTargetType.localRtmp) {
      final rawIp = _ipController.text.trim();
      if (rawIp.isNotEmpty) {
        appProvider.updateRtmpLaptopIp(rawIp);
      }
      Navigator.of(context).pop();

      InteractiveToastOverlay.show(
        context,
        title: 'Local RTMP Target Updated',
        message: 'rtmp://${appProvider.rtmpLaptopIp}/live/demo',
        icon: Icons.cell_tower_rounded,
        accentColor: AppTheme.accentGreen,
      );
    } else {
      final rawYoutube = _youtubeUrlController.text.trim();
      if (rawYoutube.isNotEmpty) {
        appProvider.setCustomStreamerYouTubeUrl(rawYoutube);
      }
      Navigator.of(context).pop();

      final videoId = AppProvider.extractYouTubeId(rawYoutube);
      InteractiveToastOverlay.show(
        context,
        title: 'YouTube Live Target Updated',
        message: 'Active Video ID: $videoId',
        icon: Icons.videocam_rounded,
        accentColor: AppTheme.accentRed,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final amir = appProvider.getStreamerById('prof_alghamdi_01');
    final isLive = amir?.isCurrentlyLive ?? false;

    return Dialog(
      backgroundColor: AppTheme.darkSurface3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        side: const BorderSide(color: AppTheme.accentRed, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cell_tower_rounded,
                      color: AppTheme.accentRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'live_studio.director_title'.tr(),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'STUDIO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'live_studio.director_subtitle'.tr(),
                          style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spaceMd),
              const Divider(color: AppTheme.darkBorderSubtle, height: 1),
              const SizedBox(height: AppTheme.spaceMd),

              // 🔴 Amir Al-Hatemi Live Status & Go-Live Control Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: isLive
                      ? AppTheme.accentRed.withValues(alpha: 0.15)
                      : AppTheme.darkSurface1,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                    color: isLive ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLive ? '🔴 AMIR AL-HATEMI IS LIVE' : '⚪ BROADCAST OFFLINE',
                            style: TextStyle(
                              color: isLive ? AppTheme.accentRed : AppTheme.textMutedDark,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isLive
                                ? 'Live notification broadcasted to followers'
                                : 'Click to go live on discovery feed and map',
                            style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    ElevatedButton.icon(
                      onPressed: () {
                        appProvider.toggleBroadcasterGoLive(context);
                      },
                      icon: Icon(
                        isLive ? Icons.stop_circle_rounded : Icons.sensors_rounded,
                        size: 16,
                      ),
                      label: Text(
                        isLive ? 'End Stream' : 'Go Live',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLive ? Colors.red.shade800 : AppTheme.accentRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceMd),

              // Target Selector Tabs: OBS RTMP vs YouTube Live vs Phone Camera
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface1,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.darkBorderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TargetTab(
                        icon: Icons.play_circle_fill_rounded,
                        label: 'YouTube Live',
                        selected: _selectedTarget == BroadcastTargetType.youtubeLive,
                        selectedColor: AppTheme.accentRed,
                        onTap: () => setState(() => _selectedTarget = BroadcastTargetType.youtubeLive),
                      ),
                    ),
                    Expanded(
                      child: _TargetTab(
                        icon: Icons.laptop_chromebook_rounded,
                        label: 'Local OBS',
                        selected: _selectedTarget == BroadcastTargetType.localRtmp,
                        selectedColor: AppTheme.accentBlue,
                        onTap: () => setState(() => _selectedTarget = BroadcastTargetType.localRtmp),
                      ),
                    ),
                    Expanded(
                      child: _TargetTab(
                        icon: Icons.smartphone_rounded,
                        label: 'From Phone',
                        selected: _selectedTarget == BroadcastTargetType.phoneToYoutube,
                        selectedColor: AppTheme.accentGreen,
                        onTap: () => setState(() => _selectedTarget = BroadcastTargetType.phoneToYoutube),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceMd),

              // 🔴 Section 1: YouTube Live Stream Settings
              if (_selectedTarget == BroadcastTargetType.youtubeLive) ...[
                const Text(
                  'YouTube Live URL or Video ID',
                  style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: _youtubeUrlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://youtube.com/watch?v=... or Video ID',
                    hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
                    prefixIcon: const Icon(Icons.link_rounded, color: AppTheme.accentRed, size: 18),
                    filled: true,
                    fillColor: AppTheme.darkSurface1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),

                // Auto-Detect button — scoped to Amir Al-Hatemi's own
                // YouTube channel only, so it always finds *his* current
                // live broadcast instead of relying on a manually pasted
                // link (which fails silently for channel/live URLs).
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: appProvider.isDetectingAmirLiveVideo
                        ? null
                        : () async {
                            final found =
                                await appProvider.autoDetectAmirLiveVideo();
                            if (!context.mounted) return;
                            if (found) {
                              _youtubeUrlController.text =
                                  appProvider.customYouTubeLiveUrl;
                              InteractiveToastOverlay.show(
                                context,
                                title: 'Live Broadcast Detected',
                                message: 'Active Video ID: ${appProvider.customYouTubeVideoId}',
                                icon: Icons.sensors_rounded,
                                accentColor: AppTheme.accentGreen,
                              );
                            } else {
                              InteractiveToastOverlay.show(
                                context,
                                title: 'Broadcast Detection Failed',
                                message: appProvider.amirAutoDetectError ??
                                    'Could not detect an active live video on YouTube.',
                                icon: Icons.error_outline_rounded,
                                accentColor: AppTheme.accentRed,
                              );
                            }
                          },
                    icon: appProvider.isDetectingAmirLiveVideo
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.accentRed,
                            ),
                          )
                        : const Icon(Icons.sensors_rounded, size: 16, color: AppTheme.accentRed),
                    label: Text(
                      appProvider.isDetectingAmirLiveVideo
                          ? 'Detecting...'
                          : "Auto-Detect Amir's Live Video",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentRed,
                      side: const BorderSide(color: AppTheme.accentRed),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),

                // Broadcast Format Selector (Video vs Audio-Only)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => appProvider.setBroadcastType(BroadcastType.liveVideo),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: appProvider.customBroadcastType == BroadcastType.liveVideo
                                ? AppTheme.accentRed.withValues(alpha: 0.2)
                                : AppTheme.darkSurface1,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: appProvider.customBroadcastType == BroadcastType.liveVideo
                                  ? AppTheme.accentRed
                                  : AppTheme.darkBorderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.videocam_rounded,
                                size: 15,
                                color: appProvider.customBroadcastType == BroadcastType.liveVideo
                                    ? AppTheme.accentRed
                                    : AppTheme.textMutedDark,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Video Stream',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: appProvider.customBroadcastType == BroadcastType.liveVideo
                                      ? Colors.white
                                      : AppTheme.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => appProvider.setBroadcastType(BroadcastType.liveAudio),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                          decoration: BoxDecoration(
                            color: appProvider.customBroadcastType == BroadcastType.liveAudio
                                ? const Color(0xFF3F3F46)
                                : AppTheme.darkSurface1,
                            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                            border: Border.all(
                              color: appProvider.customBroadcastType == BroadcastType.liveAudio
                                  ? const Color(0xFFA1A1AA)
                                  : AppTheme.darkBorderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mic_rounded,
                                size: 15,
                                color: appProvider.customBroadcastType == BroadcastType.liveAudio
                                    ? const Color(0xFFE4E4E7)
                                    : AppTheme.textMutedDark,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Audio-Only',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: appProvider.customBroadcastType == BroadcastType.liveAudio
                                      ? Colors.white
                                      : AppTheme.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spaceSm),

                // Helper instructions for YouTube Studio
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface1,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.darkBorderSubtle),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Where to find in YouTube Studio:',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '1. In YouTube Studio, click "Go Live".\n2. Copy the Share / Watch Link (or Video ID) and paste above.\n3. Copy the "Stream Key" and paste into OBS Studio.',
                        style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 10.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],

              // 🔵 Section 2: Local OBS RTMP Settings
              if (_selectedTarget == BroadcastTargetType.localRtmp) ...[
                const Text(
                  'Laptop Local IP Address',
                  style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: _ipController,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'e.g. 192.168.1.100',
                    hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
                    prefixIcon: const Icon(Icons.laptop_rounded, color: AppTheme.accentBlue, size: 18),
                    filled: true,
                    fillColor: AppTheme.darkSurface1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),

                // IP Presets
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _presetIps.map((ip) {
                    final isSelected = _ipController.text.trim() == ip;
                    return ChoiceChip(
                      label: Text(ip),
                      selected: isSelected,
                      selectedColor: AppTheme.accentBlue.withValues(alpha: 0.3),
                      backgroundColor: AppTheme.darkSurface1,
                      side: BorderSide(
                        color: isSelected ? AppTheme.accentBlue : AppTheme.darkBorderSubtle,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected ? AppTheme.accentBlue : AppTheme.textSecondaryDark,
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          _ipController.text = ip;
                        }
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppTheme.spaceSm),

                // OBS Target URL Preview
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.darkBgBase,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.accentBlue.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link_rounded, color: AppTheme.accentBlue, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'rtmp://${_ipController.text.trim().isEmpty ? "..." : _ipController.text.trim()}/live/demo',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
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
              ],

              // 🟢 Section 3: Broadcast From Phone (Camera/Mic -> YouTube RTMP)
              if (_selectedTarget == BroadcastTargetType.phoneToYoutube) ...[
                const Text(
                  'YouTube RTMP Ingest URL',
                  style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: _phoneRtmpUrlController,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'rtmp://a.rtmp.youtube.com/live2',
                    hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
                    prefixIcon: const Icon(Icons.podcasts_rounded, color: AppTheme.accentGreen, size: 18),
                    filled: true,
                    fillColor: AppTheme.darkSurface1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                const Text(
                  'Stream Key',
                  style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: _streamKeyController,
                  obscureText: !_streamKeyVisible,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'xxxx-xxxx-xxxx-xxxx-xxxx',
                    hintStyle: const TextStyle(color: AppTheme.textMutedDark, fontSize: 11.5),
                    prefixIcon: const Icon(Icons.key_rounded, color: AppTheme.accentGreen, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _streamKeyVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppTheme.textMutedDark,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _streamKeyVisible = !_streamKeyVisible),
                    ),
                    filled: true,
                    fillColor: AppTheme.darkSurface1,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      borderSide: const BorderSide(color: AppTheme.darkBorderSubtle),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),

                // Helper instructions for YouTube Studio
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface1,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.darkBorderSubtle),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Where to find in YouTube Studio:',
                        style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 3),
                      Text(
                        '1. In YouTube Studio, click "Go Live".\n2. Open the "Stream" tab.\n3. Copy the Stream URL and Stream Key and paste them above.',
                        style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 10.5, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppTheme.spaceLg),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryDark)),
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedTarget == BroadcastTargetType.phoneToYoutube
                          ? AppTheme.accentGreen
                          : AppTheme.accentRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    child: Text(
                      _selectedTarget == BroadcastTargetType.phoneToYoutube
                          ? 'Open Camera'
                          : 'Save & Apply',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One tab in the broadcast-target selector row. Shared by all three
/// targets (YouTube Live / Local OBS / From Phone) so adding a target only
/// means one more instance, not another copy of the tab markup.
class _TargetTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TargetTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppTheme.textSecondaryDark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
