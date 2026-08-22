import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../../../core/providers/app_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../services/rtmp_publish_engine.dart';
import '../widgets/permission_rationale_dialog.dart';
import '../widgets/phone_camera_preview.dart';

/// v0.7 Checkpoint 2 -- lets a streamer broadcast using this phone's own
/// camera/mic instead of relying on OBS. Only ever talks to the native
/// RootEncoder wrapper through [RtmpPublishEngine] (MethodChannel/
/// EventChannel), mirroring the engine/UI split the Checkpoint 1 spike
/// validated, so v1.1's iOS engine can sit behind this same screen later.
class PhoneBroadcastScreen extends StatefulWidget {
  const PhoneBroadcastScreen({super.key});

  @override
  State<PhoneBroadcastScreen> createState() => _PhoneBroadcastScreenState();
}

class _PhoneBroadcastScreenState extends State<PhoneBroadcastScreen> {
  final RtmpPublishEngine _engine = RtmpPublishEngine();
  String? _setupError;
  BroadcastQualityPreset _preset = BroadcastQualityPreset.medium;
  bool _presetConfirmed = false;

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

    try {
      await _engine.initializeCamera(preset: _preset);
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

  Future<void> _startBroadcast() async {
    try {
      await _engine.startPublishing(_appProvider.phoneBroadcastFullUrl);
      if (!mounted) return;
      if (!_appProvider.isBroadcastingLive) {
        await _appProvider.toggleBroadcasterGoLive(context);
      }
    } on Exception {
      // The engine's own error state already drives the UI here.
    }
  }

  Future<void> _stopBroadcast() async {
    await _engine.stopPublishing();
    if (_appProvider.isBroadcastingLive) {
      await _appProvider.toggleBroadcasterGoLive(mounted ? context : null);
    }
  }

  void _onEngineChanged() => setState(() {});

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    if (_engine.state == RtmpPublishState.live && _appProvider.isBroadcastingLive) {
      _appProvider.toggleBroadcasterGoLive();
    }
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface1,
        title: const Text('Broadcast From Phone'),
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

    final previewReady = _engine.state == RtmpPublishState.ready ||
        _engine.state == RtmpPublishState.connecting ||
        _engine.state == RtmpPublishState.live ||
        _engine.state == RtmpPublishState.stopped;
    if (previewReady) {
      return Stack(
        children: [
          const PhoneCameraPreview(),
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
        ],
      );
    }
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.accentRed),
    );
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
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            const Text(
              "Higher quality looks better but needs a stronger upload. "
              "You can't change this once you start the camera.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12.5),
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
                child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final canToggleGoLive = ready || live;

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
            onPressed: live || ready ? () => _engine.setMuted(!_engine.isMuted) : null,
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
                    ? (live ? _stopBroadcast : _startBroadcast)
                    : null,
            icon: Icon(live ? Icons.stop_circle_rounded : Icons.sensors_rounded),
            label: Text(
              connecting
                  ? 'Connecting...'
                  : live
                      ? 'End Broadcast'
                      : 'Go Live',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: live ? Colors.red.shade800 : AppTheme.accentGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          IconButton(
            onPressed: ready || live ? _engine.switchCamera : null,
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            tooltip: 'Swap camera',
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
          color: selected ? AppTheme.accentRed.withValues(alpha: 0.15) : AppTheme.darkSurface1,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: selected ? AppTheme.accentRed : AppTheme.darkBorderSubtle,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
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
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
