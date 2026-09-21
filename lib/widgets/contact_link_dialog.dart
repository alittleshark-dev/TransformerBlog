import 'package:flutter/material.dart';

import '../models.dart';

/// 新增或修改一条联系方式的对话框。
///
/// 保存时返回新的 [ContactLink]，取消返回 null。
class ContactLinkDialog extends StatefulWidget {
  const ContactLinkDialog({super.key, this.initial});

  /// 为 null 表示新增。
  final ContactLink? initial;

  static Future<ContactLink?> show(
    BuildContext context, {
    ContactLink? initial,
  }) {
    return showDialog<ContactLink>(
      context: context,
      builder: (BuildContext context) => ContactLinkDialog(initial: initial),
    );
  }

  @override
  State<ContactLinkDialog> createState() => _ContactLinkDialogState();
}

class _ContactLinkDialogState extends State<ContactLinkDialog> {
  late final TextEditingController _label = TextEditingController(
    text: widget.initial?.label ?? '',
  );
  late final TextEditingController _value = TextEditingController(
    text: widget.initial?.value ?? '',
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.initial?.url ?? '',
  );
  String? _errorText;

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final String label = _label.text.trim();
    final String value = _value.text.trim();
    final String url = _url.text.trim();
    if (label.isEmpty || value.isEmpty) {
      setState(() => _errorText = '名称和内容都要填');
      return;
    }
    Navigator.of(context).pop(
      ContactLink(
        label: label,
        value: value,
        url: url.isEmpty ? null : url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? '添加联系方式' : '修改联系方式'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _label,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: 'Github',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _value,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: 'your-name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              onSubmitted: (String _) => _submit(),
              decoration: const InputDecoration(
                labelText: '链接（可留空）',
                hintText: 'https://github.com/your-name',
              ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorText!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '填了链接才会变成可点的，留空就只显示文字',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}
