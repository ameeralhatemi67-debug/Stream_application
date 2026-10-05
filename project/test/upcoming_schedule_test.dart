import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/upcoming_schedule_service.dart';
import 'package:streamer_app/features/profile/models/upcoming_schedule.dart';
import 'package:streamer_app/features/profile/presentation/widgets/upcoming_schedule_tab.dart';

import 'fixtures/streamer_fixtures.dart';

class _JsonLoader extends AssetLoader {
  const _JsonLoader();
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      jsonDecode(File('$path/${locale.languageCode}.json').readAsStringSync());
}

UpcomingSchedule schedule(
  String id, {
  String kind = 'weekly',
  String time = '03:00',
  List<int> days = const [1, 3],
  DateTime? once,
  String description = '',
}) =>
    UpcomingSchedule(
      id: id,
      streamerId: mockStreamers.first.streamerId,
      kind: kind,
      localTime: time,
      weekdays: kind == 'once' ? const [] : days,
      oneTimeStartUtc: once,
      titleEn: 'Lecture $id',
      titleAr: '',
      descriptionEn: description,
      descriptionAr: '',
      tags: const [],
      colorKey: 'green',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('Saudi recurrence crosses week and month and 3 a.m. alert is prior day',
      () {
    final monday = schedule('monday', days: const [1]);
    final start = monday.nextStartUtc(DateTime.utc(2026, 10, 31, 23, 0));
    expect(start, DateTime.utc(2026, 11, 1, 24, 0));
    expect(start!.subtract(const Duration(minutes: 30)),
        DateTime.utc(2026, 11, 1, 23, 30));
    final next = monday.nextStartUtc(start);
    expect(next, start.add(const Duration(days: 7)));
  });

  test('one-time event expires at start and missing translation falls back',
      () {
    final start = DateTime.utc(2026, 10, 5, 11, 20);
    final event = schedule('special', kind: 'once', once: start);
    expect(
        event.nextStartUtc(start.subtract(const Duration(seconds: 1))), start);
    expect(event.nextStartUtc(start), isNull);
    expect(event.title('ar'), 'Lecture special');
  });

  test('schedule service fails closed without a backend', () async {
    await expectLater(
        UpcomingScheduleService().load(mockStreamers.first.streamerId),
        throwsStateError);
  });

  for (final language in ['en', 'ar']) {
    for (final width in [320.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'Upcoming cards, actions and description $language $width $scale',
            (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final streamer = mockStreamers.first
              .copyWith(avatarUrl: '', bannerUrl: '', isOrganization: false);
          final provider = AppProvider(AdminDatabaseService(null))
            ..addStreamerForTests(streamer)
            ..debugSetUpcomingSchedules(streamer.streamerId, [
              for (var i = 0; i < 4; i++)
                schedule('$i', description: i == 0 ? 'Lecture details' : ''),
            ]);
          await tester.pumpWidget(EasyLocalization(
            supportedLocales: const [Locale('en'), Locale('ar')],
            startLocale: Locale(language),
            saveLocale: false,
            path: 'assets/i18n',
            assetLoader: const _JsonLoader(),
            child: ChangeNotifierProvider<AppProvider>.value(
              value: provider,
              child: Builder(
                  builder: (context) => MaterialApp(
                        locale: context.locale,
                        localizationsDelegates: context.localizationDelegates,
                        supportedLocales: context.supportedLocales,
                        builder: (context, child) => MediaQuery(
                          data: MediaQuery.of(context)
                              .copyWith(textScaler: TextScaler.linear(scale)),
                          child: child!,
                        ),
                        home: Scaffold(
                            body: UpcomingScheduleTab(streamer: streamer)),
                      )),
            ),
          ));
          await tester.pumpAndSettle();
          final first = tester.getTopLeft(find.text('Lecture 0'));
          final last = tester.getTopLeft(find.text('Lecture 3'));
          if (width == 320) {
            expect(last.dy, greaterThan(first.dy));
          } else {
            expect(last.dy, closeTo(first.dy, 1));
          }
          // The card previews the description (two lines) behind an arrow.
          expect(find.text('Lecture details'), findsOneWidget);
          await tester.tap(find
              .byTooltip(language == 'ar' ? 'عرض الوصف' : 'Show description')
              .first);
          await tester.pumpAndSettle();
          expect(find.text('Lecture details'), findsOneWidget);
          expect(
              find.byTooltip(
                  language == 'ar' ? 'إجراءات الموعد' : 'Schedule actions'),
              findsNWidgets(4));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          provider.dispose();
        });
      }
    }
  }
}
