import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/theme/app_theme.dart';
import 'package:streamer_app/core/widgets/consent_dialog.dart';
import 'package:streamer_app/core/widgets/device_session_conflict_dialog.dart';
import 'package:streamer_app/core/widgets/duplicate_channel_resolution_dialog.dart';
import 'package:streamer_app/features/auth/presentation/welcome_screen.dart';
import 'package:streamer_app/features/discovery/presentation/discovery_feed_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/live_broadcast_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/permission_rationale_dialog.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/rtmp_ip_dialog.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/streamer_setup_guide_modal.dart';
import 'package:streamer_app/features/map/presentation/widgets/venue_navigation_sheet.dart';
import 'package:streamer_app/features/admin/presentation/admin_hub_screen.dart';
import 'package:streamer_app/features/live_stream/presentation/screens/phone_broadcast_screen.dart';
import 'package:streamer_app/features/profile/presentation/broadcaster_profile_screen.dart';
import 'package:streamer_app/features/profile/presentation/settings_screen.dart';
import 'package:streamer_app/features/profile/presentation/widgets/org_speaker_inspection_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/playlist_viewer_modal_sheet.dart';
import 'package:streamer_app/features/profile/presentation/widgets/vod_player_modal_sheet.dart';
import 'fixtures/dialog_fixtures.dart';
import 'fixtures/streamer_fixtures.dart';
import 'support/stub_video_player.dart';
/// Rendered contrast, as opposed to the token pairs `theme_contrast_test`
/// pins.
///
/// `theme_contrast_test` proves the palette is sound. It cannot see a screen
/// that paints a sound colour onto the wrong surface, which is exactly what
/// the scheme A migration produced in several places: `onMedia` white text
/// left on a white dialog or sheet, invisible rather than merely low
/// contrast. This walks the real element tree, resolves each piece of text
/// against the background actually behind it, and fails below WCAG AA.
class _DirectJsonAssetLoader extends AssetLoader {
  final Map<String, dynamic> data;
  const _DirectJsonAssetLoader(this.data);
  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async =>
      data[locale.languageCode];
}
double _contrast(Color a, Color b) {
  final x = a.computeLuminance(), y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}
