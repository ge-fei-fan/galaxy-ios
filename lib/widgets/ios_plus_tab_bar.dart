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

  static const double _barHeight = 64;
  static const double _barRadius = 24;
  static const double _sidePadding = 16;
  static const double _bottomGap = 12;

  static const double _plusSize = 58;
  static const double _plusLift = 8;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        CupertinoDynamicColor.resolve(CupertinoColors.systemBackground, context)
            .withValues(alpha: 0.82);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _sidePadding)
            .copyWith(bottom: _bottomGap),
        child: SizedBox(
          height: _barHeight + _plusLift,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              // 悬浮毛玻璃卡片底栏
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  // 注意：阴影必须在 ClipRRect 外层，否则会被裁剪掉，看起来就不“悬浮”。
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_barRadius),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_barRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(_barRadius),
                          border: Border.all(
                            color: const Color(0x1AFFFFFF),
                            width: 0.8,
                          ),
                        ),
                        child: SizedBox(
                          height: _barHeight,
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
                              // 给中间 + 预留空间
                              const SizedBox(width: 110),
                              Expanded(
                                child: _Item(
                                  selected: currentIndex == 2,
                                  icon: CupertinoIcons.slider_horizontal_3,
                                  onTap: () => onTap(2),
                                ),
                              ),
                              Expanded(
                                child: _Item(
                                  selected: currentIndex == 3,
                                  icon: CupertinoIcons.gear,
                                  onTap: () => onTap(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 中间凸起的 +
              Positioned(
                bottom: _barHeight - (_plusSize / 2) + _plusLift,
                left: 0,
                right: 0,
                child: Center(
                  child: _PlusButton(
                    onTap: onPlusTap,
                    size: _plusSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusButton extends StatelessWidget {
  const _PlusButton({
    required this.onTap,
    required this.size,
  });

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(size * 0.36),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3D000000),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: const Icon(
          CupertinoIcons.plus,
          color: Color(0xFFF9FAFB),
          size: 28,
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
