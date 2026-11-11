import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/routing/sign_in_prompt.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../domain/lessons_dates.dart';
import '../../domain/lessons_models.dart';
import '../../domain/lessons_rules.dart';
import '../../domain/lessons_vocab.dart';
import '../../state/lessons_controller.dart';
import '../lessons_kit.dart' show lessonsError;
import '../lessons_modals.dart'
    show askForLessonAlerts, lessonShareText, lessonsLink, openExternal;
import '../lessons_widgets.dart' show prayerLabel;

/// The actions of the Lessons pages in the Lantern design. Each one calls
/// the same controller method as the older pages (lessons_modals.dart,
/// lessons_widgets.dart); only the sheets and the toasts are drawn anew.

/// Runs a write and reports a failure as a Lantern toast. Null on failure.
Future<T?> lRun<T>(BuildContext context, Future<T> Function() call,
    {String? success}) async {
  try {
    final r = await call();
    if (success != null && context.mounted) lanternToast(context, success);
    return r;
  } catch (e) {
    if (context.mounted) lanternToast(context, lessonsError(e), warn: true);
    return null;
  }
}

/// Asks a guest to sign in, saying why (the older page's showTSignIn).
Future<void> showLanternSignIn(BuildContext context, String why) =>
    showLanternDialog<void>(context,
        title: 'lessons.sign_in_title'.tr(),
        body: (ctx) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(why,
                      style: Lantern.textStyle(15,
                          color: ctx.lt.fg, weight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('lessons.sign_in_note'.tr(),
                      style: Lantern.textStyle(14, color: ctx.lt.muted)),
                ]),
        actions: (ctx) => [
              LButton(
                  label: 'lessons.sign_in'.tr(),
                  icon: LGlyph.person,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    openSignIn(context);
                  }),
            ]);

/// Whether a lesson can take a reminder: the rule of the older RemindButton.
bool canRemind(LessonsController c, Lesson l) =>
    l.isPublic && !l.date.isBefore(c.today);

void remindTap(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  c.signedIn
      ? showLanternRemindSheet(context, l)
      : showLanternSignIn(context, 'lessons.sign_in_remind'.tr());
}

/// When to remind: at the adhan, 30 minutes before, or the day before.
Future<void> showLanternRemindSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  final lang = context.locale.languageCode;
  final pt = prayerTimesFor(l.date, c.mosque(l.mosqueId), c.catalog.districts);
  final current = c.reminderLead(l.id);
  String detail(String lead) => switch (lead) {
        'adhan' => 'lessons.remind.adhan_detail'
            .tr(args: [prayerLabel(l.slot), clockLabel(pt.of(l.slot), lang)]),
        '30' => '≈ ${clockLabel(c.startHours(l) - .5, lang)}',
        _ => weekdayName(addDays(l.date, -1), lang),
      };
  Future<void> set(BuildContext sheet, String? lead) async {
    Navigator.of(sheet).pop();
    await lRun(context, () => c.setReminder(l, lead),
        success: lead == null
            ? 'lessons.remind.removed'.tr()
            : 'lessons.remind.saved'.tr());
    if (lead != null && context.mounted && c.hasReminder(l.id)) {
      askForLessonAlerts(context);
    }
  }

  return showLanternSheet<void>(context,
      title: 'lessons.remind.title'.tr(),
      body: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l.title(lang),
                    style: Lantern.textStyle(14, color: ctx.lt.muted)),
                const SizedBox(height: 12),
                for (final lead in LessonsVocab.leads)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LChoiceRow(
                          key: ValueKey('lantern-remind-$lead'),
                          title: 'lessons.lead.$lead'.tr(),
                          subtitle: detail(lead),
                          icon: lead == 'adhan'
                              ? lessonSlotGlyph(l.slot)
                              : lead == 'day'
                                  ? LGlyph.calendar
                                  : LGlyph.clock,
                          selected: current == lead,
                          onTap: () => set(ctx, lead))),
                if (current != null)
                  Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LButton(
                          label: 'lessons.remind.remove'.tr(),
                          kind: LButtonKind.ghost,
                          size: LButtonSize.small,
                          icon: LGlyph.close,
                          onPressed: () => set(ctx, null))),
                const SizedBox(height: 6),
                Text('lessons.remind.note'.tr(),
                    style: Lantern.textStyle(13, color: ctx.lt.muted)),
              ]));
}

/// Share: copy the text, the system share sheet, or WhatsApp.
Future<void> showLanternShareSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  final lang = context.locale.languageCode;
  final text = lessonShareText(c, l, lang);
  return showLanternSheet<void>(context,
      title: 'lessons.share.title'.tr(),
      body: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('lessons.share.sub'.tr(),
                    style: Lantern.textStyle(14, color: ctx.lt.muted)),
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: ctx.lt.sunk,
                        borderRadius: BorderRadius.circular(Lantern.radiusTile),
                        border: Border.all(color: ctx.lt.line)),
                    child: SelectableText(text,
                        style: Lantern.textStyle(13.5, color: ctx.lt.fg))),
                const SizedBox(height: 12),
                LChoiceRow(
                    title: 'lessons.share.copy'.tr(),
                    icon: LGlyph.copy,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      lanternCopy(context, text);
                    }),
                const SizedBox(height: 8),
                LChoiceRow(
                    title: 'lessons.lesson.share'.tr(),
                    icon: LGlyph.share,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Share.share(text);
                    }),
                const SizedBox(height: 8),
                LChoiceRow(
                    title: 'lessons.share.whatsapp'.tr(),
                    icon: LGlyph.chat,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      openExternal(Uri.parse(
                          'https://wa.me/?text=${Uri.encodeComponent(text)}'));
                    }),
              ]));
}