Color _composite(Color foreground, Color background) {
  final a = foreground.a;
  if (a >= 1.0) return foreground;
  return Color.from(
    alpha: 1.0,
    red: foreground.r * a + background.r * (1 - a),
    green: foreground.g * a + background.g * (1 - a),
    blue: foreground.b * a + background.b * (1 - a),
  );
}
/// What the ancestor walk found behind a piece of text.
class _Backdrop {
  final Color? color;
  /// A gradient or image was in the way, so a single colour cannot describe
  /// what is behind the text. Those are reported separately rather than
  /// guessed at.
  final bool indeterminate;
  const _Backdrop(this.color, {this.indeterminate = false});
}
/// The colour painted behind [element], compositing translucent layers onto
/// whatever is behind them.
_Backdrop _backdropOf(Element element) {
  final layers = <Color>[];
  var indeterminate = false;
  Color? layerOf(Widget w) {
    // A chip paints its own fill inside its render object: the Material in
    // its ancestor chain carries a null colour, so an ancestor walk would
    // report the surface behind the chip instead of the chip. Rather than
    // report that as a failure, chip labels are counted as unresolved.
    if (w is RawChip) {
      indeterminate = true;
      return null;
    }
    if (w is ColoredBox) return w.color;
    if (w is Material) return w.color;
    if (w is DecoratedBox) {
      final d = w.decoration;
      if (d is BoxDecoration) {
        if (d.gradient != null || d.image != null) {
          indeterminate = true;
          return null;
        }
        return d.color;
      }
      // Chips and similar Material components paint their fill through a
      // ShapeDecoration, not a BoxDecoration; without this a selected chip
      // reads as the white surface behind it.
      if (d is ShapeDecoration) {
        if (d.gradient != null || d.image != null) {
          indeterminate = true;
          return null;
        }
        return d.color;
      }
      return null;
    }
    return null;
  }
  element.visitAncestorElements((ancestor) {
    final color = layerOf(ancestor.widget);
    if (color != null && color.a > 0) {
      layers.add(color);
      // An opaque layer hides everything above it.
      if (color.a >= 1.0) return false;
    }
    if (indeterminate) return false;
    return true;
  });
  if (indeterminate && layers.isEmpty) return const _Backdrop(null, indeterminate: true);
  if (layers.isEmpty) return const _Backdrop(null);
  // Composite from the back forwards.
  var result = layers.last;
  for (var i = layers.length - 2; i >= 0; i--) {
    result = _composite(layers[i], result);
  }
  if (result.a < 1.0) {
    // Nothing opaque underneath: the scaffold is white in this theme.
    result = _composite(result, AppTheme.bg);
  }
  return _Backdrop(result);
}
class _Finding {
  final String text;
  final Color foreground;
  final Color background;
  final double ratio;
  _Finding(this.text, this.foreground, this.background, this.ratio);
  @override
  String toString() =>
      '"$text" ${_hex(foreground)} on ${_hex(background)} = ${ratio.toStringAsFixed(2)}:1';
}
String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalogs = <String, dynamic>{};
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final lang in ['en', 'ar']) {
      catalogs[lang] =
          jsonDecode(File('assets/i18n/$lang.json').readAsStringSync());
    }
    await EasyLocalization.ensureInitialized();
    EasyLocalization.logger.enableLevels = [];
    for (final entry in {
      'IBM Plex Sans': ['assets/fonts/IBMPlexSans-Variable.ttf'],
      'IBM Plex Sans Arabic': [
        'assets/fonts/IBMPlexSansArabic-400.ttf',
        'assets/fonts/IBMPlexSansArabic-700.ttf',
      ],
      'MaterialIcons': ['fonts/MaterialIcons-Regular.otf'],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }
  });
  final screens = <String, Widget Function()>{
    'welcome': () => const WelcomeScreen(),
    'feed': () => const DiscoveryFeedScreen(),
    'settings': () => const SettingsScreen(),
    'live room': () => const LiveBroadcastScreen(streamId: 'stream_live_992'),
    'phone broadcast': () => const PhoneBroadcastScreen(),
    'broadcaster profile': () =>
        BroadcasterProfileScreen(streamerId: mockStreamers.first.streamerId),
    'admin hub': () => const AdminHubScreen(),
    'consent dialog': () => const Scaffold(body: ConsentDialog()),
    'permission dialog': () => const Scaffold(
          body: PermissionRationaleDialog(kind: BroadcastPermissionKind.camera),
        ),
    'device conflict dialog': () => Scaffold(
          body: DeviceSessionConflictDialog(
            currentDevice: currentDeviceFixture,
            existingDevice: existingDeviceFixture,
          ),
        ),
    'duplicate channel dialog': () => Scaffold(
          body: DuplicateChannelResolutionDialog(
            duplicateChannels: mockStreamers
                .take(2)
                .map((s) => s.copyWith(avatarUrl: '', bannerUrl: ''))
                .toList(),
          ),
        ),
    'vod player sheet': () => Scaffold(
          body: VodPlayerModalSheet(
            vod: vodFixture(),
            streamer: mockStreamers.first.copyWith(avatarUrl: '', bannerUrl: ''),
          ),
        ),
    'playlist sheet': () => Scaffold(
          body: PlaylistViewerModalSheet(
            playlist: playlistFixture(),
            streamer: mockStreamers.first.copyWith(avatarUrl: '', bannerUrl: ''),
            langCode: 'en',
          ),
        ),
    'org speaker sheet': () => Scaffold(
          body: OrgSpeakerInspectionSheet(
            speaker: orgSpeakersFixture.first,
            orgName: 'جمعية دليلك التعليمية',
            speakerVods: speakerVodsFixture(),
          ),
        ),
    'venue navigation sheet': () => Scaffold(
          body: VenueNavigationSheet(
            streamer: mockStreamers.first.copyWith(avatarUrl: '', bannerUrl: ''),
          ),
        ),
    // UI-02/UI-03: these two sheets had the worst instance of the onMedia-
    // on-a-pale-surface bug in the whole app (invisible "Go Live" button,
    // invisible tutorial heading/icon) and neither was covered by this
    // rendered-contrast sweep before, so the regression shipped unnoticed.
    'broadcaster studio (OBS)': () =>
        const Scaffold(body: LiveBroadcasterStudioSheet()),
    'broadcaster studio (Phone)': () => const Scaffold(
          body: LiveBroadcasterStudioSheet(initialMode: StudioMode.phone),
        ),
    'broadcaster studio (Local)': () => const Scaffold(
          body: LiveBroadcasterStudioSheet(initialMode: StudioMode.local),
        ),
    'broadcaster tutorial (OBS)': () => const Scaffold(
          body: StreamerSetupGuideModal(mode: StudioMode.obs),
        ),
  };
  for (final entry in screens.entries) {
    for (final lang in ['en', 'ar']) {
      testWidgets('${entry.key} $lang keeps every label readable where it sits',
          (tester) async {
        StubVideoPlayer.install(addTearDown: addTearDown);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(412, 915);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final provider = AppProvider();
        if (entry.key == 'admin hub') {
          provider.debugSetSignedInForTests(
              email: 'admin@example.test', isMasterAdmin: true);
        }
        for (final streamer in mockStreamers) {
          provider.addStreamerForTests(streamer.copyWith(
            avatarUrl: '',
            bannerUrl: '',
            isCurrentlyLive: streamer.streamerId == mockStreamers.first.streamerId
                ? true
                : null,
            activeStreamId:
                streamer.streamerId == mockStreamers.first.streamerId
                    ? 'stream_live_992'
                    : null,
          ));
        }
        await tester.pumpWidget(EasyLocalization(
          supportedLocales: const [Locale('en'), Locale('ar')],
          path: 'assets/i18n',
          assetLoader: _DirectJsonAssetLoader(catalogs),
          startLocale: Locale(lang),
          saveLocale: false,
          child: Builder(
            builder: (context) => ChangeNotifierProvider.value(
              value: provider,
              child: MaterialApp(
                locale: context.locale,
                supportedLocales: context.supportedLocales,
                localizationsDelegates: context.localizationDelegates,
                theme: AppTheme.forLocale(Locale(lang)),
                home: entry.value(),
              ),
            ),
          ),
        ));
        await tester.pump(const Duration(milliseconds: 200));
        while (tester.takeException() != null) {}
        final findings = <_Finding>[];
        var checked = 0;
        var skipped = 0;
        for (final element in tester.elementList(find.byType(Text))) {
          final widget = element.widget as Text;
          final data = widget.data;
          // Spans carry their own per-span colours; only plain labels are
          // resolvable from the widget alone.
          if (data == null || data.trim().isEmpty) continue;
          final inherited = DefaultTextStyle.of(element).style;
          final style = widget.style;
          final color = style?.color ??
              (style?.inherit == false ? null : inherited.color) ??
              Theme.of(element).textTheme.bodyMedium?.color;
          if (color == null || color.a < 1.0) {
            skipped++;
            continue;
          }
          final backdrop = _backdropOf(element);
          if (backdrop.indeterminate || backdrop.color == null) {
            skipped++;
            continue;
          }
          checked++;
          final ratio = _contrast(color, backdrop.color!);
          if (ratio < 4.5) {
            findings.add(_Finding(
                data.length > 40 ? '${data.substring(0, 40)}...' : data,
                color,
                backdrop.color!,
                ratio));
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        provider.dispose();
        expect(checked, greaterThan(0),
            reason: '${entry.key} $lang resolved no text against a backdrop, '
                'so this assertion proves nothing');
        expect(findings, isEmpty,
            reason: '${entry.key} $lang: ${findings.length} of $checked '
                'resolved labels fall below 4.5:1 ($skipped unresolved)\n'
                '${findings.join("\n")}');
      });
    }
  }
}
