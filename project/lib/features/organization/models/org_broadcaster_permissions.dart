/// Granular streaming permissions granted to an individual broadcaster within an Organization.
class OrgBroadcasterPermissions {
  final bool canGoLiveVideo;
  final bool canGoAudioOnly;
  final bool canChangeLocation;
  final bool canEditDescription;
  final bool canEditStreamTime;
  final bool canAddExternalLinks;

  const OrgBroadcasterPermissions({
    this.canGoLiveVideo = true,
    this.canGoAudioOnly = true,
    this.canChangeLocation = false,
    this.canEditDescription = true,
    this.canEditStreamTime = false,
    this.canAddExternalLinks = true,
  });

  factory OrgBroadcasterPermissions.fromJson(Map<String, dynamic> json) {
    return OrgBroadcasterPermissions(
      canGoLiveVideo: json['can_go_live_video'] as bool? ?? true,
      canGoAudioOnly: json['can_go_audio_only'] as bool? ?? true,
      canChangeLocation: json['can_change_location'] as bool? ?? false,
      canEditDescription: json['can_edit_description'] as bool? ?? true,
      canEditStreamTime: json['can_edit_stream_time'] as bool? ?? false,
      canAddExternalLinks: json['can_add_external_links'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'can_go_live_video': canGoLiveVideo,
      'can_go_audio_only': canGoAudioOnly,
      'can_change_location': canChangeLocation,
      'can_edit_description': canEditDescription,
      'can_edit_stream_time': canEditStreamTime,
      'can_add_external_links': canAddExternalLinks,
    };
  }

  OrgBroadcasterPermissions copyWith({
    bool? canGoLiveVideo,
    bool? canGoAudioOnly,
    bool? canChangeLocation,
    bool? canEditDescription,
    bool? canEditStreamTime,
    bool? canAddExternalLinks,
  }) {
    return OrgBroadcasterPermissions(
      canGoLiveVideo: canGoLiveVideo ?? this.canGoLiveVideo,
      canGoAudioOnly: canGoAudioOnly ?? this.canGoAudioOnly,
      canChangeLocation: canChangeLocation ?? this.canChangeLocation,
      canEditDescription: canEditDescription ?? this.canEditDescription,
      canEditStreamTime: canEditStreamTime ?? this.canEditStreamTime,
      canAddExternalLinks: canAddExternalLinks ?? this.canAddExternalLinks,
    );
  }
}
