// E3 native lifecycle probe. Fixed emulator-to-loopback endpoint; no backend,
// real channel, ingest secret or claim of server authorization/physical AV.
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:streamer_app/features/live_stream/presentation/widgets/phone_camera_preview.dart';
import 'package:streamer_app/features/live_stream/services/rtmp_publish_engine.dart';

void main() {
  if (!kDebugMode) throw StateError('Debug probe only');
  runApp(const MaterialApp(home: _Probe()));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with WidgetsBindingObserver {
  final engine = RtmpPublishEngine();
  final timers = <Timer>[];
  final elapsed = Stopwatch()..start();
  String status = 'preparing';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    engine.authorizeRecovery =
        () async => true; // Only the fixed local receiver.
    engine.addListener(changed);
    timers.add(Timer(const Duration(seconds: 2), () async {
      try {
        await engine.initializeCamera();
        await engine.startPublishing('rtmp://10.0.2.2:55935/probe');
      } catch (e) {
        debugPrint('WAVE4V2 probe error: ${e.runtimeType}');
      }
    }));
    at(
        30,
        () => SystemChrome.setPreferredOrientations(
            [DeviceOrientation.landscapeLeft]));
    at(
        40,
        () => SystemChrome.setPreferredOrientations(
            [DeviceOrientation.portraitUp]));
    at(45, () async {
      try {
        await engine.switchCamera();
      } on UnsupportedError {
        debugPrint('WAVE4V2 front camera correctly unavailable');
      }
    });
    at(
        50,
        () => SystemChrome.setPreferredOrientations(
            [DeviceOrientation.landscapeRight]));
    at(60, () => engine.setAudioOnly(true));
    at(70, engine.stopPublishing);
  }

  void at(int seconds, Future<void> Function() action) {
    timers.add(Timer(Duration(seconds: seconds), () async {
      debugPrint('WAVE4V2 action=$seconds');
      await action();
    }));
  }

  void changed() {
    final next = '${engine.state.name} retry=${engine.reconnectAttempt}';
    if (next == status) return;
    debugPrint('WAVE4V2 ${elapsed.elapsedMilliseconds}ms $next');
    if (mounted) setState(() => status = next);
  }

  @override
  void didChangeMetrics() {
    unawaited(
        engine.setOrientation(0)); // Native reads the actual display rotation.
  }

  @override
  void dispose() {
    for (final timer in timers) {
      timer.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    engine.removeListener(changed);
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('LOCAL NATIVE PROBE: $status')),
        body: const PhoneCameraPreview(),
      );
}
