import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_skin.dart' show AppSkin;
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../lessons/state/lessons_controller.dart';
import '../../../lessons/state/preacher_link_controller.dart';
import 'lantern_settings_view.dart';

/// The pieces of each Settings section in Lantern and Arch (ADR-026). The
/// section widgets keep their state and actions and hand them in here.

/// Settings → Design: the three designs as tiles, "In use" on the current one.
class LanternSkinTiles extends StatelessWidget implements LanternSkinWidget {
  const LanternSkinTiles(
      {super.key,
      required this.options,
      required this.current,
      required this.onChoose});

  final List<({AppSkin skin, String name, String hint})> options;
  final AppSkin current;
  final ValueChanged<AppSkin> onChoose;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        key: const ValueKey('lantern-settings-design'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('skin.hint'.tr(), style: Lantern.textStyle(14, color: t.muted)),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, box) {
            const gap = 14.0;
            final columns = box.maxWidth >= 640
                ? 3
                : box.maxWidth >= 340
                    ? 2
                    : 1;
            final width = (box.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              for (final o in options)
                SizedBox(
                    width: width,
                    child: _SkinTile(
                        key: ValueKey('skin-option-${o.skin.id}'),
                        skin: o.skin,
                        name: o.name,
                        hint: o.hint,
                        selected: o.skin == current,
                        onTap: () => onChoose(o.skin))),
            ]);
          }),
        ]);
  }
}

class _SkinTile extends StatelessWidget {
  const _SkinTile(
      {super.key,
      required this.skin,
      required this.name,
      required this.hint,
      required this.selected,
      required this.onTap});

  final AppSkin skin;
  final String name, hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Semantics(
        inMutuallyExclusiveGroup: true,
        child: LCard(
            onTap: onTap,
            label: selected ? '$name, ${'skin.in_use'.tr()}' : name,
            selected: selected,
            padding: const EdgeInsets.all(12),
            radius: 22,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                          height: 110,
                          width: double.infinity,
                          child: CustomPaint(painter: _Preview(skin)))),
                  const SizedBox(height: 12),
                  Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(name,
                            style: Lantern.textStyle(15,
                                color: t.fg,
                                weight: FontWeight.w700,
                                height: 1.3)),
                        if (selected)
                          LTag('skin.in_use'.tr(),
                              tone: LTone.ok, icon: LGlyph.check),
                      ]),
                  const SizedBox(height: 4),
                  Text(hint,
                      style:
                          Lantern.textStyle(13, color: t.muted, height: 1.45)),
                ])));
  }
}

/// A small picture of each design, in its own colours.
class _Preview extends CustomPainter {
  const _Preview(this.skin);

  final AppSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final (page, band, accent) = switch (skin) {
      AppSkin.gold => (
          LanternTokens.day.bg,
          LanternTokens.nightGround,
          LanternTokens.goldHi
        ),
      AppSkin.hedayah => (
          LanternTokens.white,
          LanternTokens.gold,
          LanternTokens.white
        ),
      AppSkin.lantern => (
          LanternTokens.day.bg,
          LanternTokens.nightGround,
          LanternTokens.gold
        ),
    };
    canvas.drawRect(Offset.zero & size, Paint()..color = page);
    final bandRect = Rect.fromLTWH(0, 0, size.width, size.height * .46);
    canvas.drawRect(bandRect, Paint()..color = band);
    final mark = Rect.fromCenter(
        center: bandRect.center, width: 22, height: 26);
    if (skin == AppSkin.lantern) {
      canvas.drawPath(lanternArchPath(mark, bottom: 3),
          Paint()..shader = Lantern.goldFill.createShader(mark));
    } else {
      canvas.drawPath(
          lanternStarPath(const Size.square(22))
              .shift(Offset(mark.left, mark.top + 2)),
          Paint()..color = accent);
    }
    final card = Paint()..color = LanternTokens.white;
    final shade = Paint()
      ..color = LanternTokens.ink.withValues(alpha: .08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final radius = Radius.circular(skin == AppSkin.gold ? 5 : 8);
    for (var i = 0; i < 2; i++) {
      final r = RRect.fromRectAndRadius(
          Rect.fromLTWH(10, size.height * .54 + i * size.height * .2,
              size.width - 20, size.height * .15),
          radius);
      canvas
        ..drawRRect(r, shade)
        ..drawRRect(r, card);
    }
    if (skin != AppSkin.gold) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset(size.width / 2, size.height - 8),
                  width: 44,
                  height: 9),
              const Radius.circular(5)),
          Paint()..color = LanternTokens.gold);
    }
  }

  @override
  bool shouldRepaint(_Preview old) => old.skin != skin;
}

