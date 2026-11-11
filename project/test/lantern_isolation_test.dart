import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/ds/ca_navigation.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/web/presentation/hidayah_web_header.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';
import 'support/stub_video_player.dart';

/// The rule of ADR-026: the two older designs (gold & black, Hedayah) never
/// show a widget of Lantern and Arch, and a Lantern frame never shows theirs.
///
/// Two checks hold it. Every public widget class in a `lantern/` folder
/// carries the [LanternSkinWidget] mark; and no widget with that mark is in
/// the tree of any main screen of the older designs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('every public widget in a lantern folder carries the mark', () {
    final widgetClass = RegExp(
        r'^class\s+([A-Z]\w*)(?:<[^>]*>)?\s+extends\s+(StatelessWidget|StatefulWidget)\b([^{]*)\{',
        multiLine: true);
    final unmarked = <String>[];
    var seen = 0;
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) =>
            f.path.endsWith('.dart') &&
            f.path.replaceAll('\\', '/').contains('/lantern/'))) {
      final source = file.readAsStringSync();
      for (final match in widgetClass.allMatches(source)) {
        seen++;
        if (!match.group(3)!.contains('LanternSkinWidget')) {
          unmarked.add('${file.path}: ${match.group(1)}');
        }
      }
    }
    expect(seen, greaterThan(20), reason: 'the scan found the kit');
    expect(unmarked, isEmpty,
        reason: 'add "implements LanternSkinWidget" to these classes');
  });

  test('files outside lantern folders use Lantern widgets only behind a skin check',
      () {
    // A file of the older designs may import the kit only if it also asks
    // which skin is on; the tree walk below proves the check works.
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final path = file.path.replaceAll('\\', '/');
      if (path.contains('/lantern/')) continue;
      final source = file.readAsStringSync();
      final importsKit = RegExp(r"import '[^']*/lantern/[^']*\.dart'")
              .hasMatch(source) ||
          RegExp(r"import '[^']*lantern_\w+\.dart'").hasMatch(source);
      if (!importsKit) continue;
      final asks = source.contains('isLanternSkin') ||
          source.contains('AppSkin.lantern') ||
          // Painters and shape helpers are not widgets.
          !RegExp(r'\bL[A-Z]\w+\(|\bLantern[A-Z]\w+\(').hasMatch(source);
      if (!asks) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });

  const phone = Size(390, 844), laptop = Size(1440, 900);

  for (final skin in [AppSkin.gold, AppSkin.hedayah]) {
    for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
      testWidgets('${skin.id} on a $label shows no Lantern widget',
          (tester) async {
        StubVideoPlayer.install(
            state: StreamState.live, addTearDown: addTearDown);
        final provider = lanternProvider(skin: skin)
          ..debugSetSignedInForTests(
              email: 'admin@example.invalid',
              name: 'Admin',
              isMasterAdmin: true,
              isLessonsAdmin: true,
              isStreamer: false);
        final app = await LanternApp.start(tester,
            skin: skin,
            provider: provider,
            size: size,
            lang: 'ar',
            persona: LessonsDemoPersona.admin);
        final lesson = app.lessons.upcoming.isEmpty
            ? null
            : app.lessons.upcoming.first.id;
        final routes = [
          '/feed',
          '/map',
          '/lessons',
          '/lessons/calendar',
          if (lesson != null) '/lessons/lesson/$lesson',
          '/lessons/me',
          '/live/lanternLive',
          '/profile/${provider.streamers.first.streamerId}',
          '/settings',
          '/organizations',
          '/admin',
          '/admin/lessons',
          '/streamer-apply',
          '/nowhere-at-all',
        ];
        for (final route in routes) {
          await app.go(route);
          tester.takeException();
          final found = tester.allWidgets
              .whereType<LanternSkinWidget>()
              .map((w) => w.runtimeType.toString())
              .toSet();
          expect(found, isEmpty,
              reason: '${skin.id} at $route built Lantern widgets');
        }
        await app.close();
      });
    }

    testWidgets('${skin.id} entry screens show no Lantern widget',
        (tester) async {
      final app = await LanternApp.start(tester,
          skin: skin, size: phone, lang: 'ar', location: '/welcome');
      for (final route in ['/welcome', '/viewer-setup', '/role-select']) {
        await app.go(route);
        tester.takeException();
        expect(tester.allWidgets.whereType<LanternSkinWidget>(), isEmpty,
            reason: '${skin.id} at $route');
      }
      await app.close();
    });
  }

  for (final (label, size) in [('phone', phone), ('laptop', laptop)]) {
    testWidgets('Lantern frames the tabs itself on a $label', (tester) async {
      final app =
          await LanternApp.start(tester, size: size, lang: 'ar');
      for (final route in ['/feed', '/map', '/lessons']) {
        await app.go(route);
        tester.takeException();
        expect(find.byType(LanternTabShell), findsOneWidget, reason: route);
        expect(find.byType(CaNavBar), findsNothing, reason: route);
        expect(find.byType(HidayahWebHeader), findsNothing, reason: route);
        expect(
            find.byType(
                size == phone ? LanternBottomNav : LanternWebHeader),
            findsOneWidget,
            reason: route);
      }
      await app.close();
    });
  }
}
