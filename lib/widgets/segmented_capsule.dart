import 'package:flutter/material.dart';

class SegmentedCapsule extends StatelessWidget {
  const SegmentedCapsule({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.horizontalPadding = 8,
    this.height = 36,
    this.cornerRadius = 16,
    this.backgroundColor,
    this.selectedColor,
    this.unselectedTextColor,
    this.width,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double horizontalPadding;
  final double height;
  final double cornerRadius;
  final Color? backgroundColor;
  final Color? selectedColor;
  final Color? unselectedTextColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // 背景颜色：稍微增加一点质感
    final effectiveBackgroundColor = backgroundColor ??
        (isDark ? const Color(0xFF1E1E24) : const Color(0xFFF2F2F7));
    
    // 选中项背景颜色：高质感蓝/灰色系，带轻微渐变或阴影（这里用纯色+阴影模拟）
    final defaultSelectedColor = isDark ? const Color(0xFF323540) : Colors.white;
    final effectiveSelectedColor = selectedColor ?? defaultSelectedColor;
    
    // 未选中文字颜色
    final inactiveColor = unselectedTextColor ??
        (isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93));
        
    // 选中文字颜色
    final activeTextColor = selectedColor == null 
        ? (isDark ? Colors.white : Colors.black)
        : Colors.white;

    return SizedBox(
      width: width,
      height: height + 8, // padding 4 * 2
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          borderRadius: BorderRadius.circular(cornerRadius + 4),
          // 内阴影感觉，通过边框模拟
          border: Border.all(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabCount = labels.length;
            final tabWidth = constraints.maxWidth / tabCount;
            
            return Stack(
              children: [
                // 动画滑块背景
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.fastOutSlowIn,
                  left: selectedIndex * tabWidth,
                  top: 0,
                  bottom: 0,
                  width: tabWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: effectiveSelectedColor,
                      borderRadius: BorderRadius.circular(cornerRadius),
                      boxShadow: [
                        if (selectedColor == null)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        else
                          BoxShadow(
                            color: effectiveSelectedColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                  ),
                ),
                
                // 按钮文本及可点击区域
                Row(
                  children: List.generate(tabCount, (index) {
                    final selected = index == selectedIndex;
                    return Expanded(
                      child: Semantics(
                        selected: selected,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(index),
                          child: Container(
                            alignment: Alignment.center,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 150),
                              style: theme.textTheme.labelLarge!.copyWith(
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                color: selected ? activeTextColor : inactiveColor,
                              ),
                              child: Text(labels[index]),
                            ),
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
      ),
    );
  }
}
