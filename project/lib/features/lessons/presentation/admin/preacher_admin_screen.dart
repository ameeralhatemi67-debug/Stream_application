import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart';
import '../lessons_modals.dart';
import '../lessons_widgets.dart';
import 'lessons_admin_modals.dart';
import 'lessons_admin_screen.dart' show PreacherEditCard;
import 'lessons_admin_shell.dart';

/// One preacher, as admins manage him: his card, his private number, the
/// links he can use, changes he proposed, and his lessons. Everything here
/// works whether or not he ever opens a link.
class LessonsAdminPreacherScreen extends StatefulWidget {
  const LessonsAdminPreacherScreen({super.key, required this.id});
  final String id;
  @override
  State<LessonsAdminPreacherScreen> createState() => _LessonsAdminPreacherScreenState();
}

class _LessonsAdminPreacherScreenState extends State<LessonsAdminPreacherScreen> {
  late Future<List<PreacherKey>> keys = _loadKeys();
  String? phone;

  Future<List<PreacherKey>> _loadKeys() =>
      context.read<LessonsController>().loadKeys(widget.id).catchError((Object _) => <PreacherKey>[]);

  void _reloadKeys() {
    if (!mounted) return;
    setState(() {
      keys = _loadKeys();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController>();
    final lang = context.lang;
    final p = c.preacher(widget.id);
    if (c.loaded && p == null) {
      return LessonsAdminShell(current: 'preachers', title: 'lessons.preacher_admin.title'.tr(), children: [
        TEmpty(icon: TGlyph.user, title: 'lessons.preacher.not_found'.tr()),
      ]);
    }
    if (p == null) return LessonsAdminShell(current: 'preachers', title: 'lessons.preacher_admin.title'.tr(), children: const []);
    final entry = c.rosterEntry(p.id);
    final edit = c.pendingEdits.where((e) => e.preacherId == p.id).firstOrNull;
    final requests = c.requestsOfPreacher(p.id);
    final upcoming = c.upcomingWhere((l) => l.preacherId == p.id);

    final card = TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          p.photoUrl == null
              ? TAvatar(name: p.name(lang), size: 64)
              : CircleAvatar(radius: 32, backgroundColor: TC.tint, backgroundImage: resolveImageProviderOrNull(p.photoUrl)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name(lang), style: tDisplay(22)),
              if (p.title(lang).isNotEmpty) Text(p.title(lang), style: tBody(14, color: TC.bronze, weight: FontWeight.w600)),
              Text('${cityLabel(p.city)} · ${'lessons.affiliation.${p.affiliation}'.tr()} · ${p.languages.map((x) => LessonsVocab.languageNative[x] ?? x).join(' · ')}',
                  style: tBody(13, color: TC.muted)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                p.listed
                    ? TTag('lessons.preacher_admin.public'.tr(), tone: TTone.success, icon: TGlyph.eye)
                    : TTag('lessons.preacher_admin.hidden'.tr(), tone: TTone.slate, icon: TGlyph.lock),
                if (p.linkedProfileId != null) TTag('lessons.preacher_admin.has_account'.tr(), tone: TTone.info, icon: TGlyph.radio),
              ]),
            ]),
          ),
        ]),
        if (p.bio(lang).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(p.bio(lang), style: tBody(14, color: TC.ink2)),
        ],
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          TButton('lessons.preacher_admin.edit_card'.tr(), icon: TGlyph.edit,
              onPressed: () => showPreacherEditSheet(context, preacher: p, phoneMask: entry?.phoneMask)),
          TButton('lessons.admin.add_lesson'.tr(), kind: TBtn.minted, icon: TGlyph.plus,
              onPressed: () => context.push('/admin/lessons/add?preacher=${p.id}')),
          TButton('lessons.preacher_admin.public_page'.tr(), kind: TBtn.ghost, icon: TGlyph.eye,
              onPressed: () => context.push('/lessons/preachers/${p.id}')),
        ]),
      ]),
    );

    final contact = TCard(
      child: Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          const TIcon(TGlyph.phone, size: 18, color: TC.goldIcon),
          const SizedBox(width: 10),
          Flexible(
            child: Text(phone ?? entry?.phoneMask ?? 'lessons.preacher_admin.no_phone'.tr(),
                textDirection: (phone ?? entry?.phoneMask) != null ? TextDirection.ltr : null, style: tStrong(15)),
          ),
        ]),
        if (entry?.phoneMask != null && phone == null)
          TButton('lessons.roster.show_number'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.eye, onPressed: () async {
            final n = await tRun(context, () => c.revealPhone(p.id), success: 'lessons.roster.logged'.tr());
            if (mounted && n != null) setState(() => phone = n);
          }),
      ]),
    );

    final links = TCard(
      key: const ValueKey('preacher-links'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('lessons.links.title'.tr(), style: tStrong(17))),
          TButton('lessons.links.send'.tr(), kind: TBtn.minted, small: true, icon: TGlyph.send, onPressed: () async {
            await showNewLinkSheet(context, p);
            _reloadKeys();
          }),
        ]),
        const SizedBox(height: 6),
        Text('lessons.links.body'.tr(), style: tBody(13.5, color: TC.muted)),
        const SizedBox(height: 10),
        FutureBuilder<List<PreacherKey>>(
          future: keys,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(color: TC.gold)));
            }
            final list = snap.data ?? const <PreacherKey>[];
            if (list.isEmpty) return Text('lessons.links.none_yet'.tr(), style: tBody(13.5, color: TC.ink2));
            final now = DateTime.now();
            return Column(children: [
              for (final k in list)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: TC.hair))),
                  child: Row(children: [
                    TIcon(k.kind == 'once' ? TGlyph.phone : TGlyph.clock, size: 18, color: TC.goldIcon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text('lessons.links.${k.kind}'.tr(), style: tStrong(14)),
                          TTag('lessons.links.state_${k.state(now)}'.tr(), tone: _stateTone(k.state(now))),
                        ]),
                        Text(_keyDetail(k, lang), style: tBody(12.5, color: TC.muted, height: 1.4)),
                        if (k.note.isNotEmpty) Text(k.note, style: tBody(12.5, color: TC.ink2)),
                      ]),
                    ),
                    if (k.usable(now))
                      TButton('lessons.links.revoke'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.x, onPressed: () async {
                        await tRun(context, () => c.revokeKey(k.id), success: 'lessons.links.revoked'.tr());
                        _reloadKeys();
                      }),
                  ]),
                ),
            ]);
          },
        ),
      ]),
    );

    return LessonsAdminShell(current: 'preachers', title: p.name(lang), children: [
      card,
      contact,
      links,
      if (edit != null) ...[
        TSectionHead('lessons.approvals.edits'.tr(), count: 1),
        PreacherEditCard(edit: edit),
      ],
      TSectionHead('lessons.approvals.requests'.tr(), count: requests.where((r) => r.status == 'pending').length),
      if (requests.isEmpty)
        Text('lessons.preacher_admin.no_requests'.tr(), style: tBody(13.5, color: TC.muted))
      else
        for (final r in requests)
          TCard(
            padding: const EdgeInsets.all(14),
            onTap: r.status == 'pending' ? () => context.go('/admin/lessons/approvals') : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                StatusTag(r.status),
                TypeTag(r.first.type),
                if (r.isSeries) TTag(tPlural('sessions', r.items.length), tone: TTone.slate, icon: TGlyph.repeat),
              ]),
              const SizedBox(height: 6),
              Text(r.first.title(lang), style: tStrong(15)),
              Text(whenOf(c, r.first, lang), style: tBody(13, color: TC.muted)),
              if (r.status == 'rejected' && r.first.rejectionReason != null)
                Text('${'lessons.mine.reason'.tr()} ${r.first.rejectionReason}', style: tBody(13, color: TC.dangerFg)),
            ]),
          ),
      TSectionHead('lessons.preacher_admin.upcoming'.tr(), count: upcoming.length),
      if (upcoming.isEmpty)
        Text('lessons.preacher_admin.no_upcoming'.tr(), style: tBody(13.5, color: TC.muted))
      else
        for (final l in upcoming.take(30))
          LessonRow(l,
              showDate: true,
              extra: Wrap(spacing: 6, runSpacing: 6, children: [
                TButton('lessons.lesson.edit'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.edit, onPressed: () => showEditLessonSheet(context, l)),
                TButton('lessons.mine.cancel_this'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.x, onPressed: () => showCancelSheet(context, l)),
              ])),
      _AccountLink(preacher: p),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TButton('lessons.preacher_admin.remove'.tr(), kind: TBtn.danger, icon: TGlyph.trash, onPressed: () async {
          final gone = await showRemovePreacherSheet(context, p);
          if (gone == true && context.mounted) context.go('/admin/lessons/preachers');
        }),
      ),
    ]);
  }

  static TTone _stateTone(String s) => switch (s) {
        'active' => TTone.success,
        'waiting' || 'scheduled' => TTone.info,
        _ => TTone.slate,
      };

  static String _keyDetail(PreacherKey k, String lang) => [
        'lessons.links.made'.tr(args: [agoText(k.createdAt)]),
        if (k.kind == 'window' && k.validFrom != null && k.validUntil != null)
          'lessons.links.between'.tr(args: [dateTimeLabel(k.validFrom!, lang), dateTimeLabel(k.validUntil!, lang)])
        else if (k.validUntil != null)
          'lessons.links.until_x'.tr(args: [dateTimeLabel(k.validUntil!, lang)]),
        if (k.kind == 'once') k.bound ? 'lessons.links.bound'.tr() : 'lessons.links.unopened'.tr(),
        if (k.lastUsedAt != null) 'lessons.links.seen'.tr(args: [agoText(k.lastUsedAt!)]),
      ].join(' · ');
}

