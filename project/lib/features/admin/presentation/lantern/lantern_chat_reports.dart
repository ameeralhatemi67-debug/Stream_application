import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';
import '../../models/chat_mute_audit_entry.dart';
import '../../models/chat_report_model.dart';

/// The queue of reported chat messages in Lantern and Arch.
///
/// `ChatModerationView` keeps the reports, the search and every action; this
/// view draws the cards and asks before acting. Muting, deleting and banning
/// are press-and-hold inside their dialog, and a ban needs a reason, as in
/// the older design.
class LanternChatReportsQueue extends StatelessWidget
    implements LanternSkinWidget {
  const LanternChatReportsQueue(
      {super.key,
      required this.reports,
      required this.shown,
      required this.search,
      required this.onSearchChanged,
      required this.scoped,
      required this.mutedLog,
      required this.acting,
      required this.canBan,
      required this.reasonLabel,
      required this.onDismiss,
      required this.onMute,
      required this.onBan,
      required this.onDelete});

  /// Every open report in scope, and those that match the search.
  final List<ChatReportModel> reports, shown;
  final TextEditingController search;
  final VoidCallback onSearchChanged;

  /// Reports of one stream (an organization's show) rather than all.
  final bool scoped;

  /// The muted chatters log; null where the older view does not show it.
  final List<ChatMuteAuditEntry>? mutedLog;
  final Set<String> acting;
  final bool canBan;
  final String Function(String reason) reasonLabel;
  final ValueChanged<ChatReportModel> onDismiss, onDelete;

  /// [hours] null mutes for good.
  final void Function(ChatReportModel report, double? hours) onMute;
  final void Function(ChatReportModel report, String reason) onBan;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide && !scoped;
    final gutter = context.lanternWide ? Lantern.webGutter : Lantern.gutter;
    final log = mutedLog;
    final list = <Widget>[
      Row(children: [
        Expanded(
            child: Semantics(
                header: true,
                child: Text('design_ui.chat_moderation'.tr(),
                    style: Lantern.displayStyle(context.lanternWide ? 24 : 20,
                        color: t.fg,
                        height: context.lanternArabic ? 1.45 : 1.25)))),
        LTag('${reports.length}', tone: LTone.gold),
      ]),
      const SizedBox(height: 4),
      Text(
          (scoped
                  ? 'organization_v1.scoped_reports'
                  : 'design_ui.reported_live_chat_messages_platform_wide_dismiss_a_report_delete')
              .tr(),
          style: Lantern.textStyle(13.5, color: t.muted, height: 1.5)),
      const SizedBox(height: 14),
      LField(
          key: const ValueKey('lantern-chat-reports-search'),
          controller: search,
          pill: true,
          icon: LGlyph.search,
          hint: 'moderation.search'.tr(),
          onChanged: (_) => onSearchChanged()),
      const SizedBox(height: 14),
      if (log != null && !wide) ...[
        _MutedLog(entries: log, collapsible: true),
        const SizedBox(height: 14),
      ],
      if (shown.isEmpty)
        LEmptyState(
            key: const ValueKey('lantern-chat-reports-empty'),
            icon: LGlyph.chat,
            title: (reports.isEmpty
                    ? 'lantern.admin.chat_empty'
                    : 'lantern.admin.chat_no_match')
                .tr(),
            body: reports.isEmpty ? 'lantern.admin.chat_empty_body'.tr() : null)
      else
        for (final report in shown)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReportCard(
                  key: ValueKey('lantern-chat-report-${report.id}'),
                  report: report,
                  count: reports
                      .where(
                          (r) => r.reportedSenderId == report.reportedSenderId)
                      .length,
                  acting: acting.contains(report.id),
                  canBan: canBan,
                  reasonLabel: reasonLabel(report.reason),
                  onDismiss: () => onDismiss(report),
                  onMute: () => _mute(context, report),
                  onDelete: () => _delete(context, report),
                  onBan: () => _ban(context, report))),
    ];
    final scroll = ListView(
        key: const ValueKey('lantern-chat-reports'),
        padding: EdgeInsets.fromLTRB(gutter, scoped ? 4 : 18, gutter, 24),
        children: list);
    if (!wide || log == null) return scroll;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: scroll),
      SizedBox(
          width: 340,
          child: ListView(
              padding: EdgeInsetsDirectional.fromSTEB(0, 18, gutter, 24),
              children: [_MutedLog(entries: log, collapsible: false)])),
    ]);
  }

  Future<void> _mute(BuildContext context, ChatReportModel report) async {
    final hours = await showLanternSheet<double>(context,
        title: 'design_ui.mute_duration'.tr(),
        body: (ctx) => Column(
                key: const ValueKey('lantern-mute-durations'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (label, value) in [
                    ('moderation.ten_minutes'.tr(), 10 / 60),
                    ('moderation.one_hour'.tr(), 1.0),
                    // 0 is "for good"; the sheet's own null is "closed".
                    ('design_ui.permanent'.tr(), 0.0),
                  ])
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: LRow(
                            key: ValueKey('lantern-mute-$value'),
                            icon: value == 0 ? LGlyph.lock : LGlyph.clock,
                            title: label,
                            onTap: () => Navigator.of(ctx).pop(value))),
                ]));
    if (hours == null || !context.mounted) return;
    final sure = await _holdDialog(context,
        title: 'moderation.mute_title'.tr(),
        body: 'moderation.mute_body'
            .tr(namedArgs: {'name': report.reportedDisplayName}),
        hold: 'lantern.admin.hold_mute'.tr(),
        icon: LGlyph.micoff,
        kind: LButtonKind.dark);
    if (sure == true) onMute(report, hours == 0 ? null : hours);
  }

  Future<void> _delete(BuildContext context, ChatReportModel report) async {
    final sure = await _holdDialog(context,
        title: 'moderation.delete_title'.tr(),
        body: 'moderation.delete_body'.tr(),
        hold: 'lantern.admin.hold_delete'.tr(),
        icon: LGlyph.trash);
    if (sure == true) onDelete(report);
  }

  Future<void> _ban(BuildContext context, ChatReportModel report) async {
    final reason = TextEditingController(text: reasonLabel(report.reason));
    final given = await showLanternDialog<String>(context,
        title: 'design_ui.ban_account_platform_wide'.tr(),
        body: (ctx) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                      'moderation.ban_body'
                          .tr(namedArgs: {'name': report.reportedDisplayName}),
                      style: Lantern.textStyle(14.5,
                          color: ctx.lt.muted, height: 1.5)),
                  const SizedBox(height: 14),
                  LField(
                      key: const ValueKey('lantern-ban-reason'),
                      controller: reason,
                      label: 'admin.ban_reason_label'.tr(),
                      maxLines: 3,
                      minLines: 2),
                ]),
        actions: (ctx) => [
              LButton(
                  label: 'settings.cancel'.tr(),
                  kind: LButtonKind.ghost,
                  onPressed: () => Navigator.of(ctx).pop()),
              ValueListenableBuilder<TextEditingValue>(
                  valueListenable: reason,
                  builder: (ctx, value, _) => LHoldButton(
                      key: const ValueKey('lantern-ban-hold'),
                      label: 'lantern.admin.hold_ban'.tr(),
                      icon: LGlyph.ban,
                      enabled: value.text.trim().isNotEmpty,
                      onConfirmed: () =>
                          Navigator.of(ctx).pop(reason.text.trim()))),
            ]);
    // The field is still drawn while the dialog closes, so the controller is
    // left to the garbage collector.
    if (given == null || given.isEmpty) return;
    onBan(report, given);
  }

  static Future<bool?> _holdDialog(BuildContext context,
          {required String title,
          required String body,
          required String hold,
          required LGlyph icon,
          LButtonKind kind = LButtonKind.danger}) =>
      showLanternDialog<bool>(context,
          title: title,
          body: (ctx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(body,
                        style: Lantern.textStyle(14.5,
                            color: ctx.lt.muted, height: 1.5)),
                    const SizedBox(height: 8),
                    Text('lantern.admin.hold_hint'.tr(),
                        style: Lantern.textStyle(12.5,
                            color: ctx.lt.muted, height: 1.4)),
                  ]),
          actions: (ctx) => [
                LButton(
                    label: 'settings.cancel'.tr(),
                    kind: LButtonKind.ghost,
                    onPressed: () => Navigator.of(ctx).pop(false)),
                LHoldButton(
                    key: const ValueKey('lantern-moderation-hold'),
                    label: hold,
                    icon: icon,
                    kind: kind,
                    onConfirmed: () => Navigator.of(ctx).pop(true)),
              ]);
}

