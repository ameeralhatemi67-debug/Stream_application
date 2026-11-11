import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../models/channel_connection.dart';
import '../../models/org_membership.dart';

/// YouTube connections in Lantern and Arch: connect the personal channel or
/// an organization's, and see or disconnect the channels already linked.
/// `ChannelConnectionsScreen` keeps the loads, the consent flow and the
/// server calls.
class LanternChannelsView extends StatelessWidget implements LanternSkinWidget {
  const LanternChannelsView(
      {super.key,
      required this.returnStatus,
      required this.busy,
      required this.error,
      required this.personal,
      required this.owners,
      required this.channels,
      required this.currentUserId,
      required this.canGoBack,
      required this.onClose,
      required this.onRefresh,
      required this.onConnect,
      required this.onDisconnect});

  /// `connected` or `failed` after Google's consent returns to the app.
  final String? returnStatus;
  final bool busy, personal, canGoBack;

  /// Already translated.
  final String? error;
  final List<OrgMembership> owners;
  final List<ChannelConnection> channels;
  final String? currentUserId;
  final VoidCallback onClose, onRefresh;

  /// Null connects the personal channel.
  final ValueChanged<String?> onConnect;
  final ValueChanged<ChannelConnection> onDisconnect;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        final wide = context.lanternWide;
        final gutter = wide ? Lantern.webGutter : Lantern.gutter;
        final lang = context.locale.languageCode;
        Widget row(
                {Key? key,
                required LGlyph icon,
                required String title,
                Widget? details,
                Widget? action}) =>
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LCard(
                    key: key,
                    padding: const EdgeInsets.all(14),
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: t.sunk,
                                    borderRadius: BorderRadius.circular(
                                        Lantern.radiusTile)),
                                child: LIcon(icon, size: 20, color: t.goldInk)),
                            const SizedBox(width: 12),
                            Flexible(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                  Text(title,
                                      style: Lantern.textStyle(14.5,
                                          color: t.fg,
                                          weight: FontWeight.w700,
                                          height: 1.35)),
                                  if (details != null) ...[
                                    const SizedBox(height: 4),
                                    details,
                                  ],
                                ])),
                          ]),
                          if (action != null) action,
                        ])));
        final children = <Widget>[
          if (wide) ...[
            Row(children: [
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text('organization_v1.channels'.tr(),
                          style: Lantern.displayStyle(30,
                              color: t.fg,
                              height: context.lanternArabic ? 1.45 : 1.25)))),
              LButton(
                  key: const ValueKey('lantern-channels-refresh'),
                  label: 'organization_v1.refresh'.tr(),
                  kind: LButtonKind.secondary,
                  size: LButtonSize.small,
                  icon: LGlyph.refresh,
                  loading: busy,
                  onPressed: busy ? null : onRefresh),
            ]),
            const SizedBox(height: 16),
          ],
          LBanner('organization_v1.channel_consent_hint'.tr(),
              icon: LGlyph.info),
          const SizedBox(height: 12),
          if (returnStatus == 'connected' || returnStatus == 'failed') ...[
            LBanner('organization_v1.consent_$returnStatus'.tr(),
                key: const ValueKey('lantern-channels-return'),
                tone: returnStatus == 'failed' ? LTone.live : LTone.ok,
                icon: returnStatus == 'failed' ? LGlyph.warn : LGlyph.check),
            const SizedBox(height: 12),
          ],
          if (busy)
            const Padding(
                key: ValueKey('lantern-channels-loading'),
                padding: EdgeInsets.only(bottom: 12),
                child: Center(child: LStarLoader())),
          if (error != null) ...[
            LBanner(error!,
                key: const ValueKey('lantern-channels-error'),
                tone: LTone.live,
                icon: LGlyph.warn),
            const SizedBox(height: 12),
          ],
          if (personal)
            row(
                key: const ValueKey('lantern-channels-personal'),
                icon: LGlyph.person,
                title: 'organization_v1.personal_destination'.tr(),
                action: LButton(
                    label: 'organization_v1.connect'.tr(),
                    size: LButtonSize.small,
                    icon: LGlyph.video,
                    onPressed: busy ? null : () => onConnect(null))),
          for (final m in owners)
            row(
                key: ValueKey('lantern-channels-org-${m.organizationId}'),
                icon: LGlyph.org,
                title:
                    lang == 'ar' ? m.organizationNameAr : m.organizationNameEn,
                details: LTag('organization_v1.${m.roleValue}'.tr(),
                    tone: LTone.gold, icon: LGlyph.crown),
                action: LButton(
                    label: 'organization_v1.connect'.tr(),
                    size: LButtonSize.small,
                    icon: LGlyph.video,
                    onPressed:
                        busy ? null : () => onConnect(m.organizationId))),
          for (final c in channels)
            row(
                key: ValueKey('lantern-channel-${c.id}'),
                icon: LGlyph.play,
                title: c.title,
                details: Wrap(spacing: 8, runSpacing: 6, children: [
                  Text(c.channelId,
                      textDirection: TextDirection.ltr,
                      style: Lantern.textStyle(12.5, color: t.muted)),
                  LTag('organization_v1.channel_${c.status}'.tr(),
                      tone: c.connected ? LTone.ok : LTone.warn,
                      icon: c.connected ? LGlyph.check : LGlyph.warn),
                ]),
                action: c.ownerId != currentUserId
                    ? null
                    : LButton(
                        key: ValueKey('lantern-channel-disconnect-${c.id}'),
                        label: 'organization_v1.disconnect'.tr(),
                        kind: LButtonKind.ghost,
                        size: LButtonSize.small,
                        onPressed: busy ? null : () => onDisconnect(c))),
          if (channels.isEmpty && !busy)
            LEmptyState(
                key: const ValueKey('lantern-channels-empty'),
                icon: LGlyph.play,
                compact: true,
                title: 'organization_v1.no_channel'.tr()),
        ];
        final list = ListView(
            key: const ValueKey('lantern-channels'),
            padding: wide
                ? EdgeInsets.zero
                : EdgeInsets.fromLTRB(gutter, 16, gutter,
                    24 + MediaQuery.paddingOf(context).bottom),
            children: wide
                ? [
                    Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: Padding(
                                padding:
                                    EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: children)))),
                    const LanternWebFooter(),
                  ]
                : children);
        return Scaffold(
            backgroundColor: t.bg,
            appBar: wide
                ? null
                : LanternPageBar(
                    title: 'organization_v1.channels'.tr(),
                    // Opened from a return link with nothing underneath, the
                    // back button still leads somewhere.
                    onBack: canGoBack ? null : onClose,
                    actions: [
                        LIconButton(
                            key: const ValueKey('lantern-channels-refresh'),
                            icon: LGlyph.refresh,
                            label: 'organization_v1.refresh'.tr(),
                            onPressed: busy ? null : onRefresh),
                      ]),
            body: wide
                ? Column(children: [
                    const LanternWebHeader(),
                    Expanded(child: list),
                  ])
                : list);
      }));
}
