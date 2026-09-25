// Local E3 adapter harness. No backend, credentials, or claim of live playback.
// flutter run -d web-server -t tool/p6s_browser_probe.dart --web-port 55890
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:streamer_app/features/live_stream/presentation/abstract_video_player.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  runApp(EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
    path: 'assets/i18n',
    fallbackLocale: const Locale('en'),
    child: Builder(
        builder: (context) => MaterialApp(
              locale: context.locale,
              supportedLocales: context.supportedLocales,
              localizationsDelegates: context.localizationDelegates,
              home: const _Probe(),
            )),
  ));
}

class _Probe extends StatefulWidget {
  const _Probe();
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  String id = 'M7lc1UVf-VE'; // Official YouTube API example; not a broadcast.
  String event = 'waiting';
  int instance = 0;
  void report(StreamState state) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => event = state.name);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('AUDIT HARNESS — no live broadcast')),
        body: ListView(children: [
          Text('Adapter event: $event. This is not playback proof.'),
          Wrap(children: [
            TextButton(
                onPressed: () => setState(() {
                      id = id == 'M7lc1UVf-VE' ? 'abcdefghijk' : 'M7lc1UVf-VE';
                    }),
                child: const Text('Change watch ID')),
            TextButton(
                onPressed: () => setState(() => instance++),
                child: const Text('Remount muted')),
          ]),
          SizedBox(
              height: 360,
              child: YouTubePlayerAdapter(
                key: ValueKey(instance),
                streamUrl: id,
                autoPlay: false,
                initialMuted: true,
                onStateChanged: report,
              )),
        ]),
      );
}
