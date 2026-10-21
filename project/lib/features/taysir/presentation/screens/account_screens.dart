import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/sign_in_prompt.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../data/demo_taysir_repository.dart';
import '../../domain/taysir_models.dart';
import '../../domain/taysir_rules.dart';
import '../../domain/taysir_vocab.dart';
import '../../state/taysir_controller.dart';
import '../taysir_kit.dart';
import '../taysir_shell.dart';
import '../taysir_widgets.dart';

// -------------------------------------------------------------------- me
class TaysirMeScreen extends StatelessWidget {
  const TaysirMeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final lang = context.lang;
    final demo = c.demoPersona;
    final children = <Widget>[
      if (demo != null) _DemoPersonaCard(current: demo),
      if (!c.signedIn) ...[
        TCard(
          child: Column(children: [
            const TEmpty(icon: TGlyph.user, title: ''),
            Text('taysir.me.guest_title'.tr(), textAlign: TextAlign.center, style: tDisplay(24)),
            const SizedBox(height: 8),
            Text('taysir.me.guest_body'.tr(), textAlign: TextAlign.center, style: tBody(15, color: TC.muted)),
            const SizedBox(height: 16),
            TButton('taysir.sign_in'.tr(), kind: TBtn.minted, expand: true, onPressed: () => openSignIn(context)),
          ]),
        ),
        TCard(
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: TC.tagBg, shape: BoxShape.circle),
                child: const TIcon(TGlyph.link, size: 20, color: TC.goldIcon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('taysir.me.invite_title'.tr(), style: tStrong(15)),
                Text('taysir.me.invite_body'.tr(), style: tBody(13, color: TC.muted)),
              ]),
            ),
          ]),
        ),
      ] else ...[
        if (c.canSubmitOwn) _PreacherSummary(c: c),
        if (c.canCoordinate)
          TCard(
            onTap: () => context.push('/taysir/console'),
            child: Row(children: [
              Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: TC.tagBg, shape: BoxShape.circle),
                  child: const TIcon(TGlyph.inbox, size: 20, color: TC.goldIcon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('taysir.me.console'.tr(), style: tStrong(15)),
                  Text('taysir.me.console_body'.tr(args: [
                    tPlural('requests', c.pendingRequests.length),
                    tPlural('reports', c.staff.flags.where((f) => f.status == 'open').length),
                  ]), style: tBody(13, color: TC.muted)),
                ]),
              ),
              TButton('taysir.me.open'.tr(), kind: TBtn.minted, small: true, iconEnd: TGlyph.arrowEnd, onPressed: () => context.push('/taysir/console')),
            ]),
          ),
        TCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            _MenuRow(TGlyph.bell, 'taysir.me.reminders'.tr(), count: c.mine.reminders.length, onTap: () => context.push('/taysir/me/saved?tab=reminders')),
            _MenuRow(TGlyph.users, 'taysir.me.following'.tr(), count: c.mine.follows.length, onTap: () => context.push('/taysir/me/saved?tab=preachers')),
            _MenuRow(TGlyph.book, 'taysir.me.log'.tr(), count: c.mine.attended.length, onTap: () => context.push('/taysir/me/saved?tab=log')),
            _MenuRow(TGlyph.inbox, 'taysir.me.notifications'.tr(), count: c.mine.unread, onTap: () => context.push('/taysir/me/notifications')),
            _MenuRow(TGlyph.key, 'taysir.me.permissions'.tr(), onTap: () => context.push('/taysir/permissions')),
          ]),
        ),
        const _PrefsCard(),
      ],
      TCard(
        onTap: () => context.push('/settings'),
        child: Row(children: [
          const AppLogo(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('taysir.me.settings'.tr(), style: tStrong(15)),
              Text('settings.experience_hint_taysir'.tr(), style: tBody(13, color: TC.muted)),
            ]),
          ),
          const TIcon(TGlyph.chevron, size: 18, color: TC.faint),
        ]),
      ),
    ];
    return TaysirTabBody(narrow: true, children: [
      if (c.signedIn && lang.isNotEmpty) Text('taysir.nav.me'.tr(), style: tDisplay(26)),
      ...children,
    ]);
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.glyph, this.label, {required this.onTap, this.count});
  final TGlyph glyph;
  final String label;
  final int? count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(children: [
            TIcon(glyph, size: 19, color: TC.goldIcon),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: tBody(15, color: TC.ink, weight: FontWeight.w600))),
            if ((count ?? 0) > 0) TTag('$count', tone: TTone.gold),
            const SizedBox(width: 6),
            const TIcon(TGlyph.chevron, size: 16, color: TC.faint),
          ]),
        ),
      );
}

