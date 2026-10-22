import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/language_switcher.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../data/lessons_repository.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../../state/preacher_link_controller.dart';
import '../admin/lessons_admin_modals.dart' show dateTimeLabel;
import '../lessons_kit.dart';
import '../lessons_widgets.dart';

/// The page a preacher's link opens: no account, no sign-in. He sees his
/// lessons, asks for a new one and suggests changes to his card; admins
/// approve each one (owner decisions 2026-10-22). Written for older,
/// non-technical readers: large text, few choices per screen, plain words.
class PreacherLinkScreen extends StatelessWidget {
  const PreacherLinkScreen({super.key, required this.token});
  final String token;
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (ctx) => PreacherLinkController(ctx.read<LessonsController>().repository, token)..open(),
        child: const _LinkPage(),
      );
}

class _LinkPage extends StatelessWidget {
  const _LinkPage();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<PreacherLinkController>();
    final lang = context.lang;
    final Widget body;
    if (s.view == null && s.failure == null) {
      body = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: TC.gold)));
    } else if (s.view == null) {
      final e = s.failure!;
      final why = e.failure == LessonsFailure.expired ? e.detail : (e.failure == LessonsFailure.unavailable ? 'offline' : 'revoked');
      body = TCard(
        child: TEmpty(
          icon: why == 'offline' ? TGlyph.refresh : TGlyph.lock,
          title: 'lessons.link.closed_$why'.tr(),
          body: 'lessons.link.closed_body_$why'.tr(),
          action: why == 'offline' ? TButton('lessons.retry'.tr(), kind: TBtn.minted, large: true, icon: TGlyph.refresh, onPressed: s.open) : null,
        ),
      );
    } else {
      body = _Home(view: s.view!, lang: lang);
    }
    return Scaffold(
      backgroundColor: TC.page,
      appBar: AppBar(
        backgroundColor: TC.page,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        shape: const Border(bottom: BorderSide(color: TC.hair)),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const AppLogo(size: 30),
          const SizedBox(width: 8),
          Flexible(child: Text('lessons.app_name'.tr(), maxLines: 1, overflow: TextOverflow.ellipsis, style: tDisplay(18))),
        ]),
        actions: [
          TextButton(
            onPressed: () => LanguageSwitcher.toggle(context),
            child: Text(context.ar ? 'English' : 'العربية', style: tStrong(15, color: TC.bronze)),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: TC.gold,
        onRefresh: s.open,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Padding(padding: const EdgeInsets.fromLTRB(18, 18, 18, 40), child: body),
            ),
          ),
        ),
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.view, required this.lang});
  final PreacherLinkView view;
  final String lang;
  @override
  Widget build(BuildContext context) {
    final p = view.preacher;
    final today = lessonsToday();
    final coming = view.lessons.where((l) => !l.date.isBefore(today)).toList();
    final past = view.lessons.where((l) => l.date.isBefore(today) && l.status == 'approved').toList().reversed.toList();
    final lasts = view.kind == 'once'
        ? (view.validUntil == null ? 'lessons.link.this_phone'.tr() : 'lessons.link.this_phone_until'.tr(args: [dateTimeLabel(view.validUntil!, lang)]))
        : 'lessons.link.until'.tr(args: [dateTimeLabel(view.validUntil!, lang)]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        p.photoUrl == null
            ? TAvatar(name: p.name(lang), size: 64)
            : CircleAvatar(radius: 32, backgroundColor: TC.tint, backgroundImage: resolveImageProviderOrNull(p.photoUrl)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('lessons.link.hello'.tr(args: [p.name(lang)]), style: tDisplay(26)),
            Text('lessons.link.your_page'.tr(), style: tBody(16, color: TC.muted)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        const TIcon(TGlyph.lock, size: 15, color: TC.muted),
        const SizedBox(width: 6),
        Expanded(child: Text(lasts, style: tBody(14, color: TC.muted))),
      ]),
      const SizedBox(height: 18),
      TButton('lessons.link.request'.tr(), kind: TBtn.minted, large: true, expand: true, icon: TGlyph.plus,
          onPressed: () => _showRequestSheet(context, view)),
      const SizedBox(height: 10),
      TButton('lessons.link.edit_card'.tr(), large: true, expand: true, icon: TGlyph.edit, onPressed: () => _showCardSheet(context, view)),
      const SizedBox(height: 24),
      Text('lessons.link.coming'.tr(), style: tDisplay(22)),
      const SizedBox(height: 10),
      if (coming.isEmpty)
        TCard(child: Text('lessons.link.none_coming'.tr(), style: tBody(16, color: TC.ink2)))
      else
        for (final l in coming) Padding(padding: const EdgeInsets.only(bottom: 10), child: _LessonCard(lesson: l, lang: lang)),
      const SizedBox(height: 18),
      Text('lessons.link.card'.tr(), style: tDisplay(22)),
      const SizedBox(height: 10),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name(lang), style: tStrong(18)),
          if (p.title(lang).isNotEmpty) Text(p.title(lang), style: tBody(16, color: TC.bronze, weight: FontWeight.w600)),
          if (p.bio(lang).isNotEmpty) ...[const SizedBox(height: 8), Text(p.bio(lang), style: tBody(16, color: TC.ink2))],
          const SizedBox(height: 8),
          Text(p.languages.map((x) => LessonsVocab.languageNative[x] ?? x).join(' · '), style: tBody(15, color: TC.muted)),
          if (view.pendingEdit != null) ...[
            const SizedBox(height: 12),
            TCallout(tone: TTone.info, icon: TGlyph.clock, child: Text('lessons.link.edit_waiting'.tr(), style: tBody(15))),
          ],
        ]),
      ),
      if (past.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text('lessons.link.past'.tr(), style: tDisplay(22)),
        const SizedBox(height: 10),
        for (final l in past.take(10)) Padding(padding: const EdgeInsets.only(bottom: 10), child: _LessonCard(lesson: l, lang: lang)),
      ],
      const SizedBox(height: 18),
      Text('lessons.link.footer'.tr(), style: tBody(14, color: TC.muted)),
    ]);
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, required this.lang});
  final PreacherLinkLesson lesson;
  final String lang;
  @override
  Widget build(BuildContext context) {
    final l = lesson;
    final (TTone tone, String label) = switch (l.status) {
      'approved' => (TTone.success, 'lessons.link.s_approved'.tr()),
      'pending' => (TTone.warning, 'lessons.link.s_pending'.tr()),
      'rejected' => (TTone.danger, 'lessons.link.s_rejected'.tr()),
      'cancelled' => (TTone.slate, 'lessons.link.s_cancelled'.tr()),
      _ => (TTone.slate, l.status),
    };
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(l.title(lang), style: tStrong(18))),
          TTag(label, tone: tone),
        ]),
        const SizedBox(height: 6),
        Text('${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)} · ${hijriLabel(l.date, lang)}', style: tBody(16, color: TC.ink)),
        Text(l.exactTime ?? slotLabel(l.slot), style: tBody(16, color: TC.ink2)),
        Text(l.mosque(lang).isEmpty ? 'lessons.link.mosque_later'.tr() : l.mosque(lang), style: tBody(16, color: TC.ink2)),
        if (l.seq != null) Text('lessons.lesson.session'.tr(args: ['${l.seq}']), style: tBody(14, color: TC.muted)),
        if (l.status == 'rejected' && (l.rejectionReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          TCallout(tone: TTone.danger, icon: TGlyph.info, child: Text('${'lessons.mine.reason'.tr()} ${l.rejectionReason}', style: tBody(15))),
        ],
        if (l.status == 'cancelled' && (l.cancelReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(l.cancelReason!, style: tBody(15, color: TC.muted)),
        ],
        if (l.status == 'pending' && l.source == 'preacher' && (l.seq ?? 1) == 1) ...[
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TButton('lessons.link.withdraw'.tr(), kind: TBtn.ghost, icon: TGlyph.x, onPressed: () async {
              final s = context.read<PreacherLinkController>();
              await tRun(context, () => s.withdraw(l.requestId), success: 'lessons.link.withdrawn'.tr());
            }),
          ),
        ],
      ]),
    );
  }
}

