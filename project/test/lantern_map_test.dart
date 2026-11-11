import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
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
import 'package:streamer_app/core/widgets/language_switcher.dart';
import 'package:streamer_app/features/map/models/map_models.dart';
import 'package:streamer_app/features/map/presentation/lantern/lantern_map_chrome.dart';
import 'package:streamer_app/features/map/presentation/lantern/lantern_map_pins.dart';
import 'package:streamer_app/features/map/presentation/lantern/lantern_place_card.dart';
import 'package:streamer_app/features/map/presentation/map_cluster_layout.dart';
import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/map/presentation/web/map_web_panel.dart';
import 'package:streamer_app/features/map/presentation/widgets/city_selector_dropdown.dart';
import 'package:streamer_app/features/map/presentation/widgets/map_cluster_badge.dart';
import 'package:streamer_app/features/map/presentation/widgets/map_status_details.dart';
import 'package:streamer_app/features/map/presentation/widgets/marker_summary_card.dart';
import 'package:streamer_app/features/map/presentation/widgets/spatial_streamer_marker.dart';
import 'package:streamer_app/features/map/presentation/widgets/streamer_sliding_drawer.dart';
import 'package:streamer_app/features/map/presentation/widgets/top_spatial_search_bar.dart';
import 'package:streamer_app/features/map/presentation/widgets/topic_selector_dropdown.dart';
import 'package:streamer_app/features/map/services/map_pack_controller.dart';
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
    // A pin under the search or a card cannot be tapped; take one that can.
    Finder? singlePin() {
      for (final type in [LanternStreamerPin, LanternMosquePin]) {
        final pins = find.byType(type).hitTestable();
        if (pins.evaluate().isNotEmpty) return pins.first;
      }
      return null;
    }

    // What the map shows changes with the time of day. When every place is
    // inside a group, come closer through a group until one stands alone.
    Future<Finder> tappablePin(WidgetTester tester, LanternApp app) async {
      for (var i = 0; i < 8; i++) {
        final pin = singlePin();
        if (pin != null) return pin;
        final groups = find.byType(LanternBubblePin).hitTestable();
        if (groups.evaluate().isEmpty) {
          await tester
              .tap(find.byKey(const ValueKey('lantern-map-zoom-in')));
        } else {
          await tester.tap(groups.first);
        }
        await app.settle(10);
        // Places that never come apart open a short list: take the first.
        final list = find.byKey(const ValueKey('lantern-map-place-list'));
        if (list.evaluate().isNotEmpty) {
          await tester.tap(
              find.descendant(of: list, matching: find.byType(LRow)).first);
          await app.settle(10);
          break;
        }
      }
      return singlePin() ?? (throw TestFailure('no pin can be tapped'));
    }

    Finder onMap(Type type) => find.descendant(
        of: find.byType(SpatialMapScreen), matching: find.byType(type));

    Finder rows(String kind) => find.byWidgetPredicate((w) {
          final key = w.key;
          return key is ValueKey<String> &&
              key.value.startsWith('lantern-map-row-$kind-');
        });

    double zoomOf(WidgetTester tester) => tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .camera
        .zoom;

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
      final card = find.byWidgetPredicate((w) =>
          w is LanternStreamerPlaceCard || w is LanternMosquePlaceCard);
      final pin = await tappablePin(tester, app);
      // The short list of a shared spot has already opened a card.
      if (card.evaluate().isEmpty) await tester.tap(pin);
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

    for (final lang in ['en', 'ar']) {
      testWidgets('a phone: only Lantern controls around the map ($lang)',
          (tester) async {
        final app = await LanternApp.start(tester,
            size: const Size(390, 844), lang: lang, location: '/map');
        await app.settle(12);
        expect(tester.takeException(), isNull);
        for (final type in [
          TopSpatialSearchBar,
          CitySelectorDropdown,
          TopicSelectorDropdown,
          MapLayerSwitch,
          MapAttributionRail,
          MapConnectionChip,
          MapNowPill,
          MapWebPanel,
          StreamerSlidingDrawer,
          LanguageSwitcher,
        ]) {
          expect(onMap(type), findsNothing, reason: '$type');
        }
        expect(find.byType(LanternMapSearch), findsOneWidget);
        expect(find.byType(LanternMapControls), findsOneWidget);
        expect(find.byType(LanternMapAttribution), findsOneWidget);
        expect(find.byType(LanternMapPanel), findsNothing);
        // The credit stays clear of the floating navigation.
        expect(
            tester.getRect(find.byType(LanternMapAttribution)).bottom,
            lessThanOrEqualTo(
                tester.getRect(find.byType(LanternBottomNav)).top + 1));
        await app.close();
      });

      testWidgets('the website layout: the panel beside the map ($lang)',
          (tester) async {
        final app = await LanternApp.start(tester,
            size: const Size(1440, 900), lang: lang, location: '/map');
        await app.settle(12);
        expect(tester.takeException(), isNull);
        expect(find.byType(LanternMapPanel), findsOneWidget);
        expect(onMap(MapWebPanel), findsNothing);
        expect(onMap(TopSpatialSearchBar), findsNothing);
        final panel = tester.getRect(find.byType(LanternMapPanel));
        final map = tester.getRect(find.byType(FlutterMap));
        expect(panel.width, Lantern.sideChat);
        // The panel is on the start side, so it mirrors in Arabic.
        if (lang == 'ar') {
          expect(panel.left, greaterThanOrEqualTo(map.right - 1));
        } else {
          expect(panel.right, lessThanOrEqualTo(map.left + 1));
        }
        // The buttons are on the end side of the map.
        final controls = tester.getRect(find.byType(LanternMapControls));
        expect((lang == 'ar' ? controls.left - map.left : map.right - controls.right),
            lessThan(40));
        await app.close();
      });
    }

    testWidgets('a row of the panel selects its place and opens its card',
        (tester) async {
      final app = await LanternApp.start(tester,
          size: const Size(1440, 900), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      expect(find.text('Lecture map'), findsOneWidget);
      expect(find.text('Scholars and channels'), findsOneWidget);
      expect(rows('s'), findsWidgets);
      await tester.tap(rows('s').first);
      await app.settle(4);
      expect(tester.takeException(), isNull);
      expect(find.byType(LanternStreamerPlaceCard), findsOneWidget);
      // The card sits at the start of the map, not over the panel.
      expect(tester.getRect(find.byType(LanternStreamerPlaceCard)).left,
          greaterThanOrEqualTo(Lantern.sideChat));
      await app.close();
    });

    testWidgets('the legend: a card on the website layout, a sheet on a phone',
        (tester) async {
      var app = await LanternApp.start(tester,
          size: const Size(1440, 900), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      const button = ValueKey('lantern-map-legend-button');
      await tester.tap(find.byKey(button));
      await app.settle(2);
      expect(find.byType(LanternMapLegendCard), findsOneWidget);
      expect(find.text('A mosque with lessons'), findsOneWidget);
      await tester.tap(find.byKey(button));
      await app.settle(2);
      expect(find.byType(LanternMapLegendCard), findsNothing);
      await app.close();

      app = await LanternApp.start(tester,
          size: const Size(390, 844), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      await tester.tap(find.byKey(button));
      await app.settle(6);
      expect(find.byType(LanternMapLegendCard), findsNothing);
      expect(find.byType(LanternMapLegend), findsOneWidget);
      expect(find.text('What the markers mean'), findsOneWidget);
      await app.close();
    });

    testWidgets('closer and farther move the camera one step', (tester) async {
      final app = await LanternApp.start(tester,
          size: const Size(390, 844), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      final start = zoomOf(tester);
      await tester.tap(find.byKey(const ValueKey('lantern-map-zoom-in')));
      await app.settle(10);
      expect(zoomOf(tester), closeTo(start + 1, .01));
      await tester.tap(find.byKey(const ValueKey('lantern-map-zoom-out')));
      await app.settle(10);
      expect(zoomOf(tester), closeTo(start, .01));
      await app.close();
    });

    testWidgets('a phone: the filters are a sheet and a city applies at once',
        (tester) async {
      final app = await LanternApp.start(tester,
          size: const Size(390, 844), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      final start = zoomOf(tester);
      await tester
          .tap(find.byKey(const ValueKey('lantern-map-filter-button')));
      await app.settle(6);
      expect(find.byKey(const ValueKey('lantern-map-filter-sheet')),
          findsOneWidget);
      expect(find.text('All three cities'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('lantern-map-city-khobar')));
      await app.settle(10);
      expect(tester.takeException(), isNull);
      expect(
          tester
              .widget<LChip>(
                  find.byKey(const ValueKey('lantern-map-city-khobar')))
              .selected,
          isTrue);
      // The camera framed the city: closer than the three-city view.
      expect(zoomOf(tester), greaterThan(start));
      await app.close();
    });

    testWidgets('a phone: the list is a sheet and a row opens its card',
        (tester) async {
      final app = await LanternApp.start(tester,
          size: const Size(390, 844), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      await tester.tap(find.byKey(const ValueKey('lantern-map-list-button')));
      await app.settle(6);
      expect(
          find.byKey(const ValueKey('lantern-map-list-sheet')), findsOneWidget);
      await tester.tap(rows('s').first);
      await app.settle(10);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lantern-map-list-sheet')), findsNothing);
      expect(find.byType(LanternStreamerPlaceCard), findsOneWidget);
      await app.close();
    });

    testWidgets('search finds a city view and a broadcaster', (tester) async {
      final app = await LanternApp.start(tester,
          size: const Size(390, 844), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      final field = find.byKey(const ValueKey('lantern-map-search'));
      final start = zoomOf(tester);
      await tester.enterText(
          find.descendant(of: field, matching: find.byType(TextField)),
          'Khobar');
      await app.settle(3);
      expect(find.byKey(const ValueKey('lantern-map-search-results')),
          findsOneWidget);
      expect(find.text('City view'), findsOneWidget);
      await tester.tap(find.text('City view'));
      await app.settle(10);
      expect(find.byKey(const ValueKey('lantern-map-search-results')),
          findsNothing);
      expect(zoomOf(tester), greaterThan(start));

      final name = app.provider.filteredStreamers.first.fullNameEn;
      await tester.enterText(
          find.descendant(of: field, matching: find.byType(TextField)), name);
      await app.settle(3);
      await tester.tap(find
          .descendant(
              of: find.byKey(const ValueKey('lantern-map-search-results')),
              matching: find.byType(LPressable))
          .first);
      await app.settle(10);
      expect(tester.takeException(), isNull);
      expect(find.byType(LanternStreamerPlaceCard), findsOneWidget);

      await tester.enterText(
          find.descendant(of: field, matching: find.byType(TextField)),
          'zzzzqq');
      await app.settle(3);
      expect(find.text('No current map results'), findsOneWidget);
      await app.close();
    });

    testWidgets('without a connection: one line with Retry, and the details',
        (tester) async {
      final app = await LanternApp.start(tester,
          size: const Size(390, 844), lang: 'en', location: '/map');
      await app.settle(12);
      tester.takeException();
      expect(find.byType(LanternMapConnection), findsNothing);
      app.provider.debugSetOnlineForTests(false);
      await app.settle(6);
      expect(tester.takeException(), isNull);
      expect(find.byType(LanternMapConnection), findsOneWidget);
      expect(onMap(MapConnectionChip), findsNothing);
      expect(find.widgetWithText(LButton, 'Retry'), findsOneWidget);
      // No broadcaster is shown as live from a saved list.
      expect(find.text('LIVE'), findsNothing);
      await tester.tap(find.byTooltip('Map details and credits'));
      await app.settle(6);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lantern-map-details')), findsOneWidget);
      expect(find.text('Credits'), findsOneWidget);
      await app.close();
    });
  });

  group('the pieces around the map', () {
    for (final (lang, night) in [
      ('en', false),
      ('ar', false),
      ('en', true),
      ('ar', true)
    ]) {
      testWidgets('they lay out with large text ($lang, night $night)',
          (tester) async {
        await pumpLanternWidget(
            tester,
            MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.3,
                maxScaleFactor: 1.3,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const LanternMapCounts(total: 12, onSite: 2, live: 3),
                          const SizedBox(height: 8),
                          const Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: LanternMapNowPill(onSite: 2, live: 3)),
                          const SizedBox(height: 8),
                          LanternMapEmptyNotice(
                              online: true, retrying: false, onRetry: () {}),
                          const SizedBox(height: 8),
                          LanternMapConnection(
                              label: 'Offline · venues saved 2026-11-10 21:05',
                              retrying: false,
                              onRetry: () {},
                              onDetails: () {}),
                          const SizedBox(height: 8),
                          LanternMapOfflineHint(
                              evicted: false, onPrepare: () {}, onDismiss: () {}),
                          const SizedBox(height: 8),
                          LanternMapLegendCard(onClose: () {}),
                          const SizedBox(height: 8),
                          Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: LanternMapAttribution(
                                  credit: '© OpenStreetMap contributors',
                                  url: 'https://www.openstreetmap.org/copyright',
                                  onDetails: () {})),
                          const SizedBox(height: 8),
                          LanternMapLayerChips(
                              value: MapLayers.all, onChanged: (_) {}),
                          const SizedBox(height: 8),
                          LanternMapFilters(
                              wrap: true,
                              cityId: kLanternAllCities,
                              onCity: (_) {},
                              topics: lessonTopicCategories(),
                              topicId: 'all',
                              onTopic: (_) {}),
                        ]))),
            lang: lang,
            night: night,
            size: const Size(360, 1500));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('the stored map cannot be used: say so, offer a retry and the list',
        (tester) async {
      var listed = 0;
      final pack = MapPackController(bundle: _NoPackBundle(), useWebStore: false);
      await tester.runAsync(pack.ensureOpened);
      await pumpLanternWidget(
          tester,
          Center(
              child: LanternMapPackStatus(
                  controller: pack, onShowList: () => listed++)));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lantern-map-pack-problem')),
          findsOneWidget);
      expect(find.text("The map can't be shown"), findsOneWidget);
      expect(find.widgetWithText(LButton, 'Try again'), findsOneWidget);
      await tester.tap(find.widgetWithText(LButton, 'Places on the map'));
      expect(listed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a saved place without a connection: what is held, and the way',
        (tester) async {
      final marker = MapMarkerModel.fromStreamer(mockStreamers.first);
      await pumpLanternWidget(
          tester,
          Builder(
              builder: (context) => Center(
                  child: LButton(
                      label: 'open',
                      onPressed: () =>
                          showLanternCachedPlace(context, marker)))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lantern-map-cached-place')),
          findsOneWidget);
      expect(find.text(marker.getLocalizedName('en')), findsOneWidget);
      expect(
          find.text("Full details and live status aren't available offline."),
          findsOneWidget);
      expect(find.widgetWithText(LButton, 'Open in Maps'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the list with nothing in it offers the three cities',
        (tester) async {
      var all = 0;
      await pumpLanternWidget(
          tester,
          LanternMapPlaceList(
              mosques: const [],
              streamers: const [],
              onMosque: (_) {},
              onStreamer: (_) {},
              onShowAll: () => all++));
      expect(find.byKey(const ValueKey('lantern-map-list-empty')),
          findsOneWidget);
      await tester.tap(find.widgetWithText(LButton, 'Show all three cities'));
      expect(all, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

/// A bundle with no map files, so the stored map reports a problem.
class _NoPackBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      throw FlutterError('Unable to load asset: $key');
}
