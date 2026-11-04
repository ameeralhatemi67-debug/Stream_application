import 'package:flutter_test/flutter_test.dart';
import 'package:streamer_app/features/lessons/domain/map_link.dart';

void main() {
  group('MapLink.parse', () {
    test('a long Google address: the pin wins over the map centre', () {
      const url =
          'https://www.google.com/maps/place/Masjid/@26.2900,50.2100,17z/data=!3m1!4b1!4m6!3m5!1s0x3e49:0x1!8m2!3d26.291234!4d50.205678!16s%2Fg%2F1';
      expect(MapLink.parse(url), (26.291234, 50.205678));
    });

    test('a place address with only the map centre', () {
      expect(MapLink.parse('https://www.google.com/maps/@26.35,50.12,15z'), (26.35, 50.12));
    });

    test('query forms', () {
      expect(MapLink.parse('https://www.google.com/maps/search/?api=1&query=26.3%2C50.1'), (26.3, 50.1));
      expect(MapLink.parse('https://maps.google.com/?q=26.3,50.1&z=16'), (26.3, 50.1));
      expect(MapLink.parse('https://www.google.com/maps?ll=26.3,50.1'), (26.3, 50.1));
    });

    test('a shared message with the name around the link', () {
      expect(MapLink.parse('جامع الراجحي\nhttps://www.google.com/maps/place/x/@26.3,50.1,17z'), (26.3, 50.1));
    });

    test('plain coordinates, as Google copies them on a right-click', () {
      expect(MapLink.parse('26.291234, 50.205678'), (26.291234, 50.205678));
      expect(MapLink.parse('26.291234 50.205678'), (26.291234, 50.205678));
      expect(MapLink.parse('(26.29, 50.2)'), (26.29, 50.2));
    });

    test('Arabic digits and commas', () {
      expect(MapLink.parse('٢٦٫٢٩١٢٣٤، ٥٠٫٢٠٥٦٧٨'), (26.291234, 50.205678));
    });

    test('nothing to read', () {
      expect(MapLink.parse(''), isNull);
      expect(MapLink.parse('جامع الراجحي'), isNull);
      expect(MapLink.parse('https://maps.app.goo.gl/abc123'), isNull);
      expect(MapLink.parse('126.5, 50.2'), isNull);
      expect(MapLink.parse('26.3, 250.2'), isNull);
      expect(MapLink.parse('0, 0'), isNull);
    });
  });

  group('MapLink.isShort', () {
    test('short links', () {
      expect(MapLink.isShort('https://maps.app.goo.gl/AbC123'), isTrue);
      expect(MapLink.isShort('الراجحي https://maps.app.goo.gl/AbC123.'), isTrue);
      expect(MapLink.isShort('https://goo.gl/maps/AbC123'), isTrue);
    });

    test('long links and text are not', () {
      expect(MapLink.isShort('https://www.google.com/maps/place/x/@26.3,50.1,17z'), isFalse);
      expect(MapLink.isShort('26.3, 50.1'), isFalse);
      expect(MapLink.isShort(''), isFalse);
    });
  });
}
