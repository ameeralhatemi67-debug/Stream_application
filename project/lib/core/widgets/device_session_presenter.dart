import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';
import '../routing/app_router.dart';
import 'device_session_conflict_dialog.dart';

/// Presents account and broadcaster-device changes on the root navigator:
/// DeviceSessionConflictDialog when another device holds the primary
/// broadcaster role on this account, the lost-session notice when this
/// device is displaced, the reason when the server ended this device's
/// broadcast, and an explicit refusal when a Google sign-in was refused. Owned by the app root (main.dart) and attached as an
/// [AppProvider] listener.
class DeviceSessionPresenter {
  DeviceSessionPresenter({required this.provider, required this.router});

  final AppProvider provider;
  final GoRouter router;
  bool _conflictDialogShown = false;
  bool _broadcastLossShown = false;
  bool _disposed = false;
  int? _remoteEndSeen;
  int _authRefusalSeen = 0;
  int _miniEndedSeen = 0;

  void attach() {
    provider.addListener(_onProviderChanged);
    router.routerDelegate.addListener(_onProviderChanged);
  }

  void dispose() {
    _disposed = true;
    provider.removeListener(_onProviderChanged);
    router.routerDelegate.removeListener(_onProviderChanged);
  }

  /// A dialog is a pageless route on top of the current page. Opened while
  /// sign-in is still hydrating or while the splash page is showing, it is
  /// removed as soon as the router replaces that page -- which is why the
  /// owner never saw it on the second phone (P6-R02).
  bool get _pageIsSettled {
    if (provider.authHydrating) return false;
    final path = router.routerDelegate.currentConfiguration.uri.path;
    return path != '/splash' && path != '/login-callback';
  }

  /// Localized explanation for a broadcast the server ended while this
  /// device kept its broadcaster role.
  static String remoteEndMessageKey(String? reason) => switch (reason) {
        'admin_end' => 'broadcast_ended.admin_end',
        'admin_remove' => 'broadcast_ended.admin_remove',
        'stale_expired' => 'broadcast_ended.stale_expired',
        'replaced' => 'broadcast_ended.replaced',
        'ingest_lost' => 'broadcast_ended.ingest_lost',
        'organization_revoked' => 'broadcast_ended.organization_revoked',
        _ => 'broadcast_ended.generic',
      };

  void _presentRemoteEnd() {
    final generation = provider.remoteBroadcastEndGeneration;
    _remoteEndSeen ??= generation;
    if (generation == _remoteEndSeen || !_pageIsSettled) return;
    _remoteEndSeen = generation;
    final key = remoteEndMessageKey(provider.remoteBroadcastEndReason);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final context = AppRouter.rootNavigatorKey.currentContext;
      if (context == null) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('broadcast-remote-end-dialog'),
          title: Text('broadcast_ended.title'.tr()),
          content: Text(key.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('broadcast_ended.ok'.tr()),
            ),
          ],
        ),
      );
    });
  }

  /// A refused Google sign-in. Always explicit: says that no account was
  /// created and, when another account is still signed in, names it.
  void _presentAuthRefusal() {
    final generation = provider.authRefusalGeneration;
    if (generation == _authRefusalSeen || !_pageIsSettled) return;
    _authRefusalSeen = generation;
    final key = provider.authRefusalKey ?? 'auth_refusal.generic';
    final signedInAs = provider.authRefusalSignedInAs;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final context = AppRouter.rootNavigatorKey.currentContext;
      if (context == null) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          key: const Key('auth-refusal-dialog'),
          title: Text('auth_refusal.title'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(key.tr()),
              if (signedInAs != null && signedInAs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('auth_refusal.still_signed_in'
                    .tr(namedArgs: {'account': signedInAs})),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.ok'.tr()),
            ),
          ],
        ),
      );
    });
  }

  /// The mini-player closed because its broadcast ended; a snackbar says so
  /// (and is announced by screen readers) instead of it silently vanishing.
  void _presentMiniPlayerEnded() {
    final generation = provider.miniPlayerEndedGeneration;
    if (generation == _miniEndedSeen) return;
    _miniEndedSeen = generation;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      final context = AppRouter.rootNavigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          key: const Key('mini-player-ended-notice'),
          content: Text('live.mini_player_broadcast_ended'.tr())));
    });
  }

  void _onProviderChanged() {
    _presentMiniPlayerEnded();
    _presentAuthRefusal();
    _presentRemoteEnd();
    final lost = provider.broadcastSessionError == 'broadcast_session_lost';
    if (lost && !_broadcastLossShown) {
      _broadcastLossShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_disposed) return;
        router.go('/feed');
        final context = AppRouter.rootNavigatorKey.currentContext;
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('broadcast_session_lost'.tr())));
        }
      });
    } else if (!lost) {
      _broadcastLossShown = false;
    }
    final remote = provider.remoteBroadcasterSession;
    final current = provider.currentDeviceSession;
    if (remote == null || current == null) {
      _conflictDialogShown = false;
      return;
    }
    if (_conflictDialogShown || !_pageIsSettled) return;
    _conflictDialogShown = true;

    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context == null) {
      _conflictDialogShown = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _onProviderChanged();
      });
      return;
    }
    DeviceSessionConflictDialog.show(
      context: context,
      currentDevice: current,
      existingDevice: remote,
    ).then((choice) {
      if (_disposed) return;
      if (choice == null) {
        // Navigation removed the dialog before the user chose; show it again
        // on the new page while the conflict still exists.
        _conflictDialogShown = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) _onProviderChanged();
        });
      } else if (choice == DeviceSessionChoice.transferBroadcaster) {
        provider.transferBroadcasterToCurrentDevice();
      } else if (choice == DeviceSessionChoice.continueAsViewer) {
        provider.continueAsViewerOnCurrentDevice();
        router.go('/feed');
      }
    });
  }
}
