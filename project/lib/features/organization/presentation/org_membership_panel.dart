import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../models/org_membership.dart';

class OrgMembershipPanel extends StatefulWidget {
  const OrgMembershipPanel({super.key, required this.orgId});
  final String orgId;
  @override
  State<OrgMembershipPanel> createState() => _OrgMembershipPanelState();
}

class _OrgMembershipPanelState extends State<OrgMembershipPanel> {
  static const _publicAppUrl = String.fromEnvironment('PUBLIC_APP_URL');
  late Future<List<OrgMembership>> _members;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _members = context.read<AppProvider>().organizationMembers(widget.orgId);
  }

  Future<void> _run(Future<void> Function(AppProvider) action) async {
    setState(() { _busy = true; _error = null; });
    try {
      await action(context.read<AppProvider>());
      if (!mounted) return;
      setState(() => _members = context.read<AppProvider>().organizationMembers(widget.orgId));
    } catch (_) {
      if (mounted) setState(() => _error = 'organization_v1.failure'.tr());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit({OrgMembership? member, required bool owner}) async {
    final email = TextEditingController();
    var role = member?.roleValue ?? 'broadcaster';
    var video = member?.permissions.canGoLiveVideo ?? false;
    var audio = member?.permissions.canGoAudioOnly ?? false;
    final save = await showDialog<bool>(context: context, builder: (dialog) =>
      StatefulBuilder(builder: (dialog, update) => AlertDialog(
        title: Text('organization_v1.${member == null ? 'invite' : 'members'}'.tr()),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (member == null) TextField(controller: email, keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'organization_v1.email'.tr())),
          if (member?.role != OrgRole.owner) DropdownButtonFormField<String>(
            initialValue: role,
            decoration: InputDecoration(labelText: 'organization_v1.role'.tr()),
            items: (owner ? ['co_owner','manager','moderator','broadcaster'] : ['broadcaster'])
              .map((r) => DropdownMenuItem(value: r, child: Text('organization_v1.$r'.tr()))).toList(),
            onChanged: (r) => update(() => role = r!),
          ),
          CheckboxListTile(title: Text('organization_v1.video'.tr()), value: video,
            onChanged: (v) => update(() => video = v!)),
          CheckboxListTile(title: Text('organization_v1.audio'.tr()), value: audio,
            onChanged: (v) => update(() => audio = v!)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text('organization_v1.decline'.tr())),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text('organization_v1.save'.tr()))],
      )));
    final address = email.text.trim();
    email.dispose();
    if (save != true || !mounted) return;
    await _run((p) async {
      final grants = <String, bool>{
        ...?member?.permissions.toJson().cast<String, bool>(),
        'can_go_live_video': video, 'can_go_audio_only': audio,
      };
      if (member != null) {
        await p.setOrganizationMember(widget.orgId, member.profileId, role, 'active', grants);
      } else {
        final invitation = await p.inviteOrganizationMember(widget.orgId, address, role, grants);
        if (!mounted) return;
        final base = _publicAppUrl.isEmpty ? Uri.base : Uri.parse(_publicAppUrl);
        if (!{'https','http'}.contains(base.scheme)) {
          throw StateError('Configure PUBLIC_APP_URL for invitation sharing');
        }
        final url = base.replace(path: '/org-invite/${invitation['id']}',
          queryParameters: {'token': invitation['token'] as String}, fragment: '');
        await Share.share(url.toString());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.select<AppProvider, OrgMembership?>((p) => p.orgMemberships
      .where((m) => m.organizationId == widget.orgId && m.active).firstOrNull);
    final owner = actor?.canManageChannel == true;
    return Padding(padding: const EdgeInsets.all(AppTheme.spaceLg), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text('organization_v1.members'.tr(),
          style: Theme.of(context).textTheme.titleLarge)),
          if (actor?.canManageMembers == true) FilledButton.icon(
            onPressed: _busy ? null : () => _edit(owner: owner), icon: const Icon(Icons.person_add_alt_1),
            label: Text('organization_v1.invite'.tr()))]),
        if (_error != null) Text(_error!, style: const TextStyle(color: AppTheme.danger)),
        FutureBuilder<List<OrgMembership>>(future: _members, builder: (context, snapshot) {
          if (snapshot.hasError) return Text('organization_v1.failure'.tr());
          if (!snapshot.hasData) return const SizedBox(height: AppTheme.spaceLg);
          return Column(children: snapshot.data!.map((m) => ListTile(
            title: Text(context.locale.languageCode == 'ar' ? m.nameAr : m.nameEn),
            subtitle: Text('${'organization_v1.${m.roleValue}'.tr()} · ${m.statusValue}'),
            trailing: actor?.canManageMembers != true || (!owner && m.role != OrgRole.broadcaster)
              ? null : PopupMenuButton<String>(enabled: !_busy, onSelected: (value) {
                if (value == 'edit') { _edit(member: m, owner: owner); return; }
                _run((p) => value == 'transfer'
                  ? p.transferOrganizationOwner(widget.orgId, toProfileId: m.profileId)
                  : p.setOrganizationMember(widget.orgId, m.profileId, m.roleValue, 'revoked', {}));
              }, itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text('organization_v1.save'.tr())),
                if (m.role != OrgRole.owner) PopupMenuItem(value: 'revoke', child: Text('organization_v1.revoke'.tr())),
                if (owner && m.role != OrgRole.owner && m.active) PopupMenuItem(value: 'transfer', child: Text('organization_v1.transfer'.tr())),
              ]),
          )).toList());
        }),
        if (actor?.active == true && !owner) TextButton(
          onPressed: _busy ? null : () => _run((p) => p.transferOrganizationOwner(widget.orgId)),
          child: Text('organization_v1.accept_transfer'.tr())),
      ],
    ));
  }
}
