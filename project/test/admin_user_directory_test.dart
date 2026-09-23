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
import 'package:streamer_app/features/admin/presentation/widgets/admin_user_directory_view.dart';

late Map<String,dynamic> enData, arData;
class DirectJsonAssetLoader extends AssetLoader {
  const DirectJsonAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
    locale.languageCode == 'ar' ? arData : enData;
}

class DirectoryService extends AdminDatabaseService {
  bool fail = false;
  final searches = <String>[];
  final actions = <String>[];
  @override
  Future<List<Map<String, dynamic>>> searchAdminUsers(String query, int offset) async {
    searches.add('$query:$offset');
    if (fail) throw StateError('private server error');
    if (query == 'missing') return [];
    return List.generate(offset == 0 ? 26 : 1, (i) => {
      'id': 'account-${offset+i}', 'email': 'test${offset+i}@example.invalid',
      'display_name_en': 'Test account ${offset+i}', 'display_name_ar': 'حساب تجريبي ${offset+i}',
    });
  }
  @override
  Future<Map<String, dynamic>> loadAdminUserDetail(String id) async => {
    'id':id,'email':'test@example.invalid','display_name_en':'Test account',
    'display_name_ar':'حساب تجريبي','is_streamer':true,'is_verified':true,
    'is_banned':false,'roles':['org_owner'],'report_count':2,
    'organizations':[{'name_en':'Test organization','name_ar':'مؤسسة تجريبية'}],
    'devices':[{'device_name':'Test phone','platform':'android',
      'last_active_at':'2026-09-22T00:00:00Z','is_primary_broadcaster':true}],
  };
  @override
  Future<void> updateAdminAccount(String id, String action, String reason) async {
    actions.add('$id:$action:$reason');
    if (fail) throw StateError('private failure');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    enData=jsonDecode(File('assets/i18n/en.json').readAsStringSync());
    arData=jsonDecode(File('assets/i18n/ar.json').readAsStringSync());
    await EasyLocalization.ensureInitialized();
  });
  Future<AppProvider> pump(WidgetTester tester, DirectoryService service,
      {String locale='en', bool admin=true}) async {
    final provider=AppProvider(service);
    provider.debugSetSignedInForTests(email:'admin@example.invalid',isAdmin:admin);
    await tester.pumpWidget(EasyLocalization(supportedLocales:const [Locale('en'),Locale('ar')],
      path:'assets/i18n',assetLoader:const DirectJsonAssetLoader(),
      startLocale:Locale(locale),fallbackLocale:const Locale('en'),saveLocale:false,
      child:ChangeNotifierProvider.value(value:provider,child:Builder(builder:(context)=>MaterialApp(
        locale:context.locale,localizationsDelegates:context.localizationDelegates,
        supportedLocales:context.supportedLocales,theme:AppTheme.forLocale(context.locale),
        home:const Scaffold(body:AdminUserDirectoryView()))))));
    await tester.pumpAndSettle();
    addTearDown(provider.dispose);
    return provider;
  }
  test('unconfigured backend refuses directory reads and writes',() async {
    final service=AdminDatabaseService();
    await expectLater(service.searchAdminUsers('',0),throwsStateError);
    await expectLater(service.loadAdminUserDetail('id'),throwsStateError);
    await expectLater(service.updateAdminAccount('id','ban','reason'),throwsStateError);
  });
  testWidgets('directory denies non-admin before service call',(tester) async {
    final service=DirectoryService(); await pump(tester,service,admin:false);
    expect(find.text('Administrator access required.'),findsOneWidget);
    expect(service.searches,isEmpty);
  });
  testWidgets('server pagination and literal search reset offset',(tester) async {
    final service=DirectoryService(); await pump(tester,service);
    await tester.tap(find.text('Next')); await tester.pumpAndSettle();
    expect(service.searches.last,':25');
    await tester.enterText(find.byType(TextField),'missing');
    await tester.testTextInput.receiveAction(TextInputAction.done); await tester.pumpAndSettle();
    expect(service.searches.last,'missing:0');
    expect(find.text('No matching accounts.'),findsOneWidget);
  });
  testWidgets('failure offers retry without raw exception or false empty state',(tester) async {
    final service=DirectoryService()..fail=true; await pump(tester,service);
    expect(find.text('Retry'),findsOneWidget);
    expect(find.textContaining('private server error'),findsNothing);
    expect(find.text('No matching accounts.'),findsNothing);
    service.fail=false; await tester.tap(find.text('Retry')); await tester.pumpAndSettle();
    expect(find.text('Test account 0'),findsOneWidget);
  });
  for(final locale in ['en','ar']) {
    testWidgets('details and RTL fit a narrow screen in $locale',(tester) async {
      tester.view.physicalSize=const Size(360,800);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      final service=DirectoryService(); await pump(tester,service,locale:locale);
      await tester.tap(find.text(locale=='en'?'Test account 0':'حساب تجريبي 0'));
      await tester.pumpAndSettle();
      expect(find.text('Test phone (android)'),findsOneWidget);
      expect(tester.takeException(),isNull);
      final ctx=tester.element(find.text('Test phone (android)'));
      expect(Directionality.of(ctx),locale=='ar'?TextDirection.rtl:TextDirection.ltr);
    });
  }
  testWidgets('ban needs a reason and failure stays visible',(tester) async {
    final service=DirectoryService(); await pump(tester,service);
    await tester.tap(find.text('Test account 0'));await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ban account'));await tester.tap(find.text('Ban account'));
    await tester.pumpAndSettle(); await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();
    expect(service.actions,isEmpty);
    await tester.enterText(find.byType(TextField).last,'Test reason');service.fail=true;
    await tester.tap(find.text('Confirm'));await tester.pumpAndSettle();await tester.pump(const Duration(seconds:1));await tester.pumpAndSettle();
    expect(service.actions,['account-0:ban:Test reason']);
    expect(find.text('Action failed. Check your permissions and connection.'),findsOneWidget);
  });
  testWidgets('deletion confirms warning and closes details after success',(tester) async {
    final service=DirectoryService(); await pump(tester,service);
    await tester.tap(find.text('Test account 0')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Delete account'));
    await tester.tap(find.text('Delete account')); await tester.pumpAndSettle();
    expect(find.textContaining('Permanently deletes'),findsOneWidget);
    await tester.enterText(find.byType(TextField).last,'Approved erasure');
    await tester.tap(find.text('Confirm')); await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds:1)); await tester.pumpAndSettle();
    expect(service.actions,['account-0:delete_account:Approved erasure']);
    expect(find.text('Test phone (android)'),findsNothing);
    expect(service.searches.length,greaterThan(1));
  });

}
