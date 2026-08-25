import 'package:flutter/foundation.dart';

/// Public/Private access tier for a broadcast (client-side simulated -- see
/// AppProvider's Private & Restricted Streaming state; there is no
/// stream_attendees DB table backing this, matching the rest of the
/// live-streaming subsystem which is likewise simulated end-to-end).
enum StreamVisibility { public, private }

/// A viewer's own relationship to the currently-active private stream.
enum ViewerAccessState {
  notApplicable,
  vipPreApproved,
  knocking,
  admitted,
  denied,
}

@immutable
class StreamKnockRequest {
  final String id;
  final String displayName;
  final DateTime requestedAt;

  const StreamKnockRequest({
    required this.id,
    required this.displayName,
    required this.requestedAt,
  });
}

@immutable
class StreamAttendee {
  final String id;
  final String displayName;
  final bool isVip;

  const StreamAttendee({
    required this.id,
    required this.displayName,
    this.isVip = false,
  });
}
