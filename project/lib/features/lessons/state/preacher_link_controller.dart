import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/lessons_repository.dart';
import '../domain/lessons_models.dart';

/// A preacher's page. Opened from the link an admin sent him, he needs no
/// account: the link's key and this phone's id are checked by the server on
/// every call (a one-time link binds to the first phone that opens it).
/// Without a [token] it is the page of the preacher card linked to the
/// signed-in account (a preacher who applied, ADR-020).
class PreacherLinkController extends ChangeNotifier {
  PreacherLinkController(this.repository, this.token);

  final LessonsRepository repository;
  final String? token;
  bool get viaAccount => token == null;

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
      final t = token;
      if (t == null) {
        view = await repository.openMyPage();
      } else {
        _device ??= await deviceId();
        view = await repository.openLink(t, _device!);
        await (await SharedPreferences.getInstance()).setString(lastLinkKey, t);
      }
      failure = null;
    } on LessonsException catch (e) {
      failure = e;
      view = null;
      if (e.failure == LessonsFailure.expired && token != null) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getString(lastLinkKey) == token) await prefs.remove(lastLinkKey);
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Sends card changes for an admin to approve.
  Future<void> proposeCardEdit(Map<String, dynamic> changes) => _write(() => token == null
      ? repository.proposeMyCardEdit(changes)
      : repository.proposeCardEdit(token!, _device!, changes));

  /// Requests a lesson or a weekly series at the mosque he suggests (or
  /// none). An admin approves it and confirms or chooses the mosque.
  Future<String> requestLesson(LessonRequestDraft draft) => _write(() => token == null
      ? repository.requestMyLesson(draft)
      : repository.requestLesson(token!, _device!, draft));

  Future<void> withdraw(String requestId) => _write(() => token == null
      ? repository.withdrawMyRequest(requestId)
      : repository.withdrawRequest(token!, _device!, requestId));

  Future<T> _write<T>(Future<T> Function() call) async {
    if (token != null) _device ??= await deviceId();
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
