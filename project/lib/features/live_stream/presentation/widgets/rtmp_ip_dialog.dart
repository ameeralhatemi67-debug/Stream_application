import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/hadayah_loading_indicator.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../services/broadcast_publishing_controller.dart';
import '../../services/rtmp_publish_engine.dart';
import '../../../organization/models/channel_connection.dart';
import '../../../organization/models/org_membership.dart';
import '../screens/phone_broadcast_screen.dart';
import 'live_chat_layout.dart';

enum StudioMode { obs, phone, local }

class LiveBroadcasterStudioSheet extends StatefulWidget {
  const LiveBroadcasterStudioSheet({super.key,this.initialMode=StudioMode.obs,this.onEndBroadcast,this.openedFromVideo=false});
  final StudioMode initialMode;
  final Future<void> Function()? onEndBroadcast;
  final bool openedFromVideo;
  static Future<void> show(BuildContext context,{Future<void> Function()? onEndBroadcast,bool openedFromVideo=false}) =>
    showModalBottomSheet<void>(context:context,isScrollControlled:true,
      builder:(_)=>LiveBroadcasterStudioSheet(onEndBroadcast:onEndBroadcast,openedFromVideo:openedFromVideo));
  @override
  State<LiveBroadcasterStudioSheet> createState()=>_StudioState();
}

