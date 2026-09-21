import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/auth/presentation/viewer_setup_screen.dart';
import 'package:streamer_app/features/auth/presentation/role_select_screen.dart';
import 'package:streamer_app/features/auth/presentation/application_pending_screen.dart';
import 'package:streamer_app/features/auth/presentation/streamer_apply_screen.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';

import 'package:streamer_app/features/map/presentation/spatial_map_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';
import 'fixtures/streamer_fixtures.dart';
import 'fixtures/dialog_fixtures.dart';
import 'support/stub_video_player.dart';
import 'package:streamer_app/core/widgets/device_session_conflict_dialog.dart';
import 'package:streamer_app/core/widgets/duplicate_channel_resolution_dialog.dart';
import 'package:streamer_app/features/discovery/presentation/widgets/tags_filter_bottom_sheet.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/permission_rationale_dialog.dart';
import 'package:streamer_app/features/map/presentation/widgets/venue_navigation_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/org_branches_modal_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/org_speaker_inspection_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/playlist_viewer_modal_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/viewer_profile_editor_dialog.dart';
import 'package:streamer_app/features/profile/presentation/widgets/vod_player_modal_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/join_org_modal_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/broadcaster_application_sheet.dart';
import 'package:streamer_app/features/auth/presentation/steps/apply_step_3_professional.dart';
import 'package:streamer_app/core/widgets/consent_dialog.dart';
import 'package:streamer_app/features/notifications/presentation/notification_center_sheet.dart';

class DirectJsonAssetLoader extends AssetLoader {
  final Map<String, dynamic> data;
  const DirectJsonAssetLoader(this.data);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async => data[locale.languageCode];
}

/// Stream ids the live-room variants resolve against. They are the fixtures'
/// own `activeStreamId`s, so the room finds a real streamer rather than
/// falling back to the first one in the list.
const _videoStreamId = 'stream_live_992';
const _audioStreamId = 'stream_quran_live_audio';
const _speakersStreamId = 'stream_org_speakers';

/// The player state each live-room variant reports, which is what selects the
/// placeholder overlay the room paints over the viewport.
StreamState _stubStateFor(String key) {
  switch (key) {
    case 'live room starting soon':
      return StreamState.startingSoon;
    case 'live room reconnecting':
      return StreamState.reconnecting;
    case 'live room offline':
      return StreamState.offline;
    case 'live room failed':
      return StreamState.fallbackError;
    default:
      return StreamState.live;
  }
}

