import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'package:galaxy_ios/controllers/mqtt_controller.dart';
import 'package:galaxy_ios/pages/logs_page.dart';
import 'package:galaxy_ios/widgets/page_header.dart';

class SettingsPage extends StatefulWidget {
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
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _checkingUpdate = false;
  _UpdateDownloadState _downloadState = _UpdateDownloadState.idle;
  String? _downloadedFilePath;
  String? _downloadError;
  int _receivedBytes = 0;
  int? _totalBytes;
  double _downloadSpeedBytesPerSec = 0;
  DateTime? _downloadStartedAt;
  http.Client? _downloadClient;
  StreamSubscription<List<int>>? _downloadSubscription;
  IOSink? _downloadSink;
  File? _partialDownloadFile;
  bool _downloadCancelled = false;
  StateSetter? _updateDialogSetState;

  @override
  void dispose() {
    unawaited(_cancelDownload(silent: true));
    super.dispose();
  }

  void _refreshUpdateDialog() {
    if (mounted) {
      setState(() {});
    }
    final dialogSetState = _updateDialogSetState;
    if (dialogSetState != null) {
      dialogSetState(() {});
    }
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    try {
      final uri = Uri.parse(
        'https://api.github.com/repos/ge-fei-fan/galaxy-ios/releases/latest',
      );
      final response = await http.get(
        uri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('请求失败（HTTP ${response.statusCode}）');
      }

      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('返回数据格式错误');
      }

      final tagName = (data['tag_name'] as String? ?? '').trim();
      final ipaUrl = _extractIpaUrl(data);
      _downloadState = _UpdateDownloadState.idle;
      _downloadedFilePath = null;
      _downloadError = null;
      _receivedBytes = 0;
      _totalBytes = null;
      _downloadSpeedBytesPerSec = 0;
      if (!mounted) return;
      await _showUpdateDialog(tagName: tagName, ipaUrl: ipaUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('检查更新失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }
  }

  String? _extractIpaUrl(Map<String, dynamic> data) {
    final assets = data['assets'];
    if (assets is! List) return null;

    for (final item in assets) {
      if (item is! Map) continue;
      final rawUrl = item['browser_download_url']?.toString();
      if (rawUrl == null || rawUrl.isEmpty) continue;
      if (rawUrl.toLowerCase().endsWith('.ipa')) {
        return rawUrl;
      }
    }

    for (final item in assets) {
      if (item is! Map) continue;
      final rawUrl = item['browser_download_url']?.toString();
      if (rawUrl != null && rawUrl.isNotEmpty) {
        return rawUrl;
      }
    }
    return null;
  }

  Future<void> _showUpdateDialog({
    required String tagName,
    required String? ipaUrl,
  }) async {
    final displayTag = tagName.isEmpty ? '(未提供 tag_name)' : tagName;

    await showDialog<void>(
      context: context,
      barrierDismissible: _downloadState != _UpdateDownloadState.downloading,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            _updateDialogSetState = dialogSetState;
            return PopScope(
              canPop: _downloadState != _UpdateDownloadState.downloading,
              child: AlertDialog(
                title: const Text('检查更新'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('最新版本：$displayTag'),
                    const SizedBox(height: 8),
                    Text(_buildUpdateStatusText(ipaUrl)),
                    if (_downloadState == _UpdateDownloadState.downloading ||
                        _downloadState == _UpdateDownloadState.completed ||
                        _downloadState == _UpdateDownloadState.failed ||
                        _downloadState == _UpdateDownloadState.cancelled) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: _progressValue),
                      const SizedBox(height: 8),
                      Text(_buildProgressDetailText()),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: _downloadState == _UpdateDownloadState.downloading
                        ? () => _cancelDownload()
                        : () {
                            _updateDialogSetState = null;
                            Navigator.of(dialogContext).pop();
                          },
                    child: Text(
                      _downloadState == _UpdateDownloadState.downloading ? '取消下载' : '关闭',
                    ),
                  ),
                  if (_downloadState == _UpdateDownloadState.completed)
                    FilledButton(
                      onPressed: _downloadedFilePath == null
                          ? null
                          : () async {
                              final message = await widget.controller
                                  .installLocalIpaViaTrollStore(_downloadedFilePath!);
                              if (!mounted) return;
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(message)));
                            },
                      child: const Text('安装'),
                    )
                  else
                    FilledButton(
                      onPressed: ipaUrl == null ||
                              _downloadState == _UpdateDownloadState.downloading
                          ? null
                          : () => _startDownload(ipaUrl, tagName: tagName),
                      child: Text(
                        _downloadState == _UpdateDownloadState.failed ||
                                _downloadState == _UpdateDownloadState.cancelled
                            ? '重新下载'
                            : '下载更新',
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );

    _updateDialogSetState = null;
  }

  Future<void> _startDownload(String ipaUrl, {required String tagName}) async {
    if (_downloadState == _UpdateDownloadState.downloading) return;

    _downloadCancelled = false;
    _downloadedFilePath = null;
    _downloadError = null;
    _receivedBytes = 0;
    _totalBytes = null;
    _downloadSpeedBytesPerSec = 0;
    _downloadStartedAt = DateTime.now();
    _downloadState = _UpdateDownloadState.downloading;
    _refreshUpdateDialog();

    final client = http.Client();
    _downloadClient = client;

    try {
      final uri = Uri.parse(ipaUrl);
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('下载失败（HTTP ${response.statusCode}）');
      }

      final total = response.contentLength;
      _totalBytes = total != null && total > 0 ? total : null;

      final dir = await _ensureUpdateDirectory();
      final safeTag = _sanitizeFileName(tagName.isEmpty ? 'latest' : tagName);
      final finalFile = File('${dir.path}${Platform.pathSeparator}galaxy_ios_$safeTag.ipa');
      final partialFile = File('${finalFile.path}.part');
      _partialDownloadFile = partialFile;

      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      if (await finalFile.exists()) {
        await finalFile.delete();
      }

      await partialFile.create(recursive: true);
      final sink = partialFile.openWrite();
      _downloadSink = sink;

      final completer = Completer<void>();
      _downloadSubscription = response.stream.listen(
        (chunk) {
          if (_downloadCancelled) return;
          sink.add(chunk);
          _receivedBytes += chunk.length;
          final startedAt = _downloadStartedAt;
          if (startedAt != null) {
            final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
            if (elapsedMs > 0) {
              _downloadSpeedBytesPerSec = _receivedBytes / (elapsedMs / 1000);
            }
          }
          _refreshUpdateDialog();
        },
        onDone: () async {
          if (completer.isCompleted) return;
          try {
            await sink.flush();
            await sink.close();
            _downloadSink = null;

            if (_downloadCancelled) {
              if (await partialFile.exists()) {
                await partialFile.delete();
              }
              if (!completer.isCompleted) completer.complete();
              return;
            }

            await partialFile.rename(finalFile.path);
            _downloadedFilePath = finalFile.path;
            _downloadState = _UpdateDownloadState.completed;
            _refreshUpdateDialog();
            completer.complete();
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
        onError: (error, _) async {
          if (_downloadCancelled) {
            if (!completer.isCompleted) completer.complete();
            return;
          }
          if (_downloadSink != null) {
            await _downloadSink?.close();
            _downloadSink = null;
          }
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      if (_downloadCancelled) {
        _downloadState = _UpdateDownloadState.cancelled;
      } else {
        _downloadState = _UpdateDownloadState.failed;
        _downloadError = e.toString();
      }
      _refreshUpdateDialog();
    } finally {
      await _downloadSubscription?.cancel();
      _downloadSubscription = null;
      _downloadClient?.close();
      _downloadClient = null;
      if (_downloadCancelled && _downloadState != _UpdateDownloadState.completed) {
        _downloadState = _UpdateDownloadState.cancelled;
        _refreshUpdateDialog();
      }
    }
  }

  Future<void> _cancelDownload({bool silent = false}) async {
    if (_downloadState != _UpdateDownloadState.downloading) return;
    _downloadCancelled = true;
    _downloadClient?.close();
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    await _downloadSink?.close();
    _downloadSink = null;
    final partialFile = _partialDownloadFile;
    _partialDownloadFile = null;
    if (partialFile != null && await partialFile.exists()) {
      await partialFile.delete();
    }
    _downloadState = _UpdateDownloadState.cancelled;
    if (!silent) {
      _refreshUpdateDialog();
    }
  }

  Future<Directory> _ensureUpdateDirectory() async {
    final baseDir = await getTemporaryDirectory();
    final dir = Directory(
      '${baseDir.path}${Platform.pathSeparator}galaxy_ios_updates',
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _buildUpdateStatusText(String? ipaUrl) {
    switch (_downloadState) {
      case _UpdateDownloadState.idle:
        return ipaUrl == null ? '未找到可用的 browser_download_url' : '已找到 IPA 下载地址，可先下载再安装。';
      case _UpdateDownloadState.downloading:
        return '正在下载 IPA，请稍候…';
      case _UpdateDownloadState.completed:
        return '下载完成，已可跳转 TrollStore 安装。';
      case _UpdateDownloadState.failed:
        return '下载失败：${_downloadError ?? '未知错误'}';
      case _UpdateDownloadState.cancelled:
        return '下载已取消。';
    }
  }

  double? get _progressValue {
    final total = _totalBytes;
    if (total == null || total <= 0) return null;
    return (_receivedBytes / total).clamp(0, 1).toDouble();
  }

  String _buildProgressDetailText() {
    final downloaded = _formatBytes(_receivedBytes);
    final total = _totalBytes == null ? '未知大小' : _formatBytes(_totalBytes!);
    final speed = _downloadSpeedBytesPerSec <= 0
        ? '--/s'
        : '${_formatBytes(_downloadSpeedBytesPerSec.round())}/s';
    final percent = _progressValue == null
        ? '正在下载'
        : '${(_progressValue! * 100).toStringAsFixed(1)}%';
    return '$percent · $downloaded / $total · $speed';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    double value = bytes / 1024;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : value >= 10 ? 1 : 2)} ${units[unitIndex]}';
  }

  String _sanitizeFileName(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121318) : const Color(0xFFF2F1F6);
    final cardColor = isDark ? const Color(0xFF1C1D23) : Colors.white;
    final sectionTitleColor = isDark
        ? const Color(0xFF9A9AA0)
        : const Color(0xFF8C8C93);
    final lineColor = isDark
        ? const Color(0xFF2A2B31)
        : const Color(0xFFE7E7EC);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 16),
          child: ListView(
            children: [
              Column(
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
                        fontWeight: FontWeight.w700,
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
                          isDarkMode: widget.isDarkMode,
                          onThemeModeChanged: widget.onThemeModeChanged,
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 72, right: 18),
                          color: lineColor,
                        ),
                        const _GeneralRow(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      '其他',
                      style: TextStyle(
                        fontSize: 14,
                        color: sectionTitleColor,
                        fontWeight: FontWeight.w700,
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
                        _LogsRow(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    LogsPage(controller: widget.controller),
                              ),
                            );
                          },
                        ),
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 72, right: 18),
                          color: lineColor,
                        ),
                        _CheckUpdateRow(
                          checking: _checkingUpdate,
                          onTap: _checkUpdate,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _UpdateDownloadState { idle, downloading, completed, failed, cancelled }

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.isDarkMode, required this.onThemeModeChanged});

  final bool isDarkMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chipBg = isDark ? const Color(0xFF2A2C32) : const Color(0xFFF0F0F4);
    final activeBg = isDark ? const Color(0xFF3B3D44) : Colors.white;
    final activeColor = Theme.of(context).colorScheme.primary;
    final normalColor = isDark
        ? const Color(0xFF9FA1A8)
        : const Color(0xFF7D7F87);

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
            margin: const EdgeInsets.all(2),
            height: 28,
            decoration: BoxDecoration(
              color: active ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              icon,
              size: 18,
              color: active ? activeColor : normalColor,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
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
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
              ),
            ),
            Container(
              width: 132,
              height: 36,
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
      ),
    );
  }
}

class _GeneralRow extends StatelessWidget {
  const _GeneralRow();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {},
        child: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF9FA3AE),
                child: Icon(Icons.settings, size: 18, color: Colors.white),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  '通用',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogsRow extends StatelessWidget {
  const _LogsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF6DAAFD),
                child: Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  '日志',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckUpdateRow extends StatelessWidget {
  const _CheckUpdateRow({required this.onTap, required this.checking});

  final VoidCallback onTap;
  final bool checking;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: checking ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF6FD08C),
                child: Icon(
                  Icons.system_update_alt,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  '检查更新',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                ),
              ),
              if (checking)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