class _PreacherSummary extends StatelessWidget {
  const _PreacherSummary({required this.c});
  final TaysirController c;
  @override
  Widget build(BuildContext context) {
    final reqs = c.myRequests();
    final up = c.myLessons(upcomingOnly: true).where((l) => l.isPublic).length;
    final due = c.myLessons(upcomingOnly: false).where((l) => !c.staff.reports.containsKey(l.id)).length;
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('taysir.me.my_lessons'.tr(), style: tStrong(17))),
          TButton('taysir.discover.submit'.tr(), kind: TBtn.minted, small: true, icon: TGlyph.plus, onPressed: () => context.push('/taysir/submit')),
        ]),
        const SizedBox(height: 12),
        TStatTiles([
          ('$up', 'taysir.me.t_approved'.tr()),
          ('${reqs.where((r) => r.status == 'pending').length}', 'taysir.me.t_review'.tr()),
          ('${reqs.where((r) => r.status == 'rejected').length}', 'taysir.me.t_changes'.tr()),
          ('$due', 'taysir.me.t_reports'.tr()),
        ]),
        const SizedBox(height: 12),
        TButton('taysir.me.manage'.tr(), expand: true, iconEnd: TGlyph.arrowEnd, onPressed: () => context.push('/taysir/me/lessons')),
      ]),
    );
  }
}

class _PrefsCard extends StatelessWidget {
  const _PrefsCard();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final prefs = c.mine.preferences;
    final ar = context.ar;
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('taysir.me.prefs'.tr(), style: tStrong(17)),
        const SizedBox(height: 10),
        Text('taysir.me.default_lead'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        TSeg<String>(
          full: true,
          small: true,
          value: prefs.defaultLead,
          onChanged: (v) => tRun(context, () => c.savePreferences(TaysirPreferences(defaultLead: v, eveningDigest: prefs.eveningDigest))),
          options: [for (final l in TaysirVocab.leads) TSegOption(l, 'taysir.lead.$l'.tr())],
        ),
        TToggleRow(
          label: 'taysir.me.digest'.tr(),
          desc: 'taysir.me.digest_body'.tr(),
          icon: TGlyph.moon,
          value: prefs.eveningDigest,
          onChanged: (v) => tRun(context, () => c.savePreferences(TaysirPreferences(defaultLead: prefs.defaultLead, eveningDigest: v))),
        ),
        Row(children: [
          Expanded(child: Text('taysir.lessons.language'.tr(), style: tBody(14, color: TC.ink))),
          TSeg<String>(small: true, value: ar ? 'ar' : 'en', onChanged: (v) => context.setLocale(Locale(v)), options: const [
            TSegOption('ar', 'العربية'),
            TSegOption('en', 'English'),
          ]),
        ]),
      ]),
    );
  }
}

class _DemoPersonaCard extends StatelessWidget {
  const _DemoPersonaCard({required this.current});
  final TaysirDemoPersona current;
  @override
  Widget build(BuildContext context) {
    final c = context.read<TaysirController>();
    return TCard(
      color: TC.warnBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('taysir.me.demo_title'.tr(), style: tStrong(15)),
        const SizedBox(height: 8),
        TChips([
          for (final p in TaysirDemoPersona.values)
            TChip('taysir.me.p_${p.name}'.tr(), small: true, selected: p == current, onTap: () => c.setDemoPersona(p)),
        ]),
        const SizedBox(height: 8),
        Text('taysir.me.demo_note'.tr(), style: tBody(12.5, color: TC.warnFg)),
      ]),
    );
  }
}

