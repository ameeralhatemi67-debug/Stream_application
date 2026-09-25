// P6S wave 3, group 5: the page the YouTube adapter loads into the web view.
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:streamer_app/features/live_stream/presentation/adapters/youtube_player_adapter.dart';

void main() {
  String page({bool muted = false}) => buildYouTubeEmbedHtml(
      videoId: 'abcdefghijk', autoPlay: true, muted: muted);

  test('embeds exactly the given watch ID on youtube-nocookie (ADR-006)', () {
    final html = page();
    expect(
        html, contains('https://www.youtube-nocookie.com/embed/abcdefghijk?'));
    expect(html, contains('enablejsapi=1'));
    expect(html, contains('origin=https://www.youtube-nocookie.com'));
    expect(html, contains('referrerpolicy="strict-origin-when-cross-origin"'));
    expect(html, isNot(contains('M7lc1UVf-VE')));
  });

  test('a muted viewer gets a muted embed from the start', () {
    expect(page(muted: true), contains('mute=1'));
    expect(page(), contains('mute=0'));
  });

  test('uses the official ready handshake instead of a raw message listener',
      () {
    final html = page();
    expect(html, contains('https://www.youtube.com/iframe_api'));
    expect(html, contains("new YT.Player('youtube-player'"));
    expect(html, isNot(contains("addEventListener('message'")));
    final export = Platform.environment['P6S_EMBED_EXPORT'];
    if (export != null) File(export).writeAsStringSync(page(muted: true));
  });

  test("forwards state, errors and the player's own mute to the app", () {
    final html = page();
    expect(html, contains('onStateChange: function(event)'));
    expect(html, contains('onError: function(event)'));
    expect(html, contains('player.isMuted()'));
    expect(html, contains('event.target === player'));
    expect(html, contains("type: 'muted'"));
    expect(html, contains("type: 'ready'"));
  });
}
