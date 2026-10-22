import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/sign_in_prompt.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_map.dart';
import '../lessons_modals.dart';
import '../lessons_shell.dart';
import '../lessons_widgets.dart';
import 'account_screens.dart' show PermissionMatrix;
import 'coordinators_admin.dart';

const consoleTabs = ['overview', 'review', 'preachers', 'mosques', 'reports', 'audit', 'team'];

TGlyph _tabGlyph(String t) => switch (t) {
      'overview' => TGlyph.chart,
      'review' => TGlyph.inbox,
      'preachers' => TGlyph.users,
      'mosques' => TGlyph.mosque,
      'reports' => TGlyph.file,
      'audit' => TGlyph.history,
      _ => TGlyph.key,
    };

/// The coordinators' console (Lessons's dashboard, rebuilt inside the app).
class LessonsConsoleScreen extends StatefulWidget {
  const LessonsConsoleScreen({super.key, this.tab = 'overview', this.filter});
  final String tab;
  final String? filter;
  @override
  State<LessonsConsoleScreen> createState() => _LessonsConsoleScreenState();
}

class _LessonsConsoleScreenState extends State<LessonsConsoleScreen> {
  late String tab = consoleTabs.contains(widget.tab) ? widget.tab : 'overview';

  @override
  void initState() {
    super.initState();
    unawaited(context.read<LessonsController>().openConsole());
  }

  @override
  void didUpdateWidget(LessonsConsoleScreen old) {
    super.didUpdateWidget(old);
    if (old.tab != widget.tab && consoleTabs.contains(widget.tab)) tab = widget.tab;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    if (!c.loaded) {
      return LessonsPage(title: 'lessons.console.title'.tr(), children: const [Center(child: CircularProgressIndicator(color: TC.gold))]);
    }
    if (!c.canCoordinate) {
      return LessonsPage(title: 'lessons.console.title'.tr(), children: [
        TEmpty(
          icon: TGlyph.lock,
          title: 'lessons.console.locked'.tr(),
          body: 'lessons.console.locked_body'.tr(),
          action: c.signedIn
              ? TButton('lessons.nav.permissions'.tr(), onPressed: () => context.push('/lessons/permissions'))
              : TButton('lessons.sign_in'.tr(), kind: TBtn.minted, onPressed: () => openSignIn(context)),
        ),
      ]);
    }
    final org = c.staffOrganizationId;
    final orgs = c.consoleOrganizations;
    final openFlags = c.staff.flags.where((f) => f.status == 'open').length;
    final counts = {
      'review': c.pendingRequests.length + openFlags,
      'mosques': c.catalog.mosques.values.where((m) => !m.verified).length,
    };
    final content = org == null
        // No organization to open yet: admins still manage coordinators.
        ? (c.roles.admin ? const AdminCoordinatorsCard() : const SizedBox.shrink())
        : switch (tab) {
            'review' => _Review(initial: widget.filter),
            'preachers' => _Roster(org: org),
            'mosques' => const _Mosques(),
            'reports' => _Stats(org: org),
            'audit' => const _Audit(),
            'team' => _Team(org: org),
            _ => _Overview(onTab: (t) => setState(() => tab = t)),
          };
    final nav = context.wide
        ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final t in consoleTabs)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(gradient: tab == t ? HidayahGradients.selected : null, borderRadius: BorderRadius.circular(TC.r)),
                    child: InkWell(
                      onTap: () => setState(() => tab = t),
                      borderRadius: BorderRadius.circular(TC.r),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Row(children: [
                          TIcon(_tabGlyph(t), size: 18, color: tab == t ? HidayahGold.g200 : TC.goldIcon),
                          const SizedBox(width: 10),
                          Expanded(child: Text('lessons.console.$t'.tr(), style: tBody(14, color: tab == t ? HidayahGold.g200 : TC.ink, weight: FontWeight.w600, height: 1.3))),
                          if ((counts[t] ?? 0) > 0) TTag('${counts[t]}', tone: tab == t ? TTone.slate : TTone.gold),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
          ])
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final t in consoleTabs)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: TChip('lessons.console.$t'.tr(), icon: _tabGlyph(t), selected: tab == t, count: (counts[t] ?? 0) > 0 ? counts[t] : null,
                      onTap: () => setState(() => tab = t)),
                ),
            ]),
          );
    final head = Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.end, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        TEyebrow(c.roles.admin ? 'lessons.console.all_orgs'.tr() : (c.catalog.organizations[org]?.name(lang) ?? ''), icon: TGlyph.shield),
        const SizedBox(height: 4),
        Text('lessons.console.title'.tr(), style: tDisplay(context.wide ? 32 : 24)),
      ]),
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (orgs.length > 1)
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<String>(
              initialValue: org,
              isExpanded: true,
              decoration: tInput(),
              items: [
                for (final o in orgs)
                  DropdownMenuItem(value: o, child: Text(c.organization(o)?.name(lang) ?? o, overflow: TextOverflow.ellipsis))
              ],
              onChanged: (v) => v == null ? null : c.openConsole(v),
            ),
          ),
        TButton('lessons.console.submit_for'.tr(), icon: TGlyph.plus, onPressed: () => context.push('/lessons/submit')),
      ]),
    ]);
    return LessonsPage(title: 'lessons.console.title'.tr(), children: [
      head,
      if (context.wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 250, child: nav),
          const SizedBox(width: 28),
          Expanded(child: content),
        ])
      else ...[
        nav,
        content,
      ],
    ]);
  }
}

