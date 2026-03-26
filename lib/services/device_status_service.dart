import 'dart:async';

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

  Timer? _timer;
  bool _fetching = false;

  Stream<DeviceStatusSnapshot> get stream => _controller.stream;

  void start() {
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
      if (map == null) return;
      _controller.add(DeviceStatusSnapshot.fromMap(map));
    } on MissingPluginException {
      // 非 iOS / 插件未注册时忽略
    } on PlatformException {
      // 原生采集失败时忽略，保留上次成功数据
    } finally {
      _fetching = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
    await _controller.close();
  }
}