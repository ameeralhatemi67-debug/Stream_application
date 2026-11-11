import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../lessons/domain/lessons_dates.dart' show agoLabel;
import '../../models/broadcaster_application_model.dart';

/// The verification queue in Lantern and Arch, the tab reviewers live in.
///
/// Every value and action comes from `AdminHubScreen`: the filter, the
/// search, the selection and the review log are its state, and each button
/// calls back into it. The view only filters the rows it is given the way the
/// older tab does, so both show the same applications.
class LanternVerificationQueue extends StatefulWidget
    implements LanternSkinWidget {
  const LanternVerificationQueue(
      {super.key,
      required this.rows,
      required this.filter,
      required this.onFilter,
      required this.search,
      required this.onSearchChanged,
      required this.showLog,
      required this.onShowLog,
      required this.selected,
      required this.onSelect,
      required this.onSelectAll,
      required this.onClearSelection,
      required this.onRefresh,
      required this.onInspect,
      required this.onApprove,
      required this.onReject,
      required this.onRemove,
      required this.onApproveSelected,
      required this.onRejectSelected,
      required this.events,
      required this.isReversible,
      required this.onEventDetails,
      required this.onReverse});

  /// The queue's rows (`verificationQueueRows`), before filter and search.
  final List<BroadcasterApplicationModel> rows;
  final ApplicationStatus? filter;
  final ValueChanged<ApplicationStatus?> onFilter;
  final TextEditingController search;
  final VoidCallback onSearchChanged;
  final bool showLog;
  final ValueChanged<bool> onShowLog;
  final Set<String> selected;
  final void Function(String id, bool on) onSelect;
  final void Function(List<String> ids, bool on) onSelectAll;
  final VoidCallback onClearSelection;

  /// Reloads applications and the log; the list shows its loading state
  /// until it returns.
  final Future<void> Function() onRefresh;
  final ValueChanged<BroadcasterApplicationModel> onInspect,
      onApprove,
      onReject,
      onRemove;
  final VoidCallback onApproveSelected, onRejectSelected;
  final List<Map<String, dynamic>> events;
  final bool Function(Map<String, dynamic> event) isReversible;
  final ValueChanged<Map<String, dynamic>> onEventDetails, onReverse;

  @override
  State<LanternVerificationQueue> createState() =>
      _LanternVerificationQueueState();
}

