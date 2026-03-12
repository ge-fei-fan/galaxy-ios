import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('topics');
  await Hive.openBox('messages');
  runApp(const MqttApp());
}

class MqttApp extends StatefulWidget {
  const MqttApp({super.key});

  @override
  State<MqttApp> createState() => _MqttAppState();
}

class _MqttAppState extends State<MqttApp> {
  late final MqttController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = MqttController();
    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return MaterialApp(
          title: 'MQTT 客户端',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
            useMaterial3: true,
          ),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('MQTT 客户端 (iOS)'),
              backgroundColor: Theme.of(context).colorScheme.surface,
              foregroundColor: Theme.of(context).colorScheme.onSurface,
            ),
            body: _controller.initialized
                ? IndexedStack(
                    index: _currentIndex,
                    children: [
                      ConfigPage(controller: _controller),
                      TopicsPage(controller: _controller),
                      MessagesPage(controller: _controller),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: '配置',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt),
                  label: '主题',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.message),
                  label: '消息',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MqttConfig {
  const MqttConfig({
    required this.host,
    required this.port,
    required this.useTls,
    required this.clientId,
    this.username,
    this.password,
    this.keepAliveInBackground = false,
  });

  final String host;
  final int port;
  final bool useTls;
  final String clientId;
  final String? username;
  final String? password;
  final bool keepAliveInBackground;

  MqttConfig copyWith({
    String? host,
    int? port,
    bool? useTls,
    String? clientId,
    String? username,
    String? password,
    bool? keepAliveInBackground,
  }) {
    return MqttConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      clientId: clientId ?? this.clientId,
      username: username ?? this.username,
      password: password ?? this.password,
      keepAliveInBackground: keepAliveInBackground ?? this.keepAliveInBackground,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'useTls': useTls,
      'clientId': clientId,
      'username': username,
      'password': password,
      'keepAliveInBackground': keepAliveInBackground,
    };
  }

  static MqttConfig fromMap(Map<dynamic, dynamic> map) {
    return MqttConfig(
      host: map['host'] as String? ?? 'test.mosquitto.org',
      port: (map['port'] as num?)?.toInt() ?? 1883,
      useTls: map['useTls'] as bool? ?? false,
      clientId: map['clientId'] as String? ?? 'flutter_mqtt_client',
      username: map['username'] as String?,
      password: map['password'] as String?,
      keepAliveInBackground: map['keepAliveInBackground'] as bool? ?? false,
    );
  }
}

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
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 调试日志列表，用于在界面上展示
  final List<String> debugLogs = [];

  void _log(String message) {
    final time = DateTime.now().toLocal().toString().substring(11, 19);
    debugLogs.add('[$time] $message');
    // 最多保留 50 条日志
    if (debugLogs.length > 50) {
      debugLogs.removeAt(0);
    }
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
      _log('插件初始化结果: $initResult');

      final permResult = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      _log('权限请求结果: $permResult');
    } catch (e) {
      _log('初始化异常: $e');
    }
  }

  Future<String> showMessage(String topic, String payload) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      _log('发送通知 id=$id');
      const details = NotificationDetails(
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      await _plugin.show(id, 'MQTT: $topic', payload, details);
      _log('通知发送成功');
      return '✅ 通知发送成功 (id=$id)';
    } catch (e) {
      _log('通知发送异常: $e');
      return '❌ 通知发送失败: $e';
    }
  }
}

