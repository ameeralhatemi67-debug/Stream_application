import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/services/organization_broadcast_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';
import '../models/channel_connection.dart';
import '../models/org_event.dart';
import '../models/org_event_text.dart';
import '../models/org_invitation.dart';
import '../models/org_membership.dart';
import 'org_membership_panel.dart';

/// Every account's organization home: invitations addressed to it, the
/// organizations it belongs to (with rollout availability, pending ownership
/// transfers and the owner's setup steps) and its organization activity. The
/// server decides every action shown here; this screen only reflects it.
class OrganizationHubScreen extends StatefulWidget {
  const OrganizationHubScreen({super.key});
  @override
  State<OrganizationHubScreen> createState() => _OrganizationHubScreenState();
}

class _OrganizationHubScreenState extends State<OrganizationHubScreen> {
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() => _run((p) async {
        await p.refreshOrgMemberships();
        await Future.wait([
          p.refreshOrganizationInvitations(),
          p.refreshOrganizationEvents(),
          if (p.orgMemberships.any((m) => m.canManageChannel)) p.refreshChannelConnections(),
        ]);
        _loaded = true;
      });

  Future<bool> _run(Future<void> Function(AppProvider) action) async {
    if (_busy) return false;
    setState(() { _busy = true; _error = null; });
    try {
      await action(context.read<AppProvider>());
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = OrganizationBroadcastService.actionErrorKey(error));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _answer(OrgInvitation invitation, bool accept) async {
    final ok = await _run((p) async {
      await p.answerOrganizationInvite(invitation.id, accept);
      await p.refreshOrganizationInvitations();
    });
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          (accept ? 'organization_v1.invite_accepted' : 'organization_v1.invite_declined').tr())));
    }
  }

  Future<void> _acceptTransfer(OrgMembership m) async {
    final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(
      title: Text('organization_v1.accept_transfer'.tr()),
      content: Text('organization_v1.transfer_accept_hint'.tr()),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text('organization_v1.close'.tr())),
        FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text('organization_v1.accept_transfer'.tr())),
      ],
    ));
    if (confirmed != true || !mounted) return;
    final ok = await _run((p) => p.transferOrganizationOwner(m.organizationId));
    // The incoming owner must reconnect the organization channel themselves.
    if (ok && mounted) context.push('/channels');
  }

  void _openMembers(OrgMembership m, String language) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => Scaffold(
      appBar: AppBar(title: Text(language == 'ar' ? m.organizationNameAr : m.organizationNameEn,
          overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(child: OrgMembershipPanel(orgId: m.organizationId)),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final (memberships, invitations, events, channels) = context.select<AppProvider,
        (List<OrgMembership>, List<OrgInvitation>, List<OrgEvent>, List<ChannelConnection>)>(
      (p) => (p.orgMemberships, p.myOrganizationInvitations, p.organizationEvents, p.channelConnections));
    final language = context.locale.languageCode;
    final visible = memberships.where((m) => m.status != OrgMembershipStatus.revoked).toList();
    final unread = events.where((e) => !e.read).length;
    return Scaffold(
      appBar: AppBar(title: Text('organization_v1.organizations'.tr()), actions: [
        IconButton(onPressed: _busy ? null : _refresh, tooltip: 'organization_v1.refresh'.tr(),
            icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(AppTheme.spaceLg), children: [
        if (_busy) const Padding(padding: EdgeInsets.only(bottom: AppTheme.spaceMd),
            child: Center(child: HadayahLoadingIndicator())),
        if (_error != null) _Notice(text: _error!.tr(), color: AppTheme.danger, onRetry: _refresh),
        if (invitations.isNotEmpty) ...[
          _Header('organization_v1.pending_invitations'.tr()),
          for (final invitation in invitations)
            _InvitationCard(invitation: invitation, busy: _busy, language: language,
                onAnswer: (accept) => _answer(invitation, accept)),
        ],
        _Header('organization_v1.my_organizations'.tr()),
        if (_loaded && visible.isEmpty && invitations.isEmpty)
          _Notice(text: 'organization_v1.no_organizations'.tr(), color: AppTheme.textSecondary),
        for (final m in visible)
          _MembershipCard(
            membership: m, language: language, busy: _busy,
            channelConnected: channels.any((c) => c.organizationId == m.organizationId && c.connected),
            onShows: () => context.push(Uri(path: '/shows', queryParameters: {'org': m.organizationId}).toString()),
            onMembers: () => _openMembers(m, language),
            onChannel: () => context.push('/channels'),
            onAcceptTransfer: () => _acceptTransfer(m),
            onCancelTransfer: () => _run((p) => p.cancelOrganizationTransfer(m.organizationId)),
          ),
        if (events.isNotEmpty) ...[
          Row(children: [
            Expanded(child: _Header('organization_v1.activity'.tr())),
            if (unread > 0) TextButton(
              onPressed: _busy ? null : () => _run((p) => p.markOrganizationEventsRead()),
              child: Text('organization_v1.mark_all_read'.tr())),
          ]),
          for (final event in events.take(30)) _EventTile(event: event, language: language),
        ],
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AppTheme.spaceLg, bottom: AppTheme.spaceSm),
        child: Semantics(header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.color, this.onRetry});
  final String text;
  final Color color;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSm),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(color: color))),
          if (onRetry != null) TextButton(onPressed: onRetry, child: Text('organization_v1.refresh'.tr())),
        ]),
      );
}