class _StudioState extends State<LiveBroadcasterStudioSheet> {
  late final BroadcastPublishingController _studio;
  final _title=TextEditingController();
  bool _audio=false,_showKey=false;
  String? _loadError;
  bool get _android=>!kIsWeb&&defaultTargetPlatform==TargetPlatform.android;
  @override
  void initState(){
    super.initState();_studio=BroadcastPublishingController(context.read<AppProvider>());
    _studio.sender=widget.initialMode==StudioMode.phone&&_android?'phone_direct':'obs_laptop';
    _studio.addListener(_changed);if(widget.initialMode!=StudioMode.local)_load();
  }
  void _changed(){if(mounted)setState((){});}
  Future<void> _load() async {
    try {await _studio.load();if(mounted)setState(()=>_loadError=null);}
    catch(_){if(mounted)setState(()=>_loadError='organization_v1.publish_failure');}
  }
  @override
  void dispose(){_studio.removeListener(_changed);_studio.dispose();_title.dispose();super.dispose();}
  Future<void> _prepare() async {
    if(widget.onEndBroadcast!=null && _studio.sender=='phone_direct') return;
    if(!await _studio.prepare(_title.text.trim(),_audio?'liveAudio':'liveVideo')||!mounted)return;
    if(_studio.sender=='phone_direct') {
      final navigator=Navigator.of(context);
      navigator.pop();
      navigator.push(MaterialPageRoute<void>(builder:(_)=>const PhoneBroadcastScreen(quickLaunchPreset:BroadcastQualityPreset.medium)));
    }
  }
  Future<void> _start() async {
    await context.read<AppProvider>().setBroadcasterLive(true);
    if(mounted)setState((){});
  }
  Future<void> _end() async {
    if(widget.onEndBroadcast!=null) { Navigator.pop(context); await widget.onEndBroadcast!(); }
    else { await _studio.end(); }
    if(mounted)setState((){});
  }
  @override
  Widget build(BuildContext context){
    if(widget.openedFromVideo && isCompactLandscapeChat(context)) { return SafeArea(child:SingleChildScrollView(
      padding:const EdgeInsets.all(AppTheme.spaceLg),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text('live.landscape_settings_portrait'.tr()),
        if(widget.onEndBroadcast!=null) OutlinedButton(onPressed:_end,child:Text('organization_v1.end'.tr())),
        TextButton(onPressed:()=>Navigator.pop(context),child:Text('organization_v1.close'.tr())),
      ]))); }
    if(widget.initialMode==StudioMode.local) { return SafeArea(child:Padding(padding:const EdgeInsets.all(AppTheme.spaceLg),
      child:Column(key:const ValueKey('local-unavailable'),mainAxisSize:MainAxisSize.min,children:[
        Text('live_studio.local_unavailable_body'.tr()),TextButton(onPressed:()=>Navigator.pop(context),child:Text('organization_v1.close'.tr()))]))); }

    final (connections,memberships,personal,live,error)=context.select<AppProvider,(List<ChannelConnection>,List<OrgMembership>,bool,bool,String?)>(
      (p)=>(p.channelConnections,p.orgMemberships,p.personalBroadcastApproved,p.isBroadcastingLive,p.broadcastSessionError));
    final destinations=connections.where((c)=>c.id==_studio.destination?.id || c.connected&&(c.organizationId==null
      ?personal:memberships.any((m)=>m.organizationId==c.organizationId&&m.active&&
        (m.permissions.canGoLiveVideo||m.permissions.canGoAudioOnly)))).toList();
    final frozen=_studio.frozen;
    final operationBusy=context.select<AppProvider,bool>((p)=>p.broadcastOperationBusy)||_studio.busy;
    final choices=_studio.assignments.where((s)=>s.organizationId==_studio.destination?.organizationId).toList();
    if(_studio.session!=null && !choices.any((s)=>s.id==_studio.session!.id)) choices.add(_studio.session!);
    final pending=context.select<AppProvider,bool>((p)=>p.publishingSession?.terminationPending==true);
    return Material(color:AppTheme.surface,child:SafeArea(child:SingleChildScrollView(
      padding:EdgeInsets.fromLTRB(AppTheme.spaceLg,AppTheme.spaceLg,AppTheme.spaceLg,AppTheme.spaceLg+MediaQuery.viewInsetsOf(context).bottom),
      child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[Expanded(child:Text('organization_v1.studio'.tr(),style:Theme.of(context).textTheme.titleLarge)),
          const LanguageSwitcher(showLabel:false),
          IconButton(onPressed:()=>Navigator.pop(context),tooltip:'organization_v1.close'.tr(),icon:const Icon(Icons.close))]),
        Text('organization_v1.publish_hint'.tr()),
        if(_loadError!=null) Text(_loadError!.tr(),style:const TextStyle(color:AppTheme.danger)),
        TextButton(onPressed:()=>context.push('/channels'),child:Text('organization_v1.channels'.tr())),
        DropdownButtonFormField<String>(key:ValueKey(_studio.destination?.id),initialValue:_studio.destination?.id,
          isExpanded:true,decoration:InputDecoration(labelText:'organization_v1.destination'.tr()),
          items:destinations.map((c)=>DropdownMenuItem(value:c.id,child:Text(c.title,overflow:TextOverflow.ellipsis))).toList(),
          onChanged:frozen||operationBusy?null:(id)=>setState((){_studio.destination=destinations.where((c)=>c.id==id).firstOrNull;
            _studio.session=null;_studio.confirmed=false;})),
        if(_studio.destination?.organizationId!=null) ...[
          DropdownButtonFormField<String>(key:ValueKey(_studio.destination!.id),initialValue:_studio.session?.id,
            isExpanded:true,decoration:InputDecoration(labelText:'organization_v1.assignment'.tr()),
            items:choices.map((s)=>DropdownMenuItem(value:s.id,child:Text(s.title(context.locale.languageCode),overflow:TextOverflow.ellipsis))).toList(),
            onChanged:frozen||operationBusy?null:(id)=>setState(()=>_studio.session=choices.where((s)=>s.id==id).firstOrNull)),
          TextButton(onPressed:()=>context.push('/shows'),child:Text('organization_v1.shows'.tr())),
        ] else if(!frozen) ...[
          TextField(controller:_title,maxLength:100,decoration:InputDecoration(labelText:'organization_v1.title'.tr())),
          SwitchListTile(title:Text('organization_v1.audio'.tr()),value:_audio,onChanged:(v)=>setState(()=>_audio=v)),
        ],
        if(!frozen) ...[
          SegmentedButton<String>(segments:[ButtonSegment(value:'obs_laptop',label:Text('organization_v1.sender_obs'.tr()),icon:const Icon(Icons.computer)),
            if(_android) ButtonSegment(value:'phone_direct',label:Text('organization_v1.sender_android'.tr()),icon:const Icon(Icons.phone_android))],
            selected:{_studio.sender},onSelectionChanged:(v)=>setState(()=>_studio.sender=v.single)),
        ],
        if(_studio.session?.state!='ending' && widget.onEndBroadcast==null) ...[
          CheckboxListTile(value:_studio.confirmed,onChanged:operationBusy?null:(v)=>setState(()=>_studio.confirmed=v??false),
            title:Text('organization_v1.confirm_destination'.tr(namedArgs:{'channel':_studio.destination?.title??''}))),
          FilledButton(onPressed:operationBusy||!_studio.confirmed?null:_prepare,child:_studio.busy?
            const SizedBox(width:20,height:20,child:HadayahLoadingIndicator()):Text('organization_v1.prepare'.tr())),
        ],
        if(frozen&&_studio.ingestKey.isNotEmpty&&_studio.sender=='obs_laptop') ...[
          Text('organization_v1.obs_hint'.tr()),
          SelectableText(_studio.ingestUrl),
          Row(children:[Expanded(child:SelectableText(_showKey?_studio.ingestKey:'••••••••')),
            IconButton(onPressed:()=>setState(()=>_showKey=!_showKey),tooltip:'organization_v1.show_key'.tr(),icon:const Icon(Icons.visibility)),
            IconButton(onPressed:()=>Clipboard.setData(ClipboardData(text:_studio.ingestKey)),tooltip:'organization_v1.copy_key'.tr(),icon:const Icon(Icons.copy))]),
          if(!live) FilledButton(onPressed:operationBusy?null:_start,child:Text('organization_v1.start'.tr())),
        ],
        if(frozen) OutlinedButton(onPressed:operationBusy?null:_end,child:Text('organization_v1.end'.tr())),
        if(live) Text('organization_v1.live'.tr()),
        if(pending) Text('organization_v1.termination_pending'.tr()),
        if(_studio.errorKey!=null||error!=null) Text((_studio.errorKey??error!).tr(),style:const TextStyle(color:AppTheme.danger)),
        TextButton(onPressed:operationBusy?null:_load,child:Text('organization_v1.refresh'.tr())),
      ]))));
  }
}
