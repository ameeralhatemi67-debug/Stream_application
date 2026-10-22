import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/lessons_models.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';

/// Admins add a coordinator, change the organizations they coordinate, or
/// remove them, across every organization (taysir_set_coordinator_orgs on
/// the server, admin tier only).
class AdminCoordinatorsCard extends StatelessWidget {
  const AdminCoordinatorsCard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final orgs = c.adminOrganizations;
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 12, runSpacing: 10, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('lessons.coord.title'.tr(), style: tStrong(17)),
              Text('lessons.coord.sub'.tr(), style: tBody(13, color: TC.muted)),
            ]),
          ),
          TButton('lessons.coord.add'.tr(),
              kind: TBtn.minted, small: true, icon: TGlyph.plus, onPressed: orgs.isEmpty ? null : () => showCoordinatorEditor(context)),
        ]),
        const SizedBox(height: 12),
        if (orgs.isEmpty)
          TCallout(tone: TTone.info, icon: TGlyph.info, child: Text('lessons.coord.no_orgs'.tr()))
        else if (c.coordinators.isEmpty)
          Text('lessons.coord.none'.tr(), style: tBody(13.5, color: TC.muted))
        else
          for (final k in c.coordinators) _CoordinatorRow(k),
      ]),
    );
  }
}

class _CoordinatorRow extends StatelessWidget {
  const _CoordinatorRow(this.k);
  final LessonsCoordinator k;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.hair))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TAvatar(name: k.name(lang), size: 38, ring: false),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k.name(lang), style: tStrong(14)),
              if (k.email.isNotEmpty && k.email != k.name(lang))
                Text(k.email, textDirection: TextDirection.ltr, style: tBody(12.5, color: TC.muted, height: 1.4)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final id in k.organizationIds)
                  TTag(c.organization(id)?.name(lang) ?? id,
                      tone: (c.organization(id)?.enabled ?? false) ? TTone.gold : TTone.slate, icon: TGlyph.key),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TButton('lessons.coord.edit'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.edit,
              onPressed: () => showCoordinatorEditor(context, existing: k)),
          TButton('lessons.coord.remove'.tr(), small: true, kind: TBtn.danger, icon: TGlyph.x,
              onPressed: () => confirmRemoveCoordinator(context, k)),
        ]),
      ]),
    );
  }
}

/// Add a coordinator (search an account, choose organizations) or change an
/// existing coordinator's organizations.
Future<void> showCoordinatorEditor(BuildContext context, {LessonsCoordinator? existing}) => showTModal<void>(
      context,
      title: existing == null ? 'lessons.coord.add_title'.tr() : 'lessons.coord.edit_title'.tr(),
      subtitle: existing?.name(context.lang),
      body: (ctx) => _CoordinatorEditor(existing: existing, page: context),
    );

Future<void> confirmRemoveCoordinator(BuildContext context, LessonsCoordinator k) {
  final c = context.read<LessonsController>();
  return showTModal<void>(context,
      title: 'lessons.coord.remove_title'.tr(args: [k.name(context.lang)]),
      body: (ctx) => Text('lessons.coord.remove_body'.tr(), style: tBody(14, color: TC.muted)),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.coord.remove'.tr(), kind: TBtn.danger, icon: TGlyph.x, onPressed: () async {
              Navigator.of(ctx).pop();
              await tRun(context, () => c.setCoordinatorOrganizations(k.profileId, const []), success: 'lessons.coord.removed'.tr());
            }),
          ]);
}

class _CoordinatorEditor extends StatefulWidget {
  const _CoordinatorEditor({required this.existing, required this.page});
  final LessonsCoordinator? existing;

  /// The console page: toasts and the write outlive the sheet.
  final BuildContext page;
  @override
  State<_CoordinatorEditor> createState() => _CoordinatorEditorState();
}

class _CoordinatorEditorState extends State<_CoordinatorEditor> {
  final query = TextEditingController();
  LessonsAccount? account;
  late final Set<String> picked = {...?widget.existing?.organizationIds};
  List<LessonsAccount>? results;
  bool searching = false, tried = false;

  @override
  void initState() {
    super.initState();
    final k = widget.existing;
    if (k != null) account = LessonsAccount(id: k.profileId, nameAr: k.nameAr, nameEn: k.nameEn, email: k.email);
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => searching = true);
    final found = await tRun(context, () => context.read<LessonsController>().searchAccounts(query.text));
    if (!mounted) return;
    setState(() {
      searching = false;
      results = found ?? const [];
    });
  }

  void _choose(LessonsAccount a) {
    final c = context.read<LessonsController>();
    // Choosing someone who already coordinates edits their organizations.
    final current = c.coordinators.where((k) => k.profileId == a.id).firstOrNull;
    setState(() {
      account = a;
      picked
        ..clear()
        ..addAll(current?.organizationIds ?? const []);
    });
  }

  Future<void> _save() async {
    setState(() => tried = true);
    final a = account;
    if (a == null || picked.isEmpty) return;
    final c = context.read<LessonsController>();
    final page = widget.page;
    Navigator.of(context).pop();
    await tRun(page, () => c.setCoordinatorOrganizations(a.id, picked.toList()), success: 'lessons.coord.saved'.tr());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final a = account;
    final children = <Widget>[];
    if (a == null) {
      children.addAll([
        TField(
          label: 'lessons.coord.account'.tr(),
          child: Row(children: [
            Expanded(child: TSearchBox(hint: 'lessons.coord.search_hint'.tr(), controller: query, onSubmitted: (_) => _search())),
            const SizedBox(width: 8),
            TButton('lessons.coord.search'.tr(), small: true, icon: TGlyph.search, onPressed: searching ? null : _search),
          ]),
        ),
        const SizedBox(height: 10),
        if (searching)
          const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: TC.gold)))
        else if (results != null && results!.isEmpty)
          Text('lessons.coord.no_results'.tr(), style: tBody(13.5, color: TC.muted))
        else
          for (final r in results ?? const <LessonsAccount>[])
            TOptionRow(title: r.name(lang), subtitle: r.email, leading: TGlyph.user, selected: false, onTap: () => _choose(r)),
      ]);
    } else {
      children.addAll([
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: TC.tint, borderRadius: BorderRadius.circular(TC.r)),
          child: Row(children: [
            TAvatar(name: a.name(lang), size: 34, ring: false),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name(lang), style: tStrong(14.5)),
                if (a.email.isNotEmpty && a.email != a.name(lang))
                  Text(a.email, textDirection: TextDirection.ltr, style: tBody(12.5, color: TC.muted, height: 1.4)),
              ]),
            ),
            if (widget.existing == null)
              TButton('lessons.coord.change'.tr(), small: true, kind: TBtn.ghost, onPressed: () => setState(() => account = null)),
          ]),
        ),
        const SizedBox(height: 14),
        Text('lessons.coord.orgs'.tr(), style: tBody(13, color: TC.ink2, weight: FontWeight.w700)),
        for (final o in c.adminOrganizations)
          TToggleRow(
            label: o.name(lang),
            desc: o.enabled ? null : 'lessons.coord.lessons_off'.tr(),
            icon: TGlyph.users,
            value: picked.contains(o.id),
            onChanged: (v) => setState(() => v ? picked.add(o.id) : picked.remove(o.id)),
          ),
        if (tried && picked.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('lessons.coord.pick_org'.tr(), style: tBody(13, color: TC.dangerFg)),
          ),
        const SizedBox(height: 14),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
          children: [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(context).pop()),
            TButton('lessons.save'.tr(), kind: TBtn.minted, icon: TGlyph.check, onPressed: _save),
          ],
        ),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
