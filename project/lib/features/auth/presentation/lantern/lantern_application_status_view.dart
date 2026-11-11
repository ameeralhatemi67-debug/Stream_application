import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../admin/models/broadcaster_application_model.dart';

/// Where an application stands, in Lantern and Arch (/application-pending):
/// a night band with the state, a tracker of three stages (sent, under
/// review, then verified or changes requested with the reviewer's note),
/// what was sent, what happens next, and the page's actions. It reads the
/// application the app already holds; with none it shows the state right
/// after sending.
class LanternApplicationStatusView extends StatelessWidget
    implements LanternSkinWidget {
  const LanternApplicationStatusView({super.key});

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _page(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    final app = context
        .select<AppProvider, BroadcasterApplicationModel?>((p) => p.myApplication);
    final approvedStreamer =
        context.select<AppProvider, bool>((p) => p.isApprovedStreamer);
    final status = app?.status ?? ApplicationStatus.pending;
    final lang = context.locale.languageCode;
    final m = MaterialLocalizations.of(context);
    final note = app?.reviewNotes?.trim();

    final (badge, icon, title, body) = switch (status) {
      ApplicationStatus.approved => (
          LBadgeKind.now,
          LGlyph.verified,
          'application.status_approved'.tr(),
          'application.status_approved_desc'.tr()
        ),
      ApplicationStatus.rejected => (
          LBadgeKind.soon,
          LGlyph.edit,
          'application.status_rejected'.tr(),
          note == null || note.isEmpty
              ? 'lantern.apply.track_changes'.tr()
              : '${'application.admin_feedback'.tr()}: $note'
        ),
      ApplicationStatus.suspended => (
          LBadgeKind.off,
          LGlyph.ban,
          'lantern.apply.track_suspended'.tr(),
          note == null || note.isEmpty ? '' : note
        ),
      _ => (
          LBadgeKind.soon,
          LGlyph.clock,
          'wizard_pending.title'.tr(),
          'wizard_pending.subtitle'.tr()
        ),
    };

    // The three stages: sent; under review; the decision.
    final decided = status != ApplicationStatus.pending;
    final stages = <_Stage>[
      _Stage(
          title: 'lantern.apply.track_submitted'.tr(),
          detail: app == null
              ? null
              : 'lantern.apply.submitted_on'
                  .tr(args: [m.formatMediumDate(app.submittedAt.toLocal())]),
          state: _StageState.done),
      _Stage(
          title: (decided
                  ? 'lantern.apply.track_reviewed'
                  : 'lantern.apply.track_review')
              .tr(),
          detail: decided
              ? (app?.reviewedAt == null
                  ? null
                  : m.formatMediumDate(app!.reviewedAt!.toLocal()))
              : 'lantern.apply.track_review_body'.tr(),
          state: decided ? _StageState.done : _StageState.current),
      _Stage(
          title: switch (status) {
            ApplicationStatus.rejected => 'lantern.apply.track_changes'.tr(),
            ApplicationStatus.suspended =>
              'lantern.apply.track_suspended'.tr(),
            _ => 'lantern.apply.track_verified'.tr(),
          },
          detail: switch (status) {
            ApplicationStatus.approved =>
              'lantern.apply.track_verified_body'.tr(),
            ApplicationStatus.rejected ||
            ApplicationStatus.suspended =>
              note == null || note.isEmpty ? null : note,
            _ => null,
          },
          state: switch (status) {
            ApplicationStatus.approved => _StageState.done,
            ApplicationStatus.rejected ||
            ApplicationStatus.suspended =>
              _StageState.warn,
            _ => _StageState.todo,
          }),
    ];

    final hero = LNightBand(
        key: const ValueKey('lantern-status-hero'),
        padding: EdgeInsets.symmetric(vertical: wide ? 44 : 30),
        child: Builder(builder: (context) {
          final n = context.lt;
          return _Column(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (badge) {
                          LBadgeKind.now => n.okSoft,
                          LBadgeKind.off => n.sunk,
                          _ => n.warnSoft,
                        }),
                    child: LIcon(icon,
                        size: 26,
                        color: switch (badge) {
                          LBadgeKind.now => n.ok,
                          LBadgeKind.off => n.muted,
                          _ => n.warn,
                        })),
                const SizedBox(height: 16),
                Semantics(
                    header: true,
                    child: Text(title,
                        key: const ValueKey('lantern-status-title'),
                        style: Lantern.displayStyle(wide ? 32 : 24,
                            color: LanternTokens.onNight,
                            height: context.lanternArabic ? 1.45 : 1.25))),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Text(body,
                          style: Lantern.textStyle(15,
                              color: n.muted, height: 1.6))),
                ],
              ]));
        }));

    final tracker = Column(
        key: const ValueKey('lantern-status-track'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, s) in stages.indexed)
            _StageRow(stage: s, index: i, last: i == stages.length - 1),
        ]);

    final actions = Wrap(
        key: const ValueKey('lantern-status-actions'),
        spacing: 10,
        runSpacing: 10,
        children: [
          // A pending or declined application is edited in place; an
          // approved channel is edited from Settings (as on the Settings
          // status card).
          if (app != null && !app.isApproved && !approvedStreamer)
            LButton(
                key: const ValueKey('lantern-status-edit'),
                label: (status == ApplicationStatus.rejected
                        ? 'application.reapply_btn'
                        : 'application.edit_btn')
                    .tr(),
                icon: LGlyph.edit,
                onPressed: () => context.push('/streamer-apply')),
          LButton(
              key: const ValueKey('lantern-status-explore'),
              label: 'wizard_pending.btn_explore'.tr(),
              kind: app != null && !app.isApproved && !approvedStreamer
                  ? LButtonKind.secondary
                  : LButtonKind.primary,
              onPressed: () => context.go('/feed')),
        ]);

    final sent = app == null
        ? null
        : LCard(
            key: const ValueKey('lantern-status-sent'),
            padding: const EdgeInsets.all(20),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanelTitle('lantern.apply.what_you_sent'.tr()),
                  for (final (k, v) in [
                    (
                      'ds.apply_identity'.tr(),
                      lang == 'ar' ? app.applicantNameAr : app.applicantNameEn
                    ),
                    (
                      'ds.apply_professional'.tr(),
                      (app.isOrganization
                              ? 'lantern.apply.type_org'
                              : 'lantern.apply.type_individual')
                          .tr()
                    ),
                    if (app.youtubeHandle.trim().isNotEmpty)
                      ('YouTube', app.youtubeHandle),
                    if ((lang == 'ar' ? app.venueNameAr : app.venueNameEn)
                        .trim()
                        .isNotEmpty)
                      (
                        'ds.apply_venue'.tr(),
                        lang == 'ar' ? app.venueNameAr : app.venueNameEn
                      ),
                  ])
                    _Kv(k, v),
                ]));

    final next = LCard(
        key: const ValueKey('lantern-status-next'),
        padding: const EdgeInsets.all(20),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _PanelTitle('lantern.apply.what_next'.tr()),
              for (var i = 1; i <= 3; i++)
                Padding(
                    padding: EdgeInsets.only(bottom: i < 3 ? 12 : 0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('wizard_pending.step${i}_title'.tr(),
                              style: Lantern.textStyle(14.5,
                                  color: t.fg,
                                  weight: FontWeight.w600,
                                  height: 1.35)),
                          const SizedBox(height: 2),
                          Text('wizard_pending.step${i}_desc'.tr(),
                              style: Lantern.textStyle(13.5,
                                  color: t.muted, height: 1.5)),
                        ])),
            ]));

    final main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [tracker, const SizedBox(height: 8), actions]);
    final side = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sent != null) ...[sent, const SizedBox(height: 16)],
          next,
        ]);

    final scroll = SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      hero,
      _Column(
          top: wide ? 36 : 24,
          bottom: wide ? 56 : 28 + MediaQuery.paddingOf(context).bottom,
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: main),
                  const SizedBox(width: 32),
                  SizedBox(width: 380, child: side),
                ])
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [main, const SizedBox(height: 24), side])),
      if (wide) const LanternWebFooter(),
    ]));
    if (wide) {
      return Scaffold(
          key: const ValueKey('lantern-status'),
          backgroundColor: t.bg,
          body: SafeArea(
              child: Column(children: [
            const LanternWebHeader(active: LanternSection.channel),
            Expanded(child: scroll),
          ])));
    }
    return Scaffold(
        key: const ValueKey('lantern-status'),
        backgroundColor: t.bg,
        appBar: LanternPageBar(
            title: 'application.status_title'.tr(),
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/settings')),
        body: scroll);
  }
}

