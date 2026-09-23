import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Platform switches held in `public.app_flags` (20260923120000). Anyone may
/// read them; only a Master Admin with a live session may change one, through
/// `admin_set_app_flag`, which also writes the audit record. The database
/// enforces each switch on its own (chat inserts, Auth user inserts), so these
/// values only decide what the app explains, never what it allows.
enum AppFlagKey {
  chatEnabled('chat_enabled'),
  registrationsOpen('registrations_open');

  const AppFlagKey(this.column);
  final String column;
}

enum AppFlagsStatus { unknown, loaded, failed }

enum AppFlagFailure { notPermitted, invalid, network }

class AppFlagException implements Exception {
  const AppFlagException(this.failure);
  final AppFlagFailure failure;
  @override
  String toString() => 'AppFlagException($failure)';
}

abstract class AppFlagsStore {
  Future<Map<String, ({bool enabled, DateTime? updatedAt})>> fetch();
  Future<void> set(String key, bool enabled, String reason);
}

class SupabaseAppFlagsStore implements AppFlagsStore {
  const SupabaseAppFlagsStore();

  @override
  Future<Map<String, ({bool enabled, DateTime? updatedAt})>> fetch() async {
    final rows = await Supabase.instance.client
        .from('app_flags')
        .select('key, enabled, updated_at');
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['key'] as String: (
          enabled: r['enabled'] as bool,
          updatedAt: DateTime.tryParse('${r['updated_at']}'),
        ),
    };
  }

  @override
  Future<void> set(String key, bool enabled, String reason) async {
    await Supabase.instance.client.rpc('admin_set_app_flag', params: {
      'p_key': key,
      'p_enabled': enabled,
      'p_reason': reason,
    });
  }
}

class AppFlags extends ChangeNotifier {
  AppFlags({AppFlagsStore? store})
      : _store = store ?? const SupabaseAppFlagsStore();

  static final AppFlags instance = AppFlags();

  final AppFlagsStore _store;
  Map<String, ({bool enabled, DateTime? updatedAt})> _values = const {};
  AppFlagsStatus _status = AppFlagsStatus.unknown;
  Future<void>? _inFlight;

  AppFlagsStatus get status => _status;

  /// An unread switch counts as on: the server refuses anything that is
  /// really off, so a failed read must not lock people out of the app.
  bool isEnabled(AppFlagKey key) => _values[key.column]?.enabled ?? true;
  bool get chatEnabled => isEnabled(AppFlagKey.chatEnabled);
  bool get registrationsOpen => isEnabled(AppFlagKey.registrationsOpen);

  /// Whether the server has confirmed a value for [key].
  bool isKnown(AppFlagKey key) => _values.containsKey(key.column);
  DateTime? updatedAt(AppFlagKey key) => _values[key.column]?.updatedAt;

  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
    try {
      _values = await _store.fetch();
      _status = AppFlagsStatus.loaded;
    } catch (e) {
      debugPrint('AppFlags: refresh failed: $e');
      _status = AppFlagsStatus.failed;
    }
    notifyListeners();
  }

  /// Changes a switch through the audited RPC, then re-reads the table so the
  /// shown value is the server's, not the one that was asked for.
  Future<void> setFlag(AppFlagKey key, bool enabled, String reason) async {
    final trimmed = reason.trim();
    if (trimmed.isEmpty || trimmed.length > 500) {
      throw const AppFlagException(AppFlagFailure.invalid);
    }
    try {
      await _store.set(key.column, enabled, trimmed);
    } on PostgrestException catch (e) {
      throw AppFlagException(switch (e.code) {
        '42501' => AppFlagFailure.notPermitted,
        '22023' => AppFlagFailure.invalid,
        _ => AppFlagFailure.network,
      });
    } catch (_) {
      throw const AppFlagException(AppFlagFailure.network);
    }
    await refresh();
  }

  @visibleForTesting
  void debugSetValues(Map<AppFlagKey, bool> values) {
    _values = {
      for (final e in values.entries)
        e.key.column: (enabled: e.value, updatedAt: null),
    };
    _status = AppFlagsStatus.loaded;
    notifyListeners();
  }

  @visibleForTesting
  void debugReset() {
    _values = const {};
    _status = AppFlagsStatus.unknown;
    _inFlight = null;
    notifyListeners();
  }
}
