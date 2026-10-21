import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_identity.dart';
import '../domain/taysir_dates.dart';
import '../domain/taysir_models.dart';
import '../domain/taysir_rules.dart';
import '../domain/taysir_vocab.dart';
import '../state/taysir_controller.dart';
import 'taysir_kit.dart';
import 'taysir_map.dart';
import 'taysir_widgets.dart';

/// Public link to a Taysir page on the website.
String taysirLink(String path) => '${AppIdentity.websiteUrl}/#$path';

Future<void> openExternal(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

// ----------------------------------------------------------------- remind
Future<void> showRemindSheet(BuildContext context, TaysirLesson l) {
  final c = context.read<TaysirController>();
  final lang = context.lang;
  final pt = prayerTimesFor(l.date, c.mosque(l.mosqueId), c.catalog.districts);
  final current = c.reminderLead(l.id);
  Future<void> set(BuildContext ctx, String? lead) async {
    Navigator.of(ctx).pop();
    await tRun(context, () => c.setReminder(l, lead), success: lead == null ? 'taysir.remind.removed'.tr() : 'taysir.remind.saved'.tr());
  }

  String detail(String lead) => switch (lead) {
        'adhan' => 'taysir.remind.adhan_detail'.tr(args: [prayerLabel(l.slot), clockLabel(pt.of(l.slot), lang)]),
        '30' => '≈ ${clockLabel(c.startHours(l) - .5, lang)}',
        _ => weekdayName(addDays(l.date, -1), lang),
      };
  return showTModal<void>(context,
      title: 'taysir.remind.title'.tr(),
      subtitle: l.title(lang),
      body: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final lead in TaysirVocab.leads)
              TOptionRow(
                title: 'taysir.lead.$lead'.tr(),
                subtitle: detail(lead),
                selected: current == lead,
                leading: lead == 'adhan' ? slotGlyph(l.slot) : lead == 'day' ? TGlyph.calendar : TGlyph.clock,
                onTap: () => set(ctx, lead),
              ),
            if (current != null)
              Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TButton('taysir.remind.remove'.tr(), kind: TBtn.ghost, icon: TGlyph.x, onPressed: () => set(ctx, null))),
            const SizedBox(height: 6),
            Text('taysir.remind.note'.tr(), style: tBody(13, color: TC.muted)),
          ]));
}

// ------------------------------------------------------------------ share
String lessonShareText(TaysirController c, TaysirLesson l, String lang) {
  final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId), d = c.district(m?.districtId);
  return [
    l.title(lang),
    p?.name(lang) ?? '',
    '${m?.name(lang) ?? ''}${d == null ? '' : ' — ${d.name(lang)}'}',
    '${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)} (${hijriLabel(l.date, lang)})',
    whenOf(c, l, lang, withDate: false),
    taysirLink('/taysir/lessons/${l.id}'),
  ].where((s) => s.isNotEmpty).join('\n');
}

