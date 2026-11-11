import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../models/org_event.dart';
import '../../models/org_event_text.dart';
import '../../models/org_invitation.dart';
import '../../models/org_membership.dart';

/// The organization home in Lantern and Arch: invitations, the organizations
/// the person belongs to (square avatars, their availability, transfers and
/// the owner's setup steps) and organization activity.
///
/// `OrganizationHubScreen` keeps the loads and the server actions; each
/// button calls back into it.
class LanternOrganizationHub extends StatelessWidget
    implements LanternSkinWidget {
  const LanternOrganizationHub(
      {super.key,
      required this.busy,
      required this.loaded,
      required this.error,
      required this.invitations,
      required this.memberships,
      required this.connectedOrganizations,
      required this.events,
      required this.onRefresh,
      required this.onAnswer,
      required this.onShows,
      required this.onMembers,
      required this.onChannel,
      required this.onAcceptTransfer,
      required this.onCancelTransfer,
      required this.onMarkAllRead,
      required this.onEvent});

  final bool busy, loaded;

  /// A translation key of the last refused action, or null.
  final String? error;
  final List<OrgInvitation> invitations;

  /// Memberships that are not revoked.
  final List<OrgMembership> memberships;

  /// Organizations whose YouTube channel is connected.
  final Set<String> connectedOrganizations;
  final List<OrgEvent> events;
  final VoidCallback onRefresh, onChannel, onMarkAllRead;
  final void Function(OrgInvitation invitation, bool accept) onAnswer;
  final ValueChanged<OrgMembership> onShows,
      onMembers,
      onAcceptTransfer,
      onCancelTransfer;
  final ValueChanged<OrgEvent> onEvent;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        final wide = context.lanternWide;
        final gutter = wide ? Lantern.webGutter : Lantern.gutter;
        final main = <Widget>[
          if (wide) ...[
            Row(children: [
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text('organization_v1.organizations'.tr(),
                          style: Lantern.displayStyle(30,
                              color: t.fg,
                              height: context.lanternArabic ? 1.45 : 1.25)))),
              LButton(
                  key: const ValueKey('lantern-org-refresh'),
                  label: 'organization_v1.refresh'.tr(),
                  kind: LButtonKind.secondary,
                  size: LButtonSize.small,
                  icon: LGlyph.refresh,
                  loading: busy,
                  onPressed: busy ? null : onRefresh),
            ]),
            const SizedBox(height: 6),
            Text('organization_v1.organizations_hint'.tr(),
                style: Lantern.textStyle(14, color: t.muted)),
            const SizedBox(height: 18),
          ],
          if (busy && !loaded)
            Column(key: const ValueKey('lantern-org-loading'), children: [
              for (var i = 0; i < 2; i++)
                const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LSkeleton(height: 150, radius: Lantern.radiusCard)),
            ]),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: LBanner(error!.tr(),
                    key: const ValueKey('lantern-org-error'),
                    tone: LTone.live,
                    icon: LGlyph.warn,
                    action: LButton(
                        label: 'organization_v1.refresh'.tr(),
                        kind: LButtonKind.ghost,
                        size: LButtonSize.small,
                        onPressed: busy ? null : onRefresh))),
          if (invitations.isNotEmpty) ...[
            _Heading('organization_v1.pending_invitations'.tr(),
                count: invitations.length),
            for (final invitation in invitations)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InvitationCard(
                      key: ValueKey('lantern-org-invitation-${invitation.id}'),
                      invitation: invitation,
                      busy: busy,
                      onAnswer: (accept) => onAnswer(invitation, accept))),
            const SizedBox(height: 8),
          ],
          _Heading('organization_v1.my_organizations'.tr(),
              count: memberships.isEmpty ? null : memberships.length),
          if (loaded && memberships.isEmpty && invitations.isEmpty)
            LEmptyState(
                key: const ValueKey('lantern-org-empty'),
                icon: LGlyph.org,
                title: 'organization_v1.no_organizations'.tr())
          else
            for (final m in memberships)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MembershipCard(
                      key: ValueKey(
                          'lantern-org-membership-${m.organizationId}'),
                      membership: m,
                      busy: busy,
                      channelConnected:
                          connectedOrganizations.contains(m.organizationId),
                      onShows: () => onShows(m),
                      onMembers: () => onMembers(m),
                      onChannel: onChannel,
                      onAcceptTransfer: () => onAcceptTransfer(m),
                      onCancelTransfer: () => onCancelTransfer(m))),
        ];
        final activity = events.isEmpty
            ? const <Widget>[]
            : <Widget>[
                _Activity(
                    events: events,
                    busy: busy,
                    onMarkAllRead: onMarkAllRead,
                    onEvent: onEvent),
              ];
        final Widget body;
        if (wide) {
          body = ListView(
              key: const ValueKey('lantern-org-hub'),
              padding: EdgeInsets.zero,
              children: [
                Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(
                            maxWidth:
                                Lantern.webContent + 2 * Lantern.webGutter),
                        child: Padding(
                            padding:
                                EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: main)),
                                  if (activity.isNotEmpty) ...[
                                    const SizedBox(width: 24),
                                    SizedBox(
                                        width: 360,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: activity)),
                                  ],
                                ])))),
                const LanternWebFooter(),
              ]);
        } else {
          body = ListView(
              key: const ValueKey('lantern-org-hub'),
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter,
                  24 + MediaQuery.paddingOf(context).bottom),
              children: [
                ...main,
                if (activity.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...activity
                ],
              ]);
        }
        return Scaffold(
            backgroundColor: t.bg,
            appBar: wide
                ? null
                : LanternPageBar(
                    title: 'organization_v1.organizations'.tr(),
                    actions: [
                        LIconButton(
                            key: const ValueKey('lantern-org-refresh'),
                            icon: LGlyph.refresh,
                            label: 'organization_v1.refresh'.tr(),
                            onPressed: busy ? null : onRefresh),
                      ]),
            body: wide
                ? Column(children: [
                    const LanternWebHeader(
                        active: LanternSection.organizations),
                    Expanded(child: body),
                  ])
                : body);
      }));
}

