import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:galaxy_ios/models/device_status_snapshot.dart';

class DeviceStatusService {
  DeviceStatusService({Duration interval = const Duration(seconds: 1)})
      : _interval = interval;

  static const MethodChannel _channel =
      MethodChannel('com.galaxy/background_keep_alive');

  final Duration _interval;
  final StreamController<DeviceStatusSnapshot> _controller =
      StreamController<DeviceStatusSnapshot>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Timer? _timer;
  bool _fetching = false;
  bool _pluginUnavailableLogged = false;

  Stream<DeviceStatusSnapshot> get stream => _controller.stream;
  Stream<String> get statusStream => _statusController.stream;

  void start() {
    _statusController.add('连接中');
    _timer ??= Timer.periodic(_interval, (_) => unawaited(_fetchOnce()));
    unawaited(_fetchOnce());
  }

  Future<void> _fetchOnce() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final map = await _channel.invokeMapMethod<dynamic, dynamic>(
        'getDeviceStatusSnapshot',
      );
      if (map == null) {
        _statusController.add('暂无数据');
        return;
      }
      _controller.add(DeviceStatusSnapshot.fromMap(map));
      _statusController.add('已连接');
    } on MissingPluginException {
      _statusController.add('通道未就绪');
      if (!_pluginUnavailableLogged) {
        _pluginUnavailableLogged = true;
        debugPrint('[DeviceStatus] MissingPluginException: 通道尚未注册');
      }
    } on PlatformException {
      _statusController.add('采集异常');
      debugPrint('[DeviceStatus] PlatformException: 读取设备状态失败');
    } finally {
      _fetching = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _statusController.close();
    await _controller.close();
  }
}