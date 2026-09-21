import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 用外部浏览器打开链接，失败时给出提示。
Future<void> openExternalUrl(BuildContext context, String url) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) return;

  bool opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    opened = false;
  }

  if (opened || !context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('无法打开链接: $url')));
}