// --------------------------------------------------------------- overview
class _Overview extends StatelessWidget {
  const _Overview({required this.onTab});
  final ValueChanged<String> onTab;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final reqs = c.pendingRequests;
    final week = c.upcoming.where((l) => !l.date.isAfter(addDays(c.today, 6))).toList();
    final active = c.publicLessons.where((l) => l.isPublic && !l.date.isBefore(addDays(c.today, -30))).map((l) => l.preacherId).toSet().length;
    final clashN = reqs.where((r) => r.items.any((l) => c.clashes(l).isNotEmpty)).length;
    final due = c.publicLessons
        .where((l) => l.isPublic && l.date.isBefore(c.today) && !l.date.isBefore(addDays(c.today, -14)) && !c.staff.reports.containsKey(l.id))
        .length;
    final attention = [
      (reqs.length, TGlyph.inbox, 'lessons.overview.a_requests', 'review', TTone.warning),
      (clashN, TGlyph.alert, 'lessons.overview.a_clash', 'review', TTone.danger),
      (c.staff.flags.where((f) => f.status == 'open').length, TGlyph.flag, 'lessons.overview.a_reports', 'review', TTone.warning),
      (c.catalog.mosques.values.where((m) => !m.verified).length, TGlyph.mosque, 'lessons.overview.a_mosques', 'mosques', TTone.info),
      (c.staff.roster.where((r) => r.account == 'none').length, TGlyph.link, 'lessons.overview.a_invite', 'preachers', TTone.info),
      (due, TGlyph.file, 'lessons.overview.a_due', 'reports', TTone.slate),
    ].where((a) => a.$1 > 0).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TStatTiles(big: true, [
        ('${reqs.length}', 'lessons.overview.waiting'.tr()),
        ('${week.length}', 'lessons.overview.week'.tr()),
        ('$active', 'lessons.overview.active'.tr()),
        ('${week.map((l) => l.mosqueId).toSet().length}', 'lessons.overview.covered'.tr()),
      ]),
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
      const SizedBox(height: 16),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('lessons.overview.attention'.tr(), style: tStrong(17)),
          const SizedBox(height: 8),
          if (attention.isEmpty) TEmpty(ok: true, icon: TGlyph.check, title: 'lessons.overview.all_clear'.tr()),
          for (final (n, glyph, key, target, tone) in attention)
            InkWell(
              onTap: () => onTab(target),
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

// ----------------------------------------------------------------- review
class _Review extends StatefulWidget {
  const _Review({this.initial});
  final String? initial;
  @override
  State<_Review> createState() => _ReviewState();
}

class _ReviewState extends State<_Review> {
  late String filter = widget.initial ?? 'all';
  final selected = <String>{};
  String? open;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final reqs = c.pendingRequests;
    bool isClash(LessonRequest r) => r.items.any((l) => c.clashes(l).isNotEmpty);
    bool newMosque(LessonRequest r) => !(c.mosque(r.first.mosqueId)?.verified ?? true);
    final shown = reqs
        .where((r) => switch (filter) {
              'clash' => isClash(r),
              'new_mosque' => newMosque(r),
              'series' => r.isSeries,
              _ => true,
            })
        .toList();
    final reports = c.staff.flags.where((f) => f.status == 'open').toList();

    Future<void> approve(List<String> ids) async {
      final n = await tRun(context, () => c.review(ids, 'approve'));
      setState(selected.clear);
      if (n != null && context.mounted) {
        tToast(context, 'lessons.review.approved'.tr(args: [tPlural('requests', n)]),
            actionLabel: 'lessons.review.undo'.tr(), onAction: () => tRun(context, () => c.undoReview(ids), success: 'lessons.review.undone'.tr()));
      }
    }

    Future<void> reject(List<String> ids) async {
      final done = await showRejectSheet(context, ids);
      if (done == true) setState(selected.clear);
    }

    Widget flags(LessonRequest r) => Wrap(spacing: 6, runSpacing: 6, children: [
          if (isClash(r)) TTag('lessons.review.clash'.tr(), tone: TTone.danger, icon: TGlyph.alert),
          if (newMosque(r)) TTag('lessons.review.new_mosque'.tr(), tone: TTone.info, icon: TGlyph.mosque),
          if (r.isSeries) TTag(tPlural('sessions', r.items.length), tone: TTone.slate, icon: TGlyph.repeat),
          if (r.first.language != 'ar') TTag(languageLabel(r.first.language), tone: TTone.info, icon: TGlyph.globe),
        ]);

    Widget detail(LessonRequest r) {
      final l = r.first;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 10),
        if (l.description(lang).isNotEmpty) Text('${'lessons.review.description'.tr()}: ${l.description(lang)}', style: tBody(13.5)),
        Text('${'lessons.lesson.audience'.tr()}: ${audienceLabel(l.audience)}${l.womenSection ? ' · ${'lessons.lesson.women'.tr()}' : ''}', style: tBody(13.5)),
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
                    '${gregorianLabel(x.date, lang)} · ${slotLabel(x.slot)}: ${o.mosqueId == x.mosqueId ? 'lessons.review.clash_mosque'.tr() : 'lessons.review.clash_preacher'.tr()} «${o.title(lang)}» — ${c.preacher(o.preacherId)?.name(lang) ?? ''} (${statusLabel(o.status)})'),
              ),
            ),
        if (newMosque(r))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TCallout(
              tone: TTone.info,
              icon: TGlyph.mosque,
              action: TButton('lessons.review.verify_now'.tr(), small: true,
                  onPressed: () => tRun(context, () => c.verifyMosque(l.mosqueId), success: 'lessons.mosques.verified'.tr())),
              child: Text('lessons.review.mosque_note'.tr()),
            ),
          ),
      ]);
    }

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
            Expanded(child: Text(c.preacher(l.preacherId)?.name(lang) ?? '', style: tStrong(14))),
            Text(agoText(r.submittedAt), style: tBody(12, color: TC.faint)),
          ]),
          Wrap(spacing: 6, children: [TypeTag(l.type)]),
          const SizedBox(height: 6),
          Text(l.title(lang), style: tStrong(16)),
          Text('${placeOf(c, l, lang)} · ${whenOf(c, l, lang)}${r.isSeries ? 'lessons.review.weekly'.tr() : ''}', style: tBody(13, color: TC.muted)),
          const SizedBox(height: 8),
          flags(r),
          if (open == r.id) detail(r),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TButton('lessons.review.approve'.tr(), kind: TBtn.minted, small: true, icon: TGlyph.check, onPressed: () => approve([r.id])),
            TButton('lessons.review.reject'.tr(), kind: TBtn.danger, small: true, icon: TGlyph.x, onPressed: () => reject([r.id])),
            TButton('lessons.review.details'.tr(), kind: TBtn.ghost, small: true, icon: open == r.id ? TGlyph.chevronDown : TGlyph.info,
                onPressed: () => setState(() => open = open == r.id ? null : r.id)),
          ]),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TChips([
          for (final (k, n) in [
            ('all', reqs.length),
            ('clash', reqs.where(isClash).length),
            ('new_mosque', reqs.where(newMosque).length),
            ('series', reqs.where((r) => r.isSeries).length),
            ('reports', reports.length),
          ])
            TChip('lessons.review.$k'.tr(), small: true, count: n, selected: filter == k, onTap: () => setState(() {
              filter = k;
              selected.clear();
            })),
        ]),
        if (filter != 'reports')
          Wrap(spacing: 8, runSpacing: 8, children: [
            TButton('lessons.review.select_all'.tr(), small: true, kind: TBtn.ghost,
                onPressed: shown.isEmpty ? null : () => setState(() => selected.length == shown.length ? selected.clear() : selected.addAll(shown.map((r) => r.id)))),
            TButton('lessons.review.approve_sel'.tr(args: ['${selected.length}']), small: true, kind: TBtn.minted, icon: TGlyph.check,
                onPressed: selected.isEmpty ? null : () => approve(selected.toList())),
            TButton('lessons.review.reject_sel'.tr(), small: true, kind: TBtn.danger, icon: TGlyph.x, onPressed: selected.isEmpty ? null : () => reject(selected.toList())),
          ]),
      ]),
      const SizedBox(height: 14),
      if (filter == 'reports')
        reports.isEmpty
            ? TEmpty(icon: TGlyph.flag, title: 'lessons.review.no_reports'.tr())
            : Column(children: [
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
                        Wrap(spacing: 8, children: [
                          TButton('lessons.review.open_lesson'.tr(), small: true, icon: TGlyph.eye, onPressed: () => context.push('/lessons/lesson/${f.lessonId}')),
                          TButton('lessons.review.resolved'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
                            await tRun(context, () => c.resolveFlag(f.id), success: 'lessons.review.resolved_toast'.tr());
                            await c.openConsole(c.staffOrganizationId);
                          }),
                        ]),
                      ]),
                    ),
                  ),
              ])
      else if (shown.isEmpty)
        TEmpty(ok: true, icon: TGlyph.check, title: 'lessons.review.empty'.tr(), body: 'lessons.review.empty_body'.tr())
      else
        Column(children: [for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: card(r))]),
    ]);
  }
}

