import 'package:flutter/material.dart';

import '../models.dart';
import 'avatar_image.dart';

/// 新增或修改一条友链的对话框。
///
/// 保存时返回新的 [Friend]，取消返回 null。
class FriendDialog extends StatefulWidget {
  const FriendDialog({super.key, this.initial});

  /// 为 null 表示新增。
  final Friend? initial;

  static Future<Friend?> show(BuildContext context, {Friend? initial}) {
    return showDialog<Friend>(
      context: context,
      builder: (BuildContext context) => FriendDialog(initial: initial),
    );
  }

  @override
  State<FriendDialog> createState() => _FriendDialogState();
}

class _FriendDialogState extends State<FriendDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.initial?.description ?? '',
  );
  late final TextEditingController _avatar = TextEditingController(
    text: widget.initial?.avatar ?? '',
  );
  late final TextEditingController _url = TextEditingController(
    text: widget.initial?.url ?? '',
  );
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // 头像跟着输入实时预览
    _avatar.addListener(_onAvatarChanged);
  }

  void _onAvatarChanged() => setState(() {});

  @override
  void dispose() {
    _avatar.removeListener(_onAvatarChanged);
    _name.dispose();
    _description.dispose();
    _avatar.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '名称要填');
      return;
    }
    Navigator.of(context).pop(
      Friend(
        name: name,
        description: _description.text.trim(),
        avatar: _avatar.text.trim(),
        url: _url.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? '添加友链' : '修改友链'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AvatarImage(url: _avatar.text.trim(), size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '名称',
                      hintText: '朋友的站点',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '描述（可留空）',
                hintText: '一句话介绍',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _avatar,
              decoration: const InputDecoration(
                labelText: '头像地址（可留空）',
                hintText: 'https://example.com/avatar.jpg',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              onSubmitted: (String _) => _submit(),
              decoration: const InputDecoration(
                labelText: '链接（可留空）',
                hintText: 'https://example.com',
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
              '头像可以填网络地址，也可以填 assets/images/ 下的相对路径；'
              '链接留空就只展示、不可点击',
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
