import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/sign_in_prompt.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../data/demo_lessons_repository.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_shell.dart';
import '../lessons_widgets.dart';

// -------------------------------------------------------------------- me
/// A person's programme page (roles, reminders, preferences), opened from
/// Settings.
class LessonsMeScreen extends StatelessWidget {
  const LessonsMeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final demo = c.demoPersona;
    final children = <Widget>[
      if (demo != null) _DemoPersonaCard(current: demo),
      if (!c.signedIn) ...[
        TCard(
          child: Column(children: [
            const TEmpty(icon: TGlyph.user, title: ''),
            Text('lessons.me.guest_title'.tr(), textAlign: TextAlign.center, style: tDisplay(24)),
            const SizedBox(height: 8),
            Text('lessons.me.guest_body'.tr(), textAlign: TextAlign.center, style: tBody(15, color: TC.muted)),
            const SizedBox(height: 16),
            TButton('lessons.sign_in'.tr(), kind: TBtn.minted, expand: true, onPressed: () => openSignIn(context)),
          ]),
        ),
        TCard(
          child: Row(children: [
            Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: TC.tagBg, shape: BoxShape.circle),
                child: const TIcon(TGlyph.link, size: 20, color: TC.goldIcon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('lessons.me.invite_title'.tr(), style: tStrong(15)),
                Text('lessons.me.invite_body'.tr(), style: tBody(13, color: TC.muted)),
              ]),
            ),
          ]),
        ),
      ] else ...[
        if (c.canManage)
          TCard(
            onTap: () => context.push('/admin/lessons'),
            child: Row(children: [
              Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: TC.tagBg, shape: BoxShape.circle),
                  child: const TIcon(TGlyph.inbox, size: 20, color: TC.goldIcon)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('lessons.me.console'.tr(), style: tStrong(15)),
                  Text('lessons.me.console_body'.tr(args: [
                    tPlural('requests', c.pendingRequests.length + c.pendingEdits.length),
                    tPlural('reports', c.openFlags.length),
                  ]), style: tBody(13, color: TC.muted)),
                ]),
              ),
              TButton('lessons.me.open'.tr(), kind: TBtn.minted, small: true, iconEnd: TGlyph.arrowEnd, onPressed: () => context.push('/admin/lessons')),
            ]),
          ),
        TCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            _MenuRow(TGlyph.bell, 'lessons.me.reminders'.tr(), count: c.mine.reminders.length, onTap: () => context.push('/lessons/me/saved?tab=reminders')),
            _MenuRow(TGlyph.users, 'lessons.me.following'.tr(), count: c.mine.follows.length, onTap: () => context.push('/lessons/me/saved?tab=preachers')),
            _MenuRow(TGlyph.book, 'lessons.me.log'.tr(), count: c.mine.attended.length, onTap: () => context.push('/lessons/me/saved?tab=log')),
            _MenuRow(TGlyph.inbox, 'lessons.me.notifications'.tr(), count: c.mine.unread, onTap: () => context.push('/lessons/me/notifications')),
          ]),
        ),
        const _PrefsCard(),
      ],
    ];
    return LessonsPage(title: 'lessons.programme'.tr(), narrow: true, children: [
      Text('lessons.programme'.tr(), style: tDisplay(26)),
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

class _PrefsCard extends StatelessWidget {
  const _PrefsCard();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final prefs = c.mine.preferences;
    final ar = context.ar;
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('lessons.me.prefs'.tr(), style: tStrong(17)),
        const SizedBox(height: 10),
        Text('lessons.me.default_lead'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        TSeg<String>(
          full: true,
          small: true,
          value: prefs.defaultLead,
          onChanged: (v) => tRun(context, () => c.savePreferences(LessonsPreferences(defaultLead: v, eveningDigest: prefs.eveningDigest))),
          options: [for (final l in LessonsVocab.leads) TSegOption(l, 'lessons.lead.$l'.tr())],
        ),
        TToggleRow(
          label: 'lessons.me.digest'.tr(),
          desc: 'lessons.me.digest_body'.tr(),
          icon: TGlyph.moon,
          value: prefs.eveningDigest,
          onChanged: (v) => tRun(context, () => c.savePreferences(LessonsPreferences(defaultLead: prefs.defaultLead, eveningDigest: v))),
        ),
        Row(children: [
          Expanded(child: Text('lessons.calendar.language'.tr(), style: tBody(14, color: TC.ink))),
          TSeg<String>(small: true, value: ar ? 'ar' : 'en', onChanged: (v) => LanguageSwitcher.set(context, v), options: const [
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
  final LessonsDemoPersona current;
  @override
  Widget build(BuildContext context) {
    final c = context.read<LessonsController>();
    return TCard(
      color: TC.warnBg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('lessons.me.demo_title'.tr(), style: tStrong(15)),
        const SizedBox(height: 8),
        TChips([
          for (final p in LessonsDemoPersona.values)
            TChip('lessons.me.p_${p.name}'.tr(), small: true, selected: p == current, onTap: () => c.setDemoPersona(p)),
        ]),
        const SizedBox(height: 8),
        Text('lessons.me.demo_note'.tr(), style: tBody(12.5, color: TC.warnFg)),
      ]),
    );
  }
}

// ---------------------------------------------------------- notifications
class LessonsNotificationsScreen extends StatelessWidget {
  const LessonsNotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final list = c.mine.notifications;
    return LessonsPage(title: 'lessons.notifications.title'.tr(), narrow: true, children: [
      Row(children: [
        Expanded(child: Text('lessons.notifications.title'.tr(), style: tDisplay(26))),
        if (list.any((n) => n.unread))
          TButton('lessons.notifications.mark_all'.tr(), kind: TBtn.ghost, small: true, icon: TGlyph.check, onPressed: () => tRun(context, () => c.markRead())),
      ]),
      if (list.isEmpty)
        TEmpty(icon: TGlyph.bell, title: 'lessons.notifications.empty'.tr(), body: c.signedIn ? null : 'lessons.notifications.empty_guest'.tr())
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
class LessonsSavedScreen extends StatefulWidget {
  const LessonsSavedScreen({super.key, this.tab});
  final String? tab;
  @override
  State<LessonsSavedScreen> createState() => _LessonsSavedScreenState();
}

class _LessonsSavedScreenState extends State<LessonsSavedScreen> {
  late String tab = widget.tab ?? 'reminders';
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final rem = [for (final id in c.mine.reminders.keys) c.lesson(id)].whereType<Lesson>().toList()..sort(compareLessons);
    List<String> followed(String kind) => [for (final f in c.mine.follows) if (f.startsWith('$kind:')) f.substring(kind.length + 1)];
    final att = [for (final id in c.mine.attended) c.lesson(id)].whereType<Lesson>().toList()..sort((a, b) => compareLessons(b, a));
    Widget empty() => TEmpty(title: 'lessons.saved.empty'.tr());
    return LessonsPage(title: 'lessons.saved.title'.tr(), narrow: true, children: [
      Text('lessons.saved.title'.tr(), style: tDisplay(26)),
      if (!c.signedIn)
        TEmpty(icon: TGlyph.user, title: 'lessons.me.guest_title'.tr(), action: TButton('lessons.sign_in'.tr(), kind: TBtn.minted, onPressed: () => openSignIn(context)))
      else ...[
        TTabs<String>(value: tab, onChanged: (v) => setState(() => tab = v), options: [
          TSegOption('reminders', 'lessons.saved.reminders'.tr(), count: rem.length),
          TSegOption('preachers', 'lessons.saved.preachers'.tr(), count: followed('preacher').length),
          TSegOption('series', 'lessons.saved.series'.tr(), count: followed('series').length),
          TSegOption('mosques', 'lessons.saved.mosques'.tr(), count: followed('mosque').length),
          TSegOption('log', 'lessons.saved.log'.tr(), count: att.length),
        ]),
        switch (tab) {
          'reminders' => rem.isEmpty
              ? TEmpty(icon: TGlyph.bell, title: 'lessons.saved.empty_reminders'.tr(), body: 'lessons.saved.empty_reminders_body'.tr())
              : Column(children: [
                  for (final l in rem)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LessonRow(l,
                          showDate: true,
                          extra: TTag('lessons.lead.${c.reminderLead(l.id)}'.tr(), tone: TTone.gold, icon: TGlyph.bell)),
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
                        onTap: () => context.push('/lessons/mosques/$id'),
                      ),
                ]),
          _ => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TStatTiles([
                ('${att.length}', 'lessons.saved.t_attended'.tr()),
                ('${att.length}', 'lessons.saved.t_hours'.tr()),
                ('${att.map((l) => l.topic).toSet().length}', 'lessons.saved.t_subjects'.tr()),
                ('${att.map((l) => l.preacherId).toSet().length}', 'lessons.saved.t_preachers'.tr()),
              ]),
              const SizedBox(height: 10),
              Text('lessons.saved.log_note'.tr(), style: tBody(13, color: TC.muted)),
              const SizedBox(height: 10),
              for (final l in att) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, showDate: true)),
            ]),
        },
      ],
    ]);
  }
}
