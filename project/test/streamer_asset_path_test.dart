import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/core/services/streamer_asset_path.dart';

void main() {
  const owner = '10000000-0000-4000-8000-000000000001';
  test('upload input cannot escape the authenticated namespace', () {
    for (final folder in [
      'applications',
      '../../victim',
      '/org/victim',
      r'..\victim'
    ]) {
      final path = streamerAssetPath(
        userId: owner,
        folder: folder,
        fileName: '../../banner.png',
        timestamp: 42,
      );
      expect(path.split('/').first, owner);
      expect(path.split('/'), hasLength(3));
      expect(path.split('/'), isNot(contains('..')));
    }
  });
  test('missing or path-shaped identities fail closed', () {
    for (final id in ['', '../victim', '$owner/other']) {
      expect(
        () => streamerAssetPath(
            userId: id, folder: 'avatars', fileName: 'a.png', timestamp: 1),
        throwsArgumentError,
      );
    }
  });
}
