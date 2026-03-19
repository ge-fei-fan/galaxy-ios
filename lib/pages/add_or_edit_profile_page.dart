import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/models/mqtt_profile.dart';

class AddOrEditProfilePage extends StatefulWidget {
  const AddOrEditProfilePage({
    super.key,
    required this.controller,
    this.initial,
  });

  final MqttController controller;
  final MqttProfile? initial;

  @override
  State<AddOrEditProfilePage> createState() => _AddOrEditProfilePageState();
}

class _AddOrEditProfilePageState extends State<AddOrEditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _remarkController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _clientIdController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _useTls = false;
  bool _enableLiveActivity = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nameController = TextEditingController(text: p?.name ?? '');
    _remarkController = TextEditingController(text: p?.remark ?? '');
    _hostController =
        TextEditingController(text: p?.host ?? 'test.mosquitto.org');
    _portController = TextEditingController(text: (p?.port ?? 1883).toString());
    _clientIdController =
        TextEditingController(text: p?.clientId ?? 'flutter_mqtt_client');
    _usernameController = TextEditingController(text: p?.username ?? '');
    _passwordController = TextEditingController(text: p?.password ?? '');
    _useTls = p?.useTls ?? false;
    _enableLiveActivity = p?.enableLiveActivity ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _remarkController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _clientIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('配置名称不能为空')),
      );
      return;
    }
    final port = int.tryParse(_portController.text.trim()) ?? 1883;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    final profile = MqttProfile(
      id: widget.initial?.id ?? _newId(),
      name: name,
      remark: _remarkController.text.trim(),
      host: _hostController.text.trim(),
      port: port,
      useTls: _useTls,
      clientId: _clientIdController.text.trim().isEmpty
          ? 'flutter_mqtt_client'
          : _clientIdController.text.trim(),
      topics: widget.initial?.topics ?? const [],
      username: username.isEmpty ? null : username,
      password: password.isEmpty ? null : password,
      keepAliveInBackground: true,
      enableLiveActivity: _enableLiveActivity,
    );

    if (widget.initial == null) {
      await widget.controller.addProfile(profile);
    } else {
      await widget.controller.updateProfile(profile);
    }

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑配置' : '新增配置'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '配置名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remarkController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '备注',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _hostController,
                textInputAction: TextInputAction.next,
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
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '端口',
                  hintText: '1883',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _clientIdController,
                textInputAction: TextInputAction.next,
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
              const SizedBox(height: 8),
              SwitchListTile(
                value: _enableLiveActivity,
                onChanged: (value) => setState(() => _enableLiveActivity = value),
                title: const Text('启用灵动岛消息展示'),
                subtitle: const Text('默认关闭；开启后收到 MQTT 消息会更新灵动岛'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '用户名（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: const InputDecoration(
                  labelText: '密码（可选）',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
