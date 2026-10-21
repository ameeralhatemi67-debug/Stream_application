import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/routing/sign_in_prompt.dart';
import '../../domain/taysir_dates.dart';
import '../../domain/taysir_models.dart';
import '../../domain/taysir_rules.dart';
import '../../domain/taysir_vocab.dart';
import '../../state/taysir_controller.dart';
import '../taysir_kit.dart';
import '../taysir_map.dart';
import '../taysir_modals.dart';
import '../taysir_shell.dart';
import '../taysir_widgets.dart';
import 'account_screens.dart' show TStepper;

Widget _locked(BuildContext context, String title, String body) {
  final c = context.read<TaysirController>();
  return TEmpty(
    icon: TGlyph.lock,
    title: title,
    body: body,
    action: c.signedIn
        ? TButton('taysir.nav.permissions'.tr(), onPressed: () => context.push('/taysir/permissions'))
        : TButton('taysir.sign_in'.tr(), kind: TBtn.minted, onPressed: () => openSignIn(context)),
  );
}

// -------------------------------------------------------------- my lessons
class TaysirMyLessonsScreen extends StatefulWidget {
  const TaysirMyLessonsScreen({super.key, this.tab});
  final String? tab;
  @override
  State<TaysirMyLessonsScreen> createState() => _TaysirMyLessonsScreenState();
}

class _TaysirMyLessonsScreenState extends State<TaysirMyLessonsScreen> {
  late String tab = widget.tab ?? 'all';
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final lang = context.lang;
    if (!c.canSubmitOwn) {
      return TaysirPage(title: 'taysir.nav.my_lessons'.tr(), active: TaysirSection.mine, children: [
        _locked(context, 'taysir.mine.not_preacher'.tr(), 'taysir.mine.not_preacher_body'.tr()),
      ]);
    }
    final reqs = c.myRequests();
    final upcoming = c.myLessons(upcomingOnly: true);
    final past = c.myLessons(upcomingOnly: false);
    final due = past.where((l) => !c.staff.reports.containsKey(l.id)).toList();
    final shown = reqs.where((r) => tab == 'all' ? r.status != 'withdrawn' : r.status == tab).toList();

