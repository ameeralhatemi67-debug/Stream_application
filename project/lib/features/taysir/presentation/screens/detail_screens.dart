import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

class _Fact extends StatelessWidget {
  const _Fact(this.glyph, this.label, this.value, this.sub, {this.onTap, this.night = false});
  final TGlyph glyph;
  final String label, value, sub;
  final VoidCallback? onTap;
  final bool night;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TIcon(glyph, size: 18, color: night ? TC.onNightGold : TC.goldIcon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: tBody(12, color: night ? TC.onNight2 : TC.muted, height: 1.3)),
                Text(value, style: tStrong(14.5, color: night ? TC.onNight : TC.ink).copyWith(decoration: onTap == null ? null : TextDecoration.underline)),
                Text(sub, style: tBody(12.5, color: night ? TC.onNightGold : TC.bronze, height: 1.4)),
              ]),
            ),
          ]),
        ),
      );
}

class TaysirLessonScreen extends StatelessWidget {
  const TaysirLessonScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final l = c.lesson(id);
    final lang = context.lang, wide = context.wide;
    if (l == null) {
      return TaysirPage(title: 'taysir.nav.lesson'.tr(), children: [
        c.loading ? const Center(child: CircularProgressIndicator(color: TC.gold)) : TEmpty(title: 'taysir.lesson.not_found'.tr()),
      ]);
    }
    final p = c.preacher(l.preacherId), m = c.mosque(l.mosqueId), d = c.district(m?.districtId);
    final pt = prayerTimesFor(l.date, m, c.catalog.districts);
    final s = c.seriesOf(l.seriesId);
    final sibs = s == null ? <TaysirLesson>[] : c.sessionsOf(s.id);
    final past = l.date.isBefore(c.today);
    final mine = c.ownPreacherId == l.preacherId;
    final staff = c.coordinates(l.organizationId);
    final report = c.staff.reports[l.id];
    final channel = preacherChannel(context, p);
    final liveNow = c.isLiveNow(l) || (channel?.isCurrentlyLive ?? false) && l.streamed && sameDay(l.date, c.today);
    final org = c.catalog.organizations[l.organizationId];

    final facts = [
      _Fact(TGlyph.calendar, 'taysir.lesson.date'.tr(), '${relativeDayLabel(l.date, lang) == weekdayName(l.date, lang) ? '' : '${relativeDayLabel(l.date, lang)} · '}${weekdayName(l.date, lang)} ${gregorianLabel(l.date, lang)}',
          hijriLabel(l.date, lang), night: true),
      _Fact(slotGlyph(l.slot), 'taysir.lesson.time'.tr(), l.exactTime != null ? clockLabel(hhmmToHours(l.exactTime!), lang) : slotLabel(l.slot),
          'taysir.time.adhan_line'.tr(args: [prayerLabel(l.slot), clockLabel(pt.of(l.slot), lang), clockLabel(c.startHours(l), lang)]), night: true),
      _Fact(TGlyph.mosque, 'taysir.lesson.place'.tr(), m?.name(lang) ?? '', d == null ? '' : '${d.name(lang)} · ${cityLabel(d.city)}',
          night: true, onTap: m == null ? null : () => context.push('/taysir/mosques/${m.id}')),
    ];
    final actions = Wrap(spacing: 8, runSpacing: 8, children: [
      if (past) AttendToggle(l) else RemindButton(l),
      if (!past && l.isPublic)
        TButton('taysir.lesson.calendar'.tr(), kind: TBtn.night, icon: TGlyph.calendar, onPressed: () => openExternal(calendarLink(c, l, lang))),
      if (m?.directions != null) TButton('taysir.lesson.directions'.tr(), kind: TBtn.night, icon: TGlyph.nav, onPressed: () => openExternal(m!.directions!)),
      if (l.isPublic || l.isCancelled) TButton('taysir.lesson.share'.tr(), kind: TBtn.night, icon: TGlyph.share, onPressed: () => showShareSheet(context, l)),
    ]);

