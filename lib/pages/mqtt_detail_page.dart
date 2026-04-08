import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/models/mqtt_profile.dart';
import 'package:galaxy_ios/pages/receive_page.dart';
import 'package:galaxy_ios/pages/send_page.dart';

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
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
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
    final pageBackground = isDark
        ? const Color(0xFF121318)
        : const Color(0xFFF2F1F6);
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: pageBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          '客户端详情',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            color: pageBackground,
            child: _AnimatedTabBar(
              controller: _tabController,
              isDark: isDark,
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

/// 自定义动画 Tab 栏：带滑动高亮指示器 + 图标 + 文字。
/// 选中项以主题色胶囊背景高亮，未选中为半透明灰色。
class _AnimatedTabBar extends StatelessWidget {
  const _AnimatedTabBar({
    required this.controller,
    required this.isDark,
  });

  final TabController controller;
  final bool isDark;

  static const double _tabHeight = 46;

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF4A6CF7);
    final inactiveColor = isDark
        ? const Color(0xFF7C8091)
        : const Color(0xFF8E93A4);
    final pillColor = isDark
        ? activeColor.withValues(alpha: 0.18)
        : activeColor.withValues(alpha: 0.14);
    final barBg = isDark
        ? const Color(0xFF1C1E26)
        : const Color(0xFFEEEFF4);

    final tabs = [
      _TabData(
        label: '发送',
        icon: Icons.send_rounded,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
      ),
      _TabData(
        label: '接收',
        icon: Icons.inbox_rounded,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
      ),
    ];

    final selectedIndex = controller.index.clamp(0, tabs.length - 1);

    return Container(
      height: _tabHeight + 8,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: barBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;

          return Stack(
            children: [
              // 滑动高亮胶囊
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                left: selectedIndex * tabWidth + 3,
                top: 0,
                width: tabWidth - 6,
                height: _tabHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.10),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
              // Tab 按钮
              Row(
                children: List.generate(tabs.length, (index) {
                  final selected = index == selectedIndex;
                  final tab = tabs[index];
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        controller.animateTo(index);
                      },
                      child: Container(
                        height: _tabHeight,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.08 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                tab.icon,
                                size: 20,
                                color: selected
                                    ? tab.activeColor
                                    : tab.inactiveColor,
                              ),
                            ),
                            const SizedBox(width: 7),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? tab.activeColor
                                    : tab.inactiveColor,
                                height: 1.1,
                              ),
                              child: Text(tab.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabData {
  const _TabData({
    required this.label,
    required this.icon,
    required this.activeColor,
    required this.inactiveColor,
  });

  final String label;
  final IconData icon;
  final Color activeColor;
  final Color inactiveColor;
}

