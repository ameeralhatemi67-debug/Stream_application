/// Every upload starts in the authenticated user's storage namespace.
String streamerAssetPath({
  required String userId,
  required String folder,
  required String fileName,
  required int timestamp,
}) {
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(userId)) {
    throw ArgumentError.value(
        userId, 'userId', 'Expected an authenticated UUID');
  }
  final safeFolder = folder.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final safeName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return '${userId.toLowerCase()}/$safeFolder/${timestamp}_$safeName';
}