class _LanternVerificationQueueState extends State<LanternVerificationQueue> {
  bool _loading = false;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// The same search as the older tab.
  List<BroadcasterApplicationModel> _searched() {
    final query = widget.search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.rows;
    return widget.rows.where((a) {
      return a.applicantNameEn.toLowerCase().contains(query) ||
          a.applicantNameAr.contains(query) ||
          a.email.toLowerCase().contains(query) ||
          (a.institutionEn?.toLowerCase().contains(query) ?? false) ||
          a.venueNameEn.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final searched = _searched();
    final shown = widget.filter == null
        ? searched
        : searched.where((a) => a.status == widget.filter).toList();
    final pendingIds = shown
        .where((a) => a.status == ApplicationStatus.pending)
        .map((a) => a.id)
        .toList();
    final chosen = pendingIds.where(widget.selected.contains).length;
    final gutter = context.lanternWide ? Lantern.webGutter : Lantern.gutter;
    int count(ApplicationStatus? s) => s == null
        ? searched.length
        : searched.where((a) => a.status == s).length;

    final children = <Widget>[
      Row(children: [
        Expanded(
            child: Semantics(
                header: true,
                child: Text('admin.tab_verification'.tr(),
                    style: Lantern.displayStyle(context.lanternWide ? 26 : 22,
                        color: t.fg,
                        height: context.lanternArabic ? 1.45 : 1.25)))),
        LIconButton(
            key: const ValueKey('lantern-queue-refresh'),
            icon: LGlyph.refresh,
            label: 'admin.refresh_reviews'.tr(),
            onPressed: _loading ? null : _refresh),
      ]),
      const SizedBox(height: 12),
      Align(
          alignment: AlignmentDirectional.centerStart,
          child: LSegmented<bool>(
              key: const ValueKey('lantern-queue-tabs'),
              value: widget.showLog,
              segments: [
                (
                  value: false,
                  label: 'admin.queue_tab'.tr(),
                  icon: LGlyph.list
                ),
                (
                  value: true,
                  label: 'admin.review_log_tab'.tr(),
                  icon: LGlyph.history
                ),
              ],
              onChanged: widget.onShowLog)),
      const SizedBox(height: 14),
    ];

    if (widget.showLog) {
      children.addAll(_log(context));
    } else {
      children.addAll([
        LField(
            key: const ValueKey('lantern-queue-search'),
            controller: widget.search,
            pill: true,
            icon: LGlyph.search,
            hint: 'admin.search_applications'.tr(),
            onChanged: (_) => widget.onSearchChanged()),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (label, status) in <(String, ApplicationStatus?)>[
            ('admin.filter_all'.tr(), null),
            ('admin.filter_pending'.tr(), ApplicationStatus.pending),
            ('admin.filter_approved'.tr(), ApplicationStatus.approved),
            ('admin.filter_rejected'.tr(), ApplicationStatus.rejected),
          ])
            LChip(
                key: ValueKey('lantern-queue-filter-${status?.name ?? 'all'}'),
                label: label,
                count: count(status),
                selected: widget.filter == status,
                onTap: () => widget.onFilter(status)),
        ]),
        const SizedBox(height: 10),
        if (pendingIds.isNotEmpty && !_loading)
          Row(children: [
            LCheckbox(
                key: const ValueKey('lantern-queue-select-all'),
                value: chosen == 0
                    ? false
                    : chosen == pendingIds.length
                        ? true
                        : null,
                label: 'lantern.admin.select_all_pending'.tr(),
                onChanged: (_) => widget.onSelectAll(
                    pendingIds, chosen != pendingIds.length)),
            const SizedBox(width: 4),
            Flexible(
                child: Text('lantern.admin.select_all_pending'.tr(),
                    style:
                        Lantern.textStyle(13.5, color: t.muted, height: 1.35))),
          ]),
        const SizedBox(height: 6),
        if (_loading)
          Column(key: const ValueKey('lantern-queue-loading'), children: [
            for (var i = 0; i < 3; i++)
              const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LSkeleton(height: 132, radius: Lantern.radiusCard)),
          ])
        else if (shown.isEmpty)
          LEmptyState(
              key: const ValueKey('lantern-queue-empty'),
              icon: LGlyph.verified,
              title: 'design_ui.no_applications_match_the_selected_filter'.tr(),
              body: widget.rows.isEmpty
                  ? 'lantern.admin.queue_empty_body'.tr()
                  : null,
              action: widget.filter == null && widget.search.text.isEmpty
                  ? null
                  : LButton(
                      label: 'lantern.admin.show_all'.tr(),
                      kind: LButtonKind.secondary,
                      onPressed: () {
                        widget.search.clear();
                        widget.onSearchChanged();
                        widget.onFilter(null);
                      }))
        else
          for (final app in shown)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApplicationCard(
                    key: ValueKey('lantern-application-${app.id}'),
                    app: app,
                    selected: widget.selected.contains(app.id),
                    onSelect: (on) => widget.onSelect(app.id, on),
                    onInspect: () => widget.onInspect(app),
                    onApprove: () => widget.onApprove(app),
                    onReject: () => widget.onReject(app),
                    onRemove: () => widget.onRemove(app))),
      ]);
    }

    final count0 = widget.selected.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
          child: ListView(
              key: const ValueKey('lantern-verification-queue'),
              padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 24),
              children: children)),
      if (count0 > 0 && !widget.showLog)
        _BatchBar(
            count: count0,
            onClear: widget.onClearSelection,
            onApprove: widget.onApproveSelected,
            onReject: widget.onRejectSelected),
    ]);
  }

  List<Widget> _log(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    if (widget.events.isEmpty) {
      return [
        LEmptyState(
            key: const ValueKey('lantern-review-log-empty'),
            icon: LGlyph.history,
            title: 'admin.review_log_empty'.tr()),
      ];
    }
    return [
      for (final event in widget.events)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: () {
              final action = event['action'] as String? ?? '';
              final localOnly =
                  (event['id'] as String? ?? '').startsWith('local-');
              final name = lang == 'ar'
                  ? event['applicant_name_ar'] as String? ?? ''
                  : event['applicant_name_en'] as String? ?? '';
              final when =
                  DateTime.tryParse(event['created_at'] as String? ?? '');
              final reason = event['reason'] as String? ?? '';
              return LCard(
                  key: ValueKey('lantern-review-event-${event['id']}'),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(name,
                                  style: Lantern.textStyle(14.5,
                                      color: t.fg,
                                      weight: FontWeight.w600,
                                      height: 1.35)),
                              LTag('admin.log_$action'.tr(),
                                  tone: switch (action) {
                                    'approved' => LTone.ok,
                                    'rejected' => LTone.live,
                                    _ => LTone.neutral,
                                  }),
                            ]),
                        const SizedBox(height: 4),
                        Text(
                            [
                              event['actor_name'] as String? ?? 'Admin',
                              if (when != null) agoLabel(when.toLocal(), lang),
                            ].join(' · '),
                            style: Lantern.textStyle(12.5,
                                color: t.muted, height: 1.4)),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(reason,
                              style: Lantern.textStyle(13.5,
                                  color: t.fg, height: 1.5)),
                        ],
                        if (localOnly) ...[
                          const SizedBox(height: 6),
                          Text('admin.local_log_notice'.tr(),
                              style: Lantern.textStyle(12.5,
                                  color: t.muted, height: 1.4)),
                        ],
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          LButton(
                              label: 'admin.btn_inspect'.tr(),
                              kind: LButtonKind.ghost,
                              size: LButtonSize.small,
                              icon: LGlyph.eye,
                              onPressed: () => widget.onEventDetails(event)),
                          if (widget.isReversible(event))
                            LButton(
                                key: ValueKey(
                                    'lantern-review-reverse-${event['id']}'),
                                label: action == 'approved'
                                    ? 'admin.reverse_approval'.tr()
                                    : 'admin.approve_instead'.tr(),
                                kind: LButtonKind.secondary,
                                size: LButtonSize.small,
                                icon: LGlyph.history,
                                onPressed: () => widget.onReverse(event)),
                        ]),
                      ]));
            }()),
    ];
  }
}

