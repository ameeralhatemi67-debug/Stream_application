import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../live_stream/models/broadcast_session.dart';
import '../../models/org_membership.dart';
import '../../models/org_venue_branch_model.dart';

/// One show with what this person may do with it, decided by
/// `OrganizationShowsScreen` from the same rules as the older design.
typedef LanternShowItem = ({
  BroadcastSession session,
  bool moderate,
  bool answer,
  bool edit,
  bool replaceSeries,
  bool end,
  bool cancelSeries,
  bool open,
});

/// Shows and assignments in Lantern and Arch: the destination (my
/// assignments or one organization), scheduling for leaders, and each show
/// with its state and actions.
class LanternShowsView extends StatelessWidget implements LanternSkinWidget {
  const LanternShowsView(
      {super.key,
      required this.organizations,
      required this.selected,
      required this.onSelect,
      required this.busy,
      required this.error,
      required this.notEnabled,
      required this.canSchedule,
      required this.items,
      required this.onRefresh,
      required this.onSchedule,
      required this.onStudio,
      required this.onModerate,
      required this.onAnswer,
      required this.onEdit,
      required this.onEnd,
      required this.onCancelSeries,
      required this.onOpen});

  /// Active memberships; [selected] is an organization id, or null for the
  /// person's own assignments.
  final List<OrgMembership> organizations;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final bool busy, notEnabled, canSchedule;
  final String? error;
  final List<LanternShowItem> items;
  final VoidCallback onRefresh, onSchedule, onStudio;
  final ValueChanged<BroadcastSession> onModerate,
      onEnd,
      onCancelSeries,
      onOpen;
  final void Function(BroadcastSession session, bool accept) onAnswer;
  final void Function(BroadcastSession session, bool series) onEdit;

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: (context) {
        final t = context.lt;
        final wide = context.lanternWide;
        final gutter = wide ? Lantern.webGutter : Lantern.gutter;
        final lang = context.locale.languageCode;
        final children = <Widget>[
          if (wide) ...[
            Row(children: [
              Expanded(
                  child: Semantics(
                      header: true,
                      child: Text('organization_v1.shows'.tr(),
                          style: Lantern.displayStyle(30,
                              color: t.fg,
                              height: context.lanternArabic ? 1.45 : 1.25)))),
              LButton(
                  key: const ValueKey('lantern-shows-refresh'),
                  label: 'organization_v1.refresh'.tr(),
                  kind: LButtonKind.secondary,
                  size: LButtonSize.small,
                  icon: LGlyph.refresh,
                  loading: busy,
                  onPressed: busy ? null : onRefresh),
            ]),
            const SizedBox(height: 16),
          ],
          Text('organization_v1.destination'.tr(),
              style: Lantern.textStyle(13,
                  color: t.muted, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
              key: const ValueKey('lantern-shows-destinations'),
              spacing: 8,
              runSpacing: 8,
              children: [
                LChip(
                    key: const ValueKey('lantern-shows-mine'),
                    label: 'organization_v1.my_assignments'.tr(),
                    icon: LGlyph.person,
                    selected: selected == null,
                    onTap: busy ? null : () => onSelect(null)),
                for (final m in organizations)
                  LChip(
                      key: ValueKey('lantern-shows-org-${m.organizationId}'),
                      label: lang == 'ar'
                          ? m.organizationNameAr
                          : m.organizationNameEn,
                      icon: LGlyph.org,
                      selected: selected == m.organizationId,
                      onTap: busy ? null : () => onSelect(m.organizationId)),
              ]),
          const SizedBox(height: 10),
          Row(children: [
            LIcon(LGlyph.clock, size: 16, color: t.muted),
            const SizedBox(width: 6),
            Expanded(
                child: Text('organization_v1.riyadh'.tr(),
                    style: Lantern.textStyle(12.5, color: t.muted))),
          ]),
          if (notEnabled) ...[
            const SizedBox(height: 12),
            LBanner('organization_v1.not_enabled_hint'.tr(),
                tone: LTone.warn, icon: LGlyph.info),
          ],
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (canSchedule)
              LButton(
                  key: const ValueKey('lantern-shows-schedule'),
                  label: 'organization_v1.schedule'.tr(),
                  icon: LGlyph.plus,
                  onPressed: busy ? null : onSchedule),
            LButton(
                key: const ValueKey('lantern-shows-studio'),
                label: 'organization_v1.studio'.tr(),
                kind: LButtonKind.secondary,
                icon: LGlyph.video,
                onPressed: onStudio),
          ]),
          const SizedBox(height: 16),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: LBanner(error!.tr(),
                    key: const ValueKey('lantern-shows-error'),
                    tone: LTone.live,
                    icon: LGlyph.warn)),
          if (busy && items.isEmpty)
            Column(key: const ValueKey('lantern-shows-loading'), children: [
              for (var i = 0; i < 2; i++)
                const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LSkeleton(height: 130, radius: Lantern.radiusCard)),
            ])
          else if (items.isEmpty)
            LEmptyState(
                key: const ValueKey('lantern-shows-empty'),
                icon: LGlyph.calendar,
                title: 'organization_v1.no_shows'.tr())
          else ...[
            if (busy)
              const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LProgress(.5, height: 4)),
            for (final item in items)
              Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ShowCard(
                      key: ValueKey('lantern-show-${item.session.id}'),
                      item: item,
                      busy: busy,
                      onModerate: () => onModerate(item.session),
                      onAccept: () => onAnswer(item.session, true),
                      onDecline: () => onAnswer(item.session, false),
                      onEdit: () => onEdit(item.session, false),
                      onReplace: () => onEdit(item.session, true),
                      onEnd: () => onEnd(item.session),
                      onCancelSeries: () => onCancelSeries(item.session),
                      onOpen: () => onOpen(item.session))),
          ],
        ];
        final list = ListView(
            key: const ValueKey('lantern-shows'),
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
                : LanternPageBar(title: 'organization_v1.shows'.tr(), actions: [
                    LIconButton(
                        key: const ValueKey('lantern-shows-refresh'),
                        icon: LGlyph.refresh,
                        label: 'organization_v1.refresh'.tr(),
                        onPressed: busy ? null : onRefresh),
                  ]),
            body: wide
                ? Column(children: [
                    const LanternWebHeader(
                        active: LanternSection.organizations),
                    Expanded(child: list),
                  ])
                : list);
      }));
}

