import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/presentation/lantern/lantern_lessons_actions.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';

import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The invitation picture (Lantern and Arch): a lesson drawn as a poster on
/// the device and handed to the system share sheet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const data = LanternPosterData(
      eyebrow: 'Mosque lesson',
      title: 'An explanation of the Forty Hadith of al-Nawawi',
      person: 'Sheikh Fahd Al-Otaibi',
      facts: [
        (icon: LGlyph.calendar, text: 'Wednesday 11 Nov (20 Jumada I 1448)'),
        (icon: LGlyph.clock, text: 'After Maghrib · ≈ 5:11 PM'),
        (icon: LGlyph.mosque, text: 'Al-Taqwa Mosque — Al-Rayyan, Dammam'),
      ],
      link: 'https://live.hedayh.org.sa/#/lessons/lesson/abc');

  const arabic = LanternPosterData(
      eyebrow: 'درس في المسجد',
      title: 'شرح الأربعين النووية: حديث إنما الأعمال بالنيات وما يتفرع عنه',
      person: 'الشيخ فهد بن عبدالله العتيبي',
      facts: [
        (icon: LGlyph.calendar, text: 'الأربعاء 11 نوفمبر (20 جمادى الأولى 1448)'),
        (icon: LGlyph.clock, text: 'بعد المغرب · ≈ 5:11 م'),
        (icon: LGlyph.mosque, text: 'مسجد التقوى — الريان، الدمام'),
      ],
      link: 'https://live.hedayh.org.sa/#/lessons/lesson/abc');

  for (final (lang, poster) in [('en', data), ('ar', arabic)]) {
    testWidgets('the poster keeps its size and fits its text ($lang)',
        (tester) async {
      await pumpLanternWidget(
          tester,
          // Large text on the phone must not change the picture.
          MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.6,
              maxScaleFactor: 1.6,
              child: Center(child: LanternPoster(poster))),
          lang: lang);
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(LanternPoster)), LanternPoster.size);
      expect(find.text(poster.title), findsOneWidget);
      expect(find.text(poster.person!), findsOneWidget);
      expect(find.text(poster.link), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('the picture is a 1080 by 1350 PNG and goes to the share sheet',
      (tester) async {
    final sent = <(Uint8List, String, String)>[];
    await pumpLanternWidget(
        tester,
        Builder(
            builder: (context) => Center(
                child: LButton(
                    label: 'open',
                    onPressed: () => showLanternPoster(context, data,
                        fileName: 'lesson-abc',
                        share: (png, name, text) async =>
                            sent.add((png, name, text)))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('lantern-poster-preview')), findsOneWidget);
    expect(find.text('Invitation picture'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('lantern-poster-share')));
      for (var i = 0; i < 40 && sent.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(sent, hasLength(1));
    final (png, name, text) = sent.single;
    expect(name, 'lesson-abc.png');
    expect(text, data.link);
    // The PNG signature, then the size.
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(png);
      return (await codec.getNextFrame()).image;
    });
    expect((image!.width, image.height), (1080, 1350));
    image.dispose();

    final dir = Platform.environment['LANTERN_CAPTURE_DIR'];
    if (dir != null) {
      Directory(dir).createSync(recursive: true);
      File('$dir/poster-en.png').writeAsBytesSync(png);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a failure to make the picture says so and sends nothing',
      (tester) async {
    await pumpLanternWidget(
        tester,
        Builder(
            builder: (context) => Center(
                child: LButton(
                    label: 'open',
                    onPressed: () => showLanternPoster(context, data,
                        share: (png, name, text) async =>
                            throw StateError('no share target'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('lantern-poster-share')));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('The picture could not be made. Try again.'),
        findsOneWidget);
    // The button is ready for another try.
    expect(
        tester
            .widget<LButton>(find.byKey(const ValueKey('lantern-poster-share')))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a lesson offers the invitation picture in its share sheet',
      (tester) async {
    final c = await tester.runAsync(() async {
      final c = LessonsController(DemoLessonsRepository());
      await c.ensureLoaded();
      return c;
    });
    addTearDown(c!.dispose);
    final lesson = c.upcoming.first;
    await pumpLanternWidget(
        tester,
        ChangeNotifierProvider<LessonsController>.value(
            value: c,
            child: Builder(
                builder: (context) => Center(
                    child: LButton(
                        label: 'share',
                        onPressed: () =>
                            showLanternShareSheet(context, lesson))))));
    await tester.tap(find.text('share'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('lantern-share-poster'));
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LanternPoster), findsOneWidget);
    final poster = tester.widget<LanternPoster>(find.byType(LanternPoster));
    expect(poster.data.title, lesson.title('en'));
    expect(poster.data.link, contains('/lessons/lesson/${lesson.id}'));
    expect(poster.data.facts, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
