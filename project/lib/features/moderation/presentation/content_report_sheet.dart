import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/app_provider.dart';
import '../../../core/routing/sign_in_prompt.dart';
import '../../../core/services/content_report_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ds/ca_surfaces.dart';
import '../../../core/widgets/hadayah_loading_indicator.dart';
import '../../admin/presentation/admin_surface.dart';

/// Report a broadcast or a channel, in the gold & black and Hedayah designs.
///
/// It follows the way those designs already report a chat message: a sheet
/// of reasons, one tap sends, and a message bar says what happened. The
/// Lantern design has its own sheet (`lantern/lantern_report_sheet.dart`).
/// A guest is asked to sign in first, because a report needs an account
/// behind it.
Future<void> showContentReportSheet(BuildContext context,
    {required ContentReportKind kind,
    required String channelProfileId,
    required String name,
    String? streamId}) async {
  final provider = context.read<AppProvider>();
  final messenger = ScaffoldMessenger.of(context);
  if (provider.currentUserId == null) {
    messenger.showSnackBar(SnackBar(
        content: Text('lantern.report.sign_in_body'.tr()),
        action: SnackBarAction(
            label: 'lessons.sign_in'.tr(),
            onPressed: () {
              if (context.mounted) openSignIn(context);
            })));
    return;
  }
  final reason = await showCaSheet<String>(context,
      title: '',
      framed: false,
      body: _ReasonMenu(kind: kind, name: name));
  if (reason == null) return;
  final outcome = await provider.submitContentReport(
      kind: kind,
      channelProfileId: channelProfileId,
      streamId: streamId,
      reason: reason);
  final accepted = outcome == ContentReportOutcome.sent ||
      outcome == ContentReportOutcome.already;
  messenger.showSnackBar(SnackBar(
      content: Text('lantern.report.outcome_${outcome.name}'.tr()),
      backgroundColor: accepted ? null : Canopy.liveCrimson));
}

class _ReasonMenu extends StatelessWidget {
  const _ReasonMenu({required this.kind, required this.name});

  final ContentReportKind kind;
  final String name;

  @override
  Widget build(BuildContext context) {
    return CaSheet(
        key: const ValueKey('content-report-sheet'),
        title: (kind == ContentReportKind.stream
                ? 'lantern.report.title_stream'
                : 'lantern.report.title_channel')
            .tr(),
        onClose: () => Navigator.of(context).pop(),
        body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      AppTheme.spaceMd, 0, AppTheme.spaceMd, AppTheme.spaceSm),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Canopy.ink,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('lantern.report.lead'.tr(),
                            style: const TextStyle(
                                color: Canopy.slate, fontSize: 13)),
                      ])),
              for (final reason in ContentReportReason.all)
                ListTile(
                    key: ValueKey('content-report-reason-$reason'),
                    title: Text(ContentReportReason.labelKey(reason).tr(),
                        style: const TextStyle(color: Canopy.ink)),
                    onTap: () => Navigator.of(context).pop(reason)),
              Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Text('lantern.report.privacy'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Canopy.slate, fontSize: 12))),
            ]));
  }
}

/// The admin's list of reported broadcasts and channels, in the gold & black
/// and Hedayah designs. It draws nothing while the list is empty, so the
/// moderation tab looks as before until a report arrives.
class ContentReportsSection extends StatefulWidget {
  const ContentReportsSection({super.key});

  @override
  State<ContentReportsSection> createState() => _ContentReportsSectionState();
}

