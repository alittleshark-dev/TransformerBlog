/// 解析 JSON 数组，自动忽略结构不正确的元素。
List<T> parseJsonList<T>(
  Object? raw,
  T Function(Map<String, dynamic> json) fromJson,
) {
  if (raw is! List) return const [];
  return raw.whereType<Map<String, dynamic>>().map(fromJson).toList();
}

/// 站点与个人信息，对应 assets/data/profile.json。
class Profile {
  const Profile({
    required this.siteTitle,
    required this.name,
    required this.tagline,
    required this.avatar,
    required this.links,
    required this.footer,
    this.favicon = '',
    this.editPassword = '',
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      siteTitle: json['siteTitle'] as String? ?? '个人网站',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      links: parseJsonList<ContactLink>(json['links'], ContactLink.fromJson),
      footer: json['footer'] as String? ?? '',
      favicon: json['favicon'] as String? ?? '',
      editPassword: json['editPassword'] as String? ?? '',
    );
  }

  final String siteTitle;
  final String name;
  final String tagline;

  /// 头像地址，留空则显示默认图标。
  final String avatar;
  final List<ContactLink> links;
  final String footer;

  /// 浏览器标签页上的站点图标地址，留空则用 web/favicon.png。
  final String favicon;

  /// 进入编辑模式所需的密码，留空则不显示编辑入口。
  ///
  /// 部署了 server/server.dart 时由服务端校验，没部署就是纯前端校验。
  final String editPassword;
}

/// 联系方式条目，没有 url 时只展示文本、不可点击。
class ContactLink {
  const ContactLink({required this.label, required this.value, this.url});

  factory ContactLink.fromJson(Map<String, dynamic> json) {
    final String? url = json['url'] as String?;
    return ContactLink(
      label: json['label'] as String? ?? '',
      value: json['value'] as String? ?? '',
      url: (url == null || url.isEmpty) ? null : url,
    );
  }

  /// 编辑模式下保存到本地时用，格式和 profile.json 里的写法一致。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'value': value,
        if (url != null) 'url': url,
      };

  final String label;
  final String value;
  final String? url;
}

/// 友链，对应 assets/data/friendship.json 中的一项。
class Friend {
  const Friend({
    required this.name,
    required this.description,
    required this.avatar,
    required this.url,
  });

  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }

  final String name;
  final String description;

  /// 头像地址，留空则显示默认图标。
  final String avatar;

  /// 友链地址，留空则只展示、不可点击。
  final String url;

  /// 编辑模式下保存到本地时用，格式和 friendship.json 里的写法一致。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'description': description,
        'avatar': avatar,
        'url': url,
      };
}

/// 文章，对应 assets/data/articles.json 中的一项。
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.summary,
    required this.date,
    required this.content,
    this.tags = const [],
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '无标题',
      summary: json['summary'] as String? ?? '',
      date: json['date'] as String? ?? '',
      content: json['content'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .toList(),
    );
  }

  final String id;
  final String title;
  final String summary;

  /// 发布日期，格式为 yyyy-MM-dd，归档按前 7 位（yyyy-MM）分组。
  final String date;

  /// 正文，使用 Markdown 语法。
  final String content;

  final List<String> tags;

  /// 编辑模式下保存到本地时用，格式和 articles.json 里的写法一致。
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'summary': summary,
        'date': date,
        'content': content,
        if (tags.isNotEmpty) 'tags': tags,
      };
}
