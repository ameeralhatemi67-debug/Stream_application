import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/lessons_models.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_widgets.dart';
import 'lessons_admin_modals.dart' show dateTimeLabel;

/// The log's groups, for its filter. Every action a server function writes
/// to lesson_audit belongs to one.
const lessonsLogGroups = <String, Set<String>>{
  'applications': {'applicationReceived', 'applicationApproved', 'applicationRejected', 'applicationWithdrawn'},
  'preachers': {'addPreacher', 'editPreacher', 'removePreacher', 'import', 'phone', 'email', 'preacherEdit', 'editApproved', 'editRejected'},
  'lessons': {'add', 'request', 'approve', 'reject', 'undo', 'withdraw', 'cancel', 'edit', 'report', 'resolve'},
  'links': {'keyOnce', 'keyWindow', 'keyRevoke', 'invite'},
  'mosques': {'addMosque', 'editMosque', 'removeMosque', 'mergeMosque'},
  'emails': {'emailFailed', 'emailRetry'},
};

TTone _tone(String action) => const {
      'reject', 'cancel', 'removePreacher', 'removeMosque', 'keyRevoke', 'editRejected', 'applicationRejected', 'emailFailed'
    }.contains(action)
        ? TTone.danger
        : const {'phone', 'email'}.contains(action)
            ? TTone.warning
            : const {'applicationApproved', 'approve', 'editApproved', 'invite'}.contains(action)
                ? TTone.success
                : TTone.slate;

/// Who did it: the admin's name and email as they were, a preacher through
/// his link, or the system (the email sender).
(String, String) lessonsLogActor(BuildContext context, LessonsAuditEntry a) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  if (a.actorId == null && a.action.startsWith('email')) return ('lessons.auditlog.system'.tr(), '');
  if (a.actorId == null && a.preacherId != null) {
    return ('lessons.auditlog.via_link'.tr(args: [c.preacher(a.preacherId)?.name(lang) ?? '—']), '');
  }
  final you = a.actorId != null && a.actorId == c.repository.currentUserId;
  if (a.actorName.isNotEmpty) return (you ? '${a.actorName} (${'lessons.auditlog.you'.tr()})' : a.actorName, a.actorEmail);
  if (you) return ('lessons.auditlog.you'.tr(), a.actorEmail);
  return (a.actorId == null ? '—' : 'lessons.auditlog.an_admin'.tr(), a.actorEmail);
}

/// Log entries, newest first.
class LessonsLogList extends StatelessWidget {
  const LessonsLogList({super.key, required this.entries});
  final List<LessonsAuditEntry> entries;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return TCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (final a in entries)
          Container(
            key: ValueKey('log-${a.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TC.hair))),
            child: Builder(builder: (context) {
              final (who, email) = lessonsLogActor(context, a);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  TTag('lessons.audit.${a.action}'.tr(), tone: _tone(a.action)),
                  Text(a.target(lang), style: tBody(13.5, color: TC.ink, weight: FontWeight.w600)),
                ]),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: who, style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
                    if (email.isNotEmpty) TextSpan(text: ' · $email', style: tBody(12.5, color: TC.muted)),
                    TextSpan(text: ' · ${dateTimeLabel(a.createdAt, lang)} (${agoText(a.createdAt)})', style: tBody(12.5, color: TC.faint)),
                  ]),
                ),
                if (a.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${'lessons.auditlog.reason'.tr()}: ${a.note}', style: tBody(13, color: TC.ink2)),
                  ),
              ]);
            }),
          ),
      ]),
    );
  }
}

TTone _emailTone(String status) => switch (status) {
      'sent' => TTone.success,
      'queued' => TTone.info,
      'failed' => TTone.danger,
      _ => TTone.slate,
    };

