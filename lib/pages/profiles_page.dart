import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/models/mqtt_profile.dart';
import 'package:galaxy_ios/pages/add_or_edit_profile_page.dart';
import 'package:galaxy_ios/pages/mqtt_detail_page.dart';

class ProfilesPage extends StatelessWidget {
  const ProfilesPage({super.key, required this.controller});

  final MqttController controller;

  Future<void> _openEdit(BuildContext context, MqttProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddOrEditProfilePage(
          controller: controller,
          initial: profile,
        ),
      ),
    );
  }

  Future<void> _openAdd(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddOrEditProfilePage(controller: controller),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, MqttProfile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MqttDetailPage(
          controller: controller,
          profile: profile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = controller.activeProfile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const Text(
                  'mqtt客户端',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
              ),
              IconButton(
                tooltip: '新增配置',
                onPressed: () => _openAdd(context),
                icon: const Icon(Icons.add_circle_outline),
              ),
              // if (active != null)
              //   Chip(
              //     label: Text(controller.connected ? '已连接' : '未连接'),
              //     backgroundColor: controller.connected
              //         ? Colors.green.shade50
              //         : Colors.orange.shade50,
              //     side: BorderSide(
              //       color: controller.connected
              //           ? Colors.green.shade200
              //           : Colors.orange.shade200,
              //     ),
              //   ),
            ],
          ),
          const SizedBox(height: 12),
          if (active != null)
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _openDetail(context, active),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: controller.connected
                                  ? Colors.green
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '当前：${active.name}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '连接',
                            onPressed: controller.connected
                                ? null
                                : () => controller.connectProfile(active.id),
                            icon: const Icon(Icons.link),
                          ),
                          IconButton(
                            tooltip: '断开',
                            onPressed: controller.connected
                                ? controller.disconnect
                                : null,
                            icon: const Icon(Icons.link_off),
                          ),
                        ],
                      ),
                      if (active.remark.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          active.remark,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text('${active.host}:${active.port}'),
                      const SizedBox(height: 8),
                      const SizedBox(height: 8),
                      Text(
                        controller.status,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: controller.profiles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final p = controller.profiles[index];
                final selected = p.id == controller.activeProfileId;
                final isConnectedSelected = selected && controller.connected;

                return Card(
                  child: ListTile(
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isConnectedSelected
                            ? Colors.green
                            : (selected ? Colors.blue : Colors.grey.shade400),
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      [
                        if (p.remark.trim().isNotEmpty) p.remark.trim(),
                        '${p.host}:${p.port}',
                      ].join(' · '),
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: '编辑',
                          onPressed: () => _openEdit(context, p),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: '删除',
                          onPressed: controller.profiles.length <= 1
                              ? null
                              : () => controller.deleteProfile(p.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    onTap: () => controller.selectProfile(p.id),
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