/// Report a wrong time or place: the controller's flag().
Future<void> showLanternFlagSheet(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  var kind = 'time';
  final msg = TextEditingController();
  return showLanternSheet<void>(context,
      title: 'lessons.flag.title'.tr(),
      body: (ctx) => StatefulBuilder(
          builder: (ctx, set) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l.title(ctx.locale.languageCode),
                        style: Lantern.textStyle(14, color: ctx.lt.muted)),
                    const SizedBox(height: 12),
                    for (final k in LessonsVocab.flagKinds)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: LChoiceRow(
                              title: 'lessons.flag_kind.$k'.tr(),
                              selected: kind == k,
                              radio: true,
                              onTap: () => set(() => kind = k))),
                    const SizedBox(height: 4),
                    LField(
                        controller: msg,
                        label:
                            '${'lessons.flag.details'.tr()} (${'lessons.optional'.tr()})',
                        hint: 'lessons.flag.hint'.tr(),
                        maxLines: 3,
                        maxLength: 1000),
                    const SizedBox(height: 10),
                    Text('lessons.flag.note'.tr(),
                        style: Lantern.textStyle(13, color: ctx.lt.muted)),
                    const SizedBox(height: 14),
                    Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: LButton(
                            label: 'lessons.flag.send'.tr(),
                            icon: LGlyph.send,
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await lRun(context,
                                  () => c.flag(l.id, kind, msg.text.trim()),
                                  success: 'lessons.flag.sent'.tr());
                            })),
                  ])));
}

Future<void> lanternCopy(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) lanternToast(context, 'lessons.copied'.tr());
}

/// Follow a preacher, series or mosque (the older FollowButton's action).
Future<void> toggleLessonsFollow(
    BuildContext context, String kind, String id) async {
  final c = context.read<LessonsController>();
  if (!c.signedIn) {
    await showLanternSignIn(context, 'lessons.sign_in_follow'.tr());
    return;
  }
  final on = c.isFollowing(kind, id);
  await lRun(context, () => c.toggleFollow(kind, id),
      success: on ? 'lessons.follow.off'.tr() : 'lessons.follow.on'.tr());
  if (!on && context.mounted) askForLessonAlerts(context);
}

/// The attended mark of a past lesson (the older AttendToggle's action).
Future<void> toggleLessonAttended(BuildContext context, Lesson l) {
  final c = context.read<LessonsController>();
  final on = c.attended(l.id);
  return lRun(context, () => c.toggleAttended(l.id),
      success: on
          ? 'lessons.calendar.removed_log'.tr()
          : 'lessons.calendar.added_log'.tr());
}

String preacherLink(String id) => lessonsLink('/lessons/preachers/$id');

/// The prayer a slot follows, as a Lantern icon.
LGlyph lessonSlotGlyph(String slot) => switch (slot) {
      'maghrib' || 'isha' || 'fajr' => LGlyph.moon,
      _ => LGlyph.sun,
    };

/// A tappable choice in a sheet: an icon disc, a title and a line, and a
/// check (or a radio ring) when it is chosen.
class LChoiceRow extends StatelessWidget implements LanternSkinWidget {
  const LChoiceRow(
      {super.key,
      required this.title,
      this.subtitle,
      this.icon,
      this.selected = false,
      this.radio = false,
      required this.onTap});

  final String title;
  final String? subtitle;
  final LGlyph? icon;
  final bool selected, radio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return LPressable(
        onTap: onTap,
        label: subtitle == null ? title : '$title, $subtitle',
        selected: selected,
        radius: Lantern.radiusTile,
        pressScale: .985,
        excludeChildSemantics: true,
        builder: (context, s) => AnimatedContainer(
            duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
            constraints: const BoxConstraints(minHeight: Lantern.target + 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                color: selected
                    ? t.sunk
                    : s.hovered
                        ? t.sunk
                        : t.surface,
                borderRadius: BorderRadius.circular(Lantern.radiusTile),
                border: Border.all(
                    color: selected ? LanternTokens.gold : t.line,
                    width: selected ? 1.5 : 1)),
            child: Row(children: [
              if (radio)
                Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsetsDirectional.only(end: 12),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selected ? LanternTokens.gold : t.faint,
                            width: selected ? 6 : 1.5)))
              else if (icon != null) ...[
                Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: t.sunk,
                        borderRadius: BorderRadius.circular(12)),
                    child: LIcon(icon!, size: 18, color: t.goldInk)),
                const SizedBox(width: 12),
              ],
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                    Text(title,
                        style: Lantern.textStyle(14.5,
                            color: t.fg, weight: FontWeight.w600, height: 1.35)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Lantern.textStyle(12.5,
                              color: t.muted, height: 1.35)),
                  ])),
              if (selected && !radio)
                const LStar(size: 16, color: LanternTokens.gold),
            ])));
  }
}
