import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../services/map_offline_store.dart';
import '../../services/map_pack_controller.dart';

/// Always-visible map credit: the pack's short OpenStreetMap credit link plus a
/// 48 px information button that opens the local notices and map status.
/// Never ellipsized; it wraps at large text sizes instead.
class MapAttributionRail extends StatelessWidget {
  const MapAttributionRail({
    super.key,
    required this.controller,
    required this.onDetails,
  });

  final MapPackController controller;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final manifest = controller.manifest;
    final credit = manifest?.attributionShort ?? kOsmCreditFallback;
    final url =
        manifest?.attributionUrl ?? 'https://www.openstreetmap.org/copyright';
    return Material(
      color: AppTheme.surface.withValues(alpha: 0.9),
      borderRadius: const BorderRadiusDirectional.only(
          topEnd: Radius.circular(AppTheme.radiusSm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            link: true,
            label: 'map.credit_link_label'.tr(namedArgs: {'credit': credit}),
            excludeSemantics: true,
            child: InkWell(
              onTap: () => launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                      start: AppTheme.spaceSm, end: AppTheme.spaceXs),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      credit,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'map.details_open'.tr(),
            onPressed: onDetails,
            icon: const Icon(Icons.info_outline_rounded,
                size: 20, color: AppTheme.textSecondary),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          ),
        ],
      ),
    );
  }
}

/// Browser only: a one-line suggestion to prepare the offline map, shown
/// until the user prepares or dismisses it (and again if the browser removes
/// a prepared copy).
class MapWebOfflineHint extends StatelessWidget {
  const MapWebOfflineHint({
    super.key,
    required this.evicted,
    required this.onPrepare,
    required this.onDismiss,
  });

