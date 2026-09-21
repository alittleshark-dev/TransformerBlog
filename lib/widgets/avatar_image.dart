import 'package:flutter/material.dart';

/// 头像图片。
///
/// 支持两种写法：`https://...` 走网络加载，其余当成 assets 里的相对路径。
/// 留空或加载失败时显示默认的人形图标。
class AvatarImage extends StatelessWidget {
  const AvatarImage({super.key, required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primary,
      child: ClipOval(
        child: url.isEmpty ? _fallback(scheme) : _buildImage(scheme),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme) => SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.person, size: size / 2, color: scheme.onPrimary),
      );

  Widget _buildImage(ColorScheme scheme) {
    Widget onError(BuildContext context, Object error, StackTrace? stackTrace) =>
        _fallback(scheme);

    if (url.startsWith('http')) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: onError,
        loadingBuilder:
            (BuildContext context, Widget child, ImageChunkEvent? progress) =>
                progress == null ? child : const SizedBox.shrink(),
      );
    }
    return Image.asset(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: onError,
    );
  }
}
