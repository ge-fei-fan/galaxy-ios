import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/widgets/page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    required this.isDarkMode,
    required this.onThemeModeChanged,
  });

  final MqttController controller;
  final bool isDarkMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final cardColor = isDark ? const Color(0xFF1C1D23) : Colors.white;
    final sectionTitleColor =
        isDark ? const Color(0xFF9A9AA0) : const Color(0xFF8C8C93);
    final lineColor = isDark ? const Color(0xFF2A2B31) : const Color(0xFFE7E7EC);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppPageTitle(
                title: '设置',
                trailing: HeaderCircleIconButton(
                  icon: Icons.person_2_outlined,
                  onTap: () {},
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  '常规设定',
                  style: TextStyle(
                    fontSize: 14,
                    color: sectionTitleColor,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    if (!isDark)
                      const BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 14,
                        offset: Offset(0, 3),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    _ThemeRow(
                      isDarkMode: isDarkMode,
                      onThemeModeChanged: onThemeModeChanged,
                    ),
                    Divider(height: 1, indent: 72, endIndent: 18, color: lineColor),
                    const _GeneralRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.isDarkMode,
    required this.onThemeModeChanged,
  });

  final bool isDarkMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF2A2C32) : const Color(0xFFF0F0F4);
    final activeBg = isDark ? const Color(0xFF3B3D44) : Colors.white;
    final activeColor = Theme.of(context).colorScheme.primary;
    final normalColor = isDark ? const Color(0xFF9FA1A8) : const Color(0xFF7D7F87);

    Widget themeButton({
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(3),
            height: 34,
            decoration: BoxDecoration(
              color: active ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 20, color: active ? activeColor : normalColor),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: Color(0xFFB25CFF),
            child: Icon(Icons.brush_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '主题',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            width: 146,
            height: 42,
            decoration: BoxDecoration(
              color: chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                themeButton(
                  icon: Icons.wb_sunny_outlined,
                  active: !isDarkMode,
                  onTap: () => onThemeModeChanged(ThemeMode.light),
                ),
                themeButton(
                  icon: Icons.dark_mode_outlined,
                  active: isDarkMode,
                  onTap: () => onThemeModeChanged(ThemeMode.dark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneralRow extends StatelessWidget {
  const _GeneralRow();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 0,
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      leading: const CircleAvatar(
        radius: 17,
        backgroundColor: Color(0xFF9FA3AE),
        child: Icon(Icons.settings, size: 18, color: Colors.white),
      ),
      title: const Text(
        '通用',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 28),
      onTap: () {},
    );
  }
}
