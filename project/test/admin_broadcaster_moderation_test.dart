import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:streamer_app/core/providers/app_provider.dart';
import 'package:streamer_app/core/services/admin_database_service.dart';

import 'fixtures/streamer_fixtures.dart';

/// Records the audited server actions and can refuse them like the server.
class _ModerationDb extends AdminDatabaseService {
  _ModerationDb() : super(null);
  PostgrestException? refuse;
  final calls = <String>[];

  @override
  Future<void> setStreamerHiddenFromMap({
    required String streamerId,
    required bool isOrganization,
    required bool hidden,
    required String reason,
  }) async {
    calls.add('map:$streamerId:$isOrganization:$hidden:$reason');
    if (refuse != null) throw refuse!;
  }

  @override
  Future<void> revokeBroadcasterApproval({
    required String streamerId,
    required bool isOrganization,
    required String reason,
  }) async {
    calls.add('revoke:$streamerId:$isOrganization:$reason');
    if (refuse != null) throw refuse!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const denied = PostgrestException(message: 'Not permitted', code: '42501');

  test('R09: a refused map-visibility change is reported and not applied',
      () async {
    final db = _ModerationDb()..refuse = denied;
    final provider = AppProvider(db);
    final streamer = mockStreamers.first;
    provider.addStreamer(streamer);

    final ok = await provider.setStreamerHiddenFromMap(
        streamerId: streamer.streamerId, hidden: true, reason: 'spam');

    expect(ok, isFalse);
    expect(provider.getStreamerById(streamer.streamerId)!
        .isTemporarilyHiddenFromMap, isFalse);
    expect(db.calls, ['map:${streamer.streamerId}:false:true:spam']);
    provider.dispose();
  });

  test('R09: an accepted map-visibility change carries the reason', () async {
    final db = _ModerationDb();
    final provider = AppProvider(db);
    final streamer = mockStreamers.first;
    provider.addStreamer(streamer);

    expect(
        await provider.setStreamerHiddenFromMap(
            streamerId: streamer.streamerId, hidden: true, reason: 'spam'),
        isTrue);
    expect(provider.getStreamerById(streamer.streamerId)!
        .isTemporarilyHiddenFromMap, isTrue);
    provider.dispose();
  });

  test('R09: a refused revocation keeps the channel and reports failure',
      () async {
    final db = _ModerationDb()..refuse = denied;
    final provider = AppProvider(db);
    final streamer = mockStreamers.first;
    provider.addStreamer(streamer);

    final ok = await provider.revokeBroadcasterApproval(streamer.streamerId,
        reason: 'policy');

    expect(ok, isFalse);
    expect(provider.getStreamerById(streamer.streamerId), isNotNull,
        reason: 'no optimistic removal before the server answers');
    provider.dispose();
  });

  test('R09: organizations are revoked as organizations, not deleted',
      () async {
    final db = _ModerationDb();
    final provider = AppProvider(db);
    final org = mockStreamers.first
        .copyWith(streamerId: 'org-1', isOrganization: true);
    provider.addStreamer(org);

    expect(await provider.revokeBroadcasterApproval('org-1', reason: 'policy'),
        isTrue);
    expect(db.calls, ['revoke:org-1:true:policy']);
    expect(provider.getStreamerById('org-1'), isNotNull,
        reason: 'an unverified organization still exists');
    provider.dispose();
  });
}