/// The page column: 1200 wide with 32 px gutters, 16 on phones.
class _Column extends StatelessWidget implements LanternSkinWidget {
  const _Column({required this.child, this.top = 0, this.bottom = 0});

  final Widget child;
  final double top, bottom;

  @override
  Widget build(BuildContext context) {
    final g = context.lanternWide ? Lantern.webGutter : Lantern.gutter;
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: Lantern.webContent + 2 * Lantern.webGutter),
            child: Padding(
                padding: EdgeInsets.fromLTRB(g, top, g, bottom),
                child: child)));
  }
}

class _PanelTitle extends StatelessWidget implements LanternSkinWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
          header: true,
          child: Text(text,
              style: Lantern.displayStyle(17,
                  color: context.lt.fg,
                  height: context.lanternArabic ? 1.45 : 1.25))));
}

class _Kv extends StatelessWidget implements LanternSkinWidget {
  const _Kv(this.k, this.v);

  final String k, v;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: t.line2))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: Lantern.textStyle(13.5, color: t.muted, height: 1.4)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: Lantern.textStyle(13.5,
                      color: t.fg, weight: FontWeight.w600, height: 1.4))),
        ]));
  }
}

enum _StageState { done, current, warn, todo }

class _Stage {
  const _Stage({required this.title, required this.state, this.detail});

