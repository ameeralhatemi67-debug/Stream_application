import 'package:flutter/material.dart';
import 'rtmp_spike_screen.dart';

/// v0.7 Checkpoint 1 -- throwaway prototype entrypoint. Deliberately a
/// separate `main`, not reachable through the real app's routes/navigation:
/// `flutter run -t lib/spike_rtmp/main_rtmp_spike.dart`.
///
/// Exists purely to answer Checkpoint 1's question -- does phone camera/mic
/// -> RTMP publishing actually work, at acceptable latency/stability, on a
/// current Android toolchain, without conflicting with flutter_vlc_player's
/// native dependencies already in this project -- before Checkpoint 2 builds
/// the real feature on top of whichever approach this validates. See
/// doc/Roadmap/v0.7_Mobile_Streaming_Android.md Checkpoint 1.
///
/// STATUS: rtmp_streaming (the package this was built against) does not
/// build on this project's current Android toolchain -- see the spike
/// commit body for the three independent Gradle/Kotlin failures found.
/// `rtmp_streaming`/`permission_handler` were removed from pubspec.yaml
/// (leaving them in would break `flutter build apk` for the whole app, not
/// just this spike) and lib/spike_rtmp/ is excluded from analysis in
/// analysis_options.yaml. This file is kept only as a record of the exact
/// API shape that was validated as far as it could be, and the
/// engine/UI split Checkpoint 2 should copy regardless of which streaming
/// approach it ends up using.
void main() {
  runApp(const RtmpSpikeApp());
}

class RtmpSpikeApp extends StatelessWidget {
  const RtmpSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RtmpSpikeScreen(),
    );
  }
}