/// The application to broadcast: an invitation to apply, or its state.
class LanternApplicationCard extends StatelessWidget
    implements LanternSkinWidget {
  const LanternApplicationCard.invite({super.key, required this.onApply})
      : state = null,
        name = '',
        email = '',
        organization = false,
        message = '',
        feedback = false,
        actionLabel = null,
        onAction = null;

  const LanternApplicationCard.status(
      {super.key,
      required LanternApplicationState this.state,
      required this.name,
      required this.email,
      required this.organization,
      required this.message,
      required this.feedback,
      this.actionLabel,
      this.onAction})
      : onApply = null;

  final LanternApplicationState? state;
  final String name, email, message;
  final bool organization, feedback;
  final String? actionLabel;
  final VoidCallback? onAction, onApply;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final state = this.state;
    if (state == null) {
      return LanternSettingsCallout(
          key: const ValueKey('lantern-settings-apply'),
          icon: LGlyph.verified,
          title: 'application.apply_card_title'.tr(),
          body: 'application.apply_card_desc'.tr(),
          action: Align(
              alignment: AlignmentDirectional.centerStart,
              child: LButton(
                  label: 'application.apply_btn'.tr(),
                  icon: LGlyph.check,
                  onPressed: onApply)));
    }
    final (tone, glyph, title) = switch (state) {
      LanternApplicationState.approved => (
          LTone.ok,
          LGlyph.verified,
          'application.status_approved'.tr()
        ),
      LanternApplicationState.rejected => (
          LTone.live,
          LGlyph.warn,
          'application.status_rejected'.tr()
        ),
      LanternApplicationState.pending => (
          LTone.warn,
          LGlyph.clock,
          'application.status_pending'.tr()
        ),
    };
    return Container(
        key: const ValueKey('lantern-settings-application'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: t.line)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LTag(title, tone: tone, icon: glyph),
                    LTag(
                        (organization
                                ? 'application.role_org'
                                : 'application.role_scholar')
                            .tr(),
                        outlined: true),
                  ]),
              const SizedBox(height: 10),
              Text(email.isEmpty ? name : '$name · $email',
                  style: Lantern.textStyle(14,
                      color: t.fg, weight: FontWeight.w600, height: 1.4)),
              const SizedBox(height: 10),
              LBanner(
                  feedback
                      ? '${'application.admin_feedback'.tr()}: $message'
                      : message,
                  tone: tone == LTone.ok ? LTone.ok : LTone.neutral),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 12),
                LButton(
                    key: const ValueKey('lantern-settings-application-action'),
                    label: actionLabel!,
                    icon: LGlyph.edit,
                    kind: LButtonKind.tonal,
                    size: LButtonSize.small,
                    onPressed: onAction),
              ],
            ]));
  }
}

enum LanternApplicationState { pending, approved, rejected }

