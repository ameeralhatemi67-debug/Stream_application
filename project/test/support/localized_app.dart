import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/theme/app_theme.dart';

class DirectJsonAssetLoader extends AssetLoader {
  const DirectJsonAssetLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync());
}

Future<void> initializeTestLocalization() async {
  SharedPreferences.setMockInitialValues({});
  await EasyLocalization.ensureInitialized();
}

Widget localizedApp({required Widget home}) => EasyLocalization(
  supportedLocales: const [Locale('en'), Locale('ar')],
  startLocale: const Locale('en'), saveLocale: false, path: 'assets/i18n',
  assetLoader: const DirectJsonAssetLoader(),
  child: Builder(builder: (context) => MaterialApp(
    theme: AppTheme.forLocale(context.locale), locale: context.locale,
    supportedLocales: context.supportedLocales,
    localizationsDelegates: context.localizationDelegates, home: home,
  )),
);
