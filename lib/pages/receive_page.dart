import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/models/mqtt_message_entry.dart';
import 'package:galaxy_ios/widgets/segmented_capsule.dart';

class ReceivePage extends StatefulWidget {
  const ReceivePage({super.key, required this.controller});

  final MqttController controller;

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final cardBg = isDark ? const Color(0xFF1B1D23) : Colors.white;
    final mutedColor = isDark
        ? const Color(0xFFB2B8C8)
        : const Color(0xFF697089);

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: pageBg,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedIndex == 0 ? '订阅管理' : '消息记录',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selectedIndex == 0 ? '维护主题订阅列表' : '查看主题实时消息',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                ),
                SegmentedCapsule(
                  labels: const ['订阅', '消息'],
                  selectedIndex: _selectedIndex,
                  width: 176,
                  height: 38,
                  cornerRadius: 16,
                  selectedColor: const Color(0xFF4A6CF7),
                  onChanged: (index) {
                    setState(() => _selectedIndex = index);
                  },
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _TopicsTab(controller: widget.controller),
              _MessagesTab(controller: widget.controller),
            ],
          ),
        ),
      ],
    );
  }
}

class _TopicsTab extends StatefulWidget {
  const _TopicsTab({required this.controller});

  final MqttController controller;

  @override
  State<_TopicsTab> createState() => _TopicsTabState();
}

class _TopicsTabState extends State<_TopicsTab> {
  final TextEditingController _topicController = TextEditingController();

  Future<void> _addTopic() async {
    final topic = _topicController.text;
    await widget.controller.addTopic(topic);
    _topicController.clear();
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final cardBg = isDark ? const Color(0xFF1B1D23) : Colors.white;
    final inputFill = isDark ? const Color(0xFF20232B) : Colors.white;
    final inputBorderColor = isDark
        ? const Color(0xFF3A3D46)
        : const Color(0xFFD2D2D7);
    final tileBg = isDark ? const Color(0xFF20232B) : const Color(0xFFF8F9FC);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: inputBorderColor),
    );

    return Container(
      color: pageBg,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topicController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addTopic(),
                        decoration: InputDecoration(
                          labelText: '输入主题',
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
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: _addTopic,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('添加'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF4A6CF7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.04),
                    ),
                  ),
                  child: widget.controller.topics.isEmpty
                      ? const _EmptyState(
                          icon: Icons.rss_feed_rounded,
                          title: '暂无订阅主题',
                          subtitle: '输入 Topic 后点击添加，即可开始订阅',
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          itemCount: widget.controller.topics.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final topic = widget.controller.topics[index];
                            final messageCount =
                                widget
                                    .controller
                                    .messagesByTopic[topic]
                                    ?.length ??
                                0;
                            final selected =
                                widget.controller.selectedTopic == topic;
                            return Container(
                              decoration: BoxDecoration(
                                color: tileBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF9FB3FF)
                                      : (isDark
                                            ? const Color(0xFF303543)
                                            : const Color(0xFFE6E9F3)),
                                ),
                              ),
                              child: ListTile(
                                title: Text(
                                  topic,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text('历史消息: $messageCount'),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  onPressed: () async {
                                    await widget.controller.removeTopic(topic);
                                    if (!mounted) return;
                                    setState(() {});
                                  },
                                ),
                                onTap: () {
                                  widget.controller.selectTopic(topic);
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessagesTab extends StatelessWidget {
  const _MessagesTab({required this.controller});

  final MqttController controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final cardBg = isDark ? const Color(0xFF1B1D23) : Colors.white;
    final inputFill = isDark ? const Color(0xFF20232B) : Colors.white;
    final inputBorderColor = isDark
        ? const Color(0xFF3A3D46)
        : const Color(0xFFD2D2D7);
    final tileBg = isDark ? const Color(0xFF20232B) : const Color(0xFFF8F9FC);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: inputBorderColor),
    );
    final selected = controller.selectedTopic;
    final List<MqttMessageEntry> messages = selected == null
        ? <MqttMessageEntry>[]
        : controller.messagesByTopic[selected] ?? [];

    return Container(
      color: pageBg,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
              ),
              child: DropdownButtonFormField<String>(
                initialValue: selected,
                items: controller.topics
                    .map(
                      (topic) =>
                          DropdownMenuItem(value: topic, child: Text(topic)),
                    )
                    .toList(),
                onChanged: controller.selectTopic,
                decoration: InputDecoration(
                  labelText: '选择主题',
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
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: selected == null
                    ? const _EmptyState(
                        icon: Icons.topic_outlined,
                        title: '请先选择主题',
                        subtitle: '先在订阅页添加主题，然后在这里查看消息',
                      )
                    : messages.isEmpty
                    ? const _EmptyState(
                        icon: Icons.mark_chat_unread_outlined,
                        title: '暂无消息',
                        subtitle: '等待新消息到来后会展示在这里',
                      )
                    : ListView.separated(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: messages.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: tileBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF303543)
                                    : const Color(0xFFE6E9F3),
                              ),
                            ),
                            child: ListTile(
                              title: Text(
                                message.payload,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${message.topic} · ${_formatLocalTime(message.timestamp)}',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? const Color(0x223B82F6) : const Color(0x1A4A6CF7);
    final iconColor = const Color(0xFF4A6CF7);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLocalTime(DateTime time) {
  final t = time.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