/// Settings → Notifications: the alert limit, planned stream reminders, the
/// categories and the muted channels.
class LanternNotificationPrefs extends StatelessWidget
    implements LanternSkinWidget {
  const LanternNotificationPrefs(
      {super.key,
      required this.limit,
      required this.onLimit,
      required this.categories,
      required this.muted,
      this.reminders,
      this.leadMinutes = 10,
      this.onLead,
      this.pushNote,
      this.pushHelp,
      this.onEnablePush});

  final int limit;
  final ValueChanged<int> onLimit;
  final List<(String title, LGlyph icon, bool value, ValueChanged<bool>)>
      categories;
  final List<(String name, VoidCallback onUnmute)> muted;

  /// Null when reminders are not offered on this build.
  final bool? reminders;
  final int leadMinutes;
  final ValueChanged<int>? onLead;
  final String? pushNote, pushHelp;
  final VoidCallback? onEnablePush;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final ar = context.lanternArabic;
    final alerts = ar ? '$limit إشعارات' : '$limit alerts';
    return Column(
        key: const ValueKey('lantern-settings-notifications'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          LanternSettingsGroup(
              title: 'design_copy.notification_preferences'.tr(),
              children: [
                Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    decoration: BoxDecoration(
                        color: t.surface,
                        borderRadius: BorderRadius.circular(Lantern.radiusRow),
                        border: Border.all(color: t.line2)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: t.sunk,
                                    borderRadius: BorderRadius.circular(
                                        Lantern.radiusTile)),
                                child: LIcon(LGlyph.clock,
                                    size: 20, color: t.goldInk)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(
                                    'design_copy.10_minute_alert_limit'.tr(),
                                    style: Lantern.textStyle(14.5,
                                        color: t.fg,
                                        weight: FontWeight.w600,
                                        height: 1.35))),
                            LTag(alerts, tone: LTone.gold, outlined: true),
                          ]),
                          const SizedBox(height: 6),
                          Text(
                              'design_copy.prevents_notification_fatigue_by_bundling_excess_alerts_into_a_sm'
                                  .tr(),
                              style: Lantern.textStyle(12.5,
                                  color: t.muted, height: 1.4)),
                          LSlider(
                              key: const ValueKey('lantern-settings-limit'),
                              value: limit.toDouble(),
                              min: 1,
                              max: 10,
                              divisions: 9,
                              label: 'design_copy.10_minute_alert_limit'.tr(),
                              valueLabel: alerts,
                              onChanged: (v) => onLimit(v.round())),
                        ])),
                if (reminders != null) ...[
                  LRow(
                      icon: LGlyph.calendar,
                      title: 'upcoming.reminder_settings'.tr(),
                      subtitle: 'upcoming.lead_time'.tr()),
                  Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        for (var m = 5; m <= 30; m += 5)
                          LChip(
                              key: ValueKey('lantern-settings-lead-$m'),
                              label: '$m ${ar ? 'دقيقة' : 'min'}',
                              selected: m == leadMinutes,
                              dense: true,
                              onTap: onLead == null ? null : () => onLead!(m)),
                      ])),
                  if (pushNote != null)
                    LBanner(pushNote!,
                        tone: LTone.warn,
                        action: onEnablePush == null
                            ? null
                            : LButton(
                                key: const ValueKey('turn-on-notifications'),
                                label: 'upcoming.permission_enable'.tr(),
                                size: LButtonSize.small,
                                kind: LButtonKind.tonal,
                                onPressed: onEnablePush)),
                  if (pushHelp != null)
                    Text(pushHelp!,
                        style: Lantern.textStyle(12.5, color: t.muted)),
                ],
              ]),
          const SizedBox(height: 18),
          LanternSettingsGroup(
              title: 'design_copy.active_notification_categories'.tr(),
              children: [
                for (final (title, icon, value, onChanged) in categories)
                  LRow(
                      icon: icon,
                      title: title.trim(),
                      dense: true,
                      trailing: LSwitch(
                          value: value, label: title.trim(), onChanged: onChanged)),
              ]),
          if (muted.isNotEmpty) ...[
            const SizedBox(height: 18),
            LanternSettingsGroup(
                title: ar
                    ? 'القنوات المكتومة (${muted.length})'
                    : 'Muted Channels (${muted.length})',
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (name, onUnmute) in muted)
                      LChip(
                          label: name,
                          icon: LGlyph.volumeoff,
                          onTap: onUnmute,
                          onRemove: onUnmute),
                  ]),
                ]),
          ],
        ]);
  }
}

/// Settings → Privacy & data, and the account's danger zone.
class LanternPrivacyView extends StatelessWidget implements LanternSkinWidget {
  const LanternPrivacyView(
      {super.key,
      required this.showPrivacy,
      required this.showDanger,
      required this.consentStatus,
      required this.exporting,
      required this.onExport,
      required this.clearingStream,
      required this.onClearStream,
      required this.deletingAll,
      required this.onDeleteAll,
      required this.deleting,
      required this.onDelete});