Future<void> showShareSheet(BuildContext context, TaysirLesson l) {
  final c = context.read<TaysirController>();
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
      title: 'taysir.share.title'.tr(),
      subtitle: 'taysir.share.sub'.tr(),
      body: (ctx) => TNight(
            radius: BorderRadius.circular(TC.rLg),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${'taysir.programme'.tr()} · ${c.catalog.organizations[l.organizationId]?.name(lang) ?? ''}',
                  style: tBody(12.5, color: TC.onNightGold, weight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text('${typeLabel(l.type)}${l.seq != null ? ' · ${'taysir.lesson.session'.tr(args: ['${l.seq}'])}' : ''}',
                  style: tBody(12.5, color: TC.onNight2)),
              Text(l.title(lang), style: tDisplay(24, color: TC.onNight)),
              Text(p?.name(lang) ?? '', style: tBody(14, color: TC.onNightGold, weight: FontWeight.w600)),
              const SizedBox(height: 14),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                cell('taysir.share.when'.tr(), '${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)}', hijriLabel(l.date, lang)),
                const SizedBox(width: 10),
                cell('taysir.share.time'.tr(), slotLabel(l.slot), '≈ ${clockLabel(c.startHours(l), lang)}'),
                const SizedBox(width: 10),
                cell('taysir.share.where'.tr(), m?.name(lang) ?? '', d == null ? '' : '${d.name(lang)} · ${cityLabel(d.city)}'),
              ]),
              const SizedBox(height: 14),
              Text('taysir.share.link_hint'.tr(), style: tBody(12, color: TC.onNight2)),
              SelectableText(taysirLink('/taysir/lessons/${l.id}'), style: tBody(12, color: TC.onNightGold)),
            ]),
          ),
      footer: (ctx) => [
            TButton('taysir.share.copy'.tr(), icon: TGlyph.copy, onPressed: () => copyToClipboard(context, text)),
            TButton('taysir.lesson.share'.tr(), icon: TGlyph.share, onPressed: () => Share.share(text)),
            TButton('taysir.share.whatsapp'.tr(), kind: TBtn.minted, icon: TGlyph.whatsapp,
                onPressed: () => openExternal(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}'))),
          ]);
}

/// Google Calendar template link for a lesson (Saudi time is UTC+3).
Uri calendarLink(TaysirController c, TaysirLesson l, String lang) {
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
Future<void> showFlagSheet(BuildContext context, TaysirLesson l) {
  final c = context.read<TaysirController>();
  var kind = 'time';
  final msg = TextEditingController();
  return showTModal<void>(context,
      title: 'taysir.flag.title'.tr(),
      subtitle: l.title(context.lang),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TChips([
                for (final k in TaysirVocab.flagKinds)
                  TChip('taysir.flag_kind.$k'.tr(), selected: kind == k, onTap: () => set(() => kind = k)),
              ]),
              const SizedBox(height: 14),
              TField(
                  label: '${'taysir.flag.details'.tr()} (${'taysir.optional'.tr()})',
                  child: TextField(controller: msg, maxLines: 3, maxLength: 1000, decoration: tInput(hint: 'taysir.flag.hint'.tr()))),
              Text('taysir.flag.note'.tr(), style: tBody(13, color: TC.muted)),
            ]),
          ),
      footer: (ctx) => [
            TButton('taysir.flag.send'.tr(), kind: TBtn.minted, icon: TGlyph.send, onPressed: () async {
              Navigator.of(ctx).pop();
              await tRun(context, () => c.flag(l.id, kind, msg.text.trim()), success: 'taysir.flag.sent'.tr());
            }),
          ]);
}

// ----------------------------------------------------------------- cancel
Future<void> showCancelSheet(BuildContext context, TaysirLesson l) {
  final c = context.read<TaysirController>();
  var why = 'travel';
  final msg = TextEditingController();
  return showTModal<void>(context,
      title: 'taysir.cxl.title'.tr(),
      subtitle: '${l.title(context.lang)} — ${gregorianLabel(l.date, context.lang)}',
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TChips([
                for (final r in TaysirVocab.cancelReasons)
                  TChip('taysir.cancel_reason.$r'.tr(), selected: why == r, onTap: () => set(() => why = r)),
              ]),
              const SizedBox(height: 14),
              TField(
                  label: '${'taysir.cxl.message'.tr()} (${'taysir.optional'.tr()})',
                  child: TextField(controller: msg, maxLength: 300, decoration: tInput())),
              TCallout(tone: TTone.info, icon: TGlyph.bell, child: Text('taysir.cxl.notify'.tr())),
              if (l.seriesId != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text('taysir.cxl.series_note'.tr(), style: tBody(13, color: TC.muted))),
            ]),
          ),
      footer: (ctx) => [
            TButton('taysir.cxl.keep'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('taysir.cxl.confirm'.tr(), kind: TBtn.danger, icon: TGlyph.x, onPressed: () async {
              Navigator.of(ctx).pop();
              final reason = msg.text.trim().isEmpty ? 'taysir.cancel_reason.$why'.tr() : msg.text.trim();
              final n = await tRun(context, () => c.cancelLesson(l.id, reason));
              if (n != null && context.mounted) tToast(context, 'taysir.cxl.done'.tr(args: [tPlural('people', n)]));
            }),
          ]);
}

