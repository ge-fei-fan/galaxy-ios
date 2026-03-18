class MqttProfile {
  const MqttProfile({
    required this.id,
    required this.name,
    required this.remark,
    required this.host,
    required this.port,
    required this.useTls,
    required this.clientId,
    required this.topics,
    this.username,
    this.password,
    this.keepAliveInBackground = true,
  });

  final String id;
  final String name;
  final String remark;
  final String host;
  final int port;
  final bool useTls;
  final String clientId;
  final List<String> topics;
  final String? username;
  final String? password;
  final bool keepAliveInBackground;

  MqttProfile copyWith({
    String? id,
    String? name,
    String? remark,
    String? host,
    int? port,
    bool? useTls,
    String? clientId,
    List<String>? topics,
    String? username,
    String? password,
    bool? keepAliveInBackground,
  }) {
    return MqttProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      remark: remark ?? this.remark,
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      clientId: clientId ?? this.clientId,
      topics: topics ?? this.topics,
      username: username ?? this.username,
      password: password ?? this.password,
      keepAliveInBackground: keepAliveInBackground ?? this.keepAliveInBackground,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'remark': remark,
      'host': host,
      'port': port,
      'useTls': useTls,
      'clientId': clientId,
      'topics': topics,
      'username': username,
      'password': password,
      'keepAliveInBackground': keepAliveInBackground,
    };
  }

  static MqttProfile fromMap(Map<dynamic, dynamic> map) {
    return MqttProfile(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '未命名',
      remark: map['remark'] as String? ?? '',
      host: map['host'] as String? ?? 'test.mosquitto.org',
      port: (map['port'] as num?)?.toInt() ?? 1883,
      useTls: map['useTls'] as bool? ?? false,
      clientId: map['clientId'] as String? ?? 'flutter_mqtt_client',
      topics: (map['topics'] as List?)?.whereType<String>().toList() ?? const [],
      username: map['username'] as String?,
      password: map['password'] as String?,
      keepAliveInBackground: map['keepAliveInBackground'] as bool? ?? true,
    );
  }
}
