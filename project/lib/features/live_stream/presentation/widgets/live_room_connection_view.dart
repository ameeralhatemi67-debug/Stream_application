import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/theme/app_theme.dart';

/// A local recovery view. It does not change chat or publisher lifecycles.
class LiveRoomConnectionView extends StatefulWidget {
  const LiveRoomConnectionView({
    super.key,
    required this.status,
    this.awaitingFreshCatalog = false,
    this.liveNotConfirmed = false,
  });

  final NetworkStatus status;
  final bool awaitingFreshCatalog;
  final bool liveNotConfirmed;

  @override
  State<LiveRoomConnectionView> createState() => _LiveRoomConnectionViewState();
}

class _LiveRoomConnectionViewState extends State<LiveRoomConnectionView> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    await context.read<AppProvider>().refreshConnectivityNow();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  color: AppTheme.warning, size: 42),
              const SizedBox(height: AppTheme.spaceMd),
              Text(
                  (widget.awaitingFreshCatalog
                          ? widget.liveNotConfirmed
                              ? 'offline_experience.room_not_live'
                              : 'offline_experience.room_rechecking'
                          : 'offline_experience.room_title')
                      .tr(),
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                  (widget.awaitingFreshCatalog
                          ? widget.liveNotConfirmed
                              ? 'offline_experience.room_not_live_body'
                              : 'offline_experience.room_rechecking_body'
                          : widget.status == NetworkStatus.degraded
                              ? 'offline_experience.degraded_title'
                              : 'offline_experience.room_body')
                      .tr(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: AppTheme.spaceLg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppTheme.spaceSm,
                children: [
                  FilledButton(
                    onPressed: _retrying ? null : _retry,
                    child: Text(_retrying
                        ? 'offline_experience.retrying'.tr()
                        : 'offline_experience.retry'.tr()),
                  ),
                  TextButton(
                    onPressed: () => context.go('/feed'),
                    child: Text('offline_experience.back_to_feed'.tr()),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}
