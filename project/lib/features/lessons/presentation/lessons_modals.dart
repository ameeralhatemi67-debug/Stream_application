import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_identity.dart';
import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import '../domain/lessons_rules.dart';
import '../domain/lessons_vocab.dart';
import '../state/lessons_controller.dart';
import 'lessons_kit.dart';
import 'lessons_map.dart';
import 'lessons_widgets.dart';

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
              Text('${'lessons.programme'.tr()} · ${c.catalog.organizations[l.organizationId]?.name(lang) ?? ''}',
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

// --------------------------------------------------------- coordinator edit
Future<void> showEditLessonSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final titleAr = TextEditingController(text: l.titleAr), titleEn = TextEditingController(text: l.titleEn);
  var date = l.date;
  var slot = l.slot;
  var mosqueId = l.mosqueId;
  return showTModal<void>(context,
      title: 'lessons.lesson.edit'.tr(),
      subtitle: l.title(lang),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'lessons.submit.title_ar'.tr(), required: true, child: TextField(controller: titleAr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.submit.title_en'.tr(), child: TextField(controller: titleEn, decoration: tInput())),
              const SizedBox(height: 12),
              TField(
                label: 'lessons.lesson.place'.tr(),
                child: DropdownButtonFormField<String>(
                  initialValue: mosqueId,
                  isExpanded: true,
                  decoration: tInput(),
                  items: [for (final m in c.verifiedMosques) DropdownMenuItem(value: m.id, child: Text(m.name(lang), overflow: TextOverflow.ellipsis))],
                  onChanged: (v) => set(() => mosqueId = v ?? mosqueId),
                ),
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
                        'mosque_id': mosqueId,
                        'lesson_date': isoDate(date),
                        'slot': slot,
                      }),
                  success: 'lessons.roster.saved'.tr());
            }),
          ]);
}

// ----------------------------------------------------------------- invite
Future<void> showInviteSheet(BuildContext context, Preacher p) async {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final token = await tRun(context, () => c.createInvite(p.id));
  if (token == null || !context.mounted) return;
  final org = c.catalog.organizations[p.organizationId]?.name(lang) ?? 'lessons.programme'.tr();
  final link = lessonsLink('/lessons/claim/$token');
  final msg = 'lessons.roster.invite_msg'.tr(args: [p.name(lang), org, link]);
  await showTModal<void>(context,
      title: 'lessons.roster.invite_title'.tr(),
      subtitle: p.name(lang),
      body: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TCallout(tone: TTone.info, icon: TGlyph.lock, child: Text('lessons.roster.invite_note'.tr())),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: TC.page, borderRadius: BorderRadius.circular(TC.r), border: Border.all(color: TC.hair)),
              child: SelectableText(msg, style: tBody(13.5, color: TC.ink, height: 1.7)),
            ),
          ]),
      footer: (ctx) => [
            TButton('lessons.roster.copy_msg'.tr(), icon: TGlyph.copy, onPressed: () => copyToClipboard(context, msg)),
            TButton('lessons.roster.whatsapp'.tr(), kind: TBtn.minted, icon: TGlyph.whatsapp,
                onPressed: () => openExternal(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'))),
          ]);
}