// ----------------------------------------------------------------- reject
Future<bool?> showRejectSheet(BuildContext context, List<String> requestIds) {
  final c = context.read<TaysirController>();
  var reason = 'clash';
  final more = TextEditingController();
  return showTModal<bool>(context,
      title: 'taysir.review.reject_title'.tr(),
      subtitle: '${'taysir.review.reject_sub'.tr()} ${tPlural('requests', requestIds.length)}',
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final r in TaysirVocab.rejectReasons)
                TOptionRow(title: 'taysir.reject_reason.$r'.tr(), selected: reason == r, onTap: () => set(() => reason = r)),
              const SizedBox(height: 6),
              TField(
                  label: '${'taysir.review.suggestion'.tr()} (${'taysir.optional'.tr()})',
                  child: TextField(controller: more, maxLength: 400, decoration: tInput(hint: 'taysir.review.suggestion_hint'.tr()))),
            ]),
          ),
      footer: (ctx) => [
            TButton('taysir.back'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop(false)),
            TButton('taysir.review.reject_sel'.tr(), kind: TBtn.danger, icon: TGlyph.x, onPressed: () async {
              final base = 'taysir.reject_reason.$reason'.tr();
              final text = more.text.trim().isEmpty ? base : '$base. ${more.text.trim()}';
              Navigator.of(ctx).pop(true);
              final n = await tRun(context, () => c.review(requestIds, 'reject', reason: text));
              if (n != null && context.mounted) {
                tToast(context, 'taysir.review.rejected'.tr(args: [tPlural('requests', n)]),
                    actionLabel: 'taysir.review.undo'.tr(),
                    onAction: () => tRun(context, () => c.undoReview(requestIds), success: 'taysir.review.undone'.tr()));
              }
            }),
          ]);
}

// --------------------------------------------------------- coordinator edit
Future<void> showEditLessonSheet(BuildContext context, TaysirLesson l) {
  final c = context.read<TaysirController>();
  final lang = context.lang;
  final titleAr = TextEditingController(text: l.titleAr), titleEn = TextEditingController(text: l.titleEn);
  var date = l.date;
  var slot = l.slot;
  var mosqueId = l.mosqueId;
  return showTModal<void>(context,
      title: 'taysir.lesson.edit'.tr(),
      subtitle: l.title(lang),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'taysir.submit.title_ar'.tr(), required: true, child: TextField(controller: titleAr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'taysir.submit.title_en'.tr(), child: TextField(controller: titleEn, decoration: tInput())),
              const SizedBox(height: 12),
              TField(
                label: 'taysir.lesson.place'.tr(),
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
                label: 'taysir.lesson.date'.tr(),
                hint: hijriLabel(date, lang),
                child: TButton('${weekdayName(date, lang)} ${gregorianLabel(date, lang, year: true)}', icon: TGlyph.calendar, onPressed: () async {
                  final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: c.today, lastDate: addDays(c.today, 365));
                  if (picked != null) set(() => date = dateOnly(picked));
                }),
              ),
              const SizedBox(height: 12),
              TChips([for (final s in TaysirVocab.slots) TChip(slotLabel(s), small: true, icon: slotGlyph(s), selected: slot == s, onTap: () => set(() => slot = s))]),
            ]),
          ),
      footer: (ctx) => [
            TButton('taysir.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('taysir.save'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              Navigator.of(ctx).pop();
              await tRun(context,
                  () => c.editLesson(l.id, {
                        'title_ar': titleAr.text.trim(),
                        'title_en': titleEn.text.trim(),
                        'mosque_id': mosqueId,
                        'lesson_date': isoDate(date),
                        'slot': slot,
                      }),
                  success: 'taysir.roster.saved'.tr());
            }),
          ]);
}

