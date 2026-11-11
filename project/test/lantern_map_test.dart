import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/widgets/lantern/lantern.dart';
import 'package:streamer_app/features/lessons/data/demo_lessons_repository.dart';
import 'package:streamer_app/features/lessons/domain/lessons_rules.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_in_app.dart';
import 'package:streamer_app/features/lessons/presentation/lessons_map.dart';
import 'package:streamer_app/features/lessons/state/lessons_controller.dart';
import 'package:streamer_app/features/map/presentation/lantern/lantern_map_pins.dart';
import 'package:streamer_app/features/map/presentation/lantern/lantern_place_card.dart';
import 'package:streamer_app/features/map/presentation/map_cluster_layout.dart';
import 'package:streamer_app/features/map/presentation/widgets/map_cluster_badge.dart';
import 'package:streamer_app/features/map/presentation/widgets/marker_summary_card.dart';
import 'package:streamer_app/features/map/presentation/widgets/spatial_streamer_marker.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/lantern_harness.dart';
import 'support/localized_app.dart';

/// The map in Lantern and Arch (ADR-026): markers never cover each other,
/// labels included; a bubble zooms to where it comes apart; places that
/// never come apart open a short list; and the new place cards.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await initializeTestLocalization();
    await loadAppFonts();
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('grouping by the box of a pin and its label', () {
    Offset project(LatLng p) => Offset(p.longitude, p.latitude);
    MapClusterPoint point(String id, double x, double y, {int priority = 0}) =>
        MapClusterPoint(id, LatLng(y, x), priority: priority);
    final w = kMapPinFootprint.width, h = kMapPinFootprint.height;

    bool overlap(Offset a, Offset b) =>
        (a.dx - b.dx).abs() < w && (a.dy - b.dy).abs() < h;

    test('two pins whose boxes would overlap become one bubble', () {
      final groups = clusterMapFootprints(
          [point('m:a', 100, 100), point('s:b', 100 + w - 1, 100 + h - 1)],
          project: project);
      expect(groups.single.memberIds, ['m:a', 's:b']);
    });

    test('a full box apart, across or down, they stay two markers', () {
      expect(
          clusterMapFootprints(
              [point('a', 100, 100), point('b', 100 + w, 100)],
              project: project),
          hasLength(2));
      expect(
          clusterMapFootprints(
              [point('a', 100, 100), point('b', 100, 100 + h)],
              project: project),
          hasLength(2));
    });

    test('it is a box, not a circle: near across but a box apart down', () {
      // 20 px across and 74 px down is closer than the box is wide, yet the
      // two boxes do not touch.
      final groups = clusterMapFootprints(
          [point('a', 100, 100), point('b', 120, 100 + h)],
          project: project);
      expect(groups, hasLength(2));
      // A circle of the old radius would still have joined pins this near.
      expect(
          clusterMapPoints([point('a', 100, 100), point('b', 120, 160)],
              project: project, radius: 84),
          hasLength(1));
    });

    test('no two markers left on the map overlap, labels included', () {
      final pins = [
        for (var i = 0; i < 400; i++)
          point('p$i', (i * 37 % 1200).toDouble(), (i * 53 % 800).toDouble(),
              priority: i % 5)
      ];
      final groups = clusterMapFootprints(pins, project: project);
      for (var i = 0; i < groups.length; i++) {
        for (var j = i + 1; j < groups.length; j++) {
          expect(
              overlap(project(groups[i].center), project(groups[j].center)),
              isFalse,
              reason: '${groups[i].id} and ${groups[j].id}');
        }
      }
      expect(groups.expand((g) => g.memberIds).toSet(), hasLength(400),
          reason: 'nothing is lost');
    });

    test('the highest priority anchors the bubble where it really is', () {
      final groups = clusterMapFootprints([
        point('m:quiet', 10, 10),
        point('s:live', 40, 20, priority: 6),
        point('s:off', 60, 10, priority: 1)
      ], project: project);
      expect(groups.single.center, const LatLng(20, 40));
    });

    test('the same pins group the same way in any order', () {
      final pins = [for (var i = 0; i < 60; i++) point('p$i', i * 23.0, i * 7)];
      expect(
          clusterMapFootprints(pins.reversed, project: project)
              .map((g) => g.id),
          clusterMapFootprints(pins, project: project).map((g) => g.id));
    });

    group('where a bubble comes apart', () {
      // World pixels double with each zoom level, as on the real map.
      Offset at(LatLng p, double zoom) =>
          Offset(p.longitude, p.latitude) * math.pow(2, zoom).toDouble();

      test('it is the first level at which two markers stand alone', () {
        // 30 px apart at zoom 10: 60 at 11, 120 at 12.
        final members = [point('a', 0, 0), point('b', 30 / 1024, 0)];
        final zoom = mapSeparationZoom(members,
            projectAt: at, from: 10, max: 18, step: .5);
        expect(zoom, 11.5, reason: '30 x 2^1.5 is the first width over 84');
        final groups = clusterMapFootprints(members,
            project: (p) => at(p, zoom!));
        expect(groups, hasLength(2));
        final before = clusterMapFootprints(members,
            project: (p) => at(p, zoom! - .5));
        expect(before, hasLength(1));
      });

      test('three places: it stops as soon as one stands alone', () {
        final members = [
          point('a', 0, 0),
          point('b', 2 / 1024, 0),
          point('c', 60 / 1024, 0)
        ];
        final zoom =
            mapSeparationZoom(members, projectAt: at, from: 10, max: 18);
        expect(zoom, 10.5);
      });

      test('places on the same spot never come apart', () {
        final members = [point('m:mosque', 5, 5), point('s:channel', 5, 5)];
        expect(
            mapSeparationZoom(members, projectAt: at, from: 10, max: 18),
            isNull);
      });

      test('it never asks for more than the map allows', () {
        final members = [point('a', 0, 0), point('b', 30 / 1024, 0)];
        expect(
            mapSeparationZoom(members, projectAt: at, from: 10, max: 11),
            isNull);
        expect(mapSeparationZoom([point('a', 0, 0)],
            projectAt: at, from: 10, max: 18), isNull);
      });
    });
  });

  group('pins', () {
    MapMosque mosque(
            {MosqueStatus status = MosqueStatus.today,
            bool live = false,
            String chip = 'in 2 h 28 min',
            int count = 3}) =>
        (
          id: 'm1',
          point: const LatLng(26.3, 50.2),
          label: 'Al-Huda Mosque',
          count: count,
          live: live,
          status: status,
          minutes: 40,
          chip: chip
        );

    for (final lang in ['ar', 'en']) {
      testWidgets('every pin keeps inside its box ($lang, large text)',
          (tester) async {
        await pumpLanternWidget(
            tester,
            MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: Wrap(children: [
                  LanternMosquePin(mosque(), onTap: () {}),
                  LanternMosquePin(mosque(live: true, chip: 'LIVE'),
                      onTap: () {}),
                  LanternMosquePin(
                      mosque(status: MosqueStatus.quiet, chip: '', count: 0),
                      onTap: () {}),
                  LanternStreamerPin(
                      name: 'الشيخ فهد بن سالم العتيبي',
                      live: true,
                      onTap: () {}),
                  LanternStreamerPin(
                      name: 'Quran', audio: true, live: true, onTap: () {}),
                  LanternStreamerPin(
                      name: 'Org',
                      org: true,
                      soon: 'in 35 minutes and more',
                      onTap: () {}),
                  LanternBubblePin(
                      count: 12,
                      mosques: 7,
                      live: 3,
                      onSite: 2,
                      semantics: '12 venues',
                      onTap: () {}),
                ])),
            lang: lang);
        expect(tester.takeException(), isNull);
        for (final type in [
          LanternMosquePin,
          LanternStreamerPin,
          LanternBubblePin
        ]) {
          for (final element in find.byType(type).evaluate()) {
            expect(tester.getSize(find.byWidget(element.widget)),
                kMapPinFootprint);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('state is in words and in the spoken name', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpLanternWidget(
          tester,
          Wrap(children: [
            LanternMosquePin(mosque(), onTap: () => taps++),
            LanternStreamerPin(
                name: 'Sheikh Fahd', live: true, onTap: () => taps++),
            LanternStreamerPin(
                name: 'Holy Quran', audio: true, live: true, onTap: () {}),
            LanternBubblePin(
                count: 5,
                mosques: 3,
                live: 1,
                onSite: 2,
                semantics: '5 venues. Tap to zoom or choose one.',
                onTap: () => taps++),
          ]));
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('AUDIO'), findsOneWidget);
      expect(find.text('in 2 h 28 min'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.bySemanticsLabel('Sheikh Fahd, LIVE'), findsOneWidget);
      expect(find.bySemanticsLabel('Holy Quran, AUDIO'), findsOneWidget);
      expect(
          find.bySemanticsLabel(
              RegExp('Al-Huda Mosque, 3 lessons this week, in 2 h 28 min')),
          findsOneWidget);
      await tester.tap(find.byType(LanternMosquePin));
      await tester.tap(find.byType(LanternStreamerPin).first);
      await tester.tap(find.byType(LanternBubblePin));
      expect(taps, 3);
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('place cards', () {
    Future<LessonsController> lessons() async {
      final c = LessonsController(DemoLessonsRepository());
      await c.ensureLoaded();
      return c;
    }

    Future<void> pumpCard(WidgetTester tester, LessonsController c,
        Widget card, {String lang = 'en', bool night = false}) async {
      await pumpLanternWidget(
          tester,
          ChangeNotifierProvider<LessonsController>.value(
              value: c,
              child: SingleChildScrollView(
                  child: Padding(
                      padding: const EdgeInsets.all(12), child: card))),
          lang: lang,
          night: night,
          size: const Size(420, 1400));
    }

    testWidgets('a mosque: this week, its page and its status from the schedule',
        (tester) async {
      final c = await tester.runAsync(lessons);
      addTearDown(c!.dispose);
      final withLessons = mapMosques(c, 'en')
          .where((m) => m.count > 0)
          .map((m) => m.id)
          .first;
      var closed = 0;
      for (final (lang, night) in [('en', false), ('ar', true)]) {
        await pumpCard(
            tester,
            c,
            LanternMosquePlaceCard(
                mosqueId: withLessons, onClose: () => closed++),
            lang: lang,
            night: night);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('lantern-map-mosque-card')),
            findsOneWidget);
      }
      await pumpCard(tester, c,
          LanternMosquePlaceCard(mosqueId: withLessons, onClose: () => closed++));
      expect(find.text(c.mosque(withLessons)!.name('en')), findsOneWidget);
      expect(find.text('This week at this mosque'), findsOneWidget);
      expect(find.widgetWithText(LButton, 'Mosque page'), findsOneWidget);
      expect(find.byKey(const ValueKey('lantern-map-status-band')),
          findsOneWidget);
      expect(find.text('Shown from the schedule'), findsOneWidget);
      await tester.tap(find.byTooltip('Close the card'));
      expect(closed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('without a connection it claims nothing about now',
        (tester) async {
      final c = await tester.runAsync(lessons);
      addTearDown(c!.dispose);
      final id =
          mapMosques(c, 'en').where((m) => m.count > 0).map((m) => m.id).first;
      await pumpCard(
          tester,
          c,
          LanternMosquePlaceCard(
              mosqueId: id, onClose: () {}, online: false));
      expect(
          find.byKey(const ValueKey('lantern-map-status-band')), findsNothing);
      expect(find.text('This week at this mosque'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a broadcaster who is live: the state, the place, Watch',
        (tester) async {
      final c = await tester.runAsync(lessons);
      addTearDown(c!.dispose);
      final live = mockStreamers.first.copyWith(
          isCurrentlyLive: true,
          broadcastType: BroadcastType.liveVideo,
          activeStreamId: 'lanternLive');
      await pumpCard(tester, c,
          LanternStreamerPlaceCard(streamer: live, onClose: () {}));
      expect(tester.takeException(), isNull);
      expect(find.text('LIVE'), findsWidgets);
      expect(find.widgetWithText(LButton, 'Watch'), findsOneWidget);
      expect(find.widgetWithText(LButton, 'Follow'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('lantern-map-card-venue')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a broadcaster who is not live: the next broadcast',
        (tester) async {
      final c = await tester.runAsync(lessons);
      addTearDown(c!.dispose);
      final off = mockStreamers[1].copyWith(isCurrentlyLive: false);
      await pumpCard(
          tester,
          c,
          LanternStreamerPlaceCard(
              streamer: off,
              onClose: () {},
              nextStart: DateTime.now().add(const Duration(days: 2)),
              nextTitle: 'Tafsir of Juz Amma'));
      expect(find.text('Next broadcast'), findsOneWidget);
      expect(find.text('Tafsir of Juz Amma'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.widgetWithText(LButton, 'Open the channel'), findsOneWidget);
      await pumpCard(tester, c,
          LanternStreamerPlaceCard(streamer: off, onClose: () {}));
      expect(find.text('No broadcast is scheduled'), findsOneWidget);
      expect(find.text('Offline'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('places that share a spot open a short list', (tester) async {
      final opened = <String>[];
      await pumpLanternWidget(
          tester,
          Builder(
              builder: (context) => Center(
                  child: LButton(
                      label: 'open',
                      onPressed: () => showLanternPlaceList(context,
                              title: '2 venues here',
                              places: [
                                (
                                  label: 'Al-Huda Mosque',
                                  mosque: true,
                                  open: () => opened.add('mosque')
                                ),
                                (
                                  label: 'Sheikh Fahd',
                                  mosque: false,
                                  open: () => opened.add('channel')
                                ),
                              ])))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('lantern-map-place-list')),
          findsOneWidget);
      expect(find.text('2 venues here'), findsOneWidget);
      await tester.tap(find.text('Sheikh Fahd'));
      await tester.pumpAndSettle();
      expect(opened, ['channel']);
      expect(
          find.byKey(const ValueKey('lantern-map-place-list')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('in the app', () {
    for (final (label, size) in [
      ('phone', const Size(390, 844)),
      ('laptop', const Size(1440, 900))
    ]) {
      testWidgets('the map draws Lantern pins and none overlap on a $label',
          (tester) async {
        final app = await LanternApp.start(tester,
            size: size, lang: 'ar', location: '/map');
        await app.settle(12);
        tester.takeException();
        final pins = [
          ...find.byType(LanternMosquePin).evaluate(),
          ...find.byType(LanternStreamerPin).evaluate(),
          ...find.byType(LanternBubblePin).evaluate(),
        ];
        expect(pins, isNotEmpty);
        expect(find.byType(SpatialStreamerMarker), findsNothing);
        expect(find.byType(MapClusterBadge), findsNothing);
        expect(find.byType(MosqueArch), findsNothing);
        final boxes = [
          for (final e in pins) tester.getRect(find.byWidget(e.widget))
        ];
        for (var i = 0; i < boxes.length; i++) {
          for (var j = i + 1; j < boxes.length; j++) {
            expect(boxes[i].deflate(.5).overlaps(boxes[j].deflate(.5)), isFalse,
                reason: 'pin $i and pin $j');
          }
        }
        await app.close();
      });
    }

    testWidgets('a pin opens the Lantern place card', (tester) async {
      final app = await LanternApp.start(tester,
          size: const Size(390, 844), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      final pin = find.byType(LanternStreamerPin).evaluate().isNotEmpty
          ? find.byType(LanternStreamerPin).first
          : find.byType(LanternMosquePin).first;
      await tester.tap(pin, warnIfMissed: false);
      await app.settle(10);
      tester.takeException();
      expect(
          find.byType(LanternStreamerPlaceCard).evaluate().length +
              find.byType(LanternMosquePlaceCard).evaluate().length,
          1);
      expect(find.byType(MarkerSummaryCard), findsNothing);
      expect(find.byType(MapMosqueCard), findsNothing);
      await app.close();
    });
  });
}
