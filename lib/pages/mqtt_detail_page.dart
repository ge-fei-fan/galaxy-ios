import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/models/mqtt_profile.dart';
import 'package:galaxy_ios/pages/receive_page.dart';
import 'package:galaxy_ios/pages/send_page.dart';

class MqttDetailPage extends StatelessWidget {
  const MqttDetailPage({
    super.key,
    required this.controller,
    required this.profile,
  });

  final MqttController controller;
  final MqttProfile profile;

  @override
  Widget build(BuildContext context) {
    final topics = controller.topics;
    final topicSummary = topics.isEmpty ? '暂无主题' : topics.join('、');
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.name),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前配置：${profile.name}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${profile.host}:${profile.port}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '当前主题：$topicSummary',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                tabs: [
                  Tab(text: '发送'),
                  Tab(text: '订阅接收'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  SendPage(controller: controller),
                  ReceivePage(controller: controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}