import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/demo_lessons_repository.dart';
import '../data/lessons_repository.dart';
import '../domain/lessons_dates.dart';
import '../domain/lessons_models.dart';
import '../domain/lessons_rules.dart';

/// Lessons's client state: the public catalogue, the signed-in account's own
/// data and roles, and (for admins) the preacher list, waiting changes,
/// reports and log.
///
/// A standalone controller, not part of AppProvider (see CLAUDE.md: feature
/// state lives with its feature). Every write goes to the repository and is
/// followed by a reload, so the screens always show what the server holds.
class LessonsController extends ChangeNotifier {
  LessonsController(this.repository);

  final LessonsRepository repository;

  LessonsCatalog catalog = const LessonsCatalog();
  LessonsMine mine = const LessonsMine();
  LessonsRoles roles = LessonsRoles.guest;
  LessonsAdminData admin = const LessonsAdminData();

  bool loading = false;
  bool loaded = false;
  LessonsFailure? failure;
  String? _userId;
  bool _disposed = false;
  Future<void>? _inFlight;

  bool get isDemo => repository.isDemo;
  bool get signedIn => repository.currentUserId != null;
  DateTime get today => lessonsToday();

  // ------------------------------------------------------------- loading
  /// Loads once; later calls reuse the result until [refresh].
  Future<void> ensureLoaded() => loaded ? Future.value() : refresh();

  Future<void> refresh() => _inFlight ??= _load().whenComplete(() => _inFlight = null);