// ----------------------------------------------------------------- invite
Future<void> showInviteSheet(BuildContext context, TaysirPreacher p) async {
  final c = context.read<TaysirController>();
  final lang = context.lang;
  final token = await tRun(context, () => c.createInvite(p.id));
  if (token == null || !context.mounted) return;
  final org = c.catalog.organizations[p.organizationId]?.name(lang) ?? 'taysir.programme'.tr();
  final link = taysirLink('/taysir/claim/$token');
  final msg = 'taysir.roster.invite_msg'.tr(args: [p.name(lang), org, link]);
  await showTModal<void>(context,
      title: 'taysir.roster.invite_title'.tr(),
      subtitle: p.name(lang),
      body: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TCallout(tone: TTone.info, icon: TGlyph.lock, child: Text('taysir.roster.invite_note'.tr())),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: TC.page, borderRadius: BorderRadius.circular(TC.r), border: Border.all(color: TC.hair)),
              child: SelectableText(msg, style: tBody(13.5, color: TC.ink, height: 1.7)),
            ),
          ]),
      footer: (ctx) => [
            TButton('taysir.roster.copy_msg'.tr(), icon: TGlyph.copy, onPressed: () => copyToClipboard(context, msg)),
            TButton('taysir.roster.whatsapp'.tr(), kind: TBtn.minted, icon: TGlyph.whatsapp,
                onPressed: () => openExternal(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'))),
          ]);
}

