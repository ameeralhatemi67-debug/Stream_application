import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';
import '../../../core/services/organization_broadcast_service.dart';
import '../../live_stream/models/broadcast_session.dart';
import '../../live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import '../models/org_membership.dart';
import '../../admin/presentation/widgets/chat_moderation_view.dart';

class OrganizationShowsScreen extends StatefulWidget {
  const OrganizationShowsScreen({super.key, this.initialOrganizationId});
  final String? initialOrganizationId;
  @override
  State<OrganizationShowsScreen> createState() => _ShowsState();
}

class _ShowsState extends State<OrganizationShowsScreen> {
  List<BroadcastSession> _sessions=[];
  String? _org, _error;
  bool _busy=false;
  @override
  void initState() { super.initState(); _org=widget.initialOrganizationId; _load(); }
  Future<void> _load() async {
    setState(()=>_busy=true);
    try {
      final p=context.read<AppProvider>();
      await p.refreshOrgMemberships();
      final sessions=await p.organizationSessions(organizationId:_org,mine:_org==null);
      if(mounted) setState(() { _sessions=sessions; _error=null; });
    } catch(error) { if(mounted) setState(()=>_error=OrganizationBroadcastService.actionErrorKey(error)); }
    finally { if(mounted) setState(()=>_busy=false); }
  }
  Future<void> _run(Future<void> Function() action) async {
    if(_busy)return;
    setState(()=>_busy=true);
    try { await action(); if(mounted) await _load(); }
    catch(error) { if(mounted)setState(()=>_error=OrganizationBroadcastService.actionErrorKey(error)); }
    finally { if(mounted)setState(()=>_busy=false); }
  }
  Future<void> _edit({BroadcastSession? session, bool series=false}) async {
    if(_org==null)return;
    final members=await context.read<AppProvider>().organizationMembers(_org!);
    if(!mounted)return;
    await showDialog<void>(context:context,builder:(_)=>_ScheduleEditor(org:_org!,members:members,session:session,series:series));
    if(mounted) await _load();
  }
  @override
  Widget build(BuildContext context) {
    final (members,user)=context.select<AppProvider,(List<OrgMembership>,String?)>((p)=>(p.orgMemberships,p.currentUserId));
    final organizations=members.where((m)=>m.active).toList();
    final manage=organizations.any((m)=>m.organizationId==_org && m.canManageMembers);
    final selected=organizations.where((m)=>m.organizationId==_org).firstOrNull;
    if(_org!=null && !_busy && selected==null && organizations.isNotEmpty) {
      // A membership that ended while this screen was open (or a stale link).
      WidgetsBinding.instance.addPostFrameCallback((_) { if(mounted && _org!=null) { setState(()=>_org=null); _load(); } });
    }
    final language=context.locale.languageCode;
    return Scaffold(appBar:AppBar(title:Text('organization_v1.shows'.tr()),actions:[IconButton(
      onPressed:_busy?null:_load,tooltip:'organization_v1.refresh'.tr(),icon:const Icon(Icons.refresh))]),
      body:ListView(padding:const EdgeInsets.all(AppTheme.spaceLg),children:[
        DropdownButtonFormField<String>(key:ValueKey(_org),initialValue:organizations.any((m)=>m.organizationId==_org)?_org:'',isExpanded:true,
          decoration:InputDecoration(labelText:'organization_v1.destination'.tr()),
          items:[DropdownMenuItem(value:'',child:Text('organization_v1.my_assignments'.tr())),
            ...organizations.map((m)=>DropdownMenuItem(value:m.organizationId,
              child:Text(language=='ar'?m.organizationNameAr:m.organizationNameEn,overflow:TextOverflow.ellipsis)))],
          onChanged:_busy?null:(v){setState(()=>_org=v==''?null:v);_load();}),
        Text('organization_v1.riyadh'.tr()),
        if(selected!=null && !selected.v1Enabled) Text('organization_v1.not_enabled_hint'.tr(),style:const TextStyle(color:AppTheme.textSecondary)),
        if(manage) FilledButton(onPressed:_busy?null:()=>_edit(),child:Text('organization_v1.schedule'.tr())),
        TextButton(onPressed:()=>LiveBroadcasterStudioSheet.show(context),child:Text('organization_v1.studio'.tr())),
        if(_busy) const Center(child:HadayahLoadingIndicator()),
        if(_error!=null) Text(_error!.tr(),style:const TextStyle(color:AppTheme.danger)),
        if(!_busy && _sessions.isEmpty) Text('organization_v1.no_shows'.tr()),
        ..._sessions.map((s)=>Card(child:Padding(padding:const EdgeInsets.all(AppTheme.spaceLg),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(s.title(language),style:Theme.of(context).textTheme.titleMedium),
          if(s.startUtc!=null) Text(DateFormat('yyyy-MM-dd HH:mm',language).format(s.startUtc!.add(const Duration(hours:3)))),
          Text('organization_v1.state_${s.state}'.tr()),
          if(s.terminationPending) Text('organization_v1.termination_pending'.tr()),
          Wrap(spacing:AppTheme.spaceSm,children:[
            if(organizations.any((m)=>m.organizationId==s.organizationId && m.canModerate))
              TextButton(onPressed:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>Scaffold(
                appBar:AppBar(title:Text(s.title(language))),body:ChatModerationView(streamId:s.id)))),child:Text('design_ui.chat_moderation'.tr())),
            if(s.presenterId==user && s.state=='awaiting_acceptance') ...[
              TextButton(onPressed:_busy?null:()=>_run(()=>context.read<AppProvider>().answerBroadcastAssignment(s,true)),child:Text('organization_v1.accept'.tr())),
              TextButton(onPressed:_busy?null:()=>_run(()=>context.read<AppProvider>().answerBroadcastAssignment(s,false)),child:Text('organization_v1.decline'.tr())),
            ],
            if(manage && ['draft','awaiting_acceptance','scheduled'].contains(s.state)) ...[
              TextButton(onPressed:_busy?null:()=>_edit(session:s),child:Text('organization_v1.edit_occurrence'.tr())),
              if(s.scheduleId!=null) TextButton(onPressed:_busy?null:()=>_edit(session:s,series:true),child:Text('organization_v1.replace_series'.tr())),
            ],
            if((manage || s.presenterId==user) && ['draft','awaiting_acceptance','scheduled','preparing','live','ending'].contains(s.state))
              TextButton(onPressed:_busy?null:()=>_run(()=>context.read<AppProvider>().endOrganizationSession(s)),child:Text('organization_v1.end'.tr())),
            if(manage && s.scheduleId!=null && !s.active)
              TextButton(onPressed:_busy?null:()=>_run(()=>context.read<AppProvider>().cancelOrganizationSchedule(s.scheduleId!)),child:Text('organization_v1.cancel_series'.tr())),
            if(s.live || s.replayStatus=='available') TextButton(onPressed:()=>context.push('/live/${s.id}'),child:Text('organization_v1.open_room'.tr())),
          ])])))),
      ]));
  }
}

