import 'dart:async';

import 'core/config/app_distribution.dart';
import 'core/config/app_identity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/services/app_skin_preference.dart';
import 'core/services/notifications/notification_models.dart';
import 'core/services/reminder_push_service.dart';
import 'core/services/retired_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/skin_fonts.dart';
import 'core/providers/app_provider.dart';
import 'core/providers/app_update_controller.dart';
import 'core/routing/app_router.dart';
import 'core/widgets/app_update_gate.dart';
import 'core/widgets/app_update_presenter.dart';
import 'core/widgets/device_session_presenter.dart';
import 'core/widgets/interactive_toast_overlay.dart';
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

  if (kIsWeb) {
    // The web downloads Firebase's scripts for this; the first frame does not
    // wait for them. Push handlers attach when it finishes.
    unawaited(ReminderPushService.initializeIfConfigured());
  } else {
    // On a phone it is local, and a tapped push that started the app is read
    // right after the first frame.
    await ReminderPushService.initializeIfConfigured();
  }
  final skin = await readAppSkin();
  // Only the Hedayah and Lantern skins' heading font, and only for them;
  // gold returns at once (skin_fonts.dart).
  await SkinFonts.ensureLoaded(skin);
  // Lantern and Arch only: day or night, and calm motion (ADR-026).
  final lantern = skin == AppSkin.lantern;
  final appearance =
      lantern ? await readLanternAppearance() : LanternAppearance.fallback;
  final calmMotion = lantern && await readLanternCalmMotion();

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
      child: StreamerApp(
          initialSkin: skin,
          initialAppearance: appearance,
          initialCalmMotion: calmMotion),
    ),
  );
}

class StreamerApp extends StatefulWidget {
  const StreamerApp(
      {super.key,
      this.initialSkin = AppSkin.gold,
      this.initialAppearance = LanternAppearance.fallback,
      this.initialCalmMotion = false});

  /// The design saved on this device (or named by a web link).
  final AppSkin initialSkin;

  /// Lantern and Arch only: day or night, and calm motion, as saved.
  final LanternAppearance initialAppearance;
  final bool initialCalmMotion;

  @override
  State<StreamerApp> createState() => _StreamerAppState();
}

class _StreamerAppState extends State<StreamerApp> with WidgetsBindingObserver {
  late final AppProvider _appProvider;
  late final GoRouter _router;
  late final DeviceSessionPresenter _deviceSessionPresenter;
  late final AppUpdateController _appUpdates;
  late final AppUpdatePresenter _appUpdatePresenter;

  /// Lessons: created on first use; follows sign-in and sign-out. Without a
  /// configured backend it shows sample data, marked as such.
  late final LessonsController _lessons = LessonsController(
      SupabaseConfig.isConfigured
          ? SupabaseLessonsRepository()
          : DemoLessonsRepository());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appProvider = AppProvider()
      ..restoreAppSkin(widget.initialSkin,
          appearance: widget.initialAppearance,
          calmMotion: widget.initialCalmMotion);
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
    _appProvider.attachReminderPush(
        onOpen: (streamerId) async {
          await _appProvider.loadVerifiedStreamersFromBackend();
          _openFromPush('/profile/$streamerId?tab=upcoming', replace: true);
        },
        onOpenRoute: (route) async => _openFromPush(route),
        onLessonNotice: () => unawaited(_lessons.refresh()),
        onLessonNoticeRead: (id) => unawaited(_lessons
            .markRead([id]).catchError((Object e) =>
                debugPrint('Lesson notice read sync failed: $e'))),
        onPushWhileOpen: _showPushWhileOpen);
    _deviceSessionPresenter =
        DeviceSessionPresenter(provider: _appProvider, router: _router)
          ..attach();
    // ADR-017: the downloaded APK (and later the Play build) asks for the
    // newest published release on start and on return; other builds only
    // read their own version for Settings.
    _appUpdates = AppUpdateController(distribution: AppDistribution.current);
    _appUpdatePresenter = AppUpdatePresenter(
        updates: _appUpdates, provider: _appProvider, router: _router)
      ..attach();
    unawaited(_appUpdates.loadInstalled().then((_) => _appUpdates.check()));
  }

  /// Opens the page a tapped push points at. A tap can be what started the
  /// app, and the splash screen replaces whatever is open when it finishes, so
  /// until then the page waits for the splash screen to open it.
  void _openFromPush(String route, {bool replace = false}) {
    if (!mounted) return;
    final current = _router.routerDelegate.currentConfiguration.uri.path;
    if (current.isEmpty || current == '/' || current == '/splash') {
      unawaited(_appProvider.rememberSignInReturn(route));
    } else if (replace) {
      _router.go(route);
    } else {
      unawaited(_router.push(route));
    }
  }

  /// Android shows nothing for a push while the app is in front.
  void _showPushWhileOpen(PushWhileOpen push) {
    final overlay = _router.routerDelegate.navigatorKey.currentState?.overlay;
    final route = push.route;
    if (!mounted || overlay == null) return;
    final ar = context.locale.languageCode == 'ar';
    InteractiveToastOverlay.show(context,
        overlay: overlay,
        title: ar ? push.titleAr : push.titleEn,
        message: ar ? push.bodyAr : push.bodyEn,
        onTap: route == null ? null : () => _openFromPush(route));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appProvider.setConnectivityForeground(state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive);
    // Android can freeze a backgrounded app and skip Realtime events and
    // heartbeats; re-check ownership, approval and ban state on return.
    if (state == AppLifecycleState.resumed) {
      unawaited(_appProvider.onAppResumed());
      unawaited(_appUpdates.check());
      unawaited(_lessons.refreshIfOlderThan(const Duration(minutes: 3)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deviceSessionPresenter.dispose();
    _appUpdatePresenter.dispose();
    _appUpdates.dispose();
    _appProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: _appProvider),
        ChangeNotifierProvider<AppUpdateController>.value(value: _appUpdates),
        ChangeNotifierProxyProvider<AppProvider, LessonsController>(
          create: (_) => _lessons,
          update: (_, app, lessons) => lessons!
            ..onAccountChanged(app.isLoggedInStreamer ? app.currentUserId : null)
            ..setLiveChannels(app.liveChannelIds),
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
            builder: (context, child) {
              final app = AppUpdateGate(child: child ?? const SizedBox.shrink());
              return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                  ? app
                  : MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3, child: app);
            },
          );
        },
      ),
    );
  }
}
