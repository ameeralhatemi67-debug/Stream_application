/// Lessons links from before 2026-10-22 began with /taysir. They still open:
/// /taysir → /lessons, /taysir/lessons → /lessons/calendar,
/// /taysir/lessons/<id> → /lessons/lesson/<id>, anything else keeps its tail.
String? legacyLessonsLocation(Uri uri) {
  final path = uri.path;
  if (path != '/taysir' && !path.startsWith('/taysir/')) return null;
  var rest = path.substring('/taysir'.length);
  if (rest.startsWith('/lessons/')) {
    rest = '/lesson/${rest.substring('/lessons/'.length)}';
  } else if (rest == '/lessons') {
    rest = '/calendar';
  }
  return Uri(path: '/lessons$rest', query: uri.hasQuery ? uri.query : null)
      .toString();
}
