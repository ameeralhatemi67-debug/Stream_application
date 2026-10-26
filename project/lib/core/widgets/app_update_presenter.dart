import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_distribution.dart';
import '../providers/app_provider.dart';
import '../providers/app_update_controller.dart';
import '../routing/app_router.dart';
import '../services/app_release_service.dart';

/// Offers a newer release once per version (ADR-017), with "Later" and
/// "Download". It waits for a quiet moment: one of the main tabs or Settings,
/// nothing open on top, and no phone broadcast running. Owned by the app root
/// (main.dart), like [DeviceSessionPresenter].
class AppUpdatePresenter {
  AppUpdatePresenter(
      {required this.updates, required this.provider, required this.router});

  final AppUpdateController updates;
  final AppProvider provider;
  final GoRouter router;
  bool _showing = false;
  bool _disposed = false;

  static const quietPaths = {'/feed', '/map', '/lessons', '/settings'};

  void attach() {
    updates.addListener(_evaluate);
    provider.addListener(_evaluate);
    router.routerDelegate.addListener(_evaluate);
  }

  void dispose() {
    _disposed = true;
    updates.removeListener(_evaluate);
    provider.removeListener(_evaluate);
    router.routerDelegate.removeListener(_evaluate);
  }

  bool get _isQuiet {
    if (provider.authHydrating || provider.isBroadcastingLive) return false;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    if (!quietPaths.contains(path)) return false;
    return !(AppRouter.rootNavigatorKey.currentState?.canPop() ?? true);
  }

  void _evaluate() {
    if (_showing || !updates.promptPending || !_isQuiet) return;
    final release = updates.release!;
    _showing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = AppRouter.rootNavigatorKey.currentContext;
      if (_disposed || context == null || !updates.promptPending) {
        _showing = false;
        return;
      }
      final download = await showDialog<bool>(
        context: context,
        builder: (dialogContext) =>
            UpdateAvailableDialog(release: release, updates: updates),
      );
      // Any way of closing it (Later, Back, a tap outside) settles this
      // release on this device; Settings keeps the download.
      await updates.dismiss();
      if (download == true) await updates.openDownload();
      _showing = false;
    });
    // A check that only finds "available" rebuilds nothing on screen, so no
    // frame would come to run the callback until the next touch.
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

class UpdateAvailableDialog extends StatelessWidget {
  const UpdateAvailableDialog(
      {super.key, required this.release, required this.updates});

  final AppRelease release;
  final AppUpdateController updates;

  @override
  Widget build(BuildContext context) {
    final notes = release.notes(context.locale.languageCode);
    return AlertDialog(
      key: const Key('update-available-dialog'),
      title: Text('update.available_title'.tr()),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('update.available_body'
                .tr(namedArgs: {'version': release.versionName})),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('update.whats_new'.tr(),
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(notes),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('update-available-later'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('update.later'.tr()),
        ),
        TextButton(
          key: const Key('update-available-download'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(updates.distribution == AppDistribution.play
              ? 'update.open_play'.tr()
              : 'update.download'.tr()),
        ),
      ],
    );
  }
}
