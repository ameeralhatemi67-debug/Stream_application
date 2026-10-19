import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/organization_broadcast_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/layout/window_class.dart';
import '../../../../core/widgets/ds/ca_icon.dart';
import '../../../../core/widgets/ds/ca_button.dart';
import '../../../../core/widgets/ds/ca_surfaces.dart';
import '../../../../core/widgets/ds/ca_rows.dart';
import '../../../../core/widgets/ds/ca_fields.dart';
import '../../services/broadcast_publishing_controller.dart';
import '../../services/rtmp_publish_engine.dart';
import '../../../organization/models/channel_connection.dart';
import '../../../organization/models/org_membership.dart';
import '../../../organization/presentation/channel_consent_return_screen.dart';
import '../screens/phone_broadcast_screen.dart';
import 'live_chat_layout.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../web/presentation/hidayah_web_kit.dart';

class FeatureInProgressModal extends StatelessWidget {
  const FeatureInProgressModal({super.key, required this.title});

  final String title;

  static Future<void> show(BuildContext context, {required String title}) =>
      showDialog<void>(
        context: context,
        builder: (_) => FeatureInProgressModal(title: title),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text('live_studio.btn_local_unavailable'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('organization_v1.close'.tr()),
          ),
        ],
      );
}
enum StudioMode { obs, phone, local }

class LiveBroadcasterStudioSheet extends StatefulWidget {
  const LiveBroadcasterStudioSheet(
      {super.key,
      this.initialMode = StudioMode.phone,
      this.onEndBroadcast,
      this.openedFromVideo = false,
      this.consentStatus});
  final StudioMode initialMode;
  final Future<void> Function()? onEndBroadcast;
  final bool openedFromVideo;

  /// `connected` or `failed` when the studio reopens after Google consent.
  final String? consentStatus;
  static Future<void> show(BuildContext context,
      {Future<void> Function()? onEndBroadcast,
      bool openedFromVideo = false,
      String? consentStatus}) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS &&
        !iosPhonePublishingEnabled) {
      return FeatureInProgressModal.show(context,
          title: 'organization_v1.studio'.tr());
    }
    if (context.usesHidayahWeb) {
      // The website studio is a full page: an overview beside the controls.
      final provider = context.read<AppProvider>();
      return showGeneralDialog<void>(
          context: context,
          barrierLabel: 'organization_v1.studio'.tr(),
          transitionDuration: CanopyMotion.sheetIn,
          pageBuilder: (_, __, ___) => ChangeNotifierProvider<AppProvider>.value(
              value: provider,
              child: LiveBroadcasterStudioSheet(
                  onEndBroadcast: onEndBroadcast,
                  openedFromVideo: openedFromVideo,
                  consentStatus: consentStatus)));
    }
    return showCaSheet<void>(context,
        title: 'organization_v1.studio'.tr(),
        job: CaSheetJob.studio,
        framed: false,
        fullWidthOnPhone: true,
        edgeColor: paletteColor(context, Canopy.forestDeep),
        body: ChangeNotifierProvider<AppProvider>.value(
            value: context.read<AppProvider>(),
            child: LiveBroadcasterStudioSheet(
                onEndBroadcast: onEndBroadcast,
                openedFromVideo: openedFromVideo,
                consentStatus: consentStatus)));
  }
  @override
  State<LiveBroadcasterStudioSheet> createState() => _StudioState();
}

class _StudioState extends State<LiveBroadcasterStudioSheet> {
  late final BroadcastPublishingController _studio;
  final _title = TextEditingController();
  final _credentials = TextEditingController();
  BroadcastQualityPreset _quality = BroadcastQualityPreset.medium;
  bool _audio = false, _showKey = false, _connecting = false;
  String? _loadError, _connectError;
  bool get _phoneAvailable => phonePublishingAvailable;
  @override
  void initState() {
    super.initState();
    _studio = BroadcastPublishingController(context.read<AppProvider>());
    _studio.sender = widget.initialMode == StudioMode.phone && _phoneAvailable
        ? 'phone_direct'
        : 'obs_laptop';
    _studio.addListener(_changed);
    if (widget.initialMode != StudioMode.local) _load();
  }