class _ShowCard extends StatelessWidget {
  const _ShowCard(
      {super.key,
      required this.item,
      required this.busy,
      required this.onModerate,
      required this.onAccept,
      required this.onDecline,
      required this.onEdit,
      required this.onReplace,
      required this.onEnd,
      required this.onCancelSeries,
      required this.onOpen});

  final LanternShowItem item;
  final bool busy;
  final VoidCallback onModerate,
      onAccept,
      onDecline,
      onEdit,
      onReplace,
      onEnd,
      onCancelSeries,
      onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final s = item.session;
    final lang = context.locale.languageCode;
    final tone = s.live
        ? LTone.live
        : switch (s.state) {
            'awaiting_acceptance' => LTone.warn,
            'scheduled' => LTone.ok,
            _ => LTone.neutral,
          };
    return LCard(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(s.title(lang),
                        style: Lantern.textStyle(15.5,
                            color: t.fg,
                            weight: FontWeight.w700,
                            height: 1.4))),
                const SizedBox(width: 8),
                if (s.live)
                  LBadge('organization_v1.state_live'.tr(),
                      kind: LBadgeKind.live, small: true)
                else
                  LTag('organization_v1.state_${s.state}'.tr(), tone: tone),
              ]),
              if (s.startUtc != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  LIcon(LGlyph.calendar, size: 15, color: t.muted),
                  const SizedBox(width: 6),
                  Text(
                      DateFormat('yyyy-MM-dd HH:mm', lang)
                          .format(s.startUtc!.add(const Duration(hours: 3))),
                      style: Lantern.textStyle(13, color: t.muted)
                          .copyWith(fontFeatures: Lantern.tabular)),
                ]),
              ],
              if (s.terminationPending) ...[
                const SizedBox(height: 10),
                LBanner('organization_v1.termination_pending'.tr(),
                    tone: LTone.warn, icon: LGlyph.warn),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (item.answer) ...[
                  LButton(
                      key: ValueKey('lantern-show-accept-${s.id}'),
                      label: 'organization_v1.accept'.tr(),
                      size: LButtonSize.small,
                      icon: LGlyph.check,
                      onPressed: busy ? null : onAccept),
                  LButton(
                      key: ValueKey('lantern-show-decline-${s.id}'),
                      label: 'organization_v1.decline'.tr(),
                      kind: LButtonKind.ghost,
                      size: LButtonSize.small,
                      onPressed: busy ? null : onDecline),
                ],
                if (item.open)
                  LButton(
                      label: 'organization_v1.open_room'.tr(),
                      size: LButtonSize.small,
                      icon: LGlyph.play,
                      onPressed: onOpen),
                if (item.moderate)
                  LButton(
                      label: 'design_ui.chat_moderation'.tr(),
                      kind: LButtonKind.secondary,
                      size: LButtonSize.small,
                      icon: LGlyph.shield,
                      onPressed: onModerate),
                if (item.edit)
                  LButton(
                      key: ValueKey('lantern-show-edit-${s.id}'),
                      label: 'organization_v1.edit_occurrence'.tr(),
                      kind: LButtonKind.secondary,
                      size: LButtonSize.small,
                      icon: LGlyph.edit,
                      onPressed: busy ? null : onEdit),
                if (item.replaceSeries)
                  LButton(
                      label: 'organization_v1.replace_series'.tr(),
                      kind: LButtonKind.secondary,
                      size: LButtonSize.small,
                      icon: LGlyph.clock,
                      onPressed: busy ? null : onReplace),
                if (item.end)
                  LButton(
                      key: ValueKey('lantern-show-end-${s.id}'),
                      label: 'organization_v1.end'.tr(),
                      kind: LButtonKind.ghost,
                      size: LButtonSize.small,
                      icon: LGlyph.stop,
                      onPressed: busy ? null : onEnd),
                if (item.cancelSeries)
                  LButton(
                      key: ValueKey('lantern-show-cancel-series-${s.id}'),
                      label: 'organization_v1.cancel_series'.tr(),
                      kind: LButtonKind.ghost,
                      size: LButtonSize.small,
                      icon: LGlyph.close,
                      onPressed: busy ? null : onCancelSeries),
              ]),
            ]));
  }
}