/// One email: what it was about, to whom (masked), its state and, when it
/// failed or was skipped, a way to send it again.
class EmailStatusRow extends StatelessWidget {
  const EmailStatusRow(this.email, {super.key, this.showName = true, this.onRetried});
  final PreacherEmailEntry email;
  final bool showName;
  final VoidCallback? onRetried;
  @override
  Widget build(BuildContext context) {
    final e = email;
    final lang = context.lang;
    final when = e.sentAt ?? e.sendAfter ?? e.createdAt;
    return Container(
      key: ValueKey('email-${e.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.hair))),
      child: Row(children: [
        const TIcon(TGlyph.send, size: 17, color: TC.goldIcon),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('lessons.email_kind.${e.kind}'.tr(), style: tStrong(14)),
              TTag('lessons.email_status.${e.status}'.tr(), tone: _emailTone(e.status)),
            ]),
            Text(
                [
                  if (showName && e.name(lang).isNotEmpty) e.name(lang),
                  if (e.to.isNotEmpty) e.to,
                  '${e.status == 'queued' ? 'lessons.emails.due'.tr() : ''}${dateTimeLabel(when, lang)}',
                  if ((e.error ?? '').isNotEmpty) 'lessons.emails.why_${e.error == 'no_address' ? 'no_address' : 'error'}'.tr(args: [e.error!]),
                ].join(' · '),
                style: tBody(12.5, color: TC.muted, height: 1.4)),
          ]),
        ),
        if (e.canRetry)
          TButton('lessons.emails.retry'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.refresh, onPressed: () async {
            final done = await tRun(context, () async {
              await context.read<LessonsController>().retryEmail(e.id);
              return true;
            }, success: 'lessons.emails.retried'.tr());
            if (done == true) onRetried?.call();
          }),
      ]),
    );
  }
}

/// The Log tab: every action with who took it, and every email.
class LessonsLogView extends StatefulWidget {
  const LessonsLogView({super.key});
  @override
  State<LessonsLogView> createState() => _LessonsLogViewState();
}

class _LessonsLogViewState extends State<LessonsLogView> {
  String view = 'actions';
  String? group;
  String q = '';
  late Future<List<PreacherEmailEntry>> emails = _load();

  Future<List<PreacherEmailEntry>> _load() =>
      context.read<LessonsController>().loadEmails().catchError((Object _) => <PreacherEmailEntry>[]);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    bool matches(LessonsAuditEntry a) {
      if (group != null && !(lessonsLogGroups[group] ?? const {}).contains(a.action)) return false;
      if (q.isEmpty) return true;
      final s = q.toLowerCase();
      return [a.actorName, a.actorEmail, a.targetAr, a.targetEn, a.note, 'lessons.audit.${a.action}'.tr(),
        c.preacher(a.preacherId)?.name(lang) ?? '']
          .any((x) => x.toLowerCase().contains(s));
    }

    final list = c.admin.audit.where(matches).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.auditlog.note'.tr(), style: tBody(14, color: TC.muted)),
      const SizedBox(height: 12),
      TTabs<String>(
          value: view,
          onChanged: (v) => setState(() {
                view = v;
                if (v == 'emails') emails = _load();
              }),
          options: [
            TSegOption('actions', 'lessons.auditlog.actions'.tr(), count: c.admin.audit.length),
            TSegOption('emails', 'lessons.auditlog.emails'.tr()),
          ]),
      const SizedBox(height: 12),
      if (view == 'actions') ...[
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
              width: 280,
              child: TSearchBox(
                  key: const ValueKey('log-search'), hint: 'lessons.auditlog.search'.tr(), onChanged: (v) => setState(() => q = v.trim()))),
          TChips([
            TChip('lessons.all'.tr(), small: true, selected: group == null, onTap: () => setState(() => group = null)),
            for (final g in lessonsLogGroups.keys)
              TChip('lessons.auditlog.g_$g'.tr(), small: true, selected: group == g, onTap: () => setState(() => group = group == g ? null : g)),
          ]),
        ]),
        const SizedBox(height: 12),
        if (list.isEmpty) TEmpty(icon: TGlyph.history, title: 'lessons.auditlog.empty'.tr()) else LessonsLogList(entries: list),
      ] else
        FutureBuilder<List<PreacherEmailEntry>>(
          future: emails,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: TC.gold)));
            }
            final all = snap.data ?? const <PreacherEmailEntry>[];
            final now = DateTime.now();
            final stuck = all.where((e) => e.status == 'queued' && (e.sendAfter ?? e.createdAt).isBefore(now.subtract(const Duration(minutes: 10))));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('lessons.emails.log_body'.tr(), style: tBody(13.5, color: TC.muted)),
              if (stuck.isNotEmpty) ...[
                const SizedBox(height: 10),
                TCallout(
                    key: const ValueKey('emails-stuck'),
                    tone: TTone.warning,
                    icon: TGlyph.alert,
                    child: Text('lessons.emails.stuck'.tr(args: ['${stuck.length}']))),
              ],
              const SizedBox(height: 10),
              if (all.isEmpty)
                TEmpty(icon: TGlyph.send, title: 'lessons.emails.empty'.tr())
              else
                TCard(
                  child: Column(children: [
                    for (final e in all) EmailStatusRow(e, onRetried: () => setState(() => emails = _load())),
                  ]),
                ),
            ]);
          },
        ),
    ]);
  }
}