class _ContentReportsSectionState extends State<ContentReportsSection> {
  List<ContentReport> _reports = const [];
  final Set<String> _clearing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reports = await context.read<AppProvider>().loadContentReports();
    if (mounted) setState(() => _reports = reports);
  }

  Future<void> _clear(ContentReport report) async {
    final sure = await showCaDialog<bool>(
        context: context,
        builder: (dialog) => CaAlertDialog(
                title: Text('lantern.report.clear_title'.tr()),
                content: Text('lantern.report.clear_body'.tr()),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialog, false),
                      child: Text('settings.cancel'.tr())),
                  ElevatedButton(
                      key: const ValueKey('content-report-clear-confirm'),
                      onPressed: () => Navigator.pop(dialog, true),
                      child: Text('lantern.report.clear'.tr())),
                ]));
    if (sure != true || !mounted) return;
    setState(() => _clearing.add(report.id));
    final messenger = ScaffoldMessenger.of(context);
    final done =
        await context.read<AppProvider>().dismissContentReport(report.id);
    if (!mounted) return;
    setState(() {
      _clearing.remove(report.id);
      if (done) {
        _reports = [
          for (final r in _reports)
            if (r.id != report.id) r
        ];
      }
    });
    messenger.showSnackBar(SnackBar(
        content: Text(
            (done ? 'lantern.report.cleared' : 'lantern.report.clear_failed')
                .tr()),
        backgroundColor: done ? Canopy.leaf : Canopy.liveCrimson));
  }

  @override
  Widget build(BuildContext context) {
    if (_reports.isEmpty) return const SizedBox.shrink();
    final provider = context.read<AppProvider>();
    final lang = context.locale.languageCode;
    return Column(
        key: const ValueKey('content-reports-section'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('lantern.report.queue_tab_content'.tr(),
              style: const TextStyle(
                  color: Canopy.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(height: 4),
          Text('lantern.report.queue_lead'.tr(),
              style: const TextStyle(color: Canopy.slate, fontSize: 12)),
          const SizedBox(height: AppTheme.spaceMd),
          for (final report in _reports)
            Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
                child: _card(provider, report, lang)),
          const Divider(color: Canopy.hairline),
          const SizedBox(height: AppTheme.spaceMd),
        ]);
  }

  Widget _card(AppProvider provider, ContentReport report, String lang) {
    final name =
        provider.getStreamerById(report.channelProfileId)?.getLocalizedName(lang) ??
            'lantern.report.unknown_channel'.tr();
    final stream = report.kind == ContentReportKind.stream;
    final clearing = _clearing.contains(report.id);
    return AdminCard(
        key: ValueKey('content-report-${report.id}'),
        padding: const EdgeInsets.all(AppTheme.spaceMd),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  '${(stream ? 'lantern.report.kind_stream' : 'lantern.report.kind_channel').tr()} · $name',
                  style: const TextStyle(
                      color: Canopy.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              const SizedBox(height: 6),
              Text(ContentReportReason.labelKey(report.reason).tr(),
                  style:
                      const TextStyle(color: AppTheme.warning, fontSize: 12)),
              if ((report.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(report.note!,
                    style:
                        const TextStyle(color: Canopy.slate, fontSize: 12.5)),
              ],
              const SizedBox(height: 4),
              Text(
                  DateFormat('yyyy-MM-dd HH:mm', lang)
                      .format(report.createdAt.toLocal()),
                  style: const TextStyle(color: Canopy.haze, fontSize: 12)),
              const SizedBox(height: AppTheme.spaceMd),
              if (clearing)
                const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: HadayahLoadingIndicator(
                            strokeWidth: 2, color: AppTheme.primary)))
              else
                Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (stream && report.streamId != null)
                        OutlinedButton(
                            onPressed: () =>
                                context.push('/live/${report.streamId}'),
                            child: Text('lantern.report.open_stream'.tr())),
                      OutlinedButton(
                          onPressed: () => context
                              .push('/profile/${report.channelProfileId}'),
                          child: Text('lantern.map.open_channel'.tr())),
                      ElevatedButton(
                          key: ValueKey('content-report-clear-${report.id}'),
                          onPressed: () => _clear(report),
                          child: Text('lantern.report.clear'.tr())),
                    ]),
            ]));
  }
}
