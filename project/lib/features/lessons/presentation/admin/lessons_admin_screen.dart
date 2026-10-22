import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_modals.dart';
import '../lessons_widgets.dart';
import 'lessons_admin_modals.dart';
import 'lessons_admin_shell.dart';

/// The Preachers & lessons area of the admin page: admins (and lessons-only
/// admins) run the whole programme here, whether or not a preacher ever
/// opens his link.
class LessonsAdminScreen extends StatelessWidget {
  const LessonsAdminScreen({super.key, this.tab = 'overview'});
  final String tab;
  @override
  Widget build(BuildContext context) {
    final t = lessonsAdminTabs.contains(tab) ? tab : 'overview';
    final head = Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        TEyebrow('lessons.admin.title'.tr(), icon: TGlyph.shield),
        const SizedBox(height: 4),
        Text('lessons.admin.tab_$t'.tr(), style: tDisplay(context.wide ? 30 : 24)),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        TButton('lessons.admin.add_preacher'.tr(), icon: TGlyph.user, onPressed: () => showPreacherEditSheet(context)),
        TButton('lessons.admin.add_lesson'.tr(), kind: TBtn.minted, icon: TGlyph.plus, onPressed: () => context.push('/admin/lessons/add')),
      ]),
    ]);
    return LessonsAdminShell(current: t, children: [
      head,
      switch (t) {
        'approvals' => const _Approvals(),
        'preachers' => const _Roster(),
        'lessons' => const _LessonsList(),
        'mosques' => const _Mosques(),
        'reports' => const _Reports(),
        'stats' => const _Stats(),
        'log' => const _Log(),
        _ => const _Overview(),
      },
    ]);
  }
}

// --------------------------------------------------------------- overview
class _Overview extends StatelessWidget {
  const _Overview();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final reqs = c.pendingRequests;
    final week = c.upcoming.where((l) => !l.date.isAfter(addDays(c.today, 6))).toList();
    final active = c.publicLessons.where((l) => l.isPublic && !l.date.isBefore(addDays(c.today, -30))).map((l) => l.preacherId).toSet().length;
    final clashN = reqs.where((r) => r.items.any((l) => c.clashes(l).isNotEmpty)).length;
    final due = c.publicLessons
        .where((l) => l.isPublic && l.date.isBefore(c.today) && !l.date.isBefore(addDays(c.today, -14)) && !c.admin.reports.containsKey(l.id))
        .length;
    final attention = [
      (reqs.length, TGlyph.inbox, 'lessons.overview.a_requests', 'approvals', TTone.warning),
      (clashN, TGlyph.alert, 'lessons.overview.a_clash', 'approvals', TTone.danger),
      (c.pendingEdits.length, TGlyph.user, 'lessons.overview.a_edits', 'approvals', TTone.warning),
      (c.openFlags.length, TGlyph.flag, 'lessons.overview.a_reports', 'reports', TTone.warning),
      (c.catalog.mosques.values.where((m) => !m.verified).length, TGlyph.mosque, 'lessons.overview.a_hidden', 'mosques', TTone.info),
      (due, TGlyph.file, 'lessons.overview.a_due', 'lessons', TTone.slate),
    ].where((a) => a.$1 > 0).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TStatTiles(big: true, [
        ('${reqs.length + c.pendingEdits.length}', 'lessons.overview.waiting'.tr()),
        ('${week.length}', 'lessons.overview.week'.tr()),
        ('$active', 'lessons.overview.active'.tr()),
        ('${week.map((l) => l.mosqueId).toSet().length}', 'lessons.overview.covered'.tr()),
      ]),
      const SizedBox(height: 16),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('lessons.overview.attention'.tr(), style: tStrong(17)),
          const SizedBox(height: 8),
          if (attention.isEmpty) TEmpty(ok: true, icon: TGlyph.check, title: 'lessons.overview.all_clear'.tr()),
          for (final (n, glyph, key, target, tone) in attention)
            InkWell(
              onTap: () => context.go('/admin/lessons/$target'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: toneColors(tone).$1, shape: BoxShape.circle),
                      child: TIcon(glyph, size: 16, color: toneColors(tone).$2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(key.tr(), style: tBody(14.5, color: TC.ink))),
                  Text('$n', style: tStrong(16)),
                  const SizedBox(width: 6),
                  const TIcon(TGlyph.chevron, size: 16, color: TC.faint),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('lessons.overview.chart'.tr(), style: tStrong(17))),
            Text('lessons.overview.eight'.tr(), style: tBody(13, color: TC.muted)),
          ]),
          const SizedBox(height: 12),
          const SizedBox(height: 210, child: _WeeklyChart()),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 6, children: [
            for (final t in LessonsVocab.types)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: _typeColor(t), borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 6),
                Text(typeLabel(t), style: tBody(12.5, color: TC.ink2)),
              ]),
            Text('lessons.overview.next_note'.tr(), style: tBody(12.5, color: TC.muted)),
          ]),
        ]),
      ),
    ]);
  }
}