class _ReportCard extends StatelessWidget {
  const _ReportCard(
      {super.key,
      required this.report,
      required this.count,
      required this.acting,
      required this.canBan,
      required this.reasonLabel,
      required this.onDismiss,
      required this.onMute,
      required this.onDelete,
      required this.onBan});

  final ChatReportModel report;
  final int count;
  final bool acting, canBan;
  final String reasonLabel;
  final VoidCallback onDismiss, onMute, onDelete, onBan;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final when = DateFormat('yyyy-MM-dd HH:mm', context.locale.languageCode)
        .format(report.createdAt.toLocal());
    return LCard(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LAvatar(name: report.reportedDisplayName, size: 38),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(
                          'moderation.reported'.tr(
                              namedArgs: {'name': report.reportedDisplayName}),
                          style: Lantern.textStyle(14.5,
                              color: t.fg,
                              weight: FontWeight.w700,
                              height: 1.35)),
                      if (report.reportedEmail != null)
                        Text(report.reportedEmail!,
                            textDirection: TextDirection.ltr,
                            style: Lantern.textStyle(12.5,
                                color: t.muted, height: 1.35)),
                    ])),
                if (count > 1) ...[
                  const SizedBox(width: 8),
                  LTag(
                      'lantern.admin.report_count'
                          .tr(namedArgs: {'count': '$count'}),
                      tone: LTone.live),
                ],
              ]),
              const SizedBox(height: 10),
              LTag('moderation.reason'.tr(namedArgs: {'reason': reasonLabel}),
                  tone: LTone.warn, icon: LGlyph.flag),
              const SizedBox(height: 10),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                      color: t.sunk,
                      borderRadius: BorderRadius.circular(Lantern.radiusTile),
                      border: BorderDirectional(
                          start: BorderSide(color: t.line, width: 3))),
                  child: Text('"${report.messageBody}"',
                      style: Lantern.textStyle(14, color: t.fg, height: 1.5))),
              const SizedBox(height: 8),
              Text(
                  'moderation.metadata'.tr(namedArgs: {
                    'name': report.reporterDisplayName,
                    'stream': report.streamId,
                    'date': when,
                  }),
                  style: Lantern.textStyle(12.5, color: t.muted, height: 1.4)),
              const SizedBox(height: 12),
              if (acting)
                const Align(
                    key: ValueKey('lantern-chat-report-acting'),
                    alignment: AlignmentDirectional.centerEnd,
                    child: LStarLoader(size: 22))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  LButton(
                      key: ValueKey('lantern-chat-dismiss-${report.id}'),
                      label: 'design_ui.dismiss'.tr(),
                      kind: LButtonKind.ghost,
                      size: LButtonSize.small,
                      icon: LGlyph.check,
                      onPressed: onDismiss),
                  LButton(
                      key: ValueKey('lantern-chat-mute-${report.id}'),
                      label: 'design_ui.mute_in_stream'.tr(),
                      kind: LButtonKind.secondary,
                      size: LButtonSize.small,
                      icon: LGlyph.micoff,
                      onPressed: onMute),
                  LButton(
                      key: ValueKey('lantern-chat-delete-${report.id}'),
                      label: 'design_ui.delete_message'.tr(),
                      kind: LButtonKind.secondary,
                      size: LButtonSize.small,
                      icon: LGlyph.trash,
                      onPressed: onDelete),
                  if (canBan)
                    LButton(
                        key: ValueKey('lantern-chat-ban-${report.id}'),
                        label: 'design_ui.ban_platform_wide'.tr(),
                        kind: LButtonKind.danger,
                        size: LButtonSize.small,
                        icon: LGlyph.ban,
                        onPressed: onBan),
                ]),
            ]));
  }
}