// ---------------------------------------------------------- notifications
class TaysirNotificationsScreen extends StatelessWidget {
  const TaysirNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final lang = context.lang;
    final list = c.mine.notifications;
    return TaysirPage(title: 'taysir.notifications.title'.tr(), narrow: true, children: [
      Row(children: [
        Expanded(child: Text('taysir.notifications.title'.tr(), style: tDisplay(26))),
        if (list.any((n) => n.unread))
          TButton('taysir.notifications.mark_all'.tr(), kind: TBtn.ghost, small: true, icon: TGlyph.check, onPressed: () => tRun(context, () => c.markRead())),
      ]),
      if (list.isEmpty)
        TEmpty(icon: TGlyph.bell, title: 'taysir.notifications.empty'.tr(), body: c.signedIn ? null : 'taysir.notifications.empty_guest'.tr())
      else
        TCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final n in list)
              InkWell(
                onTap: () {
                  if (n.unread) tRun(context, () => c.markRead([n.id]));
                  context.push(n.route);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.unread ? TC.tint.withValues(alpha: .5) : null,
                    border: const Border(bottom: BorderSide(color: TC.hair)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 34, height: 34, alignment: Alignment.center, decoration: const BoxDecoration(color: TC.tagBg, shape: BoxShape.circle),
                        child: TIcon(_notificationGlyph(n.icon), size: 17, color: TC.goldIcon)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(n.title(lang), style: tStrong(14.5)),
                        if (n.body(lang).isNotEmpty) Text(n.body(lang), style: tBody(13, color: TC.muted)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(agoText(n.createdAt), style: tBody(12, color: TC.faint)),
                  ]),
                ),
              ),
          ]),
        ),
    ]);
  }
}

TGlyph _notificationGlyph(String icon) => switch (icon) {
      'check' => TGlyph.check,
      'x' => TGlyph.x,
      'inbox' => TGlyph.inbox,
      'flag' => TGlyph.flag,
      'alert' => TGlyph.alert,
      'sparkle' => TGlyph.sparkle,
      'clock' => TGlyph.clock,
      'user' => TGlyph.user,
      'file' => TGlyph.file,
      _ => TGlyph.bell,
    };

// ------------------------------------------------------------------ saved
class TaysirSavedScreen extends StatefulWidget {
  const TaysirSavedScreen({super.key, this.tab});
  final String? tab;
  @override
  State<TaysirSavedScreen> createState() => _TaysirSavedScreenState();
}

