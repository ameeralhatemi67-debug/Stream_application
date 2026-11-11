import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../models/broadcaster_application_model.dart';
import 'lantern_verification_queue.dart' show lanternApplicationStatus;

/// The verification queue's dialogs in Lantern and Arch. Each one asks what
/// the older dialog asks, keeps its rule (a rejection needs a reason) and
/// calls the same `AppProvider` method; only the drawing and the toasts are
/// Lantern's.

void _toast(BuildContext context, String message, {bool warn = false}) =>
    lanternToast(context, message,
        warn: warn, icon: warn ? LGlyph.warn : LGlyph.check);

Widget _body(BuildContext context, String text) => Text(text,
    style: Lantern.textStyle(14.5, color: context.lt.muted, height: 1.5));

Widget _cancel(BuildContext context, [Object? result]) => LButton(
    label: 'settings.cancel'.tr(),
    kind: LButtonKind.ghost,
    onPressed: () => Navigator.of(context).pop(result));

/// A label and its value, stacked on narrow dialogs.
class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: Lantern.textStyle(12.5,
                      color: t.muted, weight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 2),
              SelectableText(value.isEmpty ? '—' : value,
                  style: Lantern.textStyle(14, color: t.fg, height: 1.45)),
            ]));
  }
}

/// Approves one application and shows the five stages of the approval as
/// they happen (`approveBroadcasterApplication`'s `onProgress`).
Future<void> lanternApproveApplication(BuildContext context,
    AppProvider provider, BroadcasterApplicationModel app) async {
  final stage = ValueNotifier<int>(1);
  final lang = context.locale.languageCode;
  showLanternDialog<void>(context,
      title: 'design_ui.approving_broadcaster'.tr(),
      dismissible: false,
      body: (ctx) => ValueListenableBuilder<int>(
          valueListenable: stage,
          builder: (ctx, current, _) => _Pipeline(
              name: app.getLocalizedApplicantName(lang), stage: current)));
  var success = false;
  try {
    success = await provider.approveBroadcasterApplication(app.id,
        onProgress: (s, _) => stage.value = s.clamp(1, 5));
  } catch (_) {
    success = false;
  }
  if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  if (success) {
    if (context.mounted) _toast(context, 'admin.app_approved_toast'.tr());
  } else {
    if (context.mounted) {
      _toast(context, 'admin.review_changed'.tr(), warn: true);
    }
  }
}

/// The approval's stages as a checklist with a progress bar.
class _Pipeline extends StatelessWidget {
  const _Pipeline({required this.name, required this.stage});
  final String name;
  final int stage;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final done = stage >= 5;
    return Semantics(
        liveRegion: true,
        child: Column(
            key: const ValueKey('lantern-approve-pipeline'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  style: Lantern.textStyle(14, color: t.muted, height: 1.4)),
              const SizedBox(height: 12),
              for (var i = 1; i <= 5; i++)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient:
                                  i < stage || done ? Lantern.goldFill : null,
                              color: i < stage || done ? null : t.sunk,
                              border: Border.all(
                                  color: i == stage && !done
                                      ? LanternTokens.gold
                                      : t.line,
                                  width: 1.5)),
                          child: i < stage || done
                              ? const LIcon(LGlyph.check,
                                  size: 14, color: LanternTokens.onGold)
                              : Text('$i',
                                  style: Lantern.textStyle(12,
                                      color: i == stage ? t.goldInk : t.muted,
                                      weight: FontWeight.w700,
                                      height: 1.1))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('lantern.admin.stage_$i'.tr(),
                              style: Lantern.textStyle(13.5,
                                  color: i <= stage ? t.fg : t.muted,
                                  weight: i == stage
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  height: 1.4))),
                    ])),
              const SizedBox(height: 6),
              LProgress(stage / 5,
                  label: 'design_ui.approving_broadcaster'.tr()),
              const SizedBox(height: 8),
              Text('lantern.admin.stage_of'.tr(namedArgs: {'stage': '$stage'}),
                  style: Lantern.textStyle(12.5, color: t.muted)
                      .copyWith(fontFeatures: Lantern.tabular)),
            ]));
  }
}

