import 'dart:convert';

/// Represents an active device session associated with a user/broadcaster account.
/// Used to manage multi-device sign-ins, prevent unauthorized stream takeovers,
/// and allow users to pick or transfer active broadcaster rights between devices.
class DeviceSessionModel {
  final String deviceId;
  final String deviceName;
  final String platform;
  final DateTime lastActiveAt;
  final bool isPrimaryBroadcaster;
  final String? ipAddress;

  const DeviceSessionModel({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.lastActiveAt,
    this.isPrimaryBroadcaster = true,
    this.ipAddress,
  });

  DeviceSessionModel copyWith({
    String? deviceId,
    String? deviceName,
    String? platform,
    DateTime? lastActiveAt,
    bool? isPrimaryBroadcaster,
    String? ipAddress,
  }) {
    return DeviceSessionModel(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      isPrimaryBroadcaster: isPrimaryBroadcaster ?? this.isPrimaryBroadcaster,
      ipAddress: ipAddress ?? this.ipAddress,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'device_name': deviceName,
      'platform': platform,
      'last_active_at': lastActiveAt.toIso8601String(),
      'is_primary_broadcaster': isPrimaryBroadcaster,
      'ip_address': ipAddress,
    };
  }

  factory DeviceSessionModel.fromJson(Map<String, dynamic> json) {
    return DeviceSessionModel(
      deviceId: json['device_id'] as String? ?? 'unknown_device',
      deviceName: json['device_name'] as String? ?? 'Unknown Device',
      platform: json['platform'] as String? ?? 'unknown',
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isPrimaryBroadcaster: json['is_primary_broadcaster'] as bool? ?? true,
      ipAddress: json['ip_address'] as String?,
    );
  }

  String serialize() => jsonEncode(toJson());

  static DeviceSessionModel? deserialize(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return DeviceSessionModel.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DeviceSessionModel &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() =>
      'DeviceSessionModel(deviceId: $deviceId, deviceName: $deviceName, platform: $platform, isPrimaryBroadcaster: $isPrimaryBroadcaster)';
}
