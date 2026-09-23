import 'dart:convert';
import 'dart:io';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/routing/app_router.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';
import 'package:streamer_app/features/admin/models/viewer_analytics_model.dart';

late Map<String,dynamic> enData, arData;
class DirectJsonAssetLoader extends AssetLoader {
  const DirectJsonAssetLoader();
  @override
  Future<Map<String,dynamic>> load(String path, Locale locale) async => locale.languageCode == 'ar' ? arData : enData;
}
class LoadingRoleProvider extends AppProvider {
  LoadingRoleProvider() : super(AdminDatabaseService(null));
  bool waiting = true;
  @override
  bool get adminRoleLoading => waiting;
}
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    enData=jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    arData=jsonDecode(File('assets/i18n/ar.json').readAsStringSync());
    await EasyLocalization.ensureInitialized();
  });
  for(final width in [390.0,1280.0]) {
    for(final language in ['en','ar']) {
      testWidgets('Admin navigation $width $language persists locale and selection', (tester) async {
        tester.view.physicalSize=Size(width,850); tester.view.devicePixelRatio=1;
        addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final p=AppProvider(AdminDatabaseService(null));
        p.debugSetSignedInForTests(email:'master@example.invalid',isMasterAdmin:true);
        await tester.pumpWidget(EasyLocalization(
          supportedLocales:const [Locale('en'),Locale('ar')],path:'assets/i18n',
          assetLoader:const DirectJsonAssetLoader(),startLocale:Locale(language),
          child:ChangeNotifierProvider.value(value:p,child:Builder(builder:(context)=>MaterialApp(
            locale:context.locale,localizationsDelegates:context.localizationDelegates,
            supportedLocales:context.supportedLocales,theme:AppTheme.forLocale(context.locale),
            home:const AdminHubScreen())))));
        await tester.pumpAndSettle();
        expect(find.text('1605'),findsNothing);expect(find.text('365'),findsNothing);
        expect(find.byType(TabBar),findsNothing);
        if(width<900) {
          tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
          await tester.pumpAndSettle();
        }
        final viewers=find.byKey(const ValueKey('admin.tab_viewers'));
        await tester.ensureVisible(viewers); await tester.tap(viewers); await tester.pumpAndSettle();
        expect(tester.widget<TabBarView>(find.byType(TabBarView).first).controller!.index,4);
        expect(find.textContaining('45%'),findsNothing);
        await tester.tap(find.text(language=='en'?'عربي':'EN')); await tester.pumpAndSettle();
        expect((await SharedPreferences.getInstance()).getString('locale'),language=='en'?'ar':'en');
        expect(tester.widget<TabBarView>(find.byType(TabBarView).first).controller!.index,4);
        if(width<900) {
          tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer(); await tester.pumpAndSettle();
        }
        final roles=find.byKey(const ValueKey('admin.tab_roles'));
        await tester.scrollUntilVisible(roles, 200, scrollable: find.descendant(of: find.byKey(const ValueKey('admin-navigation')), matching: find.byType(Scrollable)).first);
        await tester.pumpAndSettle();expect(roles,findsOneWidget);
        await tester.tap(roles);await tester.pumpAndSettle();
        p.debugSetSignedInForTests(email:'admin@example.invalid',isAdmin:true);
        await tester.pumpAndSettle();
        expect(tester.widget<TabBarView>(find.byType(TabBarView).first).controller!.index,0);
        expect(tester.takeException(),isNull);
        await tester.pumpWidget(const SizedBox());p.dispose();
      });
    }
  }
  testWidgets('Direct admin link waits for the role and then opens the hub', (tester) async {
    final p=LoadingRoleProvider();
    p.debugSetSignedInForTests(email:'master@example.invalid');
    final router=AppRouter.build(p);
    router.go('/admin');
    await tester.pumpWidget(EasyLocalization(
      supportedLocales:const [Locale('en'),Locale('ar')],path:'assets/i18n',
      assetLoader:const DirectJsonAssetLoader(),startLocale:const Locale('en'),saveLocale:false,
      child:ChangeNotifierProvider<AppProvider>.value(value:p,child:Builder(builder:(context)=>MaterialApp.router(
        routerConfig:router,locale:context.locale,localizationsDelegates:context.localizationDelegates,
        supportedLocales:context.supportedLocales,theme:AppTheme.forLocale(context.locale))))));
    await tester.pump();await tester.pump(const Duration(milliseconds:200));
    expect(router.routeInformationProvider.value.uri.path,'/admin');
    expect(find.byType(AdminHubScreen),findsNothing);
    p.waiting=false;
    p.debugSetSignedInForTests(email:'master@example.invalid',isMasterAdmin:true);
    await tester.pumpAndSettle();
    expect(find.byType(AdminHubScreen),findsOneWidget);
    await tester.pumpWidget(const SizedBox());router.dispose();p.dispose();
  });
  test('Missing analytics never fabricate sample values',(){
    final empty=ViewerAnalyticsModel.fromJson(const {});
    expect(empty.totalGuestSessions,0);expect(empty.activeViewersLive,0);
    expect(ViewerAnalyticsModel.createDefault().totalBroadcastHours,0);
  });
}