  final bool evicted;
  final VoidCallback onPrepare;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.mapOverlayRadius),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: AppTheme.spaceMd),
        child: Row(
          children: [
            const Icon(Icons.download_for_offline_outlined,
                color: AppTheme.primary, size: 20),
            const SizedBox(width: AppTheme.spaceSm),
            Expanded(
              child: Text(
                (evicted
                        ? 'map.web_offline_hint_evicted'
                        : 'map.web_offline_hint')
                    .tr(),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 12.5),
              ),
            ),
            TextButton(
              onPressed: onPrepare,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text('map.web_offline_hint_prepare'.tr()),
            ),
            if (!evicted)
              IconButton(
                tooltip: 'map.web_offline_hint_dismiss'.tr(),
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.textSecondary),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact, single-line backend status for the map ("Offline · saved
/// venues from …"). Map streets never depend on it.
class MapConnectionChip extends StatelessWidget {
  const MapConnectionChip({
    super.key,
    required this.label,
    required this.isRetrying,
    required this.onRetry,
    required this.onDetails,
  });

  final String label;
  final bool isRetrying;
  final VoidCallback onRetry;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface.withValues(alpha: 0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.mapOverlayRadius),
        side: BorderSide(color: AppTheme.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              liveRegion: true,
              child: InkWell(
                onTap: onDetails,
                borderRadius: BorderRadius.circular(AppTheme.mapOverlayRadius),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMd,
                        vertical: AppTheme.spaceXs),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            color: AppTheme.warning, size: 18),
                        const SizedBox(width: AppTheme.spaceSm),
                        Expanded(
                          child: Text(
                            label,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: isRetrying ? null : onRetry,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primary,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              isRetrying
                  ? 'map.offline_retrying'.tr()
                  : 'map.offline_retry'.tr(),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown over the map when the local pack is still opening or cannot be
/// used. Venue pins, the list and live actions keep working underneath.
class MapPackStatusCard extends StatelessWidget {
  const MapPackStatusCard({
    super.key,
    required this.controller,
    required this.onShowList,
    this.showListAction = true,
  });

  final MapPackController controller;
  final VoidCallback onShowList;
  final bool showListAction;

  static String problemText(MapPackProblem? problem) => switch (problem) {
        MapPackProblem.corrupt => 'map.pack_problem_corrupt'.tr(),
        MapPackProblem.incompatible => 'map.pack_problem_incompatible'.tr(),
        _ => 'map.pack_problem_missing'.tr(),
      };

  @override
  Widget build(BuildContext context) {
    if (controller.status == MapPackStatus.loading) {
      return Semantics(
        liveRegion: true,
        label: 'map.pack_loading'.tr(),
        child: const Padding(
          padding: EdgeInsets.all(AppTheme.spaceMd),
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border.all(color: AppTheme.borderStrong),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.mapOverlayShadow,
      ),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map_outlined, color: AppTheme.warning),
                const SizedBox(width: AppTheme.spaceSm),
                Expanded(
                  child: Text('map.pack_unavailable_title'.tr(),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(problemText(controller.problem),
                style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: AppTheme.spaceSm,
              runSpacing: AppTheme.spaceXs,
              children: [
                OutlinedButton(
                  onPressed: controller.retry,
                  child: Text('map.pack_retry'.tr()),
                ),
                if (showListAction)
                  TextButton(
                    onPressed: onShowList,
                    child: Text('map.broadcasters_list'.tr()),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime? value) =>
    value == null ? '' : DateFormat('yyyy-MM-dd HH:mm').format(value.toLocal());

/// Map details: what is stored locally, venue list age, browser offline
/// preparation, credits and the bundled licence notices. Opened from the
/// credit rail's information button and the connection chip.
Future<void> showMapDetailsSheet(
  BuildContext context, {
  required MapPackController controller,
  required DateTime? venuesUpdatedAt,
  required bool backendOnline,
}) {
  // Re-inspect browser storage: it may have been cleared or evicted since
  // the status was last read.
  unawaited(controller.refreshWebOffline());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) => _MapDetailsBody(
          controller: controller,
          venuesUpdatedAt: venuesUpdatedAt,
          backendOnline: backendOnline,
          scroll: scroll,
        ),
      ),
    ),
  );
}

class _MapDetailsBody extends StatelessWidget {
  const _MapDetailsBody({
    required this.controller,
    required this.venuesUpdatedAt,
    required this.backendOnline,
    required this.scroll,
  });

  final MapPackController controller;
  final DateTime? venuesUpdatedAt;
  final bool backendOnline;
  final ScrollController scroll;

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            ...children,
          ],
        ),
      );

  Text _body(String text) => Text(text,
      style: const TextStyle(color: AppTheme.textSecondary, height: 1.4));

  @override
  Widget build(BuildContext context) {
    final manifest = controller.manifest;
    final pack = manifest?.file('basemap.pmtiles');
    final web = controller.webOffline;
    return SafeArea(
      child: ListView(
        controller: scroll,
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        children: [
          _section('map.details_title'.tr(), [
            _body(controller.isReady
                ? (!controller.supportsWebOffline
                        ? 'map.details_pack_ready'
                        : web?.state == WebOfflineState.ready
                            ? 'map.details_pack_saved_web'
                            : 'map.details_pack_ready_web')
                    .tr(namedArgs: {'date': manifest?.dataDate ?? ''})
                : controller.status == MapPackStatus.loading
                    ? 'map.pack_loading'.tr()
                    : MapPackStatusCard.problemText(controller.problem)),
            const SizedBox(height: AppTheme.spaceXs),
            _body('map.details_coverage'.tr()),
            if (manifest != null && manifest.isStale(DateTime.now())) ...[
              const SizedBox(height: AppTheme.spaceXs),
              _body('map.details_pack_stale'
                  .tr(namedArgs: {'date': manifest.dataDate})),
            ],
            if (pack != null) ...[
              const SizedBox(height: AppTheme.spaceXs),
              Text(
                'map.details_pack_id'.tr(namedArgs: {
                  'id': manifest!.packId,
                  'size': (pack.bytes / (1 << 20)).toStringAsFixed(1),
                }),
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
            ],
            if (!controller.isReady &&
                controller.status != MapPackStatus.loading) ...[
              const SizedBox(height: AppTheme.spaceSm),
              OutlinedButton(
                onPressed: controller.retry,
                child: Text('map.pack_retry'.tr()),
              ),
            ],
          ]),
          _section('map.details_venues_title'.tr(), [
            _body(backendOnline
                ? 'map.details_venues_online'.tr()
                : venuesUpdatedAt == null
                    ? 'map.offline_last_updated_never'.tr()
                    : 'map.details_venues_saved'
                        .tr(namedArgs: {'time': _date(venuesUpdatedAt)})),
          ]),
          if (controller.supportsWebOffline && web != null)
            _section('map.web_offline_title'.tr(), [
              _body(_webText(web, pack?.bytes)),
              const SizedBox(height: AppTheme.spaceSm),
              if (web.state == WebOfflineState.preparing)
                LinearProgressIndicator(
                  value: web.total == 0 ? null : web.done / web.total,
                )
              else if (web.state != WebOfflineState.unsupported)
                Wrap(
                  spacing: AppTheme.spaceSm,
                  runSpacing: AppTheme.spaceXs,
                  children: [
                    if (web.state != WebOfflineState.ready)
                      FilledButton(
                        // Needs this website reachable, not the backend:
                        // a failed download is reported, never "ready".
                        onPressed: controller.isReady
                            ? controller.prepareWebOffline
                            : null,
                        child: Text('map.web_offline_prepare'.tr()),
                      ),
                    if (web.state == WebOfflineState.ready ||
                        web.state == WebOfflineState.evicted)
                      OutlinedButton(
                        onPressed: () => _confirmRemove(context),
                        child: Text('map.web_offline_remove'.tr()),
                      ),
                  ],
                ),
            ]),
          _section('map.details_credits_title'.tr(), [
            _body('map.details_credits_body'.tr()),
            TextButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(manifest?.attributionShort ?? kOsmCreditFallback),
              onPressed: () => launchUrl(
                  Uri.parse(manifest?.attributionUrl ??
                      'https://www.openstreetmap.org/copyright'),
                  mode: LaunchMode.externalApplication),
            ),
            if (controller.notice != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('map.details_notices'.tr(),
                    style: const TextStyle(color: AppTheme.textPrimary)),
                children: [
                  SelectableText(
                    controller.notice!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
          ]),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('map.web_offline_remove_title'.tr()),
        content: Text('map.web_offline_remove_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('design_ui.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('map.web_offline_remove'.tr()),
          ),
        ],
      ),
    );
    if (remove == true) await controller.resetWebOffline();
  }

  String _webText(WebOfflineStatus status, int? packBytes) {
    final size = packBytes == null
        ? ''
        : (packBytes / (1 << 20) + 20).toStringAsFixed(0);
    return switch (status.state) {
      WebOfflineState.notPrepared =>
        'map.web_offline_not_prepared'.tr(namedArgs: {'size': size}),
      WebOfflineState.preparing => 'map.web_offline_preparing'.tr(
          namedArgs: {'done': '${status.done}', 'total': '${status.total}'}),
      WebOfflineState.ready => 'map.web_offline_ready'
          .tr(namedArgs: {'date': _date(status.preparedAt)}),
      WebOfflineState.evicted => 'map.web_offline_evicted'.tr(),
      WebOfflineState.unsupported => 'map.web_offline_unsupported'.tr(),
      WebOfflineState.failed => switch (status.detail) {
          'quota' => 'map.web_offline_failed_quota'.tr(),
          'private' => 'map.web_offline_failed_private'.tr(),
          'mismatch' => 'map.web_offline_failed_mismatch'.tr(),
          'incomplete' => 'map.web_offline_failed_incomplete'.tr(),
          'unsupported' => 'map.web_offline_unsupported'.tr(),
          _ => 'map.web_offline_failed_network'.tr(),
        },
    };
  }
}
