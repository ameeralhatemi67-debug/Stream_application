import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/organization_broadcast_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/org_invitation.dart';
import '../models/org_membership.dart';

/// The share link for an invitation. The web app routes in the URL fragment,
/// so the route and its single-use token go after `#`, never into the path.
Uri organizationInvitationLink(Uri base, String id, String token) {
  if (!{'https', 'http'}.contains(base.scheme) || base.host.isEmpty) {
    throw StateError('Configure PUBLIC_APP_URL for invitation sharing');
  }
  final route = Uri(path: '/org-invite/$id', queryParameters: {'token': token});
  return Uri(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null,
      path: '/', fragment: route.toString());
}

class OrgMembershipPanel extends StatefulWidget {
  const OrgMembershipPanel({super.key, required this.orgId});
  final String orgId;
  @override
  State<OrgMembershipPanel> createState() => _OrgMembershipPanelState();
}

class _OrgMembershipPanelState extends State<OrgMembershipPanel> {
  static const _publicAppUrl = String.fromEnvironment('PUBLIC_APP_URL');
  late Future<List<OrgMembership>> _members;
  Future<List<OrgInvitation>>? _invitations;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final p = context.read<AppProvider>();
    _members = p.organizationMembers(widget.orgId);
    final actor = p.orgMemberships
        .where((m) => m.organizationId == widget.orgId && m.active).firstOrNull;
    _invitations = actor?.canManageMembers == true ? p.organizationInvitations(widget.orgId) : null;
  }

  Future<void> _run(Future<void> Function(AppProvider) action) async {
    setState(() { _busy = true; _error = null; });
    try {
      await action(context.read<AppProvider>());
      if (!mounted) return;
      setState(_reload);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is StateError && error.message.contains('PUBLIC_APP_URL')
            ? 'organization_v1.share_url_missing'
            : OrganizationBroadcastService.actionErrorKey(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
        title: Text(title), content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text('organization_v1.close'.tr())),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text('organization_v1.confirm'.tr())),
        ],
      )) == true;

  Future<void> _edit({OrgMembership? member, required bool owner}) async {
    final email = TextEditingController();
    var role = member?.roleValue ?? 'broadcaster';
    var video = member?.permissions.canGoLiveVideo ?? false;
    var audio = member?.permissions.canGoAudioOnly ?? false;
    final save = await showDialog<bool>(context: context, builder: (dialog) =>
      StatefulBuilder(builder: (dialog, update) => AlertDialog(
        title: Text('organization_v1.${member == null ? 'invite' : 'edit_member'}'.tr()),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (member == null) TextField(controller: email, keyboardType: TextInputType.emailAddress,
            autofocus: true, decoration: InputDecoration(labelText: 'organization_v1.email'.tr())),
          if (member?.role != OrgRole.owner) DropdownButtonFormField<String>(
            initialValue: role, isExpanded: true,
            decoration: InputDecoration(labelText: 'organization_v1.role'.tr()),
            items: (owner ? ['co_owner','manager','moderator','broadcaster'] : ['broadcaster'])
              .map((r) => DropdownMenuItem(value: r, child: Text('organization_v1.$r'.tr()))).toList(),
            onChanged: (r) => update(() => role = r!),
          ),
          CheckboxListTile(title: Text('organization_v1.video'.tr()), value: video,
            onChanged: (v) => update(() => video = v!)),
          CheckboxListTile(title: Text('organization_v1.audio'.tr()), value: audio,
            onChanged: (v) => update(() => audio = v!)),
          if (member == null) Text('organization_v1.invite_hint_leader'.tr(),
            style: const TextStyle(color: AppTheme.textSecondary)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text('organization_v1.close'.tr())),
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
        final base = _publicAppUrl.isEmpty ? Uri.base : Uri.parse(_publicAppUrl);
        // Validate before creating a server invitation that could not be shared.
        organizationInvitationLink(base, 'check', 'check');
        final invitation = await p.inviteOrganizationMember(widget.orgId, address, role, grants);
        if (!mounted) return;
        final url = organizationInvitationLink(base, invitation['id'] as String, invitation['token'] as String);
        await showDialog<void>(context: context, builder: (dialog) => AlertDialog(
          title: Text('organization_v1.invite'.tr()),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('organization_v1.invite_link_hint'.tr()),
            const SizedBox(height: AppTheme.spaceSm),
            SelectableText(url.toString()),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(dialog),
            child: Text('organization_v1.close'.tr())),
            FilledButton(onPressed: () => Share.share(url.toString()),
              child: Text('organization_v1.share'.tr()))],
        ));
      }
    });
  }

  Future<void> _memberAction(String value, OrgMembership m, bool owner) async {
    final language = context.locale.languageCode;
    final name = language == 'ar' ? m.nameAr : m.nameEn;
    switch (value) {
      case 'edit':
        await _edit(member: m, owner: owner);
      case 'revoke':
        if (await _confirm('organization_v1.revoke'.tr(), 'organization_v1.revoke_hint'.tr(namedArgs: {'name': name}))) {
          await _run((p) => p.setOrganizationMember(widget.orgId, m.profileId, m.roleValue, 'revoked', {}));
        }
      case 'transfer':
        if (await _confirm('organization_v1.transfer'.tr(), 'organization_v1.transfer_hint'.tr(namedArgs: {'name': name}))) {
          await _run((p) => p.transferOrganizationOwner(widget.orgId, toProfileId: m.profileId));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actor = context.select<AppProvider, OrgMembership?>((p) => p.orgMemberships
      .where((m) => m.organizationId == widget.orgId && m.active).firstOrNull);
    final owner = actor?.canManageChannel == true;
    final language = context.locale.languageCode;
    return Padding(padding: const EdgeInsets.all(AppTheme.spaceLg), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Semantics(header: true, child: Text('organization_v1.members'.tr(),
          style: Theme.of(context).textTheme.titleLarge))),
          if (actor?.canManageMembers == true) FilledButton.icon(
            onPressed: _busy ? null : () => _edit(owner: owner), icon: const Icon(Icons.person_add_alt_1),
            label: Text('organization_v1.invite'.tr()))]),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
          child: Text(_error!.tr(), style: const TextStyle(color: AppTheme.danger))),
        if (owner) TextButton.icon(onPressed:()=>context.push('/channels'),
          icon:const Icon(Icons.video_library_outlined),label:Text('organization_v1.channels'.tr())),
        if (owner && actor?.transferTargetId != null) Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
          child: Row(children: [
            Expanded(child: Text('organization_v1.transfer_pending'.tr(namedArgs: {'date': actor?.transferExpiresAt == null
              ? '' : DateFormat.yMMMd(language).format(actor!.transferExpiresAt!.toLocal())}))),
            TextButton(onPressed: _busy ? null : () => _run((p) => p.cancelOrganizationTransfer(widget.orgId)),
              child: Text('organization_v1.withdraw_transfer'.tr())),
          ])),
        FutureBuilder<List<OrgMembership>>(future: _members, builder: (context, snapshot) {
          if (snapshot.hasError) return Text('organization_v1.failure'.tr());
          if (!snapshot.hasData) return const SizedBox(height: AppTheme.spaceLg);
          return Column(children: snapshot.data!.map((m) {
            final grants = [
              if (m.permissions.canGoLiveVideo) 'organization_v1.video'.tr(),
              if (m.permissions.canGoAudioOnly) 'organization_v1.audio'.tr(),
            ];
            return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(language == 'ar' ? m.nameAr : m.nameEn, overflow: TextOverflow.ellipsis),
            subtitle: Text([
              'organization_v1.${m.roleValue}'.tr(),
              'organization_v1.status_${m.statusValue}'.tr(),
              ...grants,
            ].join(' · ')),
            trailing: actor?.canManageMembers != true || (!owner && m.role != OrgRole.broadcaster)
                || m.status == OrgMembershipStatus.revoked
              ? null : PopupMenuButton<String>(enabled: !_busy,
                tooltip: 'organization_v1.member_actions'.tr(),
                onSelected: (value) => _memberAction(value, m, owner),
                itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text('organization_v1.edit_member'.tr())),
                if (m.role != OrgRole.owner) PopupMenuItem(value: 'revoke', child: Text('organization_v1.revoke'.tr())),
                if (owner && m.role != OrgRole.owner && m.active) PopupMenuItem(value: 'transfer', child: Text('organization_v1.transfer'.tr())),
              ]),
          );}).toList());
        }),
        if (_invitations != null) FutureBuilder<List<OrgInvitation>>(future: _invitations, builder: (context, snapshot) {
          final rows = snapshot.data ?? const <OrgInvitation>[];
          if (snapshot.hasError) return Text('organization_v1.failure'.tr());
          if (rows.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: AppTheme.spaceLg),
            Semantics(header: true, child: Text('organization_v1.pending_invitations'.tr(),
              style: Theme.of(context).textTheme.titleMedium)),
            for (final invitation in rows) ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(invitation.email ?? '', overflow: TextOverflow.ellipsis),
              subtitle: Text('${'organization_v1.${invitation.role}'.tr()} · ${'organization_v1.expires'.tr(namedArgs: {
                'date': DateFormat.yMMMd(language).format(invitation.expiresAt.toLocal())})}'),
              trailing: TextButton(onPressed: _busy ? null : () async {
                if (await _confirm('organization_v1.revoke_invite'.tr(), 'organization_v1.revoke_invite_hint'.tr())) {
                  await _run((p) => p.revokeOrganizationInvite(invitation.id));
                }
              }, child: Text('organization_v1.revoke_invite'.tr())),
            ),
          ]);
        }),
      ],
    ));
  }
}
