import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/routing/sign_in_prompt.dart';
import '../../../../core/services/content_report_service.dart';
import '../../../../core/widgets/lantern/lantern.dart';

/// Report a broadcast or a channel (Lantern and Arch).
///
/// A viewer picks one reason, may add a few words, and sends. The report
/// goes to the platform's admins only; the channel is not told who sent it.
/// A guest is asked to sign in first, because a report needs an account
/// behind it.
Future<void> showLanternReportSheet(BuildContext context,
    {required ContentReportKind kind,
    required String channelProfileId,
    required String name,
    String? streamId}) {
  final provider = context.read<AppProvider>();
  if (provider.currentUserId == null) {
    return showLanternDialog<void>(context,
        title: 'lantern.report.sign_in_title'.tr(),
        body: (ctx) => Text('lantern.report.sign_in_body'.tr(),
            style: Lantern.textStyle(14.5, color: ctx.lt.muted, height: 1.5)),
        actions: (ctx) => [
              LButton(
                  label: 'design_ui.cancel'.tr(),
                  kind: LButtonKind.ghost,
                  onPressed: () => Navigator.of(ctx).pop()),
              LButton(
                  key: const ValueKey('lantern-report-sign-in'),
                  label: 'lessons.sign_in'.tr(),
                  icon: LGlyph.person,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    openSignIn(context);
                  }),
            ]);
  }
  return showLanternSheet<void>(context,
      title: (kind == ContentReportKind.stream
              ? 'lantern.report.title_stream'
              : 'lantern.report.title_channel')
          .tr(),
      body: (sheet) => ChangeNotifierProvider<AppProvider>.value(
          value: provider,
          child: _ReportForm(
              kind: kind,
              channelProfileId: channelProfileId,
              streamId: streamId,
              name: name,
              // Toasts show over the page the sheet was opened from.
              host: context)));
}

class _ReportForm extends StatefulWidget {
  const _ReportForm(
      {required this.kind,
      required this.channelProfileId,
      required this.name,
      required this.host,
      this.streamId});

  final ContentReportKind kind;
  final String channelProfileId, name;
  final String? streamId;
  final BuildContext host;

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _note = TextEditingController();
  String? _reason, _failure;
  bool _sending = false, _missing = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    if (_reason == null) {
      setState(() => _missing = true);
      return;
    }
    setState(() {
      _sending = true;
      _failure = null;
    });
    final outcome = await context.read<AppProvider>().submitContentReport(
        kind: widget.kind,
        channelProfileId: widget.channelProfileId,
        streamId: widget.streamId,
        reason: _reason!,
        note: _note.text);
    if (!mounted) return;
    final failed = outcome == ContentReportOutcome.failed ||
        outcome == ContentReportOutcome.tooMany ||
        outcome == ContentReportOutcome.signIn;
    final message = 'lantern.report.outcome_${outcome.name}'.tr();
    // A failure keeps the sheet open and says why in it, so the choice is
    // not lost.
    setState(() {
      _sending = false;
      _failure = failed ? message : null;
    });
    if (failed) return;
    Navigator.of(context).pop();
    final host = widget.host;
    if (host.mounted) lanternToast(host, message);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Column(
        key: const ValueKey('lantern-report-form'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Lantern.textStyle(14.5,
                  color: t.fg, weight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 4),
          Text('lantern.report.lead'.tr(),
              style: Lantern.textStyle(13.5, color: t.muted, height: 1.5)),
          const SizedBox(height: 14),
          Semantics(
              container: true,
              label: 'lantern.report.reason'.tr(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final reason in ContentReportReason.all)
                  _ReasonRow(
                      key: ValueKey('lantern-report-reason-$reason'),
                      label: ContentReportReason.labelKey(reason).tr(),
                      selected: _reason == reason,
                      onTap: _sending
                          ? null
                          : () => setState(() {
                                _reason = reason;
                                _missing = false;
                              })),
              ])),
          if (_missing)
            Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: LBanner('lantern.report.pick_reason'.tr(),
                    tone: LTone.warn)),
          const SizedBox(height: 10),
          LField(
              key: const ValueKey('lantern-report-note'),
              controller: _note,
              label: 'lantern.report.note'.tr(),
              hint: 'lantern.report.note_hint'.tr(),
              maxLines: 3,
              minLines: 2,
              maxLength: 500,
              enabled: !_sending),
          const SizedBox(height: 14),
          if (_failure != null) ...[
            LBanner(_failure!,
                key: const ValueKey('lantern-report-failure'),
                tone: LTone.live),
            const SizedBox(height: 10),
          ],
          LButton(
              key: const ValueKey('lantern-report-send'),
              label: 'lantern.report.send'.tr(),
              icon: LGlyph.flag,
              expand: true,
              loading: _sending,
              onPressed: _sending ? null : _send),
          const SizedBox(height: 10),
          Text('lantern.report.privacy'.tr(),
              textAlign: TextAlign.center,
              style: Lantern.textStyle(12.5, color: t.muted, height: 1.45)),
        ]);
  }
}

/// One reason: a radio mark and its words.
class _ReasonRow extends StatelessWidget {
  const _ReasonRow(
      {super.key,
      required this.label,
      required this.selected,
      required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: LPressable(
            label: label,
            selected: selected,
            excludeChildSemantics: true,
            radius: Lantern.radiusRow,
            pressScale: .99,
            onTap: onTap,
            builder: (context, s) => AnimatedContainer(
                duration: Lantern.calm(context) ? Lantern.none : Lantern.state,
                constraints: const BoxConstraints(minHeight: Lantern.target),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: selected || s.hovered ? t.sunk : t.surface,
                    borderRadius: BorderRadius.circular(Lantern.radiusRow),
                    border: Border.all(
                        color: selected ? LanternTokens.gold : t.line2,
                        width: selected ? 1.5 : 1)),
                child: Row(children: [
                  Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: selected ? LanternTokens.gold : t.line,
                              width: 1.5)),
                      child: selected
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                  color: LanternTokens.gold,
                                  shape: BoxShape.circle))
                          : null),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(label,
                          style: Lantern.textStyle(14.5,
                              color: t.fg,
                              weight:
                                  selected ? FontWeight.w600 : FontWeight.w500,
                              height: 1.35))),
                ]))));
  }
}
