import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'package:galaxy_ios/models/mqtt_message_entry.dart';
import 'package:galaxy_ios/models/mqtt_profile.dart';
import 'package:galaxy_ios/services/notification_service.dart';

class MqttController extends ChangeNotifier with WidgetsBindingObserver {
  MqttController();

  final NotificationService _notificationService = NotificationService();
  final Box _settingsBox = Hive.box('settings');
  final Box _topicsBox = Hive.box('topics');
  final Box _messagesBox = Hive.box('messages');
  final Box _profilesBox = Hive.box('profiles');

  static const _channel = MethodChannel('com.galaxy/background_keep_alive');

  bool initialized = false;

  bool connected = false;
  String status = '未连接';

  List<MqttProfile> profiles = [];
  String? activeProfileId;

  MqttProfile? get activeProfile {
    final id = activeProfileId;
    if (id == null) return null;
    return profiles.where((p) => p.id == id).firstOrNull;
  }

  List<String> topics = [];
  String? selectedTopic;
  Map<String, List<MqttMessageEntry>> messagesByTopic = {};
  final Map<String, List<String>> _topicsByProfile = {};
  final Map<String, Map<String, List<MqttMessageEntry>>> _messagesByProfile =
      {};

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  bool _isExplicitDisconnect = false;
  int _reconnectDelaySeconds = 2;
  Timer? _reconnectTimer;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    // 监听原生日志回传
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'log') {
        final String message = call.arguments as String;
        _notificationService.log('Native: $message');
        notifyListeners();
      }
    });

    _loadProfilesWithMigration();
    _loadTopics();
    _loadMessages();
    _syncActiveProfileData();

    await _notificationService.init();

    // 延迟一点时间再同步保活状态给原生，确保原生 MethodChannel 已准备完毕
    Future.delayed(const Duration(milliseconds: 500), () {
      _syncKeepAliveStateToNative();
    });

    initialized = true;
    notifyListeners();
  }

  void _loadProfilesWithMigration() {
    // 新结构：profiles box
    final storedProfiles = _profilesBox.get('profiles');
    if (storedProfiles is List) {
      profiles = storedProfiles
          .whereType<Map>()
          .map(MqttProfile.fromMap)
          .where((p) => p.id.isNotEmpty)
          .toList();
    }

    final storedActive = _profilesBox.get('activeProfileId');
    if (storedActive is String && storedActive.isNotEmpty) {
      activeProfileId = storedActive;
    }

    // 兼容迁移：旧 settings->config
    if (profiles.isEmpty) {
      final old = _settingsBox.get('config');
      if (old is Map) {
        final migrated = MqttProfile(
          id: _newId(),
          name: '默认配置',
          remark: '',
          host: old['host'] as String? ?? 'test.mosquitto.org',
          port: (old['port'] as num?)?.toInt() ?? 1883,
          useTls: old['useTls'] as bool? ?? false,
          clientId: old['clientId'] as String? ?? 'flutter_mqtt_client',
          username: old['username'] as String?,
          password: old['password'] as String?,
          keepAliveInBackground: true,
          topics: const [],
        );
        profiles = [migrated];
        activeProfileId = migrated.id;
        _persistProfiles();
      }
    }

    // 兜底：还是没有就创建一个默认
    if (profiles.isEmpty) {
      final fallback = MqttProfile(
        id: _newId(),
        name: '默认配置',
        remark: '',
        host: 'test.mosquitto.org',
        port: 1883,
        useTls: false,
        clientId: 'flutter_mqtt_client',
        username: null,
        password: null,
        keepAliveInBackground: true,
        topics: const [],
      );
      profiles = [fallback];
      activeProfileId = fallback.id;
      _persistProfiles();
    }

    // active 不存在时，默认第一条
    if (activeProfileId == null ||
        profiles.every((p) => p.id != activeProfileId)) {
      activeProfileId = profiles.first.id;
      _profilesBox.put('activeProfileId', activeProfileId);
    }
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _persistProfiles() async {
    await _profilesBox.put('profiles', profiles.map((e) => e.toMap()).toList());
    await _profilesBox.put('activeProfileId', activeProfileId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 从后台回到前台时，如果发现意外断开，并且不是用户主动断开，则立即重试重连
      if (!connected && !_isExplicitDisconnect && _client != null) {
        _reconnectDelaySeconds = 2; // 重置退避延迟
        _scheduleReconnect();
      }
      // 回到前台时，也同步一次保活状态以防止原生状态丢失
      unawaited(_syncKeepAliveStateToNative());
    } else if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // 在应用即将被挂起/进入后台时，再强行同步一次状态给原生
      unawaited(_syncKeepAliveStateToNative());
    }
  }

  Future<void> _syncKeepAliveStateToNative() async {
    try {
      final keepAlive = activeProfile?.keepAliveInBackground ?? true;
      if (keepAlive) {
        await _channel.invokeMethod('enableKeepAlive');
        _notificationService.log('Flutter: 已通知原生启用保活');
      } else {
        await _channel.invokeMethod('disableKeepAlive');
        _notificationService.log('Flutter: 已通知原生禁用保活');
      }
    } catch (e) {
      _notificationService.log('Flutter: 同步保活状态失败: $e');
      debugPrint('Sync keep alive state failed: $e');
    }
  }

  Future<void> addProfile(MqttProfile profile) async {
    profiles = [...profiles, profile];
    activeProfileId = profile.id;
    await _persistProfiles();
    await _syncKeepAliveStateToNative();
    _syncActiveProfileData();
    notifyListeners();
  }

  Future<void> updateProfile(MqttProfile profile) async {
    profiles = profiles.map((p) => p.id == profile.id ? profile : p).toList();
    await _persistProfiles();
    await _syncKeepAliveStateToNative();
    _syncActiveProfileData();
    notifyListeners();
  }

  Future<void> deleteProfile(String id) async {
    if (profiles.length <= 1) return;
    if (connected && activeProfileId == id) {
      disconnect();
    }
    profiles = profiles.where((p) => p.id != id).toList();
    _topicsByProfile.remove(id);
    _messagesByProfile.remove(id);
    if (activeProfileId == id) {
      activeProfileId = profiles.first.id;
    }
    await _persistProfiles();
    await _persistTopics();
    await _persistMessages();
    await _syncKeepAliveStateToNative();
    _syncActiveProfileData();
    notifyListeners();
  }

  Future<void> selectProfile(String id) async {
    if (activeProfileId == id) return;
    if (connected) {
      disconnect();
    }
    activeProfileId = id;
    await _profilesBox.put('activeProfileId', activeProfileId);
    await _syncKeepAliveStateToNative();
    _syncActiveProfileData();
    notifyListeners();
  }

  Future<void> connect() async {
    if (connected) return;
    final profile = activeProfile;
    if (profile == null) {
      status = '未选择配置';
      notifyListeners();
      return;
    }

    _isExplicitDisconnect = false;
    _reconnectTimer?.cancel();

    status = '连接中...';
    notifyListeners();

    _client = MqttServerClient(profile.host, profile.clientId)
      ..port = profile.port
      ..secure = profile.useTls
      ..logging(on: false)
      ..keepAlivePeriod = 20
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected
      ..onSubscribed = _handleSubscribed
      ..onSubscribeFail = _handleSubscribeFail;

    final connectMessage =
        MqttConnectMessage().withClientIdentifier(profile.clientId).startClean();

    if ((profile.username ?? '').isNotEmpty) {
      connectMessage.authenticateAs(profile.username!, profile.password ?? '');
    }

    _client!.connectionMessage = connectMessage;

    try {
      await _client!.connect();
    } catch (error) {
      status = '连接失败: $error';
      connected = false;
      _client?.disconnect();
      notifyListeners();
      _scheduleReconnect();
      return;
    }

    final state = _client!.connectionStatus?.state;
    if (state != MqttConnectionState.connected) {
      status = '连接失败: ${_client!.connectionStatus?.returnCode}';
      connected = false;
      _client?.disconnect();
      notifyListeners();
      _scheduleReconnect();
      return;
    }

    connected = true;
    _reconnectDelaySeconds = 2; // 连接成功后重置退避延迟
    status = '已连接';
    _listenToMessages();
    for (final topic in topics) {
      subscribe(topic);
    }
    notifyListeners();
  }

  Future<void> connectProfile(String id) async {
    if (activeProfileId == id && connected) return;
    if (connected) {
      disconnect();
    }
    await selectProfile(id);
    await connect();
  }

  void disconnect() {
    _isExplicitDisconnect = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    connected = false;
    status = '已断开';
    unawaited(_endMqttLiveActivity());
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_isExplicitDisconnect) return;

    _reconnectTimer?.cancel();
    status = '$_reconnectDelaySeconds 秒后重连...';
    notifyListeners();

    _reconnectTimer = Timer(Duration(seconds: _reconnectDelaySeconds), () {
      if (_isExplicitDisconnect) return;
      connect();
      // 指数退避，上限为 64 秒
      if (_reconnectDelaySeconds < 64) {
        _reconnectDelaySeconds *= 2;
      }
    });
  }

  Future<void> addTopic(String topic) async {
    final trimmed = topic.trim();
    if (trimmed.isEmpty || topics.contains(trimmed)) return;
    topics.add(trimmed);
    selectedTopic ??= trimmed;
    _setTopicsForActiveProfile(topics);
    await _persistTopics();
    notifyListeners();
    if (connected) {
      subscribe(trimmed);
    }
  }

  Future<void> removeTopic(String topic) async {
    topics.remove(topic);
    messagesByTopic.remove(topic);
    if (selectedTopic == topic) {
      selectedTopic = topics.isNotEmpty ? topics.first : null;
    }
    _setTopicsForActiveProfile(topics);
    _setMessagesForActiveProfile(messagesByTopic);
    await _persistTopics();
    await _persistMessages();
    notifyListeners();
  }

  void selectTopic(String? topic) {
    selectedTopic = topic;
    notifyListeners();
  }

  void subscribe(String topic) {
    _client?.subscribe(topic, MqttQos.atLeastOnce);
  }

  Future<void> publish(String topic, String payload) async {
    if (!connected || _client == null) {
      status = '未连接，无法发送';
      notifyListeners();
      return;
    }
    final t = topic.trim();
    if (t.isEmpty) {
      status = 'Topic 不能为空';
      notifyListeners();
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(payload);
    _client!.publishMessage(t, MqttQos.atLeastOnce, builder.payload!);
    status = '已发送: $t';
    notifyListeners();
  }

  void _listenToMessages() {
    _subscription?.cancel();
    _subscription = _client?.updates?.listen((messages) {
      final liveActivityEnabled = activeProfile?.enableLiveActivity ?? false;
      for (final msg in messages) {
        final payload = msg.payload as MqttPublishMessage;
        final message = MqttPublishPayload.bytesToStringAsString(
          payload.payload.message,
        );
        final entry = MqttMessageEntry(
          topic: msg.topic,
          payload: message,
          timestamp: DateTime.now(),
        );
        final list = messagesByTopic.putIfAbsent(msg.topic, () => []);
        list.insert(0, entry);
        _notificationService.showMessage(msg.topic, message);
        unawaited(
          _syncIncomingMessageToNative(
            entry,
            enableLiveActivity: liveActivityEnabled,
          ),
        );
      }
      _setMessagesForActiveProfile(messagesByTopic);
      _persistMessages();
      notifyListeners();
    });
  }

  void _loadTopics() {
    final storedTopicsByProfile = _topicsBox.get('topicsByProfile');
    if (storedTopicsByProfile is Map) {
      for (final entry in storedTopicsByProfile.entries) {
        final id = entry.key.toString();
        final value = entry.value;
        if (value is List) {
          _topicsByProfile[id] = value.whereType<String>().toList();
        }
      }
    }

    // 兼容旧结构：全局 topics
    final legacyTopics = _topicsBox.get('topics');
    if (legacyTopics is List && legacyTopics.isNotEmpty) {
      final activeId = activeProfileId;
      if (activeId != null && (_topicsByProfile[activeId]?.isEmpty ?? true)) {
        _topicsByProfile[activeId] = legacyTopics.whereType<String>().toList();
      }
      _topicsBox.delete('topics');
      _persistTopics();
    }
  }

  void _loadMessages() {
    final storedMessagesByProfile = _messagesBox.get('historyByProfile');
    if (storedMessagesByProfile is Map) {
      for (final entry in storedMessagesByProfile.entries) {
        final id = entry.key.toString();
        final value = entry.value;
        if (value is Map) {
          _messagesByProfile[id] = value.map<String, List<MqttMessageEntry>>(
            (key, msgList) => MapEntry(
              key.toString(),
              (msgList as List?)
                      ?.whereType<Map>()
                      .map(MqttMessageEntry.fromMap)
                      .toList() ??
                  [],
            ),
          );
        }
      }
    }

    // 兼容旧结构：全局 history
    final legacyMessages = _messagesBox.get('history');
    if (legacyMessages is Map && legacyMessages.isNotEmpty) {
      final activeId = activeProfileId;
      if (activeId != null && (_messagesByProfile[activeId]?.isEmpty ?? true)) {
        _messagesByProfile[activeId] = legacyMessages.map<String, List<MqttMessageEntry>>(
          (key, value) => MapEntry(
            key.toString(),
            (value as List?)
                    ?.whereType<Map>()
                    .map(MqttMessageEntry.fromMap)
                    .toList() ??
                [],
          ),
        );
      }
      _messagesBox.delete('history');
      _persistMessages();
    }
  }

  void _syncActiveProfileData() {
    final activeId = activeProfileId;
    if (activeId == null) {
      topics = [];
      selectedTopic = null;
      messagesByTopic = {};
      return;
    }

    final profile = activeProfile;
    if (profile != null) {
      final storedTopics = _topicsByProfile[activeId] ?? const [];
      if (profile.topics.isEmpty && storedTopics.isNotEmpty) {
        _topicsByProfile[activeId] = List<String>.from(storedTopics);
        profiles = profiles
            .map(
              (p) => p.id == activeId
                  ? p.copyWith(topics: List<String>.from(storedTopics))
                  : p,
            )
            .toList();
        _persistProfiles();
      } else {
        _topicsByProfile[activeId] = profile.topics;
      }
    }

    topics = List<String>.from(_topicsByProfile[activeId] ?? const []);
    messagesByTopic = Map<String, List<MqttMessageEntry>>.from(
      _messagesByProfile[activeId] ?? const {},
    );
    if (topics.isNotEmpty) {
      selectedTopic = topics.contains(selectedTopic) ? selectedTopic : topics.first;
    } else {
      selectedTopic = null;
    }
  }

  void _setTopicsForActiveProfile(List<String> updated) {
    final activeId = activeProfileId;
    if (activeId == null) return;
    _topicsByProfile[activeId] = List<String>.from(updated);
    profiles = profiles
        .map(
          (p) => p.id == activeId ? p.copyWith(topics: List<String>.from(updated)) : p,
        )
        .toList();
    _persistProfiles();
  }

  void _setMessagesForActiveProfile(
    Map<String, List<MqttMessageEntry>> updated,
  ) {
    final activeId = activeProfileId;
    if (activeId == null) return;
    _messagesByProfile[activeId] = Map<String, List<MqttMessageEntry>>.from(updated);
  }

  Future<void> _persistTopics() async {
    await _topicsBox.put('topicsByProfile', _topicsByProfile);
  }

  Future<void> _persistMessages() async {
    final payload = _messagesByProfile.map((profileId, topicMap) {
      return MapEntry(
        profileId,
        topicMap.map((topic, list) {
          return MapEntry(topic, list.map((e) => e.toMap()).toList());
        }),
      );
    });
    await _messagesBox.put('historyByProfile', payload);
  }

  void _handleConnected() {
    status = '已连接';
    connected = true;
    notifyListeners();
  }

  void _handleDisconnected() {
    connected = false;
    status = '连接意外断开';
    notifyListeners();

    if (!_isExplicitDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleSubscribed(String topic) {
    status = '订阅成功: $topic';
    notifyListeners();
  }

  void _handleSubscribeFail(String topic) {
    status = '订阅失败: $topic';
    notifyListeners();
  }

  /// 获取通知服务的调试日志
  List<String> get notificationDebugLogs => _notificationService.debugLogs;

  /// 清除调试日志
  void clearLogs() {
    _notificationService.clearLogs();
    notifyListeners();
  }

  /// 最后一次测试通知的结果
  String lastTestResult = '';

  Future<void> sendTestNotification() async {
    final result = await _notificationService.showMessage(
      '测试主题',
      '这是一条测试通知，时间：${DateTime.now().toLocal()}',
    );
    lastTestResult = result;
    notifyListeners();
  }

  /// 触发 iOS Live Activity（灵动岛）演示
  Future<String> startDynamicIslandDemo() async {
    try {
      final result = await _channel.invokeMethod<String>(
        'startDynamicIslandDemo',
      );
      final message = result ?? '已请求启动灵动岛演示';
      _notificationService.log('Flutter: $message');
      return message;
    } catch (e) {
      final message = '启动灵动岛演示失败: $e';
      _notificationService.log('Flutter: $message');
      return message;
    }
  }

  /// 结束 iOS Live Activity（灵动岛）演示
  Future<String> stopDynamicIslandDemo() async {
    try {
      final result = await _channel.invokeMethod<String>('stopDynamicIslandDemo');
      final message = result ?? '已请求结束灵动岛演示';
      _notificationService.log('Flutter: $message');
      return message;
    } catch (e) {
      final message = '结束灵动岛演示失败: $e';
      _notificationService.log('Flutter: $message');
      return message;
    }
  }

  Future<void> _syncIncomingMessageToNative(
    MqttMessageEntry entry, {
    required bool enableLiveActivity,
  }) async {
    try {
      await _channel.invokeMethod<String>('handleIncomingMqttMessage', {
        'topic': entry.topic,
        'payload': entry.payload,
        'updatedAt': _formatTime(entry.timestamp),
        'enableLiveActivity': enableLiveActivity,
      });
    } catch (e) {
      _notificationService.log('Flutter: 同步消息到原生失败: $e');
    }
  }

  Future<void> _endMqttLiveActivity() async {
    try {
      await _channel.invokeMethod<String>('endMqttLiveActivity');
    } catch (e) {
      _notificationService.log('Flutter: 结束灵动岛活动失败: $e');
    }
  }

  String _formatTime(DateTime time) {
    final t = time.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}

extension _FirstOrNullExt<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
