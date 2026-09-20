import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/providers/app_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The YouTubeLiveService and startQuickPhoneBroadcast groups that used to
  // live here were deleted with the code they covered (P2 / 05 D-03): the
  // service never called YouTube -- it minted deterministic fake broadcast
  // ids, RTMP URLs and stream keys, and no production screen called it (the
  // Broadcaster Studio sheet has used the streamer's real, manually entered
  // stream key since v0.9, because a simulated key is rejected by YouTube's
  // real ingest). Real phone broadcasting is covered by
  // rtmp_publish_engine/phone broadcast tests.

  group('AppProvider: Broadcaster Studio meta (v0.9)', () {
    test(
        'TC-STUDIO-META-01: setCustomBroadcastMeta updates title/description/'
        'category without touching venue', () {
      final provider = AppProvider();
      final venueBefore = provider.customLiveVenue;

      provider.setCustomBroadcastMeta(
        title: 'New Title',
        description: 'New description text.',
        category: 'engineering_tech',
      );

      expect(provider.customLiveTitle, equals('New Title'));
      expect(provider.customLiveDescription, equals('New description text.'));
      expect(provider.customLiveCategory, equals('engineering_tech'));
      expect(provider.customLiveVenue, equals(venueBefore));
    });

    test(
        'TC-STUDIO-META-02: setCustomAudioOnlyPosterPath stores and clears '
        'the poster path', () {
      final provider = AppProvider();
      expect(provider.customAudioOnlyPosterPath, isNull);

      provider.setCustomAudioOnlyPosterPath('/tmp/poster.jpg');
      expect(provider.customAudioOnlyPosterPath, equals('/tmp/poster.jpg'));

      provider.setCustomAudioOnlyPosterPath(null);
      expect(provider.customAudioOnlyPosterPath, isNull);

      provider.setCustomAudioOnlyPosterPath('');
      expect(provider.customAudioOnlyPosterPath, isNull);
    });
  });
}
