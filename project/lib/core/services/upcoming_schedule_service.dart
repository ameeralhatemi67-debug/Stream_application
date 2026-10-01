import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/profile/models/upcoming_schedule.dart';

typedef ReminderState = ({
  Set<String> channels,
  Set<String> cards,
  int leadMinutes
});

/// Backend-only schedule operations. Failed writes must not look saved.
class UpcomingScheduleService {
  UpcomingScheduleService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;

  SupabaseClient get client {
    if (_client != null) return _client!;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Schedule backend unavailable');
    }
  }

  Future<List<UpcomingSchedule>> load(String streamerId) async {
    final rows = await client
        .rpc('list_upcoming_schedules', params: {'p_streamer_id': streamerId});
    return (rows as List)
        .map((row) =>
            UpcomingSchedule.fromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<UpcomingSchedule> save(UpcomingSchedule schedule) async {
    final data = schedule.toRow();
    final Map<String, dynamic> row;
    if (schedule.id.isEmpty) {
      row = await client
          .from('upcoming_schedules')
          .insert(data)
          .select()
          .single();
    } else {
      row = await client
          .from('upcoming_schedules')
          .update(data)
          .eq('id', schedule.id)
          .select()
          .single();
    }
    return UpcomingSchedule.fromRow(row);
  }

  Future<void> delete(String id) async {
    final rows = await client
        .from('upcoming_schedules')
        .delete()
        .eq('id', id)
        .select('id');
    if ((rows as List).isEmpty) throw StateError('Schedule was not deleted');
  }

  Future<ReminderState> loadReminders() async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to set reminders');
    final channels = await client
        .from('channel_schedule_reminders')
        .select('streamer_profile_id')
        .eq('viewer_profile_id', uid);
    final cards = await client
        .from('card_schedule_reminders')
        .select('schedule_id')
        .eq('viewer_profile_id', uid);
    final preference = await client
        .from('schedule_reminder_preferences')
        .select('lead_minutes')
        .eq('viewer_profile_id', uid)
        .maybeSingle();
    return (
      channels: {
        for (final row in channels) row['streamer_profile_id'] as String
      },
      cards: {for (final row in cards) row['schedule_id'] as String},
      leadMinutes: preference?['lead_minutes'] as int? ?? 15,
    );
  }

  Future<void> setChannelReminder(String streamerId, bool enabled) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to set reminders');
    if (enabled) {
      await client.from('channel_schedule_reminders').upsert({
        'viewer_profile_id': uid,
        'streamer_profile_id': streamerId,
      });
    } else {
      await client
          .from('channel_schedule_reminders')
          .delete()
          .eq('viewer_profile_id', uid)
          .eq('streamer_profile_id', streamerId);
    }
  }

  Future<void> setCardReminder(String scheduleId, bool enabled) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to set reminders');
    if (enabled) {
      await client.from('card_schedule_reminders').upsert({
        'viewer_profile_id': uid,
        'schedule_id': scheduleId,
      });
    } else {
      await client
          .from('card_schedule_reminders')
          .delete()
          .eq('viewer_profile_id', uid)
          .eq('schedule_id', scheduleId);
    }
  }

  Future<void> setLeadMinutes(int minutes) async {
    if (minutes < 5 || minutes > 30 || minutes % 5 != 0) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in to set reminders');
    await client.from('schedule_reminder_preferences').upsert({
      'viewer_profile_id': uid,
      'lead_minutes': minutes,
    });
  }

  Future<void> upsertDevice(
      String token, String platform, String language) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    await client.rpc('register_schedule_push_device', params: {
      'p_token': token,
      'p_platform': platform,
      'p_language_code': language,
    });
  }

  Future<void> removeDevice(String token) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    await client
        .from('schedule_push_devices')
        .delete()
        .eq('viewer_profile_id', uid)
        .eq('token', token);
  }
}