  final bool showPrivacy, showDanger;
  final String consentStatus;
  final bool exporting, clearingStream, deletingAll, deleting;
  final VoidCallback onExport, onClearStream, onDeleteAll, onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    Widget busy(bool on) => on
        ? const SizedBox.square(dimension: 22, child: LStarLoader(size: 18))
        : LIcon(LGlyph.chevronend, size: 18, color: t.faint);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showPrivacy)
            LanternSettingsGroup(
                key: const ValueKey('lantern-settings-privacy'),
                children: [
                  LRow(
                      icon: LGlyph.check,
                      title: 'settings.consent_record_title'.tr(),
                      subtitle: consentStatus),
                  Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Text('settings.consent_withdraw_note'.tr(),
                          style: Lantern.textStyle(12.5, color: t.muted))),
                  LRow(
                      key: const ValueKey('lantern-settings-export'),
                      icon: LGlyph.download,
                      title: 'settings.data_export_title'.tr(),
                      subtitle: 'settings.data_export_desc'.tr(),
                      trailing: busy(exporting),
                      onTap: exporting ? null : onExport),
                ]),
          if (showDanger) ...[
            LanternSettingsGroup(
                title: 'settings.chat_history_title'.tr(),
                children: [
                  Padding(
                      padding: const EdgeInsetsDirectional.only(start: 4),
                      child: Text('settings.chat_history_desc'.tr(),
                          style: Lantern.textStyle(13, color: t.muted))),
                  LRow(
                      key: const ValueKey('lantern-settings-clear-stream'),
                      icon: LGlyph.chat,
                      title: 'settings.delete_messages_by_stream_btn'.tr(),
                      trailing: busy(clearingStream),
                      onTap: clearingStream ? null : onClearStream),
                  LRow(
                      key: const ValueKey('lantern-settings-delete-messages'),
                      icon: LGlyph.trash,
                      danger: true,
                      title: 'settings.delete_all_messages_btn'.tr(),
                      trailing: busy(deletingAll),
                      onTap: deletingAll ? null : onDeleteAll),
                ]),
            const SizedBox(height: 18),
            LanternSettingsGroup(title: 'settings.danger_zone'.tr(), children: [
              LanternSettingsCallout(
                  key: const ValueKey('lantern-settings-delete'),
                  tone: LTone.live,
                  icon: LGlyph.warn,
                  title: 'settings.delete_account_title'.tr(),
                  body: 'settings.delete_account_desc'.tr(),
                  action: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LButton(
                          key: const ValueKey('lantern-settings-delete-open'),
                          label: 'settings.delete_account_btn'.tr(),
                          icon: LGlyph.trash,
                          kind: LButtonKind.danger,
                          size: LButtonSize.small,
                          loading: deleting,
                          onPressed: deleting ? null : onDelete))),
            ]),
          ],
        ]);
  }
}

/// The three governance documents, each opening the reader.
class LanternLegalRows extends StatelessWidget implements LanternSkinWidget {
  const LanternLegalRows(
      {super.key,
      required this.version,
      required this.onOpen,
      this.support});

  final String version;
  final ValueChanged<int> onOpen;
  final Widget? support;

  @override
  Widget build(BuildContext context) => LanternSettingsGroup(
          key: const ValueKey('lantern-settings-legal'),
          title: 'settings.governance_legal'.tr(),
          children: [
            LRow(
                icon: LGlyph.book,
                title: 'settings.view_terms'.tr(),
                subtitle:
                    '${'settings.terms_version_label'.tr()}: $version',
                onTap: () => onOpen(0)),
            LRow(
                icon: LGlyph.mic,
                title: 'settings.view_guidelines'.tr(),
                subtitle: 'settings.view_guidelines_subtitle'.tr(),
                onTap: () => onOpen(1)),
            LRow(
                icon: LGlyph.lock,
                title: 'settings.view_privacy'.tr(),
                subtitle: 'settings.view_privacy_subtitle'.tr(),
                onTap: () => onOpen(2)),
            if (support != null) support!,
          ]);
}

/// One governance document with the way to the other two.
class LanternLegalReader extends StatelessWidget implements LanternSkinWidget {
  const LanternLegalReader(
      {super.key,
      required this.title,
      required this.content,
      required this.index,
      required this.onPrevious,
      required this.onNext});