// ----------------------------------------------------------------- roster
class _Roster extends StatefulWidget {
  const _Roster({required this.org});
  final String org;
  @override
  State<_Roster> createState() => _RosterState();
}

class _RosterState extends State<_Roster> {
  String q = '';
  String? account;
  final revealed = <String, String>{};

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final roster = c.staff.roster;
    final list = roster
        .where((r) => (q.isEmpty || r.preacher.nameAr.contains(q) || r.preacher.nameEn.toLowerCase().contains(q.toLowerCase())) && (account == null || r.account == account))
        .toList();
    int n(String a) => roster.where((r) => r.account == a).length;
    TTone accTone(String a) => a == 'linked' ? TTone.success : a == 'invited' ? TTone.warning : TTone.slate;

    Future<void> reveal(LessonsRosterEntry r) async {
      if (revealed.containsKey(r.preacher.id)) {
        setState(() => revealed.remove(r.preacher.id));
        return;
      }
      final phone = await tRun(context, () => c.revealPhone(r.preacher.id));
      if (phone == null || !mounted) return;
      setState(() => revealed[r.preacher.id] = phone);
      if (context.mounted) tToast(context, 'lessons.roster.logged'.tr());
    }

    Widget row(LessonsRosterEntry r) {
      final p = r.preacher;
      return TCard(
        padding: const EdgeInsets.all(14),
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
            TTag('lessons.account.${r.account}'.tr(), tone: accTone(r.account)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Tooltip(
              message: 'lessons.roster.show_number'.tr(),
              child: InkWell(
                onTap: r.phoneMask == null ? null : () => reveal(r),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const TIcon(TGlyph.eye, size: 14, color: TC.goldIcon),
                    const SizedBox(width: 6),
                    Text(revealed[p.id] ?? r.phoneMask ?? '—', textDirection: TextDirection.ltr, style: tBody(13, color: TC.ink, weight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            TTag('${'lessons.roster.h_lessons'.tr()}: ${r.lessons30d}', tone: TTone.slate),
            if (r.account == 'linked')
              Row(mainAxisSize: MainAxisSize.min, children: [
                Text('lessons.roster.h_verified'.tr(), style: tBody(13, color: TC.ink2)),
                Switch.adaptive(
                    value: r.canSubmit,
                    activeTrackColor: TC.gold,
                    onChanged: (v) async {
                      await tRun(context, () => c.setSubmit(p.id, v), success: v ? 'lessons.roster.granted'.tr() : 'lessons.roster.revoked'.tr());
                      await c.openConsole(widget.org);
                    }),
              ]),
            if (r.account != 'linked')
              TButton(r.account == 'invited' ? 'lessons.roster.resend'.tr() : 'lessons.roster.invite'.tr(), small: true, icon: TGlyph.send, onPressed: () async {
                await showInviteSheet(context, p);
                await c.openConsole(widget.org);
              }),
            TButton('lessons.lesson.edit'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.edit, onPressed: () => showPreacherEditSheet(context, widget.org, entry: r)),
            if (r.account == 'linked')
              TButton('lessons.roster.unlink'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.link, onPressed: () async {
                await tRun(context, () => c.unlinkPreacher(p.id));
                await c.openConsole(widget.org);
              }),
          ]),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TStatTiles([
        ('${roster.length}', 'lessons.roster.t_listed'.tr()),
        ('${n('linked')}', 'lessons.roster.t_linked'.tr()),
        ('${n('invited')}', 'lessons.roster.t_invited'.tr()),
        ('${n('none')}', 'lessons.roster.t_none'.tr()),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 260, child: TSearchBox(hint: 'lessons.roster.search'.tr(), onChanged: (v) => setState(() => q = v.trim()))),
        TChips([
          TChip('lessons.all'.tr(), small: true, selected: account == null, onTap: () => setState(() => account = null)),
          for (final a in ['linked', 'invited', 'none'])
            TChip('lessons.account.$a'.tr(), small: true, selected: account == a, onTap: () => setState(() => account = a)),
        ]),
        Wrap(spacing: 8, children: [
          TButton('lessons.roster.import'.tr(), small: true, icon: TGlyph.upload, onPressed: () => showImportSheet(context, widget.org)),
          TButton('lessons.roster.add'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.plus, onPressed: () => showPreacherEditSheet(context, widget.org)),
        ]),
      ]),
      const SizedBox(height: 14),
      for (final r in list) Padding(padding: const EdgeInsets.only(bottom: 8), child: row(r)),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TIcon(TGlyph.lock, size: 13, color: TC.muted),
        const SizedBox(width: 6),
        Expanded(child: Text('lessons.roster.privacy'.tr(), style: tBody(12.5, color: TC.muted))),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- mosques
class _Mosques extends StatefulWidget {
  const _Mosques();
  @override
  State<_Mosques> createState() => _MosquesState();
}

class _MosquesState extends State<_Mosques> {
  String? tab;
  final merge = <String, String>{};
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final pending = c.catalog.mosques.values.where((m) => !m.verified).toList();
    final verified = c.verifiedMosques;
    final t = tab ?? (pending.isEmpty ? 'all' : 'pending');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: TTabs<String>(value: t, onChanged: (v) => setState(() => tab = v), options: [
            TSegOption('pending', 'lessons.mosques.to_verify'.tr(), count: pending.length),
            TSegOption('all', 'lessons.mosques.directory'.tr(), count: verified.length),
          ]),
        ),
        const SizedBox(width: 10),
        TButton('lessons.mosques.add'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.plus, onPressed: () => showAddMosqueSheet(context)),
      ]),
      const SizedBox(height: 14),
      if (t == 'pending')
        if (pending.isEmpty)
          TEmpty(ok: true, icon: TGlyph.check, title: 'lessons.mosques.none'.tr())
        else
          for (final m in pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.name(lang), style: tStrong(15)),
                        Text('${c.district(m.districtId)?.name(lang) ?? ''} · ${cityLabel(c.cityOfMosque(m.id))}', style: tBody(13, color: TC.muted)),
                      ]),
                    ),
                    TTag('lessons.mosques.suggested'.tr(), tone: TTone.info, icon: TGlyph.mosque),
                  ]),
                  if (m.hasPin && LessonsMap.covers(m.latitude!, m.longitude!)) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(TC.r),
                      child: SizedBox(
                        height: 180,
                        child: LessonsMap(pins: [
                          MosquePin(id: m.id, lat: m.latitude!, lng: m.longitude!, label: m.name(lang), verified: false),
                          for (final v in verified.where((v) => v.hasPin && v.districtId == m.districtId))
                            MosquePin(id: v.id, lat: v.latitude!, lng: v.longitude!, label: v.name(lang), dim: true),
                        ], selected: m.id),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    TButton('lessons.mosques.verify'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.check,
                        onPressed: () => tRun(context, () => c.verifyMosque(m.id), success: 'lessons.mosques.verified'.tr())),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: merge[m.id],
                        isExpanded: true,
                        hint: Text('lessons.mosques.merge_into'.tr()),
                        decoration: tInput(),
                        items: [
                          for (final v in verified.where((v) => c.cityOfMosque(v.id) == c.cityOfMosque(m.id)))
                            DropdownMenuItem(value: v.id, child: Text(v.name(lang), overflow: TextOverflow.ellipsis))
                        ],
                        onChanged: (v) => setState(() => merge[m.id] = v ?? ''),
                      ),
                    ),
                    TButton('lessons.mosques.merge'.tr(), small: true, onPressed: (merge[m.id] ?? '').isEmpty
                        ? null
                        : () => tRun(context, () => c.rejectMosque(m.id, mergeInto: merge[m.id]), success: 'lessons.mosques.merged'.tr())),
                    TButton('lessons.mosques.reject'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.x,
                        onPressed: () => tRun(context, () => c.rejectMosque(m.id), success: 'lessons.mosques.rejected'.tr())),
                  ]),
                ]),
              ),
            )
      else
        for (final city in LessonsVocab.cities)
          if (verified.any((m) => c.cityOfMosque(m.id) == city)) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Text('${cityLabel(city)} · ${tPlural('mosques', verified.where((m) => c.cityOfMosque(m.id) == city).length)}', style: tStrong(15)),
            ),
            TGrid(minWidth: 240, spacing: 10, children: [
              for (final m in verified.where((m) => c.cityOfMosque(m.id) == city))
                TCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => context.push('/lessons/mosques/${m.id}'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name(lang), style: tStrong(14)),
                    Text(c.district(m.districtId)?.name(lang) ?? '', style: tBody(12.5, color: TC.muted)),
                    const SizedBox(height: 6),
                    FacilityList(m.facilities, dense: true),
                    const SizedBox(height: 6),
                    Text('${tPlural('ahead', lessonsAt(c, m.id).length)}${m.hasPin && LessonsMap.covers(m.latitude!, m.longitude!) ? '' : 'lessons.mosques.off_map'.tr()}',
                        style: tBody(12, color: TC.bronze)),
                  ]),
                ),
            ]),
          ],
    ]);
  }
}

