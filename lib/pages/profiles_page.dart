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
        builder: (_) =>
            AddOrEditProfilePage(controller: controller, initial: profile),
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
        builder: (_) =>
            MqttDetailPage(controller: controller, profile: profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = controller.activeProfile;
    const pageBg = Color(0xFFE9ECF2);
    const titleColor = Color(0xFF1F2558);

    return Container(
      color: pageBg,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'mqtt客户端',
                      style: TextStyle(
                        fontSize: 32,
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    elevation: 1.5,
                    shadowColor: const Color(0x22000000),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _openAdd(context),
                      child: const SizedBox(
                        width: 58,
                        height: 58,
                        child: Icon(
                          Icons.playlist_add_rounded,
                          color: titleColor,
                          size: 30,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (active != null)
                _MqttConnectionCard(
                  active: active,
                  connected: controller.connected,
                  status: controller.status,
                  onTap: () => _openDetail(context, active),
                  onConnect: controller.connected
                      ? null
                      : () => controller.connectProfile(active.id),
                  onDisconnect: controller.connected
                      ? controller.disconnect
                      : null,
                ),
              if (active == null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('暂无可用配置，请点击右上角新增 MQTT 配置'),
                ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'MQTT配置列表',
                        style: TextStyle(
                          color: titleColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '共 ${controller.profiles.length} 个配置',
                      style: const TextStyle(
                        color: Color(0xFF7A7C93),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: controller.profiles.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = controller.profiles[index];
                    final selected = p.id == controller.activeProfileId;
                    final isConnectedSelected =
                        selected && controller.connected;

                    return _MqttProfileTile(
                      profile: p,
                      selected: selected,
                      isConnectedSelected: isConnectedSelected,
                      canDelete: controller.profiles.length > 1,
                      onTap: () => controller.selectProfile(p.id),
                      onEdit: () => _openEdit(context, p),
                      onDelete: () => controller.deleteProfile(p.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MqttConnectionCard extends StatelessWidget {
  const _MqttConnectionCard({
    required this.active,
    required this.connected,
    required this.status,
    required this.onTap,
    required this.onConnect,
    required this.onDisconnect,
  });

  final MqttProfile active;
  final bool connected;
  final String status;
  final VoidCallback onTap;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFF1F2558);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF5FF), Color(0xFFE9F3FF), Color(0xFFF7EBD8)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.82),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_rounded,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MQTT连接',
                              style: TextStyle(
                                color: titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              active.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF20234F),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: connected
                              ? const Color(0x220AB36E)
                              : const Color(0x22000000),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: connected
                                    ? const Color(0xFF0AB36E)
                                    : const Color(0xFF9BA1B2),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              connected ? '已连接' : '未连接',
                              style: TextStyle(
                                color: connected
                                    ? const Color(0xFF0A8A57)
                                    : const Color(0xFF555B6B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${active.host}:${active.port}',
                    style: const TextStyle(
                      color: Color(0xFF373C6E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (active.remark.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      active.remark.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF666C84)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF666C84),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: onConnect,
                          icon: const Icon(Icons.link_rounded),
                          label: const Text('连接'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A6CF7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDisconnect,
                          icon: const Icon(Icons.link_off_rounded),
                          label: const Text('断开'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MqttProfileTile extends StatelessWidget {
  const _MqttProfileTile({
    required this.profile,
    required this.selected,
    required this.isConnectedSelected,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final MqttProfile profile;
  final bool selected;
  final bool isConnectedSelected;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    const titleColor = Color(0xFF1F2558);
    final borderColor = isConnectedSelected
        ? const Color(0xFF5AD7A4)
        : (selected ? const Color(0xFF9FB3FF) : const Color(0xFFE8EAF5));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x10000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isConnectedSelected
                      ? const Color(0x220AB36E)
                      : const Color(0x221F2558),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isConnectedSelected
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_outlined,
                  color: isConnectedSelected
                      ? const Color(0xFF0AB36E)
                      : titleColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: titleColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profile.host}:${profile.port}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6E7388),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile.remark.trim().isNotEmpty)
                      Text(
                        profile.remark.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8A8FA1)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF5E6380)),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: canDelete ? onDelete : null,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFF5E6380),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