Color _typeColor(String t) => t == 'lecture' ? TC.gold : t == 'talk' ? TC.infoFg : TC.slateFg;

/// Approved lessons per week for eight weeks, stacked by type.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    // Weeks start on Saturday, as the association counts them.
    final offset = (c.today.weekday - DateTime.saturday) % 7;
    final thisWeek = addDays(c.today, -offset);
    final weeks = [for (var i = -6; i <= 1; i++) addDays(thisWeek, i * 7)];
    final data = [
      for (final w in weeks)
        {
          for (final t in LessonsVocab.types)
            t: c.publicLessons.where((l) => l.isPublic && l.type == t && !l.date.isBefore(w) && !l.date.isAfter(addDays(w, 6))).length
        }
    ];
    final maxV = math.max(4, data.map((d) => d.values.fold<int>(0, (a, b) => a + b)).fold<int>(0, math.max));
    return LayoutBuilder(builder: (context, box) {
      final bw = (box.maxWidth / weeks.length) * .55;
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < weeks.length; i++)
          Expanded(
            child: Opacity(
              opacity: weeks[i].isAfter(c.today) ? .55 : 1,
              child: Column(children: [
                // The bars take what the labels leave, at any text size.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, area) => Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text('${data[i].values.fold<int>(0, (a, b) => a + b)}',
                          maxLines: 1, style: tBody(12, color: TC.ink2, weight: FontWeight.w700, height: 1.3)),
                      const SizedBox(height: 4),
                      for (final t in LessonsVocab.types.reversed)
                        Container(
                          width: bw,
                          height: math.max(0.0, area.maxHeight - MediaQuery.textScalerOf(context).scale(16) - 4) * data[i][t]! / maxV,
                          decoration: BoxDecoration(color: _typeColor(t), borderRadius: BorderRadius.circular(2)),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(height: 6),
                Text(gregorianLabel(weeks[i], lang, short: true), maxLines: 1, style: tBody(11, color: TC.muted, height: 1.2)),
                Text(sameDay(weeks[i], thisWeek) ? 'lessons.overview.this_week'.tr() : '', maxLines: 1, style: tBody(10.5, color: TC.bronze, weight: FontWeight.w700, height: 1.2)),
              ]),
            ),
          ),
      ]);
    });
  }
}

// -------------------------------------------------------------- approvals
/// Requests preachers sent through their links, and card changes they
/// proposed. Approving a request needs a mosque: the admin chooses it.
class _Approvals extends StatefulWidget {
  const _Approvals();
  @override
  State<_Approvals> createState() => _ApprovalsState();
}

class _ApprovalsState extends State<_Approvals> {
  final selected = <String>{};
  final mosqueOf = <String, String>{};
  String? open;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final reqs = c.pendingRequests;
    final edits = c.pendingEdits;
    bool isClash(LessonRequest r) => r.items.any((l) => c.clashes(l).isNotEmpty);
    String? chosen(LessonRequest r) => mosqueOf[r.id] ?? (r.first.hasMosque ? r.first.mosqueId : null);

    Future<void> approve(List<LessonRequest> rs) async {
      if (rs.any((r) => chosen(r) == null)) {
        tToast(context, 'lessons.approvals.choose_mosque'.tr(), warn: true);
        return;
      }
      // One call per mosque: the server sets it on sessions without one.
      final groups = <String, List<String>>{};
      for (final r in rs) {
        (groups[chosen(r)!] ??= []).add(r.id);
      }
      var n = 0;
      for (final g in groups.entries) {
        final done = await tRun(context, () => c.review(g.value, 'approve', mosqueId: g.key));
        if (done == null) return;
        n += done;
      }
      final ids = [for (final r in rs) r.id];
      setState(selected.clear);
      if (context.mounted) {
        tToast(context, 'lessons.review.approved'.tr(args: [tPlural('requests', n)]),
            actionLabel: 'lessons.review.undo'.tr(), onAction: () => tRun(context, () => c.undoReview(ids), success: 'lessons.review.undone'.tr()));
      }
    }

    Future<void> reject(List<String> ids) async {
      final done = await showRejectSheet(context, ids);
      if (done == true) setState(selected.clear);
    }

    final mosques = c.catalog.mosques.values.toList()
      ..sort((a, b) {
        final city = c.cityOfMosque(a.id).compareTo(c.cityOfMosque(b.id));
        return city != 0 ? city : a.name(lang).compareTo(b.name(lang));
      });