class _ScheduleEditor extends StatefulWidget {
  const _ScheduleEditor({required this.org,required this.members,this.session,required this.series});
  final String org;
  final List<OrgMembership> members;
  final BroadcastSession? session;
  final bool series;
  @override
  State<_ScheduleEditor> createState()=>_ScheduleEditorState();
}
class _ScheduleEditorState extends State<_ScheduleEditor> {
  final _en=TextEditingController(),_ar=TextEditingController();
  String? _presenter,_error,_venue;
  bool _weekly=false,_audio=false,_busy=false;
  final Set<int> _days={};
  late DateTime _date;
  late TimeOfDay _time;
  @override
  void initState(){super.initState();
    final s=widget.session;
    _date=(s?.startUtc??DateTime.now().toUtc().add(const Duration(days:1))).add(const Duration(hours:3));
    _time=TimeOfDay(hour:_date.hour,minute:_date.minute);
    _presenter=s?.presenterId;_venue=s?.venueId;_audio=s?.broadcastType=='liveAudio';
    _en.text=s?.titleEn??'';_ar.text=s?.titleAr??'';_days.add(_date.weekday);
  }
  @override
  void dispose(){_en.dispose();_ar.dispose();super.dispose();}
  Future<void> _save() async {
    if(_busy)return;
    if(_presenter==null || (_en.text.trim().isEmpty && _ar.text.trim().isEmpty) || (_weekly&&_days.isEmpty)) {
      setState(()=>_error='organization_v1.complete_schedule');return;
    }
    setState(()=>_busy=true);
    try {
      final p=context.read<AppProvider>();
      final start=DateTime.utc(_date.year,_date.month,_date.day,_time.hour,_time.minute).subtract(const Duration(hours:3));
      final s=widget.session;
      if(s!=null && !widget.series) {
        await p.editOrganizationOccurrence(s,presenterId:_presenter!,start:start,end:start.add(const Duration(hours:1)),type:_audio?'liveAudio':'liveVideo',venueId:_venue);
      } else {
        await p.saveOrganizationSchedule(orgId:widget.org,scheduleId:widget.series?s?.scheduleId:null,presenterId:_presenter!,
          kind:_weekly?'weekly':'once',localTime:'${_time.hour.toString().padLeft(2,'0')}:${_time.minute.toString().padLeft(2,'0')}',
          weekdays:_days.toList()..sort(),once:_weekly?null:start,titleEn:_en.text.trim(),titleAr:_ar.text.trim(),type:_audio?'liveAudio':'liveVideo',venueId:_venue);
      }
      if(mounted)Navigator.pop(context);
    } catch(_) {if(mounted)setState(()=>_error='organization_v1.schedule_failed');}
    finally {if(mounted)setState(()=>_busy=false);}
  }
  @override
  Widget build(BuildContext context) {
    final presenters=widget.members.where((m)=>m.active && (_audio?m.permissions.canGoAudioOnly:m.permissions.canGoLiveVideo) || m.profileId==_presenter).toList();
    final venues=context.read<AppProvider>().getOrganizationVenues(widget.org);
    final occurrence=widget.session!=null&&!widget.series;
    return AlertDialog(title:Text('organization_v1.schedule'.tr()),content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text('organization_v1.riyadh'.tr()),
      if(!occurrence) ...[
        TextField(controller:_en,maxLength:100,decoration:InputDecoration(labelText:'organization_v1.title_en'.tr())),
        TextField(controller:_ar,maxLength:100,decoration:InputDecoration(labelText:'organization_v1.title_ar'.tr())),
      ],
      DropdownButtonFormField<String>(initialValue:_presenter,isExpanded:true,decoration:InputDecoration(labelText:'organization_v1.presenter'.tr()),
        items:presenters.map((m)=>DropdownMenuItem(value:m.profileId,child:Text(context.locale.languageCode=='ar'?m.nameAr:m.nameEn,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:_busy?null:(v)=>setState(()=>_presenter=v)),
      DropdownButtonFormField<String>(initialValue:venues.any((v)=>v.venueId==_venue)?_venue:null,isExpanded:true,decoration:InputDecoration(labelText:'organization_v1.venue'.tr()),
        items:venues.map((v)=>DropdownMenuItem(value:v.venueId,child:Text(context.locale.languageCode=='ar'?v.nameAr:v.nameEn,overflow:TextOverflow.ellipsis))).toList(),
        onChanged:_busy?null:(v)=>setState(()=>_venue=v)),
      SwitchListTile(title:Text('organization_v1.audio'.tr()),value:_audio,onChanged:_busy?null:(v)=>setState(()=>_audio=v)),
      if(!occurrence) SwitchListTile(title:Text('organization_v1.weekly'.tr()),value:_weekly,onChanged:_busy?null:(v)=>setState(()=>_weekly=v)),
      if(_weekly) Wrap(children:[for(var day=1;day<=7;day++) FilterChip(label:Text(DateFormat.E(context.locale.languageCode).format(DateTime.utc(2026,9,27+day))),selected:_days.contains(day),onSelected:_busy?null:(v)=>setState(()=>v?_days.add(day):_days.remove(day)))])
      else TextButton(onPressed:_busy?null:()async {
        final now=DateTime.now().toUtc().add(const Duration(hours:3));
        final first=DateTime(now.year,now.month,now.day);
        final date=await showDatePicker(context:context,firstDate:first,lastDate:first.add(const Duration(days:365)),initialDate:_date.isBefore(first)?first:_date);
        if(date!=null&&mounted)setState(()=>_date=date);
      },child:Text(DateFormat.yMd(context.locale.languageCode).format(_date))),
      TextButton(onPressed:_busy?null:()async {final time=await showTimePicker(context:context,initialTime:_time);if(time!=null&&mounted)setState(()=>_time=time);},child:Text(_time.format(context))),
      Text('organization_v1.acceptance_reset'.tr()),
      if(_error!=null)Text(_error!.tr(),style:const TextStyle(color:AppTheme.danger)),
    ]))),actions:[TextButton(onPressed:_busy?null:()=>Navigator.pop(context),child:Text('organization_v1.close'.tr())),
      FilledButton(onPressed:_busy?null:_save,child:Text('organization_v1.save'.tr()))]);
  }
}