/// Asks for a reason, then rejects one application. The dialog stays open
/// when the server refuses, as in the older design.
Future<void> lanternRejectApplication(BuildContext context,
    AppProvider provider, BroadcasterApplicationModel app) async {
  final reason = TextEditingController();
  final error = ValueNotifier<String?>(null);
  final busy = ValueNotifier<bool>(false);
  final lang = context.locale.languageCode;
  final edit = app.revisionOf != null;
  await showLanternDialog<void>(context,
      title: 'admin.reject_dialog_title'.tr(),
      body: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _body(
                    ctx,
                    (edit
                            ? 'admin.reject_edit_body'
                            : 'admin.reject_application_body')
                        .tr(namedArgs: {
                      'name': app.getLocalizedApplicantName(lang)
                    })),
                const SizedBox(height: 14),
                ValueListenableBuilder<String?>(
                    valueListenable: error,
                    builder: (ctx, message, _) => LField(
                        key: const ValueKey('lantern-reject-reason'),
                        controller: reason,
                        label: 'admin.reject_reason_label'.tr(),
                        hint: 'admin.reject_dialog_hint'.tr(),
                        error: message,
                        maxLines: 4,
                        minLines: 3,
                        onChanged: (_) => error.value = null)),
              ]),
      actions: (ctx) => [
            _cancel(ctx),
            ValueListenableBuilder<bool>(
                valueListenable: busy,
                builder: (ctx, working, _) => LButton(
                    key: const ValueKey('lantern-reject-confirm'),
                    label: edit
                        ? 'admin.reject_edit'.tr()
                        : 'admin.btn_reject'.tr(),
                    kind: LButtonKind.danger,
                    loading: working,
                    onPressed: working
                        ? null
                        : () async {
                            final text = reason.text.trim();
                            if (text.isEmpty) {
                              error.value =
                                  'lantern.admin.reason_required'.tr();
                              return;
                            }
                            busy.value = true;
                            try {
                              final ok = await provider
                                  .rejectBroadcasterApplication(app.id,
                                      reason: text);
                              if (!ok) throw StateError('Review changed');
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (context.mounted) {
                                _toast(
                                    context, 'admin.app_rejected_toast'.tr());
                              }
                            } catch (_) {
                              if (ctx.mounted) busy.value = false;
                              if (context.mounted) {
                                _toast(context, 'admin.review_changed'.tr(),
                                    warn: true);
                              }
                            }
                          })),
          ]);
  // The controllers are left to the garbage collector: the dialog's fields
  // are still drawn during its closing animation, after this returns.
}

/// Confirms, then approves every selected application with the note the
/// older design uses. [onDone] runs after the provider answers.
Future<void> lanternApproveSelected(BuildContext context, AppProvider provider,
    List<String> ids, VoidCallback onDone) async {
  final go = await showLanternDialog<bool>(context,
      title: 'design_ui.approve_selected_applications'.tr(),
      body: (ctx) => _body(
          ctx,
          'lantern.admin.batch_approve_body'
              .tr(namedArgs: {'count': '${ids.length}'})),
      actions: (ctx) => [
            _cancel(ctx, false),
            LButton(
                key: const ValueKey('lantern-batch-approve-confirm'),
                label: 'admin.btn_approve'.tr(),
                icon: LGlyph.verified,
                onPressed: () => Navigator.of(ctx).pop(true)),
          ]);
  if (go != true) return;
  final result = await provider.bulkApproveBroadcasterApplications(ids,
      adminNotes: 'Batch-verified official credentials and venue facilities.');
  onDone();
  if (!context.mounted) return;
  _toast(
      context,
      'lantern.admin.batch_approved'
          .tr(namedArgs: {'count': '${result.succeeded}'}));
}