    Widget card(LessonRequest r) {
      final l = r.first;
      return TCard(
        highlight: selected.contains(r.id),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Checkbox(
              value: selected.contains(r.id),
              activeColor: TC.gold,
              onChanged: (v) => setState(() => v == true ? selected.add(r.id) : selected.remove(r.id)),
            ),
            Expanded(
              child: InkWell(
                onTap: () => context.push('/admin/lessons/preachers/${l.preacherId}'),
                child: Text(c.preacher(l.preacherId)?.name(lang) ?? '', style: tStrong(14)),
              ),
            ),
            Text(agoText(r.submittedAt), style: tBody(12, color: TC.faint)),
          ]),
          Wrap(spacing: 6, runSpacing: 6, children: [
            TypeTag(l.type),
            if (l.fromPreacher) TTag('lessons.approvals.via_link'.tr(), tone: TTone.info, icon: TGlyph.link),
            if (isClash(r)) TTag('lessons.review.clash'.tr(), tone: TTone.danger, icon: TGlyph.alert),
            if (r.isSeries) TTag(tPlural('sessions', r.items.length), tone: TTone.slate, icon: TGlyph.repeat),
            if (l.language != 'ar') TTag(languageLabel(l.language), tone: TTone.info, icon: TGlyph.globe),
          ]),
          const SizedBox(height: 6),
          Text(l.title(lang), style: tStrong(16)),
          Text('${topicLabel(l.topic)} · ${whenOf(c, l, lang)}${r.isSeries ? 'lessons.review.weekly'.tr() : ''}', style: tBody(13, color: TC.muted)),
          if (l.preacherNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            TCallout(tone: TTone.info, icon: TGlyph.chat, child: Text('${'lessons.approvals.note'.tr()}: ${l.preacherNote}')),
          ],
          const SizedBox(height: 10),
          TField(
            label: 'lessons.approvals.mosque'.tr(),
            required: true,
            child: DropdownButtonFormField<String>(
              key: ValueKey('approval-mosque-${r.id}'),
              initialValue: chosen(r),
              isExpanded: true,
              hint: Text('lessons.approvals.mosque_hint'.tr()),
              decoration: tInput(),
              items: [
                for (final m in mosques)
                  DropdownMenuItem(
                      value: m.id,
                      child: Text('${m.name(lang)} · ${c.district(m.districtId)?.name(lang) ?? ''}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => v == null ? mosqueOf.remove(r.id) : mosqueOf[r.id] = v),
            ),
          ),
          if (open == r.id) ...[
            const SizedBox(height: 8),
            Text('${'lessons.lesson.audience'.tr()}: ${audienceLabel(l.audience)}', style: tBody(13.5)),
            if (r.isSeries) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final x in r.items)
                  TTag('${x.seq}. ${weekdayName(x.date, lang, short: true)} ${gregorianLabel(x.date, lang, short: true)}',
                      tone: c.clashes(x).isEmpty ? TTone.slate : TTone.danger),
              ]),
            ],
            for (final x in r.items)
              for (final o in c.clashes(x))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TCallout(
                    tone: TTone.warning,
                    icon: TGlyph.alert,
                    action: TButton('lessons.review.view'.tr(), small: true, onPressed: () => context.push('/lessons/lesson/${o.id}')),
                    child: Text(
                        '${gregorianLabel(x.date, lang)} · ${slotLabel(x.slot)}: ${o.preacherId == x.preacherId ? 'lessons.review.clash_preacher'.tr() : 'lessons.review.clash_mosque'.tr()} «${o.title(lang)}» (${statusLabel(o.status)})'),
                  ),
                ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TButton('lessons.review.approve'.tr(), kind: TBtn.minted, small: true, icon: TGlyph.check, onPressed: () => approve([r])),
            TButton('lessons.review.reject'.tr(), kind: TBtn.danger, small: true, icon: TGlyph.x, onPressed: () => reject([r.id])),
            TButton('lessons.review.details'.tr(), kind: TBtn.ghost, small: true, icon: open == r.id ? TGlyph.chevronDown : TGlyph.info,
                onPressed: () => setState(() => open = open == r.id ? null : r.id)),
          ]),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.approvals.body'.tr(), style: tBody(14, color: TC.muted)),
      const SizedBox(height: 14),
      TSectionHead('lessons.approvals.requests'.tr(), count: reqs.length),
      if (reqs.isNotEmpty) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          TButton('lessons.review.select_all'.tr(), small: true, kind: TBtn.ghost,
              onPressed: () => setState(() => selected.length == reqs.length ? selected.clear() : selected.addAll(reqs.map((r) => r.id)))),
          TButton('lessons.review.approve_sel'.tr(args: ['${selected.length}']), small: true, kind: TBtn.minted, icon: TGlyph.check,
              onPressed: selected.isEmpty ? null : () => approve(reqs.where((r) => selected.contains(r.id)).toList())),
          TButton('lessons.review.reject_sel'.tr(), small: true, kind: TBtn.danger, icon: TGlyph.x,
              onPressed: selected.isEmpty ? null : () => reject(selected.toList())),
        ]),
        const SizedBox(height: 12),
      ],
      if (reqs.isEmpty)
        TEmpty(ok: true, icon: TGlyph.check, title: 'lessons.approvals.no_requests'.tr(), body: 'lessons.approvals.no_requests_body'.tr())
      else
        for (final r in reqs) Padding(padding: const EdgeInsets.only(bottom: 10), child: card(r)),
      const SizedBox(height: 18),
      TSectionHead('lessons.approvals.edits'.tr(), count: edits.length),
      if (edits.isEmpty)
        TEmpty(ok: true, icon: TGlyph.check, title: 'lessons.approvals.no_edits'.tr())
      else
        for (final e in edits) Padding(padding: const EdgeInsets.only(bottom: 10), child: PreacherEditCard(edit: e)),
    ]);
  }
}

