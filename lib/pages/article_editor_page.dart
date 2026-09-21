import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/markdown_view.dart';

/// 文章编辑器，只在编辑模式下进得来。
///
/// 保存时把编辑好的 [Article] 返回给上一页，取消返回 null。
class ArticleEditorPage extends StatefulWidget {
  const ArticleEditorPage({super.key, this.initial});

  /// 为 null 表示新建。
  final Article? initial;

  static Future<Article?> open(BuildContext context, {Article? initial}) {
    return Navigator.of(context).push<Article>(
      MaterialPageRoute<Article>(
        settings: const RouteSettings(name: '/manage/articles/edit'),
        builder: (BuildContext context) => ArticleEditorPage(initial: initial),
      ),
    );
  }

  @override
  State<ArticleEditorPage> createState() => _ArticleEditorPageState();
}

class _ArticleEditorPageState extends State<ArticleEditorPage> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initial?.title ?? '',
  );
  late final TextEditingController _summary = TextEditingController(
    text: widget.initial?.summary ?? '',
  );
  late final TextEditingController _date = TextEditingController(
    text: widget.initial?.date ?? _formatDate(DateTime.now()),
  );
  late final TextEditingController _tags = TextEditingController(
    text: widget.initial?.tags.join('、') ?? '',
  );
  late final TextEditingController _content = TextEditingController(
    text: widget.initial?.content ?? '',
  );

  bool _previewing = false;
  String? _errorText;

  bool get _isNew => widget.initial == null;

  @override
  void initState() {
    super.initState();
    // 预览打开时才有必要跟着输入刷新
    _content.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (_previewing) setState(() {});
  }

  @override
  void dispose() {
    _content.removeListener(_onContentChanged);
    _title.dispose();
    _summary.dispose();
    _date.dispose();
    _tags.dispose();
    _content.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static DateTime? _parseDate(String value) {
    try {
      return DateTime.parse(value.trim());
    } on FormatException {
      return null;
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_date.text) ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() => _date.text = _formatDate(picked));
  }

  void _submit() {
    final String title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = '标题不能为空');
      return;
    }

    // 中英文逗号、顿号都当分隔符
    final List<String> tags = _tags.text
        .split(RegExp(r'[,，、]'))
        .map((String tag) => tag.trim())
        .where((String tag) => tag.isNotEmpty)
        .toList();

    Navigator.of(context).pop(
      Article(
        id: widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        summary: _summary.text.trim(),
        date: _date.text.trim(),
        content: _content.text,
        tags: tags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? '新建文章' : '编辑文章'),
        actions: [
          TextButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.check),
            label: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _title,
                    autofocus: _isNew,
                    style: theme.textTheme.titleLarge,
                    decoration: const InputDecoration(
                      labelText: '标题',
                      hintText: '文章标题',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _date,
                    onSubmitted: (String _) => _submit(),
                    decoration: InputDecoration(
                      labelText: '日期',
                      hintText: 'yyyy-MM-dd',
                      helperText: '归档按年月分组，格式别写错',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.calendar_today_outlined),
                        tooltip: '选日期',
                        onPressed: _pickDate,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _tags,
                    decoration: const InputDecoration(
                      labelText: '标签',
                      hintText: 'Flutter、Dart',
                      helperText: '多个标签用逗号或顿号隔开',
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _summary,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: '摘要',
                      hintText: '列表里显示的那一小段',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildContentHeader(theme),
                  const SizedBox(height: 8),
                  _previewing ? _buildPreview(theme) : _buildContentField(),
                  if (_errorText != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorText!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentHeader(ThemeData theme) {
    return Row(
      children: [
        Text(
          '正文',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text('编辑'),
              icon: Icon(Icons.edit_outlined),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text('预览'),
              icon: Icon(Icons.visibility_outlined),
            ),
          ],
          selected: <bool>{_previewing},
          onSelectionChanged: (Set<bool> value) =>
              setState(() => _previewing = value.first),
        ),
      ],
    );
  }

  Widget _buildContentField() {
    return TextField(
      controller: _content,
      maxLines: null,
      minLines: 16,
      keyboardType: TextInputType.multiline,
      style: const TextStyle(
        fontFamily: 'Consolas',
        fontFamilyFallback: <String>['monospace', 'Courier New'],
        fontSize: 15,
        height: 1.6,
      ),
      decoration: const InputDecoration(
        hintText: '支持 Markdown：# 标题、**加粗**、- 列表、`代码`……',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPreview(ThemeData theme) {
    final String content = _content.text;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 340),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      child: content.trim().isEmpty
          ? Text(
              '还没有正文',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : MarkdownView(data: content),
    );
  }
}
