import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/lessons_names.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_widgets.dart';
import 'place_option_widgets.dart';

/// The Mosques page's Lists view: the cities, areas, topics, languages and
/// audiences, each with a way to add, rename and delete. The built-in ones
/// have fixed names and stay; an area can be renamed and deleted if empty.
class PlaceLists extends StatelessWidget {
  const PlaceLists({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final cities = LessonsNames.cityIds.where((x) => x != 'other').toList();

    Widget row({required Key key, required String label, String? note, VoidCallback? onEdit, VoidCallback? onDelete, bool indent = false}) => Padding(
          key: key,
          padding: EdgeInsetsDirectional.only(start: indent ? 20 : 0, bottom: 6),
          child: TCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(children: [
              Expanded(child: Text(label, style: tBody(14, color: TC.ink, weight: FontWeight.w600))),
              if (note != null) Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Text(note, style: tBody(12, color: TC.muted))),
              if (onEdit != null) TIconButton(TGlyph.edit, key: ValueKey('${(key as ValueKey).value}-edit'), tooltip: 'lessons.lesson.edit'.tr(), onPressed: onEdit),
              if (onDelete != null) TIconButton(TGlyph.trash, key: ValueKey('${(key as ValueKey).value}-delete'), tooltip: 'lessons.mosques.remove'.tr(), onPressed: onDelete),
              if (onEdit == null && onDelete == null) TTag('lessons.lists.built_in'.tr(), tone: TTone.slate),
            ]),
          ),
        );

    Widget optionSection(String kind, String title) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: TSectionHead(title)),
            TButton('lessons.lists.add'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.plus, key: ValueKey('lists-add-$kind'), onPressed: () => showAddOptionSheet(context, kind)),
          ]),
          const SizedBox(height: 6),
          for (final o in LessonsNames.optionsOf(kind))
            row(
              key: ValueKey('list-$kind-${o.code}'),
              label: o.builtIn ? (kind == 'language' ? languageNativeLabel(o.code) : _builtInLabel(kind, o.code)) : o.name(lang),
              note: o.builtIn || o.permanent ? null : 'lessons.lists.one_time'.tr(),
              onEdit: o.builtIn
                  ? null
                  : () => _editName(context, title: 'lessons.lists.edit'.tr(), nameAr: o.nameAr, nameEn: o.nameEn, keep: o.permanent, withKeep: true,
                      save: (ar, en, keep) => c.updateOption(kind, o.code, ar, en, permanent: keep)),
              onDelete: o.builtIn ? null : () => _confirmDelete(context, o.name(lang), () => c.deleteOption(kind, o.code)),
            ),
          const SizedBox(height: 14),
        ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.lists.body'.tr(), style: tBody(14, color: TC.muted)),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: TSectionHead('lessons.lists.cities'.tr())),
        TButton('lessons.lists.add'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.plus, key: const ValueKey('lists-add-city'), onPressed: () => showAddPlaceSheet(context)),
      ]),
      const SizedBox(height: 6),
      for (final id in cities) ...[
        row(
          key: ValueKey('list-city-$id'),
          label: cityLabel(id),
          onEdit: LessonsVocab.cities.contains(id)
              ? null
              : () => _editName(context, title: 'lessons.lists.edit'.tr(), nameAr: c.catalog.cities[id]?.nameAr ?? '', nameEn: c.catalog.cities[id]?.nameEn ?? '',
                  save: (ar, en, _) => c.updateCity(id, ar, en)),
          onDelete: LessonsVocab.cities.contains(id)
              ? null
              : () => c.districtsOf(id).isNotEmpty
                  ? tToast(context, 'lessons.lists.city_has_areas'.tr(), warn: true)
                  : _confirmDelete(context, cityLabel(id), () => c.deleteCity(id)),
        ),
        for (final d in c.districtsOf(id))
          row(
            key: ValueKey('list-district-${d.id}'),
            indent: true,
            label: d.name(lang),
            note: tPlural('mosques', c.catalog.mosques.values.where((m) => m.districtId == d.id).length),
            onEdit: () => _editName(context, title: 'lessons.lists.edit'.tr(), nameAr: d.nameAr, nameEn: d.nameEn == d.nameAr ? '' : d.nameEn,
                save: (ar, en, _) => c.updateDistrict(d.id, ar, en)),
            onDelete: () => c.catalog.mosques.values.any((m) => m.districtId == d.id)
                ? tToast(context, 'lessons.lists.area_has_mosques'.tr(), warn: true)
                : _confirmDelete(context, d.name(lang), () => c.deleteDistrict(d.id)),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 20, bottom: 10),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TButton('lessons.lists.add_area'.tr(args: [cityLabel(id)]),
                small: true, kind: TBtn.ghost, icon: TGlyph.plus, key: ValueKey('lists-add-area-$id'), onPressed: () => showAddPlaceSheet(context, cityId: id)),
          ),
        ),
      ],
      const SizedBox(height: 10),
      optionSection('topic', 'lessons.submit.subject'.tr()),
      optionSection('language', 'lessons.submit.language'.tr()),
      optionSection('audience', 'lessons.submit.audience'.tr()),
    ]);
  }
}