String _roleLabel(String role) => 'organization_v1.$role'.tr();
String _date(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(context.locale.languageCode).add_jm().format(value.toLocal());

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation, required this.busy, required this.language,
      required this.onAnswer});
  final OrgInvitation invitation;
  final bool busy;
  final String language;
  final void Function(bool accept) onAnswer;
  @override
  Widget build(BuildContext context) {
    final grants = [
      if (invitation.video) 'organization_v1.video'.tr(),
      if (invitation.audio) 'organization_v1.audio'.tr(),
    ];
    return Card(child: Padding(padding: const EdgeInsets.all(AppTheme.spaceLg), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(invitation.organizationName(language), style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTheme.spaceXs),
        Text('organization_v1.invited_as'.tr(namedArgs: {'role': _roleLabel(invitation.role)})),
        if (grants.isNotEmpty) Text(grants.join(' · '), style: const TextStyle(color: AppTheme.textSecondary)),
        Text('organization_v1.expires'.tr(namedArgs: {'date': _date(context, invitation.expiresAt)}),
            style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: AppTheme.spaceSm),
        Wrap(spacing: AppTheme.spaceSm, runSpacing: AppTheme.spaceSm, children: [
          FilledButton(onPressed: busy ? null : () => onAnswer(true), child: Text('organization_v1.accept'.tr())),
          OutlinedButton(onPressed: busy ? null : () => onAnswer(false), child: Text('organization_v1.decline'.tr())),
        ]),
      ])));
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({required this.membership, required this.language, required this.busy,
      required this.channelConnected, required this.onShows, required this.onMembers, required this.onChannel,
      required this.onAcceptTransfer, required this.onCancelTransfer});
  final OrgMembership membership;
  final String language;
  final bool busy;
  final bool channelConnected;
  final VoidCallback onShows, onMembers, onChannel, onAcceptTransfer, onCancelTransfer;

  @override
  Widget build(BuildContext context) {
    final m = membership;
    final name = language == 'ar' && m.organizationNameAr.isNotEmpty ? m.organizationNameAr : m.organizationNameEn;
    final presenter = m.permissions.canGoLiveVideo || m.permissions.canGoAudioOnly;
    return Card(child: Padding(padding: const EdgeInsets.all(AppTheme.spaceLg), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(name, style: Theme.of(context).textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: AppTheme.spaceXs),
        Wrap(spacing: AppTheme.spaceSm, runSpacing: AppTheme.spaceXs, children: [
          Chip(label: Text(_roleLabel(m.roleValue))),
          if (!m.active) Chip(label: Text('organization_v1.status_${m.statusValue}'.tr())),
          Chip(label: Text((m.v1Enabled ? 'organization_v1.available' : 'organization_v1.not_enabled').tr())),
        ]),
        if (!m.v1Enabled) Text('organization_v1.not_enabled_hint'.tr(),
            style: const TextStyle(color: AppTheme.textSecondary)),
        if (m.transferToMe) _Banner(
          text: 'organization_v1.transfer_incoming'.tr(namedArgs: {
            'date': m.transferExpiresAt == null ? '' : _date(context, m.transferExpiresAt!)}),
          actions: [
            FilledButton(onPressed: busy ? null : onAcceptTransfer, child: Text('organization_v1.accept_transfer'.tr())),
            OutlinedButton(onPressed: busy ? null : onCancelTransfer, child: Text('organization_v1.decline'.tr())),
          ]),
        if (m.canManageChannel && m.transferTargetId != null) _Banner(
          text: 'organization_v1.transfer_pending'.tr(namedArgs: {
            'date': m.transferExpiresAt == null ? '' : _date(context, m.transferExpiresAt!)}),
          actions: [OutlinedButton(onPressed: busy ? null : onCancelTransfer,
              child: Text('organization_v1.withdraw_transfer'.tr()))]),
        if (m.canManageChannel) ...[
          const SizedBox(height: AppTheme.spaceSm),
          Text('organization_v1.setup'.tr(), style: Theme.of(context).textTheme.titleSmall),
          _Step(done: channelConnected, text: 'organization_v1.setup_channel'.tr(),
              action: channelConnected ? null : TextButton(onPressed: onChannel, child: Text('organization_v1.connect'.tr()))),
          _Step(done: m.v1Enabled, text: 'organization_v1.setup_pilot'.tr()),
          _Step(done: false, optional: true, text: 'organization_v1.setup_members'.tr(),
              action: TextButton(onPressed: onMembers, child: Text('organization_v1.invite'.tr()))),
        ],
        const SizedBox(height: AppTheme.spaceSm),
        if (m.active) Wrap(spacing: AppTheme.spaceSm, runSpacing: AppTheme.spaceSm, children: [
          if (presenter || m.canManageMembers || m.canModerate)
            OutlinedButton.icon(onPressed: onShows, icon: const Icon(Icons.event_note_outlined),
                label: Text('organization_v1.shows'.tr())),
          if (m.canManageMembers)
            OutlinedButton.icon(onPressed: onMembers, icon: const Icon(Icons.group_outlined),
                label: Text('organization_v1.members'.tr())),
          if (m.canManageChannel)
            OutlinedButton.icon(onPressed: onChannel, icon: const Icon(Icons.video_library_outlined),
                label: Text('organization_v1.channels'.tr())),
        ]),
      ])));
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.actions});
  final String text;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: AppTheme.spaceSm),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        decoration: BoxDecoration(color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text),
          const SizedBox(height: AppTheme.spaceSm),
          Wrap(spacing: AppTheme.spaceSm, runSpacing: AppTheme.spaceSm, children: actions),
        ]),
      );
}

