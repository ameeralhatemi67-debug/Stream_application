import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/widgets/lantern/lantern.dart';

/// What the last press of Next or Submit found wrong, for the fields of the
/// step on screen. [attempt] grows with every failed press, so the field
/// scrolls into view again even when the message is the same.
class LanternApplyErrors extends InheritedWidget {
  const LanternApplyErrors(
      {super.key,
      required super.child,
      this.field,
      this.message,
      this.attempt = 0,
      this.onEdited});

  final String? field, message;
  final int attempt;

  /// Clears the message once the field in error is edited.
  final VoidCallback? onEdited;

  /// Call when the field [id] changes: its message goes away.
  static void edited(BuildContext context, String id) {
    final e = context.getInheritedWidgetOfExactType<LanternApplyErrors>();
    if (e != null && e.field == id) e.onEdited?.call();
  }

  static LanternApplyErrors? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanternApplyErrors>();

  /// The message for the field [id], or null when it is fine.
  static String? errorFor(BuildContext context, String id) {
    final e = of(context);
    return e?.field == id ? e?.message : null;
  }

  @override
  bool updateShouldNotify(LanternApplyErrors old) =>
      old.field != field || old.message != message || old.attempt != attempt;
}

/// Brings its child into view when the field [id] is the one in error.
class LanternApplyAnchor extends StatefulWidget implements LanternSkinWidget {
  const LanternApplyAnchor({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<LanternApplyAnchor> createState() => _LanternApplyAnchorState();
}

class _LanternApplyAnchorState extends State<LanternApplyAnchor> {
  int _seen = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final e = LanternApplyErrors.of(context);
    if (e == null || e.field != widget.id || e.attempt == _seen) return;
    _seen = e.attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(context,
          alignment: .2,
          duration: Lantern.calm(context)
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Lantern.ease);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The heading of a step: its title and the sentence under it.
class LanternApplyStepHead extends StatelessWidget implements LanternSkinWidget {
  const LanternApplyStepHead(
      {super.key, required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
              header: true,
              child: Text(title,
                  style: Lantern.displayStyle(22,
                      color: t.fg,
                      height: context.lanternArabic ? 1.45 : 1.25))),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(description!,
                style: Lantern.textStyle(14, color: t.muted, height: 1.55)),
          ],
          const SizedBox(height: 20),
        ]);
  }
}

/// The broadcaster application in Lantern and Arch (/streamer-apply). The
/// website layout has a night rail with the steps on the start side and
/// the step in one card beside it, Back and Next at its foot; a phone has
/// a compact stepper at the top and Back and Next pinned at the bottom.
/// StreamerApplyScreen keeps every field, check, draft and the submission;
/// this view draws them.
class LanternApplyView extends StatelessWidget implements LanternSkinWidget {
  const LanternApplyView(
      {super.key,
      required this.stepNames,
      required this.visualStep,
      required this.stepPages,
      required this.pageController,
      required this.onPageChanged,
      required this.pages,
      required this.page,
      required this.onBack,
      required this.onNext,
      required this.onExit,
      required this.onStep,
      required this.nextLabel,
      required this.isLast,
      required this.submitting,
      this.error,
      this.errorField,
      this.errorFieldMessage,
      this.attempt = 0,
      this.onFieldEdited,
      this.scrollingPages = const {}});

  /// The field in error was edited: its message can go.
  final VoidCallback? onFieldEdited;

  /// Pages that scroll themselves (a step still drawn by its older widget).
  final Set<int> scrollingPages;

  /// The five steps the applicant sees.
  final List<String> stepNames;
  final int visualStep;

  /// The first page of each visible step (an organization has a page for
  /// its speakers inside the third step).
  final List<int> stepPages;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final List<Widget> pages;
  final int page;
  final VoidCallback onBack, onNext, onExit;
  final ValueChanged<int> onStep;
  final String nextLabel;
  final bool isLast, submitting;

  /// The summary at the top of the card, and the field it points to.
  final String? error, errorField, errorFieldMessage;
  final int attempt;

  static const _icons = [
    LGlyph.person,
    LGlyph.image,
    LGlyph.book,
    LGlyph.pin,
    LGlyph.check
  ];

  @override
  Widget build(BuildContext context) =>
      LanternSurface(child: Builder(builder: _page));

