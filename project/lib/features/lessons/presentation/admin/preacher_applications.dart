import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/lessons_models.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_modals.dart';
import '../lessons_widgets.dart';
import '../preacher_form_kit.dart';

/// People who applied to give lessons, waiting for an admin (ADR-020).
/// Approving creates his preacher card linked to his account; declining
/// needs a reason. Both email him after the 15 minutes in which the admin
/// can undo.
class ApplicationsSection extends StatelessWidget {
  const ApplicationsSection({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final waiting = c.pendingApplications;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TSectionHead('lessons.applications.title'.tr(), count: waiting.length),
      if (waiting.isEmpty)
        TEmpty(ok: true, icon: TGlyph.check, title: 'lessons.applications.none'.tr(), body: 'lessons.applications.none_body'.tr())
      else
        for (final a in waiting) Padding(padding: const EdgeInsets.only(bottom: 10), child: ApplicationCard(application: a)),
    ]);
  }
}

class ApplicationCard extends StatelessWidget {
  const ApplicationCard({super.key, required this.application});
  final PreacherApplication application;
  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final a = application;
    final m = c.mosque(a.mosqueId);
    final place = m != null
        ? '${m.name(lang)} · ${c.district(m.districtId)?.name(lang) ?? ''}'
        : 'lessons.applications.named'.tr(args: [a.newMosqueName ?? '—', c.district(a.newMosqueDistrict)?.name(lang) ?? '—']);
    Widget row(String label, String value, {bool ltr = false}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 120, child: Text(label, style: tBody(13, color: TC.muted, weight: FontWeight.w600))),
            Expanded(
                child: Text(value,
                    textDirection: ltr ? TextDirection.ltr : null,
                    textAlign: ltr && context.ar ? TextAlign.end : TextAlign.start,
                    style: tBody(13.5, color: TC.ink))),
          ]),
        );
    return TCard(
      key: ValueKey('application-${a.id}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          PreacherPhoto(name: a.name(lang), url: a.photoUrl, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name(lang), style: tStrong(16)),
              if (a.titleAr.isNotEmpty) Text(a.titleAr, style: tBody(13.5, color: TC.bronze, weight: FontWeight.w600)),
            ]),
          ),
          Text(agoText(a.createdAt), style: tBody(12, color: TC.faint)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TTag('lessons.applications.via_account'.tr(), tone: TTone.info, icon: TGlyph.user),
          TTag(cityLabel(a.city), tone: TTone.slate, icon: TGlyph.map),
          if (m == null) TTag('lessons.applications.new_mosque'.tr(), tone: TTone.warning, icon: TGlyph.mosque),
        ]),
        row('lessons.applications.first_mosque'.tr(), place),
        row('lessons.roster.languages'.tr(), a.languages.map((x) => LessonsVocab.languageNative[x] ?? x).join(' · ')),
        row('lessons.roster.phone'.tr(), a.phone, ltr: true),
        row('lessons.roster.email'.tr(), a.email, ltr: true),
        if (a.experience.isNotEmpty) row('lessons.apply.experience'.tr(), a.experience),
        if (a.bioAr.isNotEmpty) row('lessons.roster.bio_ar'.tr(), a.bioAr),
        if ((a.sampleUrl ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TButton('lessons.applications.sample'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.link,
                  onPressed: () => openExternal(Uri.parse(a.sampleUrl!))),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TButton('lessons.applications.approve'.tr(), key: ValueKey('approve-application-${a.id}'), kind: TBtn.minted, small: true,
              icon: TGlyph.check, onPressed: () => showApproveApplicationSheet(context, a)),
          TButton('lessons.applications.decline'.tr(), key: ValueKey('decline-application-${a.id}'), kind: TBtn.danger, small: true,
              icon: TGlyph.x, onPressed: () => showDeclineApplicationSheet(context, a)),
        ]),
      ]),
    );
  }
}

void _undoToast(BuildContext context, String message, String applicationId) {
  final c = context.read<LessonsController>();
  tToast(context, message,
      actionLabel: 'lessons.review.undo'.tr(),
      onAction: () => tRun(context, () => c.undoApplication(applicationId), success: 'lessons.review.undone'.tr()));
}

