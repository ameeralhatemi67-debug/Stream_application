# Flutter Code Critic Report: Optimization & Architectural Review

**Author:** Senior Flutter Developer & Code Optimization Architect  
**Target:** Educational Cloud Streaming Application (AlSharqia Region Phase 1)  
**Date:** August 2026

---

## 1. Architectural & Performance Analysis

### A. State Management Inefficiency in `AppProvider`
* **Issue:** `AppProvider` functions as a monolithic global state container holding application settings, filters, streamer models, *and* highly volatile real-time state (`_chatMessages`).
* **Impact:** Calling `addChatMessage()` every 4–7 seconds via the ghost audience injection timer triggers `notifyListeners()`, which forces a rebuild of **every widget listening to `AppProvider`**. Screens using `context.watch<AppProvider>()` (such as `SpatialMapScreen` and `DiscoveryFeedScreen`) continuously re-render off-screen during a live stream session, causing unnecessary CPU cycles and battery drain.

### B. Widget Re-render & Routing Performance (`app_router.dart`)
* **Issue:** While `StatefulShellRoute.indexedStack` preserves map state when switching tabs, when `LiveBroadcastScreen` is pushed to the root navigator, the underlying map continues to live in memory. Combined with monolithic `AppProvider` notifications, the heavy `FlutterMap` widget continuously re-paints off-screen.

### C. Memory Management & Wakelock Lifecycle
* **Issue:** In `LiveBroadcastScreen`, `WakelockPlus.enable()` is called in `initState()` and `disable()` in `dispose()`.
* **Impact:** If the user minimizes the app (sending it to the background) while watching a stream, the Wakelock hardware keep-awake remains active, draining battery. `WidgetsBindingObserver` should be implemented to release the wakelock during `AppLifecycleState.paused`.

### D. Unhandled Exceptions & Error Handling Gaps
1. **`StateError` from `firstWhere`:** In `LiveBroadcastScreen.build`, catching all exceptions `catch (_)` can swallow unrelated errors.
2. **SVG Memory Usage:** In `SpatialMapScreen`, the raw SVG string (`_svgRawData`) is loaded into memory at startup but only checked to toggle a UI badge. Passing it to a pre-compiled `Path` cache avoids redundant string retainment.

---

## 2. Refactoring Recommendations & Code Snippets

### Refactoring 1: Extract Volatile Chat State into `ChatProvider`
Decouple `chatMessages` from `AppProvider` to prevent global map/feed rebuilds when a new chat comment arrives:

```dart
class ChatProvider extends ChangeNotifier {
  List<GhostComment> _chatMessages = [];
  List<GhostComment> get chatMessages => List.unmodifiable(_chatMessages);

  void addChatMessage(GhostComment comment) {
    _chatMessages.insert(0, comment);
    notifyListeners(); // Only rebuilds chat UI, not the map!
  }

  void clearChatMessages() {
    _chatMessages.clear();
    notifyListeners();
  }
}
```

### Refactoring 2: Granular Selectors with `context.select`
In `SpatialMapScreen` and `DiscoveryFeedScreen`, do not watch the full provider. Use `context.select`:

```dart
// Efficient granular selector:
final activeCategoryFilter = context.select<AppProvider, String>(
  (provider) => provider.currentCategoryFilter
);

final displayedStreamers = context.select<AppProvider, List<StreamerModel>>(
  (provider) => provider.streamers.where((s) => 
    activeCategoryFilter == 'all' || s.categoryId == activeCategoryFilter
  ).toList()
);
```

### Refactoring 3: Wakelock Lifecycle with `WidgetsBindingObserver`
Implement `WidgetsBindingObserver` to manage hardware state when backgrounded:

```dart
class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      WakelockPlus.disable();
    } else if (state == AppLifecycleState.resumed) {
      WakelockPlus.enable();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }
}
```

### Refactoring 4: Use `firstWhereOrNull` for Safe Null Handling
Replace `try/catch` with `firstWhereOrNull` from the `collection` package:

```dart
import 'package:collection/collection.dart';

final streamer = appProvider.streamers.firstWhereOrNull(
  (s) => s.activeStreamId == widget.streamId || s.streamerId == widget.streamId,
) ?? appProvider.activeStreamer;
```
