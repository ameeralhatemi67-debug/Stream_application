// P6S wave 3, group 5: viewer playback that does what it shows.
//  * Play, pause and mute send real commands to the player; the room only
//    shows the new state once the command went through.
//  * One player instance survives layout changes (rotation, fullscreen).
//  * Retry reloads the player instead of only changing a label.
//  * The "mini-player" is an honest shortcut back, not a fake video.
//  * The studio help is mode-specific and makes no promises.
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/floating_stream_mini_player.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart'
    show StudioMode;
import 'package:streamer_app/features/live_stream/presentation/widgets/streamer_setup_guide_modal.dart';
import 'package:streamer_app/features/live_stream/services/live_chat_controller.dart';
import 'package:streamer_app/features/live_stream/services/viewer_presence_service.dart';
import 'package:streamer_app/features/profile/models/streamer_models.dart';

import 'fixtures/streamer_fixtures.dart';
import 'support/localized_app.dart';
import 'support/empty_broadcasts.dart';

class _Log {
  int playerTaps = 0;
  bool confirmCommands = true;
  int created = 0;
  int disposed = 0;
  final commands = <String>[];
  bool transport = true;
  bool refuse = false;

  /// What the player reports once it is up; a real player says it is playing.
  StreamState? report = StreamState.live;

  /// Lets a test report a later state from the current player.
  ValueChanged<StreamState>? emit;

  /// The starting mute of each player created, in order.
  final initialMuted = <bool>[];
  final autoplay = <bool>[];

  /// The current player's own mute state (its built-in controls).
  ValueNotifier<bool>? muted;

  /// When set, pause() waits for it (a command in flight).
  Completer<bool>? pauseGate;
}

class _Player extends AbstractVideoPlayer {
  const _Player(
      {required super.streamUrl,
      required this.log,
      super.key,
      super.onStateChanged,
      super.onPlayerReady,
      super.autoPlay,
      this.initialMuted = false});
  final bool initialMuted;
  final _Log log;
  @override
  State<_Player> createState() => _PlayerState();
}

class _PlayerState extends State<_Player> implements PlayerTransport {
  @override
  bool get supportsCommands => widget.log.transport;

  Future<bool> _send(String c) async {
    if (widget.log.refuse) return false;
    widget.log.commands.add(c);
    if (widget.log.confirmCommands && (c == 'play' || c == 'pause')) {
      widget.onStateChanged
          ?.call(c == 'play' ? StreamState.live : StreamState.paused);
    }
    return true;
  }

  @override
  Future<bool> play() => _send('play');
  @override
  Future<bool> pause() async {
    final gate = widget.log.pauseGate;
    if (gate != null) {
      widget.log.commands.add('pause');
      final sent = await gate.future;
      if (sent && widget.log.confirmCommands) {
        widget.onStateChanged?.call(StreamState.paused);
      }
      return sent;
    }
    return _send('pause');
  }

  late final ValueNotifier<bool> _muted = ValueNotifier(widget.initialMuted);
  @override
  ValueListenable<bool> get mutedListenable => _muted;
  @override
  Future<bool> setMuted(bool muted) async {
    final sent = await _send(muted ? 'mute' : 'unmute');
    if (sent) _muted.value = muted;
    return sent;
  }

  @override
  void initState() {
    super.initState();
    widget.log.created++;
    widget.log.initialMuted.add(widget.initialMuted);
    widget.log.autoplay.add(widget.autoPlay);
    widget.log.muted = _muted;
    widget.log.emit = (state) => widget.onStateChanged?.call(state);
    final report = widget.log.report;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onPlayerReady?.call();
      if (report != null) widget.onStateChanged?.call(report);
    });
  }

  @override
  void dispose() {
    widget.log.disposed++;
    _muted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.log.playerTaps++,
        child: const SizedBox.expand(),
      );
}

class _Chat extends LiveChatController {
  _Chat(String id) : super(streamId: id);
  @override
  Future<void> start() async {}
}

class _Presence extends ViewerPresenceService {
  _Presence(String id) : super(streamId: id);
  @override
  Future<void> start() async {}
}

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

