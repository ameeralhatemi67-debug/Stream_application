import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_map.dart';
import '../lessons_modals.dart';
import '../lessons_widgets.dart';

/// The page a preacher's link opens (no account needed).
String preacherLinkUrl(String token) => lessonsLink('/preacher/$token');

/// "Saturday 24 Oct 2026, 8:30 PM" in the reader's language.
String dateTimeLabel(DateTime t, String lang) =>
    '${weekdayName(dateOnly(t), lang)} ${gregorianLabel(dateOnly(t), lang, year: true)} · ${clockLabel(t.hour + t.minute / 60, lang)}';

/// A date, then a time on it. Null when either picker is dismissed.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial, {DateTime? first}) async {
  final now = DateTime.now();
  final d = await showDatePicker(
      context: context, initialDate: initial, firstDate: first ?? DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 400)));
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

// ---------------------------------------------------------- preacher card
/// Adds a preacher, or edits [preacher]'s card. Returns the preacher's id.
Future<String?> showPreacherEditSheet(BuildContext context, {Preacher? preacher, String? phoneMask}) {
  final c = context.read<LessonsController>();
  final p = preacher;
  final nameAr = TextEditingController(text: p?.nameAr ?? ''), nameEn = TextEditingController(text: p?.nameEn ?? '');
  final titleAr = TextEditingController(text: p?.titleAr ?? ''), titleEn = TextEditingController(text: p?.titleEn ?? '');
  final bioAr = TextEditingController(text: p?.bioAr ?? ''), bioEn = TextEditingController(text: p?.bioEn ?? '');
  final photo = TextEditingController(text: p?.photoUrl ?? ''), phone = TextEditingController();
  var city = p?.city ?? 'khobar', aff = p?.affiliation ?? 'coop', listed = p?.listed ?? true;
  var langs = {...?p?.languages};
  if (langs.isEmpty) langs = {'ar'};
  return showTModal<Map<String, dynamic>>(context,
      title: p == null ? 'lessons.roster.add_title'.tr() : 'lessons.roster.edit_title'.tr(),
      wide: true,
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('lessons.preacher_admin.form_note'.tr(), style: tBody(13, color: TC.muted)),
              const SizedBox(height: 12),
              TField(
                  label: 'lessons.roster.name_ar'.tr(),
                  required: true,
                  child: TextField(key: const ValueKey('preacher-name-ar'), controller: nameAr, textDirection: TextDirection.rtl, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.roster.name_en'.tr(), child: TextField(controller: nameEn, textDirection: TextDirection.ltr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.roster.title_ar'.tr(), child: TextField(controller: titleAr, decoration: tInput(hint: 'lessons.roster.title_hint'.tr()))),
              const SizedBox(height: 12),
              TField(label: 'lessons.roster.title_en'.tr(), child: TextField(controller: titleEn, textDirection: TextDirection.ltr, decoration: tInput())),
              const SizedBox(height: 12),
              TField(label: 'lessons.roster.bio_ar'.tr(), child: TextField(controller: bioAr, maxLines: 3, maxLength: 1500, decoration: tInput())),
              TField(
                  label: 'lessons.roster.bio_en'.tr(),
                  child: TextField(controller: bioEn, maxLines: 3, maxLength: 1500, textDirection: TextDirection.ltr, decoration: tInput())),
              TField(
                  label: 'lessons.roster.photo'.tr(),
                  hint: 'lessons.roster.photo_hint'.tr(),
                  child: TextField(controller: photo, keyboardType: TextInputType.url, textDirection: TextDirection.ltr, decoration: tInput(hint: 'https://'))),
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
                      decoration: tInput(hint: phoneMask ?? '05XXXXXXXX'))),
              const SizedBox(height: 12),
              Text('lessons.roster.languages'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              TChips([
                for (final x in LessonsVocab.languages)
                  TChip(LessonsVocab.languageNative[x]!, small: true, selected: langs.contains(x),
                      onTap: () => set(() => langs.contains(x) && langs.length > 1 ? langs.remove(x) : langs.add(x))),
              ]),
              TToggleRow(
                  label: 'lessons.preacher_admin.listed'.tr(),
                  desc: 'lessons.preacher_admin.listed_desc'.tr(),
                  icon: TGlyph.eye,
                  value: listed,
                  onChanged: (v) => set(() => listed = v)),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.save'.tr(), key: const ValueKey('preacher-save'), kind: TBtn.minted, icon: TGlyph.check, onPressed: () {
              final url = photo.text.trim();
              if (nameAr.text.trim().length < 3) return tToast(ctx, 'lessons.preacher_admin.name_needed'.tr(), warn: true);
              if (url.isNotEmpty && !url.startsWith('https://')) return tToast(ctx, 'lessons.preacher_admin.photo_https'.tr(), warn: true);
              Navigator.of(ctx).pop({
                if (p != null) 'id': p.id,
                'name_ar': nameAr.text.trim(),
                'name_en': nameEn.text.trim(),
                'title_ar': titleAr.text.trim(),
                'title_en': titleEn.text.trim(),
                'bio_ar': bioAr.text.trim(),
                'bio_en': bioEn.text.trim(),
                'photo_url': url,
                'city': city,
                'affiliation': aff,
                'languages': langs.toList(),
                'listed': listed,
                if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
              });
            }),
          ]).then((fields) async {
    if (fields == null || !context.mounted) return null;
    return tRun(context, () => c.upsertPreacher(fields),
        success: p == null ? 'lessons.roster.added'.tr() : 'lessons.roster.saved'.tr());
  });
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

