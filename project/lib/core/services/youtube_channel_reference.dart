/// Syntactic channel reference, never proof of ownership or existence.
class YouTubeChannelReference {
  const YouTubeChannelReference(this.parameter, this.value);
  final String parameter;
  final String value;
  String get url => Uri.https(
          'www.youtube.com',
          switch (parameter) {
            'id' => '/channel/$value',
            'forUsername' => '/user/$value',
            'custom' => '/c/$value',
            _ => '/@$value',
          })
      .toString();
  String get stored =>
      parameter == 'forHandle' || parameter == 'id' ? value : url;
  bool sameAs(YouTubeChannelReference other) =>
      parameter == other.parameter &&
      (parameter == 'id'
          ? value == other.value
          : value.toLowerCase() == other.value.toLowerCase());

  static YouTubeChannelReference? parse(String input,
      {bool requireUrl = false}) {
    var text = input.trim();
    if (text.isEmpty) return null;
    var parameter = 'forHandle';
    var value = text;
    final looksUrl = text.contains('/') || text.contains('://');
    if (looksUrl || requireUrl) {
      if (!text.contains('://')) text = 'https://$text';
      final uri = Uri.tryParse(text);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          !{'youtube.com', 'www.youtube.com', 'm.youtube.com'}
              .contains(uri.host.toLowerCase()) ||
          uri.userInfo.isNotEmpty ||
          uri.hasPort) {
        return null;
      }
      final parts = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      if (parts.isEmpty) return null;
      if (parts.first.startsWith('@')) {
        value = parts.removeAt(0).substring(1);
      } else if (parts.length >= 2 &&
          {'channel', 'user', 'c'}.contains(parts.first)) {
        parameter = {
          'channel': 'id',
          'user': 'forUsername',
          'c': 'custom'
        }[parts.removeAt(0)]!;
        value = parts.removeAt(0);
      } else {
        return null;
      }
      if (parts.length > 1 ||
          (parts.isNotEmpty &&
              !{'videos', 'featured', 'playlists', 'streams', 'shorts', 'about'}
                  .contains(parts.single))) {
        return null;
      }
    } else {
      value = value.replaceFirst(RegExp(r'^@'), '');
      if (!input.trim().startsWith('@') &&
          RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(value)) {
        parameter = 'id';
      }
    }
    if (parameter == 'id') {
      if (!RegExp(r'^UC[A-Za-z0-9_-]{22}$').hasMatch(value)) return null;
    } else if (value.runes.isEmpty ||
        value.runes.length > 100 ||
        !RegExp(r'^[\p{L}\p{M}\p{N}._\-·]+$', unicode: true).hasMatch(value)) {
      return null;
    }
    return YouTubeChannelReference(parameter, value);
  }

  /// An early correction path, shared by both forms and the save boundary.
  static String? pairError(String url, String handle) {
    final a = parse(url, requireUrl: true);
    final b = parse(handle);
    if (a == null || b == null) return 'live.channel_invalid';
    if (a.parameter == 'custom' || b.parameter == 'custom') {
      return 'live.channel_custom';
    }
    if (a.parameter == b.parameter && !a.sameAs(b)) {
      return 'live.channel_mismatch';
    }
    return null;
  }
}
