class ChannelConnection {
  const ChannelConnection({required this.id,required this.ownerId,required this.organizationId,
    required this.channelId,required this.title,required this.status,required this.revision});
  final String id;
  final String ownerId;
  final String? organizationId;
  final String channelId;
  final String title;
  final String status;
  final int revision;
  bool get connected => status == 'connected';
  factory ChannelConnection.fromRow(Map<String,dynamic> row) => ChannelConnection(
    id:row['id'] as String,ownerId:row['owner_profile_id'] as String,
    organizationId:row['organization_id'] as String?,channelId:row['youtube_channel_id'] as String,
    title:row['channel_title'] as String,status:row['status'] as String,
    revision:(row['revision'] as num).toInt());
}