    final hero = TNight(
      padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16, vertical: wide ? 32 : 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Builder(builder: (context) {
            final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [TypeTag(l.type), LessonBadges(l, max: 5), if (!l.isPublic && !l.isCancelled) StatusTag(l.status)]),
              const SizedBox(height: 10),
              Text(l.title(lang), style: tDisplay(wide ? 34 : 26, color: TC.onNight)),
              const SizedBox(height: 10),
              if (p != null)
                InkWell(
                  onTap: () => context.push('/taysir/preachers/${p.id}'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    TAvatar(name: p.name(lang), size: 30),
                    const SizedBox(width: 8),
                    Flexible(child: Text('${p.name(lang)}${p.title(lang).isEmpty ? '' : ' · ${p.title(lang)}'}', style: tBody(14, color: TC.onNight2, weight: FontWeight.w600))),
                  ]),
                ),
              const SizedBox(height: 12),
              ...facts,
              const SizedBox(height: 12),
              actions,
            ]);
            if (!wide) return copy;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: copy),
              const SizedBox(width: 32),
              Expanded(
                  flex: 2,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(TC.rLg),
                      child: TCover(seed: l.id + l.mosqueId, glyph: typeGlyph(l.type), word: topicLabel(l.topic), tags: [if (liveNow) const TLiveTag()]))),
            ]);
          }),
        ),
      ),
    );

    final ownerBar = (mine || staff)
        ? Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(TC.rLg), border: Border.all(color: TC.hair2)),
            child: Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              TIcon(mine ? TGlyph.user : TGlyph.shield, size: 18, color: TC.goldIcon),
              Text(l.status == 'pending' ? 'taysir.lesson.pending_note'.tr() : (mine ? 'taysir.lesson.yours'.tr() : 'taysir.lesson.approved_by'.tr()),
                  style: tBody(14, color: TC.ink2, weight: FontWeight.w600)),
              if (l.isPublic && !past) ...[
                if (staff)
                  TButton('taysir.lesson.edit'.tr(), small: true, icon: TGlyph.edit, onPressed: () => showEditLessonSheet(context, l))
                else
                  TButton('taysir.lesson.request_change'.tr(), small: true, icon: TGlyph.edit, onPressed: () => context.push('/taysir/submit?from=${l.id}')),
                TButton('taysir.lesson.cancel'.tr(), small: true, kind: TBtn.danger, icon: TGlyph.x, onPressed: () => showCancelSheet(context, l)),
              ],
              if (past && l.isPublic && report == null && (mine || staff))
                TButton('taysir.lesson.add_report'.tr(), small: true, kind: TBtn.minted, icon: TGlyph.file, onPressed: () => context.push('/taysir/report/${l.id}')),
              if (report != null) TTag('taysir.lesson.report_done'.tr(args: ['${report.attendance}']), tone: TTone.success, icon: TGlyph.check),
            ]),
          )
        : null;

    final main = [
      if (l.isCancelled)
        TCallout(tone: TTone.danger, icon: TGlyph.alert, child: Text('${'taysir.lesson.cancelled'.tr()} ${l.cancelReason ?? ''}')),
      if (ownerBar != null) ownerBar,
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('taysir.lesson.about'.tr(), style: tStrong(17)),
          if (l.description(lang).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.description(lang), style: tBody(15, height: 1.9))),
          const SizedBox(height: 12),
          _Kv([
            ('taysir.lesson.subject'.tr(), topicLabel(l.topic)),
            ('taysir.lesson.language'.tr(),
                '${languageLabel(l.language)}${l.interpretation == null ? '' : ' · ${'taysir.lesson.interp_into'.tr(args: [languageLabel(l.interpretation!)])}'}'),
            ('taysir.lesson.audience'.tr(), '${audienceLabel(l.audience)}${l.womenSection ? ' · ${'taysir.lesson.women'.tr()}' : ''}'),
            if (org != null) ('taysir.lesson.organized_by'.tr(), '${org.name(lang)} · ${'taysir.programme'.tr()}'),
          ]),
        ]),
      ),
      if (l.streamed || channel != null)
        TCard(
          child: Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Container(width: 44, height: 44, alignment: Alignment.center, decoration: const BoxDecoration(color: TC.tagBg, shape: BoxShape.circle),
                child: const TIcon(TGlyph.radio, size: 20, color: TC.goldIcon)),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(liveNow ? 'taysir.lesson.live_now'.tr() : 'taysir.lesson.will_stream'.tr(), style: tStrong(15)),
                Text('taysir.lesson.stream_note'.tr(), style: tBody(13, color: TC.muted)),
              ]),
            ),
            if (channel != null)
              TButton('taysir.lesson.watch'.tr(), kind: TBtn.minted, icon: TGlyph.play,
                  onPressed: () => context.push(channel.isCurrentlyLive && channel.activeStreamId != null
                      ? '/live/${channel.activeStreamId}'
                      : '/profile/${channel.streamerId}')),
          ]),
        ),
      if (s != null)
        TCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TEyebrow('taysir.lesson.series'.tr(), icon: TGlyph.repeat),
                  Text(s.title(lang), style: tStrong(17)),
                ]),
              ),
              FollowButton(kind: 'series', id: s.id, small: true),
            ]),
            const SizedBox(height: 10),
            TMeter(value: sibs.where((x) => x.date.isBefore(c.today)).length, max: s.total),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final x in sibs)
                InkWell(
                  onTap: () => x.id == l.id ? null : context.push('/taysir/lessons/${x.id}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: x.id == l.id ? TC.tint : TC.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: x.id == l.id ? TC.gold : TC.hair),
                    ),
                    child: Column(children: [
                      Text('${x.seq ?? ''}', style: tStrong(13)),
                      Text(gregorianLabel(x.date, lang, short: true), style: tBody(11.5, color: TC.muted, height: 1.3)),
                      Text(
                          x.isCancelled
                              ? 'taysir.status.cancelled'.tr()
                              : x.date.isBefore(c.today)
                                  ? (c.attended(x.id) ? 'taysir.lesson.attended'.tr() : 'taysir.lesson.held'.tr())
                                  : sameDay(x.date, c.today)
                                      ? 'taysir.time.today'.tr()
                                      : 'taysir.lesson.upcoming'.tr(),
                          style: tBody(11, color: TC.bronze, height: 1.3)),
                    ]),
                  ),
                ),
            ]),
          ]),
        ),
      if (c.signedIn && (l.isPublic || l.isCancelled))
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TButton('taysir.lesson.flag_link'.tr(), kind: TBtn.ghost, icon: TGlyph.flag, onPressed: () => showFlagSheet(context, l)),
        ),
    ];
    final side = [
      if (p != null)
        TCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            InkWell(
              onTap: () => context.push('/taysir/preachers/${p.id}'),
              child: Row(children: [
                TAvatar(name: p.name(lang), size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name(lang), style: tStrong(15)),
                    if (p.title(lang).isNotEmpty) Text(p.title(lang), style: tBody(13, color: TC.muted)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            FollowButton(kind: 'preacher', id: p.id, expand: true),
          ]),
        ),
      if (m != null)
        ClipRRect(
          borderRadius: BorderRadius.circular(TC.rLg),
          child: TCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (m.hasPin && TaysirMap.covers(m.latitude!, m.longitude!))
                SizedBox(
                    height: 190,
                    child: TaysirMap(
                        pins: [TaysirPin(id: m.id, lat: m.latitude!, lng: m.longitude!, label: m.name(lang), verified: m.verified)],
                        selected: m.id,
                        interactive: false)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.name(lang), style: tStrong(15)),
                  if (d != null) Text('${d.name(lang)} · ${cityLabel(d.city)}', style: tBody(13, color: TC.muted)),
                  const SizedBox(height: 8),
                  FacilityList(m.facilities, dense: true),
                ]),
              ),
            ]),
          ),
        ),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${'taysir.lesson.prayer_times'.tr()} · ${cityLabel(d?.city ?? 'khobar')}', style: tStrong(15)),
          const SizedBox(height: 8),
          for (final x in TaysirVocab.slots)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: x == l.slot ? BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(8)) : null,
              child: Row(children: [
                TIcon(slotGlyph(x), size: 15, color: TC.goldIcon),
                const SizedBox(width: 8),
                Expanded(child: Text(prayerLabel(x), style: tBody(13.5, color: TC.ink, weight: x == l.slot ? FontWeight.w700 : FontWeight.w400))),
                Text(clockLabel(pt.of(x), lang), style: tBody(13.5, color: TC.ink2, weight: FontWeight.w600)),
              ]),
            ),
        ]),
      ),
    ];
    Widget column(List<Widget> xs) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < xs.length; i++) ...[if (i > 0) const SizedBox(height: 16), xs[i]]
        ]);
    return TaysirPage(
      title: 'taysir.nav.lesson'.tr(),
      active: TaysirSection.lessons,
      header: hero,
      children: [
        if (wide)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 2, child: column(main)),
            const SizedBox(width: 28),
            Expanded(child: column(side)),
          ])
        else
          column([...main, ...side]),
      ],
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.rows);
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 120, child: Text(k, style: tBody(14, color: TC.muted))),
              Expanded(child: Text(v, style: tBody(14, color: TC.ink, weight: FontWeight.w600))),
            ]),
          ),
      ]);
}

