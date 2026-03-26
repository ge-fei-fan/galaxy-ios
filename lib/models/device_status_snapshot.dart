class DeviceStatusSnapshot {
  const DeviceStatusSnapshot({
    required this.deviceName,
    required this.systemVersion,
    required this.modelIdentifier,
    required this.chip,
    required this.storageTotalBytes,
    required this.storageUsedBytes,
    required this.memoryTotalBytes,
    required this.memoryUsedBytes,
    required this.cpuUsagePercent,
    required this.batteryLevelPercent,
    required this.batteryState,
    required this.networkConnected,
    required this.networkType,
    required this.downloadSpeedBytesPerSec,
    required this.uploadSpeedBytesPerSec,
    required this.downloadTotalBytes,
    required this.uploadTotalBytes,
    required this.uptimeSeconds,
    required this.bootAt,
    required this.retrievedAt,
  });

  final String? deviceName;
  final String? systemVersion;
  final String? modelIdentifier;
  final String? chip;
  final int? storageTotalBytes;
  final int? storageUsedBytes;
  final int? memoryTotalBytes;
  final int? memoryUsedBytes;
  final double? cpuUsagePercent;
  final double? batteryLevelPercent;
  final String? batteryState;
  final bool? networkConnected;
  final String? networkType;
  final double? downloadSpeedBytesPerSec;
  final double? uploadSpeedBytesPerSec;
  final double? downloadTotalBytes;
  final double? uploadTotalBytes;
  final int? uptimeSeconds;
  final DateTime? bootAt;
  final DateTime retrievedAt;

  static DeviceStatusSnapshot fromMap(Map<dynamic, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return DeviceStatusSnapshot(
      deviceName: map['deviceName'] as String?,
      systemVersion: map['systemVersion'] as String?,
      modelIdentifier: map['modelIdentifier'] as String?,
      chip: map['chip'] as String?,
      storageTotalBytes: parseInt(map['storageTotalBytes']),
      storageUsedBytes: parseInt(map['storageUsedBytes']),
      memoryTotalBytes: parseInt(map['memoryTotalBytes']),
      memoryUsedBytes: parseInt(map['memoryUsedBytes']),
      cpuUsagePercent: parseDouble(map['cpuUsagePercent']),
      batteryLevelPercent: parseDouble(map['batteryLevelPercent']),
      batteryState: map['batteryState'] as String?,
      networkConnected: map['networkConnected'] as bool?,
      networkType: map['networkType'] as String?,
      downloadSpeedBytesPerSec: parseDouble(map['downloadSpeedBytesPerSec']),
      uploadSpeedBytesPerSec: parseDouble(map['uploadSpeedBytesPerSec']),
      downloadTotalBytes: parseDouble(map['downloadTotalBytes']),
      uploadTotalBytes: parseDouble(map['uploadTotalBytes']),
      uptimeSeconds: parseInt(map['uptimeSeconds']),
      bootAt: parseDate(map['bootAt']),
      retrievedAt: DateTime.now(),
    );
  }
}