/// The status of an application in words and a tone.
({String label, LTone tone}) lanternApplicationStatus(ApplicationStatus s) =>
    switch (s) {
      ApplicationStatus.pending => (
          label: 'admin.filter_pending'.tr(),
          tone: LTone.warn
        ),
      ApplicationStatus.approved => (
          label: 'admin.filter_approved'.tr(),
          tone: LTone.ok
        ),
      ApplicationStatus.rejected => (
          label: 'admin.filter_rejected'.tr(),
          tone: LTone.live
        ),
      ApplicationStatus.suspended => (
          label: 'admin.suspended'.tr(),
          tone: LTone.live
        ),
    };

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard(
      {super.key,
      required this.app,
      required this.selected,
      required this.onSelect,
      required this.onInspect,
      required this.onApprove,
      required this.onReject,
      required this.onRemove});

  final BroadcasterApplicationModel app;
  final bool selected;
  final ValueChanged<bool> onSelect;
  final VoidCallback onInspect, onApprove, onReject, onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final ar = lang == 'ar';
    final name = ar ? app.applicantNameAr : app.applicantNameEn;
    final pending = app.status == ApplicationStatus.pending;
    final status = lanternApplicationStatus(app.status);
    final handle = app.youtubeHandle.replaceFirst('@', '').trim();
    final detail = app.isOrganization
        ? [
            ar ? app.venueNameAr : app.venueNameEn,
            app.city == null ? '' : (ar ? app.city!.nameAr : app.city!.nameEn),
          ]
        : [
            ar ? (app.academicTitleAr ?? '') : (app.academicTitleEn ?? ''),
            ar ? (app.institutionAr ?? '') : (app.institutionEn ?? ''),
          ];
    final notes = app.adminReviewNotes ?? '';

    Widget meta(LGlyph icon, String text, {Color? color}) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          LIcon(icon, size: 14, color: color ?? t.muted),
          const SizedBox(width: 5),
          Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Lantern.textStyle(12.5,
                      color: color ?? t.muted, height: 1.35))),
        ]);

    return LCard(
        selected: selected,
        padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 14, 14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (pending)
                  LCheckbox(
                      key: ValueKey('lantern-application-select-${app.id}'),
                      value: selected,
                      label: 'lantern.admin.select_app'
                          .tr(namedArgs: {'name': name}),
                      onChanged: onSelect)
                else
                  const SizedBox(width: 8),
                const SizedBox(width: 4),
                Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: LAvatar(
                        name: app.applicantNameEn,
                        image: resolveImageProviderOrNull(app.avatarUrl),
                        size: 44,
                        org: app.isOrganization)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(name,
                          style: Lantern.textStyle(15,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.35)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        LTag(
                            app.isOrganization
                                ? 'admin.application_org'.tr()
                                : 'admin.application_scholar'.tr(),
                            tone:
                                app.isOrganization ? LTone.gold : LTone.neutral,
                            icon: app.isOrganization
                                ? LGlyph.org
                                : LGlyph.person),
                        if (app.revisionOf != null)
                          LTag('admin.edit_after_verification'.tr(),
                              tone: LTone.mod, icon: LGlyph.edit),
                        LTag(status.label, tone: status.tone),
                      ]),
                    ])),
              ]),
              Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, top: 10),
                  child: Wrap(spacing: 14, runSpacing: 6, children: [
                    if (detail.any((d) => d.isNotEmpty))
                      meta(app.isOrganization ? LGlyph.pin : LGlyph.book,
                          detail.where((d) => d.isNotEmpty).join(' · ')),
                    handle.isEmpty
                        ? meta(
                            LGlyph.warn, 'lantern.admin.youtube_missing'.tr(),
                            color: t.warn)
                        : meta(LGlyph.play,
                            '${'admin.field_youtube'.tr()} @$handle'),
                    if (app.seatingCapacity > 0)
                      meta(
                          LGlyph.users,
                          'lantern.admin.capacity'.tr(
                              namedArgs: {'count': '${app.seatingCapacity}'})),
                    meta(LGlyph.clock, agoLabel(app.submittedAt, lang)),
                  ])),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: LBanner('${'admin.review_notes'.tr()}: $notes',
                        tone: LTone.warn, icon: LGlyph.info)),
              ],
              const SizedBox(height: 12),
              Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        LButton(
                            key: ValueKey(
                                'lantern-application-inspect-${app.id}'),
                            label: 'admin.btn_inspect'.tr(),
                            kind: LButtonKind.ghost,
                            size: LButtonSize.small,
                            icon: LGlyph.eye,
                            onPressed: onInspect),
                        if (pending) ...[
                          LButton(
                              key: ValueKey(
                                  'lantern-application-reject-${app.id}'),
                              label: app.revisionOf == null
                                  ? 'admin.btn_reject'.tr()
                                  : 'admin.reject_edit'.tr(),
                              kind: LButtonKind.secondary,
                              size: LButtonSize.small,
                              onPressed: onReject),
                          LButton(
                              key: ValueKey(
                                  'lantern-application-approve-${app.id}'),
                              label: app.revisionOf == null
                                  ? 'admin.btn_approve'.tr()
                                  : 'admin.approve_edit'.tr(),
                              size: LButtonSize.small,
                              icon: LGlyph.verified,
                              onPressed: onApprove),
                        ] else
                          LIconButton(
                              key: ValueKey(
                                  'lantern-application-remove-${app.id}'),
                              icon: LGlyph.trash,
                              label: 'admin.btn_delete'.tr(),
                              color: t.liveText,
                              onPressed: onRemove),
                      ])),
            ]));
  }
}

