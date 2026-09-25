// P6S wave 3, group 5: the page the YouTube adapter loads into the web view.
import 'package:flutter_test/flutter_test.dart';
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

  test('keeps asking the player to report until it answers', () {
    final html = page();
    expect(html, contains("event: 'listening'"));
    expect(html, contains('setTimeout(ping, 250)'));
    expect(html, contains('heardFromPlayer = true'));
  });

  test("forwards state, errors and the player's own mute to the app", () {
    final html = page();
    expect(html, contains("data.event === 'onStateChange'"));
    expect(html, contains("data.event === 'onError'"));
    expect(html, contains("data.event === 'infoDelivery'"));
    expect(html, contains("type: 'muted'"));
    expect(html, contains("type: 'ready'"));
  });
}
