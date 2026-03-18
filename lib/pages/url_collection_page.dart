import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:galaxy_ios/models/saved_link.dart';
import 'package:webview_flutter/webview_flutter.dart';

class UrlCollectionPage extends StatefulWidget {
  const UrlCollectionPage({super.key});

  @override
  State<UrlCollectionPage> createState() => _UrlCollectionPageState();
}

class _UrlCollectionPageState extends State<UrlCollectionPage> {
  final Box _linksBox = Hive.box('links');
  final List<SavedLink> _links = [];

  @override
  void initState() {
    super.initState();
    _loadLinks();
  }

  void _loadLinks() {
    final stored = _linksBox.get('items');
    if (stored is List) {
      _links
        ..clear()
        ..addAll(stored.whereType<Map>().map(SavedLink.fromMap));
    }
  }

  Future<void> _saveLinks() async {
    await _linksBox.put(
      'items',
      _links.map((link) => link.toMap()).toList(),
    );
  }

  Future<void> _openAddDialog() async {
    final result = await showDialog<_LinkFormResult>(
      context: context,
      builder: (context) => const _LinkDialog(),
    );
    if (result == null) return;
    final link = SavedLink(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: result.url,
      title: result.title.isEmpty ? result.url : result.title,
      createdAt: DateTime.now(),
    );
    setState(() {
      _links.insert(0, link);
    });
    await _saveLinks();
  }

  Future<void> _openEditDialog(SavedLink link) async {
    final result = await showDialog<_LinkFormResult>(
      context: context,
      builder: (context) => _LinkDialog(
        dialogTitle: '编辑网址',
        initialUrl: link.url,
        initialTitle: link.title,
      ),
    );
    if (result == null) return;
    final updated = SavedLink(
      id: link.id,
      url: result.url,
      title: result.title.isEmpty ? result.url : result.title,
      createdAt: link.createdAt,
    );
    setState(() {
      final index = _links.indexWhere((item) => item.id == link.id);
      if (index != -1) {
        _links[index] = updated;
      }
    });
    await _saveLinks();
  }

  Future<void> _removeLink(SavedLink link) async {
    setState(() {
      _links.removeWhere((item) => item.id == link.id);
    });
    await _saveLinks();
  }

  Future<void> _openLink(SavedLink link) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebEmbedPage(link: link),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const pageBackground = Color(0xFFF4F4F6);
    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Text('收藏夹'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _CapsuleActionButton(
              label: '新增',
              icon: Icons.add_rounded,
              onPressed: _openAddDialog,
            ),
          ),
        ],
      ),
      body: _links.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              itemCount: _links.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final link = _links[index];
                return _LinkCard(
                  link: link,
                  onTap: () => _openLink(link),
                  onEdit: () => _openEditDialog(link),
                  onDelete: () => _removeLink(link),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.bookmark_border,
                color: Color(0xFF5B7BFF),
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '还没有保存网址',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '点击右上角新增一个网址',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.link,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final SavedLink link;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _ThumbnailBox(title: link.title),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatMeta(link),
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  IconButton(
                    tooltip: '编辑',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '删除',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
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

class _ThumbnailBox extends StatelessWidget {
  const _ThumbnailBox({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF7A8BFF),
      const Color(0xFF8BC6FF),
      const Color(0xFF9B8DFF),
      const Color(0xFF6EC7C7),
    ];
    final color = colors[title.hashCode.abs() % colors.length];
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.65),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        title.isNotEmpty ? title.characters.first.toUpperCase() : 'W',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }
}

class _CapsuleActionButton extends StatelessWidget {
  const _CapsuleActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [
                Color(0xFF8B7DFF),
                Color(0xFF4EA7FF),
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3D5A7BFF),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatMeta(SavedLink link) {
  final date = link.createdAt;
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day · 已收藏';
}

class WebEmbedPage extends StatefulWidget {
  const WebEmbedPage({super.key, required this.link});

  final SavedLink link;

  @override
  State<WebEmbedPage> createState() => _WebEmbedPageState();
}

class _WebEmbedPageState extends State<WebEmbedPage> {
  bool _loading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.link.title),
      ),
      body: Stack(
        children: [
          WebViewWrapper(
            url: widget.link.url,
            onPageFinished: () => setState(() => _loading = false),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

class WebViewWrapper extends StatefulWidget {
  const WebViewWrapper({
    super.key,
    required this.url,
    required this.onPageFinished,
  });

  final String url;
  final VoidCallback onPageFinished;

  @override
  State<WebViewWrapper> createState() => _WebViewWrapperState();
}

class _WebViewWrapperState extends State<WebViewWrapper> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => widget.onPageFinished(),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({
    this.dialogTitle = '新增网址',
    this.initialUrl,
    this.initialTitle,
  });

  final String dialogTitle;
  final String? initialUrl;
  final String? initialTitle;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _urlController;
  late final TextEditingController _titleController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _titleController =
        TextEditingController(text: widget.initialTitle ?? '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  bool _isValidUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

  void _submit() {
    final url = _urlController.text.trim();
    final title = _titleController.text.trim();
    if (!_isValidUrl(url)) {
      setState(() => _errorText = '请输入有效的 http/https 网址');
      return;
    }
    Navigator.of(context).pop(_LinkFormResult(url: url, title: title));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: '网址',
              hintText: 'https://example.com',
              errorText: _errorText,
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: '标题（可选）',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _LinkFormResult {
  const _LinkFormResult({required this.url, required this.title});

  final String url;
  final String title;
}