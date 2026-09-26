// Harness adapted from the reviewed Opus probe; executed independently on the Astra stack.
// Local-only E3 probe for P6S wave 3 group 1 (disposable stack
// P6S_astra_20260926, API 127.0.0.1:55811). Never prints keys or tokens.
// Clients: A and B = two phones of broadcaster C; V = an unrelated viewer;
// M = admin. Observes what Realtime and the public view actually deliver.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:supabase/supabase.dart';

const cli =
    r'C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app\node_modules\.bin\supabase.cmd';
const container = 'supabase_db_P6S_astra_20260926';

void check(bool cond, String label) {
  stdout.writeln('${cond ? 'PASS' : 'FAIL'} $label');
  if (!cond) exitCode = 1;
}

Future<void> psql(String sql) async {
  final r = await Process.run(
    r'C:\Users\User\AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe',
    [
      'exec',
      container,
      'psql',
      '-U',
      'postgres',
      '-d',
      'postgres',
      '-v',
      'ON_ERROR_STOP=1',
      '-q',
      '-c',
      sql,
    ],
  );
  if (r.exitCode != 0) throw StateError('psql failed: ${r.stderr}');
}

/// Subscribes like AppProvider: postgres_changes on profiles, optionally
/// filtered to one row; counts events after the channel joined.
Future<({RealtimeChannel channel, List<DateTime> events})> watchProfiles(
  SupabaseClient c,
  String name, {
  String? id,
}) async {
  final events = <DateTime>[];
  final joined = Completer<void>();
  final channel = c
      .channel('$name:${DateTime.now().microsecondsSinceEpoch}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: id == null
            ? null
            : PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: id,
              ),
        callback: (_) => events.add(DateTime.now()),
      )
      .subscribe((s, [e]) {
        if (s == RealtimeSubscribeStatus.subscribed && !joined.isCompleted) {
          joined.complete();
        }
      });
  await joined.future.timeout(const Duration(seconds: 20));
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return (channel: channel, events: events);
}

