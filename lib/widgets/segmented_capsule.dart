import 'package:flutter/material.dart';

class SegmentedCapsule extends StatelessWidget {
  const SegmentedCapsule({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.horizontalPadding = 8,
    this.height = 36,
    this.cornerRadius = 12,
    this.backgroundColor = const Color(0xFFE6E6E8),
    this.selectedColor = const Color(0xFF4CB3FF),
    this.unselectedTextColor,
    this.width,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double horizontalPadding;
  final double height;
  final double cornerRadius;
  final Color backgroundColor;
  final Color selectedColor;
  final Color? unselectedTextColor;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inactiveColor =
        unselectedTextColor ?? theme.textTheme.labelLarge?.color ?? Colors.black54;
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(cornerRadius + 6),
        ),
        child: SizedBox(
          height: height,
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = index == selectedIndex;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: selected ? selectedColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(cornerRadius),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(cornerRadius),
                    onTap: () => onChanged(index),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: horizontalPadding,
                      ),
                      child: Center(
                        child: Text(
                          labels[index],
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : inactiveColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}