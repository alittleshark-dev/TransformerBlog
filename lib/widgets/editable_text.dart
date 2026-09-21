import 'package:flutter/material.dart';

import 'avatar_image.dart';

/// 编辑模式下可以点击修改的文字。
///
/// 非编辑模式下就是一段普通文字，排版和原来完全一致；
/// 进入编辑模式后加一层浅色底纹和下划线，提示这里可以点。
class EditableTextBlock extends StatelessWidget {
  const EditableTextBlock({
    super.key,
    required this.text,
    required this.editMode,
    required this.onEdit,
    this.style,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.placeholder = '（空，点击填写）',
  });

  final String text;
  final bool editMode;
  final VoidCallback onEdit;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;

  /// 编辑模式下内容为空时显示的提示，避免没内容时点不到。
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final bool isPlaceholder =
        editMode && text.isEmpty && placeholder.isNotEmpty;
    final Widget label = Text(
      isPlaceholder ? placeholder : text,
      style: isPlaceholder
          ? (style ?? const TextStyle()).copyWith(fontStyle: FontStyle.italic)
          : style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
    if (!editMode) return label;

    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '点击修改',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onEdit,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.06),
              border: Border(
                bottom: BorderSide(
                  color: scheme.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: label,
          ),
        ),
      ),
    );
  }
}

/// 修改文字的对话框，保存时返回新内容，取消返回 null。
class EditTextDialog extends StatefulWidget {
  const EditTextDialog({
    super.key,
    required this.title,
    required this.initialValue,
    this.multiline = false,
  });

  final String title;
  final String initialValue;
  final bool multiline;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String initialValue,
    bool multiline = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => EditTextDialog(
        title: title,
        initialValue: initialValue,
        multiline: multiline,
      ),
    );
  }

  @override
  State<EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<EditTextDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: widget.multiline ? 3 : 1,
        maxLines: widget.multiline ? 5 : 1,
        onSubmitted: widget.multiline ? null : (String _) => _submit(),
        decoration: const InputDecoration(labelText: '内容'),
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

/// 编辑模式下可以点击修改的头像。
///
/// 非编辑模式下就是原来那个头像，不加任何装饰。
class EditableAvatar extends StatelessWidget {
  const EditableAvatar({
    super.key,
    required this.child,
    required this.editMode,
    required this.onEdit,
  });

  final Widget child;
  final bool editMode;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (!editMode) return child;

    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '点击修改头像',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: onEdit,
          customBorder: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.primary, width: 2),
                ),
                child: child,
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.edit,
                    size: 12,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 修改图片地址的对话框，带实时预览。保存时返回新地址，取消返回 null。
///
/// 头像和站点图标都是「填一个图片地址 + 看预览」，文案不同而已，
/// 所以放在一个对话框里，用 [title] 之类参数区分。
class AvatarEditDialog extends StatefulWidget {
  const AvatarEditDialog({
    super.key,
    required this.initialValue,
    this.title = '修改头像',
    this.labelText = '图片地址',
    this.hintText = 'https://example.com/avatar.jpg',
    this.helperText = '可以填网络地址，也可以填 assets/images/ 下的相对路径；'
        '留空则显示默认图标',
  });

  final String initialValue;
  final String title;
  final String labelText;
  final String hintText;
  final String helperText;

  static Future<String?> show(
    BuildContext context, {
    required String initialValue,
    String title = '修改头像',
    String labelText = '图片地址',
    String hintText = 'https://example.com/avatar.jpg',
    String helperText = '可以填网络地址，也可以填 assets/images/ 下的相对路径；'
        '留空则显示默认图标',
  }) {
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) => AvatarEditDialog(
        initialValue: initialValue,
        title: title,
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
      ),
    );
  }

  @override
  State<AvatarEditDialog> createState() => _AvatarEditDialogState();
}

class _AvatarEditDialogState extends State<AvatarEditDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void initState() {
    super.initState();
    // 输入时刷新预览
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AvatarImage(url: _controller.text.trim(), size: 80),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            autofocus: true,
            onSubmitted: (String _) => _submit(),
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.helperText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
