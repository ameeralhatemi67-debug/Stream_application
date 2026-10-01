import 'package:flutter/foundation.dart';

@immutable
class BroadcastDestination {
  const BroadcastDestination({required this.connectionId, required this.channelId,
    required this.title, this.organizationId});
  final String connectionId;
  final String channelId;
  final String title;
  final String? organizationId;
}

@immutable
class BroadcastSession {
  const BroadcastSession({required this.id,required this.presenterId,required this.organizationId,
    required this.state,required this.revision,required this.titleEn,required this.titleAr,required this.broadcastType,
    required this.startUtc,required this.endUtc,required this.accepted,required this.watchId,required this.replayStatus,
    required this.terminationPending,required this.channelConnectionId,this.scheduleId,this.venueId});
  final String id,presenterId,state,titleEn,titleAr,broadcastType,replayStatus;
  final String? organizationId,watchId,channelConnectionId,scheduleId,venueId;
  final int revision;
  final DateTime? startUtc,endUtc;
  final bool accepted,terminationPending;
  bool get live => state=='live';
  bool get active => ['preparing','live','ending'].contains(state);
  bool get frozen => channelConnectionId!=null;
  String title(String language) => language=='ar' ? (titleAr.isEmpty?titleEn:titleAr) : (titleEn.isEmpty?titleAr:titleEn);
  factory BroadcastSession.fromRow(Map<String,dynamic> row) => BroadcastSession(
    id:row['id'] as String,presenterId:row['owner_id'] as String,organizationId:row['org_id'] as String?,
    state:row['state'] as String,revision:(row['revision'] as num).toInt(),titleEn:row['title_en'] as String? ?? '',
    titleAr:row['title_ar'] as String? ?? '',broadcastType:row['broadcast_type'] as String,
    startUtc:DateTime.tryParse(row['scheduled_start_at'] as String? ?? '')?.toUtc(),
    endUtc:DateTime.tryParse(row['expected_end_at'] as String? ?? '')?.toUtc(),accepted:row['accepted_at']!=null,
    watchId:row['stream_id'] as String?,replayStatus:row['replay_status'] as String? ?? 'not_started',
    terminationPending:row['termination_pending']==true,channelConnectionId:row['channel_connection_id'] as String?,
    scheduleId:row['schedule_id'] as String?,venueId:row['venue_id'] as String?);
}
