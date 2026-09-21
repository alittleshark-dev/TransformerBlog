import 'package:flutter/material.dart';

/// 修改编辑模式密码的对话框。
///
/// 通过时返回新密码，取消返回 null。
class PasswordChangeDialog extends StatefulWidget {
  const PasswordChangeDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => const PasswordChangeDialog(),
    );
  }

  @override
  State<PasswordChangeDialog> createState() => _PasswordChangeDialogState();
}

class _PasswordChangeDialogState extends State<PasswordChangeDialog> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final String password = _password.text;
    if (password.isEmpty) {
      setState(() => _errorText = '新密码不能为空');
      return;
    }
    if (password != _confirm.text) {
      setState(() => _errorText = '两次输入不一致');
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: const Text('修改编辑密码'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _password,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新密码'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirm,
              obscureText: true,
              onSubmitted: (String _) => _submit(),
              decoration: InputDecoration(
                labelText: '再输一次',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '改完之后，进入编辑模式要用新密码。\n'
              '密码保存在 profile.json 的 editPassword 里，'
              '部署了后端时由服务端校验，没部署就只是前端校验。',
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