  Future<void> _load() async {
    loading = true;
    // Loads start while widgets build (a page's first build, the provider's
    // account update), so listeners hear about it after that frame.
    scheduleMicrotask(_notify);
    try {
      final r = await Future.wait<Object>([repository.loadCatalog(), repository.loadRoles(), repository.loadMine()]);
      catalog = r[0] as LessonsCatalog;
      roles = r[1] as LessonsRoles;
      mine = r[2] as LessonsMine;
      admin = roles.admin ? await repository.loadAdmin() : const LessonsAdminData();
      _userId = repository.currentUserId;
      failure = null;
      loaded = true;
      unawaited(_realignReminders());
    } on LessonsException catch (e) {
      failure = e.failure;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// The server sends a reminder at its stored time, but only this app knows
  /// the prayer times, so a lesson an admin moved keeps its reminders at the
  /// old time. Each load puts them on the lesson's current time; the server
  /// makes a moved reminder due again (20261028133020).
  Future<void> _realignReminders() async {
    if (!signedIn || isDemo) return;
    final now = DateTime.now();
    for (final r in mine.reminders.values) {
      final l = catalog.lessons[r.lessonId];
      if (l == null || l.status != 'approved') continue;
      final due = reminderInstant(l, r.lead, catalog);
      if (due.difference(r.remindAt).abs() < const Duration(minutes: 1) ||
          due.isBefore(now)) {
        continue;
      }
      try {
        await repository.setReminder(l.id, r.lead, due);
      } catch (e) {
        debugPrint('Lesson reminder realign failed: $e');
      }
    }
  }

  /// Sign-in, sign-out and account switches change what the server shows.
  void onAccountChanged(String? userId) {
    if (!loaded || userId == _userId) return;
    admin = const LessonsAdminData();
    unawaited(refresh());
  }

  /// Sample data only: view the programme as another role.
  void setDemoPersona(LessonsDemoPersona persona) {
    final repo = repository;
    if (repo is! DemoLessonsRepository) return;
    repo.persona = persona;
    admin = const LessonsAdminData();
    unawaited(refresh());
  }

  LessonsDemoPersona? get demoPersona =>
      repository is DemoLessonsRepository ? (repository as DemoLessonsRepository).persona : null;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Runs a write, then reloads. Errors reach the caller as [LessonsException].
  Future<T> _write<T>(Future<T> Function() call) async {
    final result = await call();
    await refresh();
    return result;
  }

  // ----------------------------------------------------------- selectors
  Mosque? mosque(String? id) => catalog.mosques[id];
  Preacher? preacher(String? id) => catalog.preachers[id];
  District? district(String? id) => catalog.districts[id];
  LessonSeries? seriesOf(String? id) => id == null ? null : catalog.series[id];
  Lesson? lesson(String id) => catalog.lessons[id];
  String cityOfMosque(String? mosqueId) => cityOf(catalog.mosques[mosqueId], catalog.districts);

  /// What the public calendar shows: approved sessions, and cancelled ones
  /// (kept visible, marked cancelled).
  Iterable<Lesson> get publicLessons =>
      catalog.lessons.values.where((l) => (l.isPublic || l.isCancelled) && _ready(l));

  bool _ready(Lesson l) =>
      catalog.mosques.containsKey(l.mosqueId) && catalog.preachers.containsKey(l.preacherId);

  List<Lesson> get upcoming =>
      publicLessons.where((l) => l.isPublic && !l.date.isBefore(today)).toList()..sort(compareLessons);

  List<Lesson> upcomingWhere(bool Function(Lesson) test) => upcoming.where(test).toList();

  List<Lesson> pastWhere(bool Function(Lesson) test) =>
      publicLessons.where((l) => l.isPublic && l.date.isBefore(today) && test(l)).toList()
        ..sort((a, b) => compareLessons(b, a));

  List<Lesson> sessionsOf(String seriesId) =>
      publicLessons.where((l) => l.seriesId == seriesId).toList()..sort(compareLessons);

  List<LessonSeries> get approvedSeries => catalog.series.values.where((s) => s.status == 'approved').toList();

  List<Preacher> get listedPreachers =>
      catalog.preachers.values.where((p) => p.listed).toList()..sort((a, b) => a.nameAr.compareTo(b.nameAr));

  List<Mosque> get verifiedMosques => catalog.mosques.values.where((m) => m.verified).toList();

  double startHours(Lesson l) => lessonStartHours(l, catalog);
  bool isLiveNow(Lesson l) {
    if (!l.streamed || !l.isPublic || !sameDay(l.date, today)) return false;
    final start = startHours(l), now = lessonsNowHours();
    return now >= start && now <= start + 1.25;
  }

  // -------------------------------------------------------------- admins
  /// Admins, master admins and lessons-only admins manage everything.
  bool get canManage => roles.admin;

  /// Lesson requests preachers sent through their links, waiting.
  List<LessonRequest> get pendingRequests => canManage ? requestsOf(catalog.lessons.values) : const [];

  /// Card changes preachers proposed, waiting.
  List<PreacherEdit> get pendingEdits => admin.edits.where((e) => e.pending).toList();

  List<LessonsFlag> get openFlags => admin.flags.where((f) => f.status == 'open').toList();

  /// Everything an admin should look at: requests, card changes, reports.
  int get waitingCount => pendingRequests.length + pendingEdits.length + openFlags.length;

  LessonsRosterEntry? rosterEntry(String preacherId) =>
      admin.roster.where((r) => r.preacher.id == preacherId).firstOrNull;

  /// Every lesson of [preacherId] the caller can see, newest request first.
  List<LessonRequest> requestsOfPreacher(String preacherId, {Set<String> statuses = const {'pending', 'rejected'}}) =>
      requestsOf(catalog.lessons.values.where((l) => l.preacherId == preacherId), statuses: statuses);

  List<Lesson> clashes(Lesson l) => clashesOfLesson(l, catalog.lessons.values);

  // --------------------------------------------------------- viewer data
  bool hasReminder(String lessonId) => mine.reminders.containsKey(lessonId);
  String? reminderLead(String lessonId) => mine.reminders[lessonId]?.lead;
  bool isFollowing(String kind, String id) => mine.isFollowing(kind, id);
  bool attended(String lessonId) => mine.attended.contains(lessonId);

  Future<void> setReminder(Lesson l, String? lead) => _write(() => lead == null
      ? repository.removeReminder(l.id)
      : repository.setReminder(l.id, lead, reminderInstant(l, lead, catalog)));

  Future<void> toggleFollow(String kind, String id) =>
      _write(() => repository.setFollow(kind, id, !isFollowing(kind, id)));

  Future<void> toggleAttended(String lessonId) =>
      _write(() => repository.setAttended(lessonId, !attended(lessonId)));

  Future<void> savePreferences(LessonsPreferences p) => _write(() => repository.savePreferences(p));

  Future<void> markRead([List<String>? ids]) => _write(() => repository.markNotificationsRead(ids));

  Future<void> flag(String lessonId, String kind, String message) =>
      _write(() => repository.flag(lessonId, kind, message));

  // -------------------------------------------------------- admin writes
  Future<String> addLessons(LessonDraft d) => _write(() => repository.addLessons(d));
  Future<int> review(List<String> ids, String decision, {String? reason, String? mosqueId}) =>
      _write(() => repository.review(ids, decision, reason: reason, mosqueId: mosqueId));
  Future<int> undoReview(List<String> ids) => _write(() => repository.undoReview(ids));
  Future<void> withdraw(String requestId) => _write(() => repository.withdraw(requestId));
  Future<int> cancelLesson(String id, String reason) => _write(() => repository.cancelLesson(id, reason));
  Future<void> editLesson(String id, Map<String, dynamic> patch) => _write(() => repository.editLesson(id, patch));
  Future<void> postReport(String id, int attendance, int women, String issue, String notes) =>
      _write(() => repository.postReport(id, attendance, women, issue, notes));
  Future<void> resolveFlag(String id) => _write(() => repository.resolveFlag(id));

  Future<String> upsertPreacher(Map<String, dynamic> p) => _write(() => repository.upsertPreacher(p));
  Future<int> removePreacher(String preacherId) => _write(() => repository.removePreacher(preacherId));
  Future<int> importPreachers(List<Map<String, dynamic>> rows) => _write(() => repository.importPreachers(rows));
  Future<String?> revealPhone(String preacherId) => _write(() => repository.revealPhone(preacherId));
  Future<void> decideEdit(String editId, bool approve, {String? reason}) =>
      _write(() => repository.decideEdit(editId, approve, reason: reason));
  Future<List<LessonsAccount>> searchAccounts(String query) => repository.searchAccounts(query);

  Future<NewPreacherKey> createKey(String preacherId, String kind,
          {DateTime? validFrom, DateTime? validUntil, String note = ''}) =>
      _write(() => repository.createKey(preacherId, kind, validFrom: validFrom, validUntil: validUntil, note: note));
  Future<List<PreacherKey>> loadKeys(String preacherId) => repository.loadKeys(preacherId);
  Future<void> revokeKey(String keyId) => _write(() => repository.revokeKey(keyId));

  Future<String> upsertMosque(Map<String, dynamic> m) => _write(() => repository.upsertMosque(m));
  Future<void> removeMosque(String id, {String? mergeInto}) =>
      _write(() => repository.removeMosque(id, mergeInto: mergeInto));
}
