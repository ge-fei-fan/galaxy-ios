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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '发送',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicController,
            decoration: const InputDecoration(
              labelText: 'Topic',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _payloadController,
              maxLines: null,
              expands: true,
              decoration: const InputDecoration(
                labelText: 'Payload',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
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
    );
  }
}
