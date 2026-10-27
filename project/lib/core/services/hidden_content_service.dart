import 'package:supabase_flutter/supabase_flutter.dart';

/// What a channel owner can hide inside the app.
enum HiddenContentKind { video, playlist }

/// A recording of a live made in the app, as its channel owner or an admin
/// sees it (`recording_controls`). Hiding one also makes it private on
/// YouTube; the server applies the change after the live.
class RecordingControl {
  const RecordingControl({
    required this.videoId,
    required this.privateWanted,
    required this.youtubePrivacy,
    required this.takenDown,
    required this.deletePending,
    required this.deleted,
    required this.youtubeError,
    required this.canDelete,
  });

  factory RecordingControl.fromRow(Map<String, dynamic> row) => RecordingControl(
        videoId: row['video_id'] as String,
        privateWanted: row['private_wanted'] == true,
        youtubePrivacy: row['youtube_privacy'] as String? ?? 'public',
        takenDown: row['taken_down'] == true,
        deletePending: row['delete_pending'] == true,
        deleted: row['deleted'] == true,
        youtubeError: row['youtube_error'] == true,
        canDelete: row['can_delete'] == true,
      );

  final String videoId;
  final bool privateWanted;

  /// What YouTube has: `public` or `private`.
  final String youtubePrivacy;

  /// An admin took it down; only an admin can restore it.
  final bool takenDown;
  final bool deletePending;
  final bool deleted;

  /// YouTube could not be reached or refused the last change.
  final bool youtubeError;

  /// The streamer on their own channel or an organization's owner.
  final bool canDelete;

  /// YouTube does not show what the owner chose yet.
  bool get youtubePending =>
      !deleted &&
      (deletePending || youtubePrivacy != (privateWanted ? 'private' : 'public'));

  RecordingControl copyWith(
          {bool? privateWanted, bool? takenDown, bool? deletePending}) =>
      RecordingControl(
        videoId: videoId,
        privateWanted: privateWanted ?? this.privateWanted,
        youtubePrivacy: youtubePrivacy,
        takenDown: takenDown ?? this.takenDown,
        deletePending: deletePending ?? this.deletePending,
        deleted: deleted,
        youtubeError: false,
        canDelete: canDelete,
      );
}

/// Reads and writes `hidden_channel_content`, the list of videos and playlists
/// a channel owner hid from viewers. For recordings of lives made in the app
/// the server also makes a hidden one private on YouTube, deletes one on the
/// owner's request and lets admins take one down. Failed writes throw so the
/// caller never shows a change that was not saved.
class HiddenContentService {
  HiddenContentService({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;

  SupabaseClient get client {
    if (_client != null) return _client!;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Hidden content backend unavailable');
    }
  }

  /// Entry keys (`video:<id>` / `playlist:<id>`) hidden on [streamerId].
  Future<Set<String>> load(String streamerId) async {
    final rows = await client
        .from('hidden_channel_content')
        .select('kind,item_id')
        .eq('streamer_id', streamerId);
    return {
      for (final row in rows) key(_kind(row['kind'] as String), row['item_id'] as String)
    };
  }

  Future<void> setHidden(
      String streamerId, HiddenContentKind kind, String itemId, bool hidden) async {
    if (hidden) {
      await client.from('hidden_channel_content').upsert({
        'streamer_id': streamerId,
        'kind': kind.name,
        'item_id': itemId,
      });
      return;
    }
    await client
        .from('hidden_channel_content')
        .delete()
        .eq('streamer_id', streamerId)
        .eq('kind', kind.name)
        .eq('item_id', itemId);
  }

  /// The app-made recordings on [streamerId], by YouTube video id. Empty for
  /// anyone but the channel owner or an admin.
  Future<Map<String, RecordingControl>> loadRecordings(String streamerId) async {
    final rows = await client
        .rpc('recording_controls', params: {'p_channel': streamerId}) as List;
    return {
      for (final row in rows)
        (row['video_id'] as String):
            RecordingControl.fromRow(Map<String, dynamic>.from(row as Map))
    };
  }

  /// Asks the server to delete the recording from YouTube. It disappears from
  /// the app at once; the deletion itself follows within about a minute.
  Future<void> deleteRecording(String videoId) =>
      client.rpc('recording_delete', params: {'p_video': videoId});

  /// Admins: make a recording private and hidden ([down]), or hand it back
  /// to its owner. Audited with [reason].
  Future<void> takeDownRecording(String videoId, bool down, String reason) =>
      client.rpc('admin_recording_takedown',
          params: {'p_video': videoId, 'p_down': down, 'p_reason': reason});

  static String key(HiddenContentKind kind, String itemId) =>
      '${kind.name}:$itemId';

  static HiddenContentKind _kind(String value) => HiddenContentKind.values
      .firstWhere((k) => k.name == value, orElse: () => HiddenContentKind.video);
}