/// A card change a preacher proposed: each field, before and after.
class PreacherEditCard extends StatelessWidget {
  const PreacherEditCard({super.key, required this.edit});
  final PreacherEdit edit;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final p = c.preacher(edit.preacherId);
    String now(String field) => switch (field) {
          'name_ar' => p?.nameAr ?? '',
          'name_en' => p?.nameEn ?? '',
          'title_ar' => p?.titleAr ?? '',
          'title_en' => p?.titleEn ?? '',
          'bio_ar' => p?.bioAr ?? '',
          'bio_en' => p?.bioEn ?? '',
          'languages' => (p?.languages ?? const []).map((x) => LessonsVocab.languageNative[x] ?? x).join(' · '),
          _ => '',
        };
    String value(String field, Object? v) => field == 'languages'
        ? [for (final x in (v as List? ?? const [])) LessonsVocab.languageNative[x] ?? '$x'].join(' · ')
        : '${v ?? ''}';
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          TAvatar(name: p?.name(lang) ?? '', size: 36, ring: false),
          const SizedBox(width: 10),
          Expanded(child: Text(p?.name(lang) ?? '', style: tStrong(14.5))),
          Text(agoText(edit.createdAt), style: tBody(12, color: TC.faint)),
        ]),
        const SizedBox(height: 10),
        for (final e in edit.changes.entries)
          if (value(e.key, e.value) != now(e.key))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('lessons.card_field.${e.key}'.tr(), style: tBody(12.5, color: TC.muted, weight: FontWeight.w700)),
                if (now(e.key).isNotEmpty)
                  Text(now(e.key), style: tBody(13.5, color: TC.faint).copyWith(decoration: TextDecoration.lineThrough)),
                Text(value(e.key, e.value).isEmpty ? '—' : value(e.key, e.value), style: tBody(14, color: TC.ink, weight: FontWeight.w600)),
              ]),
            ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TButton('lessons.approvals.apply'.tr(), kind: TBtn.minted, small: true, icon: TGlyph.check,
              onPressed: () => tRun(context, () => c.decideEdit(edit.id, true), success: 'lessons.approvals.applied'.tr())),
          TButton('lessons.approvals.decline'.tr(), kind: TBtn.ghost, small: true, icon: TGlyph.x,
              onPressed: () => tRun(context, () => c.decideEdit(edit.id, false), success: 'lessons.approvals.declined'.tr())),
        ]),
      ]),
    );
  }
}

// ---------------------------------------------------------------- roster
class _Roster extends StatefulWidget {
  const _Roster();
  @override
  State<_Roster> createState() => _RosterState();
}

class _RosterState extends State<_Roster> {
  String q = '';
  String? filter;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final roster = c.admin.roster;
    bool keep(LessonsRosterEntry r) => switch (filter) {
          'link' => r.activeKeys > 0,
          'nolink' => r.activeKeys == 0,
          'hidden' => !r.preacher.listed,
          _ => true,
        };
    final list = roster
        .where((r) => (q.isEmpty || r.preacher.nameAr.contains(q) || r.preacher.nameEn.toLowerCase().contains(q.toLowerCase())) && keep(r))
        .toList();

