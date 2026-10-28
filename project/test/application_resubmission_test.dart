import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/admin/models/broadcaster_application_model.dart';
import 'package:streamer_app/features/auth/presentation/steps/apply_step_2_media.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';
import 'package:streamer_app/features/profile/presentation/settings/application_settings_section.dart';
import 'package:streamer_app/features/profile/presentation/widgets/broadcaster_application_sheet.dart';

late Map<String, dynamic> enData, arData;

class DirectJsonAssetLoader extends AssetLoader {
  const DirectJsonAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      locale.languageCode == 'ar' ? arData : enData;
}

Widget _localized(String lang, Widget Function(BuildContext) app) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      startLocale: Locale(lang),
      saveLocale: false,
      child: Builder(builder: app),
    );

Widget _home(AppProvider provider, String lang, Widget child) => _localized(
    lang,
    (context) => ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: MaterialApp(
            locale: context.locale,
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            theme: AppTheme.forLocale(context.locale),
            home: Scaffold(body: SingleChildScrollView(child: child)))));

AppProvider _signedIn({required bool streamer, ApplicationStatus? status}) {
  final provider = AppProvider(AdminDatabaseService(null));
  provider.debugSetSignedInForTests(
    email: 'applicant@example.invalid',
    isStreamer: streamer,
    ownedStreamerId: status == null ? null : 'app-1',
    ownedApplicationStatus: status ?? ApplicationStatus.approved,
  );
  return provider;
}

Iterable<String> _assetNames(WidgetTester tester) sync* {
  for (final element in find.byType(Image).evaluate()) {
    final image = (element.widget as Image).image;
    if (image is AssetImage) yield image.assetName;
  }
  for (final element in find.byType(CircleAvatar).evaluate()) {
    final image = (element.widget as CircleAvatar).backgroundImage;
    if (image is AssetImage) yield image.assetName;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    enData = jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    arData = jsonDecode(File('assets/i18n/ar.json').readAsStringSync());
    await EasyLocalization.ensureInitialized();
  });

  group('the application form never writes over an approved channel', () {
    Future<GoRouter> open(WidgetTester tester, AppProvider provider) async {
      final router = AppRouter.build(provider);
      router.go('/streamer-apply');
      await tester.pumpWidget(_localized(
          'en',
          (context) => ChangeNotifierProvider<AppProvider>.value(
              value: provider,
              child: MaterialApp.router(
                  routerConfig: router,
                  locale: context.locale,
                  localizationsDelegates: context.localizationDelegates,
                  supportedLocales: context.supportedLocales,
                  theme: AppTheme.forLocale(context.locale)))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      return router;
    }

    testWidgets('an approved streamer is sent to Settings', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider =
          _signedIn(streamer: true, status: ApplicationStatus.approved);
      final opened = await open(tester, provider);
      expect(opened.routeInformationProvider.value.uri.path, '/settings');
      expect(find.byType(StreamerApplyScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
      opened.dispose();
      provider.dispose();
    });

    testWidgets('a rejected applicant can open the form to reapply',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider =
          _signedIn(streamer: false, status: ApplicationStatus.rejected);
      final opened = await open(tester, provider);
      expect(opened.routeInformationProvider.value.uri.path, '/streamer-apply');
      expect(find.byType(StreamerApplyScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      opened.dispose();
      provider.dispose();
    });
  });

  group('Settings application card', () {
    for (final lang in ['en', 'ar']) {
      testWidgets('$lang: an approved streamer edits the channel in the editor',
          (tester) async {
        final provider =
            _signedIn(streamer: true, status: ApplicationStatus.approved);
        await tester.pumpWidget(
            _home(provider, lang, const ApplicationSettingsSection()));
        await tester.pumpAndSettle();
        final edit = find.text((lang == 'ar' ? arData : enData)['application']
            ['edit_channel_btn'] as String);
        expect(edit, findsOneWidget);
        expect(
            find.text((lang == 'ar' ? arData : enData)['application']
                ['edit_btn'] as String),
            findsNothing);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        final sheet = tester.widget<BroadcasterApplicationSheet>(
            find.byType(BroadcasterApplicationSheet));
        expect(sheet.editingProfile, isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        provider.dispose();
      });
    }

    testWidgets('a rejected applicant is offered Reapply', (tester) async {
      final provider =
          _signedIn(streamer: false, status: ApplicationStatus.rejected);
      await tester.pumpWidget(
          _home(provider, 'en', const ApplicationSettingsSection()));
      await tester.pumpAndSettle();
      expect(find.text('Reapply'), findsOneWidget);
      expect(find.text('Edit channel'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });

    testWidgets('an approved organization without a channel has no form button',
        (tester) async {
      final provider =
          _signedIn(streamer: false, status: ApplicationStatus.approved);
      await tester.pumpWidget(
          _home(provider, 'en', const ApplicationSettingsSection()));
      await tester.pumpAndSettle();
      expect(find.text('Edit Application'), findsNothing);
      expect(find.text('Edit channel'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    });
  });

  testWidgets('the form offers no stand-in photo of a real person',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = AppProvider(AdminDatabaseService(null));
    await tester.pumpWidget(_localized(
        'en',
        (context) => ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: MaterialApp(
                locale: context.locale,
                localizationsDelegates: context.localizationDelegates,
                supportedLocales: context.supportedLocales,
                theme: AppTheme.forLocale(context.locale),
                home: const StreamerApplyScreen()))));
    await tester.pumpAndSettle();
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    final media = tester.widget<ApplyStep2Media>(find.byType(ApplyStep2Media));
    expect(media.avatarPath, isNull);
    expect(media.bannerPath, isNull);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
    expect(_assetNames(tester).where((name) => name.contains('Amir_Alhatemi')),
        isEmpty);
    await tester.pumpWidget(const SizedBox());
    provider.dispose();
  });
}