// --------------------------------------------------------------- series
class TaysirSeriesScreen extends StatelessWidget {
  const TaysirSeriesScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final s = c.seriesOf(id);
    final lang = context.lang;
    if (s == null) return TaysirPage(title: 'taysir.nav.series'.tr(), children: [TEmpty(title: 'taysir.lesson.not_found'.tr())]);
    final sessions = c.sessionsOf(s.id);
    final next = sessions.where((x) => !x.date.isBefore(c.today) && x.isPublic).firstOrNull;
    return TaysirPage(title: 'taysir.nav.series'.tr(), active: TaysirSection.lessons, children: [
      TPageHead(
        eyebrow: 'taysir.lesson.series'.tr(),
        title: s.title(lang),
        subtitle:
            '${c.preacher(s.preacherId)?.name(lang) ?? ''} · ${c.mosque(s.mosqueId)?.name(lang) ?? ''} · ${sessions.isEmpty ? '' : 'taysir.time.every'.tr(args: [weekdayName(sessions.first.date, lang)])} ${slotLabel(s.slot)}',
        actions: [
          FollowButton(kind: 'series', id: s.id),
          if (next != null) TButton('taysir.lesson.upcoming'.tr(), kind: TBtn.minted, iconEnd: TGlyph.arrowEnd, onPressed: () => context.push('/taysir/lessons/${next.id}')),
        ],
      ),
      TMeter(value: sessions.where((x) => x.date.isBefore(c.today)).length, max: s.total),
      Column(children: [for (final l in sessions) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, showDate: true))]),
    ]);
  }
}