String _role(String role) => 'organization_v1.$role'.tr();

String _when(BuildContext context, DateTime value) =>
    DateFormat.yMMMd(context.locale.languageCode)
        .add_jm()
        .format(value.toLocal());

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.count});
  final String text;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(children: [
          Expanded(
              child: Semantics(
                  header: true,
                  child: Text(text,
                      style: Lantern.displayStyle(19,
                          color: t.fg,
                          height: context.lanternArabic ? 1.45 : 1.25)))),
          if (count != null)
            Text('$count',
                style: Lantern.textStyle(13, color: t.muted)
                    .copyWith(fontFeatures: Lantern.tabular)),
        ]));
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard(
      {super.key,
      required this.invitation,
      required this.busy,
      required this.onAnswer});

  final OrgInvitation invitation;
  final bool busy;
  final ValueChanged<bool> onAnswer;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final name = invitation.organizationName(context.locale.languageCode);
    return LCard(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LAvatar(name: name, size: 52, org: true),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(name,
                          style: Lantern.textStyle(15.5,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.35)),
                      const SizedBox(height: 2),
                      Text(
                          'organization_v1.invited_as'
                              .tr(namedArgs: {'role': _role(invitation.role)}),
                          style: Lantern.textStyle(13.5, color: t.muted)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (invitation.video)
                          LTag('organization_v1.video'.tr(),
                              icon: LGlyph.video, tone: LTone.gold),
                        if (invitation.audio)
                          LTag('organization_v1.audio'.tr(),
                              icon: LGlyph.audio, tone: LTone.audio),
                        LTag(
                            'organization_v1.expires'.tr(namedArgs: {
                              'date': _when(context, invitation.expiresAt)
                            }),
                            icon: LGlyph.clock),
                      ]),
                    ])),
              ]),
              const SizedBox(height: 14),
              Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    LButton(
                        key: ValueKey('lantern-org-decline-${invitation.id}'),
                        label: 'organization_v1.decline'.tr(),
                        kind: LButtonKind.ghost,
                        size: LButtonSize.small,
                        onPressed: busy ? null : () => onAnswer(false)),
                    LButton(
                        key: ValueKey('lantern-org-accept-${invitation.id}'),
                        label: 'organization_v1.accept'.tr(),
                        size: LButtonSize.small,
                        icon: LGlyph.check,
                        onPressed: busy ? null : () => onAnswer(true)),
                  ])),
            ]));
  }
}

