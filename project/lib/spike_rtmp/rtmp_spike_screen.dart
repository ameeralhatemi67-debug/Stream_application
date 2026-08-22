import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rtmp_streaming/rtmp_streaming.dart' as rtmp;
import 'rtmp_publish_engine.dart';

/// v0.7 Checkpoint 1 spike screen -- throwaway, not reachable from the real
/// app (see lib/spike_rtmp/main_rtmp_spike.dart). Only talks to
/// [RtmpPublishEngine] through its public state/methods, never to the
/// underlying rtmp_streaming CameraController directly (except handing it to
/// CameraPreview, which needs the concrete instance to render).
class RtmpSpikeScreen extends StatefulWidget {
  const RtmpSpikeScreen({super.key});

  @override
  State<RtmpSpikeScreen> createState() => _RtmpSpikeScreenState();
}

class _RtmpSpikeScreenState extends State<RtmpSpikeScreen> {
  final RtmpPublishEngine _engine = RtmpPublishEngine();
  final TextEditingController _urlController = TextEditingController(
    // 10.0.2.2 is the Android emulator's alias for the host machine --
    // points at the local MediaMTX instance used to validate this spike
    // without needing real YouTube Studio credentials.
    text: 'rtmp://10.0.2.2:1935/live/spike',
  );
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _engine.addListener(_onEngineChanged);
    _setup();
  }

  Future<void> _setup() async {
    final camera = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    if (!camera.isGranted || !mic.isGranted) {
      setState(() => _permissionError =
          'Camera/microphone permission denied (camera: $camera, mic: $mic).');
      return;
    }
    await _engine.initializeCamera();
  }

  void _onEngineChanged() => setState(() {});

  @override
  void dispose() {
    _engine.removeListener(_onEngineChanged);
    _engine.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('v0.7 RTMP spike (throwaway)')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildPreview(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_permissionError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_permissionError!,
              style: const TextStyle(color: Colors.redAccent)),
        ),
      );
    }
    final controller = _engine.cameraController;
    if (controller == null ||
        _engine.state == RtmpPublishState.idle ||
        _engine.state == RtmpPublishState.initializingCamera) {
      return const Center(child: CircularProgressIndicator());
    }
    return rtmp.CameraPreview(controller);
  }

  Widget _buildControls() {
    final stats = _engine.stats;
    final isLive = _engine.state == RtmpPublishState.live;
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('state: ${_engine.state.name}',
              style: const TextStyle(color: Colors.white)),
          if (_engine.lastError != null)
            Text('error: ${_engine.lastError}',
                style: const TextStyle(color: Colors.redAccent)),
          if (stats != null)
            Text(
              'bitrate: ${stats.bitrate} bps  fps: ${stats.fps}  '
              'dropped(v/a): ${stats.droppedVideoFrames}/${stats.droppedAudioFrames}  '
              'rttMicros: ${stats.rttMicros}',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _urlController,
            enabled: !isLive,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'RTMP URL',
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _engine.state == RtmpPublishState.ready ||
                    _engine.state == RtmpPublishState.stopped
                ? () => _engine.startPublishing(_urlController.text.trim())
                : isLive
                    ? () => _engine.stopPublishing()
                    : null,
            child: Text(isLive ? 'Stop' : 'Start Publishing'),
          ),
        ],
      ),
    );
  }
}
