import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/models/mqtt_profile.dart';
import 'package:galaxy_ios/pages/add_or_edit_profile_page.dart';
import 'package:galaxy_ios/pages/mqtt_detail_page.dart';
import 'package:galaxy_ios/widgets/page_header.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final emptyCardBg = isDark ? const Color(0xFF1B1D23) : Colors.white;

    return Container(
      color: pageBg,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageTitle(
                title: '客户端',
                trailing: HeaderCircleIconButton(
                  icon: Icons.playlist_add_rounded,
                  iconSize: 30,
                  onTap: () => _openAdd(context),
                ),
              ),
              const SizedBox(height: 20),
              if (active != null)
                _MqttConnectionCard(
                  active: active,
                  connected: controller.connected,
                  status: controller.status,
                  isDark: isDark,
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
                    color: emptyCardBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '暂无可用配置，请点击右上角新增 MQTT 配置',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              // const SizedBox(height: 12),
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.symmetric(
              //     horizontal: 16,
              //     vertical: 14,
              //   ),
              //   decoration: BoxDecoration(
              //     color: Colors.white,
              //     borderRadius: BorderRadius.circular(20),
              //     boxShadow: const [
              //       BoxShadow(
              //         color: Color(0x12000000),
              //         blurRadius: 10,
              //         offset: Offset(0, 2),
              //       ),
              //     ],
              //   ),
              //   child: Row(
              //     children: [
              //       const Expanded(
              //         child: Text(
              //           'MQTT配置列表',
              //           style: TextStyle(
              //             color: titleColor,
              //             fontSize: 20,
              //             fontWeight: FontWeight.w700,
              //           ),
              //         ),
              //       ),
              //       Text(
              //         '共 ${controller.profiles.length} 个配置',
              //         style: const TextStyle(
              //           color: Color(0xFF7A7C93),
              //           fontWeight: FontWeight.w600,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
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
                      isDark: isDark,
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
    required this.isDark,
    required this.onTap,
    required this.onConnect,
    required this.onDisconnect,
  });

  final MqttProfile active;
  final bool connected;
  final String status;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onConnect;
  final VoidCallback? onDisconnect;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? const Color(0xFFE3E7F5) : const Color(0xFF1F2558);
    final subTitleColor = isDark ? const Color(0xFFC8CEDF) : const Color(0xFF20234F);
    final textColor = isDark ? const Color(0xFFB3B9CB) : const Color(0xFF666C84);
    final hostColor = isDark ? const Color(0xFFD0D6E8) : const Color(0xFF373C6E);
    final outerGradient = isDark
        ? const [Color(0xFF2A2E3A), Color(0xFF242A39), Color(0xFF2B2734)]
        : const [Color(0xFFEFF5FF), Color(0xFFE9F3FF), Color(0xFFF7EBD8)];
    final innerCardBg = isDark ? const Color(0xFF1B1D23) : Colors.white;
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.82);
    final connectedChipBg = connected
        ? const Color(0x220AB36E)
        : (isDark ? const Color(0x22FFFFFF) : const Color(0x22000000));
    final disconnectedText = isDark
        ? const Color(0xFFB7BECE)
        : const Color(0xFF555B6B);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: outerGradient,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x22000000) : const Color(0x14000000),
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
                color: innerCardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? const Color(0x14000000)
                        : const Color(0x12000000),
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
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_rounded,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
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
                              style: TextStyle(
                                color: subTitleColor,
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
                          color: connectedChipBg,
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
                                    : disconnectedText,
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
                    style: TextStyle(
                      color: hostColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (active.remark.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      active.remark.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
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
    required this.isDark,
    required this.canDelete,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final MqttProfile profile;
  final bool selected;
  final bool isConnectedSelected;
  final bool isDark;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? const Color(0xFFE3E7F5) : const Color(0xFF1F2558);
    final itemBg = isDark ? const Color(0xFF1B1D23) : Colors.white;
    final hostColor = isDark ? const Color(0xFFB8BFD1) : const Color(0xFF6E7388);
    final remarkColor = isDark ? const Color(0xFF8F96AA) : const Color(0xFF8A8FA1);
    final iconActionColor = isDark ? const Color(0xFFB3BACB) : const Color(0xFF5E6380);
    final borderColor = isConnectedSelected
        ? const Color(0xFF5AD7A4)
        : (selected
              ? const Color(0xFF9FB3FF)
              : (isDark ? const Color(0xFF303543) : const Color(0xFFE8EAF5)));

    return Material(
      color: itemBg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: itemBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.3),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x14000000) : const Color(0x10000000),
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
                      style: TextStyle(
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
                      style: TextStyle(
                        color: hostColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile.remark.trim().isNotEmpty)
                      Text(
                        profile.remark.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: remarkColor),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑',
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: iconActionColor),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: canDelete ? onDelete : null,
                icon: Icon(
                  Icons.delete_outline,
                  color: iconActionColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
