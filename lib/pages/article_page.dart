import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/markdown_view.dart';

/// 文章详情页，正文按 Markdown 渲染。
class ArticlePage extends StatelessWidget {
  const ArticlePage({super.key, required this.article});

  final Article article;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String meta = <String>[
      if (article.date.isNotEmpty) article.date,
      ...article.tags,
    ].join('   ·   ');

    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      meta,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Divider(height: 32),
                  if (article.content.trim().isEmpty)
                    Text(
                      '暂无正文',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    MarkdownView(data: article.content),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