    Widget row(LessonsRosterEntry r) {
      final p = r.preacher;
      return TCard(
        key: ValueKey('roster-${p.id}'),
        padding: const EdgeInsets.all(14),
        onTap: () => context.push('/admin/lessons/preachers/${p.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            TAvatar(name: p.name(lang), size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name(lang), style: tStrong(14.5)),
                Text('${cityLabel(p.city)} · ${'lessons.affiliation.${p.affiliation}'.tr()} · ${p.languages.map((x) => LessonsVocab.languageNative[x] ?? x).join(' · ')}',
                    style: tBody(12.5, color: TC.muted, height: 1.4)),
              ]),
            ),
            const TIcon(TGlyph.chevron, size: 16, color: TC.faint),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            r.activeKeys > 0
                ? TTag(tPlural('active_links', r.activeKeys), tone: TTone.success, icon: TGlyph.link)
                : TTag('lessons.links.none'.tr(), tone: TTone.slate, icon: TGlyph.link),
            if (r.lastSeen != null) TTag('lessons.links.seen'.tr(args: [agoText(r.lastSeen!)]), tone: TTone.slate, icon: TGlyph.eye),
            if (r.pendingEdits > 0) TTag('lessons.links.edit_waiting'.tr(), tone: TTone.warning, icon: TGlyph.edit),
            if (!p.listed) TTag('lessons.preacher_admin.hidden'.tr(), tone: TTone.slate, icon: TGlyph.lock),
            TTag('${'lessons.roster.h_lessons'.tr()}: ${r.lessons30d}', tone: TTone.slate),
          ]),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TStatTiles([
        ('${roster.length}', 'lessons.roster.t_listed'.tr()),
        ('${roster.where((r) => r.activeKeys > 0).length}', 'lessons.roster.t_link'.tr()),
        ('${roster.where((r) => r.pendingEdits > 0).length}', 'lessons.roster.t_edits'.tr()),
        ('${roster.where((r) => r.lessons30d > 0).length}', 'lessons.roster.t_active'.tr()),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 260, child: TSearchBox(hint: 'lessons.roster.search'.tr(), onChanged: (v) => setState(() => q = v.trim()))),
        TChips([
          TChip('lessons.all'.tr(), small: true, selected: filter == null, onTap: () => setState(() => filter = null)),
          for (final f in ['link', 'nolink', 'hidden'])
            TChip('lessons.roster.f_$f'.tr(), small: true, selected: filter == f, onTap: () => setState(() => filter = f)),
        ]),
        Wrap(spacing: 8, children: [
          TButton('lessons.roster.import'.tr(), small: true, icon: TGlyph.upload, onPressed: () => showImportSheet(context)),
          TButton('lessons.roster.add'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.plus, onPressed: () => showPreacherEditSheet(context)),
        ]),
      ]),
      const SizedBox(height: 14),
      if (list.isEmpty) TEmpty(icon: TGlyph.users, title: 'lessons.roster.empty'.tr(), body: 'lessons.roster.empty_body'.tr()),
      TGrid(minWidth: 340, spacing: 10, children: [for (final r in list) row(r)]),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TIcon(TGlyph.lock, size: 13, color: TC.muted),
        const SizedBox(width: 6),
        Expanded(child: Text('lessons.roster.privacy'.tr(), style: tBody(12.5, color: TC.muted))),
      ]),
    ]);
  }
}

// --------------------------------------------------------------- lessons
class _LessonsList extends StatefulWidget {
  const _LessonsList();
  @override
  State<_LessonsList> createState() => _LessonsListState();
}

class _LessonsListState extends State<_LessonsList> {
  String tab = 'upcoming';
  String q = '';
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    bool match(Lesson l) {
      if (q.isEmpty) return true;
      final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId);
      return [l.titleAr, l.titleEn, p?.nameAr ?? '', p?.nameEn ?? '', m?.nameAr ?? '', m?.nameEn ?? '']
          .any((s) => s.toLowerCase().contains(q.toLowerCase()));
    }

    final upcoming = c.upcomingWhere(match);
    final past = c.pastWhere(match).where((l) => !l.date.isBefore(addDays(c.today, -60))).toList();
    final cancelled = c.publicLessons.where((l) => l.isCancelled && match(l)).toList()..sort(compareLessons);
    final shown = switch (tab) { 'past' => past, 'cancelled' => cancelled, _ => upcoming };
    Widget actions(Lesson l) => Wrap(spacing: 6, runSpacing: 6, children: [
          if (l.isPublic && !l.date.isBefore(c.today)) ...[
            TButton('lessons.lesson.edit'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.edit, onPressed: () => showEditLessonSheet(context, l)),
            TButton('lessons.mine.cancel_this'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.x, onPressed: () => showCancelSheet(context, l)),
          ],
          if (l.isPublic && l.date.isBefore(c.today))
            c.admin.reports[l.id] != null
                ? TTag('lessons.lesson.report_done'.tr(args: ['${c.admin.reports[l.id]!.attendance}']), tone: TTone.success, icon: TGlyph.check)
                : TButton('lessons.lesson.add_report'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.file,
                    onPressed: () => context.push('/admin/lessons/report/${l.id}')),
          TButton('lessons.admin.copy_as_new'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.copy,
              onPressed: () => context.push('/admin/lessons/add?from=${l.id}')),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 280, child: TSearchBox(hint: 'lessons.admin.search_lessons'.tr(), onChanged: (v) => setState(() => q = v.trim()))),
        TButton('lessons.admin.add_lesson'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.plus, onPressed: () => context.push('/admin/lessons/add')),
      ]),
      const SizedBox(height: 12),
      TTabs<String>(value: tab, onChanged: (v) => setState(() => tab = v), options: [
        TSegOption('upcoming', 'lessons.mine.upcoming'.tr(), count: upcoming.length),
        TSegOption('past', 'lessons.mine.past'.tr(), count: past.where((l) => !c.admin.reports.containsKey(l.id)).length),
        TSegOption('cancelled', 'lessons.status.cancelled'.tr(), count: cancelled.length),
      ]),
      const SizedBox(height: 12),
      if (shown.isEmpty)
        TEmpty(title: 'lessons.mine.nothing'.tr())
      else
        for (final l in shown.take(120))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LessonRow(l, showDate: true, extra: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.preacher(l.preacherId)?.name(lang) ?? '', style: tBody(12.5, color: TC.muted)),
              const SizedBox(height: 6),
              actions(l),
            ])),
          ),
    ]);
  }
}

