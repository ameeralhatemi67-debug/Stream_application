import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../profile/models/streamer_models.dart';
import '../../models/stream_privacy_models.dart';
import '../../services/rtmp_publish_engine.dart';
import '../widgets/permission_rationale_dialog.dart';
import '../widgets/phone_camera_preview.dart';

/// v0.7 Checkpoint 2 -- lets a streamer broadcast using this phone's own
/// camera/mic instead of relying on OBS. Only ever talks to the native
/// RootEncoder wrapper through [RtmpPublishEngine] (MethodChannel/
/// EventChannel), mirroring the engine/UI split the Checkpoint 1 spike
/// validated, so v1.1's iOS engine can sit behind this same screen later.
class PhoneBroadcastScreen extends StatefulWidget {
  /// Set when this screen is launched from the Broadcaster Studio bottom
  /// sheet's Phone mode (LiveBroadcasterStudioSheet), which already
  /// collected the quality preset (and everything else) up front -- skips
  /// the picker below and heads straight into camera setup. Null only if
  /// this screen is ever pushed without a preset already chosen, which then
  /// still shows the picker.
  final BroadcastQualityPreset? quickLaunchPreset;

  const PhoneBroadcastScreen({super.key, this.quickLaunchPreset});

  @override
  State<PhoneBroadcastScreen> createState() => _PhoneBroadcastScreenState();
}

class _PhoneBroadcastScreenState extends State<PhoneBroadcastScreen> {
  final RtmpPublishEngine _engine = RtmpPublishEngine();
  String? _setupError;
  late BroadcastQualityPreset _preset;
  late bool _presetConfirmed;

