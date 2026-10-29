import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../auth/presentation/widgets/image_arrange_modal.dart';
import '../domain/lessons_vocab.dart';
import '../state/lessons_controller.dart';
import 'lessons_kit.dart';
import 'lessons_widgets.dart';

// Pieces shared by the preacher forms: an admin adding a preacher, a person
// applying, a preacher requesting a lesson, an admin approving one.

/// A preacher's photo in a circle, or his initial when there is none or it
/// cannot load (a deleted account's photo, say).
class PreacherPhoto extends StatelessWidget {
  const PreacherPhoto({super.key, required this.name, this.url, this.size = 44, this.ring = true});
  final String name;
  final String? url;
  final double size;
  final bool ring;
  @override
  Widget build(BuildContext context) {
    final fallback = TAvatar(name: name, size: size, ring: ring);
    final u = url?.trim() ?? '';
    Widget? image;
    if (u.startsWith('data:image/')) {
      // Sample data keeps an uploaded picture in its address.
      final bytes = Uri.tryParse(u)?.data?.contentAsBytes();
      if (bytes != null) image = Image.memory(bytes, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    } else if (u.startsWith('https://')) {
      image = Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
    }
    if (image == null) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: Semantics(label: name, image: true, child: image)),
    );
  }
}

/// Upload, replace or remove a photo. [application]: the applicant's own
/// folder; otherwise the admins' preacher photos. [onChanged] gets the new
/// address (null when removed); nothing is saved until the form is sent.
class PhotoField extends StatefulWidget {
  const PhotoField({super.key, required this.name, this.url, required this.onChanged, this.application = false, this.large = false});
  final String name;
  final String? url;
  final ValueChanged<String?> onChanged;
  final bool application, large;
  @override
  State<PhotoField> createState() => _PhotoFieldState();
}

class _PhotoFieldState extends State<PhotoField> {
  bool busy = false;

  Future<void> _pick() async {
    final c = context.read<LessonsController>();
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800, maxHeight: 800);
    } catch (_) {
      if (mounted) tToast(context, 'lessons.photo.cannot_read'.tr(), warn: true);
      return;
    }
    if (file == null || !mounted) return;
    final raw = await file.readAsBytes();
    if (!mounted) return;
    final cropped = await ImageArrangeModal.show(
        context: context, imagePath: file.path, imageBytes: raw, arrangeType: ImageArrangeType.avatarCircle);
    if (!mounted) return;
    await upload(cropped ?? raw, c);
  }

  /// Visible for tests: uploads [bytes] as the photo.
  Future<void> upload(Uint8List bytes, LessonsController c) async {
    setState(() => busy = true);
    final url = await tRun(context, () => c.uploadPhoto(bytes, application: widget.application));
    if (!mounted) return;
    setState(() => busy = false);
    if (url != null) widget.onChanged(url);
  }

  @override
  Widget build(BuildContext context) {
    final has = (widget.url ?? '').isNotEmpty;
    return Row(children: [
      busy
          ? SizedBox(
              width: widget.large ? 72 : 56,
              height: widget.large ? 72 : 56,
              child: const Center(child: CircularProgressIndicator(color: TC.gold, strokeWidth: 2.5)))
          : PreacherPhoto(name: widget.name, url: widget.url, size: widget.large ? 72 : 56),
      const SizedBox(width: 14),
      Expanded(
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          TButton(has ? 'lessons.photo.change'.tr() : 'lessons.photo.upload'.tr(),
              key: const ValueKey('photo-upload'), icon: TGlyph.upload, large: widget.large, onPressed: busy ? null : _pick),
          if (has)
            TButton('lessons.photo.remove'.tr(), kind: TBtn.ghost, icon: TGlyph.x, large: widget.large,
                onPressed: busy ? null : () => widget.onChanged(null)),
        ]),
      ),
    ]);
  }
}

/// City, then (optionally) area, then mosque: only the mosques of the chosen
/// city (and area) are offered. [onNewMosque] lets an applicant name a
/// mosque that is not listed (he gives its area); [onAddMosque] lets an admin
/// add one to the directory and returns its id. [hidden] lists hidden
/// mosques too (admins). [noneLabel] offers "no mosque" under that label.
class CityMosquePicker extends StatefulWidget {
  const CityMosquePicker({
    super.key,
    required this.city,
    required this.mosqueId,
    required this.onChanged,
    this.hidden = false,
    this.required = true,
    this.large = false,
    this.mosqueLabel,
    this.noneLabel,
    this.newMosqueName,
    this.newMosqueDistrict,
    this.onNewMosque,
    this.onAddMosque,
  });
  final String city;
  final String? mosqueId;
  final void Function(String city, String? mosqueId) onChanged;
  final bool hidden, required, large;
  final String? mosqueLabel, noneLabel;
  final String? newMosqueName, newMosqueDistrict;
  final void Function(String? name, String? districtId)? onNewMosque;
  final Future<String?> Function(String city)? onAddMosque;
  @override
  State<CityMosquePicker> createState() => _CityMosquePickerState();
}

class _CityMosquePickerState extends State<CityMosquePicker> {
  String? area;
  late final TextEditingController newName = TextEditingController(text: widget.newMosqueName ?? '');

  bool get naming => widget.onNewMosque != null && widget.newMosqueName != null;

