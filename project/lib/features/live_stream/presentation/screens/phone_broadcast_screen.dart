import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/theme/app_theme.dart';
import '../../services/rtmp_publish_engine.dart';
import '../widgets/permission_rationale_dialog.dart';
import '../widgets/phone_camera_preview.dart';

/// v0.7 Checkpoint 2 Phase 1 -- lets a streamer broadcast using this phone's
/// own camera/mic instead of relying on OBS. Only ever talks to the native
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

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngineChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  Future<void> _setup() async {
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
      await _engine.initializeCamera();
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

  void _onEngineChanged() => setState(() {});

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
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
            _buildControls(),
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
    final ready = _engine.state == RtmpPublishState.ready ||
        _engine.state == RtmpPublishState.connecting ||
        _engine.state == RtmpPublishState.live;
    if (ready) {
      return const PhoneCameraPreview();
    }
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.accentRed),
    );
  }

  Widget _buildControls() {
    final ready = _engine.state == RtmpPublishState.ready;
    return Container(
      color: AppTheme.darkSurface1,
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: ready ? _engine.switchCamera : null,
            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
            tooltip: 'Swap camera',
          ),
        ],
      ),
    );
  }
}
