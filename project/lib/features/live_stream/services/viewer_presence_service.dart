import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/admin_database_service.dart';

/// Reports this device as one viewer of a live stream, and polls the real
/// audience size back (P3 / 05 D-08).
///
/// The contract, deliberately narrow:
/// * a heartbeat goes out every 20 s, and **only** while the player is on
///   screen and the app is in the foreground -- a backgrounded app is not
///   watching anything;
/// * the count shown is whatever the server counted in the last 45 s;
/// * [count] is null until the first successful read, and the UI renders "—"
///   for it. An unknown count is never rendered as 0 or as a made-up number;
/// * the viewer key is the signed-in user id (resolved server-side) or a
///   per-install UUID, so one person is one viewer.
///
/// The service owns no widgets and no BuildContext: a screen creates it,
/// calls [start], and disposes it.
class ViewerPresenceService extends ChangeNotifier with WidgetsBindingObserver {
  ViewerPresenceService({
    required this.streamId,
    AdminDatabaseService? database,
  }) : _database = database;

  /// The stream being watched -- the same id `set_live_state` published.
  final String streamId;

  static const Duration heartbeatInterval = Duration(seconds: 20);
  static const Duration countPollInterval = Duration(seconds: 15);
  static const String _installKeyPrefsKey = 'viewer_install_key';

  AdminDatabaseService? _database;
  Timer? _heartbeatTimer;
  Timer? _countTimer;
  String? _viewerKey;
  bool _isVisible = false;
  bool _isForeground = true;
  bool _disposed = false;

  int? _count;

  /// Live viewers, or null while it is not known yet (first poll pending,
  /// offline, or the stream is not live). The UI shows "—" for null.
  int? get count => _count;

  bool get isRunning => _heartbeatTimer != null;

  /// Starts reporting and polling. Safe to call more than once.
  Future<void> start() async {
    if (_disposed || _isVisible) return;
    _isVisible = true;
    WidgetsBinding.instance.addObserver(this);
    _database ??= await AdminDatabaseService.create();
    _viewerKey ??= await _resolveViewerKey();
    if (_disposed) return;
    await _tick();
    _restartTimers();
  }

  /// Stops reporting. The last known count is kept so a returning viewer does
  /// not see the number flicker to "—".
  void stop() {
    _isVisible = false;
    _cancelTimers();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _isForeground) return;
    _isForeground = foreground;
    if (_isForeground && _isVisible) {
      unawaited(_tick());
      _restartTimers();
    } else {
      // Backgrounded: stop claiming to be watching. The server forgets this
      // viewer 45 s later without any further call.
      _cancelTimers();
    }
  }

  void _restartTimers() {
    _cancelTimers();
    if (!_isVisible || !_isForeground || _disposed) return;
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) => _heartbeat());
    _countTimer = Timer.periodic(countPollInterval, (_) => _refreshCount());
  }

  void _cancelTimers() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _countTimer?.cancel();
    _countTimer = null;
  }

  Future<void> _tick() async {
    await _heartbeat();
    await _refreshCount();
  }

  Future<void> _heartbeat() async {
    final key = _viewerKey;
    final db = _database;
    if (key == null || db == null || streamId.isEmpty) return;
    await db.viewerHeartbeat(streamId: streamId, viewerKey: key);
  }

  Future<void> _refreshCount() async {
    final db = _database;
    if (db == null || streamId.isEmpty) return;
    final counts = await db.fetchViewerCounts([streamId]);
    if (_disposed) return;
    final value = counts[streamId];
    if (value == null || value == _count) return;
    _count = value;
    notifyListeners();
  }

  /// Signed-in viewers are keyed server-side by their user id; this key only
  /// matters for guests, and must be stable for the install so re-opening the
  /// room does not count the same guest twice.
  Future<String> _resolveViewerKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_installKeyPrefsKey);
      if (existing != null && existing.length >= 8) return existing;
      final generated = _generateInstallKey();
      await prefs.setString(_installKeyPrefsKey, generated);
      return generated;
    } catch (e) {
      debugPrint('ViewerPresenceService: install key unavailable: $e');
      return _generateInstallKey();
    }
  }

  static String _generateInstallKey() {
    final random = Random.secure();
    final bytes =
        List<int>.generate(16, (_) => random.nextInt(256)).map((b) => b.toRadixString(16).padLeft(2, '0'));
    return 'guest-${bytes.join()}';
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
