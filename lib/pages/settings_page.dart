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
    final activeProfile = controller.activeProfile;
    final liveActivityEnabled = activeProfile?.enableLiveActivity ?? false;
    final clipboardEnabled = controller.clipboardMonitorEnabled;

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
            Card(
              child: SwitchListTile(
                value: clipboardEnabled,
                onChanged: (value) async {
                  await controller.setClipboardMonitorEnabled(value);
                },
                title: const Text('启用剪贴板监听'),
                subtitle: const Text('默认关闭。检测到新复制内容后会触发通知并可更新灵动岛'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SwitchListTile(
                value: liveActivityEnabled,
                onChanged: activeProfile == null
                    ? null
                    : (value) async {
                        final updated = activeProfile.copyWith(
                          enableLiveActivity: value,
                        );
                        await controller.updateProfile(updated);
                        if (!value) {
                          await controller.stopDynamicIslandDemo();
                        }
                      },
                title: const Text('启用灵动岛消息展示'),
                subtitle: Text(
                  activeProfile == null
                      ? '请先选择配置'
                      : '默认关闭。开启后收到 MQTT 消息会在灵动岛显示主题和消息',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showDebugLogs(context),
                icon: const Icon(Icons.bug_report_outlined),
                label: const Text('查看日志'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}