  void _changed() {
    if (_credentials.text != _studio.ingestKey) {
      _credentials.text = _studio.ingestKey;
    }
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      await _studio.load();
      if (mounted) setState(() => _loadError = null);
      _prewarm();
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'organization_v1.publish_failure');
      }
    }
  }

  String get _defaultTitle => 'organization_v1.default_title'
      .tr(namedArgs: {'channel': _studio.destination?.title ?? ''});

  /// Starts the YouTube handshake while the presenter picks options, so
  /// Preview opens the camera without waiting for it.
  void _prewarm() {
    if (!mounted || widget.onEndBroadcast != null) return;
    _studio.prewarm(
        title: _defaultTitle, type: _audio ? 'liveAudio' : 'liveVideo');
  }

  @override
  void dispose() {
    _studio.removeListener(_changed);
    _studio.dispose();
    _title.dispose();
    _credentials.dispose();
    super.dispose();
  }

  /// Starts Google consent straight from the studio. The return link reopens
  /// the studio where this started (see `/channel-connected` in AppRouter).
  Future<void> _connectYouTube() async {
    if (_connecting) return;
    final provider = context.read<AppProvider>();
    final ar = context.locale.languageCode == 'ar';
    final targets = <(String?, String)>[
      if (provider.personalBroadcastApproved)
        (null, 'organization_v1.personal_destination'.tr()),
      ...provider.orgMemberships.where((m) => m.canManageChannel).map((m) =>
          (m.organizationId, ar ? m.organizationNameAr : m.organizationNameEn)),
    ];
    if (targets.isEmpty) {
      setState(() =>
          _connectError = 'organization_v1.channel_permission_required');
      return;
    }
    final target = targets.length == 1
        ? (targets.single.$1,)
        : await showCaDialog<(String?,)>(
            context: context,
            builder: (dialog) => CaAlertDialog(
                title: Text('organization_v1.destination'.tr()),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final t in targets)
                    CaButton(
                        label: t.$2,
                        variant: CaButtonVariant.text,
                        onPressed: () => Navigator.pop(dialog, (t.$1,)))
                ])));
    if (target == null || !mounted) return;
    final stack = ChannelConsentReturnScreen.currentStack(context);
    setState(() {
      _connecting = true;
      _connectError = null;
    });
    try {
      final url =
          await provider.connectYouTubeChannel(organizationId: target.$1);
      if (stack != null) {
        await provider.rememberChannelConsentReturn(stack, studio: true);
      }
      if (!await launchUrl(url,
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_self')) {
        throw const FunctionException(
            status: 503, details: {'error': 'channel_browser_failed'});
      }
    } catch (error) {
      if (mounted) {
        setState(() =>
            _connectError = OrganizationBroadcastService.channelErrorKey(error));
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _prepare() async {
    if (widget.onEndBroadcast != null && _studio.sender == 'phone_direct') {
      return;
    }
    final typed = _title.text.trim();
    // The title is optional: an empty one becomes "<channel> – Live".
    final title = typed.isNotEmpty ? typed : _defaultTitle;
    if (!await _studio.prepare(title, _audio ? 'liveAudio' : 'liveVideo') ||
        !mounted) {
      return;
    }
    if (_studio.sender == 'phone_direct') {
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.push(MaterialPageRoute<void>(
          builder: (_) => PhoneBroadcastScreen(
              quickLaunchPreset: _quality, autoStart: false)));
    }
  }

  Future<void> _start() async {
    await context.read<AppProvider>().setBroadcasterLive(true);
    if (mounted) setState(() {});
  }

  Future<void> _end() async {
    if (widget.onEndBroadcast != null) {
      Navigator.pop(context);
      await widget.onEndBroadcast!();
    } else {
      await _studio.end();
    }
    if (mounted) setState(() {});
  }

  /// [parts] is the sheet: its title bar, the scrolling controls and, when
  /// present, the action footer. The website studio swaps the title bar for a
  /// page bar and sets an overview beside the controls.
  Widget _frame(BuildContext context, List<Widget> parts,
      {required bool live, required bool frozen}) {
    if (!context.usesHidayahWeb) {
      return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: parts);
    }
    return ColoredBox(
        color: HidayahGold.s950,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _webBar(context, live),
          Expanded(
              child: HidayahWebWidth(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                                child: SingleChildScrollView(
                                    child: _webOverview(context, live, frozen))),
                            const SizedBox(width: 28),
                            SizedBox(
                                width: 480,
                                child: Container(
                                    decoration: BoxDecoration(
                                        color: HidayahGold.s900,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: HidayahGold.s800)),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: parts.sublist(1)))),
                          ])))),
        ]));
  }

  Widget _webBar(BuildContext context, bool live) => Container(
      height: HidayahWeb.headerHeight,
      decoration: const BoxDecoration(
          color: HidayahGold.s900,
          border: Border(bottom: BorderSide(color: HidayahGold.s800))),
      child: HidayahWebWidth(
          child: Row(children: [
        const AppLogo(size: 36),
        const SizedBox(width: 12),
        Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('organization_v1.studio'.tr(),
                  style: HidayahText.display(21, color: HidayahGold.g50)),
              Text('web.studio_sub'.tr(),
                  style: HidayahText.body(12, color: HidayahGold.s300, height: 1.3)),
            ]),
        const Spacer(),
        live
            ? HidayahLiveBadge(label: 'web.badge_live'.tr())
            : HidayahGlassBadge(label: 'web.studio_offline'.tr()),
        const SizedBox(width: 12),
        const CaLanguageChip(glass: true, compact: true, bare: true),
        const SizedBox(width: 8),
        HidayahButton(
            label: 'organization_v1.close'.tr(),
            icon: CaGlyph.close,
            kind: HidayahButtonKind.onDark,
            compact: true,
            onPressed: () => Navigator.pop(context)),
      ])));

  Widget _webOverview(BuildContext context, bool live, bool frozen) {
    final destination = _studio.destination?.title ?? '';
    final steps = [
      ('web.studio_step1'.tr(), destination.isNotEmpty),
      ('web.studio_step2'.tr(), frozen),
      ('web.studio_step3'.tr(), live),
    ];
    final status = live
        ? 'web.studio_live'
        : frozen
            ? 'web.studio_ready'
            : 'web.studio_setup';
    Widget fact(String label, String value) => Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(HidayahText.upper(context, label),
              style: HidayahText.eyebrow(context, HidayahGold.g300)),
          const SizedBox(height: 6),
          Text(value.isEmpty ? '—' : value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: HidayahText.body(15,
                  color: HidayahGold.g50, weight: FontWeight.w700, height: 1.35)),
        ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      HidayahNightBand(
          radius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status.tr(),
                        style: HidayahText.display(30, color: HidayahGold.g50)),
                    const SizedBox(height: 6),
                    Text('${status}_body'.tr(),
                        style: HidayahText.body(14.5, color: HidayahGold.s300)),
                    const SizedBox(height: 24),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      fact('web.studio_destination'.tr(), destination),
                      fact(
                          'web.studio_sender'.tr(),
                          (_studio.sender == 'phone_direct'
                                  ? (iosPhonePublishingEnabled
                                      ? 'organization_v1.sender_ios'
                                      : 'organization_v1.sender_android')
                                  : 'organization_v1.sender_obs')
                              .tr()),
                      fact('web.studio_format'.tr(),
                          (_audio ? 'organization_v1.audio' : 'design_copy.video')
                              .tr()),
                    ]),
                  ]))),
      const SizedBox(height: 20),
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: HidayahGold.s900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HidayahGold.s800)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('web.studio_steps'.tr(),
                style: HidayahText.display(19, color: HidayahGold.g50)),
            const SizedBox(height: 16),
            for (var i = 0; i < steps.length; i++)
              Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: steps[i].$2 ? HidayahGradients.minted : null,
                            border: steps[i].$2
                                ? null
                                : Border.all(color: HidayahGold.s600)),
                        child: Center(
                            child: steps[i].$2
                                ? const CaIcon(CaGlyph.check,
                                    color: HidayahGold.s900, size: 16)
                                : Text('${i + 1}',
                                    style: HidayahText.body(13,
                                        color: HidayahGold.s300,
                                        weight: FontWeight.w700,
                                        height: 1)))),
                    const SizedBox(width: 14),
                    Expanded(
                        child: Text(steps[i].$1,
                            style: HidayahText.body(15,
                                color: steps[i].$2
                                    ? HidayahGold.g50
                                    : HidayahGold.s300,
                                weight: FontWeight.w600,
                                height: 1.4))),
                  ])),
          ])),
      const SizedBox(height: 20),
      Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: HidayahGold.s900,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HidayahGold.s800)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const CaIcon(CaGlyph.info, color: HidayahGold.g300, size: 20),
              const SizedBox(width: 10),
              Text('web.studio_help'.tr(),
                  style: HidayahText.display(19, color: HidayahGold.g50)),
            ]),
            const SizedBox(height: 10),
            Text('organization_v1.obs_hint'.tr(),
                style: HidayahText.body(14, color: HidayahGold.s200)),
          ])),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.openedFromVideo && isCompactLandscapeChat(context)) {
      return SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('live.landscape_settings_portrait'.tr()),
                if (widget.onEndBroadcast != null)
                  OutlinedButton(
                      onPressed: _end, child: Text('organization_v1.end'.tr())),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('organization_v1.close'.tr())),
              ])));
    }
    if (widget.initialMode == StudioMode.local) {
      return SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                  key: const ValueKey('local-unavailable'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('live_studio.local_unavailable_body'.tr()),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('organization_v1.close'.tr()))
                  ])));
    }

    final (_, _, _, live, error) = context.select<
            AppProvider,
            (List<ChannelConnection>, List<OrgMembership>, bool, bool, String?)>(
        (p) => (
              p.channelConnections,
              p.orgMemberships,
              p.personalBroadcastApproved,
              p.isBroadcastingLive,
              p.broadcastSessionError
            ));
    final destinations = _studio.destinations;
    final frozen = _studio.frozen;
    final operationBusy =
        context.select<AppProvider, bool>((p) => p.broadcastOperationBusy) ||
            _studio.busy;
    final choices = _studio.assignments
        .where((s) => s.organizationId == _studio.destination?.organizationId)
        .toList();
    if (_studio.session != null &&
        !choices.any((s) => s.id == _studio.session!.id)) {
      choices.add(_studio.session!);
    }
    final pending = context.select<AppProvider, bool>(
        (p) => p.publishingSession?.terminationPending == true);
    final canPrepare = destinations.isNotEmpty &&
        _studio.session?.state != 'ending' &&
        widget.onEndBroadcast == null;
    final canStart = frozen &&
        _studio.ingestKey.isNotEmpty &&
        _studio.sender == 'obs_laptop' &&
        !live;
    // While typing the title, the keyboard needs the room; Preview/Prepare
    // returns as soon as it closes.
    final keyboardOpen = View.of(context).viewInsets.bottom > 0;
    return Material(
        color: paletteColor(context, Canopy.forestDeep),
        child: Theme(
            data: Theme.of(context).copyWith(
                inputDecorationTheme: Theme.of(context)
                    .inputDecorationTheme
                    .copyWith(
                        counterStyle: TextStyle(color: paletteColor(context, Canopy.mist))),
                textTheme: Theme.of(context)
                    .textTheme
                    .apply(bodyColor: paletteColor(context, Canopy.paper), displayColor: paletteColor(context, Canopy.paper)),
                iconTheme: IconThemeData(color: paletteColor(context, Canopy.paper)),
                colorScheme: Theme.of(context).colorScheme.copyWith(
                    onSurface: paletteColor(context, Canopy.paper),
                    surface: paletteColor(context, Canopy.forestDeep),
                    primary: paletteColor(context, Canopy.mist),
                    onPrimary: paletteColor(context, Canopy.ink))),
            child: Builder(
                builder: (context) => DefaultTextStyle.merge(
                    style: TextStyle(color: paletteColor(context, Canopy.paper)),
                    child: SafeArea(
                        child: _frame(context, live: live, frozen: frozen, [
                          ColoredBox(
                              color: paletteColor(context, Canopy.forestDeep),
                              child: Padding(
                                  // Title lines up with the content below it.
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      AppTheme.spaceLg,
                                      AppTheme.spaceMd,
                                      AppTheme.spaceXs,
                                      AppTheme.spaceXs),
                                  child: DefaultTextStyle.merge(
                                      style:
                                          TextStyle(color: paletteColor(context, Canopy.paper)),
                                      child: IconTheme.merge(
                                          data: IconThemeData(
                                              color: paletteColor(context, Canopy.paper)),
                                          child: Row(children: [
                                            Expanded(
                                                child: Text(
                                                    'organization_v1.studio'
                                                        .tr(),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge
                                                        ?.copyWith(
                                                            color: paletteColor(context, Canopy.paper),
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700))),
                                            const CaLanguageChip(
                                                glass: true,
                                                compact: true,
                                                bare: true),
                                            IconButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                tooltip: 'organization_v1.close'
                                                    .tr(),
                                                icon: const Icon(Icons.close))
                                          ]))))),
                          Flexible(
                              child: SingleChildScrollView(
                                  padding:
                                      const EdgeInsets.all(AppTheme.spaceLg),
                                  child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (context.isPhoneLandscape)
                                          Text(
                                              'live.landscape_settings_portrait'
                                                  .tr()),
                                        if (!frozen) ...[
                                          CaSegmentedTabs(
                                              dark: true,
                                              labels: [
                                                'organization_v1.sender_obs'
                                                    .tr(),
                                                (iosPhonePublishingEnabled
                                                    ? 'organization_v1.sender_ios'
                                                    : 'organization_v1.sender_android')
                                                    .tr()
                                              ],
                                              disabledIndices: {
                                                if (operationBusy) 0,
                                                if (operationBusy || !_phoneAvailable)
                                                  1
                                              },
                                              index: _studio.sender ==
                                                      'phone_direct'
                                                  ? 1
                                                  : 0,
                                              onChanged: (index) {
                                                setState(() => _studio.sender =
                                                    index == 0
                                                        ? 'obs_laptop'
                                                        : 'phone_direct');
                                                // The background preparation is
                                                // for this phone only.
                                                if (index == 0) {
                                                  _studio.discardWarm();
                                                } else {
                                                  _prewarm();
                                                }
                                              }),
                                          const SizedBox(
                                              height: AppTheme.spaceMd),
                                          if (_studio.destination
                                                  ?.organizationId ==
                                              null)
                                            CaSegmentedTabs(
                                                dark: true,
                                                labels: [
                                                  'design_copy.video'.tr(),
                                                  'organization_v1.audio'.tr()
                                                ],
                                                index: _audio ? 1 : 0,
                                                onChanged: (index) => setState(
                                                    () => _audio = index == 1)),
                                          if (!_phoneAvailable)
                                            Text(
                                                'live_studio.error_phone_unsupported'
                                                    .tr(),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall),
                                          if (_studio.sender ==
                                              'phone_direct') ...[
                                            const SizedBox(
                                                height: AppTheme.spaceMd),
                                            CaQualityPresets<
                                                    BroadcastQualityPreset>(
                                                cinema: true,
                                                options: [
                                                  for (final preset
                                                      in BroadcastQualityPreset
                                                          .values)
                                                    (
                                                      value: preset,
                                                      label:
                                                          '${preset.height}p',
                                                      detail:
                                                          '${preset.videoBitrateBps ~/ 1000} kbps'
                                                    )
                                                ],
                                                value: _quality,
                                                onChanged: operationBusy
                                                    ? null
                                                    : (preset) => setState(() =>
                                                        _quality = preset)),
                                          ],
                                        ],
                                        const SizedBox(
                                            height: AppTheme.spaceMd),
                                        Text('organization_v1.publish_hint'
                                            .tr()),
                                        if (_loadError != null)
                                          Text(_loadError!.tr(),
                                              style: TextStyle(
                                                  color: paletteColor(context, Canopy.errorTint))),
                                        if (widget.consentStatus ==
                                                'connected' ||
                                            widget.consentStatus == 'failed')
                                          Text(
                                              'organization_v1.consent_${widget.consentStatus}'
                                                  .tr(),
                                              style: TextStyle(
                                                  color: widget.consentStatus ==
                                                          'failed'
                                                      ? paletteColor(context, Canopy.errorTint)
                                                      : paletteColor(context, Canopy.mint))),
                                        if (destinations.isEmpty) ...[
                                          const SizedBox(
                                              height: AppTheme.spaceSm),
                                          Text(
                                              'organization_v1.connect_before_live'
                                                  .tr()),
                                          const SizedBox(
                                              height: AppTheme.spaceSm),
                                          CaButton(
                                              label:
                                                  'organization_v1.connect'.tr(),
                                              icon: CaGlyph.video,
                                              loading: _connecting,
                                              onPressed: _connecting
                                                  ? null
                                                  : _connectYouTube),
                                        ] else
                                          TextButton(
                                              onPressed: _connecting || frozen
                                                  ? null
                                                  : _connectYouTube,
                                              style: TextButton.styleFrom(
                                                  foregroundColor: paletteColor(context, Canopy.mint)),
                                              child: Text(
                                                  'organization_v1.reconnect'
                                                      .tr())),
                                        if (_connectError != null)
                                          Text(_connectError!.tr(),
                                              style: TextStyle(
                                                  color: paletteColor(context, Canopy.errorTint))),
                                        if (_studio.simplePersonalDestination)
                                          Text('organization_v1.going_live_on'
                                              .tr(namedArgs: {
                                            'channel':
                                                _studio.destination!.title
                                          }))
                                        else if (destinations.isNotEmpty) ...[
                                          Text(
                                              'organization_v1.destination'
                                                  .tr(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge),
                                          const SizedBox(
                                              height: AppTheme.spaceSm),
                                          DropdownButtonFormField<String>(
                                            key: ValueKey(
                                                _studio.destination?.id),
                                            initialValue:
                                                _studio.destination?.id,
                                            isExpanded: true,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(color: paletteColor(context, Canopy.ink)),
                                            dropdownColor: paletteColor(context, Canopy.mint),
                                            decoration: InputDecoration(
                                                filled: true,
                                                fillColor: paletteColor(context, Canopy.mint)),
                                            items: destinations
                                                .map((c) => DropdownMenuItem(
                                                    value: c.id,
                                                    child: Text(c.title,
                                                        overflow: TextOverflow
                                                            .ellipsis)))
                                                .toList(),
                                            onChanged: frozen || operationBusy
                                                ? null
                                                : (id) {
                                                    setState(() {
                                                      _studio.destination =
                                                          destinations
                                                              .where((c) =>
                                                                  c.id == id)
                                                              .firstOrNull;
                                                      _studio.session = null;
                                                      _studio.confirmed = false;
                                                    });
                                                    _studio.discardWarm();
                                                    _prewarm();
                                                  }),
                                        ],
                                        if (_studio
                                                .destination?.organizationId !=
                                            null) ...[
                                          Text(
                                              'organization_v1.assignment'.tr(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelLarge),
                                          const SizedBox(
                                              height: AppTheme.spaceSm),
                                          DropdownButtonFormField<String>(
                                              key: ValueKey(
                                                  _studio.destination!.id),
                                              initialValue: _studio.session?.id,
                                              isExpanded: true,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(color: paletteColor(context, Canopy.ink)),
                                              dropdownColor: paletteColor(context, Canopy.mint),
                                              decoration: InputDecoration(
                                                  filled: true,
                                                  fillColor: paletteColor(context, Canopy.mint)),
                                              items: choices
                                                  .map((s) => DropdownMenuItem(
                                                      value: s.id,
                                                      child: Text(s.title(context.locale.languageCode),
                                                          overflow: TextOverflow
                                                              .ellipsis)))
                                                  .toList(),
                                              onChanged: frozen || operationBusy
                                                  ? null
                                                  : (id) => setState(() => _studio.session = choices
                                                      .where((s) => s.id == id)
                                                      .firstOrNull)),
                                          TextButton(
                                              onPressed: () =>
                                                  context.push('/shows'),
                                              child: Text(
                                                  'organization_v1.shows'
                                                      .tr())),
                                        ] else if (!frozen) ...[
                                          CaInput(
                                              label:
                                                  'organization_v1.title_optional'
                                                      .tr(),
                                              controller: _title,
                                              maxLength: 100,
                                              readOnly:
                                                  context.isPhoneLandscape),
                                        ],
                                        if (destinations.isNotEmpty &&
                                            _studio.session?.state != 'ending')
                                          SwitchListTile(
                                              key: const Key(
                                                  'studio-hide-replay'),
                                              contentPadding: EdgeInsets.zero,
                                              value: _studio.hideReplay,
                                              activeThumbColor: paletteColor(
                                                  context, Canopy.mint),
                                              onChanged: operationBusy
                                                  ? null
                                                  : (value) => _studio
                                                      .setHideReplay(value),
                                              title: Text(
                                                  'live.hide_replay'.tr()),
                                              subtitle: Text(
                                                  'live.hide_replay_sub'.tr(),
                                                  style: TextStyle(
                                                      color: paletteColor(
                                                          context,
                                                          Canopy.mist)))),
                                        if (frozen &&
                                            _studio.ingestKey.isNotEmpty &&
                                            _studio.sender == 'obs_laptop') ...[
                                          Text('organization_v1.obs_hint'.tr()),
                                          SelectableText(_studio.ingestUrl),
                                          const SizedBox(
                                              height: AppTheme.spaceMd),
                                          Row(children: [
                                            Expanded(
                                                child: TextField(
                                                    controller: _credentials,
                                                    readOnly: true,
                                                    obscureText: !_showKey,
                                                    textDirection:
                                                        TextDirection.ltr,
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            'design_copy.stream_key'
                                                                .tr()))),
                                            IconButton(
                                                onPressed: () => setState(
                                                    () => _showKey = !_showKey),
                                                tooltip:
                                                    'organization_v1.show_key'
                                                        .tr(),
                                                icon: const Icon(
                                                    Icons.visibility)),
                                            IconButton(
                                                onPressed: () =>
                                                    Clipboard.setData(
                                                        ClipboardData(
                                                            text: _studio
                                                                .ingestKey)),
                                                tooltip:
                                                    'organization_v1.copy_key'
                                                        .tr(),
                                                icon: const Icon(Icons.copy))
                                          ]),
                                        ],
                                        if (frozen)
                                          OutlinedButton(
                                              onPressed:
                                                  operationBusy ? null : _end,
                                              child: Text(
                                                  'organization_v1.end'.tr())),
                                        if (live)
                                          Text('organization_v1.live'.tr()),
                                        if (pending)
                                          Text(
                                              'organization_v1.termination_pending'
                                                  .tr()),
                                        if (_studio.errorKey != null ||
                                            error != null)
                                          Text(
                                              (_studio.errorKey ?? error!).tr(),
                                              style: TextStyle(
                                                  color: paletteColor(context, Canopy.errorTint))),
                                        TextButton(
                                            onPressed:
                                                operationBusy ? null : _load,
                                            style: TextButton.styleFrom(
                                                foregroundColor: paletteColor(context, Canopy.mint)),
                                            child: Text(
                                                'organization_v1.refresh'
                                                    .tr())),
                                      ]))),
                          if ((canPrepare || canStart) && !keyboardOpen)
                            Padding(
                                padding: const EdgeInsets.all(AppTheme.spaceLg),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (canPrepare &&
                                          !_studio.simplePersonalDestination)
                                        CheckboxListTile(
                                            contentPadding: EdgeInsets.zero,
                                            value: _studio.confirmed,
                                            onChanged: operationBusy
                                                ? null
                                                : (v) => setState(() => _studio
                                                    .confirmed = v ?? false),
                                            title: Text(
                                                'organization_v1.confirm_destination'
                                                    .tr(namedArgs: {
                                              'channel':
                                                  _studio.destination?.title ??
                                                      ''
                                            }))),
                                      if (canStart) ...[
                                        CaButton(
                                            label: 'organization_v1.start'.tr(),
                                            onPressed:
                                                operationBusy ? null : _start),
                                        // Recovery remains available without presenting two primary actions.
                                        if (canPrepare)
                                          TextButton(
                                              onPressed: operationBusy ||
                                                      !_studio.confirmed
                                                  ? null
                                                  : _prepare,
                                              child: Text(
                                                  'organization_v1.prepare'
                                                      .tr())),
                                      ] else if (canPrepare)
                                        CaButton(
                                            label: (_studio.sender ==
                                                        'phone_direct'
                                                    ? 'organization_v1.preview'
                                                    : 'organization_v1.prepare')
                                                .tr(),
                                            loading: _studio.busy,
                                            onPressed: operationBusy ||
                                                    !_studio.confirmed
                                                ? null
                                                : _prepare),
                                    ])),
                        ]))))));
  }
}
