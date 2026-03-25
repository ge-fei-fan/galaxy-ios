import 'package:flutter/material.dart';

class AppPageTitle extends StatelessWidget {
  const AppPageTitle({
    super.key,
    required this.title,
    this.trailing = const SizedBox.shrink(),
  });

  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          height: 1.04,
          letterSpacing: -0.4,
        );

    return Row(
      children: [
        Text(title, style: style),
        const Spacer(),
        trailing,
      ],
    );
  }
}

class HeaderCircleIconButton extends StatelessWidget {
  const HeaderCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconSize = 28,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF3A3B42) : const Color(0xFFD7D7DC),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? const Color(0xFFA7A8AE) : const Color(0xFF8D8D94),
            size: iconSize,
          ),
        ),
      ),
    );
  }
}