    Widget reqCard(TaysirRequest r) {
      final l = r.first;
      final clash = r.status == 'pending' && r.items.any((x) => c.clashes(x).isNotEmpty);
      return TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                StatusTag(r.status),
                TypeTag(l.type),
                if (r.isSeries) TTag(tPlural('sessions', r.items.length), tone: TTone.slate, icon: TGlyph.repeat),
              ]),
            ),
            Text('taysir.mine.sent'.tr(args: [agoText(r.submittedAt)]), style: tBody(12, color: TC.faint)),
          ]),
          const SizedBox(height: 8),
          Text(l.title(lang), style: tStrong(16)),
          Text('${placeOf(c, l, lang)} · ${whenOf(c, l, lang)}${r.isSeries ? ' ${'taysir.mine.first_session'.tr()}' : ''}',
              style: tBody(13, color: TC.muted)),
          if (r.status == 'rejected' && l.rejectionReason != null) ...[
            const SizedBox(height: 10),
            TCallout(tone: TTone.danger, icon: TGlyph.info, child: Text('${'taysir.mine.reason'.tr()} ${l.rejectionReason}')),
          ],
          if (clash) ...[
            const SizedBox(height: 10),
            TCallout(tone: TTone.warning, icon: TGlyph.alert, child: Text('taysir.mine.clash'.tr())),
          ],
          if (r.status == 'pending' || r.status == 'rejected') ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              if (r.status == 'pending') ...[
                TButton('taysir.mine.edit'.tr(), small: true, icon: TGlyph.edit, onPressed: () => context.push('/taysir/submit?from=${l.id}&replaces=${r.id}')),
                TButton('taysir.mine.withdraw'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.x,
                    onPressed: () => tRun(context, () => c.withdraw(r.id), success: 'taysir.mine.withdrawn'.tr())),
              ] else
                TButton('taysir.mine.resubmit'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.edit,
                    onPressed: () => context.push('/taysir/submit?from=${l.id}&replaces=${r.id}')),
            ]),
          ],
        ]),
      );
    }

    return TaysirPage(title: 'taysir.nav.my_lessons'.tr(), active: TaysirSection.mine, children: [
      TPageHead(
        eyebrow: 'taysir.mine.eyebrow'.tr(),
        title: 'taysir.mine.title'.tr(),
        subtitle: 'taysir.mine.body'.tr(),
        actions: [TButton('taysir.discover.submit'.tr(), kind: TBtn.minted, large: true, icon: TGlyph.plus, onPressed: () => context.push('/taysir/submit'))],
      ),
      TStatTiles([
        ('${upcoming.where((l) => l.isPublic).length}', 'taysir.me.t_approved'.tr()),
        ('${reqs.where((r) => r.status == 'pending').length}', 'taysir.me.t_review'.tr()),
        ('${reqs.where((r) => r.status == 'rejected').length}', 'taysir.me.t_changes'.tr()),
        ('${due.length}', 'taysir.me.t_reports'.tr()),
      ]),
      TTabs<String>(value: tab, onChanged: (v) => setState(() => tab = v), options: [
        TSegOption('all', 'taysir.mine.requests'.tr()),
        TSegOption('pending', 'taysir.mine.in_review'.tr()),
        TSegOption('rejected', 'taysir.mine.changes'.tr()),
        TSegOption('approved', 'taysir.mine.upcoming'.tr()),
        TSegOption('past', 'taysir.mine.past'.tr(), count: due.length),
      ]),
      if (tab == 'approved')
        upcoming.isEmpty
            ? TEmpty(title: 'taysir.mine.nothing'.tr())
            : Column(children: [
                for (final l in upcoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LessonRow(l,
                        showDate: true,
                        extra: l.isPublic
                            ? Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TButton('taysir.mine.cancel_this'.tr(), small: true, kind: TBtn.ghost, onPressed: () => showCancelSheet(context, l)))
                            : null),
                  ),
              ])
      else if (tab == 'past')
        past.isEmpty
            ? TEmpty(title: 'taysir.mine.nothing'.tr())
            : Column(children: [
                for (final l in past)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LessonRow(l,
                        showDate: true,
                        extra: c.staff.reports[l.id] != null
                            ? TTag('taysir.lesson.report_done'.tr(args: ['${c.staff.reports[l.id]!.attendance}']), tone: TTone.success, icon: TGlyph.check)
                            : Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: TButton('taysir.lesson.add_report'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.file,
                                    onPressed: () => context.push('/taysir/report/${l.id}')))),
                  ),
              ])
      else if (shown.isEmpty)
        TEmpty(title: 'taysir.mine.nothing'.tr())
      else
        Column(children: [for (final r in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: reqCard(r))]),
    ]);
  }
}

// ---------------------------------------------------------------- submit
class TaysirSubmitScreen extends StatefulWidget {
  const TaysirSubmitScreen({super.key, this.fromLessonId, this.replaces});
  final String? fromLessonId, replaces;
  @override
  State<TaysirSubmitScreen> createState() => _TaysirSubmitScreenState();
}

class _TaysirSubmitScreenState extends State<TaysirSubmitScreen> {
  int step = 0;
  bool _seeded = false, busy = false;
  String? preacherId;
  String type = 'lesson', topic = 'aqeedah', language = 'ar', audience = 'all', slot = 'isha';
  String? interpretation, mosqueId, district, exact;
  String city = 'khobar';
  bool weekly = false, women = false, streamed = false, notify = true, direct = false, useExact = false;
  late DateTime date, start;
  final weekdays = <int>{};
  int count = 8;
  final titleAr = TextEditingController(), titleEn = TextEditingController(), desc = TextEditingController(), mq = TextEditingController();
  TaysirNewMosque? newMosque;
  final newName = TextEditingController();
  (double, double)? newPin;

