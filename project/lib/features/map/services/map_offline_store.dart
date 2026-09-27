/// Browser offline-preparation state. Native apps never use this: the map
/// pack ships inside the installed app and is always available offline.
enum WebOfflineState {
  /// Nothing prepared yet (or the user reset it). The map still works while
  /// the site is reachable.
  notPrepared,

  /// Copying the app shell and the complete map into browser storage.
  preparing,

  /// Shell and complete map are stored; a later visit can start offline.
  ready,

  /// Preparation was recorded but the browser has since removed stored
  /// files (eviction, cleared site data). Needs preparing again.
  evicted,

  /// The last preparation failed (quota, private window, network drop).
  failed,

  /// This browser has no Cache Storage / service worker support.
  unsupported,
}

class WebOfflineStatus {
  const WebOfflineStatus(this.state,
      {this.preparedAt, this.detail, this.done = 0, this.total = 0});

  final WebOfflineState state;
  final DateTime? preparedAt;

  /// Stable, untranslated reason code for [WebOfflineState.failed]
  /// (`quota`, `network`, `mismatch`, `incomplete`, `unsupported`,
  /// `private`), mapped to localized copy by the UI.
  final String? detail;
  final int done;
  final int total;
}

/// Stores the web app shell plus the complete map pack for offline starts.
abstract class WebOfflineMapStore {
  Future<WebOfflineStatus> inspect({required String packSha256});

  /// Fetches every required file from the network (never from the old
  /// offline copy), verifies the pack at [packAssetKey] against
  /// [packSha256], and replaces the live copy and its readiness record only
  /// after everything succeeded. An interrupted run is never reported as
  /// ready and leaves an existing offline copy untouched.
  Future<WebOfflineStatus> prepare({
    required String packSha256,
    required String packAssetKey,
    required List<String> requiredAssetKeys,
    required int packBytes,
    void Function(int done, int total)? onProgress,
  });

  /// Removes only this app's offline-map cache.
  Future<void> reset();
}
