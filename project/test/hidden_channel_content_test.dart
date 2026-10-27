import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/hidden_content_service.dart';
import 'package:streamer_app/features/profile/models/vod_models.dart';
import 'package:streamer_app/features/profile/presentation/widgets/channel_content_item.dart';
import 'package:streamer_app/features/live_stream/models/broadcast_session.dart';

import 'support/localized_app.dart';

class _FakeHiddenService extends HiddenContentService {
  _FakeHiddenService({this.fail = false});
  bool fail;
  final writes = <String>[];
  final deletes = <String>[];
  final takeDowns = <String>[];
  @override
  Future<void> setHidden(String streamerId, HiddenContentKind kind,
      String itemId, bool hidden) async {
    if (fail) throw StateError('offline');
    writes.add('${hidden ? 'hide' : 'show'} ${kind.name}:$itemId');
  }

  @override
  Future<void> deleteRecording(String videoId) async {
    if (fail) throw StateError('offline');
    deletes.add(videoId);
  }

  @override
  Future<void> takeDownRecording(String videoId, bool down, String reason) async {
    if (fail) throw StateError('offline');
    takeDowns.add('$videoId $down $reason');
  }
}

RecordingControl _recording(String id,
        {bool privateWanted = false,
        String youtubePrivacy = 'public',
        bool takenDown = false,
        bool deletePending = false,
        bool deleted = false,
        bool youtubeError = false,
        bool canDelete = true}) =>
    RecordingControl(
        videoId: id,
        privateWanted: privateWanted,
        youtubePrivacy: youtubePrivacy,
        takenDown: takenDown,
        deletePending: deletePending,
        deleted: deleted,
        youtubeError: youtubeError,
        canDelete: canDelete);

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

