import 'dart:convert';

import 'package:http/http.dart' as http;

/// 后端接口的地址。
///
/// 默认 `/api`，也就是跟页面同源：nginx 反代到 server.dart，或者直接
/// `server.dart --static build/web` 跑起来，两种部署都不用改这里。
///
/// 开发时前端在 `flutter run` 的端口上，跟后端不同源，这时会自动再试
/// 一下 [devFallbackUrl]，所以不用额外加参数。后端换了端口就用
/// `--dart-define=API_BASE=http://127.0.0.1:9090/api` 指定。
const String _defaultBaseUrl = String.fromEnvironment(
  'API_BASE',
  defaultValue: '/api',
);

/// 开发时后端默认监听的地址。
const String devFallbackUrl = 'http://127.0.0.1:8090/api';

/// 后端配置接口的客户端。
///
/// 部署了 server/server.dart 时，前端从它读数据、把编辑结果写回去，
/// 改动会真正落到 assets/data 的 JSON 文件里。
///
/// 没部署后端时（纯静态托管），[read] 一律返回 null，[write] 一律返回
/// [WriteResult.unavailable]，前端就退回本浏览器保存的老路。
class ConfigApi {
  const ConfigApi({this.baseUrl = _defaultBaseUrl});

  final String baseUrl;

  /// 探测和读取的超时。纯静态托管下请求会很快失败，不用等太久。
  static const Duration timeout = Duration(seconds: 5);

  static const Map<String, String> _headers = <String, String>{
    'Content-Type': 'application/json; charset=utf-8',
  };

  /// 依次要试的后端地址。
  ///
  /// 第一个永远是 [baseUrl]。页面跑在本机时再补一个开发用的地址：
  /// `flutter run` 起的端口上只有前端，没有 /api，得去找单独跑的后端。
  List<String> get _candidates {
    if (baseUrl != _defaultBaseUrl) return <String>[baseUrl];
    return <String>[baseUrl, if (_isLocal) devFallbackUrl];
  }

  /// 页面是不是跑在本机上。用 [Uri.base] 取页面地址，各平台都能用。
  bool get _isLocal {
    final String host = Uri.base.host;
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  /// 读一份配置。
  ///
  /// 返回文件内容；所有候选地址都拿不到就返回 null。
  Future<String?> read(String name) async {
    for (final String base in _candidates) {
      final String? content = await _readFrom(base, name);
      if (content != null) return content;
    }
    return null;
  }

  Future<String?> _readFrom(String base, String name) async {
    try {
      final http.Response response = await http
          .get(Uri.parse('$base/data/$name'), headers: _headers)
          .timeout(timeout);
      if (response.statusCode != 200) return null;
      // 后端明确返回 utf-8，这里手动解一下，避免中文乱码
      final String body = utf8.decode(response.bodyBytes);
      // 光看状态码不够：`flutter run` 的 dev server 对没匹配上的路径会返回
      // 200 + index.html。当成数据收下的话，解析 JSON 会炸，整页报加载失败
      if (!_looksLikeJson(body)) return null;
      return body;
    } on Exception {
      return null;
    }
  }

  /// 响应体看起来是不是 JSON。
  ///
  /// 只看开头的 `{` 或 `[`，不去解析，免得为了判断格式白解析一遍。
  static bool _looksLikeJson(String body) {
    final String trimmed = body.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }

  /// 把一份配置写回后端。
  Future<WriteResult> write(
    String name,
    String content, {
    required String password,
  }) async {
    WriteResult? failure;
    for (final String base in _candidates) {
      final WriteResult? result = await _writeTo(
        base,
        name,
        content,
        password: password,
      );
      // null 表示这个地址上没有后端，接着试下一个
      if (result == null) continue;
      if (result == WriteResult.saved || result == WriteResult.wrongPassword) {
        return result;
      }
      // 后端在但写失败了，记下来，万一后面都连不上也好给出准确提示
      failure = result;
    }
    return failure ?? WriteResult.unavailable;
  }

  Future<WriteResult?> _writeTo(
    String base,
    String name,
    String content, {
    required String password,
  }) async {
    try {
      final http.Response response = await http
          .put(
            Uri.parse('$base/data/$name'),
            headers: <String, String>{
              ..._headers,
              // 密码先百分号编码再放头里：HTTP 头只能放 ASCII，
              // 密码里有中文的话不编码会直接抛异常，看起来就像后端没开
              'X-Edit-Password': Uri.encodeComponent(password),
            },
            body: utf8.encode(content),
          )
          .timeout(timeout);

      // 404/405 说明这个地址上压根没有后端（比如前端自己的 dev server）
      if (response.statusCode == 404 || response.statusCode == 405) return null;
      if (response.statusCode == 200) return WriteResult.saved;
      if (response.statusCode == 401) return WriteResult.wrongPassword;
      return WriteResult.failed;
    } on Exception {
      return null;
    }
  }
}

/// 写回后端的结果。
enum WriteResult {
  /// 已写进 JSON 文件，所有访客都能看到。
  saved,

  /// 后端在，但密码不对。
  wrongPassword,

  /// 后端在，但写入失败（比如文件没权限）。
  failed,

  /// 没有后端，改动只留在了本浏览器。
  unavailable,
}
