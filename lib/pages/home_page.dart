import 'dart:async';

import 'package:flutter/material.dart';

import 'package:galaxy_ios/models/device_status_snapshot.dart';
import 'package:galaxy_ios/services/device_status_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final DeviceStatusService _service;

  @override
  void initState() {
    super.initState();
    _service = DeviceStatusService();
    _service.start();
  }

  @override
  void dispose() {
    unawaited(_service.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final palette = _DashboardPalette.from(colorScheme);

    return SafeArea(
      top: true,
      bottom: false,
      child: StreamBuilder<DeviceStatusSnapshot>(
        stream: _service.stream,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final vmTotal = data?.memoryTotalBytes;
          final vmUsed = data?.memoryUsedBytes;
          final storageTotal = data?.storageTotalBytes;
          final storageUsed = data?.storageUsedBytes;

          final batteryPercent = data?.batteryLevelPercent;
          final cpuPercent = data?.cpuUsagePercent;

          final downSpeed = data?.downloadSpeedBytesPerSec;
          final upSpeed = data?.uploadSpeedBytesPerSec;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Text(
                'Device Status+',
                style: textTheme.displaySmall?.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.02,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '实时设备监控和传感器控制',
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  color: textTheme.bodyMedium?.color?.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 16),
              _DeviceOverviewCard(
                colorScheme: colorScheme,
                palette: palette,
                deviceName: data?.deviceName ?? '当前设备',
                osVersion: _buildSystemVersion(data),
                model: _orDash(data?.modelIdentifier),
                storageTotal: _formatCapacity(storageTotal),
                chip: _orDash(data?.chip),
                memoryTotal: _formatCapacity(vmTotal),
                uptime: _formatUptime(data?.uptimeSeconds),
                bootAt: _formatDateTime(data?.bootAt),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.28,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _MetricCard(
                    colorScheme: colorScheme,
                    title: 'CPU',
                    icon: Icons.memory_rounded,
                    valueLabel: _formatPercent(cpuPercent),
                    subLabel: '',
                    progress: _toProgress(cpuPercent),
                    accent: palette.cpu,
                  ),
                  _MetricCard(
                    colorScheme: colorScheme,
                    title: '运行内存',
                    icon: Icons.developer_board_rounded,
                    valueLabel: _formatPercent(
                      _computePercent(vmUsed, vmTotal),
                    ),
                    subLabel: _formatUsage(vmUsed, vmTotal),
                    progress: _toProgress(_computePercent(vmUsed, vmTotal)),
                    accent: palette.memory,
                  ),
                  _MetricCard(
                    colorScheme: colorScheme,
                    title: '存储空间',
                    icon: Icons.save_outlined,
                    valueLabel: _formatPercent(
                      _computePercent(storageUsed, storageTotal),
                    ),
                    subLabel: _formatUsage(storageUsed, storageTotal),
                    progress: _toProgress(
                      _computePercent(storageUsed, storageTotal),
                    ),
                    accent: palette.storage,
                  ),
                  _MetricCard(
                    colorScheme: colorScheme,
                    title: '电池',
                    icon: Icons.battery_std_rounded,
                    valueLabel: _formatPercent(batteryPercent),
                    subLabel: _batteryStateLabel(data?.batteryState),
                    progress: _toProgress(batteryPercent),
                    accent: palette.battery,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _NetworkCard(
                colorScheme: colorScheme,
                palette: palette,
                connectionLabel: _networkStateLabel(
                  data?.networkConnected,
                  data?.networkType,
                ),
                downSpeedLabel: _formatSpeed(downSpeed),
                upSpeedLabel: _formatSpeed(upSpeed),
                downTotalLabel: _formatBytes(data?.downloadTotalBytes),
                upTotalLabel: _formatBytes(data?.uploadTotalBytes),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _buildSystemVersion(DeviceStatusSnapshot? data) {
  final version = data?.systemVersion;
  if (version == null || version.isEmpty) return '--';
  return 'iOS $version';
}

String _orDash(String? value) =>
    (value == null || value.trim().isEmpty) ? '--' : value.trim();

double? _computePercent(num? used, num? total) {
  if (used == null || total == null || total <= 0) return null;
  return (used / total) * 100;
}

double _toProgress(double? percent) {
  if (percent == null) return 0;
  return (percent / 100).clamp(0.0, 1.0);
}

String _formatPercent(double? value) {
  if (value == null || value.isNaN) return '--';
  return '${value.clamp(0, 100).toStringAsFixed(1)}%';
}

String _formatCapacity(int? bytes) {
  if (bytes == null || bytes < 0) return '--';
  final gb = bytes / (1024 * 1024 * 1024);
  return '${gb.toStringAsFixed(1)} G';
}

String _formatUsage(num? used, num? total) {
  if (used == null || total == null || total <= 0) return '--';
  final usedGb = used / (1024 * 1024 * 1024);
  final totalGb = total / (1024 * 1024 * 1024);
  return '${usedGb.toStringAsFixed(1)} G / ${totalGb.toStringAsFixed(1)} G';
}

String _formatSpeed(double? bytesPerSec) {
  if (bytesPerSec == null || bytesPerSec < 0) return '--';
  final mb = bytesPerSec / (1024 * 1024);
  return '${mb.toStringAsFixed(2)} MB/s';
}

String _formatBytes(double? bytes) {
  if (bytes == null || bytes < 0) return '--';
  const gb = 1024 * 1024 * 1024;
  return '${(bytes / gb).toStringAsFixed(2)} GB';
}

String _formatUptime(int? seconds) {
  if (seconds == null || seconds < 0) return '--';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h ${m}m';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

String _formatDateTime(DateTime? dateTime) {
  if (dateTime == null) return '--';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)} '
      '${two(dateTime.hour)}:${two(dateTime.minute)}:${two(dateTime.second)}';
}

String _batteryStateLabel(String? state) {
  switch (state) {
    case 'charging':
      return '充电中';
    case 'full':
      return '已充满';
    case 'unplugged':
      return '未充电';
    case 'unknown':
      return '--';
    default:
      return '--';
  }
}

String _networkStateLabel(bool? connected, String? type) {
  if (connected == false) return '网络未连接';
  if (connected == true) {
    if (type == null || type.isEmpty) return '网络已连接';
    return '$type 已连接';
  }
  return '--';
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    required this.colorScheme,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
  });

  final Widget child;
  final ColorScheme colorScheme;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1C22) : Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.045),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DeviceOverviewCard extends StatelessWidget {
  const _DeviceOverviewCard({
    required this.colorScheme,
    required this.palette,
    required this.deviceName,
    required this.osVersion,
    required this.model,
    required this.storageTotal,
    required this.chip,
    required this.memoryTotal,
    required this.uptime,
    required this.bootAt,
  });

  final ColorScheme colorScheme;
  final _DashboardPalette palette;
  final String deviceName;
  final String osVersion;
  final String model;
  final String storageTotal;
  final String chip;
  final String memoryTotal;
  final String uptime;
  final String bootAt;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.phone.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.smartphone_rounded,
                  color: palette.phone,
                  size: 24,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.headlineMedium?.copyWith(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        height: 1.02,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      osVersion,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textTheme.bodySmall?.color?.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoCell(label: '型号', value: model),
                    const SizedBox(height: 8),
                    _InfoCell(label: '芯片', value: chip),
                    const SizedBox(height: 8),
                    _InfoCell(label: '启动时间', value: uptime),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoCell(label: '存储空间', value: storageTotal),
                    const SizedBox(height: 8),
                    _InfoCell(label: '内存', value: memoryTotal),
                    const SizedBox(height: 8),
                    _InfoCell(label: '重启日期', value: bootAt),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.06,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.titleMedium?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textTheme.bodySmall?.color?.withValues(alpha: 0.62),
            height: 1.06,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.colorScheme,
    required this.title,
    required this.icon,
    required this.valueLabel,
    required this.subLabel,
    required this.progress,
    required this.accent,
  });

  final ColorScheme colorScheme;
  final String title;
  final IconData icon;
  final String valueLabel;
  final String subLabel;
  final double progress;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      colorScheme: colorScheme,
      padding: const EdgeInsets.all(13),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: Colors.black.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Text(
                  subLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textTheme.bodySmall?.color?.withValues(alpha: 0.92),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                valueLabel,
                style: textTheme.titleLarge?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.colorScheme,
    required this.palette,
    required this.connectionLabel,
    required this.downSpeedLabel,
    required this.upSpeedLabel,
    required this.downTotalLabel,
    required this.upTotalLabel,
  });

  final ColorScheme colorScheme;
  final _DashboardPalette palette;
  final String connectionLabel;
  final String downSpeedLabel;
  final String upSpeedLabel;
  final String downTotalLabel;
  final String upTotalLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _GlassCard(
      colorScheme: colorScheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.network.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.wifi_rounded,
                  color: palette.network,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '网络',
                      style: textTheme.titleLarge?.copyWith(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '●  $connectionLabel',
                      style: textTheme.bodyLarge?.copyWith(
                        fontSize: 16,
                        color: palette.network,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '↓ $downSpeedLabel',
                    style: textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.network,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '↑ $upSpeedLabel',
                    style: textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.cpu,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 11),
          Divider(color: Colors.black.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '总使用量',
                style: textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  color: textTheme.bodySmall?.color?.withValues(alpha: 0.84),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    '↓ $downTotalLabel',
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.network,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '↑ $upTotalLabel',
                    style: textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: palette.cpu,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black.withValues(alpha: 0.02),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _GridLinePainter(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.only(right: 10, bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.primary.withValues(alpha: 0.2),
                          colorScheme.primary.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardPalette {
  const _DashboardPalette({
    required this.phone,
    required this.cpu,
    required this.memory,
    required this.storage,
    required this.battery,
    required this.network,
  });

  final Color phone;
  final Color cpu;
  final Color memory;
  final Color storage;
  final Color battery;
  final Color network;

  static _DashboardPalette from(ColorScheme scheme) {
    final cpu = scheme.primary;
    final memory =
        Color.lerp(scheme.primary, scheme.secondary, 0.55) ?? scheme.secondary;
    final storage =
        Color.lerp(scheme.tertiary, const Color(0xFFFF4FA0), 0.38) ??
            scheme.tertiary;
    final battery =
        Color.lerp(scheme.secondary, const Color(0xFF3ECC67), 0.68) ??
            scheme.secondary;
    final network =
        Color.lerp(scheme.secondary, const Color(0xFF34C759), 0.58) ??
            scheme.secondary;
    final phone =
        Color.lerp(scheme.primary, const Color(0xFF7A6BFF), 0.45) ??
            scheme.primary;

    return _DashboardPalette(
      phone: phone,
      cpu: cpu,
      memory: memory,
      storage: storage,
      battery: battery,
      network: network,
    );
  }
}

class _GridLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    const rows = 4;
    const cols = 4;

    for (var r = 1; r < rows; r++) {
      final y = size.height * r / rows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (var c = 1; c < cols; c++) {
      final x = size.width * c / cols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}