class _MembershipCard extends StatelessWidget {
  const _MembershipCard(
      {super.key,
      required this.membership,
      required this.busy,
      required this.channelConnected,
      required this.onShows,
      required this.onMembers,
      required this.onChannel,
      required this.onAcceptTransfer,
      required this.onCancelTransfer});

  final OrgMembership membership;
  final bool busy, channelConnected;
  final VoidCallback onShows,
      onMembers,
      onChannel,
      onAcceptTransfer,
      onCancelTransfer;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final m = membership;
    final name =
        context.locale.languageCode == 'ar' && m.organizationNameAr.isNotEmpty
            ? m.organizationNameAr
            : m.organizationNameEn;
    final presenter =
        m.permissions.canGoLiveVideo || m.permissions.canGoAudioOnly;
    final expires =
        m.transferExpiresAt == null ? '' : _when(context, m.transferExpiresAt!);
    final steps = [channelConnected, m.v1Enabled, false];
    final links = [
      if (m.active && (presenter || m.canManageMembers || m.canModerate))
        (LGlyph.calendar, 'organization_v1.shows', onShows),
      if (m.active && m.canManageMembers)
        (LGlyph.users, 'organization_v1.members', onMembers),
      if (m.active && m.canManageChannel)
        (LGlyph.video, 'organization_v1.channels', onChannel),
    ];
    return LCard(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LAvatar(name: name, size: 52, org: true),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(name,
                          style: Lantern.textStyle(15.5,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.35)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        LTag(_role(m.roleValue),
                            tone:
                                m.canManageChannel ? LTone.gold : LTone.neutral,
                            icon: m.canManageChannel
                                ? LGlyph.crown
                                : LGlyph.person),
                        if (!m.active)
                          LTag('organization_v1.status_${m.statusValue}'.tr(),
                              tone: LTone.warn),
                        LTag(
                            (m.v1Enabled
                                    ? 'organization_v1.available'
                                    : 'organization_v1.not_enabled')
                                .tr(),
                            tone: m.v1Enabled ? LTone.ok : LTone.warn,
                            icon: m.v1Enabled ? LGlyph.check : LGlyph.clock),
                      ]),
                    ])),
              ]),
              if (!m.v1Enabled) ...[
                const SizedBox(height: 10),
                Text('organization_v1.not_enabled_hint'.tr(),
                    style:
                        Lantern.textStyle(13.5, color: t.muted, height: 1.5)),
              ],
              if (m.transferToMe) ...[
                const SizedBox(height: 12),
                LBanner(
                    'organization_v1.transfer_incoming'
                        .tr(namedArgs: {'date': expires}),
                    tone: LTone.gold,
                    icon: LGlyph.crown),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  LButton(
                      key: ValueKey(
                          'lantern-org-accept-transfer-${m.organizationId}'),
                      label: 'organization_v1.accept_transfer'.tr(),
                      size: LButtonSize.small,
                      onPressed: busy ? null : onAcceptTransfer),
                  LButton(
                      key: ValueKey(
                          'lantern-org-decline-transfer-${m.organizationId}'),
                      label: 'organization_v1.decline'.tr(),
                      kind: LButtonKind.ghost,
                      size: LButtonSize.small,
                      onPressed: busy ? null : onCancelTransfer),
                ]),
              ],
              if (m.canManageChannel && m.transferTargetId != null) ...[
                const SizedBox(height: 12),
                LBanner(
                    'organization_v1.transfer_pending'
                        .tr(namedArgs: {'date': expires}),
                    icon: LGlyph.clock,
                    action: LButton(
                        label: 'organization_v1.withdraw_transfer'.tr(),
                        kind: LButtonKind.ghost,
                        size: LButtonSize.small,
                        onPressed: busy ? null : onCancelTransfer)),
              ],
              if (m.canManageChannel) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                      child: Text('organization_v1.setup'.tr(),
                          style: Lantern.textStyle(14,
                              color: t.fg, weight: FontWeight.w700))),
                  Text(
                      'lantern.org.setup_count'.tr(namedArgs: {
                        'done': '${steps.where((s) => s).length}',
                        'total': '${steps.length}',
                      }),
                      style: Lantern.textStyle(12.5, color: t.muted)
                          .copyWith(fontFeatures: Lantern.tabular)),
                ]),
                const SizedBox(height: 8),
                LProgress(steps.where((s) => s).length / steps.length,
                    height: 6, label: 'organization_v1.setup'.tr()),
                const SizedBox(height: 10),
                _Step(
                    index: 1,
                    done: channelConnected,
                    text: 'organization_v1.setup_channel'.tr(),
                    action: channelConnected
                        ? null
                        : LLink('organization_v1.connect'.tr(),
                            onTap: onChannel)),
                _Step(
                    index: 2,
                    done: m.v1Enabled,
                    text: 'organization_v1.setup_pilot'.tr()),
                _Step(
                    index: 3,
                    done: false,
                    optional: true,
                    text: 'organization_v1.setup_members'.tr(),
                    action:
                        LLink('organization_v1.invite'.tr(), onTap: onMembers)),
              ],
              if (links.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final (icon, key, onTap) in links)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: LRow(
                          key: ValueKey(key),
                          icon: icon,
                          title: key.tr(),
                          dense: true,
                          onTap: onTap)),
              ],
            ]));
  }
}