AppProvider _admin(_FakeHiddenService service) =>
    AppProvider.withServices(hiddenContentService: service)
      ..debugSetSignedInForTests(
          email: 'admin@example.invalid', isStreamer: false, isAdmin: true);

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

  group('recordings of lives made in the app', () {
    test('hiding or showing one updates what YouTube should have', () async {
      final service = _FakeHiddenService();
      final owner = _owner(service);
      owner.setRecordingControlsForTests('owner', {'a': _recording('a')});
      await owner.setContentHidden('owner', HiddenContentKind.video, 'a', true);
      expect(owner.recordingControl('owner', 'a')!.privateWanted, isTrue);
      expect(owner.recordingControl('owner', 'a')!.youtubePending, isTrue,
          reason: 'YouTube is still public until the server writes it');
      await owner.setContentHidden('owner', HiddenContentKind.video, 'a', false);
      expect(owner.recordingControl('owner', 'a')!.privateWanted, isFalse);
      expect(owner.recordingControl('owner', 'b'), isNull);
    });

    test('a taken-down recording cannot be shown by its owner', () async {
      final service = _FakeHiddenService();
      final owner = _owner(service);
      owner.setRecordingControlsForTests(
          'owner', {'a': _recording('a', privateWanted: true, takenDown: true)});
      owner.setHiddenContentForTests('owner', {'video:a'});
      await expectLater(
          owner.setContentHidden('owner', HiddenContentKind.video, 'a', false),
          throwsStateError);
      expect(service.writes, isEmpty);
      expect(owner.isContentHidden('owner', HiddenContentKind.video, 'a'),
          isTrue);
    });

    test('deleting needs a recording the owner may delete, and hides it at once',
        () async {
      final service = _FakeHiddenService();
      final owner = _owner(service);
      await expectLater(owner.deleteRecording('owner', 'a'), throwsStateError,
          reason: 'not a recording of a live made in the app');
      owner.setRecordingControlsForTests(
          'owner', {'a': _recording('a', canDelete: false)});
      await expectLater(owner.deleteRecording('owner', 'a'), throwsStateError,
          reason: 'a co-owner or presenter may not delete');
      expect(service.deletes, isEmpty);
      owner.setRecordingControlsForTests('owner', {'a': _recording('a')});
      await owner.deleteRecording('owner', 'a');
      expect(service.deletes, ['a']);
      expect(owner.isContentHidden('owner', HiddenContentKind.video, 'a'),
          isTrue);
      expect(owner.recordingControl('owner', 'a')!.deletePending, isTrue);
    });

    test('only admins take a recording down; they also see hidden items',
        () async {
      final ownerService = _FakeHiddenService();
      final owner = _owner(ownerService);
      owner.setRecordingControlsForTests('owner', {'a': _recording('a')});
      await expectLater(owner.takeDownRecording('owner', 'a', true, 'x'),
          throwsStateError);
      expect(ownerService.takeDowns, isEmpty);

      final service = _FakeHiddenService();
      final admin = _admin(service);
      admin.setStreamerMediaForTests('owner',
          vods: [_vod('a'), _vod('b')], playlists: const []);
      admin.setRecordingControlsForTests('owner', {'a': _recording('a')});
      await admin.takeDownRecording('owner', 'a', true, 'Harmful content');
      expect(service.takeDowns, ['a true Harmful content']);
      expect(admin.isContentHidden('owner', HiddenContentKind.video, 'a'),
          isTrue);
      expect(admin.recordingControl('owner', 'a')!.takenDown, isTrue);
      expect(admin.getVodsForStreamer('owner'), hasLength(2),
          reason: 'an admin must find a taken-down recording to restore it');
    });

    test('a hidden or taken-down replay is not offered for playing', () {
      BroadcastSession session(
              {bool hide = false,
              bool takenDown = false,
              String replay = 'available'}) =>
          BroadcastSession.fromRow({
            'id': 's',
            'owner_id': 'o',
            'org_id': null,
            'state': 'completed',
            'revision': 1,
            'broadcast_type': 'liveVideo',
            'stream_id': 'a',
            'replay_status': replay,
            'hide_replay': hide,
            'replay_taken_down': takenDown,
          });
      expect(session().replayWatchable, isTrue);
      expect(session(hide: true).replayWatchable, isFalse);
      expect(session(takenDown: true).replayWatchable, isFalse);
      expect(session(replay: 'deleted').replayWatchable, isFalse);
    });
  });

  group('recording menu', () {
    Widget host(AppProvider provider) =>
        ChangeNotifierProvider<AppProvider>.value(
            value: provider,
            child: localizedApp(
                home: const Scaffold(
                    body: Center(
                        child: SizedBox(
                            width: 240,
                            height: 140,
                            child: ChannelContentItem(
                                streamerId: 'owner',
                                kind: HiddenContentKind.video,
                                itemId: 'a',
                                title: 'Lecture a',
                                shareText: 'Lecture a\nhttps://youtu.be/a',
                                child: Card(child: Text('video card'))))))));

    Future<void> openMenu(WidgetTester tester) async {
      await tester.longPress(find.text('video card'));
      await tester.pumpAndSettle();
    }

    testWidgets('the owner sees YouTube wording, the status and delete',
        (tester) async {
      final service = _FakeHiddenService();
      final provider = _owner(service)
        ..setRecordingControlsForTests('owner', {'a': _recording('a')});
      await tester.pumpWidget(host(provider));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('content_actions.hide_recording_hint'.tr()),
          findsOneWidget);
      expect(find.text('content_actions.hide_hint'.tr()), findsNothing);
      expect(find.text('content_actions.yt_public'.tr()), findsOneWidget);
      expect(find.byKey(const Key('content-action-delete')), findsOneWidget);
      expect(find.byKey(const Key('content-action-take-down')), findsNothing);

      // Cancelling the confirmation deletes nothing.
      await tester.tap(find.byKey(const Key('content-action-delete')));
      await tester.pumpAndSettle();
      expect(find.text('content_actions.delete_confirm_title'.tr()),
          findsOneWidget);
      await tester.tap(find.text('common.cancel'.tr()));
      await tester.pumpAndSettle();
      expect(service.deletes, isEmpty);

      await openMenu(tester);
      await tester.tap(find.byKey(const Key('content-action-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('recording-delete-confirm')));
      await tester.pumpAndSettle();
      expect(service.deletes, ['a']);
      expect(find.byType(ImageFiltered), findsOneWidget,
          reason: 'gone from viewers at once; the owner sees it blurred');

      await openMenu(tester);
      expect(find.text('content_actions.yt_deleting'.tr()), findsOneWidget);
      expect(find.byKey(const Key('content-action-delete')), findsNothing,
          reason: 'already being deleted');
    });

    testWidgets('a taken-down recording: the owner cannot show it',
        (tester) async {
      final service = _FakeHiddenService();
      final provider = _owner(service)
        ..setRecordingControlsForTests('owner', {
          'a': _recording('a',
              privateWanted: true, youtubePrivacy: 'private', takenDown: true)
        })
        ..setHiddenContentForTests('owner', {'video:a'});
      await tester.pumpWidget(host(provider));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('content_actions.taken_down_hint'.tr()), findsOneWidget);
      expect(find.text('content_actions.taken_down_badge'.tr()), findsOneWidget);
      expect(find.text('content_actions.yt_private'.tr()), findsOneWidget);
      await tester.tap(find.byKey(const Key('content-action-hide-show')));
      await tester.pumpAndSettle();
      expect(service.writes, isEmpty);
      expect(find.byKey(const Key('content-action-delete')), findsOneWidget,
          reason: 'the owner may still delete it');
    });

    testWidgets('an admin takes a recording down with a reason',
        (tester) async {
      final service = _FakeHiddenService();
      final provider = _admin(service)
        ..setRecordingControlsForTests(
            'owner', {'a': _recording('a', canDelete: false)});
      await tester.pumpWidget(host(provider));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.byKey(const Key('content-action-hide-show')), findsNothing);
      expect(find.byKey(const Key('content-action-delete')), findsNothing);
      await tester.tap(find.byKey(const Key('content-action-take-down')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('safety-reason-field')), 'Harmful content');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('safety-reason-confirm')));
      await tester.pumpAndSettle();
      expect(service.takeDowns, ['a true Harmful content']);

      await openMenu(tester);
      expect(find.text('content_actions.restore_recording'.tr()),
          findsOneWidget);
    });

    testWidgets('YouTube problems, and videos not made in the app',
        (tester) async {
      final provider = _owner(_FakeHiddenService())
        ..setRecordingControlsForTests('owner', {
          'a': _recording('a', privateWanted: true, youtubeError: true)
        });
      await tester.pumpWidget(host(provider));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('content_actions.yt_error'.tr()), findsOneWidget);
    });

    testWidgets('a video not made in the app keeps the app-only menu',
        (tester) async {
      final plain = _owner(_FakeHiddenService());
      await tester.pumpWidget(host(plain));
      await tester.pumpAndSettle();
      await openMenu(tester);
      expect(find.text('content_actions.hide_hint'.tr()), findsOneWidget);
      expect(find.byKey(const Key('content-recording-status')), findsNothing);
      expect(find.byKey(const Key('content-action-delete')), findsNothing);
    });

    for (final (locale, width, scale) in const [
      (Locale('ar'), 360.0, 2.0),
      (Locale('en'), 360.0, 2.0),
      (Locale('ar'), 1280.0, 1.0),
    ]) {
      testWidgets(
          'menu and confirmation fit: ${locale.languageCode} ${width.toInt()} px ${scale}x',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final provider = _owner(_FakeHiddenService())
          ..setRecordingControlsForTests('owner', {
            'a': _recording('a',
                privateWanted: true, youtubePrivacy: 'private', takenDown: true)
          });
        await tester.pumpWidget(host(provider));
        await tester.pumpAndSettle();
        await tester.element(find.byType(Scaffold)).setLocale(locale);
        await tester.pumpAndSettle();
        await openMenu(tester);
        expect(tester.takeException(), isNull);
        await tester
            .ensureVisible(find.byKey(const Key('content-action-delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('content-action-delete')));
        await tester.pumpAndSettle();
        expect(
            find.byKey(const Key('recording-delete-confirm')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