// --------------------------------------------------------------- request
Future<void> _showRequestSheet(BuildContext context, PreacherLinkView view) {
  final s = context.read<PreacherLinkController>();
  final lang = context.lang;
  final today = lessonsToday();
  var type = 'lesson', topic = 'aqeedah', slot = 'isha', audience = 'all';
  var language = view.preacher.languages.firstOrNull ?? 'ar';
  var date = addDays(today, 3);
  var weekly = false;
  var count = 4;
  final title = TextEditingController(), note = TextEditingController();
  List<DateTime> dates() => weekly ? seriesDates(date, {date.weekday}, count) : [date];
  Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(t, style: tStrong(17)));
  return showTModal<void>(context,
      title: 'lessons.link.request'.tr(),
      subtitle: 'lessons.link.request_sub'.tr(),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              label('lessons.link.q_type'.tr()),
              for (final t in LessonsVocab.types)
                TOptionRow(title: typeLabel(t), subtitle: 'lessons.type_desc.$t'.tr(), leading: typeGlyph(t), selected: type == t, onTap: () => set(() => type = t)),
              label('lessons.link.q_title'.tr()),
              TextField(
                key: const ValueKey('link-request-title'),
                controller: title,
                style: tBody(17, color: TC.ink),
                maxLength: 160,
                decoration: tInput(hint: 'lessons.submit.title_ar_hint'.tr()),
              ),
              label('lessons.link.q_topic'.tr()),
              TChips([for (final t in LessonsVocab.topics) TChip(topicLabel(t), selected: topic == t, onTap: () => set(() => topic = t))]),
              label('lessons.link.q_date'.tr()),
              TButton('${weekdayName(date, lang)} ${gregorianLabel(date, lang, year: true)}', large: true, expand: true, icon: TGlyph.calendar,
                  onPressed: () async {
                final p = await showDatePicker(context: ctx, initialDate: date, firstDate: today, lastDate: addDays(today, 180));
                if (p != null) set(() => date = dateOnly(p));
              }),
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(hijriLabel(date, lang), style: tBody(15, color: TC.muted))),
              TToggleRow(
                  label: 'lessons.link.weekly'.tr(),
                  desc: 'lessons.link.weekly_desc'.tr(args: [weekdayName(date, lang)]),
                  icon: TGlyph.repeat,
                  value: weekly,
                  onChanged: (v) => set(() => weekly = v)),
              if (weekly)
                Row(children: [
                  Expanded(child: Text('lessons.link.how_many'.tr(), style: tBody(16, color: TC.ink))),
                  TIconButton(TGlyph.minus, tooltip: '-', onPressed: () => set(() => count = (count - 1).clamp(2, 12))),
                  SizedBox(width: 40, child: Text('$count', textAlign: TextAlign.center, style: tStrong(18))),
                  TIconButton(TGlyph.plus, tooltip: '+', onPressed: () => set(() => count = (count + 1).clamp(2, 12))),
                ]),
              label('lessons.link.q_time'.tr()),
              for (final x in LessonsVocab.slots)
                TOptionRow(title: slotLabel(x), leading: slotGlyph(x), selected: slot == x, onTap: () => set(() => slot = x)),
              label('lessons.link.q_language'.tr()),
              TChips([
                for (final x in LessonsVocab.languages)
                  TChip(LessonsVocab.languageNative[x]!, selected: language == x, onTap: () => set(() => language = x)),
              ]),
              label('lessons.link.q_audience'.tr()),
              TChips([for (final a in LessonsVocab.audiences) TChip(audienceLabel(a), selected: audience == a, onTap: () => set(() => audience = a))]),
              label('lessons.link.q_note'.tr()),
              TextField(
                controller: note,
                maxLines: 3,
                maxLength: 600,
                style: tBody(16, color: TC.ink),
                decoration: tInput(hint: 'lessons.link.note_hint'.tr()),
              ),
              TCallout(tone: TTone.info, icon: TGlyph.mosque, child: Text('lessons.link.mosque_note'.tr(), style: tBody(15))),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.link.send'.tr(), key: const ValueKey('link-request-send'), kind: TBtn.minted, large: true, icon: TGlyph.send, onPressed: () async {
              if (title.text.trim().length < 3) {
                tToast(ctx, 'lessons.link.title_needed'.tr(), warn: true);
                return;
              }
              final draft = LessonRequestDraft(
                  type: type, topic: topic, titleAr: title.text.trim(), language: language, audience: audience, slot: slot,
                  dates: dates(), note: note.text.trim());
              final r = await tRun(ctx, () => s.requestLesson(draft));
              if (r == null || !ctx.mounted) return;
              Navigator.of(ctx).pop();
              if (context.mounted) tToast(context, 'lessons.link.sent'.tr());
            }),
          ]);
}

