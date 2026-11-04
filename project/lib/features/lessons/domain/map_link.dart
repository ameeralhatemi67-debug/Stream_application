/// Reads a place out of what an admin copies from Google Maps: the address of a
/// place (any form of it), a shared short link, or two coordinates.
abstract final class MapLink {
  static const _number = r'(-?\d{1,3}(?:\.\d+)?)';

  /// The pin of a place inside a long Google address (`!3d<lat>!4d<lng>`).
  static final _pin = RegExp('!3d$_number!4d$_number');

  /// `?q=26.3,50.1`, `&ll=…`, `&destination=…`, `&center=…`.
  static final _param = RegExp('[?&](?:q|query|ll|sll|center|destination|daddr|markers)=$_number,\\s*$_number');

  /// `/@26.3,50.1,17z` — where the map is centred (the pin when nothing else says).
  static final _view = RegExp('@$_number,$_number');

  /// Two numbers and nothing else: `26.3, 50.1` or `(26.3 50.1)`.
  static final _plain = RegExp('^[(\\[]?\\s*$_number\\s*[,;\\s]\\s*$_number\\s*[)\\]]?\$');

  static final _url = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);

  /// Arabic digits and separators are what an Arabic keyboard or page gives.
  static String _normalise(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x0660 && r <= 0x0669) {
        b.writeCharCode(r - 0x0660 + 0x30);
      } else if (r >= 0x06F0 && r <= 0x06F9) {
        b.writeCharCode(r - 0x06F0 + 0x30);
      } else if (r == 0x066B) {
        b.write('.');
      } else if (r == 0x060C || r == 0x061B) {
        b.write(',');
      } else {
        b.writeCharCode(r);
      }
    }
    return b.toString();
  }

  static String _decode(String s) {
    try {
      return Uri.decodeComponent(s);
    } catch (_) {
      return s;
    }
  }

  static (double, double)? _valid(String a, String b) {
    final lat = double.tryParse(a), lng = double.tryParse(b);
    if (lat == null || lng == null) return null;
    if (lat.abs() > 90 || lng.abs() > 180 || (lat == 0 && lng == 0)) return null;
    double r6(double v) => double.parse(v.toStringAsFixed(6));
    return (r6(lat), r6(lng));
  }

  /// The place in [input], or null when there is none to read.
  static (double, double)? parse(String input) {
    final text = _decode(_normalise(input.trim()));
    if (text.isEmpty) return null;
    for (final re in [_pin, _param, _view, _plain]) {
      for (final m in re.allMatches(text)) {
        final p = _valid(m.group(1)!, m.group(2)!);
        if (p != null) return p;
      }
    }
    return null;
  }

  /// The first web address in [input] (a shared message has the place name
  /// around it).
  static Uri? firstUrl(String input) {
    final m = _url.firstMatch(input);
    return m == null ? null : Uri.tryParse(m.group(0)!.replaceAll(RegExp(r'[).,،]+$'), ''));
  }

  /// A short link (`maps.app.goo.gl/…`) holds no place by itself: the server
  /// has to follow it.
  static bool isShort(String input) {
    final u = firstUrl(input);
    if (u == null) return false;
    final h = u.host.toLowerCase();
    return h == 'maps.app.goo.gl' ||
        (h == 'goo.gl' && u.path.startsWith('/maps')) ||
        (h == 'g.co' && u.path.startsWith('/kgs')) ||
        h == 'share.google';
  }
}
