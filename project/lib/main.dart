import 'dart:async';

import 'core/config/app_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/services/app_skin_preference.dart';
import 'core/services/reminder_push_service.dart';
import 'core/services/retired_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_provider.dart';
import 'core/routing/app_router.dart';
import 'core/widgets/device_session_presenter.dart';
import 'features/lessons/data/demo_lessons_repository.dart';
import 'features/lessons/data/supabase_lessons_repository.dart';
import 'features/lessons/state/lessons_controller.dart';

Future<void> main() async {
  // ~180 debugPrint calls (some on per-rebuild or per-failure paths) stay
  // active in release builds and format strings, print to the console and, on
  // web, cost a console call each. They are diagnostics for development only
  // (audit LOG-01); errors still reach FlutterError/zone handlers.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
    // Flutter reports framework errors through debugPrint, so silencing it
    // above would also hide them. Keep one line per error on the console.
    FlutterError.onError = (details) {
      // ignore: avoid_print
      print('FlutterError: ${details.exceptionAsString()}');
    };
  }
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  unawaited(forgetRetiredPreferences());

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

  await ReminderPushService.initializeIfConfigured();
  final skin = await readAppSkin();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/i18n',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      // Use each language's CLDR plural rules. The package default maps every
      // count above 2 to "other", which never selects Arabic's few/many forms
      // (audit 2026-10-21, section 5.3).
      ignorePluralRules: false,
      child: StreamerApp(initialSkin: skin),
    ),
  );
}

class StreamerApp extends StatefulWidget {
  const StreamerApp({super.key, this.initialSkin = AppSkin.gold});

  /// The design saved on this device (or named by a web link).
  final AppSkin initialSkin;

  @override
  State<StreamerApp> createState() => _StreamerAppState();
}

class _StreamerAppState extends State<StreamerApp> with WidgetsBindingObserver {
  late final AppProvider _appProvider;
  late final GoRouter _router;
  late final DeviceSessionPresenter _deviceSessionPresenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appProvider = AppProvider()..restoreAppSkin(widget.initialSkin);
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
    _appProvider.attachReminderPush(onOpen: (streamerId) async {
      await _appProvider.loadVerifiedStreamersFromBackend();
      if (mounted) _router.go('/profile/$streamerId?tab=upcoming');
    }, onOpenRoute: (route) async {
      if (mounted) _router.push(route);
    });
    _deviceSessionPresenter =
        DeviceSessionPresenter(provider: _appProvider, router: _router)
          ..attach();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appProvider.setConnectivityForeground(state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive);
    // Android can freeze a backgrounded app and skip Realtime events and
    // heartbeats; re-check ownership, approval and ban state on return.
    if (state == AppLifecycleState.resumed) {
      unawaited(_appProvider.onAppResumed());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deviceSessionPresenter.dispose();
    _appProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: _appProvider),
        // Lessons: created on first use; follows sign-in and sign-out. Without
        // a configured backend it shows sample data, marked as such.
        ChangeNotifierProxyProvider<AppProvider, LessonsController>(
          create: (_) => LessonsController(SupabaseConfig.isConfigured
              ? SupabaseLessonsRepository()
              : DemoLessonsRepository()),
          update: (_, app, lessons) => lessons!
            ..onAccountChanged(app.isLoggedInStreamer ? app.currentUserId : null),
        ),
      ],
      child: Builder(
        builder: (context) {
          final skin = context.select<AppProvider, AppSkin>((p) => p.appSkin);
          return MaterialApp.router(
            title: AppIdentity.name(context.locale.languageCode),
            debugShowCheckedModeBanner: false,
            theme: AppTheme.forLocale(context.locale, skin: skin),
            themeMode: ThemeMode.light,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            routerConfig: _router,
            builder: (context, child) =>
                !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                    ? child ?? const SizedBox.shrink()
                    : MediaQuery.withClampedTextScaling(
                        maxScaleFactor: 1.3,
                        child: child ?? const SizedBox.shrink()),
          );
        },
      ),
    );
  }
}