/// Asks for one reason sent to every selected applicant, then rejects them.
Future<void> lanternRejectSelected(BuildContext context, AppProvider provider,
    List<String> ids, VoidCallback onDone) async {
  final reason = await _askReason(context,
      title:
          'admin.batch_reject_title'.tr(namedArgs: {'count': '${ids.length}'}),
      body: 'design_ui.this_feedback_note_is_sent_to_every_selected_applicant'
          .tr(),
      label: 'admin.reject_reason_label'.tr(),
      hint: 'admin.reject_dialog_hint'.tr(),
      confirm: 'admin.btn_reject'.tr());
  if (reason == null) return;
  final result =
      await provider.bulkRejectBroadcasterApplications(ids, reason: reason);
  onDone();
  if (!context.mounted) return;
  _toast(
      context,
      'admin.batch_reject_result'.tr(namedArgs: {
        'succeeded': '${result.succeeded}',
        'failed': '${result.failed}',
      }),
      warn: result.failed != 0);
}

/// A dialog with one required text field; null when cancelled.
Future<String?> _askReason(BuildContext context,
    {required String title,
    required String body,
    required String label,
    String? hint,
    String? initial,
    required String confirm,
    int? maxLength}) async {
  final controller = TextEditingController(text: initial);
  final error = ValueNotifier<String?>(null);
  final result = await showLanternDialog<String>(context,
      title: title,
      body: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _body(ctx, body),
                const SizedBox(height: 14),
                ValueListenableBuilder<String?>(
                    valueListenable: error,
                    builder: (ctx, message, _) => LField(
                        key: const ValueKey('lantern-reason-field'),
                        controller: controller,
                        label: label,
                        hint: hint,
                        error: message,
                        maxLines: 4,
                        minLines: 3,
                        maxLength: maxLength,
                        onChanged: (_) => error.value = null)),
              ]),
      actions: (ctx) => [
            _cancel(ctx),
            LButton(
                key: const ValueKey('lantern-reason-confirm'),
                label: confirm,
                kind: LButtonKind.danger,
                onPressed: () {
                  final text = controller.text.trim();
                  if (text.isEmpty) {
                    error.value = 'lantern.admin.reason_required'.tr();
                    return;
                  }
                  Navigator.of(ctx).pop(text);
                }),
          ]);
  // Left to the garbage collector, as above.
  return result;
}

/// Removes an application row from the queue; the account and any approved
/// profile stay.
Future<void> lanternRemoveApplication(BuildContext context,
    AppProvider provider, BroadcasterApplicationModel app) async {
  final remove = await showLanternDialog<bool>(context,
      title: 'admin.remove_queue_title'.tr(),
      body: (ctx) => _body(ctx, 'admin.remove_queue_body'.tr()),
      actions: (ctx) => [
            _cancel(ctx, false),
            LButton(
                key: const ValueKey('lantern-remove-confirm'),
                label: 'admin.btn_delete'.tr(),
                kind: LButtonKind.danger,
                icon: LGlyph.trash,
                onPressed: () => Navigator.of(ctx).pop(true)),
          ]);
  if (remove != true || !context.mounted) return;
  try {
    final ok = await provider.deleteBroadcasterApplication(app.id);
    if (!ok) throw StateError('Application changed');
    if (context.mounted) _toast(context, 'admin.app_deleted_toast'.tr());
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'admin.review_changed'.tr(), warn: true);
    }
  }
}

/// Reverses an approval, or approves a rejected application instead, with a
/// required reason.
Future<void> lanternReverseReview(BuildContext context, AppProvider provider,
    Map<String, dynamic> event) async {
  final reason = await _askReason(context,
      title: 'admin.reverse_title'.tr(),
      body: event['action'] == 'approved'
          ? 'admin.reverse_approval'.tr()
          : 'admin.approve_instead'.tr(),
      label: 'admin.reject_reason_label'.tr(),
      confirm: 'admin.reverse_confirm'.tr(),
      maxLength: 500);
  if (reason == null || !context.mounted) return;
  try {
    if (event['action'] == 'approved') {
      await provider.reverseApprovedApplication(event['id'] as String, reason);
    } else {
      final ok = await provider.approveRejectedApplication(
          event['application_id'] as String,
          adminNotes: reason);
      if (!ok) throw StateError('Review changed');
    }
    if (context.mounted) _toast(context, 'admin.review_reversed'.tr());
  } catch (_) {
    if (context.mounted) {
      _toast(context, 'admin.review_changed'.tr(), warn: true);
    }
  }
}

