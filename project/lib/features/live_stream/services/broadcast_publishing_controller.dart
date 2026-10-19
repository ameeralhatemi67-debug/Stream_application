import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/organization_broadcast_service.dart';
import '../../organization/models/channel_connection.dart';
import '../models/broadcast_session.dart';

/// A personal phone broadcast prepared on YouTube in the background while the
/// studio is open. Not this device's publishing session until Preview adopts it.
class _Warm {
  _Warm(this.destination);
  final ChannelConnection destination;
  String? id, title, type;
  Map<String, dynamic>? result;
}

/// Credentials live only for this studio visit and the active phone publisher.
class BroadcastPublishingController extends ChangeNotifier {
  BroadcastPublishingController(this.provider) { provider.addListener(_authorityChanged); }
  final AppProvider provider;
  List<BroadcastSession> assignments = [];
  ChannelConnection? destination;
  BroadcastSession? session;
  String? _createdId;
  String sender = 'obs_laptop';
  String ingestUrl = '', ingestKey = '';
  bool confirmed = false, busy = false;
  /// Hide the recording in the app when the live ends. Applied to the session
  /// on Preview/Prepare, or at once when one is already prepared.
  bool hideReplay = false;
  String? errorKey;
  bool _disposed = false;
  int _generation = 0;
  _Warm? _warm;
  Future<void>? _warming;
  Future<void>? _discarding;
  bool get frozen => session?.frozen == true || _createdId != null;
  bool get operating => busy || provider.broadcastOperationBusy;
  List<ChannelConnection> get destinations => provider.channelConnections.where((c) =>
    c.id == destination?.id || c.connected && (c.organizationId == null
      ? provider.personalBroadcastApproved : provider.orgMemberships.any((m) =>
        // Only organizations the rollout flag or pilot list has enabled; the
        // server refuses the start otherwise.
        m.organizationId == c.organizationId && m.active && m.v1Enabled &&
        (m.permissions.canGoLiveVideo || m.permissions.canGoAudioOnly)))).toList();
  bool get simplePersonalDestination => destinations.length == 1 &&
    destination?.organizationId == null && destination?.connected == true;

  void _authorityChanged() {
    if (provider.currentDeviceSession?.isPrimaryBroadcaster == true &&
        (ingestKey.isEmpty || provider.publishingSession?.id == session?.id)) { return; }
    _generation++;
    session = null; destination = null; _createdId = null;
    ingestUrl = ''; ingestKey = ''; confirmed = false;
    _releaseWarm();
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (operating) return;
    final generation = _generation;
    // A preparation from a studio visit closed moments ago is reused below.
    final released = provider.reclaimWarmBroadcast();
    await provider.refreshChannelConnections();
    final rows = await provider.organizationSessions(mine: true);
    if (_disposed || generation != _generation) {
      if (released != null) provider.releaseWarmBroadcast(released);
      return;
    }
    assignments = rows.where((s) => s.accepted &&
        ['scheduled', 'preparing', 'live', 'ending'].contains(s.state)).toList();
    final id = session?.id ?? _createdId ?? provider.publishingSession?.id;
    final restored = id == null
        ? rows.where((s) => s.active || (s.organizationId == null && s.state == 'scheduled')).firstOrNull
        : await provider.loadBroadcastSession(id);
    if (_disposed || generation != _generation) return;
    if (id == null && restored != null && _warm == null && _reusableWarm(restored)) {
      // An unused phone preparation (closed studio, or the app was killed
      // after it): keep the options open and reuse it, instead of showing it
      // as a frozen show or creating another one.
      destination = provider.channelConnections.where((c) => c.id == restored.channelConnectionId).firstOrNull;
      if (destination != null) {
        _warm = _Warm(destination!)..id = restored.id..title = restored.titleEn..type = restored.broadcastType;
        hideReplay = restored.hideReplay;
      }
    } else if (restored != null && ['scheduled','preparing','live','ending'].contains(restored.state)) {
      session = restored;
      _createdId = restored.id;
      hideReplay = restored.hideReplay;
      destination = provider.channelConnections.where((c) => c.id == restored.channelConnectionId ||
          (restored.channelConnectionId == null && c.organizationId == restored.organizationId)).firstOrNull;
      if (restored.frozen) sender = restored.senderMode;
    } else if (id != null) {
      session = null; _createdId = null; ingestUrl = ''; ingestKey = ''; confirmed = false;
    }
    if (released != null && released != _warm?.id && released != session?.id) {
      unawaited(provider.discardWarmBroadcast(released));
    }
    if (destination == null && destinations.length == 1) destination = destinations.single;
    if (simplePersonalDestination) confirmed = true;
    notifyListeners();
  }