  Widget _banner() => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: LBanner(error!,
              key: const ValueKey('lantern-apply-error'), tone: LTone.live));

  Widget _pageView(BuildContext context, EdgeInsets padding) => PageView(
      key: const ValueKey('lantern-apply-pages'),
      controller: pageController,
      physics: const NeverScrollableScrollPhysics(),
      onPageChanged: onPageChanged,
      children: [
        for (final (i, p) in pages.indexed)
          scrollingPages.contains(i)
              ? Padding(padding: padding, child: p)
              : SingleChildScrollView(padding: padding, child: p),
      ]);

  Widget _footer(BuildContext context) {
    final t = context.lt;
    return Row(key: const ValueKey('lantern-apply-footer'), children: [
      LButton(
          key: const ValueKey('lantern-apply-back'),
          label: 'wizard_steps.btn_back'.tr(),
          kind: LButtonKind.ghost,
          onPressed: page == 0 ? null : onBack),
      Expanded(
          child: Text(
              '${visualStep + 1} / ${stepNames.length}',
              textAlign: TextAlign.center,
              style: Lantern.textStyle(13.5, color: t.muted)
                  .copyWith(fontFeatures: Lantern.tabular))),
      LButton(
          key: const ValueKey('lantern-apply-next'),
          label: nextLabel,
          icon: isLast ? LGlyph.send : null,
          trailing: isLast ? null : LGlyph.arrow,
          loading: submitting,
          onPressed: submitting ? null : onNext),
    ]);
  }

  Widget _page(BuildContext context) {
    final t = context.lt;
    final wide = context.lanternWide;
    final errors = LanternApplyErrors(
        field: errorField,
        message: errorFieldMessage,
        attempt: attempt,
        onEdited: onFieldEdited,
        child: wide
            ? _wide(context)
            : Column(children: [
                _compactStepper(context),
                Padding(
                    padding: const EdgeInsets.fromLTRB(
                        Lantern.gutter, 0, Lantern.gutter, 0),
                    child: _banner()),
                Expanded(
                    child: _pageView(
                        context,
                        const EdgeInsets.fromLTRB(
                            Lantern.gutter, 8, Lantern.gutter, 24))),
                DecoratedBox(
                    decoration: BoxDecoration(
                        color: t.surface,
                        border: Border(top: BorderSide(color: t.line))),
                    child: SafeArea(
                        top: false,
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Lantern.gutter, vertical: 10),
                            child: _footer(context)))),
              ]));
    if (wide) {
      return Scaffold(
          key: const ValueKey('lantern-apply'),
          backgroundColor: t.bg,
          body: SafeArea(
              child: Column(children: [
            const LanternWebHeader(active: LanternSection.channel),
            Expanded(child: errors),
          ])));
    }
    return Scaffold(
        key: const ValueKey('lantern-apply'),
        backgroundColor: t.bg,
        appBar: LanternPageBar(
            title: 'ds.apply_title'.tr(),
            onBack: onBack,
            actions: [
              LIconButton(
                  key: const Key('wizard-exit'),
                  icon: LGlyph.close,
                  label: 'wizard_steps.exit_tooltip'.tr(),
                  onPressed: onExit),
            ]),
        body: errors);
  }

  /// Phone: step n of m, the step's name and a progress line.
  Widget _compactStepper(BuildContext context) {
    final t = context.lt;
    final n = stepNames.length;
    return Padding(
        key: const ValueKey('lantern-apply-stepper'),
        padding: const EdgeInsets.fromLTRB(Lantern.gutter, 14, Lantern.gutter, 14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text('wizard_steps.step_progress'
                    .tr(args: ['${visualStep + 1}', '$n']),
                    style: Lantern.textStyle(12.5,
                        color: t.muted, weight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(stepNames[visualStep],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: Lantern.displayStyle(15,
                            color: t.fg,
                            height: context.lanternArabic ? 1.45 : 1.25))),
              ]),
              const SizedBox(height: 10),
              LProgress((visualStep + 1) / n,
                  height: 6,
                  label: 'wizard_steps.step_progress'
                      .tr(args: ['${visualStep + 1}', '$n'])),
            ]));
  }

  Widget _wide(BuildContext context) {
    final t = context.lt;
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: Lantern.webContent + 2 * Lantern.webGutter),
            child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Lantern.webGutter, 28, Lantern.webGutter, 28),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          width: Lantern.sideChat,
                          child: LNightBand(
                              key: const ValueKey('lantern-apply-rail'),
                              radius: Lantern.radiusCard,
                              padding: const EdgeInsets.all(20),
                              child: _rail(context))),
                      const SizedBox(width: 28),
                      Expanded(
                          child: DecoratedBox(
                              key: const ValueKey('lantern-apply-card'),
                              decoration: BoxDecoration(
                                  color: t.surface,
                                  borderRadius: BorderRadius.circular(
                                      Lantern.radiusCard),
                                  border: Border.all(color: t.line),
                                  boxShadow: t.shadow),
                              child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(28, 24, 28, 20),
                                  child: Column(children: [
                                    _banner(),
                                    Expanded(
                                        child: _pageView(context,
                                            const EdgeInsets.only(bottom: 16))),
                                    Container(
                                        padding: const EdgeInsets.only(top: 14),
                                        decoration: BoxDecoration(
                                            border: Border(
                                                top: BorderSide(
                                                    color: t.line))),
                                        child: _footer(context)),
                                  ])))),
                    ]))));
  }

  Widget _rail(BuildContext context) {
    final t = context.lt;
    final n = stepNames.length;
    return Semantics(
        container: true,
        label: 'lantern.apply.steps_label'.tr(),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                    child: Semantics(
                        header: true,
                        child: Text('lantern.apply.rail_title'.tr(),
                            style: Lantern.displayStyle(17,
                                color: LanternTokens.onNight,
                                height: context.lanternArabic ? 1.45 : 1.25)))),
                LIconButton(
                    key: const Key('wizard-exit'),
                    icon: LGlyph.close,
                    color: LanternTokens.onNight,
                    label: 'wizard_steps.exit_tooltip'.tr(),
                    onPressed: onExit),
              ]),
              const SizedBox(height: 14),
              for (var i = 0; i < n; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _railStep(context, i)),
              const SizedBox(height: 14),
              LProgress(visualStep / (n - 1),
                  height: 6,
                  label: 'wizard_steps.step_progress'
                      .tr(args: ['${visualStep + 1}', '$n'])),
              const Spacer(),
              Text('wizard_steps.exit_body'.tr(),
                  style: Lantern.textStyle(12.5, color: t.muted, height: 1.5)),
            ]));
  }

  Widget _railStep(BuildContext context, int i) {
    final t = context.lt;
    final done = i < visualStep, current = i == visualStep;
    final label = (done
            ? 'lantern.apply.step_done'
            : current
                ? 'lantern.apply.step_current'
                : 'lantern.apply.step_todo')
        .tr(args: [stepNames[i]]);
    return LPressable(
        key: ValueKey('lantern-apply-rail-$i'),
        // Only steps already passed can be opened again.
        onTap: done ? () => onStep(stepPages[i]) : null,
        label: label,
        selected: current,
        radius: Lantern.radiusTile,
        pressScale: .98,
        excludeChildSemantics: true,
        builder: (context, s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(
                color: current
                    ? LanternTokens.goldHi.withValues(alpha: .12)
                    : s.hovered
                        ? LanternTokens.white.withValues(alpha: .06)
                        : null,
                borderRadius: BorderRadius.circular(Lantern.radiusTile)),
            child: Row(children: [
              Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? t.ok
                          : current
                              ? LanternTokens.gold
                              : null,
                      border: Border.all(
                          color: done
                              ? t.ok
                              : current
                                  ? LanternTokens.goldHi
                                  : t.line,
                          width: current ? 2.5 : 1.5)),
                  child: done
                      ? const LIcon(LGlyph.check,
                          size: 16, color: LanternTokens.nightGround)
                      : current
                          ? LIcon(_icons[i],
                              size: 16, color: LanternTokens.onGold)
                          : Text('${i + 1}',
                              style: Lantern.displayStyle(13,
                                  color: t.muted, height: 1))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(stepNames[i],
                      style: Lantern.textStyle(14.5,
                          color: current || done
                              ? LanternTokens.onNight
                              : t.muted,
                          weight: current ? FontWeight.w700 : FontWeight.w500,
                          height: 1.3))),
            ])));
  }
}