  final String title;
  final String? detail;
  final _StageState state;
}

class _StageRow extends StatelessWidget implements LanternSkinWidget {
  const _StageRow(
      {required this.stage, required this.index, required this.last});

  final _Stage stage;
  final int index;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final s = stage.state;
    final word = switch (s) {
      _StageState.done => 'lantern.apply.step_done',
      _StageState.current => 'lantern.apply.step_current',
      _StageState.warn => 'lantern.apply.step_current',
      _StageState.todo => 'lantern.apply.step_todo',
    };
    return Semantics(
        key: ValueKey('lantern-status-stage-$index-${s.name}'),
        label: word.tr(args: [stage.title]),
        child: ExcludeSemantics(
            child: IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
              SizedBox(
                  width: 36,
                  child: Column(children: [
                    Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (s) {
                              _StageState.done => t.ok,
                              _StageState.current => LanternTokens.gold,
                              _StageState.warn => t.warn,
                              _StageState.todo => t.sunk,
                            },
                            boxShadow: s == _StageState.current
                                ? [BoxShadow(color: t.glow, spreadRadius: 5)]
                                : null),
                        child: switch (s) {
                          _StageState.done => const LIcon(LGlyph.check,
                              size: 18, color: LanternTokens.white),
                          _StageState.warn => const LIcon(LGlyph.warn,
                              size: 18, color: LanternTokens.white),
                          _ => Text('${index + 1}',
                              style: Lantern.displayStyle(14,
                                  color: s == _StageState.current
                                      ? LanternTokens.onGold
                                      : t.muted,
                                  height: 1)),
                        }),
                    if (!last)
                      Expanded(
                          child: Container(
                              width: 2,
                              color: s == _StageState.done ? t.ok : t.line)),
                  ])),
              const SizedBox(width: 16),
              Expanded(
                  child: Padding(
                      padding: EdgeInsets.only(top: 6, bottom: last ? 0 : 24),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(stage.title,
                                style: Lantern.textStyle(16,
                                    color: t.fg,
                                    weight: FontWeight.w600,
                                    height: 1.3)),
                            if (stage.detail != null) ...[
                              const SizedBox(height: 3),
                              Text(stage.detail!,
                                  style: Lantern.textStyle(13.5,
                                      color: t.muted, height: 1.5)),
                            ],
                          ]))),
            ]))));
  }
}
