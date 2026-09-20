import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/live_stream/presentation/adapters/youtube_navigation_policy.dart';

void main() {
  test('YouTube embeds and the initial blank document remain navigable', () {
    for (final url in ['about:blank', 'https://www.youtube-nocookie.com/embed/abcdefghijk',
      'https://youtube.com/watch?v=abcdefghijk', 'https://m.youtube.com/']) {
      expect(isAllowedYouTubeNavigation(url), isTrue, reason: url);
    }
  });
  test('External hosts, impersonation and active URL schemes are blocked', () {
    for (final url in ['https://youtube.com.attacker.invalid/', 'https://notyoutube.com/',
      'https://youtube.com@attacker.invalid/', 'http://youtube.com/',
      'javascript:alert(1)', 'data:text/html,test', 'file:///tmp/test',
      'intent://youtube.com/', 'https://attacker.invalid/']) {
      expect(isAllowedYouTubeNavigation(url), isFalse, reason: url);
    }
  });
}