// ---------------------------------------------------------------- mosques
class _Mosques extends StatelessWidget {
  const _Mosques();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final all = c.catalog.mosques.values.toList()..sort((a, b) => a.name(lang).compareTo(b.name(lang)));
    final hidden = all.where((m) => !m.verified).toList();
    Widget card(Mosque m) => TCard(
          key: ValueKey('admin-mosque-${m.id}'),
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(m.name(lang), style: tStrong(14))),
              if (!m.verified) TTag('lessons.mosques.hidden'.tr(), tone: TTone.slate, icon: TGlyph.lock),
            ]),
            Text(c.district(m.districtId)?.name(lang) ?? '', style: tBody(12.5, color: TC.muted)),
            const SizedBox(height: 6),
            FacilityList(m.facilities, dense: true),
            const SizedBox(height: 6),
            Text('${tPlural('ahead', lessonsAt(c, m.id).length)}${m.hasPin ? '' : 'lessons.mosques.off_map'.tr()}',
                style: tBody(12, color: TC.bronze)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              TButton('lessons.lesson.edit'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.edit, onPressed: () => showMosqueSheet(context, mosque: m)),
              TButton(m.verified ? 'lessons.mosques.hide'.tr() : 'lessons.mosques.show'.tr(), small: true, kind: TBtn.ghost,
                  icon: m.verified ? TGlyph.lock : TGlyph.eye,
                  onPressed: () => tRun(context, () => c.upsertMosque({'id': m.id, 'verified': !m.verified}),
                      success: m.verified ? 'lessons.mosques.hidden_toast'.tr() : 'lessons.mosques.shown_toast'.tr())),
              TButton('lessons.mosques.remove'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.trash, onPressed: () => showRemoveMosqueSheet(context, m)),
            ]),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('lessons.mosques.body'.tr(), style: tBody(14, color: TC.muted))),
        const SizedBox(width: 10),
        TButton('lessons.mosques.add'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.plus, onPressed: () => showMosqueSheet(context)),
      ]),
      const SizedBox(height: 14),
      if (hidden.isNotEmpty) ...[
        TSectionHead('lessons.mosques.hidden_title'.tr(), count: hidden.length),
        TGrid(minWidth: 260, spacing: 10, children: [for (final m in hidden) card(m)]),
        const SizedBox(height: 14),
      ],
      for (final city in LessonsVocab.cities)
        if (all.any((m) => m.verified && c.cityOfMosque(m.id) == city)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text('${cityLabel(city)} · ${tPlural('mosques', all.where((m) => m.verified && c.cityOfMosque(m.id) == city).length)}', style: tStrong(15)),
          ),
          TGrid(minWidth: 260, spacing: 10, children: [for (final m in all.where((m) => m.verified && c.cityOfMosque(m.id) == city)) card(m)]),
          const SizedBox(height: 8),
        ],
    ]);
  }
}

