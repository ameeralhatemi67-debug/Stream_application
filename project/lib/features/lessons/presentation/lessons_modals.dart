import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_identity.dart';
import '../../../core/providers/app_provider.dart';
import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import '../domain/lessons_rules.dart';
import '../domain/lessons_vocab.dart';
import '../state/lessons_controller.dart';
import 'lessons_kit.dart';
import 'lessons_widgets.dart';
import 'preacher_form_kit.dart';

/// Public link to a Lessons page on the website.
String lessonsLink(String path) => '${AppIdentity.websiteUrl}/#$path';

Future<void> openExternal(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

// ----------------------------------------------------------------- remind
Future<void> showRemindSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final pt = prayerTimesFor(l.date, c.mosque(l.mosqueId), c.catalog.districts);
  final current = c.reminderLead(l.id);
  Future<void> set(BuildContext ctx, String? lead) async {
    Navigator.of(ctx).pop();
    await tRun(context, () => c.setReminder(l, lead), success: lead == null ? 'lessons.remind.removed'.tr() : 'lessons.remind.saved'.tr());
    // The reminder also arrives by push: ask for it, as channel reminders do.
    if (lead != null && context.mounted && c.hasReminder(l.id)) {
      final app = context.read<AppProvider>();
      if (app.remindersAvailable && app.currentUserId != null) {
        unawaited(app.syncReminderPush(requestPermission: true, language: lang));
      }
    }
  }

  String detail(String lead) => switch (lead) {
        'adhan' => 'lessons.remind.adhan_detail'.tr(args: [prayerLabel(l.slot), clockLabel(pt.of(l.slot), lang)]),
        '30' => '≈ ${clockLabel(c.startHours(l) - .5, lang)}',
        _ => weekdayName(addDays(l.date, -1), lang),
      };
  return showTModal<void>(context,
      title: 'lessons.remind.title'.tr(),
      subtitle: l.title(lang),
      body: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final lead in LessonsVocab.leads)
              TOptionRow(
                title: 'lessons.lead.$lead'.tr(),
                subtitle: detail(lead),
                selected: current == lead,
                leading: lead == 'adhan' ? slotGlyph(l.slot) : lead == 'day' ? TGlyph.calendar : TGlyph.clock,
                onTap: () => set(ctx, lead),
              ),
            if (current != null)
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TButton('lessons.remind.remove'.tr(), kind: TBtn.ghost, icon: TGlyph.x, onPressed: () => set(ctx, null))),
            const SizedBox(height: 6),
            Text('lessons.remind.note'.tr(), style: tBody(13, color: TC.muted)),
          ]));
}

// ------------------------------------------------------------------ share
String lessonShareText(LessonsController c, Lesson l, String lang) {
  final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId), d = c.district(m?.districtId);
  return [
    l.title(lang),
    p?.name(lang) ?? '',
    '${m?.name(lang) ?? ''}${d == null ? '' : ' — ${d.name(lang)}'}',
    '${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)} (${hijriLabel(l.date, lang)})',
    whenOf(c, l, lang, withDate: false),
    lessonsLink('/lessons/lesson/${l.id}'),
  ].where((s) => s.isNotEmpty).join('\n');
}

