import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../url_utils.dart';

/// 按站点风格渲染 Markdown，详情页和编辑器预览共用。
class MarkdownView extends StatelessWidget {
  const MarkdownView({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: markdownStyleSheet(Theme.of(context)),
      onTapLink: (String text, String? href, String title) {
        if (href == null || href.isEmpty) return;
        openExternalUrl(context, href);
      },
    );
  }
}

/// 正文的 Markdown 样式，颜色跟随主题。
MarkdownStyleSheet markdownStyleSheet(ThemeData theme) {
  final ColorScheme scheme = theme.colorScheme;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
    h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
    h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
    h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    a: TextStyle(color: scheme.primary, decoration: TextDecoration.underline),
    em: theme.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
    strong: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
    blockquote: theme.textTheme.bodyLarge?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.7,
    ),
    blockquoteDecoration: BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.08),
      border: Border(
        left: BorderSide(color: scheme.primary, width: 4),
      ),
    ),
    code: TextStyle(
      fontFamily: 'Consolas',
      fontFamilyFallback: const ['monospace', 'Courier New'],
      fontSize: 14,
      backgroundColor: scheme.primary.withValues(alpha: 0.08),
    ),
    codeblockDecoration: BoxDecoration(
      color: scheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    listBullet: theme.textTheme.bodyLarge,
  );
}
