import 'package:flutter/material.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.controller});

  final MqttController controller;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late List<String> _logs;
  late DateTime _lastRefreshAt;

  @override
  void initState() {
    super.initState();
    _refreshLogs();
  }

  Future<void> _refreshLogs() async {
    setState(() {
      _logs = List<String>.from(widget.controller.notificationDebugLogs.reversed);
      _lastRefreshAt = DateTime.now();
    });
  }

  String get _refreshTimeText {
    final t = _lastRefreshAt;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = t.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final cardColor = isDark ? const Color(0xFF1C1D23) : Colors.white;
    final textColor = isDark ? const Color(0xFFE7E8EC) : const Color(0xFF1C1D23);
    final subTextColor = isDark ? const Color(0xFF9A9AA0) : const Color(0xFF8C8C93);
    final lineColor = isDark ? const Color(0xFF2A2B31) : const Color(0xFFE7E7EC);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1D23) : const Color(0xFFE7E7EC),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chevron_left_rounded,
                          size: 32,
                          color: isDark ? const Color(0xFFB6B8C0) : const Color(0xFF4A79D9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '日志',
                    style: TextStyle(
                      fontSize: 40 / 1.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '刷新日志',
                    onPressed: _refreshLogs,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.update_rounded, color: subTextColor),
                    const SizedBox(width: 8),
                    Text(
                      '最后刷新: $_refreshTimeText',
                      style: TextStyle(fontSize: 16, color: subTextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _logs.isEmpty
                      ? Center(
                          child: Text(
                            '暂无日志',
                            style: TextStyle(fontSize: 16, color: subTextColor),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refreshLogs,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            itemCount: _logs.length,
                            separatorBuilder: (_, _) => Divider(color: lineColor, height: 12),
                            itemBuilder: (context, index) {
                              return Text(
                                _logs[index],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textColor,
                                  height: 1.45,
                                ),
                              );
                            },
                          ),
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
