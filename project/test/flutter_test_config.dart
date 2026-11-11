import 'dart:async';

import 'package:streamer_app/core/routing/app_router.dart';

/// Runs once for each test file, before its tests.
///
/// Pages that the router loads when they are first opened are loaded here.
/// Without this, the second such page a test file opens never leaves its
/// loading frame: the Dart VM finishes the load in the zone of an earlier
/// test.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await AppRouter.preloadDeferredPages();
  await testMain();
}
