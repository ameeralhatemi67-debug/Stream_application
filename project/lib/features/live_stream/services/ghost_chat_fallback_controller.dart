import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/ghost_comments.dart';

/// Drives the offline/disconnected chat fallback (Checkpoint 4): when
/// LiveChatController can't reach Realtime, this injects comments from
/// GhostCommentPool every 4-7 seconds -- matching the pool's own stated
/// intent ("Injecting localized EN & AR comments every 4-7 seconds during
/// live pitch demonstrations") -- so the chat tab shows something instead of
/// sitting empty. Purely simulated content; the caller is responsible for
/// showing a visible "Demo Mode" indicator alongside it so it's never
/// mistaken for real traffic (see live_broadcast_screen.dart).
class GhostChatFallbackController extends ChangeNotifier {
  GhostChatFallbackController({required this.streamId});

  final String streamId;
  static final _random = Random();

  final List<GhostComment> _messages = [];
  List<GhostComment> get messages => List.unmodifiable(_messages);

  Timer? _timer;
  bool get isActive => _timer != null;

  /// Seeds a handful of comments immediately (so the fallback isn't empty on
  /// the first frame) and starts injecting new ones on a 4-7s cadence.
  /// No-op if already running.
  void start() {
    if (_timer != null) return;
    _messages
      ..clear()
      ..addAll(GhostCommentPool.rawComments.take(6));
    notifyListeners();
    _scheduleNext();
  }

  void _scheduleNext() {
    final delay = Duration(seconds: 4 + _random.nextInt(4));
    _timer = Timer(delay, () {
      _messages.add(GhostCommentPool.getRandomComment(streamId: streamId));
      // Bounded so a long-running disconnect doesn't grow this forever.
      if (_messages.length > 50) _messages.removeAt(0);
      notifyListeners();
      _scheduleNext();
    });
  }

  /// Stops injecting and clears the fallback content -- called the moment
  /// Realtime reconnects, so stale demo messages never linger once real chat
  /// resumes.
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (_messages.isNotEmpty) {
      _messages.clear();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
