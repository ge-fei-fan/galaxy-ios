import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.controller});

  final MqttController controller;

  void _showDebugLogs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final logs = controller.notificationDebugLogs;
            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '🔔 通知调试日志',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_outlined),
                            tooltip: '清除日志',
                            onPressed: () {
                              controller.clearLogs();
                              setSheetState(() {});
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: logs.isEmpty
                          ? const Center(child: Text('暂无日志'))
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: logs.length,
                              padding: const EdgeInsets.all(12),
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    logs[index],
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '设置',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 14),
            // Text(
            //   '工具',
            //   style: Theme.of(context).textTheme.titleMedium,
            // ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDebugLogs(context),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('查看日志'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await controller.startDynamicIslandDemo();
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('测试灵动岛（开始）'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await controller.stopDynamicIslandDemo();
                  if (!context.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(result)),
                  );
                },
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('测试灵动岛（结束）'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}