/// Streamers the live-room variants need: one broadcasting video, one audio,
/// and one organization broadcasting audio with a speaker roster, which is
/// what mounts the multi-speaker stage and its overlay.
List<StreamerModel> _liveRoomStreamers() {
  final base = mockStreamers
      .map((s) => s.copyWith(avatarUrl: '', bannerUrl: ''))
      .toList();
  final organization =
      base.firstWhere((s) => s.affiliatedSpeakers.isNotEmpty, orElse: () => base.first);
  return [
    ...base.map((s) => s.streamerId == base.first.streamerId
        ? s.copyWith(
            isCurrentlyLive: true,
            broadcastType: BroadcastType.liveVideo,
            activeStreamId: _videoStreamId,
          )
        : s),
    organization.copyWith(
      streamerId: '${organization.streamerId}_speakers',
      isCurrentlyLive: true,
      broadcastType: BroadcastType.liveAudio,
      activeStreamId: _speakersStreamId,
    ),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogs = <String,dynamic>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for(final lang in ['en','ar']) {
      catalogs[lang] = jsonDecode(File('assets/i18n/$lang.json').readAsStringSync());
    }
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
    for (final entry in {
      'IBM Plex Sans': ['assets/fonts/IBMPlexSans-Variable.ttf'],
      'IBM Plex Sans Arabic': ['assets/fonts/IBMPlexSansArabic-400.ttf', 'assets/fonts/IBMPlexSansArabic-700.ttf'],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) { loader.addFont(rootBundle.load(path)); }
      await loader.load();
    }
  });
  const sizes = [Size(320,568), Size(360,640), Size(412,915), Size(600,960), Size(800,1280), Size(1280,800), Size(568,320)];
  final screens = <String, Widget Function()>{
    'welcome': () => const WelcomeScreen(),
    'viewer setup': () => const ViewerSetupScreen(),
    'role select': () => const RoleSelectScreen(),
    'application pending': () => const ApplicationPendingScreen(),
    'application identity': () => const StreamerApplyScreen(),
    for (var step = 1; step < 5; step++) 'wizard individual $step': () => const StreamerApplyScreen(),
    for (var step = 0; step < 6; step++) 'wizard organization $step': () => const StreamerApplyScreen(),
    'consent dialog': () => const Scaffold(body: ConsentDialog()),
    'notification sheet': () => const Scaffold(body: NotificationCenterSheet()),
    // Dialogs and sheets, each holding real content rather than an empty
    // shell: a long Arabic name, a roster, a branch list or a video list is
    // what actually overruns a 320 px phone at text scale 2.0.
    'dialog device conflict': () => Scaffold(
          body: DeviceSessionConflictDialog(
            currentDevice: currentDeviceFixture,
            existingDevice: existingDeviceFixture,
          ),
        ),
    'dialog duplicate channel': () => Scaffold(
          body: DuplicateChannelResolutionDialog(
            duplicateChannels: mockStreamers
                .take(3)
                .map((s) => s.copyWith(avatarUrl: '', bannerUrl: ''))
                .toList(),
          ),
        ),
    'dialog permission camera': () => const Scaffold(
          body: PermissionRationaleDialog(kind: BroadcastPermissionKind.camera),
        ),
    'dialog viewer profile editor': () =>
        const Scaffold(body: ViewerProfileEditorDialog()),
    'sheet tags filter': () => const Scaffold(body: TagsFilterBottomSheet()),
    'sheet venue navigation': () => Scaffold(
          body: VenueNavigationSheet(
            streamer:
                mockStreamers.first.copyWith(avatarUrl: '', bannerUrl: ''),
          ),
        ),
    'sheet org branches': () => const Scaffold(
          body: OrgBranchesModalSheet(
            orgName: 'جمعية دليلك التعليمية',
            venues: orgBranchesFixture,
          ),
        ),
    'sheet org speaker': () => Scaffold(
          body: OrgSpeakerInspectionSheet(
            speaker: orgSpeakersFixture.first,
            orgName: 'جمعية دليلك التعليمية',
            speakerVods: speakerVodsFixture(),
          ),
        ),
    'sheet playlist viewer': () => Scaffold(
          body: PlaylistViewerModalSheet(
            playlist: playlistFixture(),
            streamer:
                mockStreamers.first.copyWith(avatarUrl: '', bannerUrl: ''),
            langCode: 'en',
          ),
        ),
    'sheet vod player': () => Scaffold(
          body: VodPlayerModalSheet(
            vod: vodFixture(),
            streamer:
                mockStreamers.first.copyWith(avatarUrl: '', bannerUrl: ''),
          ),
        ),
    'sheet join org': () => const Scaffold(body: JoinOrgModalSheet()),
    'sheet broadcaster application': () =>
        const Scaffold(body: BroadcasterApplicationSheet()),
    'empty feed': () => const DiscoveryFeedScreen(),
    'populated feed': () => const DiscoveryFeedScreen(),
    'empty map': () => const SpatialMapScreen(),
    'populated map': () => const SpatialMapScreen(),
    'phone broadcast': () => const PhoneBroadcastScreen(),
    // The live room, laid out against a stubbed player (support/stub_video_player.dart).
    // Each state variant is a different placeholder/overlay layout, not a
    // different network condition.
    'live room video': () => const LiveBroadcastScreen(streamId: _videoStreamId),
    'live room audio': () => const LiveBroadcastScreen(streamId: _audioStreamId),
    'live room speakers': () =>
        const LiveBroadcastScreen(streamId: _speakersStreamId),
    'live room starting soon': () =>
        const LiveBroadcastScreen(streamId: _videoStreamId),
    'live room reconnecting': () =>
        const LiveBroadcastScreen(streamId: _videoStreamId),
    'live room offline': () => const LiveBroadcastScreen(streamId: _videoStreamId),
    'live room failed': () => const LiveBroadcastScreen(streamId: _videoStreamId),
    'live room streamer': () =>
        const LiveBroadcastScreen(streamId: _videoStreamId),
    'streamer settings': () => const SettingsScreen(),
    'admin settings': () => const SettingsScreen(),
    'organization settings': () => const SettingsScreen(),
    for (var tab = 0; tab < 13; tab++) 'admin tab $tab': () => const AdminHubScreen(),
    'viewer settings': () => const SettingsScreen(),
    'admin access denied': () => const AdminHubScreen(),
  };
  for(final entry in screens.entries) {
    for(final lang in ['en','ar']) {
      testWidgets('${entry.key} $lang at all sizes and text scales', (tester) async {
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for(final size in sizes) {
          for(final scale in [1.0, 1.3, 2.0]) {
            tester.view.physicalSize = size;
            final provider = AppProvider();
            if (entry.key.startsWith('live room') ||
                entry.key == 'sheet vod player') {
              // No WebView platform exists under the tester, so the room is
              // laid out against a stub that reports a fixed player state.
              StubVideoPlayer.install(
                state: _stubStateFor(entry.key),
                error: entry.key == 'live room failed' ? 'stubbed failure' : null,
                addTearDown: addTearDown,
              );
              if (entry.key.startsWith('live room')) {
                for (final streamer in _liveRoomStreamers()) {
                  provider.addStreamerForTests(streamer);
                }
              }
              if (entry.key == 'live room streamer') {
                provider.debugSetSignedInForTests(
                  email: 'streamer@example.test',
                  ownedStreamerId: mockStreamers.first.streamerId,
                );
              }
            }
            if (entry.key.startsWith('populated') || entry.key == 'streamer settings') {
              for (final streamer in mockStreamers) {
                provider.addStreamerForTests(streamer.copyWith(avatarUrl: '', bannerUrl: ''));
              }
            }
            if (entry.key.startsWith('admin tab') || entry.key == 'admin settings') {
              provider.debugSetSignedInForTests(email: 'admin@example.test', isMasterAdmin: true);
            } else if (entry.key == 'streamer settings') {
              provider.debugSetSignedInForTests(email: 'streamer@example.test', ownedStreamerId: mockStreamers.first.streamerId);
            } else if (entry.key == 'organization settings') {
              provider.debugSetSignedInForTests(email: 'owner@example.test', isStreamer: false, permittedAdminOrgIds: ['test-org']);
            }
            final previewKey = GlobalKey();
            final details = <String>[];
            final previousHandler = FlutterError.onError;
            FlutterError.onError = (error) {
              details.add(error.toString());
              previousHandler?.call(error);
            };
            await tester.pumpWidget(EasyLocalization(
              key: UniqueKey(), supportedLocales: const [Locale('en'), Locale('ar')],
              path:'assets/i18n', assetLoader: DirectJsonAssetLoader(catalogs),
              startLocale: Locale(lang), saveLocale:false,
              child: Builder(builder:(context) => ChangeNotifierProvider.value(value:provider,
                child: MaterialApp(locale:context.locale,
                  supportedLocales:context.supportedLocales,
                  localizationsDelegates:context.localizationDelegates,
                  theme:AppTheme.forLocale(Locale(lang)),
                  builder:(context,child)=>RepaintBoundary(key:previewKey, child:MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(scale)),child:child!)),
                  home:entry.value()),
              )),
            ));
            await tester.pump(const Duration(milliseconds:200));
            if (entry.key.startsWith('wizard')) {
              final controller = tester.widget<PageView>(find.byType(PageView)).controller!;
              if (entry.key.contains('organization')) {
                controller.jumpToPage(2);
                await tester.pump();
                tester.widget<ApplyStep3Professional>(find.byType(ApplyStep3Professional)).onTypeChanged(true);
                await tester.pump();
              }
              controller.jumpToPage(int.parse(entry.key.split(' ').last));
              await tester.pump();
            }
            if (entry.key.startsWith('admin tab')) {
              tester.widget<TabBar>(find.byType(TabBar).first).controller!.index = int.parse(entry.key.split(' ').last);
              await tester.pump(const Duration(milliseconds: 400));
            }
            final errors=<Object>[];
            Object? error;
            while((error=tester.takeException()) != null) { errors.add(error!); }
            FlutterError.onError = previousHandler;
            if (Platform.environment['UPDATE_DESIGN_PREVIEWS'] == '1' && size == const Size(360,640) && scale == 1.0 && errors.isEmpty) {
              await tester.runAsync(() async {
                final boundary = previewKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
                final image = await boundary.toImage();
                final bytes = await image.toByteData(format:ui.ImageByteFormat.png);
                final directory = Directory('../brief/assets/scheme_a_evidence')..createSync(recursive:true);
                File('${directory.path}/${entry.key.replaceAll(" ", "_")}_$lang.png').writeAsBytesSync(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            provider.dispose();
            expect(errors, isEmpty, reason:'${entry.key} $lang $size scale=$scale\n${details.join("\n")}');
          }
        }
      });
    }
  }
}
