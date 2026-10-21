import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final provider = context.read<AppProvider>();
    final online = await provider.refreshConnectivityNow();
    if (online) {
      await provider.loadVerifiedStreamersFromBackend();
      await provider.ensureAcademicCategoriesLoaded();
    }
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final (
      status,
      cached,
      updatedAt
    ) = context.select<AppProvider, (NetworkStatus, bool, DateTime?)>((p) =>
        (p.networkStatus, p.isUsingCachedCatalog, p.publicCatalogUpdatedAt));
    if (status == NetworkStatus.online && !cached) {
      return const SizedBox.shrink();
    }
    final title = switch (status) {
      NetworkStatus.offline => 'offline_experience.offline_title',
      NetworkStatus.degraded => 'offline_experience.degraded_title',
      NetworkStatus.online => 'offline_experience.cached_title',
    };
    final when = updatedAt == null
        ? 'offline_experience.no_snapshot'.tr()
        : 'offline_experience.last_updated'.tr(namedArgs: {
            'time': DateFormat('yyyy-MM-dd HH:mm').format(updatedAt.toLocal())
          });
    return Container(
      key: const ValueKey('connectivity_banner'),
      margin: const EdgeInsetsDirectional.fromSTEB(
          AppTheme.spaceLg, 0, AppTheme.spaceLg, AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.warning),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.warning),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.tr(),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold)),
                Text('offline_experience.body'.tr(),
                    style: const TextStyle(color: AppTheme.textSecondary)),
                Text(when, style: const TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          ),
          TextButton(
            onPressed: _retrying ? null : _retry,
            child: Text(_retrying
                ? 'offline_experience.retrying'.tr()
                : 'offline_experience.retry'.tr()),
          ),
        ],
      ),
    );
  }
}