/// One entry of the review log: who did what, why, and what changed.
void showLanternReviewEvent(BuildContext context, Map<String, dynamic> event) {
  final ar = context.locale.languageCode == 'ar';
  final snapshot = Map<String, dynamic>.from(
      event['application_snapshot'] as Map? ?? const {});
  final base =
      Map<String, dynamic>.from(event['base_snapshot'] as Map? ?? const {});
  final changes = <Widget>[];
  if (base.isNotEmpty) {
    for (final (key, label) in [
      ('email', 'admin.field_email'),
      ('phone', 'admin.field_phone'),
      ('city_id', 'profile.city'),
      (ar ? 'venue_name_ar' : 'venue_name_en', 'admin.venue'),
      ('latitude', 'admin.location'),
      ('longitude', 'admin.location'),
      ('youtube_channel_url', 'admin.field_youtube'),
      ('youtube_handle', 'admin.field_youtube'),
    ]) {
      if (base[key] != snapshot[key]) {
        changes.add(
            _Detail(label.tr(), '${base[key] ?? ''} → ${snapshot[key] ?? ''}'));
      }
    }
  }
  String s(String key) => snapshot[key] as String? ?? '';
  showLanternDialog<void>(context,
      title: 'admin.review_log_tab'.tr(),
      maxWidth: 520,
      body: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Detail('admin.audit_actor'.tr(),
                    event['actor_name'] as String? ?? ''),
                _Detail('admin.audit_action'.tr(),
                    'admin.log_${event['action']}'.tr()),
                _Detail('admin.reject_reason_label'.tr(),
                    event['reason'] as String? ?? ''),
                if (changes.isNotEmpty) ...[
                  const LStarDivider(),
                  Text('admin.edit_after_verification'.tr(),
                      style: Lantern.textStyle(14,
                          color: ctx.lt.fg, weight: FontWeight.w700)),
                  ...changes,
                  const LStarDivider(),
                ],
                _Detail('admin.applicant'.tr(),
                    ar ? s('applicant_name_ar') : s('applicant_name_en')),
                _Detail('admin.field_email'.tr(), s('email')),
                _Detail('admin.field_phone'.tr(), s('phone')),
                _Detail('admin.venue'.tr(),
                    ar ? s('venue_name_ar') : s('venue_name_en')),
                _Detail('admin.field_youtube'.tr(), s('youtube_channel_url')),
              ]),
      actions: (ctx) => [
            LButton(
                label: 'design_ui.close'.tr(),
                kind: LButtonKind.secondary,
                onPressed: () => Navigator.of(ctx).pop()),
          ]);
}