  late AppProvider _appProvider;
  bool _appProviderCaptured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_appProviderCaptured) {
      _appProvider = Provider.of<AppProvider>(context, listen: false);
      _appProviderCaptured = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngineChanged);
    _preset = widget.quickLaunchPreset ?? BroadcastQualityPreset.medium;
    _presetConfirmed = widget.quickLaunchPreset != null;

    if (widget.quickLaunchPreset != null) {
      // A pre-chosen preset means the Broadcaster Studio sheet's Phone mode
      // launched this screen as a one-tap flow: this screen (not
      // _startBroadcast's own "wasn't live yet" check below) owns ending the
      // broadcast if the user backs out before/after the RTMP connection
      // actually goes through -- see dispose()/_stopBroadcast.
      _weStartedBroadcast = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _confirmPresetAndSetup();
      });
    }
  }

  Future<void> _confirmPresetAndSetup() async {
    setState(() => _presetConfirmed = true);

    final cameraGranted = await _ensurePermission(
      Permission.camera,
      BroadcastPermissionKind.camera,
    );
    if (!cameraGranted) return;

    final micGranted = await _ensurePermission(
      Permission.microphone,
      BroadcastPermissionKind.microphone,
    );
    if (!micGranted) return;

    // v0.7 Checkpoint 3 Phase 2 -- best-effort only: RtmpForegroundService
    // keeps the broadcast running in the background even without this (API
    // < 33 doesn't need it at all; confirmed on-device), but on API 33+ its
    // ongoing-broadcast notification is silently invisible without it. Not
    // worth a rationale dialog or gating the broadcast on the answer.
    await Permission.notification.request();

    try {
      await _engine.initializeCamera(preset: _preset);
      // v0.7 Checkpoint 3 Phase 1 -- reuses the same RTMP pipeline in
      // mic-only mode when the streamer picked Audio-Only in the
      // Broadcaster Studio sheet's format toggle, swapping the encoder's
      // video source to a static branded image.
      if (_appProvider.customBroadcastType == BroadcastType.liveAudio) {
        await _engine.setAudioOnly(true);
      }
      // A pre-chosen preset means this is a one-tap flow -- the streamer
      // already committed to going live back in the Broadcaster Studio
      // sheet, so there's no separate manual "Go Live" tap to wait for here
      // once the camera's ready.
      if (widget.quickLaunchPreset != null && mounted) {
        await _startBroadcast();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _setupError = 'Could not start the camera: $e');
    }
  }

  Future<bool> _ensurePermission(
    Permission permission,
    BroadcastPermissionKind kind,
  ) async {
    var status = await permission.status;
    if (status.isGranted) return true;

    if (!mounted) return false;
    final continueRequested =
        await PermissionRationaleDialog.show(context, kind);
    if (!continueRequested) {
      _showDenied(kind);
      return false;
    }

    status = await permission.request();
    if (!status.isGranted) {
      _showDenied(kind);
      return false;
    }
    return true;
  }

  void _showDenied(BroadcastPermissionKind kind) {
    if (!mounted) return;
    final isCamera = kind == BroadcastPermissionKind.camera;
    setState(() {
      _setupError = isCamera
          ? 'Camera access is required to broadcast from this phone. '
              'Enable it in system settings to continue.'
          : 'Microphone access is required to broadcast from this phone. '
              'Enable it in system settings to continue.';
    });
  }

  // Tracks whether *this screen* was the one that flipped
  // AppProvider.isBroadcastingLive on -- not just whether it's currently
  // true, since a broadcast could already be live via OBS/YouTube-video-ID
  // before this screen ever opened. Only undoes what it did: started here,
  // stopped here (including on dispose, e.g. the user backing out mid-
  // "connecting" rather than tapping End Broadcast first).
  bool _weStartedBroadcast = false;

  Future<void> _startBroadcast() async {
    try {
      await _engine.startPublishing(_appProvider.phoneBroadcastFullUrl);
      if (!mounted) return;
      if (!_appProvider.isBroadcastingLive) {
        await _appProvider.toggleBroadcasterGoLive(context);
        _weStartedBroadcast = true;
      }
    } on Exception {
      // The engine's own error state already drives the UI here.
    }
  }

  Future<void> _stopBroadcast() async {
    await _engine.stopPublishing();
    if (_weStartedBroadcast && _appProvider.isBroadcastingLive) {
      await _appProvider.toggleBroadcasterGoLive(mounted ? context : null);
    }
    _weStartedBroadcast = false;
  }

  void _onEngineChanged() => setState(() {});

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    if (_weStartedBroadcast && _appProvider.isBroadcastingLive) {
      // Deferred to a microtask: AppRouter is built with
      // refreshListenable: provider (ADR-001), so toggleBroadcasterGoLive's
      // notifyListeners() re-enters GoRouter's own rebuild if called
      // synchronously from dispose() while the Router is still mid-rebuild
      // from the very pop that's disposing this screen -- observed on
      // device as "setState() or markNeedsBuild() called when widget tree
      // was locked" inside _RouterState._rebuild. Running it after the
      // current frame finishes avoids the re-entrancy.
      final provider = _appProvider;
      Future.microtask(() => provider.toggleBroadcasterGoLive());
    }
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Title/description come from the Broadcaster Studio bottom sheet
    // (AppProvider.setCustomBroadcastMeta), which always runs immediately
    // before this screen is pushed -- read via Provider rather than
    // constructor params so this stays in sync with the same source of
    // truth PhoneBroadcastScreen already reads phoneBroadcastFullUrl from.
    final title = _appProvider.customLiveTitle;
    final description = _appProvider.customLiveDescription;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title.isEmpty ? 'Broadcast From Phone' : title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: AppTheme.textSecondaryDark,
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody()),
            if (_presetConfirmed) _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_setupError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Text(
            _setupError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    if (!_presetConfirmed) {
      return _buildPresetPicker();
    }

    // The native OpenGlView (and RtmpPublisherBridge.attach()) only exists
    // once this PlatformView is actually mounted -- so it has to be in the
    // tree *before* RtmpPublishEngine.initializeCamera()'s "prepare" call,
    // not gated behind it, or "prepare" reaches an unattached bridge (see
    // NOT_READY in RtmpPublisherBridge). A loading spinner overlays it until
    // the engine reports ready.
    final loading = _engine.state == RtmpPublishState.idle ||
        _engine.state == RtmpPublishState.initializingCamera;
    return Stack(
      children: [
        const PhoneCameraPreview(),
        if (loading)
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: AppTheme.accentRed),
            ),
          ),
        if (_engine.state == RtmpPublishState.live)
          Positioned(
            top: AppTheme.spaceMd,
            left: AppTheme.spaceMd,
            child: _LiveBadge(bitrateBps: _engine.lastBitrateBps),
          ),
        if (_engine.state == RtmpPublishState.connecting)
          const Positioned(
            top: AppTheme.spaceMd,
            left: AppTheme.spaceMd,
            child: _StatusPill(label: 'Connecting...', color: Colors.amber),
          ),
        if (_engine.state == RtmpPublishState.reconnecting)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _ReconnectingBanner(
              attempt: _engine.reconnectAttempt,
              maxAttempts: _engine.maxReconnectAttempts,
            ),
          ),
        if (_engine.state == RtmpPublishState.error &&
            _engine.lastError != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _StreamErrorBanner(message: _engine.lastError!),
          ),
        if (_engine.isAudioOnly)
          const Positioned(
            top: AppTheme.spaceMd,
            right: AppTheme.spaceMd,
            child: _StatusPill(label: 'AUDIO ONLY', color: AppTheme.accentBlue),
          ),
        Consumer<AppProvider>(
          builder: (context, provider, _) {
            if (provider.pendingKnockRequests.isEmpty) {
              return const SizedBox.shrink();
            }
            final request = provider.pendingKnockRequests.first;
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _KnockingBanner(
                request: request,
                queueLength: provider.pendingKnockRequests.length,
                onAdmit: () => provider.admitKnockRequest(request.id),
                onDeny: () => provider.denyKnockRequest(request.id),
                onAdmitAll: provider.admitAllKnockRequests,
              ),
            );
          },
        ),
        Consumer<AppProvider>(
          builder: (context, provider, _) {
            if (!provider.isActiveStreamPrivate) return const SizedBox.shrink();
            return Positioned(
              bottom: AppTheme.spaceMd,
              right: AppTheme.spaceMd,
              child: _AttendeesButton(
                count: provider.admittedAttendees.length,
                onTap: () => _showDirectorPanel(context, provider),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDirectorPanel(BuildContext context, AppProvider provider) {
    final handleController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkSurface1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLg),
          child: Consumer<AppProvider>(
            builder: (context, provider, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🔒 ${provider.admittedAttendees.length} Attendees',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: handleController,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Search or add @username',
                            hintStyle: const TextStyle(
                                color: AppTheme.textMutedDark, fontSize: 12),
                            filled: true,
                            fillColor: AppTheme.darkSurface2,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                              borderSide:
                                  const BorderSide(color: AppTheme.darkBorderSubtle),
                            ),
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isEmpty) return;
                            provider.admitAttendeeByHandle(value.trim());
                            handleController.clear();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.person_add_alt_1_rounded,
                            color: AppTheme.accentGreen),
                        onPressed: () {
                          final value = handleController.text.trim();
                          if (value.isEmpty) return;
                          provider.admitAttendeeByHandle(value);
                          handleController.clear();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spaceMd),
                  TextButton.icon(
                    icon: const Icon(Icons.emoji_people_rounded, size: 16),
                    label: const Text('Simulate Incoming Guest'),
                    onPressed: provider.simulateIncomingKnock,
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: provider.admittedAttendees.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                            child: Text(
                              'No attendees admitted yet.',
                              style: TextStyle(
                                  color: AppTheme.textMutedDark, fontSize: 12),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: provider.admittedAttendees.length,
                            itemBuilder: (context, index) {
                              final attendee = provider.admittedAttendees[index];
                              return ListTile(
                                dense: true,
                                leading: attendee.isVip
                                    ? const Icon(Icons.workspace_premium_rounded,
                                        color: AppTheme.accentAmber, size: 20)
                                    : const Icon(Icons.person_rounded,
                                        color: AppTheme.textSecondaryDark, size: 20),
                                title: Text(
                                  attendee.displayName,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                ),
                                trailing: TextButton.icon(
                                  icon: const Icon(Icons.block_rounded,
                                      color: AppTheme.accentRed, size: 16),
                                  label: const Text(
                                    'Kick Out',
                                    style: TextStyle(
                                        color: AppTheme.accentRed, fontSize: 12),
                                  ),
                                  onPressed: () =>
                                      provider.kickAttendee(attendee.id),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ).whenComplete(handleController.dispose);
  }

  Widget _buildPresetPicker() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose a broadcast quality',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            const Text(
              "Higher quality looks better but needs a stronger upload. "
              "You can't change this once you start the camera.",
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12.5),
            ),
            const SizedBox(height: AppTheme.spaceLg),
            ...BroadcastQualityPreset.values.map(
              (preset) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
                child: _PresetOption(
                  preset: preset,
                  selected: _preset == preset,
                  onTap: () => setState(() => _preset = preset),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _confirmPresetAndSetup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Continue',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    final ready = _engine.state == RtmpPublishState.ready ||
        _engine.state == RtmpPublishState.stopped;
    final live = _engine.state == RtmpPublishState.live;
    final connecting = _engine.state == RtmpPublishState.connecting;
    // v0.7 Checkpoint 4 Phase 1 -- reconnecting still counts as an active
    // broadcast session for control purposes: mic-mute/camera-swap stay
    // available, and End Broadcast lets the user bail out of a stuck
    // reconnect loop rather than being stuck with no way to stop.
    final broadcastActive =
        live || _engine.state == RtmpPublishState.reconnecting;
    // v0.7 Checkpoint 4 Phase 1 -- a connection failure (including a
    // reconnect that ran out of attempts) shouldn't be a dead end: the
    // camera is still prepared, so Go Live can retry a fresh connection
    // attempt rather than leaving the broadcaster stuck.
    final canToggleGoLive =
        ready || broadcastActive || _engine.state == RtmpPublishState.error;

    return Container(
      color: AppTheme.darkSurface1,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: broadcastActive || ready
                ? () => _engine.setMuted(!_engine.isMuted)
                : null,
            icon: Icon(
              _engine.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              color: Colors.white,
            ),
            tooltip: _engine.isMuted ? 'Unmute microphone' : 'Mute microphone',
          ),
          ElevatedButton.icon(
            onPressed: connecting
                ? null
                : canToggleGoLive
                    ? (broadcastActive ? _stopBroadcast : _startBroadcast)
                    : null,
            icon: Icon(
              broadcastActive
                  ? Icons.stop_circle_rounded
                  : Icons.sensors_rounded,
            ),
            label: Text(
              connecting
                  ? 'Connecting...'
                  : broadcastActive
                      ? 'End Broadcast'
                      : 'Go Live',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  broadcastActive ? Colors.red.shade800 : AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          IconButton(
            onPressed: (ready || broadcastActive) && !_engine.isAudioOnly
                ? _engine.switchCamera
                : null,
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            tooltip: _engine.isAudioOnly
                ? 'Not available in audio-only mode'
                : 'Swap camera',
          ),
        ],
      ),
    );
  }
}

class _PresetOption extends StatelessWidget {
  final BroadcastQualityPreset preset;
  final bool selected;
  final VoidCallback onTap;

  const _PresetOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentRed.withValues(alpha: 0.15)
              : AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.accentRed : AppTheme.textMutedDark,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                preset.label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSecondaryDark,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final int? bitrateBps;

  const _LiveBadge({required this.bitrateBps});

  @override
  Widget build(BuildContext context) {
    final bitrateLabel =
        bitrateBps == null ? '' : ' -- ${(bitrateBps! / 1000).round()} kbps';
    return _StatusPill(
      label: 'LIVE$bitrateLabel',
      color: AppTheme.accentRed,
    );
  }
}

/// v0.7 Checkpoint 4 Phase 1 -- shown full-width when the RTMP connection
/// drops mid-broadcast and RootEncoder is retrying with backoff, so the
/// broadcaster sees a clear "stream interrupted" state instead of a silent
/// freeze while the connection is down.
class _ReconnectingBanner extends StatelessWidget {
  final int? attempt;
  final int? maxAttempts;

  const _ReconnectingBanner({required this.attempt, required this.maxAttempts});

  @override
  Widget build(BuildContext context) {
    final attemptLabel = (attempt != null && maxAttempts != null)
        ? ' (attempt $attempt/$maxAttempts)'
        : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: Colors.orange.shade900,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              'Stream interrupted -- reconnecting$attemptLabel...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// v0.7 Checkpoint 4 Phase 1 -- shown when a broadcast ends in a real
/// failure (reconnect attempts exhausted, or a native-side connection
/// timeout with no further recovery). The camera stays prepared, so Go
/// Live in the controls below retries a fresh connection rather than
/// leaving the broadcaster stuck looking at this with no way forward.
class _StreamErrorBanner extends StatelessWidget {
  final String message;

  const _StreamErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: Colors.red.shade900,
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Private Streaming host HUD -- slide-down banner shown when a guest has
/// knocked on a private broadcast, letting the host Admit/Deny (or batch
/// Admit All) without leaving the camera view.
class _KnockingBanner extends StatelessWidget {
  final StreamKnockRequest request;
  final int queueLength;
  final VoidCallback onAdmit;
  final VoidCallback onDeny;
  final VoidCallback onAdmitAll;

  const _KnockingBanner({
    required this.request,
    required this.queueLength,
    required this.onAdmit,
    required this.onDeny,
    required this.onAdmitAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceSm,
      ),
      color: AppTheme.darkSurface1.withValues(alpha: 0.96),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppTheme.accentAmber, size: 18),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              '👤 ${request.displayName} wants to join',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (queueLength > 1) ...[
            TextButton(
              onPressed: onAdmitAll,
              child: Text('Admit All ($queueLength)',
                  style: const TextStyle(color: AppTheme.accentGreen, fontSize: 11)),
            ),
            const SizedBox(width: 4),
          ],
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AppTheme.accentRed, size: 20),
            tooltip: 'Deny',
            onPressed: onDeny,
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_rounded,
                color: AppTheme.accentGreen, size: 20),
            tooltip: 'Admit',
            onPressed: onAdmit,
          ),
        ],
      ),
    );
  }
}

/// Private Streaming host HUD -- floating attendee counter opening the
/// director panel (search/add @username, kick out).
class _AttendeesButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _AttendeesButton({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.darkSurface1.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: AppTheme.accentAmber, size: 16),
            const SizedBox(width: 6),
            Text(
              '$count Attendees',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
