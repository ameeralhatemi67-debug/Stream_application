import 'package:supabase_flutter/supabase_flutter.dart';

/// What a channel owner can hide inside the app.
enum HiddenContentKind { video, playlist }

/// Reads and writes `hidden_channel_content`, the list of videos and playlists
/// a channel owner hid from viewers. Nothing here touches YouTube. Failed
/// writes throw so the caller never shows a change that was not saved.
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

  static String key(HiddenContentKind kind, String itemId) =>
      '${kind.name}:$itemId';

  static HiddenContentKind _kind(String value) => HiddenContentKind.values
      .firstWhere((k) => k.name == value, orElse: () => HiddenContentKind.video);
}