/// Step 1: name, public handle and biography, on the screen's own fields.
class LanternApplyIdentity extends StatelessWidget implements LanternSkinWidget {
  const LanternApplyIdentity(
      {super.key,
      required this.name,
      required this.handle,
      required this.bio,
      this.onChanged});

  final TextEditingController name, handle, bio;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget field(String id, TextEditingController c, String label, String hint,
            {int maxLines = 1, int? maxLength, LGlyph? icon}) =>
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LanternApplyAnchor(
                id: id,
                child: LField(
                    key: ValueKey('lantern-apply-field-$id'),
                    controller: c,
                    label: label,
                    hint: hint,
                    icon: icon,
                    maxLines: maxLines,
                    minLines: maxLines > 1 ? 3 : null,
                    maxLength: maxLength,
                    onChanged: (_) {
                      LanternApplyErrors.edited(context, id);
                      onChanged?.call();
                    },
                    error: LanternApplyErrors.errorFor(context, id))));
    return Column(
        key: const ValueKey('lantern-apply-step-identity'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LanternApplyStepHead(
              title: 'wizard_steps.step1_title'.tr().split(':').last.trim(),
              description: 'wizard_steps.step1_desc'.tr()),
          field('name', name, 'wizard_steps.step1_name_label'.tr(),
              'wizard_steps.step1_name_hint'.tr(),
              icon: LGlyph.person),
          field('handle', handle, 'wizard_steps.step1_handle_label'.tr(),
              'wizard_steps.step1_handle_hint'.tr(),
              icon: LGlyph.link),
          field('bio', bio, 'wizard_steps.step1_bio_label'.tr(),
              'wizard_steps.step1_bio_hint'.tr(),
              maxLines: 5, maxLength: 350),
        ]);
  }
}

