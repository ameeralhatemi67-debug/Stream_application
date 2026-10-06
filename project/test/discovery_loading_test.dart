import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/services/public_catalog_cache.dart';
import 'package:streamer_app/core/widgets/ds/ca_cards.dart';
import 'package:streamer_app/core/widgets/ds/ca_feedback.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/discovery_card_skeleton.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/streamer_grid_card.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/empty_broadcasts.dart';
import 'support/localized_app.dart';

class _Catalog extends AdminDatabaseService {
  final pending = <Completer<List<StreamerModel>>>[];
  @override
  Future<int> sweepStaleLiveFlags() async => 0;
  @override
  Future<List<StreamerModel>> loadVerifiedStreamersFromBackend(
      {bool requireSuccess = false}) {
    final request = Completer<List<StreamerModel>>();
    pending.add(request);
    return request.future;
  }
}

class _DelayedImageBundle extends CachingAssetBundle {
  final image = Completer<ByteData>();
  static const path = 'assets/images/avatars/neutral_1.png';
  @override
  Future<ByteData> load(String key) =>
      key == path ? image.future : rootBundle.load(key);
}

final _streamer = mockStreamers.first.copyWith(
    avatarUrl: '',
    bannerUrl: '',
    isCurrentlyLive: false,
    broadcastType: BroadcastType.offline,
    clearLiveState: true);

Future<void> _pumpFeed(WidgetTester tester, AppProvider provider) async {
  await tester.pumpWidget(localizedApp(
      home: ChangeNotifierProvider<AppProvider>.value(
          value: provider, child: const DiscoveryFeedScreen())));
  await tester.pump();
  await tester.pump();
}