  void _seed(TaysirController c) {
    if (_seeded) return;
    _seeded = true;
    date = addDays(c.today, 2);
    start = addDays(c.today, 1);
    preacherId = c.canCoordinate ? null : c.ownPreacherId;
    final src = widget.fromLessonId == null ? null : c.lesson(widget.fromLessonId!);
    if (src == null) return;
    preacherId = src.preacherId;
    type = src.type;
    topic = src.topic;
    titleAr.text = src.titleAr;
    titleEn.text = src.titleEn;
    language = src.language;
    interpretation = src.interpretation;
    audience = src.audience;
    mosqueId = src.mosqueId;
    final m = c.mosque(src.mosqueId);
    district = m?.districtId;
    city = c.district(m?.districtId)?.city ?? 'khobar';
    date = src.date.isBefore(c.today) ? addDays(c.today, 2) : src.date;
    slot = src.slot;
    women = src.womenSection;
    streamed = src.streamed;
  }

  List<DateTime> get dates => weekly ? seriesDates(start, weekdays, count) : [date];

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final lang = context.lang;
    if (!c.loaded) return TaysirPage(title: 'taysir.nav.submit'.tr(), children: const [Center(child: CircularProgressIndicator(color: TC.gold))]);
    if (!c.canSubmitOwn && !c.canCoordinate) {
      return TaysirPage(title: 'taysir.nav.submit'.tr(), children: [_locked(context, 'taysir.submit.not_allowed'.tr(), 'taysir.submit.not_allowed_body'.tr())]);
    }
    _seed(c);
    final coord = c.canCoordinate;
    final ds = dates;
    final clashes = mosqueId == null || preacherId == null
        ? <(DateTime, TaysirLesson)>[]
        : [
            for (final d in ds)
              for (final x in candidateClashes(c, requestId: widget.replaces ?? '__new', date: d, slot: slot, mosqueId: mosqueId!, preacherId: preacherId!))
                (d, x)
          ];
    final valid = [
      preacherId != null && titleAr.text.trim().length > 2,
      mosqueId != null || (newMosque != null && newMosque!.nameAr.trim().length > 1),
      ds.isNotEmpty && !ds.first.isBefore(c.today) && (!useExact || RegExp(r'^\d{2}:\d{2}$').hasMatch(exact ?? '')),
      true,
    ];
    final mosque = mosqueId == null ? null : c.mosque(mosqueId!);

