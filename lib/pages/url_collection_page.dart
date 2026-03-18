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
      builder: (context) => const _AddLinkDialog(),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('网址收藏'),
        actions: [
          IconButton(
            tooltip: '新增网址',
            onPressed: _openAddDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _links.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _links.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final link = _links[index];
                return _LinkCard(
                  link: link,
                  onTap: () => _openLink(link),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            '还没有保存网址',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            '点击右上角 + 添加一个网址',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.link,
    required this.onTap,
    required this.onDelete,
  });

  final SavedLink link;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.public,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      link.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '删除',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  String? _errorText;

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
      title: const Text('新增网址'),
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