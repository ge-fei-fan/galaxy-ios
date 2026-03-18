import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/models/mqtt_profile.dart';
import 'package:galaxy_ios/pages/receive_page.dart';
import 'package:galaxy_ios/pages/send_page.dart';
import 'package:galaxy_ios/widgets/segmented_capsule.dart';

class MqttDetailPage extends StatefulWidget {
  const MqttDetailPage({
    super.key,
    required this.controller,
    required this.profile,
  });

  final MqttController controller;
  final MqttProfile profile;

  @override
  State<MqttDetailPage> createState() => _MqttDetailPageState();
}

class _MqttDetailPageState extends State<MqttDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topics = widget.controller.topics;
    final topicSummary = topics.isEmpty ? '暂无主题' : topics.join('、');
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F6),
      appBar: AppBar(
        title: Text(widget.profile.name),
        backgroundColor: const Color(0xFFF4F4F6),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            color: const Color(0xFFF4F4F6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前配置：${widget.profile.name}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.profile.host}:${widget.profile.port}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '当前主题：$topicSummary',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Center(
                  child: SegmentedCapsule(
                    labels: const ['发送', '接收'],
                    selectedIndex: _tabController.index,
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: 36,
                    cornerRadius: 10,
                    selectedColor: const Color(0xFF4CB3FF),
                    onChanged: (index) {
                      setState(() => _tabController.index = index);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                SendPage(controller: widget.controller),
                ReceivePage(controller: widget.controller),
              ],
            ),
          ),
        ],
      ),
    );
  }
}