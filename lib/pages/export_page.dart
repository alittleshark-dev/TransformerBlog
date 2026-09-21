import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config_exporter.dart';

/// 导出页：把编辑模式下改过的内容显示成 JSON，方便复制回 assets/data。
class ExportPage extends StatefulWidget {
  const ExportPage({super.key, required this.files});

  final List<ExportedFile> files;

  static Future<void> open(BuildContext context, List<ExportedFile> files) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/manage/export'),
        builder: (BuildContext context) => ExportPage(files: files),
      ),
    );
  }

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: widget.files.length,
    vsync: this,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  ExportedFile get _current => widget.files[_tabs.index];

  Future<void> _copyCurrent() async {
    final ExportedFile file = _current;
    await Clipboard.setData(ClipboardData(text: file.content));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已复制 ${file.name}，粘贴覆盖到 ${file.path} 即可')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导出配置'),
        actions: [
          TextButton.icon(
            onPressed: _copyCurrent,
            icon: const Icon(Icons.copy),
            label: const Text('复制'),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final ExportedFile file in widget.files) Tab(text: file.name),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          for (final ExportedFile file in widget.files) _buildFile(file),
        ],
      ),
    );
  }

  Widget _buildFile(ExportedFile file) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            '整段复制，覆盖 ${file.path} 的内容，然后重启服务就生效了。',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              file.content,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontFamilyFallback: <String>['monospace', 'Courier New'],
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