  final String title, content;
  final int index;
  final VoidCallback onPrevious, onNext;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        // In a Lantern sheet the page scrolls the reader; placed in a box of
        // its own (the website footer's sheet) it scrolls the text itself
        // and brings its own close button.
        final bounded = box.maxHeight.isFinite;
        return bounded
            ? LanternSurface(
                child: Builder(
                    builder: (context) => ColoredBox(
                        color: context.lt.raised,
                        child: SafeArea(
                            child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 8, 12, 12),
                                child: _body(context, bounded: true))))))
            : _body(context, bounded: false);
      });

  Widget _body(BuildContext context, {required bool bounded}) {
    final t = context.lt;
    final heading = Semantics(
        header: true,
        child: Text(title,
            style: Lantern.displayStyle(17,
                color: t.fg, height: context.lanternArabic ? 1.45 : 1.25)));
    final text = SelectableText(content,
        style: Lantern.textStyle(14.5, color: t.fg, height: 1.7));
    return Column(
        key: const ValueKey('lantern-legal-reader'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (bounded)
            Row(children: [
              Expanded(child: heading),
              LIconButton(
                  icon: LGlyph.close,
                  label: MaterialLocalizations.of(context).closeButtonLabel,
                  onPressed: () => Navigator.of(context).maybePop()),
            ])
          else
            heading,
          const SizedBox(height: 10),
          if (bounded)
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: text))
          else
            text,
          const SizedBox(height: 16),
          Container(height: 1, color: t.line),
          const SizedBox(height: 10),
          Row(children: [
            LButton(
                label: 'settings.legal_reader_previous'.tr(),
                icon: LGlyph.back,
                kind: LButtonKind.ghost,
                size: LButtonSize.small,
                onPressed: onPrevious),
            Expanded(
                child: Text('${index + 1} / 3',
                    textAlign: TextAlign.center,
                    style: Lantern.textStyle(13, color: t.muted)
                        .copyWith(fontFeatures: Lantern.tabular))),
            LButton(
                label: 'settings.legal_reader_next'.tr(),
                trailing: LGlyph.arrow,
                kind: LButtonKind.ghost,
                size: LButtonSize.small,
                onPressed: onNext),
          ]),
        ]);
  }
}

/// Settings → About: the two logos, the name, the version and updates.
class LanternAboutCard extends StatelessWidget implements LanternSkinWidget {
  const LanternAboutCard(
      {super.key,
      required this.appName,
      this.version,
      this.latest = false,
      this.available,
      this.downloadLabel,
      this.onDownload,
      required this.onReopenWelcome});

  final String appName;
  final String? version;

  /// "You have the latest version", once a check has answered.
  final bool latest;

  /// "Version x is available", with its download.
  final String? available, downloadLabel;
  final VoidCallback? onDownload;
  final VoidCallback onReopenWelcome;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Container(
        key: const ValueKey('lantern-settings-about'),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(Lantern.radiusCard),
            border: Border.all(color: t.line)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LLogo(height: 52, onDark: t.night),
          const SizedBox(height: 14),
          Text(appName,
              textAlign: TextAlign.center,
              style: Lantern.displayStyle(22,
                  color: t.fg, height: context.lanternArabic ? 1.45 : 1.25)),
          const SizedBox(height: 4),
          Text('common.hadayah_charity'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.textStyle(13.5, color: t.muted)),
          const SizedBox(height: 12),
          if (version != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: LTag(version!,
                    key: const ValueKey('settings-installed-version'),
                    outlined: true)),
          Text('settings.release_pending'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.textStyle(12.5, color: t.muted)),
          if (latest) ...[
            const SizedBox(height: 12),
            LBanner('update.settings_latest'.tr(),
                key: const ValueKey('settings-update-latest'), tone: LTone.ok),
          ],
          if (available != null) ...[
            const SizedBox(height: 12),
            LBanner(available!,
                key: const ValueKey('settings-update-available'),
                tone: LTone.gold,
                icon: LGlyph.download),
            if (onDownload != null && downloadLabel != null) ...[
              const SizedBox(height: 10),
              LButton(
                  key: const ValueKey('settings-update-download'),
                  label: downloadLabel!,
                  icon: LGlyph.download,
                  onPressed: onDownload),
            ],
          ],
          const SizedBox(height: 18),
          LButton(
              key: const ValueKey('lantern-settings-reopen-welcome'),
              label: 'settings.reopen_onboarding'.tr(),
              icon: LGlyph.refresh,
              kind: LButtonKind.secondary,
              onPressed: onReopenWelcome),
        ]));
  }
}