class MqttController extends ChangeNotifier with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  final Box _settingsBox = Hive.box('settings');
  final Box _topicsBox = Hive.box('topics');
  final Box _messagesBox = Hive.box('messages');

  static const _channel = MethodChannel('com.galaxy/background_keep_alive');

  bool initialized = false;
  bool connected = false;
  String status = '未连接';
  MqttConfig config = const MqttConfig(
    host: 'test.mosquitto.org',
    port: 1883,
    useTls: false,
    clientId: 'flutter_mqtt_client',
    keepAliveInBackground: false,
  );
  List<String> topics = [];
  String? selectedTopic;
  Map<String, List<MqttMessageEntry>> messagesByTopic = {};

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  bool _isExplicitDisconnect = false;
  int _reconnectDelaySeconds = 2;
  Timer? _reconnectTimer;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final storedConfig = _settingsBox.get('config');
    if (storedConfig is Map) {
      config = MqttConfig.fromMap(storedConfig);
    }
    final storedTopics = _topicsBox.get('topics');
    if (storedTopics is List) {
      topics = storedTopics.whereType<String>().toList();
    }
    final storedMessages = _messagesBox.get('history');
    if (storedMessages is Map) {
      messagesByTopic = storedMessages.map<String, List<MqttMessageEntry>>(
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
    if (topics.isNotEmpty) {
      selectedTopic = topics.first;
    }
    await _notificationService.init();
    
    // 同步保活状态给原生
    await _syncKeepAliveStateToNative();
    
    initialized = true;
    notifyListeners();
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
    }
  }

  Future<void> _syncKeepAliveStateToNative() async {
    try {
      if (config.keepAliveInBackground) {
        await _channel.invokeMethod('enableKeepAlive');
      } else {
        await _channel.invokeMethod('disableKeepAlive');
      }
    } catch (e) {
      debugPrint('Sync keep alive state failed: $e');
    }
  }

  Future<void> saveConfig(MqttConfig newConfig) async {
    final oldKeepAlive = config.keepAliveInBackground;
    config = newConfig;
    await _settingsBox.put('config', config.toMap());
    if (oldKeepAlive != config.keepAliveInBackground) {
      await _syncKeepAliveStateToNative();
    }
    notifyListeners();
  }

  Future<void> connect() async {
    if (connected) return;
    _isExplicitDisconnect = false;
    _reconnectTimer?.cancel();
    
    status = '连接中...';
    notifyListeners();

    _client = MqttServerClient(config.host, config.clientId)
      ..port = config.port
      ..secure = config.useTls
      ..logging(on: false)
      ..keepAlivePeriod = 20
      ..onConnected = _handleConnected
      ..onDisconnected = _handleDisconnected
      ..onSubscribed = _handleSubscribed
      ..onSubscribeFail = _handleSubscribeFail;

    final connectMessage = MqttConnectMessage()
        .withClientIdentifier(config.clientId)
        .startClean()
        .keepAliveFor(20);

    if ((config.username ?? '').isNotEmpty) {
      connectMessage.authenticateAs(config.username!, config.password ?? '');
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

  void disconnect() {
    _isExplicitDisconnect = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    connected = false;
    status = '已断开';
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
    await _topicsBox.put('topics', topics);
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
    await _topicsBox.put('topics', topics);
    await _saveMessages();
    notifyListeners();
  }

  void selectTopic(String? topic) {
    selectedTopic = topic;
    notifyListeners();
  }

  void subscribe(String topic) {
    _client?.subscribe(topic, MqttQos.atLeastOnce);
  }

  void _listenToMessages() {
    _subscription?.cancel();
    _subscription = _client?.updates?.listen((messages) {
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
      }
      _saveMessages();
      notifyListeners();
    });
  }

  Future<void> _saveMessages() async {
    final payload = messagesByTopic.map((topic, list) {
      return MapEntry(topic, list.map((e) => e.toMap()).toList());
    });
    await _messagesBox.put('history', payload);
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
}

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key, required this.controller});

  final MqttController controller;

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _useTls = false;
  bool _keepAliveInBackground = false;

  @override
  void initState() {
    super.initState();
    final config = widget.controller.config;
    _hostController = TextEditingController(text: config.host);
    _portController = TextEditingController(text: config.port.toString());
    _clientIdController = TextEditingController(text: config.clientId);
    _usernameController = TextEditingController(text: config.username ?? '');
    _passwordController = TextEditingController(text: config.password ?? '');
    _useTls = config.useTls;
    _keepAliveInBackground = config.keepAliveInBackground;
  }

  @override
  void didUpdateWidget(covariant ConfigPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.config != widget.controller.config) {
      final config = widget.controller.config;
      _hostController.text = config.host;
      _portController.text = config.port.toString();
      _clientIdController.text = config.clientId;
      _usernameController.text = config.username ?? '';
      _passwordController.text = config.password ?? '';
      _useTls = config.useTls;
      _keepAliveInBackground = config.keepAliveInBackground;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _clientIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showDebugLogs(BuildContext context) {
    final logs = widget.controller.notificationDebugLogs;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🔔 通知调试日志',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: logs.isEmpty
                      ? const Center(child: Text('暂无日志'))
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: logs.length,
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                logs[index],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveConfig() async {
    final port = int.tryParse(_portController.text.trim()) ?? 1883;
    await widget.controller.saveConfig(
      widget.controller.config.copyWith(
        host: _hostController.text.trim(),
        port: port,
        useTls: _useTls,
        clientId: _clientIdController.text.trim(),
        username: _usernameController.text.trim().isEmpty
            ? null
            : _usernameController.text.trim(),
        password: _passwordController.text.trim().isEmpty
            ? null
            : _passwordController.text.trim(),
        keepAliveInBackground: _keepAliveInBackground,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('配置已保存')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '连接配置',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'Broker 地址',
              hintText: 'test.mosquitto.org',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '端口',
              hintText: '1883',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clientIdController,
            decoration: const InputDecoration(
              labelText: 'Client ID',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _useTls,
            onChanged: (value) => setState(() => _useTls = value),
            title: const Text('启用 TLS'),
          ),
          SwitchListTile(
            value: _keepAliveInBackground,
            onChanged: (value) => setState(() => _keepAliveInBackground = value),
            title: const Text('iOS 后台保活'),
            subtitle: const Text('开启后进入后台继续接收消息'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: '用户名（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: '密码（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _saveConfig,
                icon: const Icon(Icons.save),
                label: const Text('保存配置'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: widget.controller.connected
                    ? null
                    : widget.controller.connect,
                icon: const Icon(Icons.link),
                label: const Text('连接'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed:
                    widget.controller.connected ? widget.controller.disconnect : null,
                icon: const Icon(Icons.link_off),
                label: const Text('断开'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: widget.controller.sendTestNotification,
                icon: const Icon(Icons.notifications_active),
                label: const Text('测试通知'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showDebugLogs(context),
                icon: const Icon(Icons.bug_report),
                label: const Text('调试日志'),
              ),
            ],
          ),
          if (widget.controller.lastTestResult.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.controller.lastTestResult.startsWith('✅')
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.controller.lastTestResult.startsWith('✅')
                      ? Colors.green.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Text(
                widget.controller.lastTestResult,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.controller.lastTestResult.startsWith('✅')
                      ? Colors.green.shade800
                      : Colors.red.shade800,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                widget.controller.connected
                    ? Icons.check_circle
                    : Icons.info_outline,
                color: widget.controller.connected
                    ? Colors.green
                    : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.controller.status)),
            ],
          ),
        ],
      ),
    );
  }
}

class TopicsPage extends StatefulWidget {
  const TopicsPage({super.key, required this.controller});

  final MqttController controller;

  @override
  State<TopicsPage> createState() => _TopicsPageState();
}

class _TopicsPageState extends State<TopicsPage> {
  final TextEditingController _topicController = TextEditingController();

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '订阅主题',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    labelText: '输入主题',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  widget.controller.addTopic(_topicController.text);
                  _topicController.clear();
                },
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.controller.topics.isEmpty
                ? const Center(child: Text('暂无订阅主题'))
                : ListView.builder(
                    itemCount: widget.controller.topics.length,
                    itemBuilder: (context, index) {
                      final topic = widget.controller.topics[index];
                      final messageCount =
                          widget.controller.messagesByTopic[topic]?.length ?? 0;
                      return Card(
                        child: ListTile(
                          title: Text(topic),
                          subtitle: Text('历史消息: $messageCount'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => widget.controller.removeTopic(topic),
                          ),
                          onTap: () => widget.controller.selectTopic(topic),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key, required this.controller});

  final MqttController controller;

  @override
  Widget build(BuildContext context) {
    final selected = controller.selectedTopic;
    final messages = selected == null
        ? <MqttMessageEntry>[]
        : controller.messagesByTopic[selected] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '消息列表',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selected,
            items: controller.topics
                .map((topic) => DropdownMenuItem(
                      value: topic,
                      child: Text(topic),
                    ))
                .toList(),
            onChanged: controller.selectTopic,
            decoration: const InputDecoration(
              labelText: '选择主题',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: selected == null
                ? const Center(child: Text('请先添加并选择主题'))
                : messages.isEmpty
                    ? const Center(child: Text('暂无消息'))
                    : ListView.separated(
                        itemCount: messages.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return ListTile(
                            title: Text(message.payload),
                            subtitle: Text(
                              '${message.topic} · ${message.timestamp.toLocal()}',
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
