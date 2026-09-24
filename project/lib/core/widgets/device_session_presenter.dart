import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/app_provider.dart';
import '../routing/app_router.dart';
import 'device_session_conflict_dialog.dart';

/// Presents broadcaster-device ownership changes on the root navigator:
/// DeviceSessionConflictDialog when another device holds the primary
/// broadcaster role on this account, and the lost-session notice when this
/// device is displaced. Owned by the app root (main.dart) and attached as an
/// [AppProvider] listener.
class DeviceSessionPresenter {
  DeviceSessionPresenter({required this.provider, required this.router});

  final AppProvider provider;
  final GoRouter router;
  bool _conflictDialogShown = false;
  bool _broadcastLossShown = false;
  bool _disposed = false;

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

  void _onProviderChanged() {
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
