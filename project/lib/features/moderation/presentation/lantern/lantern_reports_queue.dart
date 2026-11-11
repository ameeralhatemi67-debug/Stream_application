import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/content_report_service.dart';
import '../../../../core/widgets/lantern/lantern.dart';
import '../../../../core/widgets/safe_image_provider.dart';
import '../../../lessons/domain/lessons_dates.dart' show agoLabel;

/// The admin's moderation tab in Lantern and Arch: the chat reports it had,
/// and beside them the reports of broadcasts and channels.
class LanternModerationTab extends StatefulWidget implements LanternSkinWidget {
  const LanternModerationTab({super.key, required this.chat});

  /// The existing queue of reported chat messages.
  final Widget chat;

  @override
  State<LanternModerationTab> createState() => _LanternModerationTabState();
}

class _LanternModerationTabState extends State<LanternModerationTab> {
  bool _content = false;

  @override
  Widget build(BuildContext context) => LanternSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
            child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: LSegmented<bool>(
                    key: const ValueKey('lantern-moderation-switch'),
                    value: _content,
                    segments: [
                      (
                        value: false,
                        label: 'lantern.report.queue_tab_chat'.tr(),
                        icon: LGlyph.chat
                      ),
                      (
                        value: true,
                        label: 'lantern.report.queue_tab_content'.tr(),
                        icon: LGlyph.flag
                      ),
                    ],
                    onChanged: (v) => setState(() => _content = v)))),
        Expanded(
            child: IndexedStack(index: _content ? 1 : 0, children: [
          widget.chat,
          // Built on first use, so the queue is read only when asked for.
          if (_content)
            const LanternContentReportsQueue()
          else
            const SizedBox.shrink(),
        ])),
      ]));
}

/// The queue of reported broadcasts and channels, newest first. An admin
/// opens the channel or the broadcast, acts there, then clears the report.
class LanternContentReportsQueue extends StatefulWidget
    implements LanternSkinWidget {
  const LanternContentReportsQueue({super.key});

  @override
  State<LanternContentReportsQueue> createState() =>
      _LanternContentReportsQueueState();
}

class _LanternContentReportsQueueState
    extends State<LanternContentReportsQueue> {
  List<ContentReport>? _reports;
  final _clearing = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _reports = null);
    final reports = await context.read<AppProvider>().loadContentReports();
    if (mounted) setState(() => _reports = reports);
  }

  Future<void> _clear(ContentReport report) async {
    final sure = await showLanternDialog<bool>(context,
        title: 'lantern.report.clear_title'.tr(),
        body: (ctx) => Text('lantern.report.clear_body'.tr(),
            style: Lantern.textStyle(14.5, color: ctx.lt.muted, height: 1.5)),
        actions: (ctx) => [
              LButton(
                  label: 'design_ui.cancel'.tr(),
                  kind: LButtonKind.ghost,
                  onPressed: () => Navigator.of(ctx).pop(false)),
              LButton(
                  key: const ValueKey('lantern-report-clear-confirm'),
                  label: 'lantern.report.clear'.tr(),
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ]);
    if (sure != true || !mounted) return;
    setState(() => _clearing.add(report.id));
    final done =
        await context.read<AppProvider>().dismissContentReport(report.id);
    if (!mounted) return;
    setState(() {
      _clearing.remove(report.id);
      if (done) {
        _reports = [
          for (final r in _reports ?? const <ContentReport>[])
            if (r.id != report.id) r
        ];
      }
    });
    lanternToast(
        context,
        (done ? 'lantern.report.cleared' : 'lantern.report.clear_failed').tr(),
        warn: !done,
        icon: done ? LGlyph.check : LGlyph.warn);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.lt;
    final lang = context.locale.languageCode;
    final reports = _reports;
    final provider = context.read<AppProvider>();
    return ListView(
        key: const ValueKey('lantern-content-reports'),
        padding: const EdgeInsets.all(16),
        children: [
          Row(children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text('lantern.report.queue_tab_content'.tr(),
                        style: Lantern.displayStyle(18,
                            color: t.fg,
                            height: context.lanternArabic ? 1.45 : 1.25)))),
            if (reports != null && reports.isNotEmpty)
              LTag('${reports.length}', tone: LTone.gold),
            const SizedBox(width: 4),
            LIconButton(
                icon: LGlyph.refresh,
                label: 'organization_v1.refresh'.tr(),
                onPressed: reports == null ? null : _load),
          ]),
          const SizedBox(height: 4),
          Text('lantern.report.queue_lead'.tr(),
              style: Lantern.textStyle(13.5, color: t.muted, height: 1.5)),
          const SizedBox(height: 14),
          if (reports == null)
            for (var i = 0; i < 3; i++)
              const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LSkeleton(height: 96, radius: Lantern.radiusCard))
          else if (reports.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: LEmptyState(
                    key: const ValueKey('lantern-content-reports-empty'),
                    icon: LGlyph.flag,
                    title: 'lantern.report.queue_empty_title'.tr(),
                    body: 'lantern.report.queue_empty_body'.tr()))
          else
            for (final report in reports)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: () {
                    final channel =
                        provider.getStreamerById(report.channelProfileId);
                    final name = channel?.getLocalizedName(lang) ??
                        'lantern.report.unknown_channel'.tr();
                    final stream = report.kind == ContentReportKind.stream;
                    return LCard(
                        key: ValueKey('lantern-content-report-${report.id}'),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(children: [
                                LAvatar(
                                    name: name,
                                    image: resolveImageProviderOrNull(
                                        channel?.avatarUrl),
                                    size: 38,
                                    org: channel?.isOrganization ?? false),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      Text(name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Lantern.textStyle(14.5,
                                              color: t.fg,
                                              weight: FontWeight.w600,
                                              height: 1.35)),
                                      Text(agoLabel(report.createdAt, lang),
                                          style: Lantern.textStyle(12.5,
                                              color: t.muted, height: 1.35)),
                                    ])),
                                LTag(
                                    (stream
                                            ? 'lantern.report.kind_stream'
                                            : 'lantern.report.kind_channel')
                                        .tr(),
                                    icon: stream ? LGlyph.video : LGlyph.person),
                              ]),
                              const SizedBox(height: 10),
                              LTag(
                                  ContentReportReason.labelKey(report.reason)
                                      .tr(),
                                  tone: LTone.warn,
                                  icon: LGlyph.flag),
                              if ((report.note ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(report.note!,
                                    style: Lantern.textStyle(14,
                                        color: t.fg, height: 1.5)),
                              ],
                              const SizedBox(height: 12),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                if (stream && report.streamId != null)
                                  LButton(
                                      label: 'lantern.report.open_stream'.tr(),
                                      kind: LButtonKind.secondary,
                                      size: LButtonSize.small,
                                      icon: LGlyph.play,
                                      onPressed: () => context
                                          .push('/live/${report.streamId}')),
                                LButton(
                                    label: 'lantern.map.open_channel'.tr(),
                                    kind: LButtonKind.secondary,
                                    size: LButtonSize.small,
                                    icon: LGlyph.person,
                                    onPressed: () => context.push(
                                        '/profile/${report.channelProfileId}')),
                                LButton(
                                    key: ValueKey(
                                        'lantern-report-clear-${report.id}'),
                                    label: 'lantern.report.clear'.tr(),
                                    kind: LButtonKind.ghost,
                                    size: LButtonSize.small,
                                    icon: LGlyph.check,
                                    loading: _clearing.contains(report.id),
                                    onPressed: _clearing.contains(report.id)
                                        ? null
                                        : () => _clear(report)),
                              ]),
                            ]));
                  }()),
        ]);
  }
}
