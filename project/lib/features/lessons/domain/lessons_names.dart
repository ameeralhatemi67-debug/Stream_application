import 'lessons_models.dart';
import 'lessons_vocab.dart';

/// The cities, topics, languages and audiences as the database holds them
/// (admins add more), for the label functions and lists that have no
/// controller at hand. [LessonsController] feeds it after every load; before
/// that, and in sample data, it is the built-in vocabulary.
abstract final class LessonsNames {
  static Map<String, City> _cities = const {};
  static List<LessonOption> _options = const [];

  static void update(LessonsCatalog c) {
    if (c.cities.isNotEmpty) _cities = c.cities;
    if (c.options.isNotEmpty) _options = c.options.values.toList();
  }

  /// Tests start from the built-in vocabulary.
  static void reset() {
    _cities = const {};
    _options = const [];
  }

  /// City ids in order, "other" last.
  static List<String> get cityIds {
    if (_cities.isEmpty) return LessonsVocab.cities;
    final all = _cities.values.toList()..sort((a, b) => a.sort.compareTo(b.sort));
    return [for (final c in all) c.id];
  }

  static City? city(String id) => _cities[id];

  /// Where to centre a city: the stored centre, else the built-in one.
  static (double, double)? centre(String id) {
    final c = _cities[id];
    if (c != null && c.hasPin) return (c.latitude!, c.longitude!);
    return LessonsVocab.cityCentre[id];
  }

  static List<String> _codes(String kind, List<String> builtIn) {
    if (_options.isEmpty) return builtIn;
    final all = _options.where((o) => o.kind == kind && o.permanent).toList()..sort((a, b) => a.sort.compareTo(b.sort));
    return [for (final o in all) o.code];
  }

  /// What the pickers offer: the built-ins and the options kept for later.
  static List<String> get topics => _codes('topic', LessonsVocab.topics);
  static List<String> get languages => _codes('language', LessonsVocab.languages);
  static List<String> get audiences => _codes('audience', LessonsVocab.audiences);

  /// The name an admin typed for an option that is not built in, else null.
  static String? customOption(String kind, String code, String lang) {
    for (final o in _options) {
      if (o.kind == kind && o.code == code) return o.builtIn ? null : o.name(lang);
    }
    return null;
  }

  /// The name of a city that is not built in, else null.
  static String? customCity(String id, String lang) {
    if (LessonsVocab.cities.contains(id)) return null;
    return _cities[id]?.name(lang);
  }
}