Future<void> showImportSheet(BuildContext context) {
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
              final n = await tRun(context, () => c.importPreachers(rows));
              if (n != null && context.mounted) tToast(context, 'lessons.roster.imported'.tr(args: [tPlural('preachers', n)]));
            }),
          ]);
}

Future<bool?> showRemovePreacherSheet(BuildContext context, Preacher p) {
  final c = context.read<LessonsController>();
  final n = c.catalog.lessons.values.where((l) => l.preacherId == p.id).length;
  return showTModal<bool>(context,
      title: 'lessons.preacher_admin.remove_title'.tr(),
      subtitle: p.name(context.lang),
      body: (ctx) => TCallout(
          tone: TTone.danger, icon: TGlyph.alert, child: Text('lessons.preacher_admin.remove_body'.tr(args: [tPlural('lessons', n)]))),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop(false)),
            TButton('lessons.preacher_admin.remove'.tr(), kind: TBtn.danger, icon: TGlyph.trash, onPressed: () async {
              Navigator.of(ctx).pop(true);
            }),
          ]).then((ok) async {
    if (ok != true || !context.mounted) return false;
    final done = await tRun(context, () => c.removePreacher(p.id), success: 'lessons.preacher_admin.removed'.tr());
    return done != null;
  });
}

// ------------------------------------------------------------------ links
/// Creates a link for [p]: one-time (the first phone keeps it, with an
/// optional end) or timed (any phone, from a start to an end). Then shows
/// the message to send him.
Future<void> showNewLinkSheet(BuildContext context, Preacher p) async {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  var kind = 'once';
  var ends = false;
  final now = DateTime.now();
  var from = DateTime(now.year, now.month, now.day, now.hour + 1);
  var until = DateTime(now.year, now.month, now.day + 7, 23, 59);
  final note = TextEditingController();
  final created = await showTModal<NewPreacherKey>(context,
      title: 'lessons.links.new_title'.tr(),
      subtitle: p.name(lang),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) {
              Widget when(String label, DateTime value, ValueChanged<DateTime> onPick) => TField(
                    label: label,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TButton(dateTimeLabel(value, lang), icon: TGlyph.calendar, onPressed: () async {
                        final picked = await pickDateTime(ctx, value);
                        if (picked != null) set(() => onPick(picked));
                      }),
                    ),
                  );
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TOptionRow(
                  title: 'lessons.links.once'.tr(),
                  subtitle: 'lessons.links.once_desc'.tr(),
                  leading: TGlyph.phone,
                  selected: kind == 'once',
                  onTap: () => set(() => kind = 'once'),
                ),
                TOptionRow(
                  title: 'lessons.links.window'.tr(),
                  subtitle: 'lessons.links.window_desc'.tr(),
                  leading: TGlyph.clock,
                  selected: kind == 'window',
                  onTap: () => set(() => kind = 'window'),
                ),
                const SizedBox(height: 10),
                if (kind == 'once') ...[
                  TToggleRow(label: 'lessons.links.ends'.tr(), icon: TGlyph.clock, value: ends, onChanged: (v) => set(() => ends = v)),
                  if (ends) when('lessons.links.until'.tr(), until, (v) => until = v),
                ] else ...[
                  when('lessons.links.from'.tr(), from, (v) => from = v),
                  const SizedBox(height: 10),
                  when('lessons.links.until'.tr(), until, (v) => until = v),
                ],
                const SizedBox(height: 12),
                TField(
                    label: '${'lessons.links.note'.tr()} (${'lessons.optional'.tr()})',
                    child: TextField(controller: note, maxLength: 200, decoration: tInput(hint: 'lessons.links.note_hint'.tr()))),
              ]);
            },
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.links.create'.tr(), kind: TBtn.minted, icon: TGlyph.link, onPressed: () async {
              final window = kind == 'window';
              if (((window || ends) && !until.isAfter(DateTime.now())) || (window && !until.isAfter(from))) {
                tToast(ctx, 'lessons.links.bad_dates'.tr(), warn: true);
                return;
              }
              final k = await tRun(ctx,
                  () => c.createKey(p.id, kind,
                      validFrom: window ? from : null, validUntil: window || ends ? until : null, note: note.text.trim()));
              if (k != null && ctx.mounted) Navigator.of(ctx).pop(k);
            }),
          ]);
  if (created != null && context.mounted) await showLinkMessageSheet(context, p, created);
}