/// The muted chatters log: who was muted, in how many streams, why, and
/// their last messages before it.
class _MutedLog extends StatefulWidget {
  const _MutedLog({required this.entries, required this.collapsible});
  final List<ChatMuteAuditEntry> entries;
  final bool collapsible;

  @override
  State<_MutedLog> createState() => _MutedLogState();
}

class _MutedLogState extends State<_MutedLog> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final open = !widget.collapsible || _open;
    final title = 'design_ui.muted_chatters_audit_log'.tr();
    final head = Row(children: [
      LIcon(LGlyph.micoff, size: 18, color: t.warn),
      const SizedBox(width: 10),
      Expanded(
          child: Text(title,
              style: Lantern.textStyle(14.5,
                  color: t.fg, weight: FontWeight.w700, height: 1.35))),
      LTag('${widget.entries.length}'),
      if (widget.collapsible) ...[
        const SizedBox(width: 6),
        RotatedBox(
            quarterTurns: open ? 1 : 0,
            child: LIcon(LGlyph.chevronend, size: 18, color: t.muted)),
      ],
    ]);
    return LCard(
        key: const ValueKey('lantern-muted-log'),
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.collapsible)
                LPressable(
                    onTap: () => setState(() => _open = !_open),
                    label: title,
                    toggled: _open,
                    radius: 12,
                    excludeChildSemantics: true,
                    builder: (context, s) => ConstrainedBox(
                        constraints:
                            const BoxConstraints(minHeight: Lantern.target),
                        child: head))
              else
                Semantics(header: true, child: head),
              if (open) ...[
                const SizedBox(height: 10),
                if (widget.entries.isEmpty)
                  Text('design_ui.no_chatters_have_been_muted_yet'.tr(),
                      style: Lantern.textStyle(13, color: t.muted))
                else
                  for (final e in widget.entries)
                    Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: t.sunk,
                            borderRadius:
                                BorderRadius.circular(Lantern.radiusTile)),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(
                                        e.email != null
                                            ? '${e.displayName} (${e.email})'
                                            : e.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Lantern.textStyle(13.5,
                                            color: t.fg,
                                            weight: FontWeight.w700,
                                            height: 1.35))),
                                const SizedBox(width: 8),
                                LTag(
                                    'moderation.stream_count'.plural(
                                        e.streamsMutedCount,
                                        name: 'count'),
                                    tone: LTone.warn),
                              ]),
                              const SizedBox(height: 4),
                              Text(e.lastReason,
                                  style: Lantern.textStyle(12.5,
                                      color: t.muted, height: 1.4)),
                              for (final m in e.lastMessages)
                                Padding(
                                    padding: const EdgeInsets.only(top: 3),
                                    child: Text('"$m"',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Lantern.textStyle(12.5,
                                            color: t.muted, height: 1.4))),
                            ])),
              ],
            ]));
  }
}