// ---------------------------------------------------------------- reports
/// Viewers' reports of a wrong time or place.
class _Reports extends StatelessWidget {
  const _Reports();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final reports = c.openFlags;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.admin.reports_body'.tr(), style: tBody(14, color: TC.muted)),
      const SizedBox(height: 14),
      if (reports.isEmpty)
        TEmpty(ok: true, icon: TGlyph.flag, title: 'lessons.review.no_reports'.tr())
      else
        for (final f in reports)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  TTag('lessons.flag_kind.${f.kind}'.tr(), tone: TTone.warning, icon: TGlyph.flag),
                  const Spacer(),
                  Text(agoText(f.createdAt), style: tBody(12, color: TC.faint)),
                ]),
                const SizedBox(height: 8),
                if (f.message.isNotEmpty) Text(f.message, style: tBody(14, color: TC.ink)),
                if (c.lesson(f.lessonId) != null)
                  Text('${c.lesson(f.lessonId)!.title(lang)} · ${placeOf(c, c.lesson(f.lessonId)!, lang)} · ${whenOf(c, c.lesson(f.lessonId)!, lang)}',
                      style: tBody(13, color: TC.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  TButton('lessons.review.open_lesson'.tr(), small: true, icon: TGlyph.eye, onPressed: () => context.push('/lessons/lesson/${f.lessonId}')),
                  if (c.lesson(f.lessonId) case final l? when l.isPublic && !l.date.isBefore(c.today))
                    TButton('lessons.lesson.edit'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.edit, onPressed: () => showEditLessonSheet(context, l)),
                  TButton('lessons.review.resolved'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.check,
                      onPressed: () => tRun(context, () => c.resolveFlag(f.id), success: 'lessons.review.resolved_toast'.tr())),
                ]),
              ]),
            ),
          ),
    ]);
  }
}

// ------------------------------------------------------------------ stats
class _Stats extends StatefulWidget {
  const _Stats();
  @override
  State<_Stats> createState() => _StatsState();
}

class _StatsState extends State<_Stats> {
  int monthsBack = 0;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final first = DateTime(c.today.year, c.today.month - monthsBack, 1, 12);
    final last = DateTime(c.today.year, c.today.month - monthsBack + 1, 0, 12);
    final end = last.isBefore(c.today) ? last : addDays(c.today, -1);
    final held = c.publicLessons.where((l) => l.isPublic && !l.date.isBefore(first) && !l.date.isAfter(end)).toList();
    Map<String, int> by(String Function(Lesson) key) {
      final m = <String, int>{};
      for (final l in held) {
        m[key(l)] = (m[key(l)] ?? 0) + 1;
      }
      return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    }