Future<void> showShareSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId), d = c.district(m?.districtId);
  final text = lessonShareText(c, l, lang);
  Widget cell(String k, String a, String b) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: tBody(11.5, color: TC.onNightGold, weight: FontWeight.w700)),
          Text(a, style: tStrong(13.5, color: TC.onNight)),
          Text(b, style: tBody(12, color: TC.onNight2, height: 1.4)),
        ]),
      );
  return showTModal<void>(context,
      title: 'lessons.share.title'.tr(),
      subtitle: 'lessons.share.sub'.tr(),
      body: (ctx) => TNight(
            radius: BorderRadius.circular(TC.rLg),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('lessons.programme'.tr(),
                  style: tBody(12.5, color: TC.onNightGold, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('${typeLabel(l.type)}${l.seq != null ? ' · ${'lessons.lesson.session'.tr(args: ['${l.seq}'])}' : ''}',
                  style: tBody(12.5, color: TC.onNight2)),
              Text(l.title(lang), style: tDisplay(24, color: TC.onNight)),
              Text(p?.name(lang) ?? '', style: tBody(14, color: TC.onNightGold, weight: FontWeight.w600)),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                cell('lessons.share.when'.tr(), '${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)}', hijriLabel(l.date, lang)),
                const SizedBox(width: 10),
                cell('lessons.share.time'.tr(), slotLabel(l.slot), '≈ ${clockLabel(c.startHours(l), lang)}'),
                const SizedBox(width: 10),
                cell('lessons.share.where'.tr(), m?.name(lang) ?? '', d == null ? '' : '${d.name(lang)} · ${cityLabel(d.city)}'),
              ]),
              const SizedBox(height: 14),
              Text('lessons.share.link_hint'.tr(), style: tBody(12, color: TC.onNight2)),
              SelectableText(lessonsLink('/lessons/lesson/${l.id}'), style: tBody(12, color: TC.onNightGold)),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.share.copy'.tr(), icon: TGlyph.copy, onPressed: () => copyToClipboard(context, text)),
            TButton('lessons.lesson.share'.tr(), icon: TGlyph.share, onPressed: () => Share.share(text)),
            TButton('lessons.share.whatsapp'.tr(), kind: TBtn.minted, icon: TGlyph.whatsapp,
                onPressed: () => openExternal(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'))),
          ]);
}

/// Google Calendar template link for a lesson (Saudi time is UTC+3).
Uri calendarLink(LessonsController c, Lesson l, String lang) {
  final start = lessonStartInstant(l, c.catalog), end = start.add(const Duration(hours: 1));
  String f(DateTime t) => '${t.toUtc().toIso8601String().replaceAll(RegExp(r'[-:]'), '').split('.').first}Z';
  final m = c.mosque(l.mosqueId), d = c.district(m?.districtId);
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': l.title(lang),
    'dates': '${f(start)}/${f(end)}',
    'details': '${c.preacher(l.preacherId)?.name(lang) ?? ''} — ${slotLabel(l.slot)}',
    'location': [m?.name(lang), d?.name(lang), if (d != null) cityLabel(d.city)].whereType<String>().join(', '),
  });
}

// ------------------------------------------------------------------- flag
Future<void> showFlagSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  var kind = 'time';
  final msg = TextEditingController();
  return showTModal<void>(context,
      title: 'lessons.flag.title'.tr(),
      subtitle: l.title(context.lang),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TChips([
                for (final k in LessonsVocab.flagKinds)
                  TChip('lessons.flag_kind.$k'.tr(), selected: kind == k, onTap: () => set(() => kind = k)),
              ]),
              const SizedBox(height: 14),
              TField(
                  label: '${'lessons.flag.details'.tr()} (${'lessons.optional'.tr()})',
                  child: TextField(controller: msg, maxLines: 3, maxLength: 1000, decoration: tInput(hint: 'lessons.flag.hint'.tr()))),
              Text('lessons.flag.note'.tr(), style: tBody(13, color: TC.muted)),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.flag.send'.tr(), kind: TBtn.minted, icon: TGlyph.send, onPressed: () async {
              Navigator.of(ctx).pop();
              await tRun(context, () => c.flag(l.id, kind, msg.text.trim()), success: 'lessons.flag.sent'.tr());
            }),
          ]);
}

// ----------------------------------------------------------------- cancel
Future<void> showCancelSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  var why = 'travel';
  final msg = TextEditingController();
  return showTModal<void>(context,
      title: 'lessons.cxl.title'.tr(),
      subtitle: '${l.title(context.lang)} — ${gregorianLabel(l.date, context.lang)}',
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TChips([
                for (final r in LessonsVocab.cancelReasons)
                  TChip('lessons.cancel_reason.$r'.tr(), selected: why == r, onTap: () => set(() => why = r)),
              ]),
              const SizedBox(height: 14),
              TField(
                  label: '${'lessons.cxl.message'.tr()} (${'lessons.optional'.tr()})',
                  child: TextField(controller: msg, maxLength: 300, decoration: tInput())),
              TCallout(tone: TTone.info, icon: TGlyph.bell, child: Text('lessons.cxl.notify'.tr())),
              if (l.seriesId != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('lessons.cxl.series_note'.tr(), style: tBody(13, color: TC.muted))),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cxl.keep'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.cxl.confirm'.tr(), kind: TBtn.danger, icon: TGlyph.x, onPressed: () async {
              Navigator.of(ctx).pop();
              final reason = msg.text.trim().isEmpty ? 'lessons.cancel_reason.$why'.tr() : msg.text.trim();
              final n = await tRun(context, () => c.cancelLesson(l.id, reason));
              if (n != null && context.mounted) tToast(context, 'lessons.cxl.done'.tr(args: [tPlural('people', n)]));
            }),
          ]);
}