class _TaysirSavedScreenState extends State<TaysirSavedScreen> {
  late String tab = widget.tab ?? 'reminders';
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final lang = context.lang;
    final rem = [for (final id in c.mine.reminders.keys) c.lesson(id)].whereType<TaysirLesson>().toList()..sort(compareLessons);
    List<String> followed(String kind) => [for (final f in c.mine.follows) if (f.startsWith('$kind:')) f.substring(kind.length + 1)];
    final att = [for (final id in c.mine.attended) c.lesson(id)].whereType<TaysirLesson>().toList()..sort((a, b) => compareLessons(b, a));
    Widget empty() => TEmpty(title: 'taysir.saved.empty'.tr());
    return TaysirPage(title: 'taysir.saved.title'.tr(), narrow: true, children: [
      Text('taysir.saved.title'.tr(), style: tDisplay(26)),
      if (!c.signedIn)
        TEmpty(icon: TGlyph.user, title: 'taysir.me.guest_title'.tr(), action: TButton('taysir.sign_in'.tr(), kind: TBtn.minted, onPressed: () => openSignIn(context)))
      else ...[
        TTabs<String>(value: tab, onChanged: (v) => setState(() => tab = v), options: [
          TSegOption('reminders', 'taysir.saved.reminders'.tr(), count: rem.length),
          TSegOption('preachers', 'taysir.saved.preachers'.tr(), count: followed('preacher').length),
          TSegOption('series', 'taysir.saved.series'.tr(), count: followed('series').length),
          TSegOption('mosques', 'taysir.saved.mosques'.tr(), count: followed('mosque').length),
          TSegOption('log', 'taysir.saved.log'.tr(), count: att.length),
        ]),
        switch (tab) {
          'reminders' => rem.isEmpty
              ? TEmpty(icon: TGlyph.bell, title: 'taysir.saved.empty_reminders'.tr(), body: 'taysir.saved.empty_reminders_body'.tr())
              : Column(children: [
                  for (final l in rem)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LessonRow(l,
                          showDate: true,
                          extra: TTag('taysir.lead.${c.reminderLead(l.id)}'.tr(), tone: TTone.gold, icon: TGlyph.bell)),
                    ),
                ]),
          'preachers' => followed('preacher').isEmpty
              ? empty()
              : TGrid(minWidth: 220, children: [for (final id in followed('preacher')) if (c.preacher(id) != null) PreacherCard(c.preacher(id)!)]),
          'series' => followed('series').isEmpty
              ? empty()
              : TGrid(minWidth: 260, children: [for (final id in followed('series')) if (c.seriesOf(id) != null) SeriesCard(c.seriesOf(id)!)]),
          'mosques' => followed('mosque').isEmpty
              ? empty()
              : Column(children: [
                  for (final id in followed('mosque'))
                    if (c.mosque(id) != null)
                      MosqueRow(
                        mosque: c.mosque(id)!,
                        count: lessonsAt(c, id).length,
                        subtitle: c.district(c.mosque(id)!.districtId)?.name(lang),
                        onTap: () => context.push('/taysir/mosques/$id'),
                      ),
                ]),
          _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TStatTiles([
                ('${att.length}', 'taysir.saved.t_attended'.tr()),
                ('${att.length}', 'taysir.saved.t_hours'.tr()),
                ('${att.map((l) => l.topic).toSet().length}', 'taysir.saved.t_subjects'.tr()),
                ('${att.map((l) => l.preacherId).toSet().length}', 'taysir.saved.t_preachers'.tr()),
              ]),
              const SizedBox(height: 10),
              Text('taysir.saved.log_note'.tr(), style: tBody(13, color: TC.muted)),
              const SizedBox(height: 10),
              for (final l in att) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, showDate: true)),
            ]),
        },
      ],
    ]);
  }
}

// ------------------------------------------------------------ permissions
class TaysirPermissionsScreen extends StatelessWidget {
  const TaysirPermissionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    return TaysirPage(title: 'taysir.nav.permissions'.tr(), children: [
      TPageHead(eyebrow: 'taysir.perm.eyebrow'.tr(), title: 'taysir.perm.title'.tr(), subtitle: 'taysir.perm.body'.tr()),
      TGrid(minWidth: 320, children: [
        TCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const TTag('activities.coordinate', icon: TGlyph.key),
            const SizedBox(height: 8),
            Text('taysir.perm.coord'.tr(), style: tStrong(15)),
            Text('taysir.perm.coord_body'.tr(), style: tBody(13, color: TC.muted)),
          ]),
        ),
        TCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const TTag('activities.submit', icon: TGlyph.key),
            const SizedBox(height: 8),
            Text('taysir.perm.submit'.tr(), style: tStrong(15)),
            Text('taysir.perm.submit_body'.tr(), style: tBody(13, color: TC.muted)),
          ]),
        ),
      ]),
      PermissionMatrix(highlight: c.roles.master
          ? 5
          : c.roles.lead.isNotEmpty
              ? 4
              : c.canCoordinate
                  ? 3
                  : c.canSubmitOwn
                      ? 2
                      : c.signedIn
                          ? 1
                          : 0),
      Text('taysir.perm.highlight'.tr(), style: tBody(13, color: TC.muted)),
    ]);
  }
}