/// Step 5: each step with what was entered and an Edit link that opens it,
/// then the agreement to the terms.
class LanternApplyReview extends StatelessWidget implements LanternSkinWidget {
  const LanternApplyReview(
      {super.key,
      required this.rows,
      required this.agreed,
      required this.onAgree,
      required this.onReadTerms,
      required this.onEdit,
      required this.isOrganization});

  /// One row per earlier step: its name, its icon, a summary and its page.
  final List<({String title, LGlyph icon, String summary, int page})> rows;
  final bool agreed, isOrganization;
  final ValueChanged<bool> onAgree;
  final VoidCallback onReadTerms;

  /// Opens the page of a step again.
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final error = LanternApplyErrors.errorFor(context, 'terms');
    return Column(
        key: const ValueKey('lantern-apply-step-review'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LanternApplyStepHead(
              title: 'wizard_steps.step5_title'.tr().split(':').last.trim(),
              description: 'wizard_steps.step5_desc'.tr()),
          for (final r in rows)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReviewRow(row: r, onEdit: () => onEdit(r.page))),
          const SizedBox(height: 10),
          LanternApplyAnchor(
              id: 'terms',
              child: Container(
                  key: const ValueKey('lantern-apply-terms'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: t.sunk,
                      borderRadius: BorderRadius.circular(Lantern.radiusField),
                      border: Border.all(
                          color: error != null
                              ? t.live
                              : agreed
                                  ? LanternTokens.gold
                                  : t.line)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                            (isOrganization
                                    ? 'wizard_steps.step5_terms_modal_org'
                                    : 'wizard_steps.step5_terms_modal_ind')
                                .tr(),
                            style: Lantern.displayStyle(15.5,
                                color: t.fg,
                                height: context.lanternArabic ? 1.45 : 1.25)),
                        const SizedBox(height: 10),
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LSwitch(
                                  key: const ValueKey('lantern-apply-agree'),
                                  value: agreed,
                                  label: 'lantern.apply.agree'.tr(),
                                  onChanged: onAgree),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Text('lantern.apply.agree'.tr(),
                                      style: Lantern.textStyle(14,
                                          color: t.fg, height: 1.5))),
                            ]),
                        const SizedBox(height: 4),
                        LLink('lantern.apply.read_terms'.tr(),
                            icon: LGlyph.book, onTap: onReadTerms),
                        if (error != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(children: [
                                LIcon(LGlyph.warn, size: 14, color: t.liveText),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(error,
                                        style: Lantern.textStyle(12.5,
                                            color: t.liveText,
                                            weight: FontWeight.w500))),
                              ])),
                      ]))),
        ]);
  }
}

class _ReviewRow extends StatelessWidget implements LanternSkinWidget {
  const _ReviewRow({required this.row, required this.onEdit});

  final ({String title, LGlyph icon, String summary, int page}) row;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Container(
        key: ValueKey('lantern-apply-review-${row.page}'),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 6, 10),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Lantern.radiusRow),
            border: Border.all(color: t.line2)),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: t.sunk,
                  borderRadius: BorderRadius.circular(Lantern.radiusTile)),
              child: LIcon(row.icon, size: 20, color: t.goldInk)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(row.title,
                    style: Lantern.textStyle(14.5,
                        color: t.fg, weight: FontWeight.w600, height: 1.35)),
                Text(row.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Lantern.textStyle(13, color: t.muted, height: 1.45)),
              ])),
          LButton(
              key: ValueKey('lantern-apply-edit-${row.page}'),
              label: 'common.edit'.tr(),
              icon: LGlyph.edit,
              kind: LButtonKind.ghost,
              size: LButtonSize.small,
              onPressed: onEdit),
        ]));
  }
}
