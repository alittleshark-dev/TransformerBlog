import 'dart:convert';

import 'package:flutter/services.dart';

import 'config_api.dart';
import 'models.dart';

/// 从 assets/data 读取站点数据。
///
/// 模板使用者只需要修改 JSON 文件，不需要改动 Dart 代码。
///
/// 配了 [api]（也就是部署了 server/server.dart）时优先从后端读，这样
/// 编辑模式保存的改动所有访客都能看到。后端读不到就退回打包进产物的
/// JSON，所以纯静态托管照样能跑。
class DataService {
  const DataService({this.api});

  /// 后端接口，为 null 表示纯静态模式。
  final ConfigApi? api;

  static const String profilePath = 'assets/data/profile.json';
  static const String friendsPath = 'assets/data/friendship.json';
  static const String articlesPath = 'assets/data/articles.json';

  Future<Profile> loadProfile() async {
    return Profile.fromJson(await _loadObject(profilePath));
  }

  Future<List<Friend>> loadFriends() async {
    return parseJsonList<Friend>(await _load(friendsPath), Friend.fromJson);
  }

  /// 文章按日期倒序返回，最新的排在最前面。
  Future<List<Article>> loadArticles() async {
    final List<Article> articles = parseJsonList<Article>(
      await _load(articlesPath),
      Article.fromJson,
    );
    articles.sort((Article a, Article b) => b.date.compareTo(a.date));
    return articles;
  }

  Future<Object?> _load(String path) async {
    return jsonDecode(await _read(path));
  }

  Future<String> _read(String path) async {
    final ConfigApi? api = this.api;
    if (api != null) {
      final String? remote = await api.read(path.split('/').last);
      if (remote != null && remote.trim().isNotEmpty) return remote;
    }
    return rootBundle.loadString(path);
  }

  Future<Map<String, dynamic>> _loadObject(String path) async {
    final Object? data = await _load(path);
    if (data is! Map<String, dynamic>) {
      throw FormatException('$path 的顶层结构应该是 JSON 对象');
    }
    return data;
  }
}
