import 'package:flutter/material.dart';

import '../app_settings.dart';
import 'avatar_image.dart';

/// 深浅色切换按钮，任何时候都能用。
class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? '切换到浅色' : '切换到深色',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return RotationTransition(
            turns: Tween<double>(begin: 0.6, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
        child: Icon(
          isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          key: ValueKey<bool>(isDark),
        ),
      ),
      onPressed: () => settings.setDarkMode(!isDark),
    );
  }
}

/// 进入编辑模式的按钮。
class EditModeButton extends StatelessWidget {
  const EditModeButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.lock_outline),
      tooltip: '编辑模式',
      onPressed: onPressed,
    );
  }
}

/// 密码输入框，密码正确时返回 true。
class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key, required this.password});

  final String password;

  /// 弹出密码框，返回是否通过校验。
  static Future<bool> show(BuildContext context, String password) async {
    final bool? passed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => PasswordDialog(password: password),
    );
    return passed ?? false;
  }

  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text == widget.password) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _errorText = '密码不正确');
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('进入编辑模式'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: true,
        onSubmitted: (String _) => _submit(),
        decoration: InputDecoration(
          labelText: '密码',
          errorText: _errorText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('确定')),
      ],
    );
  }
}

/// 编辑模式下的面板：调主色调，以及恢复被改过的文字。
class ColorPanel extends StatefulWidget {
  const ColorPanel({
    super.key,
    required this.settings,
    this.onResetText,
    this.onExport,
    this.onEditFavicon,
    this.onChangePassword,
    this.favicon = '',
    this.hasTextChanges = false,
    this.savedToServer = false,
  });

  final AppSettings settings;

  /// 恢复默认文字，编辑模式下才有意义。
  final VoidCallback? onResetText;

  /// 把改过的内容导出成 JSON，编辑模式下才有意义。
  final VoidCallback? onExport;

  /// 改浏览器标签页上的站点图标，编辑模式下才有意义。
  final VoidCallback? onEditFavicon;

  /// 改编辑模式密码，编辑模式下才有意义。
  final VoidCallback? onChangePassword;

  /// 当前站点图标，用来在面板里预览。
  final String favicon;

  /// 是否改过文字，用来决定提示怎么显示。
  final bool hasTextChanges;

  /// 部署了后端没有，用来决定提示里说的是「写进服务器」还是「只在本地」。
  final bool savedToServer;

  @override
  State<ColorPanel> createState() => _ColorPanelState();
}

class _ColorPanelState extends State<ColorPanel> {
  /// 预设的几个常用主色，方便一键切换。
  static const List<Color> _presets = <Color>[
    Color(0xFF2196F3),
    Color(0xFF3F51B5),
    Color(0xFF009688),
    Color(0xFF4CAF50),
    Color(0xFFFF9800),
    Color(0xFFE91E63),
    Color(0xFF9C27B0),
    Color(0xFF607D8B),
  ];

  late HSVColor _hsv = HSVColor.fromColor(widget.settings.seedColor);

  void _apply(HSVColor color, {bool persist = true}) {
    setState(() => _hsv = color);
    widget.settings.setSeedColor(color.toColor(), persist: persist);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color preview = _hsv.toColor();

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '主色调',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '调整后立即生效，并保存在当前浏览器里',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: preview,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '#${preview.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: '色相',
              value: _hsv.hue,
              max: 360,
              onChanged: (double v) =>
                  _apply(_hsv.withHue(v), persist: false),
              onChangeEnd: (double v) => _apply(_hsv.withHue(v)),
            ),
            _buildSlider(
              label: '饱和度',
              value: _hsv.saturation,
              max: 1,
              onChanged: (double v) =>
                  _apply(_hsv.withSaturation(v), persist: false),
              onChangeEnd: (double v) => _apply(_hsv.withSaturation(v)),
            ),
            _buildSlider(
              label: '明度',
              value: _hsv.value,
              max: 1,
              onChanged: (double v) =>
                  _apply(_hsv.withValue(v), persist: false),
              onChangeEnd: (double v) => _apply(_hsv.withValue(v)),
            ),
            const SizedBox(height: 16),
            Text('预设颜色', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final Color color in _presets)
                  InkWell(
                    onTap: () => _apply(HSVColor.fromColor(color)),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.toARGB32() ==
                                  widget.settings.seedColor.toARGB32()
                              ? theme.colorScheme.onSurface
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                await widget.settings.resetTheme();
                if (!mounted) return;
                setState(
                  () => _hsv = HSVColor.fromColor(
                    widget.settings.seedColor,
                  ),
                );
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('恢复默认'),
            ),
            if (widget.onResetText != null) ...[
              const Divider(height: 40),
              Text(
                '文字与头像',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.hasTextChanges
                    ? (widget.savedToServer
                        ? '已经改过一些内容（包括文章），保存时都写进了服务器上的 JSON'
                        : '已经改过一些内容（包括文章），同样只保存在当前浏览器里')
                    : '点击页面上的头像、标题、名字、简介、页脚即可直接修改；'
                        '文章在顶部的「管理文章」里改',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.hasTextChanges
                    ? widget.onResetText
                    : null,
                icon: const Icon(Icons.text_format),
                label: const Text('恢复默认内容'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onExport,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('导出配置'),
              ),
            ],
            if (widget.onEditFavicon != null) ...[
              const Divider(height: 40),
              Text(
                '站点设置',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  AvatarImage(url: widget.favicon, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.favicon.isEmpty ? '默认图标' : widget.favicon,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '这是浏览器标签页上显示的图标，改完立即生效',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onEditFavicon,
                icon: const Icon(Icons.image_outlined),
                label: const Text('更换站点图标'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: widget.onChangePassword,
                icon: const Icon(Icons.key_outlined),
                label: const Text('修改编辑密码'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(value.round().toString()),
          ],
        ),
        Slider(
          value: value.clamp(0, max),
          max: max,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
