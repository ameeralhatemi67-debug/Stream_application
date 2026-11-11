import 'organization_surface.dart';
import '../../../core/widgets/ds/ca_icon.dart';
import '../../../core/widgets/ds/ca_cards.dart';
import '../../../core/widgets/ds/ca_rows.dart';
import '../../../core/widgets/ds/ca_button.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/organization_broadcast_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';
import '../models/channel_connection.dart';
import '../models/org_membership.dart';
import 'channel_consent_return_screen.dart';
import '../../live_stream/presentation/widgets/rtmp_ip_dialog.dart'
    show FeatureInProgressModal;

class ChannelConnectionsScreen extends StatefulWidget {
  const ChannelConnectionsScreen({super.key, this.returnStatus});

  /// `connected` or `failed` when Google consent returns to the app.
  final String? returnStatus;
  @override
  State<ChannelConnectionsScreen> createState() =>
      _ChannelConnectionsScreenState();
}

class _ChannelConnectionsScreenState extends State<ChannelConnectionsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _run(Future<void> Function(AppProvider) action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(context.read<AppProvider>());
    } catch (error) {
      if (mounted) {
        setState(() => _error = OrganizationBroadcastService.channelErrorKey(error).tr());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() => _run((p) => p.refreshChannelConnections());
  Future<void> _connect(String? orgId) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return FeatureInProgressModal.show(context,
          title: 'organization_v1.channels'.tr());
    }
    return _run((p) async {
      // Google's return replaces the history: remember the pages under this one.
      final under = (ChannelConsentReturnScreen.currentStack(context) ?? const <String>[])
          .where((l) => !l.startsWith('/channels') && !l.startsWith('/channel-connected'))
          .toList();
      final url = await p.connectYouTubeChannel(organizationId: orgId);
      await p.rememberChannelConsentReturn(under.isEmpty ? const ['/settings'] : under,
          studio: false);
      if (!await launchUrl(url,
          mode: LaunchMode.externalApplication, webOnlyWindowName: '_self')) {
        throw const FunctionException(
            status: 503, details: {'error': 'channel_browser_failed'});
      }
    });
  }
  Widget _channelDetails(ChannelConnection c) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.title, style: Theme.of(context).textTheme.bodyMedium),
            Text(c.channelId, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppTheme.spaceSm),
            CaStatusChip(
                kind: c.connected ? CaStatusKind.verified : CaStatusKind.offline,
                label: 'organization_v1.channel_${c.status}'.tr()),
          ]);

  /// One card per place this account can broadcast to: the channel linked to
  /// it, if any, and the way to link, change or unlink it.
  Widget _destination(
      {required String title,
      required CaGlyph icon,
      String? role,
      ChannelConnection? channel,
      required VoidCallback onConnect}) {
    final linked = channel != null && channel.status != 'disconnected';
    return OrganizationDetailRow(
        title: title,
        details: linked
            ? _channelDetails(channel)
            : role == null
                ? CaIcon(icon)
                : OrganizationChip(label: role, icon: icon),
        action: Wrap(
            spacing: AppTheme.spaceSm,
            runSpacing: AppTheme.spaceSm,
            children: [
              CaButton(
                  onPressed: _busy ? null : onConnect,
                  variant: linked && channel.connected
                      ? CaButtonVariant.secondary
                      : CaButtonVariant.primary,
                  label: (linked
                          ? 'organization_v1.reconnect'
                          : 'organization_v1.connect')
                      .tr(),
                  icon: CaGlyph.video),
              if (linked)
                CaButton(
                    variant: CaButtonVariant.text,
                    onPressed: _busy
                        ? null
                        : () => _run((p) => p.disconnectYouTubeChannel(channel.id)),
                    label: 'organization_v1.disconnect'.tr()),
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final (channels, memberships, personal) = context.select<AppProvider,
            (List<ChannelConnection>, List<OrgMembership>, bool)>(
        (p) => (
              p.channelConnections,
              p.orgMemberships,
              p.personalBroadcastApproved
            ));
    final owners = memberships.where((m) => m.canManageChannel).toList();
    return Scaffold(
        appBar: OrganizationAppBar(context: context,
            title: Text('organization_v1.channels'.tr()),
            // Opened from a return link with nothing underneath: still offer a way out.
            leading: Navigator.canPop(context)
                ? null
                : IconButton(
                    onPressed: () => context.go('/settings'),
                    icon: const CaIcon(CaGlyph.close),
                    tooltip: 'organization_v1.close'.tr()),
            actions: [
              IconButton(
                  onPressed: _busy ? null : _refresh,
                  icon: const CaIcon(CaGlyph.refresh),
                  tooltip: 'organization_v1.refresh'.tr())
            ]),
        body: OrganizationBody(
            child: ListView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                children: [
              CaBanner(message: 'organization_v1.channel_consent_hint'.tr()),
              const SizedBox(height: AppTheme.spaceMd),
              if (widget.returnStatus == 'connected' ||
                  widget.returnStatus == 'failed')
                Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        vertical: AppTheme.spaceSm),
                    child: CaBanner(
                        message:
                            'organization_v1.consent_${widget.returnStatus}'
                                .tr(),
                        kind: widget.returnStatus == 'failed'
                            ? CaBannerKind.error
                            : CaBannerKind.success)),
              if (_busy) const Center(child: HadayahLoadingIndicator()),
              if (_error != null)
                CaBanner(message: _error!, kind: CaBannerKind.error),
              if (personal)
                _destination(
                    title: 'organization_v1.personal_destination'.tr(),
                    icon: CaGlyph.user,
                    channel: channels
                        .where((c) => c.organizationId == null)
                        .firstOrNull,
                    onConnect: () => _connect(null)),
              ...owners.map((m) => _destination(
                  title: context.locale.languageCode == 'ar'
                      ? m.organizationNameAr
                      : m.organizationNameEn,
                  icon: CaGlyph.home,
                  role: 'organization_v1.${m.roleValue}'.tr(),
                  channel: channels
                      .where((c) => c.organizationId == m.organizationId)
                      .firstOrNull,
                  onConnect: () => _connect(m.organizationId))),
              // Channels of organizations this account belongs to without
              // owning them: shown, but only their owner links or unlinks them.
              ...channels
                  .where((c) =>
                      c.organizationId != null &&
                      !owners.any((m) => m.organizationId == c.organizationId))
                  .map((c) => OrganizationDetailRow(
                      title: c.title, details: _channelDetails(c))),
              if (channels.isEmpty && !personal && owners.isEmpty && !_busy)
                CaCard(child: Text('organization_v1.no_channel'.tr())),
            ])));
  }
}
