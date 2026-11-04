import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../map/models/map_tricity_domain.dart';
import '../../domain/map_link.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_map.dart';
import '../lessons_modals.dart';

/// Where a mosque is: paste a Google Maps link (or coordinates) and the pin
/// jumps there, or tap the map. "Open Google Maps" starts the search for the
/// admin. The other mosques are on the map so nothing is added twice.
class MosqueLocationField extends StatefulWidget {
  const MosqueLocationField({super.key, required this.value, required this.onChanged, required this.searchText, this.excludeId, this.height = 260});
  final (double, double)? value;
  final ValueChanged<(double, double)> onChanged;

  /// What Google Maps is asked for: the mosque's name, area and city.
  final String Function() searchText;

  /// The mosque being edited, left out of the other pins.
  final String? excludeId;
  final double height;
  @override
  State<MosqueLocationField> createState() => _MosqueLocationFieldState();
}

class _MosqueLocationFieldState extends State<MosqueLocationField> {
  final paste = TextEditingController();
  bool busy = false;
  String? problem;

  /// The last place this field set from the text, so a tap on the map (a new
  /// place) clears a link that no longer matches.
  (double, double)? applied;

  @override
  void didUpdateWidget(MosqueLocationField old) {
    super.didUpdateWidget(old);
    if (widget.value != applied && widget.value != old.value && paste.text.isNotEmpty) {
      paste.clear();
      problem = null;
    }
  }

  @override
  void dispose() {
    paste.dispose();
    super.dispose();
  }

  void set((double, double) p) {
    applied = p;
    widget.onChanged(p);
  }

  Future<void> read(String raw, {bool submitted = false}) async {
    final text = raw.trim();
    if (problem != null) setState(() => problem = null);
    if (text.isEmpty) return;
    final p = MapLink.parse(text);
    if (p != null) {
      set(p);
      return;
    }
    if (MapLink.isShort(text)) {
      setState(() => busy = true);
      final found = await context.read<LessonsController>().resolveMapLink(MapLink.firstUrl(text)!.toString());
      if (!mounted || paste.text.trim() != text) return;
      setState(() {
        busy = false;
        problem = found == null ? 'lessons.mosques.link_short_failed' : null;
      });
      if (found != null) set(found);
      return;
    }
    // Typing a name is not a mistake: only say so for what looks like a link.
    if (submitted || text.contains('http') || text.length >= 24) setState(() => problem = 'lessons.mosques.link_unreadable');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final v = widget.value;
    final others = [
      for (final m in c.catalog.mosques.values)
        if (m.hasPin && m.id != widget.excludeId) MosquePin(id: m.id, lat: m.latitude!, lng: m.longitude!, label: m.name(lang)),
    ];
    final field = TextField(
      key: const ValueKey('mosque-link'),
      controller: paste,
      onChanged: read,
      onSubmitted: (t) => read(t, submitted: true),
      decoration: tInput(
        hint: 'lessons.mosques.link_hint'.tr(),
        suffix: busy ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TC.gold))) : null,
      ),
    );
    final google = TButton('lessons.mosques.find_on_google'.tr(),
        key: const ValueKey('mosque-find-google'),
        kind: TBtn.ghost,
        icon: TGlyph.map,
        onPressed: () => openExternal(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(widget.searchText())}')));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('lessons.mosques.location'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
      const SizedBox(height: 6),
      LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 520
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: field), const SizedBox(width: 8), google])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                field,
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerStart, child: google),
              ]),
      ),
      const SizedBox(height: 6),
      if (problem != null)
        Text(problem!.tr(), key: const ValueKey('mosque-link-problem'), style: tBody(12.5, color: TC.warnFg, height: 1.4))
      else if (v == null)
        Text('lessons.mosques.link_steps'.tr(), style: tBody(12.5, color: TC.muted, height: 1.4))
      else
        Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          TTag('lessons.mosques.location_set'.tr(), key: const ValueKey('mosque-location-set'), tone: TTone.success, icon: TGlyph.check),
          if (!kTricityNavigationExtent.contains(v.$1, v.$2))
            Text('lessons.mosques.location_outside'.tr(), style: tBody(12.5, color: TC.muted, height: 1.4)),
        ]),
      const SizedBox(height: 8),
      SizedBox(
          height: widget.height,
          child: MosquePinPicker(value: v, others: others, onPick: (p) {
            applied = null;
            widget.onChanged(p);
          })),
      const SizedBox(height: 4),
      Text('lessons.mosques.pin'.tr(), style: tBody(12.5, color: TC.muted, height: 1.4)),
    ]);
  }
}