class _BatchBar extends StatelessWidget {
  const _BatchBar(
      {required this.count,
      required this.onClear,
      required this.onApprove,
      required this.onReject});

  final int count;
  final VoidCallback onClear, onApprove, onReject;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final gutter = context.lanternWide ? Lantern.webGutter : Lantern.gutter;
    return Semantics(
        container: true,
        liveRegion: true,
        child: Container(
            key: const ValueKey('lantern-queue-batch'),
            padding: EdgeInsetsDirectional.fromSTEB(
                gutter, 10, gutter, 10 + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(
                color: t.raised,
                border: Border(top: BorderSide(color: t.line)),
                boxShadow: t.shadowHi),
            child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const LStar(size: 14),
                    const SizedBox(width: 8),
                    Text(
                        'admin.selected_count'
                            .tr(namedArgs: {'count': '$count'}),
                        style: Lantern.textStyle(14,
                                color: t.fg, weight: FontWeight.w700)
                            .copyWith(fontFeatures: Lantern.tabular)),
                    const SizedBox(width: 4),
                    LButton(
                        label: 'design_ui.clear'.tr(),
                        kind: LButtonKind.ghost,
                        size: LButtonSize.small,
                        onPressed: onClear),
                  ]),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    LButton(
                        key: const ValueKey('lantern-batch-reject'),
                        label: 'design_ui.reject_selected'.tr(),
                        kind: LButtonKind.secondary,
                        size: LButtonSize.small,
                        onPressed: onReject),
                    LButton(
                        key: const ValueKey('lantern-batch-approve'),
                        label: 'design_ui.approve_selected'.tr(),
                        size: LButtonSize.small,
                        icon: LGlyph.verified,
                        onPressed: onApprove),
                  ]),
                ])));
  }
}
