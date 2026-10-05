import 'package:flutter/foundation.dart';
import '../../../core/providers/app_provider.dart';
import '../../../core/services/organization_broadcast_service.dart';
import '../../organization/models/channel_connection.dart';
import '../models/broadcast_session.dart';

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
  String? errorKey;
  bool _disposed = false;
  int _generation = 0;
  bool get frozen => session?.frozen == true || _createdId != null;
  bool get operating => busy || provider.broadcastOperationBusy;
  List<ChannelConnection> get destinations => provider.channelConnections.where((c) =>
    c.id == destination?.id || c.connected && (c.organizationId == null
      ? provider.personalBroadcastApproved : provider.orgMemberships.any((m) =>
        m.organizationId == c.organizationId && m.active &&
        (m.permissions.canGoLiveVideo || m.permissions.canGoAudioOnly)))).toList();
  bool get simplePersonalDestination => destinations.length == 1 &&
    destination?.organizationId == null && destination?.connected == true;

  void _authorityChanged() {
    if (provider.currentDeviceSession?.isPrimaryBroadcaster == true &&
        (ingestKey.isEmpty || provider.publishingSession?.id == session?.id)) { return; }
    _generation++;
    session = null; destination = null; _createdId = null;
    ingestUrl = ''; ingestKey = ''; confirmed = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (operating) return;
    final generation = _generation;
    await provider.refreshChannelConnections();
    final rows = await provider.organizationSessions(mine: true);
    if (_disposed || generation != _generation) return;
    assignments = rows.where((s) => s.accepted &&
        ['scheduled', 'preparing', 'live', 'ending'].contains(s.state)).toList();
    final id = session?.id ?? _createdId ?? provider.publishingSession?.id;
    final restored = id == null
        ? rows.where((s) => s.active || (s.organizationId == null && s.state == 'scheduled')).firstOrNull
        : await provider.loadBroadcastSession(id);
    if (_disposed || generation != _generation) return;
    if (restored != null && ['scheduled','preparing','live','ending'].contains(restored.state)) {
      session = restored;
      _createdId = restored.id;
      destination = provider.channelConnections.where((c) => c.id == restored.channelConnectionId ||
          (restored.channelConnectionId == null && c.organizationId == restored.organizationId)).firstOrNull;
      if (restored.frozen) sender = restored.senderMode;
    } else if (id != null) {
      session = null; _createdId = null; ingestUrl = ''; ingestKey = ''; confirmed = false;
    }
    if (destination == null && destinations.length == 1) destination = destinations.single;
    if (simplePersonalDestination) confirmed = true;
    notifyListeners();
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
      // Keep allocation when preparation fails or its response is lost.
      final id = session?.id ?? (_createdId ??= await provider.createPersonalBroadcast(title, type));
      if (_disposed || generation != _generation) { _createdId=null; return false; }
      final result = await provider.prepareBroadcast(id, sender, destination!);
      if (_disposed || generation != _generation) { _createdId=null; return false; }
      session = BroadcastSession.fromRow(Map<String, dynamic>.from(result['session'] as Map));
      if (session!.channelConnectionId != destination!.id) throw StateError('Destination changed');
      ingestUrl = result['ingest_url'] as String; ingestKey = result['ingest_key'] as String;
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
    provider.removeListener(_authorityChanged);
    super.dispose();
  }
}
