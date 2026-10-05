import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import 'rtmp_ip_dialog.dart' show StudioMode;
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_icon.dart';

/// "More info" for the Broadcaster Studio: short, mode-specific help that
/// explains the decision at hand and one useful action (P6S research 06).
///
/// It replaces a quest-style "Streamer Academy" carousel that promised
/// outcomes the app could not confirm and offered a clipboard shortcut for
/// the secret stream key. Each mode says only what this build can do:
/// OBS on a computer and another phone app are external senders the app
/// cannot see; the phone path keeps the screen open and ends on leave;
/// Local is not available.
class StreamerSetupGuideModal extends StatefulWidget {
  final StudioMode mode;
  final int initialPage;

  /// For [StudioMode.obs]: `obs_laptop` or `external_phone`.
  final String externalSender;

  const StreamerSetupGuideModal({
    super.key,
    required this.mode,
    this.externalSender = 'obs_laptop',
    this.initialPage = 0,
  }) : assert(initialPage == 0 || initialPage == 1);

  static Future<void> show(
    BuildContext context, {
    required StudioMode mode,
    String externalSender = 'obs_laptop',
    int initialPage = 0,
  }) {
    return showCaSheet<void>(context,
        title: '',
        framed: false,
        useRootNavigator: false,
        body: Builder(
            builder: (_) => StreamerSetupGuideModal(
                mode: mode,
                externalSender: externalSender,
                initialPage: initialPage)),
        barrierColor: AppTheme.media.withValues(alpha: 0.6));
  }

  @override
  State<StreamerSetupGuideModal> createState() =>
      _StreamerSetupGuideModalState();
}

class _StreamerSetupGuideModalState extends State<StreamerSetupGuideModal> {
  late int _page = widget.initialPage;
  StudioMode get mode => widget.mode;
  String get externalSender => widget.externalSender;

  String get _section => switch (mode) {
        StudioMode.obs =>
          externalSender == 'external_phone' ? 'phone_app' : 'obs',
        StudioMode.phone => 'phone',
        StudioMode.local => 'local',
      };

  List<String> get _stepKeys {
    if (mode == StudioMode.phone) {
      return _page == 0
          ? ['live_guide.watch_help']
          : ['live_guide.key_help', 'live_guide.phone_3', 'live_guide.phone_4'];
    }
    final count = mode == StudioMode.local ? 3 : 4;
    return [for (var i = 1; i <= count; i++) 'live_guide.${_section}_$i'];
  }

  IconData get _icon => switch (_section) {
        'obs' => Icons.laptop_mac_rounded,
        'phone_app' => Icons.smartphone_rounded,
        'phone' => Icons.videocam_rounded,
        _ => Icons.wifi_off_rounded,
      };

  Future<void> _openStudio() async {
    final uri = Uri.parse('https://studio.youtube.com');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return CaSheet(
      key: const Key('studio-guide'),
      title: 'live_guide.title_$_section'.tr(),
      onClose: () => Navigator.of(context).pop(),
      body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, color: AppTheme.primary, size: 22),
            if (mode == StudioMode.phone) ...[
              Row(
                children: [
                  IconButton(
                    key: const Key('studio-guide-previous'),
                    tooltip: 'live_guide.previous_page'.tr(),
                    onPressed:
                        _page == 0 ? null : () => setState(() => _page = 0),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_page + 1} / 2 · ${(_page == 0 ? 'design_copy.youtube_live_link' : 'design_copy.youtube_stream_key').tr()}',
                        key: const Key('studio-guide-page'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('studio-guide-next'),
                    tooltip: 'live_guide.next_page'.tr(),
                    onPressed:
                        _page == 1 ? null : () => setState(() => _page = 1),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                child: Image.asset(
                  _page == 0
                      ? 'assets/images/studio_help/watch_link.png'
                      : 'assets/images/studio_help/stream_key.png',
                  key: ValueKey('studio-guide-image-$_page'),
                  width: double.infinity,
                  fit: BoxFit.contain,
                  semanticLabel: (_page == 0
                          ? 'live_guide.watch_image'
                          : 'live_guide.key_image')
                      .tr(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
            ],
            for (final (i, key) in _stepKeys.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: Canopy.mint,
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                            color: Canopy.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSm),
                    Expanded(
                      child: Text(
                        key.tr(),
                        style: const TextStyle(
                            color: Canopy.slate,
                            fontSize: 13,
                            height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            if (mode != StudioMode.local) ...[
              const SizedBox(height: AppTheme.spaceSm),
              Container(
                key: const Key('studio-guide-link-vs-key'),
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: Canopy.mint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: Canopy.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'live_guide.link_vs_key_title'.tr(),
                      style: const TextStyle(
                          color: Canopy.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppTheme.spaceXs),
                    Text(
                      'live_guide.link_vs_key_body'.tr(),
                      style: const TextStyle(
                          color: Canopy.slate,
                          fontSize: 12.5,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spaceMd),
            ],
          ]),
      actions: [
        if (mode != StudioMode.local)
          CaButton(
              key: const Key('studio-guide-open-studio'),
              label: 'live_guide.open_studio'.tr(),
              icon: CaGlyph.external,
              onPressed: _openStudio)
      ],
    );
  }
}
