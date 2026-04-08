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
  final FocusNode _topicFocusNode = FocusNode();
  final FocusNode _payloadFocusNode = FocusNode();
  final GlobalKey _topicFieldKey = GlobalKey();
  final GlobalKey _payloadFieldKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _topicFocusNode.addListener(() {
      if (_topicFocusNode.hasFocus) {
        _ensureFieldVisible(_topicFieldKey);
      }
    });
    _payloadFocusNode.addListener(() {
      if (_payloadFocusNode.hasFocus) {
        _ensureFieldVisible(_payloadFieldKey);
      }
    });
  }

  void _ensureFieldVisible(GlobalKey key) {
    final fieldContext = key.currentContext;
    if (fieldContext == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    });
  }

  @override
  void dispose() {
    _topicController.dispose();
    _payloadController.dispose();
    _topicFocusNode.dispose();
    _payloadFocusNode.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    await widget.controller.publish(
      _topicController.text,
      _payloadController.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.controller.status)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final cardBg = isDark ? const Color(0xFF1B1D23) : Colors.white;
    final inputFill = isDark
        ? const Color(0xFF20232B)
        : const Color(0xFFF8F9FC);
    final inputBorderColor = isDark
        ? const Color(0xFF3A3D46)
        : const Color(0xFFDADCE6);

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: inputBorderColor),
    );

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      color: pageBg,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '发送消息',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '填写 Topic 与 Payload 并推送到当前 MQTT 连接',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                _ConnectionStatusPill(controller: widget.controller),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? 0.12 : 0.045,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        key: _topicFieldKey,
                        child: TextField(
                          controller: _topicController,
                          focusNode: _topicFocusNode,
                          textInputAction: TextInputAction.next,
                          onTap: () => _ensureFieldVisible(_topicFieldKey),
                          decoration: InputDecoration(
                            labelText: 'Topic',
                            hintText: '例如：home/device/status',
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(
                                color: Color(0xFF4A6CF7),
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: inputFill,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        key: _payloadFieldKey,
                        constraints: const BoxConstraints(minHeight: 220),
                        child: TextField(
                          controller: _payloadController,
                          focusNode: _payloadFocusNode,
                          minLines: 10,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          onTap: () => _ensureFieldVisible(_payloadFieldKey),
                          decoration: InputDecoration(
                            labelText: 'Payload',
                            hintText: '输入要发送的消息内容',
                            alignLabelWithHint: true,
                            border: inputBorder,
                            enabledBorder: inputBorder,
                            focusedBorder: inputBorder.copyWith(
                              borderSide: const BorderSide(
                                color: Color(0xFF4A6CF7),
                                width: 1.4,
                              ),
                            ),
                            filled: true,
                            fillColor: inputFill,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: widget.controller.connected ? _send : null,
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('发送消息'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4A6CF7),
                      disabledBackgroundColor: const Color(0xFF7E859A),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionStatusPill extends StatelessWidget {
  const _ConnectionStatusPill({required this.controller});

  final MqttController controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.connected;
    final endpoint =
        '${controller.activeProfile?.host}:${controller.activeProfile?.port}';
    final bg = connected ? const Color(0x220AB36E) : const Color(0x224A6CF7);
    final textColor = connected
        ? const Color(0xFF0A8A57)
        : const Color(0xFF4A6CF7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(
            connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              connected ? '已连接：$endpoint' : '未连接，请先到“配置列表”页建立连接',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
