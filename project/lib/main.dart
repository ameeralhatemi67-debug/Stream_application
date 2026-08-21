import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/app_provider.dart';
import 'core/routing/app_router.dart';

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

class StreamerApp extends StatelessWidget {
  const StreamerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final provider = AppProvider();
        // Start real-time live viewer polling now that the provider tree is ready.
        // This is intentionally NOT done inside AppProvider's constructor so that
        // widget tests (which use their own AppProvider instances) stay free of
        // pending Timer assertions.
        provider.ensureLivePollingActive();
        return provider;
      },
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: 'Educational Streamer',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getDarkThemeForLocale(context.locale),
            darkTheme: AppTheme.getDarkThemeForLocale(context.locale),
            themeMode: ThemeMode.dark,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