/// Who may do what: the table from the reviewed design.
class PermissionMatrix extends StatelessWidget {
  const PermissionMatrix({super.key, required this.highlight});
  final int highlight;
  static const _rows = [
    ['✓', '✓', '✓', '✓', '✓', '✓'],
    ['in', '✓', '✓', '✓', '✓', '✓'],
    ['—', '—', 'own', 'org', 'org', 'all'],
    ['—', '—', 'self', 'org', 'org', 'all'],
    ['—', '—', 'own', 'org', 'org', 'all'],
    ['—', '—', '—', 'org', 'org', 'all'],
    ['—', '—', '—', 'org', 'org', 'all'],
    ['—', '—', 'suggest', '✓', '✓', '✓'],
    ['—', '—', 'own', 'org', 'org', 'all'],
    ['—', '—', '—', '—', 'org', 'all'],
    ['—', '—', '—', '—', '—', '✓'],
  ];
  @override
  Widget build(BuildContext context) {
    const cols = ['guest', 'viewer', 'preacher', 'coordinator', 'owner', 'admin'];
    Widget cell(String v) => switch (v) {
          '✓' => const TIcon(TGlyph.check, size: 15, color: TC.successFg, stroke: 2.6),
          '—' => Text('—', style: tBody(13, color: TC.faint)),
          _ => Text('taysir.perm.v_$v'.tr(), style: tBody(12, color: TC.bronze, weight: FontWeight.w600)),
        };
    return TCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(TC.tint),
          columnSpacing: 18,
          columns: [
            DataColumn(label: Text('taysir.perm.action'.tr(), style: tStrong(13))),
            for (var i = 0; i < cols.length; i++)
              DataColumn(label: Text('taysir.perm.c_${cols[i]}'.tr(), style: tStrong(13, color: i == highlight ? TC.bronze : TC.ink))),
          ],
          rows: [
            for (var r = 0; r < _rows.length; r++)
              DataRow(cells: [
                DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Text('taysir.perm.r${r + 1}'.tr(), style: tBody(13, color: TC.ink)))),
                for (var i = 0; i < cols.length; i++)
                  DataCell(Container(
                    color: i == highlight ? TC.tint : null,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: cell(_rows[r][i]),
                  )),
              ]),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ claim
/// A preacher opens the coordinator's invitation link.
class TaysirClaimScreen extends StatefulWidget {
  const TaysirClaimScreen({super.key, required this.token});
  final String token;
  @override
  State<TaysirClaimScreen> createState() => _TaysirClaimScreenState();
}

class _TaysirClaimScreenState extends State<TaysirClaimScreen> {
  late final Future<TaysirInviteInfo?> info = context.read<TaysirController>().inviteInfo(widget.token).catchError((_) => null);
  Set<String>? langs;
  bool agree = false, done = false, busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final lang = context.lang;
    return TaysirPage(title: 'taysir.nav.claim'.tr(), narrow: true, children: [
      FutureBuilder<TaysirInviteInfo?>(
        future: info,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: TC.gold));
          final i = snap.data;
          if (done) {
            return TCard(
              child: TEmpty(
                ok: true,
                icon: TGlyph.check,
                title: 'taysir.claim.done'.tr(),
                body: 'taysir.claim.done_body'.tr(args: [i?.organization(lang) ?? '']),
                action: TButton('taysir.claim.first'.tr(), kind: TBtn.minted, icon: TGlyph.plus, onPressed: () => context.go('/taysir/submit')),
              ),
            );
          }
          if (i == null) {
            return TCard(child: TEmpty(icon: TGlyph.lock, title: 'taysir.claim.invalid'.tr(), body: 'taysir.claim.invalid_body'.tr()));
          }
          langs ??= {...i.languages};
          final step = !c.signedIn ? 1 : 2;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Stepper(step: step),
            const SizedBox(height: 16),
            TCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: AppLogo(size: 64)),
                const SizedBox(height: 10),
                Center(child: TEyebrow('taysir.claim.from'.tr(args: [i.organization(lang)]))),
                const SizedBox(height: 6),
                Text('taysir.claim.welcome'.tr(args: [i.name(lang)]), textAlign: TextAlign.center, style: tDisplay(24)),
                const SizedBox(height: 8),
                Text('taysir.claim.body'.tr(), textAlign: TextAlign.center, style: tBody(15, color: TC.muted)),
                const SizedBox(height: 12),
                TCallout(tone: TTone.info, icon: TGlyph.lock, child: Text('taysir.claim.no_password'.tr())),
                const SizedBox(height: 16),
                if (!c.signedIn)
                  TButton('taysir.claim.sign_in'.tr(), kind: TBtn.minted, large: true, expand: true, icon: TGlyph.user,
                      onPressed: () => openSignIn(context, returnTo: '/taysir/claim/${widget.token}'))
                else ...[
                  Text('taysir.claim.confirm'.tr(), style: tStrong(16)),
                  const SizedBox(height: 8),
                  _ClaimKv([
                    ('taysir.claim.name'.tr(), i.name(lang)),
                    ('taysir.claim.city'.tr(), cityLabel(i.city)),
                    ('taysir.claim.affiliation'.tr(), 'taysir.affiliation.${i.affiliation}'.tr()),
                  ]),
                  const SizedBox(height: 10),
                  Text('taysir.claim.languages'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  TChips([
                    for (final x in TaysirVocab.languages)
                      TChip(TaysirVocab.languageNative[x]!, small: true, selected: langs!.contains(x),
                          onTap: () => setState(() => langs!.contains(x) && langs!.length > 1 ? langs!.remove(x) : langs!.add(x))),
                  ]),
                  TToggleRow(label: 'taysir.claim.agree'.tr(), icon: TGlyph.file, value: agree, onChanged: (v) => setState(() => agree = v)),
                  const SizedBox(height: 8),
                  TButton('taysir.claim.link'.tr(), kind: TBtn.minted, large: true, expand: true, onPressed: !agree || busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          final r = await tRun(context, () => c.claimInvite(widget.token, langs!.toList()));
                          if (mounted) {
                            setState(() {
                              busy = false;
                              done = r != null;
                            });
                          }
                        }),
                ],
              ]),
            ),
          ]);
        },
      ),
    ]);
  }
}