// ---------------------------------------------------------- preacher edit
Future<void> showPreacherEditSheet(BuildContext context, String organizationId, {LessonsRosterEntry? entry}) {
  final c = context.read<LessonsController>();
  final p = entry?.preacher;
  final nameAr = TextEditingController(text: p?.nameAr ?? ''), nameEn = TextEditingController(text: p?.nameEn ?? '');
  final titleAr = TextEditingController(text: p?.titleAr ?? ''), phone = TextEditingController();
  var city = p?.city ?? 'khobar', aff = p?.affiliation ?? 'coop';
  var langs = {...?p?.languages};
  if (langs.isEmpty) langs = {'ar'};
  return showTModal<void>(context,
      title: p == null ? 'lessons.roster.add_title'.tr() : 'lessons.roster.edit_title'.tr(),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'lessons.roster.name_ar'.tr(), required: true, child: TextField(controller: nameAr, textDirection: TextDirection.rtl, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.roster.name_en'.tr(), child: TextField(controller: nameEn, textDirection: TextDirection.ltr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.roster.title_ar'.tr(), child: TextField(controller: titleAr, decoration: tInput(hint: 'lessons.roster.title_hint'.tr()))),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: 220,
                  child: TField(
                    label: 'lessons.roster.city'.tr(),
                    child: DropdownButtonFormField<String>(
                      initialValue: city,
                      decoration: tInput(),
                      items: [for (final x in LessonsVocab.cities) DropdownMenuItem(value: x, child: Text(cityLabel(x)))],
                      onChanged: (v) => set(() => city = v ?? city),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TField(
                    label: 'lessons.roster.affiliation'.tr(),
                    child: DropdownButtonFormField<String>(
                      initialValue: aff,
                      decoration: tInput(),
                      items: [for (final x in LessonsVocab.affiliations) DropdownMenuItem(value: x, child: Text('lessons.affiliation.$x'.tr()))],
                      onChanged: (v) => set(() => aff = v ?? aff),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TField(
                  label: 'lessons.roster.phone'.tr(),
                  hint: 'lessons.roster.phone_hint'.tr(),
                  child: TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: tInput(hint: entry?.phoneMask ?? '05XXXXXXXX'))),
              const SizedBox(height: 12),
              Text('lessons.roster.languages'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              TChips([
                for (final x in LessonsVocab.languages)
                  TChip(LessonsVocab.languageNative[x]!, small: true, selected: langs.contains(x),
                      onTap: () => set(() => langs.contains(x) && langs.length > 1 ? langs.remove(x) : langs.add(x))),
              ]),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.save'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              if (nameAr.text.trim().length < 3) return;
              Navigator.of(ctx).pop();
              await tRun(context,
                  () => c.upsertPreacher({
                        if (p != null) 'id': p.id,
                        'organization_id': organizationId,
                        'name_ar': nameAr.text.trim(),
                        'name_en': nameEn.text.trim(),
                        'title_ar': titleAr.text.trim(),
                        'city': city,
                        'affiliation': aff,
                        'languages': langs.toList(),
                        if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
                      }),
                  success: p == null ? 'lessons.roster.added'.tr() : 'lessons.roster.saved'.tr());
              await c.openConsole(organizationId);
            }),
          ]);
}

/// Parses "name,mobile,city,affiliation" CSV (header row skipped).
List<Map<String, dynamic>> parsePreacherCsv(String text) {
  String cityOf(String s) {
    final t = s.trim().toLowerCase();
    const map = {'الخبر': 'khobar', 'الظهران': 'dhahran', 'الدمام': 'dammam', 'القطيف': 'qatif'};
    if (map.containsKey(s.trim())) return map[s.trim()]!;
    for (final c in LessonsVocab.cities) {
      if (t.contains(c)) return c;
    }
    return 'khobar';
  }

  final lines = text.split(RegExp(r'\r?\n')).skip(1);
  return [
    for (final line in lines)
      if (line.trim().isNotEmpty)
        () {
          final cells = line.split(',');
          return {
            'name': cells[0].trim(),
            'phone': cells.length > 1 ? cells[1].trim() : '',
            'city': cityOf(cells.length > 2 ? cells[2] : ''),
            'affiliation': RegExp('وزار|minist', caseSensitive: false).hasMatch(cells.length > 3 ? cells[3] : '') ? 'ministry' : 'coop',
          };
        }()
  ].where((r) => (r['name'] as String).length >= 3).toList();
}

Future<void> showImportSheet(BuildContext context, String organizationId) {
  final c = context.read<LessonsController>();
  final text = TextEditingController(text: 'الاسم,الجوال,المدينة,الصفة\n');
  return showTModal<void>(context,
      title: 'lessons.roster.import_title'.tr(),
      subtitle: 'lessons.roster.import_sub'.tr(),
      wide: true,
      body: (ctx) => StatefulBuilder(builder: (ctx, set) {
            final rows = parsePreacherCsv(text.text);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(
                  label: 'lessons.roster.paste'.tr(),
                  child: TextField(controller: text, maxLines: 6, onChanged: (_) => set(() {}), decoration: tInput())),
              const SizedBox(height: 12),
              for (final r in rows.take(30))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${r['name']} · ${r['phone']} · ${cityLabel(r['city'] as String)} · ${'lessons.affiliation.${r['affiliation']}'.tr()}',
                      style: tBody(13, color: TC.ink2)),
                ),
              const SizedBox(height: 8),
              Text('lessons.roster.import_note'.tr(), style: tBody(13, color: TC.muted)),
            ]);
          }),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.roster.import'.tr(), kind: TBtn.minted, icon: TGlyph.upload, onPressed: () async {
              final rows = parsePreacherCsv(text.text);
              if (rows.isEmpty) return;
              Navigator.of(ctx).pop();
              final n = await tRun(context, () => c.importPreachers(organizationId, rows));
              if (n != null && context.mounted) {
                tToast(context, 'lessons.roster.imported'.tr(args: [tPlural('preachers', n)]));
                await c.openConsole(organizationId);
              }
            }),
          ]);
}

// ------------------------------------------------------------- add mosque
Future<void> showAddMosqueSheet(BuildContext context) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final nameAr = TextEditingController(), nameEn = TextEditingController();
  var district = c.catalog.districts.keys.firstOrNull ?? 'aqrabiyah';
  final fac = <String>{'parking'};
  (double, double)? pin;
  return showTModal<void>(context,
      title: 'lessons.mosques.add_title'.tr(),
      wide: true,
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'lessons.mosques.name_ar'.tr(), required: true, child: TextField(controller: nameAr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.mosques.name_en'.tr(), child: TextField(controller: nameEn, decoration: tInput())),
              const SizedBox(height: 12),
              TField(
                label: 'lessons.mosques.district'.tr(),
                child: DropdownButtonFormField<String>(
                  initialValue: district,
                  isExpanded: true,
                  decoration: tInput(),
                  items: [
                    for (final d in c.catalog.districts.values)
                      DropdownMenuItem(value: d.id, child: Text('${d.name(lang)} · ${cityLabel(d.city)}'))
                  ],
                  onChanged: (v) => set(() => district = v ?? district),
                ),
              ),
              const SizedBox(height: 12),
              Text('lessons.mosques.facilities'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              TChips([
                for (final f in LessonsVocab.facilities)
                  TChip(facilityLabel(f), small: true, icon: facilityGlyph(f), selected: fac.contains(f),
                      onTap: () => set(() => fac.contains(f) ? fac.remove(f) : fac.add(f))),
              ]),
              const SizedBox(height: 12),
              Text('lessons.mosques.pin'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              SizedBox(height: 260, child: MosquePinPicker(value: pin, onPick: (p) => set(() => pin = p))),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.mosques.add'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              if (nameAr.text.trim().length < 2) return;
              Navigator.of(ctx).pop();
              await tRun(context,
                  () => c.upsertMosque({
                        'name_ar': nameAr.text.trim(),
                        'name_en': nameEn.text.trim(),
                        'district_id': district,
                        if (pin != null) 'latitude': pin!.$1,
                        if (pin != null) 'longitude': pin!.$2,
                        'facilities': fac.toList(),
                      }),
                  success: 'lessons.mosques.added'.tr());
            }),
          ]);
}
