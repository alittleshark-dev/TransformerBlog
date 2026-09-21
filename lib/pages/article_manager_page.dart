import 'package:flutter/material.dart';

import '../models.dart';
import 'article_editor_page.dart';

/// 文章管理页，只在编辑模式下进得来。
///
/// 列出全部文章，可以新建、编辑、删除。每次改动都会立刻通过 [onSave]
/// 交给首页写进本地存储，部署了后端时还会一起写回 articles.json。
class ArticleManagerPage extends StatefulWidget {
  const ArticleManagerPage({
    super.key,
    required this.articles,
    required this.onSave,
    this.savedToServer = false,
  });

  final List<Article> articles;
  final Future<void> Function(List<Article> articles) onSave;

  /// 部署了 server/server.dart 没有。只用来决定提示文案怎么写，
  /// 免得明明已经写进 JSON 了，还告诉用户「只存在浏览器里」。
  final bool savedToServer;

  @override
  State<ArticleManagerPage> createState() => _ArticleManagerPageState();
}

class _ArticleManagerPageState extends State<ArticleManagerPage> {
  late List<Article> _articles = <Article>[...widget.articles];

  Future<void> _create() async {
    final Article? created = await ArticleEditorPage.open(context);
    if (created == null || !mounted) return;
    setState(() => _articles = <Article>[created, ..._articles]);
    await widget.onSave(_articles);
  }

  Future<void> _edit(int index) async {
    final Article? updated = await ArticleEditorPage.open(
      context,
      initial: _articles[index],
    );
    if (updated == null || !mounted) return;
    setState(() {
      _articles = <Article>[..._articles]..[index] = updated;
    });
    await widget.onSave(_articles);
  }

  Future<void> _delete(int index) async {
    final bool confirmed = await _confirmDelete(_articles[index].title);
    if (!confirmed || !mounted) return;
    setState(() => _articles = <Article>[..._articles]..removeAt(index));
    await widget.onSave(_articles);
  }

  Future<bool> _confirmDelete(String title) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('删除文章'),
        content: Text('确定要删除《$title》吗？删掉之后恢复不了。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文章管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建文章',
            onPressed: _create,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildNotice(context),
          Expanded(
            child: _articles.isEmpty
                ? _buildEmpty(context)
                : _buildList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        widget.savedToServer
            ? '改动会立刻写进 assets/data/articles.json，所有访客都能看到。'
            : '改动只保存在当前浏览器，不会写回 assets/data/articles.json。'
                '要让访客看到，得部署 server/server.dart，'
                '或者用「导出配置」把内容填回那个文件。',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.article_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            '还没有文章',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '点右上角的 + 新建一篇',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView.separated(
      itemCount: _articles.length,
      separatorBuilder: (BuildContext context, int index) =>
          const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final Article article = _articles[index];
        final String meta = <String>[
          if (article.date.isNotEmpty) article.date,
          ...article.tags,
        ].join('   ·   ');

        return ListTile(
          title: Text(article.title),
          subtitle: meta.isEmpty ? null : Text(meta),
          onTap: () => _edit(index),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: '编辑',
                onPressed: () => _edit(index),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: '删除',
                onPressed: () => _delete(index),
              ),
            ],
          ),
        );
      },
    );
  }
}