    Widget label(String text) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(text, style: tBody(13, color: TC.ink2, weight: FontWeight.w700)));
    Widget gap() => const SizedBox(height: 18);

    final s0 = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (coord) ...[
        TField(
          label: 'taysir.submit.preacher'.tr(),
          required: true,
          hint: 'taysir.submit.preacher_hint'.tr(),
          child: DropdownButtonFormField<String>(
            initialValue: preacherId,
            isExpanded: true,
            hint: Text('taysir.submit.choose_preacher'.tr()),
            decoration: tInput(),
            items: [
              for (final p in c.catalog.preachers.values.where((p) => c.coordinates(p.organizationId)))
                DropdownMenuItem(value: p.id, child: Text(p.name(lang), overflow: TextOverflow.ellipsis))
            ],
            onChanged: (v) => setState(() => preacherId = v),
          ),
        ),
        gap(),
      ],
      label('${'taysir.submit.type'.tr()} *'),
      TGrid(minWidth: 180, spacing: 10, children: [
        for (final t in TaysirVocab.types)
          TOptionRow(
              title: typeLabel(t), subtitle: 'taysir.type_desc.$t'.tr(), leading: typeGlyph(t), selected: type == t, onTap: () => setState(() => type = t)),
      ]),
      gap(),
      TField(
          label: 'taysir.submit.title_ar'.tr(),
          required: true,
          child: TextField(controller: titleAr, textDirection: TextDirection.rtl, onChanged: (_) => setState(() {}), decoration: tInput(hint: 'taysir.submit.title_ar_hint'.tr()))),
      gap(),
      TField(
          label: '${'taysir.submit.title_en'.tr()} (${'taysir.optional'.tr()})',
          hint: 'taysir.submit.title_en_hint'.tr(),
          child: TextField(controller: titleEn, textDirection: TextDirection.ltr, decoration: tInput())),
      gap(),
      label('taysir.submit.subject'.tr()),
      TChips([for (final t in TaysirVocab.topics) TChip(topicLabel(t), small: true, selected: topic == t, onTap: () => setState(() => topic = t))]),
      gap(),
      label('taysir.submit.language'.tr()),
      TChips([
        for (final x in TaysirVocab.languages)
          TChip(TaysirVocab.languageNative[x]!, small: true, selected: language == x, onTap: () => setState(() {
                language = x;
                if (interpretation == x) interpretation = null;
              })),
      ]),
      gap(),
      label('taysir.submit.audience'.tr()),
      TChips([for (final a in TaysirVocab.audiences) TChip(audienceLabel(a), small: true, selected: audience == a, onTap: () => setState(() => audience = a))]),
      gap(),
      TField(
          label: '${'taysir.submit.description'.tr()} (${'taysir.optional'.tr()})',
          child: TextField(controller: desc, maxLines: 3, maxLength: 2000, decoration: tInput())),
    ]);

    final districts = c.catalog.districts.values.where((d) => d.city == city).toList()..sort((a, b) => a.sort.compareTo(b.sort));
    final q = mq.text.trim().toLowerCase();
    final cityMosques = c.verifiedMosques
        .where((m) => c.district(m.districtId)?.city == city && (district == null || m.districtId == district) && (q.isEmpty || m.name(lang).toLowerCase().contains(q)))
        .toList();
    final s1 = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      label('taysir.submit.city'.tr()),
      TSeg<String>(
        value: city,
        onChanged: (v) => setState(() {
          city = v;
          district = null;
          mosqueId = null;
          newMosque = null;
        }),
        options: [for (final x in TaysirVocab.cities.where((x) => x != 'other')) TSegOption(x, cityLabel(x))],
      ),
      gap(),
      label('taysir.submit.district'.tr()),
      TChips([
        for (final d in districts) TChip(d.name(lang), small: true, selected: district == d.id, onTap: () => setState(() => district = district == d.id ? null : d.id)),
      ]),
      gap(),
      if (newMosque == null) ...[
        TSearchBox(hint: 'taysir.submit.search_mosque'.tr(), controller: mq, onChanged: (_) => setState(() {})),
        const SizedBox(height: 10),
        if (cityMosques.isEmpty) Text('taysir.submit.no_mosques'.tr(), style: tBody(13, color: TC.muted)),
        for (final m in cityMosques)
          TOptionRow(
            title: m.name(lang),
            subtitle: [c.district(m.districtId)?.name(lang) ?? '', ...m.facilities.map(facilityLabel)].join(' · '),
            selected: mosqueId == m.id,
            onTap: () => setState(() {
              mosqueId = m.id;
              district = m.districtId;
              women = m.facilities.contains('women');
            }),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TButton('taysir.submit.suggest'.tr(), kind: TBtn.ghost, icon: TGlyph.plus, onPressed: () => setState(() {
            mosqueId = null;
            newMosque = TaysirNewMosque(nameAr: '', districtId: district ?? districts.firstOrNull?.id ?? 'aqrabiyah');
          })),
        ),
      ] else
        TCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('taysir.submit.suggest_title'.tr(), style: tStrong(15))),
              TButton('taysir.cancel'.tr(), kind: TBtn.ghost, small: true, icon: TGlyph.x, onPressed: () => setState(() => newMosque = null)),
            ]),
            const SizedBox(height: 10),
            TField(
                label: 'taysir.submit.mosque_name'.tr(),
                required: true,
                child: TextField(
                    controller: newName,
                    decoration: tInput(),
                    onChanged: (v) => setState(() => newMosque = TaysirNewMosque(
                        nameAr: v, districtId: newMosque!.districtId, latitude: newPin?.$1, longitude: newPin?.$2)))),
            const SizedBox(height: 12),
            TField(
              label: 'taysir.submit.district'.tr(),
              required: true,
              child: DropdownButtonFormField<String>(
                initialValue: districts.any((d) => d.id == newMosque!.districtId) ? newMosque!.districtId : districts.firstOrNull?.id,
                decoration: tInput(),
                items: [for (final d in districts) DropdownMenuItem(value: d.id, child: Text(d.name(lang)))],
                onChanged: (v) => setState(() => newMosque =
                    TaysirNewMosque(nameAr: newName.text, districtId: v ?? newMosque!.districtId, latitude: newPin?.$1, longitude: newPin?.$2)),
              ),
            ),
            const SizedBox(height: 12),
            label('taysir.submit.tap_map'.tr()),
            SizedBox(
              height: 220,
              child: TaysirPinPicker(
                  value: newPin,
                  onPick: (p) => setState(() {
                        newPin = p;
                        newMosque = TaysirNewMosque(nameAr: newName.text, districtId: newMosque!.districtId, latitude: p.$1, longitude: p.$2);
                      })),
            ),
            const SizedBox(height: 8),
            Text('taysir.submit.suggest_note'.tr(), style: tBody(13, color: TC.muted)),
          ]),
        ),
    ]);

    final pt = prayerTimesFor(ds.isEmpty ? c.today : ds.first, mosque, c.catalog.districts);
    final s2 = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      label('taysir.submit.frequency'.tr()),
      Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TSeg<bool>(value: weekly, onChanged: (v) => setState(() => weekly = v), options: [
          TSegOption(false, 'taysir.submit.once'.tr(), icon: TGlyph.calendar),
          TSegOption(true, 'taysir.submit.weekly'.tr(), icon: TGlyph.repeat),
        ]),
        if (weekly) TTag('taysir.submit.one_request'.tr(), icon: TGlyph.sparkle),
      ]),
      gap(),
      if (!weekly) ...[
        TChips([
          for (final o in [0, 1, 2, 7])
            TChip(
                o == 0
                    ? 'taysir.time.today'.tr()
                    : o == 1
                        ? 'taysir.time.tomorrow'.tr()
                        : o == 7
                            ? 'taysir.submit.in_week'.tr()
                            : weekdayName(addDays(c.today, o), lang),
                small: true,
                selected: sameDay(date, addDays(c.today, o)),
                onTap: () => setState(() => date = addDays(c.today, o))),
        ]),
        const SizedBox(height: 10),
        TField(
          label: 'taysir.submit.date'.tr(),
          required: true,
          hint: hijriLabel(date, lang),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TButton('${weekdayName(date, lang)} ${gregorianLabel(date, lang, year: true)}', icon: TGlyph.calendar, onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: date, firstDate: c.today, lastDate: addDays(c.today, 365));
              if (p != null) setState(() => date = dateOnly(p));
            }),
          ),
        ),
      ] else ...[
        label('taysir.submit.weekdays'.tr()),
        TChips([
          for (final w in [DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday])
            TChip(weekdayName(DateTime(2026, 10, 19 + (w - 1)), lang), small: true, selected: weekdays.contains(w),
                onTap: () => setState(() => weekdays.contains(w) ? weekdays.remove(w) : weekdays.add(w))),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.end, children: [
          TField(
            label: 'taysir.submit.starts'.tr(),
            hint: hijriLabel(start, lang),
            child: TButton(gregorianLabel(start, lang, year: true), icon: TGlyph.calendar, onPressed: () async {
              final p = await showDatePicker(context: context, initialDate: start, firstDate: c.today, lastDate: addDays(c.today, 365));
              if (p != null) setState(() => start = dateOnly(p));
            }),
          ),
          TField(
            label: 'taysir.submit.count'.tr(),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TIconButton(TGlyph.minus, tooltip: '-', onPressed: () => setState(() => count = (count - 1).clamp(2, 40))),
              SizedBox(width: 36, child: Text('$count', textAlign: TextAlign.center, style: tStrong(16))),
              TIconButton(TGlyph.plus, tooltip: '+', onPressed: () => setState(() => count = (count + 1).clamp(2, 40))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (var i = 0; i < ds.length && i < 6; i++)
            TTag('${i + 1}. ${weekdayName(ds[i], lang, short: true)} ${gregorianLabel(ds[i], lang, short: true)} · ${hijriLabel(ds[i], lang, year: false)}', tone: TTone.slate),
          if (ds.length > 6) TTag('+${ds.length - 6}', tone: TTone.slate),
        ]),
      ],
      gap(),
      label('taysir.submit.time_by_prayer'.tr()),
      TGrid(minWidth: 150, spacing: 8, children: [
        for (final s in TaysirVocab.slots)
          TOptionRow(
            title: slotLabel(s),
            subtitle:
                '${'taysir.submit.adhan'.tr(args: [clockLabel(pt.of(s), lang)])}\n${'taysir.submit.starts_at'.tr(args: [clockLabel(pt.of(s) + (TaysirVocab.iqamaMinutes[s]! + 10) / 60, lang)])}',
            leading: slotGlyph(s),
            selected: !useExact && slot == s,
            onTap: () => setState(() {
              slot = s;
              useExact = false;
            }),
          ),
      ]),
      TToggleRow(label: 'taysir.submit.fixed'.tr(), icon: TGlyph.clock, value: useExact, onChanged: (v) => setState(() => useExact = v)),
      if (useExact)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TButton(exact ?? '--:--', icon: TGlyph.clock, onPressed: () async {
            final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 20, minute: 0));
            if (t != null) setState(() => exact = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
          }),
        ),
      gap(),
      TCallout(
        tone: clashes.isEmpty ? TTone.success : TTone.warning,
        icon: clashes.isEmpty ? TGlyph.check : TGlyph.alert,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              clashes.isNotEmpty
                  ? 'taysir.submit.clash_on'.tr(args: [tPlural('days', clashes.map((e) => isoDate(e.$1)).toSet().length)])
                  : mosqueId == null
                      ? 'taysir.submit.pick_mosque'.tr()
                      : 'taysir.submit.no_clash'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          for (final (d, x) in clashes.take(3))
            Text('${gregorianLabel(d, lang)} · ${x.mosqueId == mosqueId ? 'taysir.submit.same_mosque'.tr() : 'taysir.submit.booked'.tr()}: ${x.title(lang)} — ${c.preacher(x.preacherId)?.name(lang) ?? ''}',
                style: tBody(13, color: TC.warnFg)),
          if (clashes.isNotEmpty) Text('taysir.submit.still_send'.tr(), style: tBody(13, color: TC.warnFg)),
        ]),
      ),
    ]);

    final s3 = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TToggleRow(
          label: 'taysir.submit.women'.tr(),
          desc: mosque?.facilities.contains('women') ?? false ? 'taysir.submit.women_listed'.tr() : null,
          icon: TGlyph.users,
          value: women,
          onChanged: (v) => setState(() => women = v)),
      TToggleRow(label: 'taysir.submit.stream'.tr(), desc: 'taysir.submit.stream_note'.tr(), icon: TGlyph.radio, value: streamed, onChanged: (v) => setState(() => streamed = v)),
      TToggleRow(label: 'taysir.submit.notify'.tr(), icon: TGlyph.bell, value: notify, onChanged: (v) => setState(() => notify = v)),
      if (coord)
        TToggleRow(label: 'taysir.submit.direct'.tr(), desc: 'taysir.submit.direct_note'.tr(), icon: TGlyph.shield, value: direct, onChanged: (v) => setState(() => direct = v)),
      const SizedBox(height: 10),
      TField(
        label: 'taysir.submit.interp'.tr(),
        child: DropdownButtonFormField<String?>(
          initialValue: interpretation,
          decoration: tInput(),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text('taysir.none'.tr())),
            for (final x in TaysirVocab.languages.where((x) => x != language)) DropdownMenuItem<String?>(value: x, child: Text(languageLabel(x))),
          ],
          onChanged: (v) => setState(() => interpretation = v),
        ),
      ),
      gap(),
      TCard(
        color: TC.page,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('taysir.submit.summary'.tr(), style: tStrong(15)),
          const SizedBox(height: 8),
          for (final (k, v) in [
            ('taysir.submit.preacher'.tr(), preacherId == null ? '—' : c.preacher(preacherId!)?.name(lang) ?? '—'),
            ('taysir.submit.activity'.tr(), '${typeLabel(type)} · ${titleAr.text.isEmpty ? '—' : titleAr.text}'),
            ('taysir.submit.place'.tr(), mosque?.name(lang) ?? (newMosque == null ? '—' : '${newMosque!.nameAr} (${'taysir.submit.suggested'.tr()})')),
            (
              'taysir.submit.when'.tr(),
              '${weekly ? 'taysir.submit.n_sessions_from'.tr(args: ['${ds.length}', gregorianLabel(ds.first, lang)]) : '${weekdayName(ds.first, lang)} ${gregorianLabel(ds.first, lang)} · ${hijriLabel(ds.first, lang)}'} · ${useExact ? exact ?? '' : slotLabel(slot)}'
            ),
            ('taysir.submit.clashes'.tr(), clashes.isEmpty ? 'taysir.none'.tr() : 'taysir.submit.clashes_seen'.tr(args: ['${clashes.length}'])),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 110, child: Text(k, style: tBody(13.5, color: TC.muted))),
                Expanded(child: Text(v, style: tBody(13.5, color: TC.ink, weight: FontWeight.w600))),
              ]),
            ),
        ]),
      ),
    ]);

    Future<void> send() async {
      setState(() => busy = true);
      final draft = TaysirDraft(
        preacherId: preacherId!,
        type: type,
        topic: topic,
        titleAr: titleAr.text.trim(),
        titleEn: titleEn.text.trim(),
        descriptionAr: desc.text.trim(),
        language: language,
        interpretation: interpretation,
        audience: audience,
        womenSection: women,
        streamed: streamed,
        notifyFollowers: notify,
        slot: slot,
        exactTime: useExact ? exact : null,
        dates: ds,
        mosqueId: newMosque == null ? mosqueId : null,
        newMosque: newMosque,
        replaces: widget.replaces,
        direct: coord && direct,
      );
      final r = await tRun(context, () => c.submit(draft), success: coord && direct ? 'taysir.submit.published'.tr() : 'taysir.submit.sent'.tr());
      if (!context.mounted) return;
      setState(() => busy = false);
      if (r != null) context.go(c.canSubmitOwn && !coord ? '/taysir/me/lessons' : '/taysir/console/review');
    }

    final stepLabels = ['taysir.submit.s_activity'.tr(), 'taysir.submit.s_place'.tr(), 'taysir.submit.s_when'.tr(), 'taysir.submit.s_review'.tr()];
    final card = TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        [s0, s1, s2, s3][step],
        const SizedBox(height: 18),
        // Side by side when they fit; stacked at the end with large text.
        OverflowBar(
          alignment: step > 0 ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          overflowSpacing: 8,
          children: [
            if (step > 0) TButton('taysir.back'.tr(), icon: TGlyph.arrow, onPressed: () => setState(() => step--)),
            if (step < 3)
              TButton('taysir.next'.tr(), kind: TBtn.minted, iconEnd: TGlyph.arrowEnd, onPressed: valid[step] ? () => setState(() => step++) : null)
            else
              TButton(coord && direct ? 'taysir.submit.publish'.tr() : 'taysir.submit.send'.tr(),
                  kind: TBtn.minted, icon: coord && direct ? TGlyph.check : TGlyph.send, onPressed: busy || !valid.every((v) => v) ? null : send),
          ],
        ),
      ]),
    );
    final preview = TaysirLesson(
      id: 'preview',
      organizationId: '',
      requestId: 'preview',
      type: type,
      topic: topic,
      titleAr: titleAr.text.isEmpty ? 'taysir.submit.title_ar'.tr() : titleAr.text,
      titleEn: titleEn.text,
      preacherId: preacherId ?? c.ownPreacherId ?? '',
      mosqueId: mosqueId ?? c.verifiedMosques.firstOrNull?.id ?? '',
      date: ds.first,
      slot: slot,
      exactTime: useExact ? exact : null,
      language: language,
      interpretation: interpretation,
      audience: audience,
      womenSection: women,
      streamed: streamed,
      status: 'pending',
    );
    return TaysirPage(title: 'taysir.nav.submit'.tr(), active: c.canSubmitOwn ? TaysirSection.mine : TaysirSection.console, children: [
      TPageHead(
        eyebrow: widget.replaces != null ? 'taysir.submit.eyebrow_edit'.tr() : 'taysir.submit.eyebrow_new'.tr(),
        title: 'taysir.submit.title'.tr(),
      ),
      TStepper(labels: stepLabels, current: step, onTap: (i) => setState(() => step = i)),
      if (context.wide)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: card),
          const SizedBox(width: 28),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('taysir.submit.preview'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (c.preacher(preview.preacherId) != null && c.mosque(preview.mosqueId) != null) LessonCard(preview, preview: true),
              const SizedBox(height: 8),
              Text('taysir.submit.preview_note'.tr(), style: tBody(13, color: TC.muted)),
            ]),
          ),
        ])
      else
        card,
    ]);
  }
}