/// Links the card to the preacher's own Hadayah Live account, for a
/// preacher who also streams (his channel then shows on his card). The
/// account search is the admin user directory, so only platform admins
/// see this.
class _AccountLink extends StatefulWidget {
  const _AccountLink({required this.preacher});
  final Preacher preacher;
  @override
  State<_AccountLink> createState() => _AccountLinkState();
}

class _AccountLinkState extends State<_AccountLink> {
  List<LessonsAccount>? found;
  final q = TextEditingController();

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!context.select<AppProvider, bool>((a) => a.isAdminUser)) return const SizedBox.shrink();
    final c = context.read<LessonsController>();
    final lang = context.lang;
    final p = widget.preacher;
    Future<void> link(String? profileId) => tRun(context, () => c.upsertPreacher({'id': p.id, 'linked_profile_id': profileId}),
        success: profileId == null ? 'lessons.preacher_admin.unlinked'.tr() : 'lessons.preacher_admin.linked'.tr());
    return TCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('lessons.preacher_admin.account'.tr(), style: tStrong(16)),
        const SizedBox(height: 4),
        Text('lessons.preacher_admin.account_body'.tr(), style: tBody(13, color: TC.muted)),
        const SizedBox(height: 10),
        if (p.linkedProfileId != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TButton('lessons.preacher_admin.unlink'.tr(), small: true, kind: TBtn.ghost, icon: TGlyph.link, onPressed: () => link(null)),
          )
        else ...[
          TSearchBox(
            hint: 'lessons.preacher_admin.search_account'.tr(),
            controller: q,
            onChanged: (_) {},
            onSubmitted: (v) async {
              final r = await tRun(context, () => c.searchAccounts(v));
              if (mounted) setState(() => found = r ?? const []);
            },
          ),
          if (found != null && found!.isEmpty) Text('lessons.preacher_admin.no_accounts'.tr(), style: tBody(13, color: TC.muted)),
          for (final a in found ?? const <LessonsAccount>[])
            TOptionRow(title: a.name(lang), subtitle: a.email, selected: false, onTap: () => link(a.id)),
        ],
      ]),
    );
  }
}
