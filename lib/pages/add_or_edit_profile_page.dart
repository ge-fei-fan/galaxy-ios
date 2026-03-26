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
  bool _obscurePassword = true;

  static const _pageBg = Color(0xFFF2F1F6);
  static const _strokeColor = Color(0xFFD2D2D7);
  static const _labelColor = Color(0xFF8A8A91);
  static const _hintColor = Color(0xFF9A9AA1);

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _nameController = TextEditingController(text: p?.name ?? '');
    _remarkController = TextEditingController(text: p?.remark ?? '');
    _hostController = TextEditingController(
      text: p?.host ?? 'mqtt.geff.top',
    );
    _portController = TextEditingController(text: (p?.port ?? 1883).toString());
    _clientIdController = TextEditingController(
      text: p?.clientId ?? 'flutter_mqtt_client',
    );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置名称不能为空')));
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

  InputDecoration _inputDecoration({required String hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 16),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _strokeColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _strokeColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFB9B9C0), width: 1.2),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _labelColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Scaffold(
      backgroundColor: _pageBg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: const Color(0xFFE6E6EB),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isEdit ? '编辑配置' : '新增配置',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('配置名称'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(hint: '输入配置名称'),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('备注'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _remarkController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(hint: '输入备注资讯（可选）'),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Broker 地址'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _hostController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: '例如：test.mosquitto.org',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('端口'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _portController,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(hint: '1883'),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('Client ID'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _clientIdController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(
                          hint: 'flutter_mqtt_client',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('用户名（可选）'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _usernameController,
                        textInputAction: TextInputAction.next,
                        decoration: _inputDecoration(hint: '输入用户名（可选）'),
                      ),
                      const SizedBox(height: 18),
                      _fieldLabel('密码（可选）'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(),
                        decoration: _inputDecoration(
                          hint: '输入密码（可选）',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: const Color(0xFF8A8A91),
                            ),
                          ),
                        ),
                      ),
                     
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
            ),
            onPressed: _save,
            child: const Text(
              '保存',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