Future<void> _close(WidgetTester tester, AppProvider provider) async {
  await tester.pumpWidget(const SizedBox.shrink());
  provider.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  test('queued catalog refresh does not notify or fetch after disposal', () async {
    final catalog = _Catalog();
    final provider = AppProvider.withServices(
        adminDbService: catalog,
        organizationBroadcastService: EmptyBroadcasts());
    final followUp = provider.loadVerifiedStreamersFromBackend();
    provider.dispose();
    catalog.pending.removeAt(0).complete([]);
    await followUp;
    expect(provider.isLoadingPublicCatalog, isFalse);
    expect(catalog.pending, isEmpty);
  });

  testWidgets(
      'first catalog load shows skeletons then real cards; refresh keeps cards',
      (tester) async {
    final catalog = _Catalog();
    final provider = AppProvider.withServices(
        adminDbService: catalog,
        organizationBroadcastService: EmptyBroadcasts());
    await _pumpFeed(tester, provider);
    expect(provider.isLoadingPublicCatalog, isTrue);
    expect(find.byType(DiscoveryCardSkeleton), findsNWidgets(5));
    expect(find.text('No streams found'), findsNothing);
    catalog.pending.removeAt(0).complete([_streamer]);
    await tester.pump();
    await tester.pump();
    expect(provider.isLoadingPublicCatalog, isFalse);
    expect(find.byType(DiscoveryCardSkeleton), findsNothing);
    expect(find.byType(StreamerGridCard), findsOneWidget);

    final refresh = provider.refreshCatalogIfOlderThan(Duration.zero);
    await tester.pump();
    expect(provider.isLoadingPublicCatalog, isTrue);
    expect(find.byType(DiscoveryCardSkeleton), findsNothing);
    expect(find.byType(StreamerGridCard), findsOneWidget);
    provider.setSearchQuery('no matching lecturer');
    await tester.pump();
    expect(find.byType(DiscoveryCardSkeleton), findsNothing);
    expect(find.text('No streams found'), findsOneWidget);
    catalog.pending.removeAt(0).complete([_streamer]);
    await refresh;
    await _close(tester, provider);
  });

  testWidgets('successful empty catalog stays an empty state during refresh',
      (tester) async {
    final catalog = _Catalog();
    final provider = AppProvider.withServices(
        adminDbService: catalog,
        organizationBroadcastService: EmptyBroadcasts());
    catalog.pending.removeAt(0).complete([]);
    await _pumpFeed(tester, provider);
    final refresh = provider.refreshCatalogIfOlderThan(Duration.zero);
    await tester.pump();
    expect(provider.hasPublicCatalogSnapshot, isTrue);
    expect(find.byType(DiscoveryCardSkeleton), findsNothing);
    expect(find.text('No streams found'), findsOneWidget);
    catalog.pending.removeAt(0).complete([]);
    await refresh;
    await _close(tester, provider);
  });

  testWidgets(
      'failed load stops skeletons; retry shows them only while pending',
      (tester) async {
    final catalog = _Catalog();
    final provider = AppProvider.withServices(
        adminDbService: catalog,
        organizationBroadcastService: EmptyBroadcasts());
    await _pumpFeed(tester, provider);
    catalog.pending.removeAt(0).completeError(StateError('Unavailable'));
    await tester.pump();
    await tester.pump();
    expect(provider.isLoadingPublicCatalog, isFalse);
    expect(find.byType(DiscoveryCardSkeleton), findsNothing);
    final retry = provider.refreshCatalogIfOlderThan(Duration.zero);
    await tester.pump();
    expect(find.byType(DiscoveryCardSkeleton), findsNWidgets(5));
    provider.debugSetOnlineForTests(false);
    await tester.pump();
    expect(find.byType(DiscoveryCardSkeleton), findsNothing);
    catalog.pending.removeAt(0).complete([_streamer]);
    await retry;
    expect(provider.streamers, isEmpty);
    await _close(tester, provider);
  });

  testWidgets('restored cache stays visible while the backend is pending',
      (tester) async {
    await PublicCatalogCache().save([_streamer], [], updatedAt: DateTime.now());
    final catalog = _Catalog();
    final provider = AppProvider.withServices(
        adminDbService: catalog,
        organizationBroadcastService: EmptyBroadcasts());
    await provider.restorePublicCatalogFromDisk();
    await _pumpFeed(tester, provider);
    expect(provider.isLoadingPublicCatalog, isTrue);
    expect(provider.hasPublicCatalogSnapshot, isTrue);
    expect(find.byType(DiscoveryCardSkeleton), findsNothing);
    expect(find.byType(StreamerGridCard), findsOneWidget);
    catalog.pending.removeAt(0).complete([_streamer]);
    await tester.pump();
    await _close(tester, provider);
  });

  for (final fail in [false, true]) {
    testWidgets(
        'Discovery images show skeletons until ${fail ? 'failure' : 'first frame'}',
        (tester) async {
      final bundle = _DelayedImageBundle();
      final provider = AppProvider();
      final card = _streamer.copyWith(
          avatarUrl: _DelayedImageBundle.path,
          bannerUrl: _DelayedImageBundle.path);
      await tester.pumpWidget(localizedApp(
          home: ChangeNotifierProvider<AppProvider>.value(
              value: provider,
              child: DefaultAssetBundle(
                  bundle: bundle,
                  child: Scaffold(
                      body: SizedBox(
                          width: 350,
                          child: StreamerGridCard(
                              streamer: card, langCode: 'en')))))));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CaSkeleton), findsNWidgets(2));
      if (fail) {
        bundle.image.completeError(StateError('Image unavailable'));
      } else {
        bundle.image.complete(await rootBundle.load(_DelayedImageBundle.path));
        for (var frame = 0; frame < 20; frame++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)));
          await tester.pump();
          if (find.byType(CaSkeleton).evaluate().isEmpty) break;
        }
      }
      await tester.pumpAndSettle();
      expect(find.byType(CaSkeleton), findsNothing);
      expect(find.byType(CaScholarCard), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _close(tester, provider);
    });
  }
}