// ------------------------------------------------------------- preacher
class TaysirPreacherScreen extends StatefulWidget {
  const TaysirPreacherScreen({super.key, required this.id});
  final String id;
  @override
  State<TaysirPreacherScreen> createState() => _TaysirPreacherScreenState();
}

class _TaysirPreacherScreenState extends State<TaysirPreacherScreen> {
  String tab = 'upcoming';
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final p = c.preacher(widget.id);
    final lang = context.lang;
    if (p == null) return TaysirPage(title: 'taysir.nav.preacher'.tr(), children: [TEmpty(title: 'taysir.lesson.not_found'.tr())]);
    final up = c.upcomingWhere((l) => l.preacherId == p.id);
    final past = c.pastWhere((l) => l.preacherId == p.id);
    final series = c.approvedSeries.where((s) => s.preacherId == p.id).toList();
    final places = {...up, ...past}.map((l) => c.mosque(l.mosqueId)).whereType<TaysirMosque>().toSet().toList();
    final channel = preacherChannel(context, p);
    final org = c.catalog.organizations[p.organizationId];
    final bio = p.bio(lang).isNotEmpty ? p.bio(lang) : 'taysir.preacher.bio_default'.tr(args: [org?.name(lang) ?? 'taysir.programme'.tr()]);
    final header = TCard(
      child: Wrap(spacing: 20, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TAvatar(name: p.name(lang), size: context.wide ? 104 : 84, live: channel?.isCurrentlyLive ?? false),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name(lang), style: tDisplay(context.wide ? 30 : 24)),
            if (p.title(lang).isNotEmpty) Text(p.title(lang), style: tBody(15, color: TC.muted)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              TTag('taysir.preacher.verified'.tr(), icon: TGlyph.shield),
              if (p.affiliation == 'ministry') TTag('taysir.affiliation.ministry'.tr(), tone: TTone.info),
              TTag(cityLabel(p.city), tone: TTone.slate, icon: TGlyph.pin),
              if (channel != null) TTag('taysir.preacher.has_channel'.tr(), tone: TTone.liveSoft, icon: TGlyph.radio),
            ]),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FollowButton(kind: 'preacher', id: p.id),
          if (channel != null)
            TButton('taysir.preacher.channel'.tr(), icon: TGlyph.radio, onPressed: () => context.push('/profile/${channel.streamerId}')),
          TButton('taysir.preacher.copy_link'.tr(), kind: TBtn.ghost, icon: TGlyph.share,
              onPressed: () => copyToClipboard(context, taysirLink('/taysir/preachers/${p.id}'))),
        ]),
      ]),
    );
    return TaysirPage(title: 'taysir.nav.preacher'.tr(), active: TaysirSection.discover, children: [
      header,
      TStatTiles([
        ('${up.length}', 'taysir.preacher.s_upcoming'.tr()),
        ('${series.length}', 'taysir.preacher.s_series'.tr()),
        ('${places.length}', 'taysir.preacher.s_mosques'.tr()),
        ('${past.length}', 'taysir.preacher.s_held'.tr()),
      ]),
      TTabs<String>(value: tab, onChanged: (v) => setState(() => tab = v), options: [
        TSegOption('upcoming', 'taysir.preacher.upcoming'.tr(), count: up.length),
        TSegOption('series', 'taysir.preacher.series'.tr(), count: series.length),
        TSegOption('past', 'taysir.preacher.past'.tr()),
        TSegOption('about', 'taysir.preacher.about'.tr()),
      ]),
      switch (tab) {
        'upcoming' => up.isEmpty
            ? TEmpty(title: 'taysir.preacher.no_upcoming'.tr(), body: 'taysir.preacher.follow_hint'.tr())
            : Column(children: [for (final l in up) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, showDate: true))]),
        'series' => TGrid(minWidth: 280, children: [for (final s in series) SeriesCard(s)]),
        'past' => Column(children: [for (final l in past.take(12)) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, showDate: true))]),
        _ => TCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bio, style: tBody(15, height: 1.9)),
              const SizedBox(height: 12),
              _Kv([
                ('taysir.preacher.languages'.tr(), p.languages.map(languageLabel).join('، ')),
                ('taysir.preacher.affiliation'.tr(), 'taysir.affiliation.${p.affiliation}'.tr()),
                if (places.isNotEmpty) ('taysir.preacher.teaches_at'.tr(), places.map((m) => m.name(lang)).join('، ')),
              ]),
            ]),
          ),
      },
    ]);
  }
}

