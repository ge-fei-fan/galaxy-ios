class MqttMessageEntry {
  MqttMessageEntry({
    required this.topic,
    required this.payload,
    required this.timestamp,
  });

  final String topic;
  final String payload;
  final DateTime timestamp;

  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static MqttMessageEntry fromMap(Map<dynamic, dynamic> map) {
    return MqttMessageEntry(
      topic: map['topic'] as String? ?? '',
      payload: map['payload'] as String? ?? '',
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
