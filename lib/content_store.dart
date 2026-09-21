import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 编辑模式下可以改的字段，键名和 assets/data 里的 JSON 保持一致。
class ContentKeys {
  const ContentKeys._();

  static const String siteTitle = 'siteTitle';
  static const String name = 'name';
  static const String tagline = 'tagline';
  static const String avatar = 'avatar';
  static const String favicon = 'favicon';
  static const String links = 'links';
  static const String footer = 'footer';
  static const String editPassword = 'editPassword';
  static const String friends = 'friends';
  static const String articles = 'articles';
}

/// 编辑模式下改过的个人文字，按字段名保存在本地。
///
/// 注意：这里只是本地副本，部署了 server/server.dart 时首页保存会同时
/// 写回 assets/data 里的 JSON，没部署的话改动就只留在当前浏览器。
class ContentStore {
  static const String _storageKey = 'profileOverrides';

  Map<String, String> _values = <String, String>{};

  bool get isEmpty => _values.isEmpty;

  /// 这个字段有没有被改过。
  ///
  /// 用来区分「没改过」和「改成空列表」这两种情况。
  bool has(String key) => _values.containsKey(key);

  /// 取字段当前的值，没改过就返回 [fallback]。
  String valueOf(String key, String fallback) => _values[key] ?? fallback;

  /// 读取以 JSON 存进本地的列表，解析不了就返回 [fallback]。
  List<T> listOf<T>(
    String key,
    List<T> fallback,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    final String? raw = _values[key];
    if (raw == null || raw.isEmpty) return fallback;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return fallback;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(fromJson)
          .toList();
    } on FormatException {
      return fallback;
    }
  }

  Future<void> setList(String key, List<Map<String, dynamic>> items) =>
      set(key, jsonEncode(items));

  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final Object? decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        _values = <String, String>{
          for (final MapEntry<String, dynamic> entry in decoded.entries)
            if (entry.value is String) entry.key: entry.value as String,
        };
      }
    } on Exception {
      // 存的数据坏了就当没改过
      _values = <String, String>{};
    }
  }

  Future<void> set(String key, String value) async {
    _values[key] = value;
    await _persist();
  }

  /// 删掉这几个字段的本地覆盖。
  ///
  /// 内容已经写进服务器 JSON 时用。本地副本是整体替换而非合并的，留着它
  /// 会一直盖住服务器数据：以后直接改 assets/data 里的内容，页面反而不会
  /// 变，很难想到是浏览器里存了一份。
  Future<void> removeAll(Iterable<String> keys) async {
    bool changed = false;
    for (final String key in keys) {
      if (_values.remove(key) != null) changed = true;
    }
    if (changed) await _persist();
  }

  Future<void> clear() async {
    _values = <String, String>{};
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } on Exception {
      // 忽略
    }
  }

  Future<void> _persist() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_values));
    } on Exception {
      // 保存失败不影响当前会话
    }
  }
}