class _Step extends StatelessWidget {
  const _Step({required this.done, required this.text, this.action, this.optional = false});
  final bool done;
  final bool optional;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXs),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(done ? Icons.check_circle : (optional ? Icons.radio_button_unchecked : Icons.error_outline),
              color: done ? AppTheme.success : (optional ? AppTheme.textMuted : AppTheme.warning), size: 20,
              semanticLabel: (done ? 'organization_v1.step_done' : 'organization_v1.step_pending').tr()),
          const SizedBox(width: AppTheme.spaceSm),
          // The action sits under the text so long labels and large text wrap.
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text),
            if (action != null) action!,
          ])),
        ]),
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.language});
  final OrgEvent event;
  final String language;
  @override
  Widget build(BuildContext context) {
    final text = orgEventText(event, language);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(event.read ? Icons.notifications_none_outlined : Icons.notifications_active_outlined,
          color: event.read ? AppTheme.textMuted : AppTheme.primary,
          semanticLabel: (event.read ? 'organization_v1.read' : 'organization_v1.unread').tr()),
      title: Text(text.title, style: TextStyle(fontWeight: event.read ? FontWeight.normal : FontWeight.w600)),
      subtitle: Text('${text.body}\n${_date(context, event.createdAt)}'),
      isThreeLine: true,
      onTap: () {
        final provider = context.read<AppProvider>();
        if (!event.read) provider.markNotificationAsRead('org:${event.id}');
        if (event.kind == 'invitation' && event.invitationId != null &&
            !provider.myOrganizationInvitations.any((i) => i.id == event.invitationId)) {
          return; // Already answered or expired; the card above is the source of truth.
        }
        context.push(event.route);
      },
    );
  }
}