/// The message with a new link, ready for WhatsApp. The link is shown only
/// now: the server keeps no copy of it.
Future<void> showLinkMessageSheet(BuildContext context, Preacher p, NewPreacherKey k) {
  final lang = context.lang;
  final link = preacherLinkUrl(k.token);
  final how = k.kind == 'once'
      ? (k.validUntil == null
          ? 'lessons.links.msg_once'.tr()
          : 'lessons.links.msg_once_until'.tr(args: [dateTimeLabel(k.validUntil!, lang)]))
      : 'lessons.links.msg_window'.tr(args: [dateTimeLabel(k.validFrom!, lang), dateTimeLabel(k.validUntil!, lang)]);
  final msg = 'lessons.links.msg'.tr(args: [p.name(lang), link, how]);
  return showTModal<void>(context,
      title: 'lessons.links.ready_title'.tr(),
      subtitle: p.name(lang),
      body: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TCallout(tone: TTone.warning, icon: TGlyph.lock, child: Text('lessons.links.only_now'.tr())),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: TC.page, borderRadius: BorderRadius.circular(TC.r), border: Border.all(color: TC.hair)),
              child: SelectableText(msg, key: const ValueKey('preacher-link-message'), style: tBody(13.5, color: TC.ink, height: 1.7)),
            ),
          ]),
      footer: (ctx) => [
            TButton('lessons.links.copy_link'.tr(), icon: TGlyph.link, onPressed: () => copyToClipboard(context, link)),
            TButton('lessons.roster.copy_msg'.tr(), icon: TGlyph.copy, onPressed: () => copyToClipboard(context, msg)),
            TButton('lessons.lesson.share'.tr(), icon: TGlyph.share, onPressed: () => Share.share(msg)),
            TButton('lessons.roster.whatsapp'.tr(), kind: TBtn.minted, icon: TGlyph.whatsapp,
                onPressed: () => openExternal(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}'))),
          ]);
}

// ---------------------------------------------------------------- mosques
/// Adds a mosque, or edits [mosque].
Future<void> showMosqueSheet(BuildContext context, {Mosque? mosque}) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final m = mosque;
  final nameAr = TextEditingController(text: m?.nameAr ?? ''), nameEn = TextEditingController(text: m?.nameEn ?? '');
  var district = m?.districtId ?? c.catalog.districts.keys.firstOrNull ?? 'aqrabiyah';
  final fac = <String>{...?m?.facilities};
  if (m == null) fac.add('parking');
  (double, double)? pin = m != null && m.hasPin ? (m.latitude!, m.longitude!) : null;
  return showTModal<void>(context,
      title: m == null ? 'lessons.mosques.add_title'.tr() : 'lessons.mosques.edit_title'.tr(),
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
            TButton(m == null ? 'lessons.mosques.add'.tr() : 'lessons.save'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              if (nameAr.text.trim().length < 2) return;
              Navigator.of(ctx).pop();
              await tRun(context,
                  () => c.upsertMosque({
                        if (m != null) 'id': m.id,
                        'name_ar': nameAr.text.trim(),
                        'name_en': nameEn.text.trim(),
                        'district_id': district,
                        if (pin != null) 'latitude': pin!.$1,
                        if (pin != null) 'longitude': pin!.$2,
                        'facilities': fac.toList(),
                      }),
                  success: m == null ? 'lessons.mosques.added'.tr() : 'lessons.roster.saved'.tr());
            }),
          ]);
}

/// Removes a mosque. One that sessions use is merged into another instead:
/// its sessions move there.
Future<void> showRemoveMosqueSheet(BuildContext context, Mosque m) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final used = c.catalog.lessons.values.any((l) => l.mosqueId == m.id);
  String? into;
  return showTModal<void>(context,
      title: 'lessons.mosques.remove_title'.tr(),
      subtitle: m.name(lang),
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(used ? 'lessons.mosques.in_use'.tr() : 'lessons.mosques.remove_body'.tr(), style: tBody(14, color: TC.ink2)),
              if (used) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: into,
                  isExpanded: true,
                  hint: Text('lessons.mosques.merge_into'.tr()),
                  decoration: tInput(),
                  items: [
                    for (final v in c.catalog.mosques.values.where((v) => v.id != m.id))
                      DropdownMenuItem(value: v.id, child: Text('${v.name(lang)} · ${c.district(v.districtId)?.name(lang) ?? ''}', overflow: TextOverflow.ellipsis))
                  ],
                  onChanged: (v) => set(() => into = v),
                ),
              ],
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton(used ? 'lessons.mosques.merge'.tr() : 'lessons.mosques.remove'.tr(), kind: TBtn.danger, icon: TGlyph.trash, onPressed: () async {
              if (used && into == null) return;
              Navigator.of(ctx).pop();
              await tRun(context, () => c.removeMosque(m.id, mergeInto: into),
                  success: used ? 'lessons.mosques.merged'.tr() : 'lessons.mosques.removed'.tr());
            }),
          ]);
}
