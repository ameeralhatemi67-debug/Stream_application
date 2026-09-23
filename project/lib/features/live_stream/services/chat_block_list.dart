import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a block or unblock did not take effect. The caller maps each value to
/// a localized message; the list never shows raw server text.
enum ChatBlockFailure { signedOut, notPermitted, targetGone, network }

class ChatBlockException implements Exception {
  const ChatBlockException(this.failure);
  final ChatBlockFailure failure;
  @override
  String toString() => 'ChatBlockException($failure)';
}

/// Server access for `chat_user_blocks` (20260923120000). Split out so the
/// list's sync rules can be tested without a Supabase instance.
abstract class ChatBlockStore {
  String? get currentUserId;
  Future<Set<String>> fetchBlockedIds(String blockerId);
  Future<void> insertBlock(String blockerId, String blockedId);
  Future<void> deleteBlock(String blockerId, String blockedId);
  Future<Map<String, String>> resolveNames(List<String> profileIds);
}

class SupabaseChatBlockStore implements ChatBlockStore {
  const SupabaseChatBlockStore();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Set<String>> fetchBlockedIds(String blockerId) async {
    final rows = await _client
        .from('chat_user_blocks')
        .select('blocked_id')
        .eq('blocker_id', blockerId);
    return {
      for (final r in (rows as List).cast<Map<String, dynamic>>())
        r['blocked_id'] as String,
    };
  }

  @override
  Future<void> insertBlock(String blockerId, String blockedId) async {
    await _client
        .from('chat_user_blocks')
        .insert({'blocker_id': blockerId, 'blocked_id': blockedId});
  }

  @override
  Future<void> deleteBlock(String blockerId, String blockedId) async {
    await _client
        .from('chat_user_blocks')
        .delete()
        .eq('blocker_id', blockerId)
        .eq('blocked_id', blockedId);
  }

  @override
  Future<Map<String, String>> resolveNames(List<String> profileIds) async {
    if (profileIds.isEmpty) return const {};
    final rows = await _client
        .rpc('chat_sender_info', params: {'p_profile_ids': profileIds});
    return {
      for (final p in (rows as List).cast<Map<String, dynamic>>())
        p['profile_id'] as String: (p['display_name'] as String?) ?? '',
    };
  }
}

/// The signed-in account's chat blocks, with the server as the only source of
/// truth (P6). One list per app so a block made in one live room, or removed
/// in Settings, applies to every open chat at once.
///
/// * Block and unblock change local state only after the server accepts the
///   write. A refused write throws [ChatBlockException] and leaves the list
///   exactly as it was.
/// * [refresh] replaces the set with the server's rows. Rooms call it on
///   entry, Settings on open and the app on resume, which is how a block made
///   on another device arrives. The server's restrictive read policy on
///   `chat_messages` also withholds a blocked sender's history and Realtime
///   rows, so a stale local copy cannot show them anyway.
/// * The last server copy is cached per account so a room entered offline
///   still hides known blocked senders. A failed refresh keeps that copy and
///   marks it [isStale]; it never clears the list.
/// * Blocks from the old device-only store are uploaded once. The old key is
///   removed only after every upload succeeds, so nothing is lost offline.
class ChatBlockList extends ChangeNotifier {
  ChatBlockList({ChatBlockStore? store})
      : _store = store ?? const SupabaseChatBlockStore();

  static final ChatBlockList instance = ChatBlockList();

  final ChatBlockStore _store;

  static const legacyPrefsPrefix = 'chat_blocked_users_';
  static const cachePrefsPrefix = 'chat_blocks_server_cache_';

  String? _userId;
  final Set<String> _blocked = {};
  bool _isStale = false;
  bool _hasLoaded = false;
  Future<void>? _inFlight;

  Set<String> get blockedIds => Set.unmodifiable(_blocked);
  bool isBlocked(String profileId) => _blocked.contains(profileId);

  /// True when the shown set is a cached copy the server did not confirm.
  bool get isStale => _isStale;
  bool get hasLoaded => _hasLoaded;