/// Confirms (or changes) his first mosque and his affiliation, then creates
/// his card.
Future<void> showApproveApplicationSheet(BuildContext context, PreacherApplication a) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  var city = a.mosqueId != null ? cityOr(c, a.mosqueId, a.city) : a.city;
  String? mosque = a.mosqueId;
  var aff = 'coop';
  return showTModal<void>(context,
      title: 'lessons.applications.approve_title'.tr(),
      subtitle: a.name(lang),
      wide: true,
      body: (ctx) => StatefulBuilder(
            builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TCallout(tone: TTone.info, icon: TGlyph.user, child: Text('lessons.applications.approve_body'.tr())),
              const SizedBox(height: 14),
              if (a.mosqueId == null && a.newMosqueName != null) ...[
                TCallout(
                    tone: TTone.warning,
                    icon: TGlyph.mosque,
                    child: Text('lessons.applications.will_add'.tr(
                        args: [a.newMosqueName!, c.district(a.newMosqueDistrict)?.name(lang) ?? '—']))),
                const SizedBox(height: 14),
              ],
              CityMosquePicker(
                city: city,
                mosqueId: mosque,
                hidden: true,
                required: a.mosqueId != null || a.newMosqueName == null,
                mosqueLabel: 'lessons.roster.home_mosque'.tr(),
                noneLabel: a.newMosqueName == null ? null : 'lessons.applications.use_named'.tr(args: [a.newMosqueName!]),
                onChanged: (ci, m) => set(() {
                  city = ci;
                  mosque = m;
                }),
              ),
              const SizedBox(height: 14),
              TField(
                label: 'lessons.roster.affiliation'.tr(),
                hint: 'lessons.roster.affiliation_hint'.tr(),
                child: DropdownButtonFormField<String>(
                  initialValue: aff,
                  isExpanded: true,
                  decoration: tInput(),
                  items: [for (final x in LessonsVocab.affiliations) DropdownMenuItem(value: x, child: Text('lessons.affiliation.$x'.tr()))],
                  onChanged: (v) => set(() => aff = v ?? aff),
                ),
              ),
            ]),
          ),
      footer: (ctx) => [
            TButton('lessons.cancel'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.applications.approve'.tr(), key: const ValueKey('approve-application-confirm'), kind: TBtn.minted,
                icon: TGlyph.check, onPressed: () async {
              if (mosque == null && a.newMosqueName == null) {
                tToast(ctx, 'lessons.preacher_admin.mosque_needed'.tr(), warn: true);
                return;
              }
              Navigator.of(ctx).pop();
              final id = await tRun(context, () async => await c.decideApplication(a.id, true, mosqueId: mosque, affiliation: aff) ?? '');
              if (id != null && context.mounted) _undoToast(context, 'lessons.applications.approved'.tr(args: [a.name(lang)]), a.id);
            }),
          ]);
}

/// Declines with a reason he will read in the email and in the app.
Future<void> showDeclineApplicationSheet(BuildContext context, PreacherApplication a) {
  final c = context.read<LessonsController>();
  final lang = context.lang;
  final reason = TextEditingController();
  return showTModal<void>(context,
      title: 'lessons.applications.decline_title'.tr(),
      subtitle: a.name(lang),
      body: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TField(
                label: 'lessons.applications.reason'.tr(),
                required: true,
                hint: 'lessons.applications.reason_hint'.tr(),
                child: TextField(
                    key: const ValueKey('decline-application-reason'),
                    controller: reason,
                    maxLines: 3,
                    maxLength: 600,
                    decoration: tInput())),
          ]),
      footer: (ctx) => [
            TButton('lessons.back'.tr(), kind: TBtn.ghost, onPressed: () => Navigator.of(ctx).pop()),
            TButton('lessons.applications.decline'.tr(), key: const ValueKey('decline-application-confirm'), kind: TBtn.danger,
                icon: TGlyph.x, onPressed: () async {
              if (reason.text.trim().length < 3) {
                tToast(ctx, 'lessons.applications.reason_needed'.tr(), warn: true);
                return;
              }
              Navigator.of(ctx).pop();
              final done = await tRun(context, () async {
                await c.decideApplication(a.id, false, reason: reason.text.trim());
                return true;
              });
              if (done == true && context.mounted) _undoToast(context, 'lessons.applications.declined'.tr(), a.id);
            }),
          ]);
}
