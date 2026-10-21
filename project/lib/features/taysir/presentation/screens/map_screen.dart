import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/taysir_dates.dart';
import '../../domain/taysir_models.dart';
import '../../domain/taysir_vocab.dart';
import '../../state/taysir_controller.dart';
import '../taysir_kit.dart';
import '../taysir_map.dart';
import '../taysir_modals.dart';
import '../taysir_widgets.dart';

class TaysirMapScreen extends StatefulWidget {
  const TaysirMapScreen({super.key, this.initialMosque});
  final String? initialMosque;
  @override
  State<TaysirMapScreen> createState() => _TaysirMapScreenState();
}

class _TaysirMapScreenState extends State<TaysirMapScreen> {
  String range = 'week';
  String? city, selected;
  final q = TextEditingController();

  @override
  void initState() {
    super.initState();
    selected = widget.initialMosque;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TaysirController>();
    final lang = context.lang, wide = context.wide;
    bool inRange(TaysirLesson l) => switch (range) {
          'today' => sameDay(l.date, c.today),
          'week' => !l.date.isAfter(addDays(c.today, 6)),
          _ => true,
        };
    final lessons = c.upcoming.where(inRange).toList();
    final query = q.text.trim().toLowerCase();
    final mosques = c.verifiedMosques.where((m) {
      final d = c.district(m.districtId);
      if (city != null && d?.city != city) return false;
      if (query.isEmpty) return true;
      return [m.nameAr, m.nameEn, d?.nameAr ?? '', d?.nameEn ?? ''].any((s) => s.toLowerCase().contains(query));
    }).toList();
    final withCounts = [for (final m in mosques) (m, lessons.where((l) => l.mosqueId == m.id).toList())]
      ..sort((a, b) => b.$2.length.compareTo(a.$2.length));
    final onMap = withCounts.where((e) => e.$1.hasPin && TaysirMap.covers(e.$1.latitude!, e.$1.longitude!));
    final offMap = withCounts.where((e) => !(e.$1.hasPin && TaysirMap.covers(e.$1.latitude!, e.$1.longitude!)) && e.$2.isNotEmpty);
    final pins = [
      for (final (m, items) in onMap)
        TaysirPin(id: m.id, lat: m.latitude!, lng: m.longitude!, label: m.name(lang), count: items.length, dim: items.isEmpty, live: items.any(c.isLiveNow))
    ];
    final sel = selected == null ? null : c.mosque(selected!);
    final selItems = sel == null ? <TaysirLesson>[] : lessons.where((l) => l.mosqueId == sel.id).toList();

    final controls = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TSeg<String>(full: true, small: true, value: range, onChanged: (v) => setState(() => range = v), options: [
        TSegOption('today', 'taysir.map.today'.tr()),
        TSegOption('week', 'taysir.map.week'.tr()),
        TSegOption('all', 'taysir.map.all'.tr()),
      ]),
      const SizedBox(height: 10),
      TChips([
        for (final x in TaysirVocab.mapCities)
          TChip(cityLabel(x), small: true, selected: city == x, onTap: () => setState(() => city = city == x ? null : x)),
      ]),
    ]);

    final selCard = sel == null
        ? null
        : TCard(
            highlight: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sel.name(lang), style: tStrong(15.5)),
                    Text('${c.district(sel.districtId)?.name(lang) ?? ''} · ${cityLabel(c.cityOfMosque(sel.id))}', style: tBody(13, color: TC.muted)),
                  ]),
                ),
                TIconButton(TGlyph.x, tooltip: 'taysir.close'.tr(), onPressed: () => setState(() => selected = null)),
              ]),
              FacilityList(sel.facilities, dense: true),
              const SizedBox(height: 10),
              if (selItems.isEmpty)
                Text('taysir.map.none_period'.tr(), style: tBody(13, color: TC.muted))
              else
                for (final l in selItems.take(3)) Padding(padding: const EdgeInsets.only(bottom: 6), child: LessonRow(l, showDate: true)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: [
                TButton('taysir.map.mosque_page'.tr(), kind: TBtn.minted, small: true, iconEnd: TGlyph.arrowEnd, onPressed: () => context.push('/taysir/mosques/${sel.id}')),
                if (sel.directions != null) TButton('taysir.lesson.directions'.tr(), small: true, icon: TGlyph.nav, onPressed: () => openExternal(sel.directions!)),
              ]),
            ]),
          );

    final listing = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${tPlural('mosques', withCounts.where((e) => e.$2.isNotEmpty).length)} ${'taysir.map.with_lessons'.tr()}', style: tBody(13, color: TC.muted)),
      const SizedBox(height: 8),
      for (final (m, items) in onMap.where((e) => e.$2.isNotEmpty))
        MosqueRow(
          mosque: m,
          count: items.length,
          subtitle: '${c.district(m.districtId)?.name(lang) ?? ''} · ${'taysir.map.next'.tr()} ${items.first.title(lang)}',
          selected: selected == m.id,
          live: items.any(c.isLiveNow),
          onTap: () => setState(() => selected = m.id),
        ),
      for (final (m, items) in offMap)
        MosqueRow(
          mosque: m,
          count: items.length,
          subtitle: '${cityLabel(c.cityOfMosque(m.id))} · ${'taysir.map.off_map'.tr()}',
          onTap: () => context.push('/taysir/mosques/${m.id}'),
        ),
    ]);

    final map = TaysirMap(pins: pins, selected: selected, onPin: (id) => setState(() => selected = id));
    final search = TSearchBox(hint: 'taysir.map.search_hint'.tr(), controller: q, onChanged: (_) => setState(() {}));

    if (wide) {
      return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 400,
          child: Container(
            decoration: const BoxDecoration(color: TC.card, border: BorderDirectional(end: BorderSide(color: TC.hair))),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('taysir.map.title'.tr(), style: tDisplay(26)),
              Text('taysir.map.subtitle'.tr(), style: tBody(14, color: TC.muted)),
              const SizedBox(height: 14),
              search,
              const SizedBox(height: 12),
              controls,
              if (selCard != null) ...[const SizedBox(height: 14), selCard],
              const SizedBox(height: 14),
              listing,
            ]),
          ),
        ),
        Expanded(child: map),
      ]);
    }
    return ListView(padding: EdgeInsets.zero, children: [
      SizedBox(
        height: 360,
        child: Stack(children: [
          Positioned.fill(child: map),
          Positioned(left: 12, right: 12, top: 12, child: search),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          controls,
          if (selCard != null) ...[const SizedBox(height: 14), selCard],
          const SizedBox(height: 14),
          listing,
        ]),
      ),
    ]);
  }
}