  bool _reusableWarm(BroadcastSession s) => s.organizationId == null && s.state == 'preparing' &&
      s.senderMode == 'phone_direct' && s.deviceId == provider.currentDeviceSession?.deviceId &&
      s.endUtc != null && s.endUtc!.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 10)));

  /// Starts the YouTube handshake (session, feed, broadcast, binding) in the
  /// background as soon as the studio has loaded, so Preview finds it done.
  /// Only for this phone and the presenter's own channel: another sender or
  /// destination would need a different session.
  void prewarm({required String title, required String type}) {
    final target = destination;
    if (_disposed || _warming != null || session != null || _createdId != null || operating ||
        sender != 'phone_direct' || target == null || target.organizationId != null || !target.connected ||
        provider.currentDeviceSession?.isPrimaryBroadcaster != true) { return; }
    final existing = _warm;
    if (existing != null && (existing.destination.id != target.id || existing.result != null)) return;
    final warm = existing ?? _Warm(target);
    _warm = warm;
    final generation = _generation;
    Future<void> run() async {
      final pending = _discarding;
      if (pending != null) await pending;
      if (_disposed || generation != _generation || !identical(_warm, warm)) return;
      warm.id ??= await provider.createPersonalBroadcast(title, type);
      warm.title ??= title; warm.type ??= type;
      final result = await provider.prewarmBroadcast(warm.id!, target);
      if (identical(_warm, warm)) warm.result = result;
    }
    _warming = run().catchError((Object error) {
      // Preview runs the normal path and reports the real reason.
      debugPrint('Studio pre-warm failed: ${error.runtimeType}');
    }).whenComplete(() => _warming = null);
  }

  /// The sender or destination changed: an unused preparation for this phone
  /// on the personal channel no longer fits, so it is ended (one active
  /// session per presenter).
  void discardWarm() {
    final warm = _warm;
    if (warm == null || (sender == 'phone_direct' && destination?.id == warm.destination.id)) return;
    _warm = null;
    final pending = _warming;
    _discarding = () async {
      if (pending != null) await pending;
      final id = warm.id;
      if (id != null) await provider.discardWarmBroadcast(id);
    }().whenComplete(() => _discarding = null);
  }

  void _releaseWarm() {
    final warm = _warm;
    _warm = null;
    if (warm == null) return;
    final pending = _warming;
    if (pending == null) {
      if (warm.id != null) provider.releaseWarmBroadcast(warm.id!);
    } else {
      unawaited(pending.then((_) { if (warm.id != null) provider.releaseWarmBroadcast(warm.id!); }));
    }
  }

  /// Takes over the background preparation when it matches what Preview asks for.
  Future<bool> _adoptWarm(String title, String type) async {
    final pending = _warming;
    if (pending != null) await pending;
    final warm = _warm;
    if (warm == null || _disposed || sender != 'phone_direct' || destination?.id != warm.destination.id ||
        session != null || _createdId != null || warm.id == null) { return false; }
    _warm = null;
    _createdId = warm.id;
    if (warm.title != title || warm.type != type) {
      final updated = await provider.updatePersonalBroadcast(warm.id!, title, type);
      if (warm.result != null) warm.result = {...warm.result!, 'session': updated};
    }
    final result = warm.result;
    // Not prepared yet (it failed, or this is a reused session): prepare now.
    if (result == null) return false;
    provider.adoptPreparedBroadcast(result, sender, destination!);
    session = BroadcastSession.fromRow(Map<String, dynamic>.from(result['session'] as Map));
    ingestUrl = result['ingest_url'] as String; ingestKey = result['ingest_key'] as String;
    return true;
  }

  Future<bool> prepare(String title, String type) async {
    if (operating || !confirmed || destination == null) return false;
    if (session == null && _createdId == null && destination!.organizationId != null) {
      errorKey = 'organization_v1.assignment_required'; notifyListeners(); return false;
    }
    // The title is optional; YouTube still needs one, so fall back to the channel name.
    if (title.trim().isEmpty) title = destination!.title;
    busy = true; errorKey = null; notifyListeners();
    final generation = _generation;
    try {
      if (!await _adoptWarm(title, type)) {
        final pending = _discarding;
        if (pending != null) await pending;
        if (_disposed || generation != _generation) { _createdId=null; return false; }
        // Keep allocation when preparation fails or its response is lost.
        final id = session?.id ?? (_createdId ??= await provider.createPersonalBroadcast(title, type));
        if (_disposed || generation != _generation) { _createdId=null; return false; }
        final result = await provider.prepareBroadcast(id, sender, destination!);
        if (_disposed || generation != _generation) { _createdId=null; return false; }
        session = BroadcastSession.fromRow(Map<String, dynamic>.from(result['session'] as Map));
        if (session!.channelConnectionId != destination!.id) throw StateError('Destination changed');
        ingestUrl = result['ingest_url'] as String; ingestKey = result['ingest_key'] as String;
      }
      if (session!.hideReplay != hideReplay) {
        try {
          await provider.setBroadcastHideReplay(session!.id, hideReplay);
          session = session!.withHideReplay(hideReplay);
        } catch (error) {
          // The broadcast is ready; the live screen's options menu shows the
          // switch as it was saved and can set it again.
          debugPrint('Hide-recording choice not saved: ${error.runtimeType}');
        }
      }
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        session = provider.publishingSession ?? session;
        errorKey = OrganizationBroadcastService.errorKey(error);
      }
      return false;
    } finally {
      busy = false; if (!_disposed) notifyListeners();
    }
  }

  /// The hide-the-recording switch. With a session prepared the choice is
  /// saved at once; otherwise Preview/Prepare saves it.
  Future<void> setHideReplay(bool value) async {
    final previous = hideReplay;
    hideReplay = value; errorKey = null; notifyListeners();
    final target = session;
    if (target == null || !['scheduled', 'preparing', 'live'].contains(target.state)) return;
    try {
      await provider.setBroadcastHideReplay(target.id, value);
      if (identical(session, target)) session = target.withHideReplay(value);
    } catch (error) {
      hideReplay = previous;
      errorKey = OrganizationBroadcastService.actionErrorKey(error);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> end() async {
    if (operating) return;
    final target = session ?? (_createdId == null ? null : await provider.loadBroadcastSession(_createdId!));
    if (target == null || _disposed) return;
    busy = true; ingestUrl = ''; ingestKey = ''; notifyListeners();
    try {
      await provider.endOrganizationSession(target);
      session = null; _createdId = null; confirmed = false; errorKey = null;
    } catch (_) {
      errorKey = 'organization_v1.termination_pending';
    } finally {
      busy = false;
      if (!_disposed) { await load(); if (!_disposed) notifyListeners(); }
    }
  }

  @override
  void dispose() {
    _disposed = true; _generation++; ingestKey = ''; ingestUrl = '';
    // An unused preparation stays reusable for a short grace (reopening the
    // studio takes it back), then the provider ends it.
    _releaseWarm();
    provider.removeListener(_authorityChanged);
    super.dispose();
  }
}
