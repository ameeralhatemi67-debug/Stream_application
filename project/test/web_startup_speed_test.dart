// Web start-up speed (2026-11-07 diagnosis, brief/LEDGER.md). The live site
// took 30 s to its first frame on slow 4G and its streamer list waited behind
// 29 refused admin requests. These tests keep the fixes from regressing.
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/connectivity_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/theme/skin_fonts.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/admin/models/terms_and_conditions_model.dart';
import 'package:streamer_app/features/admin/models/viewer_analytics_model.dart';
import 'package:streamer_app/features/organization/models/org_affiliation_request_model.dart';
import 'package:streamer_app/features/organization/models/org_audit_log_entry.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'package:streamer_app/features/splash/presentation/app_splash_screen.dart';

import 'support/empty_broadcasts.dart';
import 'support/localized_app.dart';

/// Pretends to be the Supabase-backed service and counts which tables a
/// signed-out start asks for.
class _CountingBackend extends AdminDatabaseService {
  final reads = <String>[];

  @override
  bool get usesSupabase => true;
  @override
  Future<int> sweepStaleLiveFlags() async => 0;
  @override
  Future<List<StreamerModel>> loadVerifiedStreamersFromBackend(
      {bool requireSuccess = false}) async {
    reads.add('streamers');
    return [];
  }

  @override
  Future<TermsAndConditionsModel> loadTerms() async {
    reads.add('terms');
    return TermsAndConditionsModel.createDefault();
  }

  @override
  Future<List<BroadcasterApplicationModel>> loadApplications() async {
    reads.add('applications');
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> loadApplicationReviewEvents() async {
    reads.add('review events');
    return [];
  }

  @override
  Future<ViewerAnalyticsModel> loadAnalytics() async {
    reads.add('analytics');
    return ViewerAnalyticsModel.createDefault();
  }

  @override
  Future<List<OrgAuditLogEntry>> loadAuditLogs([String? organizationId]) async {
    reads.add('audit logs');
    return [];
  }

  @override
  Future<List<OrgAffiliationRequestModel>> loadAffiliationRequests(
      {String? orgId, String? streamerId}) async {
    reads.add('affiliation requests');
    return [];
  }
}

const _adminTables = [
  'applications',
  'review events',
  'analytics',
  'audit logs',
  'affiliation requests',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('signed-out start', () {
    test('reads the terms and the catalog, never the admin tables', () async {
      final backend = _CountingBackend();
      final provider = AppProvider.withServices(
          adminDbService: backend,
          organizationBroadcastService: EmptyBroadcasts());
      await provider.refreshAdminData();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(backend.reads, containsAll(['terms', 'streamers']));
      for (final table in _adminTables) {
        expect(backend.reads, isNot(contains(table)), reason: table);
      }
      provider.dispose();
    });

    test('without Supabase, the device store still works after create',
        () async {
      // With Supabase, create() now reads nothing. Without it, it falls back
      // to the device store, which still warms its caches.
      final service = await AdminDatabaseService.create();
      expect(service.usesSupabase, isFalse);
      expect(await service.loadApplications(), isA<List>());
    });
  });

  group('slow networks', () {
    test('the backend check waits ten seconds before calling it degraded',
        () {
      final service = ConnectivityService(
          endpoint: Uri.parse('http://127.0.0.1:1/rest/v1/'),
          checkConnectivity: () async => const [],
          connectivityChanges: const Stream.empty());
      expect(service.probeTimeout, const Duration(seconds: 10));
    });
  });

  group('start-up fonts', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final fonts = pubspec.substring(pubspec.indexOf('\n  fonts:'));

    test('only the gold design\'s fonts download before the first frame', () {
      expect(fonts, contains('family: IBM Plex Sans Arabic'));
      expect(fonts, contains('family: Reem Kufi'));
      // Plex Sans Arabic already has every English letter.
      expect(fonts, isNot(contains('family: IBM Plex Sans\n')));
      // The Hedayah skin's heading font is an asset, loaded with the skin.
      expect(fonts, isNot(contains('Readex Pro')));
      expect(pubspec, contains('- ${SkinFonts.readexProAsset}'));
    });

    test('the theme no longer names a font the app does not ship', () {
      final style = AppTheme.forLocale(const Locale('en')).textTheme.bodyLarge!;
      expect(style.fontFamilyFallback, ['IBM Plex Sans Arabic']);
    });

    test('the Hedayah skin loads Readex Pro once; gold loads nothing',
        () async {
      SkinFonts.debugReset();
      await SkinFonts.ensureLoaded(AppSkin.gold);
      final first = SkinFonts.ensureLoaded(AppSkin.hedayah);
      expect(identical(first, SkinFonts.ensureLoaded(AppSkin.hedayah)), isTrue);
      await first;
    });
  });

  group('web entry page', () {
    final html = File('web/index.html').readAsStringSync();

    test('opens the CDN connections and asks for the translations early', () {
      expect(html, contains('<link rel="preconnect" href="https://www.gstatic.com" crossorigin>'));
      expect(html, contains('<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'));
      expect(html, contains("'assets/assets/i18n/' + lang + '.json'"));
      // The hints must follow <base>, so relative paths resolve like the app's.
      expect(html.indexOf('<base href'), lessThan(html.indexOf('rel="preconnect"')));
    });
  });

  group('splash', () {
    testWidgets('opens the next page without the old 1.35 s wait',
        (tester) async {
      final provider = AppProvider();
      final router = GoRouter(initialLocation: '/splash', routes: [
        GoRoute(
            path: '/splash',
            builder: (context, state) => const AppSplashScreen()),
        GoRoute(
            path: '/welcome',
            builder: (context, state) => const Text('welcome-page')),
        GoRoute(
            path: '/feed', builder: (context, state) => const Text('feed-page')),
      ]);
      await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          startLocale: const Locale('en'),
          saveLocale: false,
          path: 'assets/i18n',
          assetLoader: const DirectJsonAssetLoader(),
          child: ChangeNotifierProvider<AppProvider>.value(
              value: provider,
              child: Builder(
                  builder: (context) => MaterialApp.router(
                      routerConfig: router,
                      locale: context.locale,
                      supportedLocales: context.supportedLocales,
                      localizationsDelegates: context.localizationDelegates,
                      builder: (context, child) => TickerMode(
                          enabled: false, child: child!))))));
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && !provider.localStateRestored; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      });
      expect(provider.localStateRestored, isTrue);
      // Translations load first; time from the moment the splash is shown.
      for (var i = 0; i < 100 && find.byType(AppSplashScreen).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5)));
        await tester.pump();
      }
      expect(find.byType(AppSplashScreen), findsOneWidget);
      var waited = Duration.zero;
      const step = Duration(milliseconds: 50);
      while (router.routeInformationProvider.value.uri.path == '/splash' &&
          waited < const Duration(seconds: 3)) {
        await tester.pump(step);
        waited += step;
      }
      expect(router.routeInformationProvider.value.uri.path, '/welcome');
      expect(waited, lessThan(const Duration(milliseconds: 600)),
          reason: 'the splash used to hold every start for at least 1.35 s');
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      provider.dispose();
    });
  });
}
