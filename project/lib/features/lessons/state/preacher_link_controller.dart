import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/lessons_repository.dart';
import '../domain/lessons_models.dart';

/// A preacher's page, opened from the link an admin sent him. He needs no
/// account: the link's key and this phone's id are checked by the server on
/// every call (a one-time link binds to the first phone that opens it).
class PreacherLinkController extends ChangeNotifier {
  PreacherLinkController(this.repository, this.token);

  final LessonsRepository repository;
  final String token;

  /// Kept on this phone so a one-time link keeps working here.
  static const deviceKey = 'preacher_link_device';

  /// The last link that opened on this phone, for Settings to offer again.
  static const lastLinkKey = 'preacher_link_token';

  PreacherLinkView? view;
  LessonsException? failure;
  bool loading = false;
  String? _device;
  bool _disposed = false;

  /// This phone's id: 32 random hex characters, made once.
  static Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(deviceKey);
    if (id == null || id.length < 16) {
      final r = math.Random.secure();
      id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await prefs.setString(deviceKey, id);
    }
    return id;
  }

  /// The link this phone opened last, if any.
  static Future<String?> lastLink() async => (await SharedPreferences.getInstance()).getString(lastLinkKey);

  Future<void> open() async {
    loading = true;
    _notify();
    try {
      _device ??= await deviceId();
      view = await repository.openLink(token, _device!);
      failure = null;
      await (await SharedPreferences.getInstance()).setString(lastLinkKey, token);
    } on LessonsException catch (e) {
      failure = e;
      view = null;
      if (e.failure == LessonsFailure.expired) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(lastLinkKey) == token) await prefs.remove(lastLinkKey);
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Sends card changes for an admin to approve.
  Future<void> proposeCardEdit(Map<String, dynamic> changes) => _write(() => repository.proposeCardEdit(token, _device!, changes));

  /// Requests a lesson or a weekly series. An admin approves it and chooses
  /// the mosque.
  Future<String> requestLesson(LessonRequestDraft draft) => _write(() => repository.requestLesson(token, _device!, draft));

  Future<void> withdraw(String requestId) => _write(() => repository.withdrawRequest(token, _device!, requestId));

  Future<T> _write<T>(Future<T> Function() call) async {
    _device ??= await deviceId();
    final r = await call();
    await open();
    return r;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
