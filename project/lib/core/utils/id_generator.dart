import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generates a v4 UUID string, for any client-created id that must match a
/// Postgres `uuid` primary key (broadcaster_applications, audit_logs,
/// affiliation_requests, org_venues, org_speakers, ...). Replaces the old
/// `'prefix_${DateTime.now().millisecondsSinceEpoch}'` id pattern, which
/// Postgres's `uuid` columns reject.
String newId() => _uuid.v4();
