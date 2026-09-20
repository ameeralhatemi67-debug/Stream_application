bool isAllowedYouTubeNavigation(String url) {
  if (url == 'about:blank') return true;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return false;
  return ['youtube.com', 'youtube-nocookie.com'].any(
    (host) => uri.host == host || uri.host.endsWith('.$host'),
  );
}