Future<bool> waitFor(bool Function() cond, Duration max) async {
  final sw = Stopwatch()..start();
  while (sw.elapsed < max) {
    if (cond()) return true;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  return cond();
}

Future<Map<String, dynamic>> publicRow(
  SupabaseClient c,
  String id,
) async => Map<String, dynamic>.from(
  await c
      .from('streamer_public_profiles')
      .select(
        'is_currently_live, active_stream_id, live_session_id, is_hidden_from_discovery, live_ingest_state',
      )
      .eq('id', id)
      .single(),
);

Future<void> main() async {
  final status = await Process.run(
    'cmd.exe',
    [
      '/d',
      '/c',
      cli,
      'status',
      '--workdir',
      'brief/.runtime/p6s-astra',
      '--output',
      'json',
    ],
    environment: {'DO_NOT_TRACK': '1'},
  );
  final out = status.stdout as String;
  final cfg =
      jsonDecode(out.substring(out.indexOf('{'), out.lastIndexOf('}') + 1))
          as Map<String, dynamic>;
  final url = Uri.parse(cfg['API_URL'] as String);
  if (!{'127.0.0.1', 'localhost'}.contains(url.host) || url.port != 55811) {
    throw StateError('Not the disposable local stack');
  }
  final service = SupabaseClient(
    url.toString(),
    cfg['SERVICE_ROLE_KEY'] as String,
  );
  final anon = cfg['ANON_KEY'] as String;
  final a = SupabaseClient(url.toString(), anon);
  final b = SupabaseClient(url.toString(), anon);
  final v = SupabaseClient(url.toString(), anon);
  final m = SupabaseClient(url.toString(), anon);
  final tag = Random.secure()
      .nextInt(0x7fffffff)
      .toRadixString(16)
      .padLeft(8, '0');
  final watch1 = 'A${tag}01', watch2 = 'A${tag}02', watch3 = 'A${tag}03';
  final created = <String>[];
  final channels = <(SupabaseClient, RealtimeChannel)>[];
  try {
    String pass() =>
        base64UrlEncode(List.generate(24, (_) => Random.secure().nextInt(256)));
    Future<String> user(String tag, String password) async {
      final id = (await service.auth.admin.createUser(
        AdminUserAttributes(
          email:
              'p6s-$tag-${DateTime.now().microsecondsSinceEpoch}@example.invalid',
          password: password,
          emailConfirm: true,
        ),
      )).user!.id;
      created.add(id);
      return id;
    }

    final cPass = pass(), vPass = pass(), mPass = pass();
    final c = await user('c', cPass);
    final viewer = await user('v', vPass);
    final admin = await user('m', mPass);
    await psql(
      "insert into public.profiles(id,is_streamer,is_verified) values('$c',true,true),('$viewer',false,false),('$admin',false,false) "
      "on conflict(id) do update set is_streamer=excluded.is_streamer,is_verified=excluded.is_verified; "
      "insert into public.user_roles(profile_id,role) values('$admin','admin');",
    );
    final cEmail = (await service.auth.admin.getUserById(c)).user!.email!;
    final vEmail = (await service.auth.admin.getUserById(viewer)).user!.email!;
    final mEmail = (await service.auth.admin.getUserById(admin)).user!.email!;
    await a.auth.signInWithPassword(email: cEmail, password: cPass);
    await b.auth.signInWithPassword(email: cEmail, password: cPass);
    await v.auth.signInWithPassword(email: vEmail, password: vPass);
    await m.auth.signInWithPassword(email: mEmail, password: mPass);

    Future<void> claim(SupabaseClient cl, String dev, {bool force = false}) =>
        cl.rpc(
          'claim_broadcaster_device_state',
          params: {
            'p_device_id': dev,
            'p_name': 'Probe $dev',
            'p_platform': 'android',
            'p_force': force,
          },
        );

    // Phone A primary and live.
    await claim(a, 'A');
    await a.rpc(
      'set_live_state',
      params: {
        'p_live': true,
        'p_type': 'liveVideo',
        'p_stream_id': watch1,
        'p_device_id': 'A',
      },
    );
    final before = await publicRow(v, c);
    check(
      before['is_currently_live'] == true && before['live_session_id'] != null,
      'viewer sees the live session through the public view',
    );

    // Subscriptions as the app makes them.
    final bOwn = await watchProfiles(b, 'user_status', id: c);
    final bAll = await watchProfiles(b, 'public_streamers');
    final vAll = await watchProfiles(v, 'public_streamers');
    final mAll = await watchProfiles(m, 'public_streamers');
    channels.addAll([
      (b, bOwn.channel),
      (b, bAll.channel),
      (v, vAll.channel),
      (m, mAll.channel),
    ]);

    // B takes over while A is live.
    final sw = Stopwatch()..start();
    await claim(b, 'B', force: true);
    final bGot = await waitFor(
      () => bOwn.events.isNotEmpty,
      const Duration(seconds: 10),
    );
    stdout.writeln(
      'INFO transferee own-row event: ${bGot ? '${sw.elapsedMilliseconds} ms' : 'NOT delivered in 10 s'}',
    );
    check(bGot, 'receiving phone gets its own profile change after transfer');
    final after = await publicRow(b, c);
    check(
      after['is_currently_live'] == false && after['live_session_id'] == null,
      'read after the event shows the broadcast ended',
    );
    final mGot = await waitFor(
      () => mAll.events.isNotEmpty,
      const Duration(seconds: 5),
    );
    check(mGot, 'admin receives the profile change');
    final vGot = await waitFor(
      () => vAll.events.isNotEmpty,
      const Duration(seconds: 5),
    );
    stdout.writeln(
      'INFO unrelated viewer profile events: ${vAll.events.length}',
    );
    check(
      !vGot,
      'an unrelated viewer receives NO Realtime event for another broadcaster (RLS); rooms must poll',
    );
    final reason = await m
        .from('broadcast_sessions')
        .select('end_reason')
        .eq('stream_id', watch1)
        .single();
    check(
      reason['end_reason'] == 'device_transfer',
      'session records device_transfer',
    );

    // B goes live through a session; admin End keeps B's device.
    final sessionB =
        await b.rpc(
              'start_broadcast_session',
              params: {
                'p_type': 'liveVideo',
                'p_stream_id': watch2,
                'p_device_id': 'B',
                'p_sender_mode': 'phone_direct',
              },
            )
            as String;
    await b.rpc(
      'report_broadcast_ingest',
      params: {
        'p_session_id': sessionB,
        'p_device_id': 'B',
        'p_state': 'interrupted',
      },
    );
    check(
      (await publicRow(v, c))['live_ingest_state'] == 'interrupted',
      'viewer sees the interruption, broadcast stays live',
    );
    final mSession = m.auth.currentSession!;
    final sessionId =
        (jsonDecode(
              utf8.decode(
                base64Url.decode(
                  base64Url.normalize(mSession.accessToken.split('.')[1]),
                ),
              ),
            )
            as Map)['session_id'];
    check(sessionId != null, 'admin token carries a session id');
    await m.rpc(
      'admin_set_stream_discovery',
      params: {'p_profile_id': c, 'p_hidden': true, 'p_reason': 'probe hide'},
    );
    final hidden = await publicRow(v, c);
    check(
      hidden['is_currently_live'] == true &&
          hidden['is_hidden_from_discovery'] == true,
      'hidden broadcast stays live and is flagged hidden in the public view',
    );
    await m.rpc(
      'admin_set_stream_discovery',
      params: {'p_profile_id': c, 'p_hidden': false, 'p_reason': 'audit show'},
    );
    check(
      (await publicRow(v, c))['is_hidden_from_discovery'] == false,
      'admin Show makes the same live session discoverable again',
    );
    var denied = false;
    try {
      await v.rpc(
        'admin_set_stream_discovery',
        params: {'p_profile_id': c, 'p_hidden': false, 'p_reason': 'x'},
      );
    } on PostgrestException catch (e) {
      denied = e.code == '42501';
    }
    check(denied, 'viewer cannot change discovery (42501)');
    await m.rpc(
      'admin_auth_account_action',
      params: {
        'p_profile_id': c,
        'p_action': 'force_end',
        'p_reason': 'probe end',
      },
    );
    var fenced = false;
    try {
      await b.rpc(
        'report_broadcast_ingest',
        params: {
          'p_session_id': sessionB,
          'p_device_id': 'B',
          'p_state': 'sending',
        },
      );
    } on PostgrestException catch (e) {
      fenced = e.code == '55000';
    }
    check(fenced, 'late reconnect report after admin End is refused (55000)');
    check(
      (await publicRow(v, c))['is_currently_live'] == false,
      'the refused reconnect did not revive LIVE',
    );
    final bStatus = Map<String, dynamic>.from(
      await b.rpc('my_broadcast_status') as Map,
    );
    check(
      bStatus['live'] == false &&
          (bStatus['last_ended'] as Map)['reason'] == 'admin_end',
      'broadcasting phone reads admin_end as the reason',
    );
    check(
      await b.rpc('device_heartbeat', params: {'p_device_id': 'B'}) == true,
      'phone B is still the primary device after admin End',
    );
    await b.rpc(
      'set_live_state',
      params: {
        'p_live': true,
        'p_type': 'liveVideo',
        'p_stream_id': watch3,
        'p_device_id': 'B',
      },
    );
    check(
      (await publicRow(v, c))['is_currently_live'] == true,
      'the owner can deliberately start a new broadcast after admin End',
    );
    await m.rpc(
      'admin_auth_account_action',
      params: {
        'p_profile_id': c,
        'p_action': 'remove_from_feed',
        'p_reason': 'audit end and block',
      },
    );
    check(
      (await publicRow(v, c))['is_currently_live'] == false,
      'End-and-block ends the current app session',
    );
    var blocked = false;
    try {
      await b.rpc(
        'start_broadcast_session',
        params: {
          'p_type': 'liveVideo',
          'p_stream_id': watch3,
          'p_device_id': 'B',
          'p_sender_mode': 'obs_laptop',
        },
      );
    } on PostgrestException catch (e) {
      blocked =
          e.code == '42501' && e.message == 'Stream removed by moderation';
    }
    check(blocked, 'End-and-block prevents relisting that same watch ID');
    final vStatus = Map<String, dynamic>.from(
      await v.rpc('my_broadcast_status') as Map,
    );
    check(
      vStatus['live'] == false && vStatus['session_id'] == null,
      'another account cannot read the broadcaster status',
    );
    await b.rpc(
      'set_live_state',
      params: {
        'p_live': false,
        'p_type': 'liveVideo',
        'p_stream_id': null,
        'p_device_id': 'B',
      },
    );
  } finally {
    for (final (cl, ch) in channels) {
      await cl.removeChannel(ch);
    }
    for (final cl in [a, b, v, m]) {
      await cl.dispose();
    }
    for (final id in created) {
      await service.auth.admin.deleteUser(id);
    }
    await psql(
      "delete from public.removed_live_streams where stream_id='$watch3'",
    );
    await service.dispose();
    stdout.writeln('Synthetic users removed; no credentials persisted.');
  }
}