Widget _app(AppProvider provider, Widget home, {String lang = 'en'}) =>
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      startLocale: Locale(lang),
      saveLocale: false,
      path: 'assets/i18n',
      assetLoader: const DirectJsonAssetLoader(),
      child: ChangeNotifierProvider<AppProvider>.value(
        value: provider,
        child: Builder(
          builder: (context) => MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!),
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            theme: AppTheme.forLocale(context.locale),
            home: home,
          ),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initializeTestLocalization);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('room player', () {
    late _Log log;
    late _Catalog roomCatalog;
    setUp(() {
      log = _Log();
      LiveBroadcastScreen.debugChatFactory = (id, _) => _Chat(id);
      LiveBroadcastScreen.debugPresenceFactory = (id) => _Presence(id);
      AbstractVideoPlayer.debugPlayerFactory = ({
        Key? key,
        required StreamSourceType sourceType,
        required String streamUrl,
        bool autoPlay = true,
        VoidCallback? onPlayerReady,
        ValueChanged<StreamState>? onStateChanged,
        ValueChanged<String>? onError,
        double aspectRatio = 16 / 9,
        String preferredQuality = 'auto',
        List<String> fallbackUrls = const [],
        bool initialMuted = false,
      }) =>
          _Player(
              autoPlay: autoPlay,
              initialMuted: initialMuted,
              key: key,
              streamUrl: streamUrl,
              log: log,
              onStateChanged: onStateChanged,
              onPlayerReady: onPlayerReady);
    });
    tearDown(() {
      LiveBroadcastScreen.debugChatFactory = null;
      LiveBroadcastScreen.debugPresenceFactory = null;
      AbstractVideoPlayer.debugPlayerFactory = null;
    });

    final live = mockStreamers.first.copyWith(
      isCurrentlyLive: true,
      broadcastType: BroadcastType.liveVideo,
      activeStreamId: 'LIVEvideo01',
      youtubeVideoId: '',
      avatarUrl: '',
      bannerUrl: '',
    );

    Future<AppProvider> open(WidgetTester tester,
        {Size size = const Size(412, 915)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalog = roomCatalog = _Catalog();
      final provider = AppProvider.withServices(
          organizationBroadcastService: EmptyBroadcasts(),
          adminDbService: catalog);
      provider.addStreamer(live);
      await tester.pumpWidget(
          _app(provider, LiveBroadcastScreen(streamId: live.streamerId)));
      await tester.pump();
      catalog.pending.removeAt(0).complete([live]);
      await tester.pump();
      await tester.pump();
      return provider;
    }

    Future<void> showControls(WidgetTester tester) async {
      if (find.byKey(const Key('room-play-pause')).evaluate().isEmpty) {
        await tester.tapAt(tester.getCenter(find.byType(_Player)));
        await tester.pump();
      }
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
        'embedded controls receive taps when app transport is unavailable',
        (tester) async {
      log.transport = false;
      await open(tester);
      await tester.tapAt(tester.getCenter(find.byType(_Player)));
      await tester.pump();
      expect(log.playerTaps, 1);
      expect(find.byKey(const Key('room-play-pause')), findsNothing);
      await close(tester);
    });

    testWidgets('pause, play and mute are sent to the player', (tester) async {
      await open(tester);
      await tester.pump();
      await showControls(tester);
      await tester.tap(find.byKey(const Key('room-play-pause')));
      await tester.pump();
      expect(log.commands, ['pause']);
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('room-play-pause')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('room-mute')));
      await tester.pump();
      expect(log.commands, ['pause', 'play', 'mute']);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await close(tester);
    });

    testWidgets('a refused command leaves the shown state unchanged',
        (tester) async {
      log.refuse = true;
      await open(tester);
      await tester.pump();
      await showControls(tester);
      await tester.tap(find.byKey(const Key('room-play-pause')));
      await tester.pump();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget,
          reason: 'still playing: nothing was sent');
      expect(find.text('live.player_not_ready'.tr()), findsOneWidget,
          reason: 'the refusal is said, not silent');
      await close(tester);
    });

    testWidgets('a delivered command cannot invent a playback state',
        (tester) async {
      log.confirmCommands = false;
      await open(tester);
      await tester.pump();
      await showControls(tester);
      await tester.tap(find.byKey(const Key('room-play-pause')));
      await tester.pump();
      expect(log.commands, ['pause']);
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      log.emit?.call(StreamState.paused);
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await close(tester);
    });

    testWidgets('a player without commands shows no dead transport buttons',
        (tester) async {
      log.transport = false;
      await open(tester);
      await tester.pump();
      expect(find.byKey(const Key('room-play-pause')), findsNothing);
      expect(find.byKey(const Key('room-mute')), findsNothing);
      expect(find.byKey(const Key('room-fullscreen')), findsOneWidget,
          reason: 'fullscreen is a layout control, not a player command');
      await close(tester);
    });

    testWidgets('a muted viewer stays muted after Retry', (tester) async {
      await open(tester);
      await tester.pump();
      await showControls(tester);
      await tester.tap(find.byKey(const Key('room-mute')));
      await tester.pump();
      expect(log.commands, ['mute']);
      // The feed fails; the viewer retries, which makes a new player.
      log.emit!(StreamState.fallbackError);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('live.retry_feed'.tr()).hitTestable().first);
      await tester.pump(const Duration(seconds: 3));
      expect(log.created, 1, reason: 'fresh session truth must precede reload');
      roomCatalog.pending.removeAt(0).complete([live]);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(log.created, 2);
      expect(log.initialMuted, [false, true],
          reason: 'the new player starts muted');
      expect(log.commands, ['mute'], reason: 'one mute path only');
      await showControls(tester);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await close(tester);
    });

    testWidgets('media buttons are 48 dp with localized tooltips (ar, 360 px)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalog = _Catalog();
      final provider = AppProvider.withServices(
          organizationBroadcastService: EmptyBroadcasts(),
          adminDbService: catalog);
      provider.addStreamer(live);
      await tester.pumpWidget(_app(
          provider, LiveBroadcastScreen(streamId: live.streamerId),
          lang: 'ar'));
      await tester.pump();
      catalog.pending.removeAt(0).complete([live]);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await showControls(tester);
      for (final key in ['room-play-pause', 'room-mute', 'room-fullscreen']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
      expect(find.byTooltip('live.tooltip_pause'.tr()), findsOneWidget);
      expect(find.byTooltip('live.tooltip_mute'.tr()), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });

    testWidgets("a mute made with the player's own controls shows here",
        (tester) async {
      await open(tester);
      await tester.pump();
      await showControls(tester);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      log.muted!.value = true;
      await tester.pump();
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      expect(log.commands, isEmpty, reason: 'nothing was sent back');
      await close(tester);
    });

    testWidgets('taps while a command is in flight send nothing more',
        (tester) async {
      log.pauseGate = Completer<bool>();
      await open(tester);
      await tester.pump();
      await showControls(tester);
      await tester.tap(find.byKey(const Key('room-play-pause')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('room-play-pause')));
      await tester.tap(find.byKey(const Key('room-mute')));
      await tester.pump();
      expect(log.commands, ['pause']);
      log.pauseGate!.complete(true);
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await close(tester);
    });

    testWidgets('a pause from the player itself shows as paused',
        (tester) async {
      log.report = StreamState.paused;
      await open(tester);
      await tester.pump();
      await showControls(tester);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await close(tester);
    });

    testWidgets('rotation keeps the same player instance', (tester) async {
      await open(tester);
      expect(log.created, 1);
      tester.view.physicalSize = const Size(915, 412);
      await tester.pump();
      await tester.pump();
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pump();
      tester.view.physicalSize = const Size(412, 915);
      await tester.pump();
      expect(log.created, 1, reason: 'no restart on layout change');
      expect(log.disposed, 0);
      await close(tester);
    });

    testWidgets(
        'automatic recovery preserves paused mute intent and stops at End',
        (tester) async {
      await open(tester);
      await showControls(tester);
      await tester.tap(find.byKey(const Key('room-mute')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('room-play-pause')));
      await tester.pump();
      log.emit!(StreamState.fallbackError);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      log.report = StreamState.paused;
      roomCatalog.pending.removeAt(0).complete([live]);
      await tester.pump();
      await tester.pump();
      expect(log.autoplay, [true, false]);
      expect(log.initialMuted, [false, true]);
      await tester.pump(const Duration(seconds: 10));
      log.emit!(StreamState.fallbackError);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      roomCatalog.pending.removeAt(0).complete(
          [live.copyWith(isCurrentlyLive: false, activeStreamId: '')]);
      await tester.pump();
      await tester.pump();
      expect(log.created, 2);
      expect(find.byKey(const Key('live-room-ended')), findsOneWidget);
      await close(tester);
    });

    for (final state in [
      StreamState.live,
      StreamState.paused,
      StreamState.unconfirmed
    ]) {
      testWidgets('delayed $state cancels queued media reload', (tester) async {
        await open(tester);
        log.emit!(StreamState.fallbackError);
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        log.report = null;
        roomCatalog.pending.removeAt(0).complete([live]);
        await tester.pump();
        await tester.pump();
        expect(log.created, 2);
        await tester.pump(const Duration(seconds: 4));
        log.emit!(state);
        await tester.pump();
        await tester.pump(const Duration(seconds: 9));
        expect(roomCatalog.pending, isEmpty,
            reason: 'a queued retry must not reload a responding player');
        expect(log.created, 2);
        if (state == StreamState.unconfirmed) {
          expect(
              find.text('live.player_state_unconfirmed'.tr()), findsOneWidget);
        }
        await tester.pump(const Duration(seconds: 1));
        await close(tester);
      });
    }

    testWidgets('viewer recovery exhausts and late truth cannot restart player',
        (tester) async {
      final p = await open(tester);
      log.emit!(StreamState.fallbackError);
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.byKey(const Key('live-room-recovery-exhausted')),
          findsOneWidget);
      final read = p.loadVerifiedStreamersFromBackend();
      await tester.pump();
      var completed = false;
      read.then((_) => completed = true);
      for (var i = 0; i < 5 && !completed; i++) {
        final requests = List.of(roomCatalog.pending);
        roomCatalog.pending.clear();
        for (final request in requests) {
          request.complete([live]);
        }
        await tester.pump();
      }
      expect(completed, isTrue);
      expect(log.created, 1);
      expect(log.disposed, 1);
      await close(tester);
    });

    testWidgets('unconfirmed viewer controls toggle stays reachable',
        (tester) async {
      log.report = StreamState.unconfirmed;
      await open(tester);
      final button = find.byTooltip('live.toggle_player_controls'.tr());
      await tester.tap(button);
      await tester.pump();
      expect(find.byKey(const Key('room-fullscreen')), findsNothing);
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      expect(find.byKey(const Key('room-fullscreen')), findsOneWidget);
      await close(tester);
    });

    testWidgets('Retry loads a fresh player', (tester) async {
      log.report = StreamState.fallbackError;
      await open(tester);
      await tester.pump();
      expect(find.text('live.retry_feed'.tr()), findsWidgets);
      log.report = StreamState.live;
      await tester.tap(find.text('live.retry_feed'.tr()).hitTestable().first);
      await tester.pump(const Duration(seconds: 3));
      expect(log.created, 1, reason: 'fresh session truth must precede reload');
      roomCatalog.pending.removeAt(0).complete([live]);
      await tester.pump();
      await tester.pump();
      expect(log.created, 2);
      expect(log.disposed, 1);
      await close(tester);
    });
  });

  group('return shortcut', () {
    testWidgets('is an honest shortcut: no video, no dead mute button',
        (tester) async {
      final provider = AppProvider();
      provider.openMiniPlayer(
        videoId: 'abcdefghijk',
        title: 'Evening lecture',
        streamerName: 'C',
        streamId: 'c',
        isAudioOnly: false,
      );
      await tester.pumpWidget(_app(provider,
          const Scaffold(body: Stack(children: [FloatingStreamMiniPlayer()]))));
      await tester.pumpAndSettle();
      expect(find.text('live.return_to_broadcast'.tr()), findsOneWidget);
      expect(
          find.textContaining('live.return_chip_paused'.tr()), findsOneWidget);
      expect(
          find.byKey(const ValueKey('mini_player_mute_button')), findsNothing);
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.byKey(const ValueKey('mini_player_close_button')));
      await tester.pump();
      expect(provider.isMiniPlayerActive, isFalse);
    });
  });

  group('studio help', () {
    Future<void> show(WidgetTester tester, StudioMode mode,
        {String sender = 'obs_laptop', String lang = 'en'}) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(
          AppProvider(),
          Scaffold(
              body:
                  StreamerSetupGuideModal(mode: mode, externalSender: sender)),
          lang: lang));
      await tester.pumpAndSettle();
    }

    for (final (mode, sender, title) in [
      (StudioMode.obs, 'obs_laptop', 'live_guide.title_obs'),
      (StudioMode.obs, 'external_phone', 'live_guide.title_phone_app'),
      (StudioMode.phone, 'obs_laptop', 'live_guide.title_phone'),
      (StudioMode.local, 'obs_laptop', 'live_guide.title_local'),
    ]) {
      for (final lang in ['en', 'ar']) {
        testWidgets('$title ($lang) explains that mode and lays out',
            (tester) async {
          await show(tester, mode, sender: sender, lang: lang);
          expect(find.text(title.tr()), findsOneWidget);
          // The old quest carousel (pages, Next Quest) is gone.
          expect(find.byType(PageView), findsNothing);
          if (mode == StudioMode.phone) {
            expect(
                find.byKey(const Key('studio-guide-image-0')), findsOneWidget);
            await tester.tap(find.byKey(const Key('studio-guide-next')));
            await tester.pumpAndSettle();
            expect(
                find.byKey(const Key('studio-guide-image-1')), findsOneWidget);
            expect(
                find.ancestor(
                    of: find.byKey(const Key('studio-guide-image-1')),
                    matching: find.byWidgetPredicate((widget) =>
                        widget is ClipRRect &&
                        widget.borderRadius ==
                            BorderRadius.circular(AppTheme.radiusMd))),
                findsOneWidget);
          }
          expect(find.byKey(const Key('studio-guide-link-vs-key')),
              mode == StudioMode.local ? findsNothing : findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the phone-app help never calls the sender OBS',
        (tester) async {
      await show(tester, StudioMode.obs, sender: 'external_phone');
      for (var i = 1; i <= 4; i++) {
        expect('live_guide.phone_app_$i'.tr(), isNot(contains('OBS')));
      }
    });
  });
}
