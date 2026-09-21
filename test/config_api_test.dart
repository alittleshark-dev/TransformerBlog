import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transformer_blog/config_api.dart';

/// 起一个真的 HTTP 服务，验证 [ConfigApi] 对各类响应的判断。
void main() {
  late HttpServer server;
  late String baseUrl;
  late int status;
  late String getBody;
  late String? receivedBody;
  late String? receivedPassword;

  setUp(() async {
    status = 200;
    getBody = '{"siteTitle":"从后端来"}';
    receivedBody = null;
    receivedPassword = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}/api';
    server.listen((HttpRequest request) async {
      receivedPassword = request.headers.value('X-Edit-Password');
      receivedBody = await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType(
          'application',
          'json',
          charset: 'utf-8',
        );
      if (request.method == 'GET' && status == 200) {
        request.response.write(getBody);
      }
      await request.response.close();
    });
  });

  tearDown(() => server.close(force: true));

  test('写成功返回 saved，并把密码和内容原样发出去', () async {
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(
      await api.write('profile.json', '{"a":1}', password: 'transformer_blog'),
      WriteResult.saved,
    );
    expect(receivedPassword, 'transformer_blog');
    expect(receivedBody, '{"a":1}');
  });

  test('密码不对返回 wrongPassword', () async {
    status = 401;
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(
      await api.write('profile.json', '{}', password: '错'),
      WriteResult.wrongPassword,
    );
  });

  test('密码带中文也能发出去，不会当成后端没开', () async {
    // HTTP 头只能放 ASCII，中文密码不编码的话请求会直接抛异常，
    // 被兜底逻辑吞掉就报成「未部署后端」了
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(
      await api.write('profile.json', '{}', password: '恐龙'),
      WriteResult.saved,
    );
    expect(receivedPassword, isNot('恐龙'));
    expect(Uri.decodeComponent(receivedPassword!), '恐龙');
  });

  test('后端出错返回 failed', () async {
    status = 500;
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(
      await api.write('profile.json', '{}', password: 'transformer_blog'),
      WriteResult.failed,
    );
  });

  test('地址上没有后端时返回 unavailable', () async {
    // 404 是「这个地址上没有 /api」，不是「后端写失败了」，
    // 否则前端自己的 dev server 会被误判成后端出错
    status = 404;
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(
      await api.write('profile.json', '{}', password: 'transformer_blog'),
      WriteResult.unavailable,
    );
  });

  test('连不上时返回 unavailable', () async {
    await server.close(force: true);
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(
      await api.write('profile.json', '{}', password: 'transformer_blog'),
      WriteResult.unavailable,
    );
  });

  test('读得到内容时原样返回，中文不乱码', () async {
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(await api.read('profile.json'), '{"siteTitle":"从后端来"}');
  });

  test('读不到时返回 null', () async {
    status = 404;
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(await api.read('profile.json'), isNull);
  });

  test('200 但返回的是 HTML 时当成没后端', () async {
    // `flutter run` 的 dev server 对没匹配上的路径返回 200 + index.html，
    // 光看状态码会把这页 HTML 当成配置，解析 JSON 时整页报加载失败
    getBody =
        '<!DOCTYPE html>\n<html><head><title>transformer_blog</title></head></html>';
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(await api.read('profile.json'), isNull);
  });

  test('200 但返回的是空内容时当成没后端', () async {
    getBody = '';
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(await api.read('profile.json'), isNull);
  });

  test('顶层是数组的 JSON 也能读', () async {
    getBody = '[{"name":"示例友链"}]';
    final ConfigApi api = ConfigApi(baseUrl: baseUrl);
    expect(await api.read('friendship.json'), '[{"name":"示例友链"}]');
  });
}
