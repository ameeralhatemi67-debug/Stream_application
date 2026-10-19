import 'package:web/web.dart' as web;

/// The browser tab icon follows the palette: the gold mark on the night tile
/// for Hidayah Gold, the site's own favicon otherwise.
void setBrowserIcon(bool hidayah) {
  final href =
      hidayah ? 'assets/assets/logo/hidayah_icon_192.png' : 'favicon.png';
  final links = web.document.querySelectorAll('link[rel="icon"]');
  for (var i = 0; i < links.length; i++) {
    (links.item(i)! as web.HTMLLinkElement).href = href;
  }
}