/// The full application, with the same actions as its card.
void showLanternApplicationDetails(
    BuildContext context, AppProvider provider, BroadcasterApplicationModel app,
    {required VoidCallback onApprove,
    required VoidCallback onReject,
    required VoidCallback onRemove}) {
  final ar = context.locale.languageCode == 'ar';
  final base =
      provider.applications.where((a) => a.id == app.revisionOf).firstOrNull;
  final changes = <({String label, String before, String after})>[];
  if (base != null) {
    void compare(String label, String before, String after) {
      if (before != after) {
        changes.add((label: label, before: before, after: after));
      }
    }

    compare('admin.field_email'.tr(), base.email, app.email);
    compare('admin.field_phone'.tr(), base.phone, app.phone);
    compare('profile.city'.tr(), base.cityId, app.cityId);
    compare('admin.venue'.tr(), ar ? base.venueNameAr : base.venueNameEn,
        ar ? app.venueNameAr : app.venueNameEn);
    compare('admin.location'.tr(), '${base.latitude}, ${base.longitude}',
        '${app.latitude}, ${app.longitude}');
    compare('YouTube', base.youtubeChannelUrl, app.youtubeChannelUrl);
    compare('YouTube @', base.youtubeHandle, app.youtubeHandle);
  }
  final pending = app.status == ApplicationStatus.pending;
  final status = lanternApplicationStatus(app.status);
  final name = ar ? app.applicantNameAr : app.applicantNameEn;
  final role = app.isOrganization
      ? (app.organizationType ?? '')
      : (ar ? (app.academicTitleAr ?? '') : (app.academicTitleEn ?? ''));
  showLanternDialog<void>(context,
      title: 'admin.btn_inspect'.tr(),
      maxWidth: 600,
      body: (ctx) {
        final t = ctx.lt;
        return Column(
            key: const ValueKey('lantern-application-details'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                LAvatar(
                    name: app.applicantNameEn,
                    image: resolveImageProviderOrNull(app.avatarUrl),
                    size: 60,
                    org: app.isOrganization,
                    verified: app.isApproved),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Text(name,
                          style: Lantern.displayStyle(18,
                              color: t.fg,
                              height: ctx.lanternArabic ? 1.45 : 1.25)),
                      if (role.isNotEmpty)
                        Text(role,
                            style: Lantern.textStyle(13,
                                color: t.goldInk, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        LTag(
                            app.isOrganization
                                ? 'admin.application_org'.tr()
                                : 'admin.application_scholar'.tr(),
                            tone: app.isOrganization
                                ? LTone.gold
                                : LTone.neutral),
                        LTag(status.label, tone: status.tone),
                      ]),
                    ])),
              ]),
              const SizedBox(height: 12),
              if (app.revisionOf != null) ...[
                Text('admin.edit_after_verification'.tr(),
                    style: Lantern.textStyle(14,
                        color: t.fg, weight: FontWeight.w700)),
                if (changes.isEmpty)
                  _body(ctx, 'admin.no_reviewed_changes'.tr()),
                for (final change in changes)
                  _Detail(change.label, '${change.before} → ${change.after}'),
                const LStarDivider(),
              ],
              _Detail('admin.field_email'.tr(), app.email),
              _Detail('admin.field_phone'.tr(), app.phone),
              _Detail(
                  'admin.field_youtube'.tr(),
                  [
                    if (app.youtubeHandle.isNotEmpty)
                      '@${app.youtubeHandle.replaceFirst('@', '')}',
                    app.youtubeChannelUrl
                  ].where((v) => v.isNotEmpty).join('\n')),
              _Detail('admin.field_category'.tr(),
                  app.categoryId.replaceAll('_', ' ').toUpperCase()),
              if (app.tags.isNotEmpty)
                _Detail('admin.field_tags'.tr(), app.tags.join(' ')),
              _Detail('admin.location'.tr(),
                  '${ar ? app.venueNameAr : app.venueNameEn} (${app.latitude.toStringAsFixed(4)}, ${app.longitude.toStringAsFixed(4)})'),
              if (app.seatingCapacity > 0)
                _Detail('admin.field_capacity'.tr(),
                    '${app.seatingCapacity} ${'admin.field_seats'.tr()}'),
              const LStarDivider(),
              _Detail('lantern.admin.bio_en'.tr(),
                  app.bioEn.isNotEmpty ? app.bioEn : 'lantern.admin.none'.tr()),
              _Detail('lantern.admin.bio_ar'.tr(),
                  app.bioAr.isNotEmpty ? app.bioAr : 'lantern.admin.none'.tr()),
            ]);
      },
      actions: (ctx) => [
            LIconButton(
                key: const ValueKey('lantern-details-remove'),
                icon: LGlyph.trash,
                label: 'admin.btn_delete'.tr(),
                color: ctx.lt.liveText,
                onPressed: () {
                  Navigator.of(ctx).pop();
                  onRemove();
                }),
            if (pending) ...[
              LButton(
                  key: const ValueKey('lantern-details-reject'),
                  label: app.revisionOf == null
                      ? 'design_ui.reject'.tr()
                      : 'admin.reject_edit'.tr(),
                  kind: LButtonKind.secondary,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onReject();
                  }),
              LButton(
                  key: const ValueKey('lantern-details-approve'),
                  label: app.revisionOf == null
                      ? 'design_ui.approve_broadcaster'.tr()
                      : 'admin.approve_edit'.tr(),
                  icon: LGlyph.verified,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onApprove();
                  }),
            ] else
              LButton(
                  label: 'design_ui.close'.tr(),
                  kind: LButtonKind.secondary,
                  onPressed: () => Navigator.of(ctx).pop()),
          ]);
}