// ---------------------------------------------------------------- mosque
class TaysirMosqueScreen extends StatelessWidget {
  const TaysirMosqueScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final m = c.mosque(id);
    final lang = context.lang;
    if (m == null) return TaysirPage(title: 'taysir.nav.mosque'.tr(), children: [TEmpty(title: 'taysir.lesson.not_found'.tr())]);
    final d = c.district(m.districtId);
    final items = c.upcomingWhere((l) => l.mosqueId == m.id);
    final week = [for (var i = 0; i < 7; i++) addDays(c.today, i)];
    return TaysirPage(title: 'taysir.nav.mosque'.tr(), active: TaysirSection.map, children: [
      TPageHead(
        eyebrow: d == null ? null : '${d.name(lang)} · ${cityLabel(d.city)}',
        title: m.name(lang),
        actions: [
          FollowButton(kind: 'mosque', id: m.id),
          if (m.directions != null) TButton('taysir.lesson.directions'.tr(), kind: TBtn.minted, icon: TGlyph.nav, onPressed: () => openExternal(m.directions!)),
        ],
      ),
      FacilityList(m.facilities),
      if (!m.verified) TCallout(tone: TTone.warning, icon: TGlyph.alert, child: Text('taysir.mosque.unverified'.tr())),
      TCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('taysir.mosque.week'.tr(), style: tStrong(17)),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const FixedColumnWidth(108),
              columnWidths: const {0: FixedColumnWidth(96)},
              border: TableBorder.all(color: TC.hair),
              children: [
                TableRow(decoration: const BoxDecoration(color: TC.tint), children: [
                  const SizedBox(),
                  for (final day in week)
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(children: [
                        Text(sameDay(day, c.today) ? 'taysir.time.today'.tr() : weekdayName(day, lang, short: true), style: tStrong(12.5)),
                        Text(gregorianLabel(day, lang, short: true), style: tBody(11.5, color: TC.muted, height: 1.3)),
                      ]),
                    ),
                ]),
                for (final s in TaysirVocab.slots)
                  TableRow(children: [
                    Padding(padding: const EdgeInsets.all(6), child: Text(prayerLabel(s), style: tBody(12.5, color: TC.ink2, weight: FontWeight.w600))),
                    for (final day in week)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Column(children: [
                          for (final l in items.where((l) => sameDay(l.date, day) && l.slot == s))
                            InkWell(
                              onTap: () => context.push('/taysir/lessons/${l.id}'),
                              child: Text(l.title(lang), maxLines: 2, overflow: TextOverflow.ellipsis, style: tStrong(11.5, color: TC.bronze)),
                            ),
                        ]),
                      ),
                  ]),
              ],
            ),
          ),
        ]),
      ),
      TSectionHead('taysir.mosque.upcoming'.tr(), count: items.length),
      Column(children: [for (final l in items.take(12)) Padding(padding: const EdgeInsets.only(bottom: 8), child: LessonRow(l, showDate: true))]),
      if (m.hasPin && TaysirMap.covers(m.latitude!, m.longitude!))
        ClipRRect(
          borderRadius: BorderRadius.circular(TC.rLg),
          child: SizedBox(
              height: 260,
              child: TaysirMap(pins: [TaysirPin(id: m.id, lat: m.latitude!, lng: m.longitude!, label: m.name(lang), count: items.length, verified: m.verified)], selected: m.id)),
        ),
    ]);
  }
}