String _builtInLabel(String kind, String code) => kind == 'topic' ? topicLabel(code) : audienceLabel(code);

/// A rename window: Arabic and English names, and (for options) whether it is kept.
Future<void> _editName(BuildContext context,
    {required String title, required String nameAr, required String nameEn, bool keep = true, bool withKeep = false, required Future<void> Function(String ar, String en, bool keep) save}) {
  final ar = TextEditingController(text: nameAr), en = TextEditingController(text: nameEn);
  var kept = keep;
  return showTModal<void>(context,
      title: title,
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TField(label: 'lessons.mosques.name_ar'.tr(), required: true, child: TextField(key: const ValueKey('edit-name-ar'), controller: ar, decoration: tInput())),
              const SizedBox(height: 12),
              TField(
                  label: '${'lessons.mosques.name_en'.tr()} (${'lessons.optional'.tr()})',
                  child: TextField(key: const ValueKey('edit-name-en'), controller: en, textDirection: TextDirection.ltr, decoration: tInput())),
              if (withKeep)
                CheckboxListTile(
                  key: const ValueKey('edit-keep'),
                  value: kept,
                  onChanged: (v) => set(() => kept = v ?? false),
                  activeColor: TC.gold,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text('lessons.add.option_keep'.tr(), style: tBody(14, color: TC.ink, weight: FontWeight.w600)),
                ),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.save'.tr(), key: const ValueKey('edit-save'), kind: TBtn.minted, icon: TGlyph.check, onPressed: () async {
              if (ar.text.trim().length < 2) return tToast(ctx, 'lessons.add.name_needed'.tr(), warn: true);
              final done = await tRun<bool>(context, () async {
                await save(ar.text.trim(), en.text.trim(), kept);
                return true;
              }, success: 'lessons.roster.saved'.tr());
              if (done == true && ctx.mounted) Navigator.of(ctx).pop();
            }),
          ]);
}

Future<void> _confirmDelete(BuildContext context, String name, Future<void> Function() delete) => showTModal<void>(context,
    title: 'lessons.mosques.remove_title'.tr(),
    subtitle: name,
    body: (ctx) => Text('lessons.lists.delete_body'.tr(), style: tBody(14, color: TC.ink2)),
    footer: (ctx) => [
          TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
          TButton('lessons.mosques.remove'.tr(), key: const ValueKey('delete-confirm'), kind: TBtn.danger, icon: TGlyph.trash, onPressed: () async {
            final done = await tRun<bool>(context, () async {
              await delete();
              return true;
            }, success: 'lessons.lists.deleted'.tr());
            if (done == true && ctx.mounted) Navigator.of(ctx).pop();
          }),
        ]);