// ----------------------------------------------------------------- reject
Future<bool?> showRejectSheet(BuildContext context, List<String> requestIds) {
  final c = context.read<LessonsController>();
  var reason = 'clash';
  final more = TextEditingController();
  return showTModal<bool>(context,
      title: 'lessons.review.reject_title'.tr(),
      subtitle: '${'lessons.review.reject_sub'.tr()} ${tPlural('requests', requestIds.length)}',
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final r in LessonsVocab.rejectReasons)
                TOptionRow(title: 'lessons.reject_reason.$r'.tr(), selected: reason == r, onTap: () => set(() => reason = r)),
              const SizedBox(height: 6),
              TField(
                  label: '${'lessons.review.suggestion'.tr()} (${'lessons.optional'.tr()})',
                  child: TextField(controller: more, maxLength: 400, decoration: tInput(hint: 'lessons.review.suggestion_hint'.tr()))),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.back'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop(false)),
            TButton('lessons.review.reject_sel'.tr(), kind: TBtn.danger, icon: TGlyph.x, onPressed: () async {
              final base = 'lessons.reject_reason.$reason'.tr();
              final text = more.text.trim().isEmpty ? base : '$base. ${more.text.trim()}';
              Navigator.of(ctx).pop(true);
              final n = await tRun(context, () => c.review(requestIds, 'reject', reason: text));
              if (n != null && context.mounted) {
                tToast(context, 'lessons.review.rejected'.tr(args: [tPlural('requests', n)]),
                    actionLabel: 'lessons.review.undo'.tr(),
                    onAction: () => tRun(context, () => c.undoReview(requestIds), success: 'lessons.review.undone'.tr()));
              }
            }),
          ]);
}

// -------------------------------------------------------------- admin edit
Future<void> showEditLessonSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final titleAr = TextEditingController(text: l.titleAr), titleEn = TextEditingController(text: l.titleEn);
  var date = l.date;
  var slot = l.slot;
  String? mosqueId = l.hasMosque ? l.mosqueId : null;
  var city = cityOr(c, mosqueId, c.preacher(l.preacherId)?.city ?? 'khobar');
  return showTModal<void>(context,
      title: 'lessons.lesson.edit'.tr(),
      subtitle: l.title(lang),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'lessons.submit.title_ar'.tr(), required: true, child: TextField(controller: titleAr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.submit.title_en'.tr(), child: TextField(controller: titleEn, decoration: tInput())),
              const SizedBox(height: 12),
              CityMosquePicker(
                city: city,
                mosqueId: mosqueId,
                hidden: true,
                mosqueLabel: 'lessons.lesson.place'.tr(),
                onChanged: (ci, m) => set(() {
                  city = ci;
                  mosqueId = m ?? mosqueId;
                }),
              ),
              const SizedBox(height: 12),
              TField(
                label: 'lessons.lesson.date'.tr(),
                hint: hijriLabel(date, lang),
                child: TButton('${weekdayName(date, lang)} ${gregorianLabel(date, lang, year: true)}', icon: TGlyph.calendar, onPressed: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: c.today, lastDate: addDays(c.today, 365));
                  if (picked != null) set(() => date = dateOnly(picked));
                }),
              ),
              const SizedBox(height: 12),
              TChips([for (final s in LessonsVocab.slots) TChip(slotLabel(s), small: true, icon: slotGlyph(s), selected: slot == s, onTap: () => set(() => slot = s))]),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.save'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              Navigator.of(ctx).pop();
              await tRun(context,
                  () => c.editLesson(l.id, {
                        'title_ar': titleAr.text.trim(),
                        'title_en': titleEn.text.trim(),
                        if (mosqueId != null) 'mosque_id': mosqueId,
                        'lesson_date': isoDate(date),
                        'slot': slot,
                      }),
                  success: 'lessons.roster.saved'.tr());
            }),
          ]);
}
