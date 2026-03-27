import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key, required this.controller});

  final MqttController controller;

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _payloadController = TextEditingController();

  @override
  void dispose() {
    _topicController.dispose();
    _payloadController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    await widget.controller.publish(
      _topicController.text,
      _payloadController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.controller.status)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputFill = isDark ? const Color(0xFF20232B) : Colors.white;
    final inputBorderColor = isDark
        ? const Color(0xFF3A3D46)
        : const Color(0xFFD2D2D7);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '发送内容',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topicController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Topic',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: inputBorderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: inputBorderColor),
                ),
                filled: true,
                fillColor: inputFill,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _payloadController,
                maxLines: null,
                expands: true,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: 'Payload',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  filled: true,
                  fillColor: inputFill,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.controller.connected ? _send : null,
                    icon: const Icon(Icons.send),
                    label: const Text('发送'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.controller.connected
                  ? '已连接：${widget.controller.activeProfile?.host}:${widget.controller.activeProfile?.port}'
                  : '未连接，请到“配置列表”页选择配置并连接',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
