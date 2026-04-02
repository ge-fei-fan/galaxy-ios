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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topics = widget.controller.topics;
    final topicSummary = topics.isEmpty ? '暂无主题' : topics.join('、');
    final pageBackground = isDark
        ? const Color(0xFF121318)
        : const Color(0xFFF2F1F6);
    final cardBg = isDark ? const Color(0xFF1B1D23) : Colors.white;
    final mutedColor = isDark
        ? const Color(0xFFB2B8C8)
        : const Color(0xFF697089);
    final titleColor = isDark
        ? const Color(0xFFE3E7F5)
        : const Color(0xFF1F2558);
    final connected = widget.controller.connected;
    final segmentWidth = MediaQuery.of(context).size.width * 0.78;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Text(widget.profile.name),
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: pageBackground,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.profile.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: titleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _MqttStatusPill(connected: connected),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.profile.host}:${widget.profile.port}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '当前主题：$topicSummary',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: mutedColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: segmentWidth,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                    ),
                    child: SegmentedCapsule(
                      labels: const ['发送', '接收'],
                      selectedIndex: _tabController.index,
                      width: segmentWidth - 8,
                      height: 38,
                      cornerRadius: 16,
                      selectedColor: const Color(0xFF4CB3FF),
                      onChanged: (index) {
                        setState(() => _tabController.index = index);
                      },
                    ),
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

class _MqttStatusPill extends StatelessWidget {
  const _MqttStatusPill({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: connected ? const Color(0x220AB36E) : const Color(0x224A6CF7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: connected
                  ? const Color(0xFF0AB36E)
                  : const Color(0xFF4A6CF7),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? '已连接' : '未连接',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: connected
                  ? const Color(0xFF0A8A57)
                  : const Color(0xFF4A6CF7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
