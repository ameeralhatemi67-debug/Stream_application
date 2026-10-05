import 'package:easy_localization/easy_localization.dart';
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

class ChannelConnectionsScreen extends StatefulWidget {
  const ChannelConnectionsScreen({super.key, this.returnStatus});
  /// `connected` or `failed` when Google consent returns to the app.
  final String? returnStatus;
  @override
  State<ChannelConnectionsScreen> createState() => _ChannelConnectionsScreenState();
}
class _ChannelConnectionsScreenState extends State<ChannelConnectionsScreen> with WidgetsBindingObserver {
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState(); WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }
  Future<void> _run(Future<void> Function(AppProvider) action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try { await action(context.read<AppProvider>()); }
    catch (error) { if (mounted) setState(() => _error = OrganizationBroadcastService.channelErrorKey(error).tr()); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _refresh() => _run((p) => p.refreshChannelConnections());
  Future<void> _connect(String? orgId) => _run((p) async {
    // Google's return replaces the history: remember the pages under this one.
    final under = (ChannelConsentReturnScreen.currentStack(context) ?? const <String>[])
        .where((l) => !l.startsWith('/channels') && !l.startsWith('/channel-connected')).toList();
    final url = await p.connectYouTubeChannel(organizationId:orgId);
    await p.rememberChannelConsentReturn(under.isEmpty ? const ['/settings'] : under, studio:false);
    if (!await launchUrl(url,mode:LaunchMode.externalApplication,webOnlyWindowName:'_self')) {
      throw const FunctionException(status:503,details:{'error':'channel_browser_failed'});
    }
  });
  @override
  Widget build(BuildContext context) {
    final (channels,memberships,personal) = context.select<AppProvider, (List<ChannelConnection>, List<OrgMembership>, bool)>(
      (p) => (p.channelConnections,p.orgMemberships,p.personalBroadcastApproved));
    final owners = memberships.where((m) => m.canManageChannel).toList();
    return Scaffold(appBar:AppBar(title:Text('organization_v1.channels'.tr()),
      // Opened from a return link with nothing underneath: still offer a way out.
      leading:Navigator.canPop(context)?null:IconButton(onPressed:()=>context.go('/settings'),
        icon:const Icon(Icons.close),tooltip:'organization_v1.close'.tr()),
      actions:[
      IconButton(onPressed:_busy?null:_refresh,icon:const Icon(Icons.refresh),tooltip:'organization_v1.refresh'.tr())]),
      body:ListView(padding:const EdgeInsets.all(AppTheme.spaceLg),children:[
        Text('organization_v1.channel_consent_hint'.tr()),
        if (widget.returnStatus == 'connected' || widget.returnStatus == 'failed')
          Padding(padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
            child: Text('organization_v1.consent_${widget.returnStatus}'.tr(),
              style: TextStyle(color: widget.returnStatus == 'failed' ? AppTheme.danger : AppTheme.success))),
        if (_busy) const Center(child:HadayahLoadingIndicator()),
        if (_error != null) Text(_error!,style:const TextStyle(color:AppTheme.danger)),
        if (personal) ListTile(title:Text('organization_v1.personal_destination'.tr()),
          trailing:FilledButton(onPressed:_busy?null:()=>_connect(null),child:Text('organization_v1.connect'.tr()))),
        ...owners.map((m)=>ListTile(title:Text(context.locale.languageCode=='ar'?m.organizationNameAr:m.organizationNameEn),
          trailing:FilledButton(onPressed:_busy?null:()=>_connect(m.organizationId),child:Text('organization_v1.connect'.tr())))),
        ...channels.map((c)=>ListTile(
          title:Text(c.title),subtitle:Text('${c.channelId}\n${'organization_v1.channel_${c.status}'.tr()}'),
          isThreeLine:true,
          trailing:c.ownerId!=context.read<AppProvider>().currentUserSessionId?null:TextButton(
            onPressed:_busy?null:()=>_run((p)=>p.disconnectYouTubeChannel(c.id)),child:Text('organization_v1.disconnect'.tr())))),
        if (channels.isEmpty && !_busy) Text('organization_v1.no_channel'.tr()),
      ]));
  }
}