    final reports = c.admin.reports;
    final att = held.fold<int>(0, (s, l) => s + (reports[l.id]?.attendance ?? 0));
    final withRep = held.where((l) => reports.containsKey(l.id)).length;
    final preachers = [
      for (final pid in held.map((l) => l.preacherId).toSet())
        (
          c.preacher(pid),
          held.where((l) => l.preacherId == pid && l.type == 'lesson').length,
          held.where((l) => l.preacherId == pid && l.type == 'lecture').length,
          held.where((l) => l.preacherId == pid && l.type == 'talk').length,
          held.where((l) => l.preacherId == pid).fold<int>(0, (s, l) => s + (reports[l.id]?.attendance ?? 0)),
        )
    ]..sort((a, b) => (b.$2 + b.$3 + b.$4).compareTo(a.$2 + a.$3 + a.$4));
    final monthLabel = '${gregorianMonthLabel(first, lang)} · ${hijriMonthLabel(first, lang)}';
    final csv = excelSafeCsv([
      ['lessons.review.h_preacher'.tr(), 'lessons.type.lesson'.tr(), 'lessons.type.lecture'.tr(), 'lessons.type.talk'.tr(), 'lessons.stats.attendance'.tr()],
      for (final r in preachers) [r.$1?.name(lang) ?? '', r.$2, r.$3, r.$4, r.$5],
    ]);
    Widget bars(String title, Map<String, int> rows, String Function(String) label) {
      final maxV = rows.values.fold<int>(1, math.max);
      return TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: tStrong(15)),
          const SizedBox(height: 10),
          for (final e in rows.entries.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 110, child: Text(label(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(13, color: TC.ink2))),
                Expanded(child: TMeter(value: e.value, max: maxV)),
                const SizedBox(width: 8),
                Text('${e.value}', style: tStrong(13)),
              ]),
            ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TSeg<int>(small: true, value: monthsBack, onChanged: (v) => setState(() => monthsBack = v), options: [
          TSegOption(0, 'lessons.stats.this_month'.tr()),
          TSegOption(1, 'lessons.stats.last_month'.tr()),
        ]),
        Text(monthLabel, style: tBody(13, color: TC.muted)),
      ]),
      const SizedBox(height: 14),
      TStatTiles([
        ('${held.length}', 'lessons.stats.held'.tr()),
        ('${held.map((l) => l.preacherId).toSet().length}', 'lessons.stats.preachers'.tr()),
        ('$att', 'lessons.stats.attendees'.tr(args: ['$withRep'])),
        ('${held.map((l) => l.language).toSet().length}', 'lessons.stats.languages'.tr()),
      ]),
      const SizedBox(height: 14),
      TGrid(minWidth: 260, children: [
        bars('lessons.stats.by_type'.tr(), by((l) => l.type), typeLabel),
        bars('lessons.stats.by_language'.tr(), by((l) => l.language), languageLabel),
        bars('lessons.stats.busiest'.tr(), by((l) => c.mosque(l.mosqueId)?.districtId ?? ''), (id) => c.district(id)?.name(lang) ?? id),
      ]),
      const SizedBox(height: 14),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('lessons.stats.monthly'.tr(), style: tStrong(17))),
            TButton('lessons.stats.copy_csv'.tr(), small: true, icon: TGlyph.copy, onPressed: () => copyToClipboard(context, csv)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: TC.page, borderRadius: BorderRadius.circular(TC.r), border: Border.all(color: TC.hair)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('lessons.programme'.tr(), style: tStrong(14)),
              Text('${'lessons.stats.report_sub'.tr()} · $monthLabel', style: tBody(12.5, color: TC.muted)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: const WidgetStatePropertyAll(TC.tint),
                  columns: [
                    DataColumn(label: Text('lessons.review.h_preacher'.tr(), style: tStrong(13))),
                    for (final t in LessonsVocab.types) DataColumn(numeric: true, label: Text(typeLabel(t), style: tStrong(13))),
                    DataColumn(numeric: true, label: Text('lessons.stats.attendance'.tr(), style: tStrong(13))),
                  ],
                  rows: [
                    for (final r in preachers)
                      DataRow(cells: [
                        DataCell(Text(r.$1?.name(lang) ?? '', style: tBody(13, color: TC.ink))),
                        DataCell(Text('${r.$2}')),
                        DataCell(Text('${r.$3}')),
                        DataCell(Text('${r.$4}')),
                        DataCell(Text(r.$5 == 0 ? '—' : '${r.$5}')),
                      ]),
                    DataRow(color: const WidgetStatePropertyAll(TC.tint), cells: [
                      DataCell(Text('lessons.stats.total'.tr(), style: tStrong(13))),
                      DataCell(Text('${preachers.fold<int>(0, (s, r) => s + r.$2)}', style: tStrong(13))),
                      DataCell(Text('${preachers.fold<int>(0, (s, r) => s + r.$3)}', style: tStrong(13))),
                      DataCell(Text('${preachers.fold<int>(0, (s, r) => s + r.$4)}', style: tStrong(13))),
                      DataCell(Text('$att', style: tStrong(13))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('lessons.stats.attendance_note'.tr(), style: tBody(12.5, color: TC.muted)),
            ]),
          ),
          const SizedBox(height: 8),
          Text('lessons.stats.csv_note'.tr(), style: tBody(12.5, color: TC.muted)),
        ]),
      ),
    ]);
  }
}

// -------------------------------------------------------------------- log
class _Log extends StatelessWidget {
  const _Log();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    String who(LessonsAuditEntry a) {
      if (a.actorId == null && a.preacherId != null) {
        return 'lessons.auditlog.via_link'.tr(args: [c.preacher(a.preacherId)?.name(lang) ?? '—']);
      }
      if (a.actorName.isNotEmpty) return a.actorName;
      if (a.actorId != null && a.actorId == c.repository.currentUserId) return 'lessons.auditlog.you'.tr();
      return a.actorId == null ? '—' : 'lessons.auditlog.an_admin'.tr();
    }

    TTone tone(String action) => const {'reject', 'cancel', 'removePreacher', 'removeMosque', 'keyRevoke', 'editRejected'}.contains(action)
        ? TTone.danger
        : action == 'phone'
            ? TTone.warning
            : TTone.slate;
    final list = c.admin.audit;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.auditlog.note'.tr(), style: tBody(14, color: TC.muted)),
      const SizedBox(height: 12),
      if (list.isEmpty)
        TEmpty(icon: TGlyph.history, title: 'lessons.auditlog.empty'.tr())
      else
        TCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final a in list)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: TC.hair))),
                child: Wrap(spacing: 12, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(width: 90, child: Text(agoText(a.createdAt), style: tBody(12.5, color: TC.faint))),
                  SizedBox(width: 190, child: Text(who(a), maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(13.5, color: TC.ink, weight: FontWeight.w600))),
                  TTag('lessons.audit.${a.action}'.tr(), tone: tone(a.action)),
                  Text(a.target(lang), style: tBody(13.5, color: TC.ink2)),
                ]),
              ),
          ]),
        ),
    ]);
  }
}
