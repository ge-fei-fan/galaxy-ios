import 'dart:async';

import 'package:flutter/material.dart';
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
  });

  final String host;
  final int port;
  final bool useTls;
  final String clientId;
  final String? username;
  final String? password;

  MqttConfig copyWith({
    String? host,
    int? port,
    bool? useTls,
    String? clientId,
    String? username,
    String? password,
  }) {
    return MqttConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
      clientId: clientId ?? this.clientId,
      username: username ?? this.username,
      password: password ?? this.password,
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

  Future<void> init() async {
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      iOS: iosSettings,
    );
    await _plugin.initialize(initializationSettings);
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> showMessage(String topic, String payload) async {
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    const details = NotificationDetails(
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _plugin.show(id, 'MQTT: $topic', payload, details);
  }
}

class MqttController extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final Box _settingsBox = Hive.box('settings');
  final Box _topicsBox = Hive.box('topics');
  final Box _messagesBox = Hive.box('messages');

  bool initialized = false;
  bool connected = false;
  String status = '未连接';
  MqttConfig config = const MqttConfig(
    host: 'test.mosquitto.org',
    port: 1883,
    useTls: false,
    clientId: 'flutter_mqtt_client',
  );
  List<String> topics = [];
  String? selectedTopic;
  Map<String, List<MqttMessageEntry>> messagesByTopic = {};

  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;

  Future<void> initialize() async {
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
    initialized = true;
    notifyListeners();
  }

  Future<void> saveConfig(MqttConfig newConfig) async {
    config = newConfig;
    await _settingsBox.put('config', config.toMap());
    notifyListeners();
  }

  Future<void> connect() async {
    if (connected) return;
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
      return;
    }

    final state = _client!.connectionStatus?.state;
    if (state != MqttConnectionState.connected) {
      status = '连接失败: ${_client!.connectionStatus?.returnCode}';
      connected = false;
      _client?.disconnect();
      notifyListeners();
      return;
    }

    connected = true;
    status = '已连接';
    _listenToMessages();
    for (final topic in topics) {
      subscribe(topic);
    }
    notifyListeners();
  }

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    connected = false;
    status = '已断开';
    notifyListeners();
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
    status = '已断开';
    notifyListeners();
  }

  void _handleSubscribed(String topic) {
    status = '订阅成功: $topic';
    notifyListeners();
  }

  void _handleSubscribeFail(String topic) {
    status = '订阅失败: $topic';
    notifyListeners();
  }

  Future<void> sendTestNotification() async {
    await _notificationService.showMessage(
      '测试主题',
      '这是一条测试通知，时间：${DateTime.now().toLocal()}',
    );
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
          ElevatedButton.icon(
            onPressed: widget.controller.sendTestNotification,
            icon: const Icon(Icons.notifications_active),
            label: const Text('测试通知'),
          ),
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