// ---------------------------------------------------------- preacher edit
Future<void> showPreacherEditSheet(BuildContext context, String organizationId, {TaysirRosterEntry? entry}) {
  final c = context.read<TaysirController>();
  final p = entry?.preacher;
  final nameAr = TextEditingController(text: p?.nameAr ?? ''), nameEn = TextEditingController(text: p?.nameEn ?? '');
  final titleAr = TextEditingController(text: p?.titleAr ?? ''), phone = TextEditingController();
  var city = p?.city ?? 'khobar', aff = p?.affiliation ?? 'coop';
  var langs = {...?p?.languages};
  if (langs.isEmpty) langs = {'ar'};
  return showTModal<void>(context,
      title: p == null ? 'taysir.roster.add_title'.tr() : 'taysir.roster.edit_title'.tr(),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'taysir.roster.name_ar'.tr(), required: true, child: TextField(controller: nameAr, textDirection: TextDirection.rtl, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'taysir.roster.name_en'.tr(), child: TextField(controller: nameEn, textDirection: TextDirection.ltr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'taysir.roster.title_ar'.tr(), child: TextField(controller: titleAr, decoration: tInput(hint: 'taysir.roster.title_hint'.tr()))),
              const SizedBox(height: 12),
              Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(
                  width: 220,
                  child: TField(
                    label: 'taysir.roster.city'.tr(),
                    child: DropdownButtonFormField<String>(
                      initialValue: city,
                      decoration: tInput(),
                      items: [for (final x in TaysirVocab.cities) DropdownMenuItem(value: x, child: Text(cityLabel(x)))],
                      onChanged: (v) => set(() => city = v ?? city),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TField(
                    label: 'taysir.roster.affiliation'.tr(),
                    child: DropdownButtonFormField<String>(
                      initialValue: aff,
                      decoration: tInput(),
                      items: [for (final x in TaysirVocab.affiliations) DropdownMenuItem(value: x, child: Text('taysir.affiliation.$x'.tr()))],
                      onChanged: (v) => set(() => aff = v ?? aff),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TField(
                  label: 'taysir.roster.phone'.tr(),
                  hint: 'taysir.roster.phone_hint'.tr(),
                  child: TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      textDirection: TextDirection.ltr,
                      decoration: tInput(hint: entry?.phoneMask ?? '05XXXXXXXX'))),
              const SizedBox(height: 12),
              Text('taysir.roster.languages'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              TChips([
                for (final x in TaysirVocab.languages)
                  TChip(TaysirVocab.languageNative[x]!, small: true, selected: langs.contains(x),
                      onTap: () => set(() => langs.contains(x) && langs.length > 1 ? langs.remove(x) : langs.add(x))),
              ]),
            ]),
          ),
      footer: (ctx) => [
            TButton('taysir.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('taysir.save'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
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
                  success: p == null ? 'taysir.roster.added'.tr() : 'taysir.roster.saved'.tr());
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
    for (final c in TaysirVocab.cities) {
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
  final c = context.read<TaysirController>();
  final text = TextEditingController(text: 'الاسم,الجوال,المدينة,الصفة\n');
  return showTModal<void>(context,
      title: 'taysir.roster.import_title'.tr(),
      subtitle: 'taysir.roster.import_sub'.tr(),
      wide: true,
      body: (ctx) => StatefulBuilder(builder: (ctx, set) {
            final rows = parsePreacherCsv(text.text);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(
                  label: 'taysir.roster.paste'.tr(),
                  child: TextField(controller: text, maxLines: 6, onChanged: (_) => set(() {}), decoration: tInput())),
              const SizedBox(height: 12),
              for (final r in rows.take(30))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${r['name']} · ${r['phone']} · ${cityLabel(r['city'] as String)} · ${'taysir.affiliation.${r['affiliation']}'.tr()}',
                      style: tBody(13, color: TC.ink2)),
                ),
              const SizedBox(height: 8),
              Text('taysir.roster.import_note'.tr(), style: tBody(13, color: TC.muted)),
            ]);
          }),
      footer: (ctx) => [
            TButton('taysir.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('taysir.roster.import'.tr(), kind: TBtn.minted, icon: TGlyph.upload, onPressed: () async {
              final rows = parsePreacherCsv(text.text);
              if (rows.isEmpty) return;
              Navigator.of(ctx).pop();
              final n = await tRun(context, () => c.importPreachers(organizationId, rows));
              if (n != null && context.mounted) {
                tToast(context, 'taysir.roster.imported'.tr(args: [tPlural('preachers', n)]));
                await c.openConsole(organizationId);
              }
            }),
          ]);
}

// ------------------------------------------------------------- add mosque
Future<void> showAddMosqueSheet(BuildContext context) {
  final c = context.read<TaysirController>();
  final lang = context.lang;
  final nameAr = TextEditingController(), nameEn = TextEditingController();
  var district = c.catalog.districts.keys.firstOrNull ?? 'aqrabiyah';
  final fac = <String>{'parking'};
  (double, double)? pin;
  return showTModal<void>(context,
      title: 'taysir.mosques.add_title'.tr(),
      wide: true,
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'taysir.mosques.name_ar'.tr(), required: true, child: TextField(controller: nameAr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'taysir.mosques.name_en'.tr(), child: TextField(controller: nameEn, decoration: tInput())),
              const SizedBox(height: 12),
              TField(
                label: 'taysir.mosques.district'.tr(),
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
              Text('taysir.mosques.facilities'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              TChips([
                for (final f in TaysirVocab.facilities)
                  TChip(facilityLabel(f), small: true, icon: facilityGlyph(f), selected: fac.contains(f),
                      onTap: () => set(() => fac.contains(f) ? fac.remove(f) : fac.add(f))),
              ]),
              const SizedBox(height: 12),
              Text('taysir.mosques.pin'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              SizedBox(height: 260, child: TaysirPinPicker(value: pin, onPick: (p) => set(() => pin = p))),
            ]),
          ),
      footer: (ctx) => [
            TButton('taysir.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('taysir.mosques.add'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
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
                  success: 'taysir.mosques.added'.tr());
            }),
          ]);
}