class _Step extends StatelessWidget {
  const _Step(
      {required this.index,
      required this.done,
      required this.text,
      this.action,
      this.optional = false});

  final int index;
  final bool done, optional;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final state =
        (done ? 'organization_v1.step_done' : 'organization_v1.step_pending')
            .tr();
    return Semantics(
        label: '$text, $state',
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ExcludeSemantics(
                  child: Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: done ? Lantern.goldFill : null,
                          color: done ? null : t.sunk,
                          border: Border.all(
                              color: done ? LanternTokens.goldLo : t.line,
                              width: 1.5)),
                      child: done
                          ? const LIcon(LGlyph.check,
                              size: 14, color: LanternTokens.onGold)
                          : Text('$index',
                              style: Lantern.textStyle(12,
                                  color: t.muted,
                                  weight: FontWeight.w700,
                                  height: 1.1)))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    ExcludeSemantics(
                        child: Text(text,
                            style: Lantern.textStyle(14,
                                color: t.fg, height: 1.45))),
                    ExcludeSemantics(
                        child: Text(state,
                            style: Lantern.textStyle(12.5,
                                color:
                                    done ? t.ok : (optional ? t.muted : t.warn),
                                weight: FontWeight.w600))),
                    if (action != null) action!,
                  ])),
            ])));
  }
}

class _Activity extends StatelessWidget {
  const _Activity(
      {required this.events,
      required this.busy,
      required this.onMarkAllRead,
      required this.onEvent});

  final List<OrgEvent> events;
  final bool busy;
  final VoidCallback onMarkAllRead;
  final ValueChanged<OrgEvent> onEvent;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final unread = events.where((e) => !e.read).length;
    return LCard(
        key: const ValueKey('lantern-org-activity'),
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                    child: Semantics(
                        header: true,
                        child: Text('organization_v1.activity'.tr(),
                            style: Lantern.displayStyle(17,
                                color: t.fg,
                                height: context.lanternArabic ? 1.45 : 1.25)))),
                if (unread > 0) LTag('$unread', tone: LTone.gold),
              ]),
              const SizedBox(height: 10),
              for (final event in events.take(30))
                Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: () {
                      final text = orgEventText(event, lang);
                      return LRow(
                          key: ValueKey('lantern-org-event-${event.id}'),
                          dense: true,
                          leading: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: event.read ? t.sunk : t.warnSoft,
                                  borderRadius: BorderRadius.circular(
                                      Lantern.radiusTile)),
                              child: LIcon(
                                  event.liveAlert ? LGlyph.live : LGlyph.bell,
                                  size: 18,
                                  color: event.read ? t.muted : t.goldInk,
                                  label: (event.read
                                          ? 'organization_v1.read'
                                          : 'organization_v1.unread')
                                      .tr())),
                          title: text.title,
                          subtitle:
                              '${text.body}\n${_when(context, event.createdAt)}',
                          onTap: () => onEvent(event));
                    }()),
              if (unread > 0)
                Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: LButton(
                        key: const ValueKey('lantern-org-mark-read'),
                        label: 'organization_v1.mark_all_read'.tr(),
                        kind: LButtonKind.ghost,
                        size: LButtonSize.small,
                        onPressed: busy ? null : onMarkAllRead)),
            ]));
  }
}
