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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SegmentedCapsule(
            labels: const ['订阅', '消息'],
            selectedIndex: _selectedIndex,
            onChanged: (index) {
              setState(() => _selectedIndex = index);
            },
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

  @override
  void dispose() {
    _topicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Padding(
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
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      widget.controller.addTopic(_topicController.text);
                      _topicController.clear();
                      FocusScope.of(context).unfocus();
                      setState(() {});
                    },
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
                    FocusScope.of(context).unfocus();
                    setState(() {});
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
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: widget.controller.topics.length,
                      itemBuilder: (context, index) {
                        final topic = widget.controller.topics[index];
                        final messageCount =
                            widget.controller.messagesByTopic[topic]?.length ??
                                0;
                        return Card(
                          child: ListTile(
                            title: Text(topic),
                            subtitle: Text('历史消息: $messageCount'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  widget.controller.removeTopic(topic),
                            ),
                            onTap: () => widget.controller.selectTopic(topic),
                          ),
                        );
                      },
                    ),
            ),
          ],
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
    final selected = controller.selectedTopic;
    final List<MqttMessageEntry> messages = selected == null
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
            initialValue: selected,
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
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
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