class _ClaimKv extends StatelessWidget {
  const _ClaimKv(this.rows);
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              SizedBox(width: 110, child: Text(k, style: tBody(14, color: TC.muted))),
              Expanded(child: Text(v, style: tBody(14, color: TC.ink, weight: FontWeight.w600))),
            ]),
          ),
      ]);
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final labels = ['taysir.claim.s_invite'.tr(), 'taysir.claim.s_sign_in'.tr(), 'taysir.claim.s_profile'.tr(), 'taysir.claim.s_done'.tr()];
    return TStepper(labels: labels, current: step);
  }
}

/// Numbered steps; finished ones show a tick.
class TStepper extends StatelessWidget {
  const TStepper({super.key, required this.labels, required this.current, this.onTap});
  final List<String> labels;
  final int current;
  final ValueChanged<int>? onTap;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: InkWell(
              onTap: onTap == null || i >= current ? null : () => onTap!(i),
              child: Column(children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: i == current ? HidayahGradients.minted : (i < current ? HidayahGradients.selected : null),
                    color: i > current ? TC.tint : null,
                  ),
                  child: i < current
                      ? const TIcon(TGlyph.check, size: 14, color: HidayahGold.g200, stroke: 2.6)
                      : Text('${i + 1}', style: tStrong(13, color: TC.ink)),
                ),
                const SizedBox(height: 4),
                Text(labels[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: tBody(12, color: i == current ? TC.ink : TC.muted, weight: FontWeight.w600, height: 1.3)),
              ]),
            ),
          ),
      ]);
}