  @override
  void dispose() {
    newName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final city = widget.city;
    final areas = c.districtsOf(city);
    final mosques = c.mosquesIn(city, lang, district: area, hidden: widget.hidden);
    // A chosen mosque outside the filter stays offered, so the field never
    // loses its value.
    final chosen = c.mosque(widget.mosqueId);
    if (chosen != null && !mosques.any((m) => m.id == chosen.id) && c.cityOfMosque(chosen.id) == city) mosques.insert(0, chosen);
    final value = mosques.any((m) => m.id == widget.mosqueId) ? widget.mosqueId : null;
    final text = widget.large ? tBody(16, color: TC.ink) : null;
    final gap = SizedBox(height: widget.large ? 16 : 12);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      TField(
        label: 'lessons.place.city'.tr(),
        required: widget.required,
        child: DropdownButtonFormField<String>(
          key: const ValueKey('picker-city'),
          initialValue: city,
          isExpanded: true,
          decoration: tInput(),
          style: text,
          items: [for (final x in LessonsVocab.cities) DropdownMenuItem(value: x, child: Text(cityLabel(x)))],
          onChanged: (v) {
            if (v == null || v == city) return;
            setState(() => area = null);
            if (naming) widget.onNewMosque!(newName.text, null);
            widget.onChanged(v, null);
          },
        ),
      ),
      if (areas.isNotEmpty) ...[
        gap,
        Text('lessons.place.area'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700, height: 1.4)),
        const SizedBox(height: 6),
        TChips([
          TChip('lessons.all'.tr(), small: !widget.large, selected: area == null, onTap: () => setState(() => area = null)),
          for (final d in areas)
            TChip(d.name(lang), small: !widget.large, selected: area == d.id, onTap: () => setState(() => area = area == d.id ? null : d.id)),
        ]),
      ],
      gap,
      if (!naming)
        TField(
          label: widget.mosqueLabel ?? 'lessons.place.mosque'.tr(),
          required: widget.required,
          hint: mosques.isEmpty ? 'lessons.place.none_listed'.tr(args: [cityLabel(city)]) : null,
          child: DropdownButtonFormField<String>(
            key: ValueKey('picker-mosque-$city-$area-${mosques.length}'),
            initialValue: value,
            isExpanded: true,
            hint: Text('lessons.place.choose'.tr()),
            decoration: tInput(),
            style: text,
            items: [
              if (widget.noneLabel != null) DropdownMenuItem<String>(value: null, child: Text(widget.noneLabel!)),
              for (final m in mosques)
                DropdownMenuItem(
                    value: m.id,
                    child: Text('${m.name(lang)} · ${c.district(m.districtId)?.name(lang) ?? ''}${m.verified ? '' : ' (${'lessons.mosques.hidden'.tr()})'}',
                        overflow: TextOverflow.ellipsis)),
            ],
            onChanged: mosques.isEmpty ? null : (v) => widget.onChanged(city, v),
          ),
        ),
      if (naming) ...[
        TField(
          label: 'lessons.place.new_name'.tr(),
          required: true,
          child: TextField(
              key: const ValueKey('picker-new-mosque'),
              controller: newName,
              maxLength: 120,
              style: text,
              decoration: tInput(hint: 'lessons.place.new_name_hint'.tr()),
              onChanged: (v) => widget.onNewMosque!(v, widget.newMosqueDistrict)),
        ),
        TField(
          label: 'lessons.place.new_area'.tr(),
          required: true,
          child: DropdownButtonFormField<String>(
            key: ValueKey('picker-new-area-$city'),
            initialValue: areas.any((d) => d.id == widget.newMosqueDistrict) ? widget.newMosqueDistrict : null,
            isExpanded: true,
            hint: Text('lessons.place.choose_area'.tr()),
            decoration: tInput(),
            style: text,
            items: [for (final d in areas) DropdownMenuItem(value: d.id, child: Text(d.name(lang)))],
            onChanged: (v) => widget.onNewMosque!(newName.text, v),
          ),
        ),
      ],
      if (widget.onNewMosque != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('picker-not-listed'),
            onPressed: () {
              if (naming) {
                widget.onNewMosque!(null, null);
              } else {
                widget.onChanged(city, null);
                widget.onNewMosque!(newName.text, area ?? areas.firstOrNull?.id);
              }
            },
            child: Text(naming ? 'lessons.place.pick_listed'.tr() : 'lessons.place.not_listed'.tr(),
                style: tBody(widget.large ? 15 : 13.5, color: TC.bronze, weight: FontWeight.w700)),
          ),
        ),
      if (widget.onAddMosque != null)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('picker-add-mosque'),
            onPressed: () async {
              final id = await widget.onAddMosque!(city);
              if (id != null && mounted) {
                final m = c.mosque(id);
                widget.onChanged(m == null ? city : c.cityOfMosque(id), id);
              }
            },
            icon: const TIcon(TGlyph.plus, size: 15, color: TC.bronze),
            label: Text('lessons.place.add_mosque'.tr(), style: tBody(13.5, color: TC.bronze, weight: FontWeight.w700)),
          ),
        ),
    ]);
  }
}

/// The city of [mosqueId], or [fallback].
String cityOr(LessonsController c, String? mosqueId, String fallback) {
  if (c.mosque(mosqueId) == null) return fallback;
  final city = c.cityOfMosque(mosqueId);
  return city.isEmpty ? fallback : city;
}
