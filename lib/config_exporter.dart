import 'dart:convert';

import 'content_store.dart';
import 'models.dart';

/// 一份导出结果：写到哪个文件、内容是什么。
class ExportedFile {
  const ExportedFile({required this.path, required this.content});

  final String path;
  final String content;

  /// 只取文件名，用来做标签页标题。
  String get name => path.split('/').last;
}

/// 三个配置文件的路径。保存到后端时按文件名请求，这里统一放一处。
class ConfigFiles {
  const ConfigFiles._();

  static const String profile = 'assets/data/profile.json';
  static const String friendship = 'assets/data/friendship.json';
  static const String articles = 'assets/data/articles.json';
}

/// 把编辑模式下改过的东西还原成可以直接覆盖回 assets/data 的 JSON。
///
/// 没改过的字段用 [base] 里的原值补齐，所以导出的始终是一份完整配置，
/// 而不是只有改动的那几项。
List<ExportedFile> exportConfig({
  required Profile base,
  required List<Friend> friends,
  required List<Article> articles,
  required ContentStore store,
}) {
  return <ExportedFile>[
    ExportedFile(
      path: ConfigFiles.profile,
      content: profileJson(base, store),
    ),
    ExportedFile(
      path: ConfigFiles.friendship,
      content: friendsJson(friends),
    ),
    ExportedFile(
      path: ConfigFiles.articles,
      content: articlesJson(articles),
    ),
  ];
}

/// 生成一份完整的 profile.json，编辑模式保存到后端时也用它。
String profileJson(Profile base, ContentStore store) =>
    _encode(_profileJson(base, store));

/// 生成一份完整的 friendship.json。
String friendsJson(List<Friend> friends) => _encode(<Map<String, dynamic>>[
      for (final Friend friend in friends) friend.toJson(),
    ]);

/// 生成一份完整的 articles.json。
String articlesJson(List<Article> articles) => _encode(<Map<String, dynamic>>[
      for (final Article article in articles) article.toJson(),
    ]);

Map<String, dynamic> _profileJson(Profile base, ContentStore store) {
  final List<ContactLink> links = store.has(ContentKeys.links)
      ? store.listOf<ContactLink>(
          ContentKeys.links,
          base.links,
          ContactLink.fromJson,
        )
      : base.links;

  return <String, dynamic>{
    'siteTitle': store.valueOf(ContentKeys.siteTitle, base.siteTitle),
    'name': store.valueOf(ContentKeys.name, base.name),
    'tagline': store.valueOf(ContentKeys.tagline, base.tagline),
    'avatar': store.valueOf(ContentKeys.avatar, base.avatar),
    'favicon': store.valueOf(ContentKeys.favicon, base.favicon),
    'links': <Map<String, dynamic>>[
      for (final ContactLink link in links) link.toJson(),
    ],
    'footer': store.valueOf(ContentKeys.footer, base.footer),
    // 改过密码就用改后的，没改过照原样带回去，免得导出后编辑入口没了
    'editPassword': store.valueOf(ContentKeys.editPassword, base.editPassword),
  };
}

/// 缩进两格，末尾补一个换行，跟手写 JSON 的观感一致。
String _encode(Object? value) =>
    '${const JsonEncoder.withIndent('  ').convert(value)}\n';
