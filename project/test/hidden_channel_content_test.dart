import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/hidden_content_service.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';
import 'package:streamer_app/features/profile/presentation/widgets/channel_content_item.dart';

import 'support/localized_app.dart';

class _FakeHiddenService extends HiddenContentService {
  _FakeHiddenService({this.fail = false});
  bool fail;
  final writes = <String>[];
  @override
  Future<void> setHidden(String streamerId, HiddenContentKind kind,
      String itemId, bool hidden) async {
    if (fail) throw StateError('offline');
    writes.add('${hidden ? 'hide' : 'show'} ${kind.name}:$itemId');
  }
}

VodModel _vod(String id) => VodModel(
    vodId: 'vod_yt_$id',
    streamerId: 'owner',
    titleEn: 'Lecture $id',
    titleAr: 'محاضرة $id',
    descriptionEn: '',
    descriptionAr: '',
    youtubeVideoId: id,
    durationSeconds: 60,
    recordedDate: '2026-10-01',
    thumbnailUrl: '',
    viewCount: 0);

PlaylistModel _playlist(String id) => PlaylistModel(
    playlistId: id,
    streamerId: 'owner',
    titleEn: 'Playlist $id',
    titleAr: 'قائمة $id',
    descriptionEn: '',
    descriptionAr: '',
    youtubePlaylistUrl: 'https://www.youtube.com/playlist?list=$id',
    thumbnailUrl: '',
    videoCount: 0,
    videos: const []);

AppProvider _viewer(_FakeHiddenService service) =>
    AppProvider.withServices(hiddenContentService: service);

AppProvider _owner(_FakeHiddenService service) =>
    AppProvider.withServices(hiddenContentService: service)
      ..debugSetSignedInForTests(
          email: 'owner@example.invalid', ownedStreamerId: 'owner');

void main() {
  setUpAll(initializeTestLocalization);

  group('hidden videos and playlists', () {
    test('viewers do not get hidden items; the owner gets everything', () {
      final viewer = _viewer(_FakeHiddenService());
      viewer.setStreamerMediaForTests('owner',
          vods: [_vod('a'), _vod('b')],
          playlists: [_playlist('p1'), _playlist('p2')]);
      viewer.setHiddenContentForTests('owner', {'video:a', 'playlist:p2'});
      expect(viewer.getVodsForStreamer('owner').map((v) => v.youtubeVideoId),
          ['b']);
      expect(
          viewer.getPlaylistsForStreamer('owner').map((p) => p.playlistId),
          ['p1']);
      expect(viewer.getVodsForStreamer('owner'),
          same(viewer.getVodsForStreamer('owner')),
          reason: 'screens select on the list, so it must be stable');

      final owner = _owner(_FakeHiddenService());
      owner.setStreamerMediaForTests('owner',
          vods: [_vod('a'), _vod('b')],
          playlists: [_playlist('p1'), _playlist('p2')]);
      owner.setHiddenContentForTests('owner', {'video:a', 'playlist:p2'});
      expect(owner.getVodsForStreamer('owner'), hasLength(2));
      expect(owner.getPlaylistsForStreamer('owner'), hasLength(2));
      expect(owner.isContentHidden('owner', HiddenContentKind.video, 'a'),
          isTrue);
    });

    test('videos inside a playlist follow the same rule', () {
      final viewer = _viewer(_FakeHiddenService());
      viewer.setHiddenContentForTests('owner', {'video:a'});
      expect(
          viewer
              .visibleVideosFor('owner', [_vod('a'), _vod('b')])
              .map((v) => v.youtubeVideoId),
          ['b']);
    });

    test('only the owner can change it, and a failed save changes nothing',
        () async {
      final service = _FakeHiddenService();
      final viewer = _viewer(service);
      await expectLater(
          viewer.setContentHidden(
              'owner', HiddenContentKind.video, 'a', true),
          throwsStateError);
      expect(service.writes, isEmpty);

      final failing = _FakeHiddenService(fail: true);
      final owner = _owner(failing);
      await expectLater(
          owner.setContentHidden('owner', HiddenContentKind.video, 'a', true),
          throwsStateError);
      expect(owner.isContentHidden('owner', HiddenContentKind.video, 'a'),
          isFalse);

      final working = _FakeHiddenService();
      final saved = _owner(working);
      await saved.setContentHidden('owner', HiddenContentKind.video, 'a', true);
      expect(saved.isContentHidden('owner', HiddenContentKind.video, 'a'),
          isTrue);
      await saved.setContentHidden('owner', HiddenContentKind.video, 'a', false);
      expect(saved.isContentHidden('owner', HiddenContentKind.video, 'a'),
          isFalse);
      expect(working.writes, ['hide video:a', 'show video:a']);
    });
  });

  group('long press menu', () {
    Widget host(AppProvider provider, {String itemId = 'a'}) =>
        ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: localizedApp(
                home: Scaffold(
                    body: Center(
                        child: SizedBox(
                            width: 240,
                            height: 140,
                            child: ChannelContentItem(
                                streamerId: 'owner',
                                kind: HiddenContentKind.video,
                                itemId: itemId,
                                title: 'Lecture a',
                                shareText: 'Lecture a\nhttps://youtu.be/a',
                                child: const Card(child: Text('video card'))))))));

    testWidgets('the owner can hide a video, then show it again',
        (tester) async {
      final service = _FakeHiddenService();
      final provider = _owner(service);
      await tester.pumpWidget(host(provider));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('video card'));
      await tester.pumpAndSettle();
      expect(find.text('content_actions.share_video'.tr()), findsOneWidget);
      await tester.tap(find.text('content_actions.hide'.tr()));
      await tester.pumpAndSettle();

      expect(service.writes, ['hide video:a']);
      expect(find.byType(ImageFiltered), findsOneWidget,
          reason: 'a hidden item is blurred for its owner');
      expect(find.text('video card'), findsOneWidget,
          reason: 'the owner still sees the item, blurred');

      await tester.longPress(find.text('video card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('content_actions.show'.tr()));
      await tester.pumpAndSettle();
      expect(service.writes, ['hide video:a', 'show video:a']);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('a viewer can only share, and never sees a hidden item',
        (tester) async {
      final provider = _viewer(_FakeHiddenService());
      await tester.pumpWidget(host(provider));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('video card'));
      await tester.pumpAndSettle();
      expect(find.text('content_actions.share_video'.tr()), findsOneWidget);
      expect(find.text('content_actions.hide'.tr()), findsNothing);
      expect(find.text('content_actions.show'.tr()), findsNothing);

      provider.setHiddenContentForTests('owner', {'video:a'});
      await tester.pumpWidget(host(provider));
      await tester.pumpAndSettle();
      expect(find.text('video card'), findsNothing);
    });
  });
}