  /// Drops another account's blocks when the signed-in user changes, so a
  /// shared device never filters one person's chat with someone else's list.
  bool _syncUser() {
    final current = _store.currentUserId;
    if (current == _userId) return current != null;
    _userId = current;
    _blocked.clear();
    _isStale = false;
    _hasLoaded = false;
    notifyListeners();
    return current != null;
  }

  Future<void> refresh() {
    return _inFlight ??= _refresh().whenComplete(() => _inFlight = null);
  }

  Future<void> _refresh() async {
    if (!_syncUser()) return;
    final userId = _userId!;
    if (!_hasLoaded) await _loadCache(userId);
    await _uploadLegacyBlocks(userId);
    try {
      final server = await _store.fetchBlockedIds(userId);
      if (userId != _userId) return;
      _blocked
        ..clear()
        ..addAll(server);
      _isStale = false;
      _hasLoaded = true;
      await _writeCache(userId);
    } catch (e) {
      debugPrint('ChatBlockList: refresh failed: $e');
      _isStale = true;
    }
    notifyListeners();
  }

  Future<void> block(String profileId) async {
    if (!_syncUser()) {
      throw const ChatBlockException(ChatBlockFailure.signedOut);
    }
    final userId = _userId!;
    if (profileId == userId) {
      throw const ChatBlockException(ChatBlockFailure.notPermitted);
    }
    try {
      await _store.insertBlock(userId, profileId);
    } catch (e) {
      final failure = _classify(e);
      // A duplicate means the server already holds this block, which is the
      // outcome the caller asked for.
      if (failure != null) throw ChatBlockException(failure);
    }
    if (userId != _userId) return;
    _blocked.add(profileId);
    await _writeCache(userId);
    notifyListeners();
  }

  Future<void> unblock(String profileId) async {
    if (!_syncUser()) {
      throw const ChatBlockException(ChatBlockFailure.signedOut);
    }
    final userId = _userId!;
    try {
      await _store.deleteBlock(userId, profileId);
    } catch (e) {
      throw ChatBlockException(_classify(e) ?? ChatBlockFailure.network);
    }
    if (userId != _userId) return;
    _blocked.remove(profileId);
    await _writeCache(userId);
    notifyListeners();
  }

  Future<Map<String, String>> resolveNames(List<String> ids) =>
      _store.resolveNames(ids);

  /// Null means the write already holds on the server (unique violation).
  ChatBlockFailure? _classify(Object e) {
    if (e is PostgrestException) {
      switch (e.code) {
        case '23505':
          return null;
        case '23503':
          return ChatBlockFailure.targetGone;
        case '42501':
        case '23514':
          return ChatBlockFailure.notPermitted;
      }
      if (e.message.contains('row-level security')) {
        return ChatBlockFailure.notPermitted;
      }
    }
    return ChatBlockFailure.network;
  }

  Future<void> _loadCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('$cachePrefsPrefix$userId');
      if (cached != null && userId == _userId) {
        _blocked.addAll(cached);
        _isStale = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ChatBlockList: cache read failed: $e');
    }
  }

  Future<void> _writeCache(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('$cachePrefsPrefix$userId', _blocked.toList());
    } catch (e) {
      debugPrint('ChatBlockList: cache write failed: $e');
    }
  }

  Future<void> _uploadLegacyBlocks(String userId) async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }
    final key = '$legacyPrefsPrefix$userId';
    final legacy = prefs.getStringList(key);
    if (legacy == null) return;
    var allHeld = true;
    for (final id in legacy) {
      if (id == userId) continue;
      try {
        await _store.insertBlock(userId, id);
      } catch (e) {
        final failure = _classify(e);
        // A deleted target has nothing left to block; keep retrying the rest.
        if (failure != null && failure != ChatBlockFailure.targetGone) {
          allHeld = false;
        }
      }
    }
    if (allHeld) await prefs.remove(key);
  }

  @visibleForTesting
  void debugReset() {
    _userId = null;
    _blocked.clear();
    _isStale = false;
    _hasLoaded = false;
    _inFlight = null;
  }
}