// ----------------------------------------------------------- post report
class TaysirReportScreen extends StatefulWidget {
  const TaysirReportScreen({super.key, required this.lessonId});
  final String lessonId;
  @override
  State<TaysirReportScreen> createState() => _TaysirReportScreenState();
}

class _TaysirReportScreenState extends State<TaysirReportScreen> {
  int attendance = 60, women = 10;
  String issue = 'none';
  final notes = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final l = c.lesson(widget.lessonId);
    final lang = context.lang;
    if (l == null) return TaysirPage(title: 'taysir.nav.report'.tr(), children: [TEmpty(title: 'taysir.lesson.not_found'.tr())]);
    Widget stepper(int v, ValueChanged<int> set) => Row(mainAxisSize: MainAxisSize.min, children: [
          TIconButton(TGlyph.minus, tooltip: '-5', onPressed: () => set((v - 5).clamp(0, 100000))),
          SizedBox(width: 56, child: Text('$v', textAlign: TextAlign.center, style: tDisplay(22))),
          TIconButton(TGlyph.plus, tooltip: '+5', onPressed: () => set(v + 5)),
        ]);
    return TaysirPage(title: 'taysir.nav.report'.tr(), narrow: true, active: TaysirSection.mine, children: [
      TPageHead(
          eyebrow: 'taysir.report.eyebrow'.tr(),
          title: l.title(lang),
          subtitle: '${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)} · ${placeOf(c, l, lang)}'),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 24, runSpacing: 16, children: [
            TField(label: 'taysir.report.attendance'.tr(), child: stepper(attendance, (v) => setState(() => attendance = v))),
            TField(label: 'taysir.report.women'.tr(), child: stepper(women, (v) => setState(() => women = v))),
          ]),
          const SizedBox(height: 18),
          Text('taysir.report.problems'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
          const SizedBox(height: 6),
          TChips([for (final x in TaysirVocab.reportIssues) TChip('taysir.issue.$x'.tr(), small: true, selected: issue == x, onTap: () => setState(() => issue = x))]),
          const SizedBox(height: 18),
          TField(
              label: '${'taysir.report.notes'.tr()} (${'taysir.optional'.tr()})',
              child: TextField(controller: notes, maxLines: 3, maxLength: 2000, decoration: tInput())),
          const SizedBox(height: 12),
          TButton('taysir.report.save'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
            try {
              await c.postReport(l.id, attendance, women, issue, notes.text.trim());
              if (!context.mounted) return;
              tToast(context, 'taysir.report.saved'.tr());
              context.go(c.canSubmitOwn ? '/taysir/me/lessons?tab=past' : '/taysir/lessons/${l.id}');
            } catch (e) {
              if (context.mounted) tToast(context, taysirError(e), warn: true);
            }
          }),
        ]),
      ),
    ]);
  }
}