// ------------------------------------------------------------------ card
Future<void> _showCardSheet(BuildContext context, PreacherLinkView view) {
  final s = context.read<PreacherLinkController>();
  final p = view.preacher;
  final pending = view.pendingEdit ?? const <String, dynamic>{};
  String start(String field, String now) => pending[field] as String? ?? now;
  final nameAr = TextEditingController(text: start('name_ar', p.nameAr)), titleAr = TextEditingController(text: start('title_ar', p.titleAr));
  final bioAr = TextEditingController(text: start('bio_ar', p.bioAr));
  final nameEn = TextEditingController(text: start('name_en', p.nameEn)), titleEn = TextEditingController(text: start('title_en', p.titleEn));
  final bioEn = TextEditingController(text: start('bio_en', p.bioEn));
  final langs = {...((pending['languages'] as List?)?.cast<String>() ?? p.languages)};
  var english = nameEn.text.isNotEmpty || titleEn.text.isNotEmpty || bioEn.text.isNotEmpty;
  Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(t, style: tStrong(17)));
  return showTModal<void>(context,
      title: 'lessons.link.edit_card'.tr(),
      subtitle: 'lessons.link.edit_sub'.tr(),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              label('lessons.link.f_name'.tr()),
              TextField(controller: nameAr, style: tBody(17, color: TC.ink), maxLength: 120, decoration: tInput()),
              label('lessons.link.f_title'.tr()),
              TextField(controller: titleAr, style: tBody(17, color: TC.ink), maxLength: 120, decoration: tInput(hint: 'lessons.roster.title_hint'.tr())),
              label('lessons.link.f_bio'.tr()),
              TextField(controller: bioAr, maxLines: 4, maxLength: 1500, style: tBody(16, color: TC.ink), decoration: tInput(hint: 'lessons.link.bio_hint'.tr())),
              label('lessons.link.f_languages'.tr()),
              TChips([
                for (final x in LessonsVocab.languages)
                  TChip(LessonsVocab.languageNative[x]!, selected: langs.contains(x),
                      onTap: () => set(() => langs.contains(x) && langs.length > 1 ? langs.remove(x) : langs.add(x))),
              ]),
              TToggleRow(label: 'lessons.link.english'.tr(), icon: TGlyph.globe, value: english, onChanged: (v) => set(() => english = v)),
              if (english) ...[
                label('lessons.roster.name_en'.tr()),
                TextField(controller: nameEn, textDirection: TextDirection.ltr, maxLength: 120, decoration: tInput()),
                label('lessons.roster.title_en'.tr()),
                TextField(controller: titleEn, textDirection: TextDirection.ltr, maxLength: 120, decoration: tInput()),
                label('lessons.roster.bio_en'.tr()),
                TextField(controller: bioEn, textDirection: TextDirection.ltr, maxLines: 4, maxLength: 1500, decoration: tInput()),
              ],
              TCallout(tone: TTone.info, icon: TGlyph.shield, child: Text('lessons.link.edit_note'.tr(), style: tBody(15))),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.link.send_edit'.tr(), kind: TBtn.minted, large: true, icon: TGlyph.send, onPressed: () async {
              if (nameAr.text.trim().length < 3) {
                tToast(ctx, 'lessons.preacher_admin.name_needed'.tr(), warn: true);
                return;
              }
              final changes = <String, dynamic>{
                'name_ar': nameAr.text.trim(),
                'title_ar': titleAr.text.trim(),
                'bio_ar': bioAr.text.trim(),
                'name_en': nameEn.text.trim(),
                'title_en': titleEn.text.trim(),
                'bio_en': bioEn.text.trim(),
                'languages': langs.toList(),
              };
              final done = await tRun(ctx, () async {
                await s.proposeCardEdit(changes);
                return true;
              });
              if (done != true || !ctx.mounted) return;
              Navigator.of(ctx).pop();
              if (context.mounted) tToast(context, 'lessons.link.edit_sent'.tr());
            }),
          ]);
}
