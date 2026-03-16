import 'dart:ui';

import 'package:flutter/cupertino.dart';

/// iOS 风格底部栏：毛玻璃 + 中间凸起“+”按钮。
///
/// 入口：发送 / 接收 / (+新增配置) / 配置列表(人员)
class IosPlusTabBar extends StatelessWidget {
  const IosPlusTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onPlusTap,
  });

  /// 仅对“页面入口”计数：0=发送，1=接收，2=配置列表
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onPlusTap;

  static const _activeColor = Color(0xFF0A63FF);
  static const _inactiveColor = Color(0xFF8E8E93);

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        CupertinoDynamicColor.resolve(CupertinoColors.systemBackground, context)
            .withValues(alpha: 0.82);

    return SafeArea(
      top: false,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: const Border(
                top: BorderSide(color: Color(0x1F000000), width: 0.5),
              ),
            ),
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  Expanded(
                    child: _Item(
                      selected: currentIndex == 0,
                      icon: CupertinoIcons.paperplane,
                      onTap: () => onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _Item(
                      selected: currentIndex == 1,
                      icon: CupertinoIcons.tray,
                      onTap: () => onTap(1),
                    ),
                  ),
                  // 中间 +
                  SizedBox(
                    width: 78,
                    child: Center(
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: onPlusTap,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            CupertinoIcons.plus,
                            color: Color(0xFFF9FAFB),
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _Item(
                      selected: currentIndex == 2,
                      icon: CupertinoIcons.person,
                      onTap: () => onTap(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? IosPlusTabBar._activeColor
        : IosPlusTabBar._inactiveColor;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      minimumSize: const Size(44, 44),
      child: Center(
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }
}