/// The schedule form in Lantern and Arch. The older editor keeps the
/// values, the validation and the save; this draws them.
class LanternScheduleForm extends StatelessWidget implements LanternSkinWidget {
  const LanternScheduleForm(
      {super.key,
      required this.occurrence,
      required this.titleEn,
      required this.titleAr,
      required this.presenters,
      required this.presenter,
      required this.onPresenter,
      required this.venues,
      required this.venue,
      required this.onVenue,
      required this.audio,
      required this.onAudio,
      required this.weekly,
      required this.onWeekly,
      required this.days,
      required this.onDay,
      required this.dateLabel,
      required this.onPickDate,
      required this.timeLabel,
      required this.onPickTime,
      required this.busy,
      required this.error,
      required this.onClose,
      required this.onSave});

  /// Editing one occurrence: no titles and no weekly repeat.
  final bool occurrence;
  final TextEditingController titleEn, titleAr;
  final List<OrgMembership> presenters;
  final String? presenter, venue;
  final ValueChanged<String> onPresenter;
  final List<OrgVenueBranchModel> venues;
  final ValueChanged<String?> onVenue;
  final bool audio, weekly, busy;
  final ValueChanged<bool> onAudio, onWeekly;
  final Set<int> days;
  final void Function(int day, bool on) onDay;
  final String dateLabel, timeLabel;
  final VoidCallback onPickDate, onPickTime, onClose, onSave;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    Widget label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text,
            style:
                Lantern.textStyle(13.5, color: t.fg, weight: FontWeight.w700)));
    Widget toggle(String text, bool value, ValueChanged<bool> onChanged) =>
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Expanded(
                  child: Text(text, style: Lantern.textStyle(14, color: t.fg))),
              LSwitch(
                  value: value,
                  label: text,
                  onChanged: busy ? null : onChanged),
            ]));
    return Column(
        key: const ValueKey('lantern-schedule-form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('organization_v1.riyadh'.tr(),
              style: Lantern.textStyle(13, color: t.muted)),
          if (!occurrence) ...[
            const SizedBox(height: 12),
            LField(
                key: const ValueKey('lantern-schedule-title-en'),
                controller: titleEn,
                label: 'organization_v1.title_en'.tr(),
                maxLength: 100,
                textDirection: TextDirection.ltr),
            const SizedBox(height: 8),
            LField(
                key: const ValueKey('lantern-schedule-title-ar'),
                controller: titleAr,
                label: 'organization_v1.title_ar'.tr(),
                maxLength: 100,
                textDirection: TextDirection.rtl),
          ],
          label('organization_v1.presenter'.tr()),
          if (presenters.isEmpty)
            Text('lantern.org.no_presenters'.tr(),
                style: Lantern.textStyle(13, color: t.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in presenters)
                LChip(
                    key: ValueKey('lantern-schedule-presenter-${m.profileId}'),
                    label: lang == 'ar' ? m.nameAr : m.nameEn,
                    icon: LGlyph.person,
                    selected: m.profileId == presenter,
                    onTap: busy ? null : () => onPresenter(m.profileId)),
            ]),
          if (venues.isNotEmpty) ...[
            label('organization_v1.venue'.tr()),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final v in venues)
                LChip(
                    label: lang == 'ar' ? v.nameAr : v.nameEn,
                    icon: LGlyph.pin,
                    selected: v.venueId == venue,
                    onTap: busy
                        ? null
                        : () => onVenue(v.venueId == venue ? null : v.venueId)),
            ]),
          ],
          toggle('organization_v1.audio'.tr(), audio, onAudio),
          if (!occurrence)
            toggle('organization_v1.weekly'.tr(), weekly, onWeekly),
          const SizedBox(height: 12),
          if (weekly)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var day = 1; day <= 7; day++)
                LChip(
                    key: ValueKey('lantern-schedule-day-$day'),
                    dense: true,
                    label: DateFormat.E(lang)
                        .format(DateTime.utc(2026, 9, 27 + day)),
                    selected: days.contains(day),
                    onTap: busy ? null : () => onDay(day, !days.contains(day))),
            ])
          else
            Align(
                alignment: AlignmentDirectional.centerStart,
                child: LButton(
                    key: const ValueKey('lantern-schedule-date'),
                    label: dateLabel,
                    kind: LButtonKind.secondary,
                    size: LButtonSize.small,
                    icon: LGlyph.calendar,
                    onPressed: busy ? null : onPickDate)),
          const SizedBox(height: 8),
          Align(
              alignment: AlignmentDirectional.centerStart,
              child: LButton(
                  key: const ValueKey('lantern-schedule-time'),
                  label: timeLabel,
                  kind: LButtonKind.secondary,
                  size: LButtonSize.small,
                  icon: LGlyph.clock,
                  onPressed: busy ? null : onPickTime)),
          const SizedBox(height: 12),
          Text('organization_v1.acceptance_reset'.tr(),
              style: Lantern.textStyle(12.5, color: t.muted, height: 1.45)),
          if (error != null) ...[
            const SizedBox(height: 10),
            LBanner(error!.tr(),
                key: const ValueKey('lantern-schedule-error'),
                tone: LTone.live,
                icon: LGlyph.warn),
          ],
          const SizedBox(height: 16),
          Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: [
                LButton(
                    label: 'organization_v1.close'.tr(),
                    kind: LButtonKind.ghost,
                    onPressed: busy ? null : onClose),
                LButton(
                    key: const ValueKey('lantern-schedule-save'),
                    label: 'organization_v1.save'.tr(),
                    loading: busy,
                    onPressed: busy ? null : onSave),
              ]),
        ]);
  }
}