// ------------------------------------------------------------------ stats
class _Stats extends StatefulWidget {
  const _Stats({required this.org});
  final String org;
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
    final held = c.publicLessons
        .where((l) => l.isPublic && l.organizationId == widget.org && !l.date.isBefore(first) && !l.date.isAfter(end))
        .toList();
    Map<String, int> by(String Function(Lesson) key) {
      final m = <String, int>{};
      for (final l in held) {
        m[key(l)] = (m[key(l)] ?? 0) + 1;
      }
      return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
    }

    final reports = c.staff.reports;
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

    final org = c.catalog.organizations[widget.org];
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
              Text(org?.name(lang) ?? '', style: tStrong(14)),
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

// ------------------------------------------------------------------ audit
class _Audit extends StatelessWidget {
  const _Audit();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    String who(LessonsAuditEntry a) {
      if (a.actorName.isNotEmpty) return a.actorName;
      for (final t in c.staff.team) {
        if (t.profileId == a.actorId) return t.name(lang);
      }
      for (final p in c.catalog.preachers.values) {
        if (p.linkedProfileId != null && p.linkedProfileId == a.actorId) return p.name(lang);
      }
      return '—';
    }

    TTone tone(String action) => const {'reject', 'revoke', 'cancel', 'rejectMosque', 'revokeSubmit', 'disable', 'unlink'}.contains(action)
        ? TTone.danger
        : action == 'phone'
            ? TTone.warning
            : TTone.slate;
    final list = c.staff.audit;
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
                  SizedBox(width: 170, child: Text(who(a), maxLines: 1, overflow: TextOverflow.ellipsis, style: tBody(13.5, color: TC.ink, weight: FontWeight.w600))),
                  TTag('lessons.audit.${a.action}'.tr(), tone: tone(a.action)),
                  Text(a.target(lang), style: tBody(13.5, color: TC.ink2)),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

// ------------------------------------------------------------------- team
class _Team extends StatelessWidget {
  const _Team({required this.org});
  final String org;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final mayGrant = c.roles.admin || c.roles.lead.contains(org);
    final orgName = c.organization(org)?.name(lang) ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (c.roles.admin) ...[const AdminCoordinatorsCard(), const SizedBox(height: 14)],
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 10, runSpacing: 6, alignment: WrapAlignment.spaceBetween, children: [
            Text('lessons.team.coordinators'.tr(args: [orgName]), style: tStrong(17)),
            if (!mayGrant) TTag('lessons.team.view_only'.tr(), tone: TTone.slate, icon: TGlyph.lock),
          ]),
          const SizedBox(height: 8),
          if (c.staff.team.isEmpty) Text('lessons.team.empty'.tr(), style: tBody(13.5, color: TC.muted)),
          for (final m in c.staff.team)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                TAvatar(name: m.name(lang), size: 38, ring: false),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.name(lang), style: tStrong(14)),
                    Text(
                        '${'lessons.team.member'.tr(args: ['lessons.role.${m.role}'.tr()])}${m.coordinator && (m.grantedByAr ?? m.grantedByEn) != null ? 'lessons.team.granted_by'.tr(args: [lang == 'ar' ? (m.grantedByAr ?? '') : (m.grantedByEn ?? '')]) : ''}',
                        style: tBody(12.5, color: TC.muted)),
                    if (m.coordinator) const Padding(padding: EdgeInsets.only(top: 4), child: TTag('activities.coordinate', icon: TGlyph.key)),
                  ]),
                ),
                if (m.role != 'owner')
                  Switch.adaptive(
                    value: m.coordinator,
                    activeTrackColor: TC.gold,
                    onChanged: !mayGrant
                        ? null
                        : (v) async {
                            await tRun(context, () => c.setCoordinator(org, m.profileId, v), success: v ? 'lessons.team.granted'.tr() : 'lessons.team.revoked'.tr());
                            await c.openConsole(org);
                          },
                  ),
              ]),
            ),
          const SizedBox(height: 6),
          Text('lessons.team.scoped'.tr(), style: tBody(12.5, color: TC.muted)),
        ]),
      ),
      if (c.roles.master) ...[
        const SizedBox(height: 14),
        TCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('lessons.team.orgs'.tr(), style: tStrong(17)),
            const SizedBox(height: 8),
            for (final o in c.adminOrganizations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: TC.tagBg, shape: BoxShape.circle),
                      child: const TIcon(TGlyph.users, size: 16, color: TC.goldIcon)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(o.name(lang), style: tBody(14, color: TC.ink, weight: FontWeight.w600))),
                  Switch.adaptive(
                    value: o.enabled,
                    activeTrackColor: TC.gold,
                    onChanged: (v) => tRun(context, () => c.setOrganizationEnabled(o.id, v),
                        success: v ? 'lessons.team.enabled'.tr() : 'lessons.team.disabled'.tr()),
                  ),
                ]),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      Text('lessons.team.matrix'.tr(), style: tStrong(17)),
      const SizedBox(height: 8),
      PermissionMatrix(highlight: c.roles.master ? 5 : c.roles.lead.contains(org) ? 4 : 3),
    ]);
  }
}