/// The blocked chat accounts, from the server, each with Unblock.
class LanternBlockedAccounts extends StatelessWidget
    implements LanternSkinWidget {
  const LanternBlockedAccounts(
      {super.key,
      required this.accounts,
      required this.pending,
      required this.loading,
      required this.stale,
      required this.onRetry,
      required this.onUnblock});

  /// Id and name; an empty name is shown as an unknown account.
  final List<(String id, String? name)> accounts;
  final Set<String> pending;
  final bool loading, stale;
  final VoidCallback onRetry;
  final ValueChanged<String> onUnblock;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        key: const ValueKey('lantern-blocked-accounts'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('settings.blocked_accounts_hint'.tr(),
              style: Lantern.textStyle(13.5, color: t.muted)),
          if (stale && !loading) ...[
            const SizedBox(height: 12),
            LBanner('settings.blocked_accounts_stale'.tr(),
                key: const Key('blocked-accounts-stale'),
                tone: LTone.warn,
                icon: LGlyph.wifioff,
                action: LButton(
                    label: 'common.retry'.tr(),
                    size: LButtonSize.small,
                    kind: LButtonKind.tonal,
                    onPressed: onRetry)),
          ],
          const SizedBox(height: 14),
          if (loading && accounts.isEmpty)
            const Center(child: LStarLoader())
          else if (accounts.isEmpty)
            LEmptyState(
                key: const Key('blocked-accounts-empty'),
                compact: true,
                icon: LGlyph.ban,
                title: 'settings.blocked_accounts_empty'.tr())
          else
            for (final (id, name) in accounts)
              Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: LRow(
                      key: Key('blocked-account-$id'),
                      icon: LGlyph.ban,
                      title: (name == null || name.isEmpty)
                          ? 'settings.blocked_account_unknown'.tr()
                          : name,
                      trailing: pending.contains(id)
                          ? const SizedBox.square(
                              dimension: 22, child: LStarLoader(size: 18))
                          : LButton(
                              label: 'settings.unblock'.tr(),
                              size: LButtonSize.small,
                              kind: LButtonKind.tonal,
                              onPressed: () => onUnblock(id)))),
        ]);
  }
}

/// Settings → Lessons: a person's own pages of the lessons programme, the
/// same rows as the older card (reminders, notifications, Preachers &
/// lessons for admins, applying to give lessons or its state, a preacher's
/// page, and the programme page).
class LanternLessonsSettings extends StatefulWidget
    implements LanternSkinWidget {
  const LanternLessonsSettings({super.key});

  @override
  State<LanternLessonsSettings> createState() => _LanternLessonsSettingsState();
}

class _LanternLessonsSettingsState extends State<LanternLessonsSettings> {
  String? _preacherLink;

  @override
  void initState() {
    super.initState();
    unawaited(context.read<LessonsController?>()?.ensureLoaded());
    unawaited(PreacherLinkController.lastLink().then((t) {
      if (mounted && t != null) setState(() => _preacherLink = t);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LessonsController?>();
    if (c == null) return const SizedBox.shrink();
    final application = c.myApplication;
    final rows = <(LGlyph, String, String, String?, int)>[
      (
        LGlyph.book,
        'lessons.programme'.tr(),
        '/lessons/me',
        'settings.lessons_hint'.tr(),
        0
      ),
      if (c.canManage)
        (
          LGlyph.shield,
          'lessons.admin.title'.tr(),
          '/admin/lessons',
          null,
          c.waitingCount
        ),
      if (c.myPreacherId != null)
        (
          LGlyph.person,
          'lessons.me.preacher_page'.tr(),
          '/lessons/me/preacher',
          'lessons.me.preacher_page_hint'.tr(),
          0
        )
      else if (c.signedIn)
        (
          LGlyph.mic,
          application?.pending == true
              ? 'lessons.apply.settings_waiting'.tr()
              : 'lessons.apply.settings_row'.tr(),
          '/lessons/apply',
          application?.pending == true
              ? 'lessons.apply.settings_waiting_hint'.tr()
              : application?.status == 'rejected'
                  ? 'lessons.apply.settings_rejected_hint'.tr()
                  : 'lessons.apply.settings_hint'.tr(),
          0
        ),
      if (_preacherLink != null && c.myPreacherId == null)
        (
          LGlyph.person,
          'lessons.link.my_page'.tr(),
          '/preacher/$_preacherLink',
          'lessons.link.my_page_hint'.tr(),
          0
        ),
      (
        LGlyph.clock,
        'lessons.me.reminders'.tr(),
        '/lessons/me/saved?tab=reminders',
        null,
        c.mine.reminders.length
      ),
      (
        LGlyph.bell,
        'lessons.me.notifications'.tr(),
        '/lessons/me/notifications',
        null,
        c.mine.unread
      ),
    ];
    return LanternSettingsGroup(
        key: const ValueKey('lantern-settings-lessons'),
        children: [
          for (final (icon, title, route, subtitle, n) in rows)
            LRow(
                icon: icon,
                title: title,
                subtitle: subtitle,
                trailing: n == 0
                    ? null
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        LTag('$n', tone: LTone.gold),
                        const SizedBox(width: 6),
                        LIcon(LGlyph.chevronend,
                            size: 18, color: context.lt.faint),
                      ]),
                onTap: () => context.push(route)),
        ]);
  }
}
