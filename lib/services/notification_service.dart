import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 调试日志列表，用于在界面上展示
  final List<String> debugLogs = [];

  void log(String message) {
    final time = DateTime.now().toLocal().toString().substring(11, 19);
    debugLogs.add('[$time] $message');
    // 最多保留 100 条日志
    if (debugLogs.length > 100) {
      debugLogs.removeAt(0);
    }
  }

  void clearLogs() {
    debugLogs.clear();
  }

  Future<void> init() async {
    try {
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initializationSettings = InitializationSettings(
        iOS: iosSettings,
      );
      final initResult = await _plugin.initialize(initializationSettings);
      log('插件初始化结果: $initResult');

      final permResult = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      log('权限请求结果: $permResult');
    } catch (e) {
      log('初始化异常: $e');
    }
  }

  Future<String> showMessage(String topic, String payload) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      log('发送通知 id=$id');
      const details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(id, 'MQTT: $topic', payload, details);
      log('通知发送成功');
      return '✅ 通知发送成功 (id=$id)';
    } catch (e) {
      log('通知发送异常: $e');
      return '❌ 通知发送失败: $e';
    }
  }
}
