import 'core/config/app_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_provider.dart';
import 'core/routing/app_router.dart';
import 'core/widgets/device_session_conflict_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  } else if (kDebugMode) {
    debugPrint(
      'Supabase not initialized: SUPABASE_URL / SUPABASE_ANON_KEY were not '
      'provided via --dart-define.',
    );
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/i18n',
      fallbackLocale: const Locale('en'),
      startLocale: const Locale('en'),
      child: const StreamerApp(),
    ),
  );
}

class StreamerApp extends StatefulWidget {
  const StreamerApp({super.key});

  @override
  State<StreamerApp> createState() => _StreamerAppState();
}

class _StreamerAppState extends State<StreamerApp> {
  late final AppProvider _appProvider;
  late final GoRouter _router;
  bool _deviceConflictDialogShown = false;

  @override
  void initState() {
    super.initState();
    _appProvider = AppProvider();
    // Start real-time live viewer polling now that the provider exists.
    // This is intentionally NOT done inside AppProvider's constructor so that
    // widget tests (which use their own AppProvider instances) stay free of
    // pending Timer assertions.
    _appProvider.ensureLivePollingActive();
    // UI-08: starts the Spatial Map's offline/online monitoring (same
    // constructor-vs-explicit-start rule as ensureLivePollingActive above).
    _appProvider.ensureConnectivityMonitoringActive();
    // Built once and bound to _appProvider so its redirect (see
    // app_router.dart) can react to auth state changes via refreshListenable
    // -- GoRouter must not be rebuilt on every frame.
    _router = AppRouter.build(_appProvider);
    _appProvider.addListener(_maybeShowDeviceConflictDialog);
  }

  /// Shows DeviceSessionConflictDialog once per detected conflict --
  /// AppProvider.initDeviceSession() populates remoteBroadcasterSession when
  /// another device already holds broadcaster rights on this account
  /// (issue_log.md multi-device collision). Global (root navigator) so it
  /// fires regardless of which screen the user lands on after sign-in.
  void _maybeShowDeviceConflictDialog() {
    final remote = _appProvider.remoteBroadcasterSession;
    final current = _appProvider.currentDeviceSession;
    if (remote == null || current == null) {
      _deviceConflictDialogShown = false;
      return;
    }
    if (_deviceConflictDialogShown) return;
    _deviceConflictDialogShown = true;

    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context == null) return;
    DeviceSessionConflictDialog.show(
      context: context,
      currentDevice: current,
      existingDevice: remote,
    ).then((choice) {
      if (choice == DeviceSessionChoice.transferBroadcaster) {
        _appProvider.transferBroadcasterToCurrentDevice();
      } else if (choice == DeviceSessionChoice.continueAsViewer) {
        _appProvider.continueAsViewerOnCurrentDevice();
      }
    });
  }

  @override
  void dispose() {
    _appProvider.removeListener(_maybeShowDeviceConflictDialog);
    _appProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appProvider,
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: AppIdentity.name(context.locale.languageCode),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.forLocale(context.locale),
            themeMode: ThemeMode.light,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            routerConfig: _router,
            builder: (context, child) => MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
